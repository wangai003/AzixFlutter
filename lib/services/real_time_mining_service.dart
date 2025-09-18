import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/secure_mining_session.dart';
import 'stellar_service.dart';
import 'email_notification_service.dart';
import 'secure_wallet_service.dart';

/// Service for real-time mining progress tracking and persistence
class RealTimeMiningService {
  static const String _sessionKey = 'current_mining_session_v2';
  static const String _lastUpdateKey = 'last_mining_update';

  final StellarService _stellarService;
  Timer? _realTimeTimer;
  Timer? _persistenceTimer;
  StreamController<SecureMiningSession>? _sessionStreamController;
  SecureMiningSession? _currentSession;

  /// Get real-time session updates stream
  Stream<SecureMiningSession> get sessionStream {
    _sessionStreamController ??=
        StreamController<SecureMiningSession>.broadcast();
    return _sessionStreamController!.stream;
  }

  /// Constructor
  RealTimeMiningService(this._stellarService);

  /// Initialize the service
  Future<void> initialize() async {
    await _restoreSession();
    _startRealTimeTracking();
    _startPersistenceTimer();
  }

  /// Start real-time progress tracking
  void _startRealTimeTracking() {
    _realTimeTimer?.cancel();
    _realTimeTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) async => await _updateRealTimeProgress(),
    );
  }

  /// Start persistence timer (saves every 10 seconds)
  void _startPersistenceTimer() {
    _persistenceTimer?.cancel();
    _persistenceTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _persistSession(),
    );
  }

  /// Update real-time mining progress
  Future<void> _updateRealTimeProgress() async {
    if (_currentSession == null ||
        !_currentSession!.isActive ||
        _currentSession!.isPaused) {
      return;
    }

    final now = DateTime.now();

    // Check if session expired
    if (now.isAfter(_currentSession!.sessionEnd)) {
      await _endSession();
      return;
    }

    // Calculate elapsed time since last resume (for current earnings cycle)
    final elapsedTimeSinceResume = now
        .difference(_currentSession!.lastResume)
        .inSeconds;

    // CRITICAL FIX: Add to accumulated seconds instead of overwriting
    // This ensures earnings accumulate properly across app restarts
    if (elapsedTimeSinceResume > 0 && elapsedTimeSinceResume < 3600) {
      // Max 1 hour to prevent corruption
      _currentSession!.accumulatedSeconds += elapsedTimeSinceResume;
    }

    // Update lastResume to prevent double-counting in future updates
    _currentSession!.lastResume = now;

    // Auto-submit proof every 5 minutes to ensure earnings calculation works
    final lastProofAge = now
        .difference(_currentSession!.lastProofSubmission)
        .inMinutes;
    if (lastProofAge >= 5) {
      _currentSession!.submitProof('auto_update', elapsedTimeSinceResume);
    }

    // Emit updated session
    _sessionStreamController?.add(_currentSession!);

    // Debug: Show real-time progress
    if (elapsedTimeSinceResume % 10 == 0) {
      // Log every 10 seconds to avoid spam
      final totalSessionElapsed = now
          .difference(_currentSession!.sessionStart)
          .inSeconds;
      final totalSessionRemaining = (24 * 3600 - totalSessionElapsed) / 3600;
      final currentCycleEarnings = _currentSession!.earnedAkofa;
    }
  }

  /// Start a new mining session
  Future<SecureMiningSession> startSession(
    String userId,
    String deviceId,
  ) async {
    // Check if there's already an active session for this user
    final existingSession = await _checkForExistingActiveSession(userId);
    if (existingSession != null) {
      // Restore the existing session
      _currentSession = existingSession;
      await _persistSession();
      _sessionStreamController?.add(_currentSession!);

      return _currentSession!;
    }

    final miningRate = await _calculateMiningRate(userId);

    _currentSession = SecureMiningSession.newSession(
      userId: userId,
      deviceId: deviceId,
      miningRate: miningRate,
    );

    await _persistSession();
    _sessionStreamController?.add(_currentSession!);

    // Send mining start notification
    await _sendMiningStartNotification(userId, _currentSession!);

    return _currentSession!;
  }

  /// Check for existing active mining session (prevents parallel mining)
  Future<SecureMiningSession?> _checkForExistingActiveSession(
    String userId,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // CRITICAL FIX: Check for ANY active session (not just non-paused)
      // This prevents parallel mining across devices
      final activeSessionsQuery = await FirebaseFirestore.instance
          .collection('USER')
          .doc(user.uid)
          .collection('active_mining_sessions')
          .where('sessionEnd', isGreaterThan: DateTime.now())
          .limit(1)
          .get();

      if (activeSessionsQuery.docs.isNotEmpty) {
        final doc = activeSessionsQuery.docs.first;
        final data = doc.data();

        // CRITICAL: Always restore existing session to prevent parallel mining
        // This ensures only ONE active session per user across all devices
        return SecureMiningSession(
          sessionId: data['sessionId'] ?? doc.id,
          sessionStart: (data['sessionStart'] as Timestamp).toDate(),
          sessionEnd: (data['sessionEnd'] as Timestamp).toDate(),
          userId: data['userId'] ?? user.uid,
          deviceId: data['deviceId'] ?? 'unknown_device',
          miningRate: (data['miningRate'] as num?)?.toDouble() ?? 0.25,
          initialChallenge: data['initialChallenge'] ?? 'existing_session',
          proofs: [],
          sessionHash: data['sessionHash'] ?? 'existing_session',
          isPaused: data['isPaused'] ?? false,
          pausedAt: data['pausedAt'] != null
              ? (data['pausedAt'] as Timestamp).toDate()
              : null,
          lastResume: data['lastResume'] != null
              ? (data['lastResume'] as Timestamp).toDate()
              : DateTime.now(),
          accumulatedSeconds: data['accumulatedSeconds'] ?? 0,
          totalProofsSubmitted: data['totalProofsSubmitted'] ?? 0,
          lastProofSubmission: data['lastProofSubmission'] != null
              ? (data['lastProofSubmission'] as Timestamp).toDate()
              : DateTime.now(),
        );
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Pause mining session and credit earned tokens
  Future<void> pauseSession() async {
    if (_currentSession == null ||
        !_currentSession!.isActive ||
        _currentSession!.isPaused) {
      return;
    }

    // Update real-time progress before pausing
    await _updateRealTimeProgress();

    // Get the current earned amount before pausing
    final earnedBeforePause = _currentSession!.earnedAkofa;

    if (earnedBeforePause > 0) {
      // First check if user can receive rewards
      final eligibility = await checkRewardEligibility();

      if (!eligibility['canReceive']) {
        // Log the ineligibility reason
        final reason = eligibility['reason'] ?? 'Unknown';
        final details = eligibility['details'] ?? '';
        // You can show this to the user or log it
        return; // Don't attempt to send reward
      }

      try {
        // Round to 4 decimal places to avoid Stellar precision errors
        final roundedAmount = _roundAkofaAmount(earnedBeforePause);

        if (roundedAmount != earnedBeforePause) {}

        // Credit the rounded amount to the user's wallet
        final result = await _stellarService.recordMiningReward(roundedAmount);

        if (result['success'] == true) {
          // Record this pause reward in session history
          await _recordPauseReward(roundedAmount, result['hash']);
        } else {
          // Log the failure reason for debugging
          final errorMessage =
              result['message'] ?? 'Unknown error during pause reward';
          // You can add logging here or show user notification
        }
      } catch (e) {
        // Log the exception for debugging
        final errorMessage = 'Exception during pause reward: $e';
        // You can add logging here or show user notification
      }
    }

    // Pause the session
    _currentSession!.isPaused = true;
    _currentSession!.pausedAt = DateTime.now();

    // CRITICAL FIX: DO NOT reset accumulatedSeconds!
    // Preserve the accumulated time so resume continues from where it left off
    // _currentSession!.accumulatedSeconds = 0; // REMOVE THIS LINE

    await _persistSession();
    _sessionStreamController?.add(_currentSession!);

    // Send mining resume notification
    await _sendMiningResumeNotification(
      _currentSession!.userId,
      _currentSession!,
    );
  }

  /// Resume mining session with fresh earnings cycle
  Future<void> resumeSession() async {
    if (_currentSession == null || !_currentSession!.isPaused) {
      return;
    }

    final now = DateTime.now();
    final pausedDuration = _currentSession!.pausedAt != null
        ? now.difference(_currentSession!.pausedAt!).inSeconds
        : 0;

    // Resume the session
    _currentSession!.isPaused = false;
    _currentSession!.lastResume = now;
    _currentSession!.pausedAt = null;

    // Note: accumulatedSeconds is already reset to 0 in pauseSession()
    // This ensures earnings start from zero for the new cycle

    await _persistSession();
    _sessionStreamController?.add(_currentSession!);

    // Send mining pause notification
    await _sendMiningPauseNotification(
      _currentSession!.userId,
      _currentSession!,
    );
  }

  /// End current mining session
  Future<double> _endSession() async {
    if (_currentSession == null) return 0.0;

    // Final progress update
    await _updateRealTimeProgress();

    final earnedAkofa = _currentSession!.earnedAkofa;

    // Mark session as completed
    _currentSession!.isPaused = true; // Stop the session

    await _persistSession();
    await _saveSessionHistory();

    // Process final mining reward if there are any remaining earnings
    if (earnedAkofa > 0) {
      try {
        // Round to 4 decimal places to avoid Stellar precision errors
        final roundedAmount = _roundAkofaAmount(earnedAkofa);

        if (roundedAmount != earnedAkofa) {}

        final result = await _stellarService.recordMiningReward(roundedAmount);

        if (result['success'] == true) {
        } else {}
      } catch (e) {}
    }

    // Send mining completion notification before clearing session
    if (_currentSession != null) {
      await _sendMiningCompletionNotification(
        _currentSession!.userId,
        _currentSession!,
      );
    }

    // Clear current session
    _currentSession = null;
    await _clearPersistedSession();

    return earnedAkofa;
  }

  /// Get current session
  SecureMiningSession? getCurrentSession() {
    return _currentSession;
  }

  /// Check if current user can receive pause rewards
  Future<Map<String, dynamic>> canReceivePauseRewards() async {
    return await checkRewardEligibility();
  }

  /// Restore session from storage and cross-device sync
  Future<void> _restoreSession() async {
    try {
      // FIRST: Try to restore from Firestore (cross-device sync) - most reliable for web
      final restoredFromServer = await _restoreFromFirestore();

      if (restoredFromServer) {
        return;
      }

      // SECOND: Fallback to local storage if no server session
      final prefs = await SharedPreferences.getInstance();
      final sessionData = prefs.getString(_sessionKey);
      final lastUpdateStr = prefs.getString(_lastUpdateKey);

      if (sessionData != null) {
        final sessionMap = json.decode(sessionData) as Map<String, dynamic>;

        // Reconstruct session from stored data
        _currentSession = SecureMiningSession(
          sessionId: sessionMap['sessionId'],
          sessionStart: DateTime.parse(sessionMap['sessionStart']),
          sessionEnd: DateTime.parse(sessionMap['sessionEnd']),
          userId: sessionMap['userId'],
          deviceId: sessionMap['deviceId'],
          miningRate: (sessionMap['miningRate'] as num).toDouble(),
          initialChallenge: sessionMap['initialChallenge'] ?? 'restored',
          proofs: [], // Will be restored from server if needed
          sessionHash: sessionMap['sessionHash'] ?? 'restored',
          isPaused: sessionMap['isPaused'] ?? false,
          pausedAt: sessionMap['pausedAt'] != null
              ? DateTime.parse(sessionMap['pausedAt'])
              : null,
          lastResume: sessionMap['lastResume'] != null
              ? DateTime.parse(sessionMap['lastResume'])
              : DateTime.now(),
          accumulatedSeconds: sessionMap['accumulatedSeconds'] ?? 0,
          totalProofsSubmitted: sessionMap['totalProofsSubmitted'] ?? 0,
          lastProofSubmission: sessionMap['lastProofSubmission'] != null
              ? DateTime.parse(sessionMap['lastProofSubmission'])
              : DateTime.now(),
        );

        final now = DateTime.now();

        // Check if session is still valid
        if (_currentSession!.isActive &&
            now.isBefore(_currentSession!.sessionEnd)) {
          // Calculate total elapsed time since session start (for session progress)
          final totalSessionElapsed = now
              .difference(_currentSession!.sessionStart)
              .inSeconds;

          // CRITICAL FIX: Preserve existing accumulated time and add time since last resume
          // Don't reset accumulatedSeconds - add to the existing value
          if (!_currentSession!.isPaused) {
            final timeSinceLastResume = now
                .difference(_currentSession!.lastResume)
                .inSeconds;

            // Only add time if it's reasonable (prevent huge jumps from corrupted timestamps)
            if (timeSinceLastResume > 0 && timeSinceLastResume < 86400) {
              // Max 24 hours
              _currentSession!.accumulatedSeconds += timeSinceLastResume;
            }

            // Update lastResume to now to prevent double-counting
            _currentSession!.lastResume = now;
          }

          // Web-specific: Validate session integrity for web browsers
          if (kIsWeb) {
            await _validateWebSessionIntegrity();
          }

          // Sync this local session to server for other devices
          await _saveToFirestore();

          final elapsedHours = _currentSession!.accumulatedSeconds / 3600.0;
          final remainingHours = 24.0 - elapsedHours;
          _sessionStreamController?.add(_currentSession!);
        } else if (now.isAfter(_currentSession!.sessionEnd)) {
          // Session expired while app was closed
          await _endSession();
        } else {
          // Invalid session
          await _clearPersistedSession();
        }
      }
    } catch (e) {
      await _clearPersistedSession();
    }
  }

  /// Restore session from Firestore for cross-device sync
  Future<bool> _restoreFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // CRITICAL FIX: Check for ANY active session (not just non-paused)
      // This enables proper cross-device sync for both active and paused sessions
      final activeSessionsQuery = await FirebaseFirestore.instance
          .collection('USER')
          .doc(user.uid)
          .collection('active_mining_sessions')
          .where('sessionEnd', isGreaterThan: DateTime.now())
          .orderBy('sessionEnd', descending: true) // Get most recent
          .limit(1)
          .get();

      if (activeSessionsQuery.docs.isNotEmpty) {
        final doc = activeSessionsQuery.docs.first;
        final data = doc.data();

        // Check if this session is from a different device
        final serverDeviceId = data['deviceId'] as String?;
        final currentDeviceId = await _getCurrentDeviceId();

        // Log cross-device sync
        if (serverDeviceId != null && serverDeviceId != currentDeviceId) {
          // Cross-device session detected - this is normal and expected
        }

        // Reconstruct session from server data
        _currentSession = SecureMiningSession(
          sessionId: data['sessionId'] ?? doc.id,
          sessionStart: (data['sessionStart'] as Timestamp).toDate(),
          sessionEnd: (data['sessionEnd'] as Timestamp).toDate(),
          userId: data['userId'] ?? user.uid,
          deviceId: serverDeviceId ?? currentDeviceId,
          miningRate: (data['miningRate'] as num?)?.toDouble() ?? 0.25,
          initialChallenge: data['initialChallenge'] ?? 'server_restored',
          proofs: [],
          sessionHash: data['sessionHash'] ?? 'server_restored',
          isPaused: data['isPaused'] ?? false,
          pausedAt: data['pausedAt'] != null
              ? (data['pausedAt'] as Timestamp).toDate()
              : null,
          lastResume: data['lastResume'] != null
              ? (data['lastResume'] as Timestamp).toDate()
              : DateTime.now(),
          accumulatedSeconds: data['accumulatedSeconds'] ?? 0,
          totalProofsSubmitted: data['totalProofsSubmitted'] ?? 0,
          lastProofSubmission: data['lastProofSubmission'] != null
              ? (data['lastProofSubmission'] as Timestamp).toDate()
              : DateTime.now(),
        );

        // Calculate current elapsed time for earnings cycle
        final now = DateTime.now();
        if (!_currentSession!.isPaused) {
          // CRITICAL FIX: Preserve existing accumulated time and add time since last resume
          // Don't reset accumulatedSeconds - add to the existing value
          final timeSinceLastResume = now
              .difference(_currentSession!.lastResume)
              .inSeconds;

          // Only add time if it's reasonable (prevent huge jumps from corrupted timestamps)
          if (timeSinceLastResume > 0 && timeSinceLastResume < 86400) {
            // Max 24 hours
            _currentSession!.accumulatedSeconds += timeSinceLastResume;
          }

          // Update lastResume to now to prevent double-counting
          _currentSession!.lastResume = now;
        }

        // Save to local storage for this device
        await _persistSession();

        _sessionStreamController?.add(_currentSession!);

        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get current device identifier
  Future<String> _getCurrentDeviceId() async {
    // Use a combination of platform and device info for unique identification
    final platform = Platform.operatingSystem;
    final deviceInfo = DeviceInfoPlugin();

    if (platform == 'android') {
      final androidInfo = await deviceInfo.androidInfo;
      return '${platform}_${androidInfo.id}';
    } else if (platform == 'ios') {
      final iosInfo = await deviceInfo.iosInfo;
      return '${platform}_${iosInfo.identifierForVendor}';
    } else if (platform == 'web') {
      // For web, create a more unique identifier using available web APIs
      try {
        // Use a combination of timestamp, random number, and user agent hash
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final random = DateTime.now().microsecondsSinceEpoch % 10000;
        final userAgent = 'web_user_agent_${timestamp}_${random}';
        final bytes = utf8.encode(userAgent);
        final hash = sha256.convert(bytes).toString().substring(0, 16);
        return '${platform}_${hash}';
      } catch (e) {
        // Fallback if crypto fails
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final random = DateTime.now().microsecondsSinceEpoch % 10000;
        return '${platform}_${timestamp}_${random}';
      }
    }

    return '${platform}_unknown';
  }

  /// Persist current session to storage
  Future<void> _persistSession() async {
    if (_currentSession == null) return;

    try {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      // Complete persistence with all session data
      final sessionInfo = {
        'sessionId': _currentSession!.sessionId,
        'userId': _currentSession!.userId,
        'deviceId': _currentSession!.deviceId,
        'sessionStart': _currentSession!.sessionStart.toIso8601String(),
        'sessionEnd': _currentSession!.sessionEnd.toIso8601String(),
        'isPaused': _currentSession!.isPaused,
        'pausedAt': _currentSession!.pausedAt?.toIso8601String(),
        'lastResume': _currentSession!.lastResume.toIso8601String(),
        'accumulatedSeconds': _currentSession!.accumulatedSeconds,
        'totalProofsSubmitted': _currentSession!.totalProofsSubmitted,
        'lastProofSubmission': _currentSession!.lastProofSubmission
            .toIso8601String(),
        'miningRate': _currentSession!.miningRate,
        'initialChallenge': _currentSession!.initialChallenge,
        'sessionHash': _currentSession!.sessionHash,
        'serverValidationHash': _currentSession!.serverValidationHash,
        // Add web-specific persistence markers
        'platform': Platform.operatingSystem,
        'persistedAt': now.toIso8601String(),
        'webCompatible': true,
      };
      await prefs.setString(_sessionKey, json.encode(sessionInfo));
      await prefs.setString(_lastUpdateKey, now.toIso8601String());

      final currentCycleHours = _currentSession!.accumulatedSeconds / 3600.0;
      final totalSessionElapsed =
          now.difference(_currentSession!.sessionStart).inSeconds / 3600.0;
      final totalSessionRemaining = 24.0 - totalSessionElapsed;

      // Also save to Firestore for cross-device sync
      await _saveToFirestore();
    } catch (e) {
      // For web, try alternative persistence if SharedPreferences fails
      if (kIsWeb) {
        try {
          await _webFallbackPersistence();
        } catch (webError) {
          // If both fail, at least try Firestore
          await _saveToFirestore();
        }
      }
    }
  }

  /// Web-specific fallback persistence using localStorage through JavaScript
  Future<void> _webFallbackPersistence() async {
    if (_currentSession == null || !kIsWeb) return;

    try {
      // This would use web-specific storage if needed
      // For now, rely on Firestore as primary web persistence
      await _saveToFirestore();
    } catch (e) {
      // Last resort - just ensure Firestore sync
    }
  }

  /// Validate web session integrity to ensure mining consistency
  Future<void> _validateWebSessionIntegrity() async {
    if (_currentSession == null || !kIsWeb) return;

    try {
      // Check if Firestore session matches local session
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final serverSession = await FirebaseFirestore.instance
          .collection('USER')
          .doc(user.uid)
          .collection('active_mining_sessions')
          .doc(_currentSession!.sessionId)
          .get();

      if (serverSession.exists) {
        final serverData = serverSession.data()!;
        final serverAccumulated = serverData['accumulatedSeconds'] ?? 0;

        // If server has more accumulated time, use server value
        if (serverAccumulated > _currentSession!.accumulatedSeconds) {
          _currentSession!.accumulatedSeconds = serverAccumulated;
        }

        // Ensure lastResume is reasonable
        final serverLastResume = (serverData['lastResume'] as Timestamp?)
            ?.toDate();
        if (serverLastResume != null &&
            serverLastResume.isAfter(_currentSession!.lastResume)) {
          _currentSession!.lastResume = serverLastResume;
        }
      }
    } catch (e) {
      // If validation fails, ensure we have Firestore backup
      await _saveToFirestore();
    }
  }

  /// Save session to Firestore
  Future<void> _saveToFirestore() async {
    if (_currentSession == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('USER')
            .doc(user.uid)
            .collection('active_mining_sessions')
            .doc(_currentSession!.sessionId)
            .set({
              'sessionId': _currentSession!.sessionId,
              'userId': _currentSession!.userId,
              'deviceId': _currentSession!.deviceId,
              'sessionStart': _currentSession!.sessionStart,
              'sessionEnd': _currentSession!.sessionEnd,
              'isPaused': _currentSession!.isPaused,
              'pausedAt': _currentSession!.pausedAt,
              'lastResume': _currentSession!.lastResume,
              'accumulatedSeconds': _currentSession!.accumulatedSeconds,
              'miningRate': _currentSession!.miningRate,
              'earnedAkofa': _currentSession!.earnedAkofa,
              'totalProofsSubmitted': _currentSession!.totalProofsSubmitted,
              'lastProofSubmission': _currentSession!.lastProofSubmission,
              'initialChallenge': _currentSession!.initialChallenge,
              'sessionHash': _currentSession!.sessionHash,
              'lastSynced': FieldValue.serverTimestamp(),
              'realTimeUpdate': true,
              'crossDeviceSync': true,
            }, SetOptions(merge: true));
      }
    } catch (e) {}
  }

  /// Record pause reward in session history
  Future<void> _recordPauseReward(
    double amount,
    String? transactionHash,
  ) async {
    if (_currentSession == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('USER')
            .doc(user.uid)
            .collection('mining_history')
            .doc(
              '${_currentSession!.sessionId}_pause_${DateTime.now().millisecondsSinceEpoch}',
            )
            .set({
              'sessionId': _currentSession!.sessionId,
              'userId': _currentSession!.userId,
              'deviceId': _currentSession!.deviceId,
              'sessionStart': _currentSession!.sessionStart,
              'sessionEnd': _currentSession!.sessionEnd,
              'type': 'pause_reward',
              'amount': amount,
              'transactionHash': transactionHash,
              'pausedAt': FieldValue.serverTimestamp(),
              'status': 'credited',
              'miningRate': _currentSession!.miningRate,
            });
      }
    } catch (e) {}
  }

  /// Save completed session to history
  Future<void> _saveSessionHistory() async {
    if (_currentSession == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('USER')
            .doc(user.uid)
            .collection('mining_history')
            .doc(_currentSession!.sessionId)
            .set({
              'sessionId': _currentSession!.sessionId,
              'userId': _currentSession!.userId,
              'deviceId': _currentSession!.deviceId,
              'sessionStart': _currentSession!.sessionStart,
              'sessionEnd': _currentSession!.sessionEnd,
              'accumulatedSeconds': _currentSession!.accumulatedSeconds,
              'miningRate': _currentSession!.miningRate,
              'earnedAkofa': _currentSession!.earnedAkofa,
              'completedAt': FieldValue.serverTimestamp(),
              'status': 'completed',
              'finalEarnings': _currentSession!.earnedAkofa,
            });
      }
    } catch (e) {}
  }

  /// Clear persisted session
  Future<void> _clearPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      await prefs.remove(_lastUpdateKey);
    } catch (e) {}
  }

  /// Check if user can receive mining rewards
  Future<Map<String, dynamic>> checkRewardEligibility() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {
          'canReceive': false,
          'reason': 'User not authenticated',
          'details': 'Please log in to receive mining rewards',
        };
      }

      String? publicKey;
      String? walletType = 'unknown';

      // First check for secure/enhanced wallet
      final hasSecureWallet = await SecureWalletService.hasSecureWallet(
        user.uid,
      );
      if (hasSecureWallet) {
        publicKey = await SecureWalletService.getWalletPublicKey(user.uid);
        walletType = 'secure';
      }

      // If no secure wallet, check for regular wallet
      if (publicKey == null) {
        final credentials = await _stellarService.getWalletCredentials();
        if (credentials != null) {
          publicKey = credentials['publicKey'];
          walletType = 'regular';
        }
      }

      // If still no wallet found
      if (publicKey == null) {
        return {
          'canReceive': false,
          'reason': 'No wallet found',
          'details':
              'Please create or import a Stellar wallet to receive mining rewards. Both regular and secure wallets are supported.',
        };
      }

      // Check if account exists
      final accountExists = await _stellarService.checkAccountExists(publicKey);
      if (!accountExists) {
        return {
          'canReceive': false,
          'reason': 'Account not funded',
          'details':
              'Your Stellar account needs to be funded with at least 1 XLM. Use the Stellar testnet faucet to fund your account.',
        };
      }

      // Check AKOFA trustline
      final hasTrustline = await _stellarService.hasAkofaTrustline(publicKey);
      if (!hasTrustline) {
        return {
          'canReceive': false,
          'reason': 'Missing AKOFA trustline',
          'details':
              'Your account needs an AKOFA trustline to receive mining rewards. This is automatically created when you set up your wallet.',
        };
      }

      // Check AKOFA tag
      final userDoc = await FirebaseFirestore.instance
          .collection('USER')
          .doc(user.uid)
          .get();
      if (!userDoc.exists) {
        return {
          'canReceive': false,
          'reason': 'User profile incomplete',
          'details':
              'User profile not found. Please complete your profile setup.',
        };
      }

      final userData = userDoc.data()!;
      final akofaTag = userData['akofaTag'] as String?;
      if (akofaTag == null || akofaTag.isEmpty) {
        return {
          'canReceive': false,
          'reason': 'Missing AKOFA tag',
          'details':
              'Please set your AKOFA tag in your profile to receive mining rewards.',
        };
      }

      return {
        'canReceive': true,
        'reason': 'Eligible for rewards',
        'details':
            'Your ${walletType} wallet is ready to receive mining rewards',
        'walletType': walletType,
        'publicKey': publicKey,
        'akofaTag': akofaTag,
      };
    } catch (e) {
      return {
        'canReceive': false,
        'reason': 'Error checking eligibility',
        'details': 'Error: $e',
      };
    }
  }

  /// Round AKOFA amount to 4 decimal places to avoid Stellar precision errors
  /// Stellar blockchain supports maximum 7 decimal places, but we use 4 for safety
  double _roundAkofaAmount(double amount) {
    if (amount <= 0) return 0.0;

    // Round to 4 decimal places
    final rounded = (amount * 10000).round() / 10000;

    // Ensure minimum amount (0.0001 AKOFA)
    if (rounded < 0.0001 && amount > 0) {
      return 0.0001;
    }

    return rounded;
  }

  /// Calculate mining rate based on user profile
  Future<double> _calculateMiningRate(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('USER')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final referralCount = userData['referralCount'] ?? 0;
        final miningRateBoosted = userData['miningRateBoosted'] ?? false;

        // Base rate: 0.25 AKOFA/hour, boosted: 0.50 AKOFA/hour
        return (referralCount >= 5 || miningRateBoosted) ? 0.50 : 0.25;
      }
    } catch (e) {}

    return 0.25; // Default rate
  }

  /// Dispose resources
  void dispose() {
    _realTimeTimer?.cancel();
    _persistenceTimer?.cancel();
    _sessionStreamController?.close();
  }

  /// Send mining start notification
  Future<void> _sendMiningStartNotification(
    String userId,
    SecureMiningSession session,
  ) async {
    try {
      final userEmail = await _getUserEmail(userId);
      if (userEmail == null) return;

      final preferences =
          await EmailNotificationService.getUserEmailPreferences(userId);
      if (!preferences['miningStart']!) return;

      await EmailNotificationService.sendMiningStartNotification(
        userId: userId,
        userEmail: userEmail,
        miningRate: session.miningRate,
        sessionStart: session.sessionStart,
        sessionEnd: session.sessionEnd,
      );
    } catch (e) {
      // Log error but don't throw
      print('Failed to send mining start notification: $e');
    }
  }

  /// Send mining pause notification
  Future<void> _sendMiningPauseNotification(
    String userId,
    SecureMiningSession session,
  ) async {
    try {
      final userEmail = await _getUserEmail(userId);
      if (userEmail == null) return;

      final preferences =
          await EmailNotificationService.getUserEmailPreferences(userId);
      if (!preferences['miningPause']!) return;

      await EmailNotificationService.sendMiningPauseNotification(
        userId: userId,
        userEmail: userEmail,
        currentEarnings: session.earnedAkofa,
        pausedAt: session.pausedAt ?? DateTime.now(),
      );
    } catch (e) {
      print('Failed to send mining pause notification: $e');
    }
  }

  /// Send mining resume notification
  Future<void> _sendMiningResumeNotification(
    String userId,
    SecureMiningSession session,
  ) async {
    try {
      final userEmail = await _getUserEmail(userId);
      if (userEmail == null) return;

      final preferences =
          await EmailNotificationService.getUserEmailPreferences(userId);
      if (!preferences['miningResume']!) return;

      await EmailNotificationService.sendMiningResumeNotification(
        userId: userId,
        userEmail: userEmail,
        currentEarnings: session.earnedAkofa,
        resumedAt: DateTime.now(),
      );
    } catch (e) {
      print('Failed to send mining resume notification: $e');
    }
  }

  /// Send mining completion notification
  Future<void> _sendMiningCompletionNotification(
    String userId,
    SecureMiningSession session,
  ) async {
    try {
      final userEmail = await _getUserEmail(userId);
      if (userEmail == null) return;

      final preferences =
          await EmailNotificationService.getUserEmailPreferences(userId);
      if (!preferences['miningComplete']!) return;

      final actualDuration = DateTime.now().difference(session.sessionStart);

      await EmailNotificationService.sendMiningCompletionNotification(
        userId: userId,
        userEmail: userEmail,
        earnedAkofa: session.earnedAkofa,
        sessionStart: session.sessionStart,
        sessionEnd: session.sessionEnd,
        actualDuration: actualDuration,
      );
    } catch (e) {
      print('Failed to send mining completion notification: $e');
    }
  }

  /// Get user's email address
  Future<String?> _getUserEmail(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('USER')
          .doc(userId)
          .get();

      final userData = userDoc.data();
      return userData?['email'] as String?;
    } catch (e) {
      return null;
    }
  }
}
