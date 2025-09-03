import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/secure_mining_session.dart';
import 'stellar_service.dart';

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
    _sessionStreamController ??= StreamController<SecureMiningSession>.broadcast();
    return _sessionStreamController!.stream;
  }
  
  /// Constructor
  RealTimeMiningService(this._stellarService);

  /// Initialize the service
  Future<void> initialize() async {
    await _restoreSession();
    _startRealTimeTracking();
    _startPersistenceTimer();
    print('🚀 Real-time mining service initialized');
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
    if (_currentSession == null || !_currentSession!.isActive || _currentSession!.isPaused) {
      return;
    }
    
    final now = DateTime.now();
    
    // Check if session expired
    if (now.isAfter(_currentSession!.sessionEnd)) {
      await _endSession();
      return;
    }
    
    // Calculate elapsed time since last resume (for current earnings cycle)
    final elapsedTimeSinceResume = now.difference(_currentSession!.lastResume).inSeconds;
    
    // Update accumulated seconds for current earnings cycle
    _currentSession!.accumulatedSeconds = elapsedTimeSinceResume;
    
    // Auto-submit proof every 5 minutes to ensure earnings calculation works
    final lastProofAge = now.difference(_currentSession!.lastProofSubmission).inMinutes;
    if (lastProofAge >= 5) {
      _currentSession!.submitProof('auto_update', elapsedTimeSinceResume);
      print('🔐 Auto-submitted proof for real-time earnings calculation');
    }
    
    // Emit updated session
    _sessionStreamController?.add(_currentSession!);
    
    // Debug: Show real-time progress
    if (elapsedTimeSinceResume % 10 == 0) { // Log every 10 seconds to avoid spam
      final totalSessionElapsed = now.difference(_currentSession!.sessionStart).inSeconds;
      final totalSessionRemaining = (24 * 3600 - totalSessionElapsed) / 3600;
      final currentCycleEarnings = _currentSession!.earnedAkofa;
      print('⏱️ Real-time update: Current cycle ${(elapsedTimeSinceResume / 3600).toStringAsFixed(2)}h, Total session ${(totalSessionElapsed / 3600).toStringAsFixed(2)}h, ${totalSessionRemaining.toStringAsFixed(2)}h remaining, ${currentCycleEarnings.toStringAsFixed(6)} AKOFA earned this cycle');
    }
  }
  
  /// Start a new mining session
  Future<SecureMiningSession> startSession(String userId, String deviceId) async {
    // Check if there's already an active session for this user
    final existingSession = await _checkForExistingActiveSession(userId);
    if (existingSession != null) {
      print('⚠️ Active mining session already exists: ${existingSession.sessionId}');
      print('🔄 Continuing existing session instead of starting new one');
      
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
    
    print('⛏️ New mining session started: ${_currentSession!.sessionId}');
    return _currentSession!;
  }
  
  /// Check for existing active mining session
  Future<SecureMiningSession?> _checkForExistingActiveSession(String userId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      
      final activeSessionsQuery = await FirebaseFirestore.instance
          .collection('USER')
          .doc(user.uid)
          .collection('active_mining_sessions')
          .where('isPaused', isEqualTo: false)
          .where('sessionEnd', isGreaterThan: DateTime.now())
          .limit(1)
          .get();
      
      if (activeSessionsQuery.docs.isNotEmpty) {
        final doc = activeSessionsQuery.docs.first;
        final data = doc.data();
        
        // Reconstruct session from server data
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
          pausedAt: data['pausedAt'] != null ? (data['pausedAt'] as Timestamp).toDate() : null,
          lastResume: data['lastResume'] != null ? (data['lastResume'] as Timestamp).toDate() : DateTime.now(),
          accumulatedSeconds: data['accumulatedSeconds'] ?? 0,
          totalProofsSubmitted: data['totalProofsSubmitted'] ?? 0,
          lastProofSubmission: data['lastProofSubmission'] != null ? (data['lastProofSubmission'] as Timestamp).toDate() : DateTime.now(),
        );
      }
      
      return null;
    } catch (e) {
      print('❌ Error checking for existing session: $e');
      return null;
    }
  }
  
  /// Pause mining session and credit earned tokens
  Future<void> pauseSession() async {
    if (_currentSession == null || !_currentSession!.isActive || _currentSession!.isPaused) {
      return;
    }
    
    // Update real-time progress before pausing
    await _updateRealTimeProgress();
    
    // Get the current earned amount before pausing
    final earnedBeforePause = _currentSession!.earnedAkofa;
    
    if (earnedBeforePause > 0) {
      try {
        // Round to 4 decimal places to avoid Stellar precision errors
        final roundedAmount = _roundAkofaAmount(earnedBeforePause);
        
        if (roundedAmount != earnedBeforePause) {
          print('🔢 Amount rounded from ${earnedBeforePause.toStringAsFixed(6)} to ${roundedAmount.toStringAsFixed(4)} AKOFA for blockchain compatibility');
        }
        
        print('💰 Pausing mining session - crediting ${roundedAmount.toStringAsFixed(4)} AKOFA to wallet');
        
        // Credit the rounded amount to the user's wallet
        final result = await _stellarService.recordMiningReward(roundedAmount);
        
        if (result['success'] == true) {
          print('✅ Mining reward credited successfully: ${roundedAmount.toStringAsFixed(4)} AKOFA');
          print('🔗 Transaction hash: ${result['hash']}');
          
          // Record this pause reward in session history
          await _recordPauseReward(roundedAmount, result['hash']);
        } else {
          print('❌ Failed to credit mining reward: ${result['message']}');
        }
      } catch (e) {
        print('❌ Error crediting mining reward on pause: $e');
      }
    }
    
    // Pause the session
    _currentSession!.isPaused = true;
    _currentSession!.pausedAt = DateTime.now();
    
    // Reset earnings counter for next resume cycle
    _currentSession!.accumulatedSeconds = 0;
    
    await _persistSession();
    _sessionStreamController?.add(_currentSession!);
    
    print('⏸️ Mining session paused. Earned ${earnedBeforePause.toStringAsFixed(6)} AKOFA credited to wallet');
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
    
    print('▶️ Mining session resumed. New earnings cycle started (0 AKOFA)');
    print('⏱️ Session will continue until ${_currentSession!.sessionEnd.toString()}');
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
        
        if (roundedAmount != earnedAkofa) {
          print('🔢 Final amount rounded from ${earnedAkofa.toStringAsFixed(6)} to ${roundedAmount.toStringAsFixed(4)} AKOFA for blockchain compatibility');
        }
        
        print('💰 Processing final mining reward: ${roundedAmount.toStringAsFixed(4)} AKOFA');
        
        final result = await _stellarService.recordMiningReward(roundedAmount);
        
        if (result['success'] == true) {
          print('✅ Final mining reward successfully credited to wallet: ${roundedAmount.toStringAsFixed(4)} AKOFA');
          print('🔗 Transaction hash: ${result['hash']}');
        } else {
          print('❌ Failed to credit final mining reward: ${result['message']}');
        }
      } catch (e) {
        print('❌ Error processing final mining reward: $e');
      }
    }
    
    // Clear current session
    _currentSession = null;
    await _clearPersistedSession();
    
    print('🏁 24-hour mining session completed. Final earnings: ${earnedAkofa.toStringAsFixed(6)} AKOFA (credited: ${_roundAkofaAmount(earnedAkofa).toStringAsFixed(4)} AKOFA)');
    return earnedAkofa;
  }
  
  /// Get current session
  SecureMiningSession? getCurrentSession() {
    return _currentSession;
  }
  
  /// Restore session from storage and cross-device sync
  Future<void> _restoreSession() async {
    try {
      // FIRST: Try to restore from Firestore (cross-device sync)
      final restoredFromServer = await _restoreFromFirestore();
      
      if (restoredFromServer) {
        print('🔄 Session restored from server (cross-device sync)');
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
          pausedAt: sessionMap['pausedAt'] != null ? DateTime.parse(sessionMap['pausedAt']) : null,
          lastResume: sessionMap['lastResume'] != null ? DateTime.parse(sessionMap['lastResume']) : DateTime.now(),
          accumulatedSeconds: sessionMap['accumulatedSeconds'] ?? 0,
          totalProofsSubmitted: sessionMap['totalProofsSubmitted'] ?? 0,
          lastProofSubmission: sessionMap['lastProofSubmission'] != null ? DateTime.parse(sessionMap['lastProofSubmission']) : DateTime.now(),
        );
        
        final now = DateTime.now();
        
        // Check if session is still valid
        if (_currentSession!.isActive && now.isBefore(_currentSession!.sessionEnd)) {
          // Calculate total elapsed time since session start (for session progress)
          final totalSessionElapsed = now.difference(_currentSession!.sessionStart).inSeconds;
          
          // For earnings, use time since last resume (current cycle)
          final currentCycleElapsed = now.difference(_currentSession!.lastResume).inSeconds;
          _currentSession!.accumulatedSeconds = currentCycleElapsed;
          
          print('⏱️ Restored session from local storage. Session: ${(totalSessionElapsed / 3600).toStringAsFixed(2)}h total, Current cycle: ${(currentCycleElapsed / 3600).toStringAsFixed(2)}h');
          
          // Sync this local session to server for other devices
          await _saveToFirestore();
          
          final elapsedHours = _currentSession!.accumulatedSeconds / 3600.0;
          final remainingHours = 24.0 - elapsedHours;
          print('🔄 Local session restored: ${elapsedHours.toStringAsFixed(2)}h elapsed, ${remainingHours.toStringAsFixed(2)}h remaining, ${_currentSession!.earnedAkofa.toStringAsFixed(6)} AKOFA earned');
          _sessionStreamController?.add(_currentSession!);
        } else if (now.isAfter(_currentSession!.sessionEnd)) {
          // Session expired while app was closed
          print('⏰ Session expired while app was closed, processing rewards');
          await _endSession();
        } else {
          // Invalid session
          await _clearPersistedSession();
        }
      }
    } catch (e) {
      print('❌ Error restoring mining session: $e');
      await _clearPersistedSession();
    }
  }
  
  /// Restore session from Firestore for cross-device sync
  Future<bool> _restoreFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      
      // Check for any active mining session for this user
      final activeSessionsQuery = await FirebaseFirestore.instance
          .collection('USER')
          .doc(user.uid)
          .collection('active_mining_sessions')
          .where('isPaused', isEqualTo: false)
          .where('sessionEnd', isGreaterThan: DateTime.now())
          .limit(1)
          .get();
      
      if (activeSessionsQuery.docs.isNotEmpty) {
        final doc = activeSessionsQuery.docs.first;
        final data = doc.data();
        
        // Check if this session is from a different device
        final serverDeviceId = data['deviceId'] as String?;
        final currentDeviceId = await _getCurrentDeviceId();
        
        if (serverDeviceId != null && serverDeviceId != currentDeviceId) {
          print('🔄 Found active mining session from different device: $serverDeviceId');
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
          pausedAt: data['pausedAt'] != null ? (data['pausedAt'] as Timestamp).toDate() : null,
          lastResume: data['lastResume'] != null ? (data['lastResume'] as Timestamp).toDate() : DateTime.now(),
          accumulatedSeconds: data['accumulatedSeconds'] ?? 0,
          totalProofsSubmitted: data['totalProofsSubmitted'] ?? 0,
          lastProofSubmission: data['lastProofSubmission'] != null ? (data['lastProofSubmission'] as Timestamp).toDate() : DateTime.now(),
        );
        
        // Note: deviceId is final, so we can't change it after creation
        // The session will continue with the original device ID for tracking purposes
        
        // Calculate current elapsed time for earnings cycle
        final now = DateTime.now();
        final currentCycleElapsed = now.difference(_currentSession!.lastResume).inSeconds;
        _currentSession!.accumulatedSeconds = currentCycleElapsed;
        
        // Save to local storage for this device
        await _persistSession();
        
        print('🔄 Session restored from server. Current cycle: ${(currentCycleElapsed / 3600).toStringAsFixed(2)}h, ${_currentSession!.earnedAkofa.toStringAsFixed(6)} AKOFA earned this cycle');
        _sessionStreamController?.add(_currentSession!);
        
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ Error restoring from Firestore: $e');
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
      // For web, use a combination of user agent and screen resolution
      // Note: html package not available, using a simpler approach
      return '${platform}_web_browser';
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
        'lastProofSubmission': _currentSession!.lastProofSubmission.toIso8601String(),
        'miningRate': _currentSession!.miningRate,
        'initialChallenge': _currentSession!.initialChallenge,
        'sessionHash': _currentSession!.sessionHash,
        'serverValidationHash': _currentSession!.serverValidationHash,
      };
      await prefs.setString(_sessionKey, json.encode(sessionInfo));
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
      
      final currentCycleHours = _currentSession!.accumulatedSeconds / 3600.0;
      final totalSessionElapsed = now.difference(_currentSession!.sessionStart).inSeconds / 3600.0;
      final totalSessionRemaining = 24.0 - totalSessionElapsed;
      print('💾 Session persisted: Current cycle ${currentCycleHours.toStringAsFixed(2)}h, Total session ${totalSessionElapsed.toStringAsFixed(2)}h, ${totalSessionRemaining.toStringAsFixed(2)}h remaining, ${_currentSession!.earnedAkofa.toStringAsFixed(6)} AKOFA earned this cycle');
      
      // Also save to Firestore for cross-device sync
      await _saveToFirestore();
      
    } catch (e) {
      print('❌ Error persisting session: $e');
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
        
        print('💾 Session synced to Firestore for cross-device access');
      }
    } catch (e) {
      print('❌ Error saving to Firestore: $e');
    }
  }
  
  /// Record pause reward in session history
  Future<void> _recordPauseReward(double amount, String? transactionHash) async {
    if (_currentSession == null) return;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('USER')
            .doc(user.uid)
            .collection('mining_history')
            .doc('${_currentSession!.sessionId}_pause_${DateTime.now().millisecondsSinceEpoch}')
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
        
        print('📝 Pause reward recorded in history: ${amount.toStringAsFixed(6)} AKOFA');
      }
    } catch (e) {
      print('❌ Error recording pause reward: $e');
    }
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
    } catch (e) {
      print('❌ Error saving session history: $e');
    }
  }
  
  /// Clear persisted session
  Future<void> _clearPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      await prefs.remove(_lastUpdateKey);
    } catch (e) {
      print('❌ Error clearing persisted session: $e');
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
    } catch (e) {
      print('❌ Error calculating mining rate: $e');
    }
    
    return 0.25; // Default rate
  }
  
  /// Dispose resources
  void dispose() {
    _realTimeTimer?.cancel();
    _persistenceTimer?.cancel();
    _sessionStreamController?.close();
    print('🔄 Real-time mining service disposed');
  }
}
