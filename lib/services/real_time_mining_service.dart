import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    
    // Calculate real-time accumulated seconds
    final lastResume = _currentSession!.lastResume;
    final totalActiveSeconds = now.difference(lastResume).inSeconds + _currentSession!.accumulatedSeconds;
    
    // Update accumulated seconds directly
    _currentSession!.accumulatedSeconds = totalActiveSeconds;
    
    // Emit updated session
    _sessionStreamController?.add(_currentSession!);
    
    // Debug: Show real-time progress
    if (totalActiveSeconds % 10 == 0) { // Log every 10 seconds to avoid spam
      print('⏱️ Real-time update: ${totalActiveSeconds}s active, ${_currentSession!.earnedAkofa.toStringAsFixed(6)} AKOFA earned');
    }
  }
  
  /// Start a new mining session
  Future<SecureMiningSession> startSession(String userId, String deviceId) async {
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
  
  /// Pause mining session
  Future<void> pauseSession() async {
    if (_currentSession == null || !_currentSession!.isActive || _currentSession!.isPaused) {
      return;
    }
    
    // Update real-time progress before pausing
    await _updateRealTimeProgress();
    
    _currentSession!.isPaused = true;
    _currentSession!.pausedAt = DateTime.now();
    
    await _persistSession();
    _sessionStreamController?.add(_currentSession!);
    
    print('⏸️ Mining session paused at ${_currentSession!.accumulatedSeconds}s');
  }
  
  /// Resume mining session
  Future<void> resumeSession() async {
    if (_currentSession == null || !_currentSession!.isPaused) {
      return;
    }
    
    final now = DateTime.now();
    final pausedDuration = _currentSession!.pausedAt != null 
        ? now.difference(_currentSession!.pausedAt!).inSeconds 
        : 0;
    
    _currentSession!.isPaused = false;
    _currentSession!.lastResume = now;
    _currentSession!.pausedAt = null;
    
    await _persistSession();
    _sessionStreamController?.add(_currentSession!);
    
    print('▶️ Mining session resumed after ${pausedDuration}s pause');
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
    
    // Process mining reward - THIS IS THE CRITICAL MISSING PIECE
    if (earnedAkofa > 0) {
      try {
        print('💰 Processing mining reward: ${earnedAkofa.toStringAsFixed(6)} AKOFA');
        
        final result = await _stellarService.recordMiningReward(earnedAkofa);
        
        if (result['success'] == true) {
          print('✅ Mining reward successfully credited to wallet');
          print('🔗 Transaction hash: ${result['hash']}');
        } else {
          print('❌ Failed to credit mining reward: ${result['message']}');
        }
      } catch (e) {
        print('❌ Error processing mining reward: $e');
      }
    }
    
    // Clear current session
    _currentSession = null;
    await _clearPersistedSession();
    
    print('🏁 Mining session ended. Earned: ${earnedAkofa.toStringAsFixed(6)} AKOFA');
    return earnedAkofa;
  }
  
  /// Get current session
  SecureMiningSession? getCurrentSession() {
    return _currentSession;
  }
  
  /// Restore session from storage
  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionData = prefs.getString(_sessionKey);
      final lastUpdateStr = prefs.getString(_lastUpdateKey);
      
      if (sessionData != null) {
        // Skip restoration for now - would need proper deserialization
        print('Session data found but skipping restoration until proper serialization implemented');
        
        final now = DateTime.now();
        
        // Check if session is still valid
        if (_currentSession!.isActive && now.isBefore(_currentSession!.sessionEnd)) {
          // Calculate time elapsed since last update
          if (lastUpdateStr != null) {
            final lastUpdate = DateTime.parse(lastUpdateStr);
            final elapsedSinceUpdate = now.difference(lastUpdate).inSeconds;
            
            // Only add elapsed time if session wasn't paused
            if (!_currentSession!.isPaused) {
              _currentSession!.accumulatedSeconds += elapsedSinceUpdate;
            }
          }
          
          print('🔄 Mining session restored: ${_currentSession!.accumulatedSeconds}s active');
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
  
  /// Persist current session to storage
  Future<void> _persistSession() async {
    if (_currentSession == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      // Simple persistence using basic session info
      final sessionInfo = {
        'sessionId': _currentSession!.sessionId,
        'userId': _currentSession!.userId,
        'deviceId': _currentSession!.deviceId,
        'sessionStart': _currentSession!.sessionStart.toIso8601String(),
        'sessionEnd': _currentSession!.sessionEnd.toIso8601String(),
        'isPaused': _currentSession!.isPaused,
        'accumulatedSeconds': _currentSession!.accumulatedSeconds,
        'miningRate': _currentSession!.miningRate,
      };
      await prefs.setString(_sessionKey, json.encode(sessionInfo));
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
      
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
          'accumulatedSeconds': _currentSession!.accumulatedSeconds,
          'miningRate': _currentSession!.miningRate,
          'earnedAkofa': _currentSession!.earnedAkofa,
          'lastSynced': FieldValue.serverTimestamp(),
          'realTimeUpdate': true,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('❌ Error saving to Firestore: $e');
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
