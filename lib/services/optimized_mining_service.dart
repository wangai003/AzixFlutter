import 'dart:async';
import 'dart:convert';
import 'dart:math';
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
import 'advanced_mining_algorithms.dart';

/// Optimized mining service with consolidated functionality and performance improvements
class OptimizedMiningService {
  static const String _sessionKey = 'optimized_mining_session_v2';
  static const String _deviceIdKey = 'mining_device_id';
  static const String _lastSyncKey = 'last_mining_sync';

  // Consolidated timer management
  Timer? _mainUpdateTimer;
  Timer? _persistenceTimer;
  Timer? _securityTimer;
  Timer? _backgroundTimer;

  // Adaptive timing intervals (in seconds)
  static const int _activeUpdateInterval = 5; // 5 seconds when active
  static const int _inactiveUpdateInterval = 30; // 30 seconds when inactive
  static const int _persistenceInterval = 60; // 1 minute persistence
  static const int _securityInterval = 300; // 5 minutes security checks
  static const int _backgroundInterval = 600; // 10 minutes background sync

  // Resource management
  final StreamController<SecureMiningSession?> _sessionController =
      StreamController<SecureMiningSession?>.broadcast();
  final Map<String, dynamic> _cache = {};
  bool _isBackgrounded = false;
  bool _isDisposed = false;

  // Dependencies
  final StellarService _stellarService;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // Advanced mining algorithms
  final AdvancedMiningAlgorithms _miningAlgorithms = AdvancedMiningAlgorithms();

  // Current state
  SecureMiningSession? _currentSession;
  String? _deviceId;
  DateTime? _lastPersistenceSave;
  DateTime? _lastSecurityCheck;

  /// Stream of session updates
  Stream<SecureMiningSession?> get sessionStream => _sessionController.stream;

  /// Current session
  SecureMiningSession? get currentSession => _currentSession;

  /// Constructor
  OptimizedMiningService({
    required StellarService stellarService,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _stellarService = stellarService,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  /// Initialize the optimized service
  Future<void> initialize() async {
    if (_isDisposed) return;

    await _initializeDeviceId();
    await _restoreSession();
    _startAdaptiveTimer();
    _startPersistenceTimer();
    _startSecurityTimer();
  }

  /// Initialize device ID for security
  Future<void> _initializeDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_deviceIdKey);

    if (_deviceId == null) {
      final deviceInfo = DeviceInfoPlugin();
      String deviceIdentifier;

      try {
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceIdentifier = androidInfo.id;
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceIdentifier = iosInfo.identifierForVendor ?? 'unknown_ios';
        } else {
          deviceIdentifier =
              'web_device_${DateTime.now().millisecondsSinceEpoch}';
        }
      } catch (e) {
        deviceIdentifier = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
      }

      _deviceId = _generateSecureDeviceId(deviceIdentifier);
      await prefs.setString(_deviceIdKey, _deviceId!);
    }
  }

  /// Generate secure device ID
  String _generateSecureDeviceId(String baseId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final input = '$baseId:$timestamp:${Random.secure().nextInt(999999)}';
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString().substring(0, 32);
  }

  /// Start adaptive timer that adjusts based on mining state
  void _startAdaptiveTimer() {
    _mainUpdateTimer?.cancel();

    final interval = _currentSession?.isActive == true && !_isBackgrounded
        ? _activeUpdateInterval
        : _inactiveUpdateInterval;

    _mainUpdateTimer = Timer.periodic(
      Duration(seconds: interval),
      (_) => _adaptiveUpdate(),
    );
  }

  /// Adaptive update based on current state
  Future<void> _adaptiveUpdate() async {
    if (_isDisposed || _currentSession == null) return;

    final now = DateTime.now();

    // Update session progress
    if (_currentSession!.isActive && !_currentSession!.isPaused) {
      final elapsedTime = now.difference(_currentSession!.lastResume).inSeconds;
      _currentSession!.accumulatedSeconds = elapsedTime;

      // Auto-submit proof every 5 minutes (optimized from every minute)
      final lastProofAge = now
          .difference(_currentSession!.lastProofSubmission)
          .inMinutes;
      if (lastProofAge >= 5) {
        _submitMiningProof();
      }

      // Emit update to UI
      _sessionController.add(_currentSession);
    }

    // Check if session expired
    if (now.isAfter(_currentSession!.sessionEnd)) {
      await endSession();
    }
  }

  /// Start persistence timer (less frequent saves)
  void _startPersistenceTimer() {
    _persistenceTimer?.cancel();
    _persistenceTimer = Timer.periodic(
      const Duration(seconds: _persistenceInterval),
      (_) => _optimizedPersistSession(),
    );
  }

  /// Optimized persistence with batching and caching
  Future<void> _optimizedPersistSession() async {
    if (_isDisposed || _currentSession == null) return;

    final now = DateTime.now();

    // Skip if recently saved and no significant changes
    if (_lastPersistenceSave != null &&
        now.difference(_lastPersistenceSave!).inSeconds < 30) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // Cache session data to avoid repeated serialization
      final sessionData = _cache['sessionData'] ??= _serializeSession(
        _currentSession!,
      );
      await prefs.setString(_sessionKey, sessionData);
      await prefs.setString(_lastSyncKey, now.toIso8601String());

      // Batch Firestore operations
      await _batchFirestoreOperations();

      _lastPersistenceSave = now;
    } catch (e) {
      // Log error but don't throw
      debugPrint('Persistence error: $e');
    }
  }

  /// Batch Firestore operations for efficiency
  Future<void> _batchFirestoreOperations() async {
    if (_currentSession == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final batch = _firestore.batch();

    // Update active session
    final sessionRef = _firestore
        .collection('USER')
        .doc(user.uid)
        .collection('active_mining_sessions')
        .doc(_currentSession!.sessionId);

    batch.set(sessionRef, {
      'sessionId': _currentSession!.sessionId,
      'userId': _currentSession!.userId,
      'deviceId': _currentSession!.deviceId,
      'sessionStart': _currentSession!.sessionStart,
      'sessionEnd': _currentSession!.sessionEnd,
      'isPaused': _currentSession!.isPaused,
      'lastResume': _currentSession!.lastResume,
      'accumulatedSeconds': _currentSession!.accumulatedSeconds,
      'miningRate': _currentSession!.miningRate,
      'earnedAkofa': _currentSession!.earnedAkofa,
      'totalProofsSubmitted': _currentSession!.totalProofsSubmitted,
      'lastProofSubmission': _currentSession!.lastProofSubmission,
      'lastSynced': FieldValue.serverTimestamp(),
      'realTimeUpdate': true,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// Start security timer (consolidated security checks)
  void _startSecurityTimer() {
    _securityTimer?.cancel();
    _securityTimer = Timer.periodic(
      const Duration(seconds: _securityInterval),
      (_) => _consolidatedSecurityCheck(),
    );
  }

  /// Consolidated security checks (rate limiting, fraud detection, validation)
  Future<void> _consolidatedSecurityCheck() async {
    if (_isDisposed || _currentSession == null) return;

    final now = DateTime.now();

    // Skip if recently checked
    if (_lastSecurityCheck != null &&
        now.difference(_lastSecurityCheck!).inMinutes < 4) {
      return;
    }

    try {
      await _validateSessionIntegrity();
      await _checkRateLimits();
      await _detectFraudPatterns();

      _lastSecurityCheck = now;
    } catch (e) {
      debugPrint('Security check error: $e');
    }
  }

  /// Validate session integrity
  Future<void> _validateSessionIntegrity() async {
    if (_currentSession == null) return;

    // Check proof frequency (should submit proof at least every 10 minutes)
    final now = DateTime.now();
    if (!_currentSession!.isPaused &&
        now.difference(_currentSession!.lastProofSubmission).inMinutes > 10) {
      // Flag as suspicious but don't terminate immediately
      debugPrint('Warning: Low proof frequency detected');
    }

    // Validate accumulated time doesn't exceed session duration
    final maxPossibleSeconds = now
        .difference(_currentSession!.sessionStart)
        .inSeconds;
    if (_currentSession!.accumulatedSeconds > maxPossibleSeconds + 60) {
      // 1 minute tolerance
      debugPrint('Warning: Accumulated time exceeds session duration');
    }
  }

  /// Check rate limits (consolidated from MiningSecurityService)
  Future<void> _checkRateLimits() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Simplified rate limiting - check recent attempts
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));

    try {
      final attempts = await _firestore
          .collection('mining_attempts')
          .doc(user.uid)
          .collection('attempts')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(oneHourAgo))
          .get();

      if (attempts.docs.length > 3) {
        // Max 3 attempts per hour
        debugPrint(
          'Rate limit warning: ${attempts.docs.length} attempts in last hour',
        );
      }
    } catch (e) {
      // Continue if rate limit check fails
    }
  }

  /// Detect fraud patterns (simplified)
  Future<void> _detectFraudPatterns() async {
    if (_currentSession == null) return;

    // Check for suspicious timing patterns
    final proofs = _currentSession!.proofs;
    if (proofs.isNotEmpty && proofs.length >= 3) {
      var exactHourEndings = 0;
      for (final proof in proofs) {
        if (proof.timestamp.minute == 0 && proof.timestamp.second == 0) {
          exactHourEndings++;
        }
      }

      if (exactHourEndings > proofs.length * 0.8) {
        debugPrint('Fraud warning: Suspicious timing pattern detected');
      }
    }
  }

  /// Submit mining proof with advanced algorithms
  Future<void> _submitMiningProof() async {
    if (_currentSession == null ||
        !_currentSession!.isActive ||
        _currentSession!.isPaused) {
      return;
    }

    final now = DateTime.now();
    final timeSinceResume = now
        .difference(_currentSession!.lastResume)
        .inSeconds;

    // Update accumulated time
    _currentSession!.accumulatedSeconds = timeSinceResume;
    _currentSession!.lastResume = now;

    try {
      // Get current difficulty from advanced algorithms
      final currentDifficulty = _miningAlgorithms.adjustDifficulty();

      // Generate challenge for this proof
      final challenge = _currentSession!.getCurrentChallenge();

      // Mine with advanced algorithm
      final miningResult = await _miningAlgorithms.mineAdvanced(
        sessionId: _currentSession!.sessionId,
        challenge: challenge,
        targetDifficulty: currentDifficulty,
        timeout: const Duration(seconds: 10), // Limit mining time
      );

      if (miningResult.success && miningResult.nonce != null) {
        // Submit proof with advanced nonce
        _currentSession!.submitAdvancedProof(
          'auto_update',
          timeSinceResume,
          miningResult.nonce!,
          miningResult.hash!,
          currentDifficulty,
        );

        // Record performance metrics
        _miningAlgorithms.recordBlockTime(timeSinceResume);

        // Cache proof data with performance metrics
        _cache['lastProof'] = {
          'timestamp': now,
          'seconds': timeSinceResume,
          'proofsCount': _currentSession!.totalProofsSubmitted,
          'difficulty': currentDifficulty,
          'hashrate': miningResult.hashrate,
          'iterations': miningResult.iterations,
        };

        debugPrint(
          'Advanced proof submitted: difficulty=$currentDifficulty, hashrate=${miningResult.hashrate.toStringAsFixed(2)} H/s',
        );
      } else {
        // Fallback to simple proof if advanced mining fails
        debugPrint('Advanced mining failed, using fallback proof');
        _currentSession!.submitProof('auto_update_fallback', timeSinceResume);
      }
    } catch (e) {
      // Fallback to simple proof on error
      debugPrint('Advanced mining error: $e, using fallback');
      _currentSession!.submitProof('auto_update_fallback', timeSinceResume);
    }
  }

  /// Start mining session
  Future<SecureMiningSession?> startSession({
    required String userId,
    required String deviceId,
  }) async {
    // Check for existing active session
    final existingSession = await _checkForExistingActiveSession(userId);
    if (existingSession != null) {
      _currentSession = existingSession;
      _sessionController.add(_currentSession);
      return _currentSession;
    }

    // Validate mining start (consolidated security checks)
    final canStart = await _canStartNewSession(userId);
    if (!canStart) {
      throw Exception('Cannot start new mining session');
    }

    final miningRate = await _calculateMiningRate(userId);

    _currentSession = SecureMiningSession.newSession(
      userId: userId,
      deviceId: deviceId,
      miningRate: miningRate,
    );

    // Start adaptive timer immediately
    _startAdaptiveTimer();

    // Persist session
    await _optimizedPersistSession();
    _sessionController.add(_currentSession);

    // Send notification
    await _sendMiningStartNotification(userId, _currentSession!);

    return _currentSession;
  }

  /// Check for existing active session
  Future<SecureMiningSession?> _checkForExistingActiveSession(
    String userId,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final activeSessionsQuery = await _firestore
          .collection('USER')
          .doc(user.uid)
          .collection('active_mining_sessions')
          .where('sessionEnd', isGreaterThan: DateTime.now())
          .limit(1)
          .get();

      if (activeSessionsQuery.docs.isNotEmpty) {
        final doc = activeSessionsQuery.docs.first;
        final data = doc.data();

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

  /// Check if user can start new session (consolidated validation)
  Future<bool> _canStartNewSession(String userId) async {
    try {
      // Check for active sessions
      final activeSessions = await _firestore
          .collection('secure_mining_sessions')
          .where('userId', isEqualTo: userId)
          .where('deviceId', isEqualTo: _deviceId)
          .where('sessionEnd', isGreaterThan: Timestamp.now())
          .get();

      if (activeSessions.docs.isNotEmpty) {
        return false;
      }

      // Check daily session limit
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final todaySessions = await _firestore
          .collection('secure_mining_sessions')
          .where('userId', isEqualTo: userId)
          .where('deviceId', isEqualTo: _deviceId)
          .where(
            'sessionStart',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .get();

      return todaySessions.docs.length < 1; // Max 1 session per day
    } catch (e) {
      return false;
    }
  }

  /// Pause mining session
  Future<void> pauseSession() async {
    if (_currentSession == null ||
        !_currentSession!.isActive ||
        _currentSession!.isPaused) {
      return;
    }

    // Update progress before pausing
    await _adaptiveUpdate();

    // Get earned amount before pausing
    final earnedBeforePause = _currentSession!.earnedAkofa;

    if (earnedBeforePause > 0) {
      try {
        final roundedAmount = _roundAkofaAmount(earnedBeforePause);

        final result = await _stellarService.recordMiningReward(roundedAmount);

        if (result['success'] == true) {
          await _recordPauseReward(roundedAmount, result['hash']);
        }
      } catch (e) {
        debugPrint('Pause reward error: $e');
      }
    }

    // Pause session
    _currentSession!.isPaused = true;
    _currentSession!.pausedAt = DateTime.now();

    // Adjust timer for paused state
    _startAdaptiveTimer();

    await _optimizedPersistSession();
    _sessionController.add(_currentSession);

    await _sendMiningPauseNotification(
      _currentSession!.userId,
      _currentSession!,
    );
  }

  /// Resume mining session
  Future<void> resumeSession() async {
    if (_currentSession == null || !_currentSession!.isPaused) {
      return;
    }

    final now = DateTime.now();
    _currentSession!.isPaused = false;
    _currentSession!.lastResume = now;
    _currentSession!.pausedAt = null;

    // Adjust timer for active state
    _startAdaptiveTimer();

    await _optimizedPersistSession();
    _sessionController.add(_currentSession);

    await _sendMiningResumeNotification(
      _currentSession!.userId,
      _currentSession!,
    );
  }

  /// End mining session
  Future<double> endSession() async {
    if (_currentSession == null) return 0.0;

    // Final update
    await _adaptiveUpdate();

    final earnedAkofa = _currentSession!.earnedAkofa;

    // Mark as completed
    _currentSession!.isPaused = true;

    await _optimizedPersistSession();
    await _saveSessionHistory();

    // Process final reward
    if (earnedAkofa > 0) {
      try {
        final roundedAmount = _roundAkofaAmount(earnedAkofa);
        final result = await _stellarService.recordMiningReward(roundedAmount);

        if (result['success'] == true) {
          debugPrint('Final reward credited: $roundedAmount AKOFA');
        }
      } catch (e) {
        debugPrint('Final reward error: $e');
      }
    }

    // Send completion notification
    await _sendMiningCompletionNotification(
      _currentSession!.userId,
      _currentSession!,
    );

    // Clear session
    _currentSession = null;
    await _clearPersistedSession();
    _sessionController.add(null);

    return earnedAkofa;
  }

  /// Restore session from storage
  Future<void> _restoreSession() async {
    try {
      // Try Firestore first (cross-device sync)
      final restoredFromServer = await _restoreFromFirestore();
      if (restoredFromServer) return;

      // Fallback to local storage
      final prefs = await SharedPreferences.getInstance();
      final sessionData = prefs.getString(_sessionKey);

      if (sessionData != null) {
        final sessionMap = json.decode(sessionData) as Map<String, dynamic>;

        _currentSession = SecureMiningSession(
          sessionId: sessionMap['sessionId'],
          sessionStart: DateTime.parse(sessionMap['sessionStart']),
          sessionEnd: DateTime.parse(sessionMap['sessionEnd']),
          userId: sessionMap['userId'],
          deviceId: sessionMap['deviceId'],
          miningRate: (sessionMap['miningRate'] as num).toDouble(),
          initialChallenge: sessionMap['initialChallenge'] ?? 'restored',
          proofs: [],
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
          final currentCycleElapsed = now
              .difference(_currentSession!.lastResume)
              .inSeconds;
          _currentSession!.accumulatedSeconds = currentCycleElapsed;

          await _batchFirestoreOperations();
          _sessionController.add(_currentSession);
        } else if (now.isAfter(_currentSession!.sessionEnd)) {
          await endSession();
        }
      }
    } catch (e) {
      debugPrint('Session restore error: $e');
      await _clearPersistedSession();
    }
  }

  /// Restore from Firestore
  Future<bool> _restoreFromFirestore() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final activeSessionsQuery = await _firestore
          .collection('USER')
          .doc(user.uid)
          .collection('active_mining_sessions')
          .where('sessionEnd', isGreaterThan: DateTime.now())
          .orderBy('sessionEnd', descending: true)
          .limit(1)
          .get();

      if (activeSessionsQuery.docs.isNotEmpty) {
        final doc = activeSessionsQuery.docs.first;
        final data = doc.data();

        _currentSession = SecureMiningSession(
          sessionId: data['sessionId'] ?? doc.id,
          sessionStart: (data['sessionStart'] as Timestamp).toDate(),
          sessionEnd: (data['sessionEnd'] as Timestamp).toDate(),
          userId: data['userId'] ?? user.uid,
          deviceId: data['deviceId'] ?? 'unknown_device',
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

        // Calculate current elapsed time
        final now = DateTime.now();
        if (!_currentSession!.isPaused) {
          final currentCycleElapsed = now
              .difference(_currentSession!.lastResume)
              .inSeconds;
          _currentSession!.accumulatedSeconds = currentCycleElapsed;
        }

        await _optimizedPersistSession();
        _sessionController.add(_currentSession);

        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Handle app background/foreground transitions
  void handleAppLifecycleChange(bool isBackgrounded) {
    _isBackgrounded = isBackgrounded;

    if (isBackgrounded) {
      // Reduce timer frequency when backgrounded
      _startAdaptiveTimer();
      _startBackgroundTimer();
    } else {
      // Resume normal frequency when foregrounded
      _backgroundTimer?.cancel();
      _startAdaptiveTimer();
    }
  }

  /// Start background timer for minimal sync
  void _startBackgroundTimer() {
    _backgroundTimer?.cancel();
    _backgroundTimer = Timer.periodic(
      const Duration(seconds: _backgroundInterval),
      (_) => _backgroundSync(),
    );
  }

  /// Background sync (minimal operations)
  Future<void> _backgroundSync() async {
    if (_isDisposed || _currentSession == null) return;

    // Only persist if there are significant changes
    final now = DateTime.now();
    if (_lastPersistenceSave == null ||
        now.difference(_lastPersistenceSave!).inMinutes >= 5) {
      await _optimizedPersistSession();
    }
  }

  /// Serialize session for caching
  String _serializeSession(SecureMiningSession session) {
    return json.encode({
      'sessionId': session.sessionId,
      'userId': session.userId,
      'deviceId': session.deviceId,
      'sessionStart': session.sessionStart.toIso8601String(),
      'sessionEnd': session.sessionEnd.toIso8601String(),
      'isPaused': session.isPaused,
      'pausedAt': session.pausedAt?.toIso8601String(),
      'lastResume': session.lastResume.toIso8601String(),
      'accumulatedSeconds': session.accumulatedSeconds,
      'totalProofsSubmitted': session.totalProofsSubmitted,
      'lastProofSubmission': session.lastProofSubmission.toIso8601String(),
      'miningRate': session.miningRate,
      'initialChallenge': session.initialChallenge,
      'sessionHash': session.sessionHash,
    });
  }

  /// Calculate mining rate
  Future<double> _calculateMiningRate(String userId) async {
    try {
      final userDoc = await _firestore.collection('USER').doc(userId).get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final referralCount = userData['referralCount'] ?? 0;
        final miningRateBoosted = userData['miningRateBoosted'] ?? false;

        return (referralCount >= 5 || miningRateBoosted) ? 0.50 : 0.25;
      }
    } catch (e) {
      debugPrint('Mining rate calculation error: $e');
    }

    return 0.25;
  }

  /// Round AKOFA amount
  double _roundAkofaAmount(double amount) {
    if (amount <= 0) return 0.0;
    final rounded = (amount * 10000).round() / 10000;
    return rounded < 0.0001 && amount > 0 ? 0.0001 : rounded;
  }

  /// Record pause reward
  Future<void> _recordPauseReward(
    double amount,
    String? transactionHash,
  ) async {
    if (_currentSession == null) return;

    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
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
              'type': 'pause_reward',
              'amount': amount,
              'transactionHash': transactionHash,
              'pausedAt': FieldValue.serverTimestamp(),
              'status': 'credited',
              'miningRate': _currentSession!.miningRate,
            });
      }
    } catch (e) {
      debugPrint('Pause reward recording error: $e');
    }
  }

  /// Save session history
  Future<void> _saveSessionHistory() async {
    if (_currentSession == null) return;

    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
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
    } catch (e) {
      debugPrint('Session history save error: $e');
    }
  }

  /// Clear persisted session
  Future<void> _clearPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      await prefs.remove(_lastSyncKey);
      _cache.clear();
    } catch (e) {
      debugPrint('Clear session error: $e');
    }
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
      debugPrint('Mining start notification error: $e');
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
      debugPrint('Mining pause notification error: $e');
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
      debugPrint('Mining resume notification error: $e');
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
      debugPrint('Mining completion notification error: $e');
    }
  }

  /// Get user email
  Future<String?> _getUserEmail(String userId) async {
    try {
      final userDoc = await _firestore.collection('USER').doc(userId).get();
      return userDoc.data()?['email'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Get mining performance statistics
  MiningStats getMiningStats() {
    return _miningAlgorithms.getMiningStats();
  }

  /// Benchmark mining performance
  Future<MiningBenchmark> benchmarkMining({
    int testDurationSeconds = 10,
    int difficulty = 8,
  }) {
    final sessionId = 'benchmark_${DateTime.now().millisecondsSinceEpoch}';
    final challenge = _generateBenchmarkChallenge();

    return _miningAlgorithms.benchmarkMining(
      testDurationSeconds: testDurationSeconds,
      difficulty: difficulty,
    );
  }

  /// Generate benchmark challenge
  String _generateBenchmarkChallenge() {
    final random = Random.secure();
    final bytes = List.generate(32, (_) => random.nextInt(256));
    return sha256.convert(bytes).toString();
  }

  /// Get optimal difficulty for current performance
  Future<int> getOptimalDifficulty() async {
    return await _miningAlgorithms.getOptimalDifficulty(
      targetTime: const Duration(seconds: 10),
    );
  }

  /// Dispose resources
  void dispose() {
    _isDisposed = true;

    _mainUpdateTimer?.cancel();
    _persistenceTimer?.cancel();
    _securityTimer?.cancel();
    _backgroundTimer?.cancel();

    _sessionController.close();
    _cache.clear();
  }
}
