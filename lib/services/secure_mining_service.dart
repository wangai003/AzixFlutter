import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/secure_mining_session.dart';

/// Enhanced mining service with cryptographic security and server-side validation
class SecureMiningService {
  static const String _sessionKey = 'secure_mining_session';
  static const String _deviceIdKey = 'device_id';
  static const int _maxSessionsPerDay = 1;

  static const int _proofIntervalSeconds = 60; // Submit proof every minute
  static const double _minValidProofRatio = 0.8; // 80% of proofs must be valid

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  Timer? _proofTimer;
  Timer? _validationTimer;
  SecureMiningSession? _currentSession;
  String? _deviceId;

  SecureMiningService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  /// Initialize the service and get device ID
  Future<void> initialize() async {
    await _initializeDeviceId();
  }

  /// Get or generate unique device ID
  Future<void> _initializeDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_deviceIdKey);
    
    if (_deviceId == null) {
      final deviceInfo = DeviceInfoPlugin();
      String deviceIdentifier;
      
      try {
        final androidInfo = await deviceInfo.androidInfo;
        deviceIdentifier = androidInfo.id;
      } catch (e) {
        // Fallback to random identifier
        final random = Random.secure();
        final bytes = List.generate(16, (_) => random.nextInt(256));
        deviceIdentifier = base64.encode(bytes);
      }
      
      _deviceId = _generateSecureDeviceId(deviceIdentifier);
      await prefs.setString(_deviceIdKey, _deviceId!);
    }
  }

  /// Generate secure device ID with additional entropy
  String _generateSecureDeviceId(String baseId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random.secure();
    final nonce = List.generate(8, (_) => random.nextInt(256));
    final input = '$baseId:$timestamp:${nonce.join('')}';
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Start a new secure mining session
  Future<SecureMiningSession?> startMining(double miningRate) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || _deviceId == null) return null;

    // Check if user can start a new session
    if (!await _canStartNewSession(userId)) {
      throw Exception('Maximum daily sessions reached or session in progress');
    }

    // Validate mining rate with server
    if (!await _validateMiningRate(userId, miningRate)) {
      throw Exception('Invalid mining rate for user');
    }

    // Create new secure session
    _currentSession = SecureMiningSession.newSession(
      userId: userId,
      deviceId: _deviceId!,
      miningRate: miningRate,
    );

    // Start proof submission timer
    _startProofTimer();
    
    // Start server validation timer
    _startValidationTimer();

    // Save session locally and to server
    await _saveSessionLocally(_currentSession!);
    await _saveSessionToServer(_currentSession!);

    return _currentSession;
  }

  /// Check if user can start a new mining session
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
        return false; // Active session exists
      }

      // Check daily session limit
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      final todaySessions = await _firestore
          .collection('secure_mining_sessions')
          .where('userId', isEqualTo: userId)
          .where('deviceId', isEqualTo: _deviceId)
          .where('sessionStart', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      return todaySessions.docs.length < _maxSessionsPerDay;
    } catch (e) {
      return false;
    }
  }

  /// Validate mining rate with server-side rules
  Future<bool> _validateMiningRate(String userId, double miningRate) async {
    try {
      // Get user document to check boosted status
      final userDoc = await _firestore.collection('USER').doc(userId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final isRateBoosted = userData['miningRateBoosted'] ?? false;
      final referralCount = userData['referralCount'] ?? 0;

      // Validate rate against user's eligibility
      const double baseRate = 0.25;
      const double boostedRate = 0.50; // 2x boost for 5+ referrals

      if (isRateBoosted && referralCount >= 5) {
        return miningRate <= boostedRate;
      } else {
        return miningRate <= baseRate;
      }
    } catch (e) {
      return false;
    }
  }

  /// Start proof submission timer
  void _startProofTimer() {
    _proofTimer?.cancel();
    _proofTimer = Timer.periodic(
      Duration(seconds: _proofIntervalSeconds),
      (_) => _submitMiningProof(),
    );
  }

  /// Submit cryptographic proof of mining work
  void _submitMiningProof() {
    final session = _currentSession;
    if (session == null || !session.isActive || session.isPaused) return;

    // Update accumulated time before submitting proof
    final now = DateTime.now();
    final timeSinceResume = now.difference(session.lastResume).inSeconds;
    session.accumulatedSeconds += timeSinceResume;
    session.lastResume = now;

    // Submit proof
    session.submitProof('mining', timeSinceResume);

    // Save updated session
    _saveSessionLocally(session);
    _saveSessionToServer(session);
  }

  /// Start server validation timer
  void _startValidationTimer() {
    _validationTimer?.cancel();
    _validationTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _validateWithServer(),
    );
  }

  /// Validate session with server
  Future<void> _validateWithServer() async {
    final session = _currentSession;
    if (session == null) return;

    try {
      // Get server-side session data
      final serverSession = await _firestore
          .collection('secure_mining_sessions')
          .doc(session.sessionId)
          .get();

      if (!serverSession.exists) {
        // Session doesn't exist on server - potential tampering
        _flagSecurityViolation('session_not_found');
        _terminateSession('security_violation');
        return;
      }

      final serverData = serverSession.data()!;
      
      // Validate critical fields haven't been tampered with
      if (serverData['userId'] != session.userId ||
          serverData['deviceId'] != session.deviceId ||
          serverData['sessionHash'] != session.sessionHash) {
        _flagSecurityViolation('session_tampering');
        _terminateSession('security_violation');
        return;
      }

      // Validate proof integrity
      final serverProofCount = (serverData['totalProofsSubmitted'] ?? 0) as int;
      if ((session.totalProofsSubmitted - serverProofCount).abs() > 2) {
        // Allow small discrepancy for network delays
        _flagSecurityViolation('proof_mismatch');
        _terminateSession('security_violation');
        return;
      }

      // Update server validation hash
      session.serverValidationHash = _generateValidationHash(session);
      await _saveSessionToServer(session);

    } catch (e) {
    }
  }

  /// Generate validation hash for integrity check
  String _generateValidationHash(SecureMiningSession session) {
    final input = '${session.sessionId}:${session.accumulatedSeconds}:${session.totalProofsSubmitted}:${DateTime.now().millisecondsSinceEpoch}';
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Flag security violation
  void _flagSecurityViolation(String violationType) {
    
    // Log to security audit trail
    _logSecurityEvent(violationType, {
      'sessionId': _currentSession?.sessionId,
      'userId': _currentSession?.userId,
      'deviceId': _currentSession?.deviceId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Log security events for audit
  Future<void> _logSecurityEvent(String eventType, Map<String, dynamic> details) async {
    try {
      await _firestore.collection('security_audit').add({
        'eventType': eventType,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
        'severity': 'high',
      });
    } catch (e) {
    }
  }

  /// Pause mining with security validation
  Future<void> pauseMining() async {
    final session = _currentSession;
    if (session == null || !session.isActive) return;

    session.pauseMining();
    _proofTimer?.cancel();
    
    await _saveSessionLocally(session);
    await _saveSessionToServer(session);
  }

  /// Resume mining with security validation
  Future<void> resumeMining() async {
    final session = _currentSession;
    if (session == null || session.isPaused) return;

    session.resumeMining();
    _startProofTimer();
    
    await _saveSessionLocally(session);
    await _saveSessionToServer(session);
  }

  /// End mining session and calculate rewards
  Future<SecureMiningSessionHistory> endMining() async {
    final session = _currentSession;
    if (session == null) throw Exception('No active mining session');

    // Stop all timers
    _proofTimer?.cancel();
    _validationTimer?.cancel();

    // Final validation
    if (!session.isValid) {
      _flagSecurityViolation('invalid_session_end');
    }

    // Calculate final earnings with proof validation
    final earnedAkofa = session.earnedAkofa;
    
    // Check minimum proof ratio
    final validProofs = session.proofs.where((p) => session.validateProof(p)).length;
    final proofRatio = session.proofs.isEmpty ? 0.0 : validProofs / session.proofs.length;
    
    if (proofRatio < _minValidProofRatio) {
      _flagSecurityViolation('insufficient_valid_proofs');
    }

    // Create history record with security metrics
    final history = SecureMiningSessionHistory(
      id: '',
      userId: session.userId,
      sessionId: session.sessionId,
      sessionStart: session.sessionStart,
      sessionEnd: session.sessionEnd,
      earnedAkofa: earnedAkofa,
      status: session.isValid && proofRatio >= _minValidProofRatio ? 'completed' : 'flagged',
      securityMetrics: session.securityMetrics,
      securityFlags: proofRatio < _minValidProofRatio ? ['low_proof_ratio'] : [],
      validationHash: _generateValidationHash(session),
    );

    // Save to history
    await _saveSessionHistory(history);
    
    // Clear current session
    _currentSession = null;
    await _clearSessionLocally();

    return history;
  }

  /// Terminate session due to security violation
  void _terminateSession(String reason) {
    _proofTimer?.cancel();
    _validationTimer?.cancel();
    _currentSession = null;
    _clearSessionLocally();
    
  }

  /// Save session locally
  Future<void> _saveSessionLocally(SecureMiningSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, json.encode(session.toJson()));
    } catch (e) {
    }
  }

  /// Save session to server
  Future<void> _saveSessionToServer(SecureMiningSession session) async {
    try {
      await _firestore
          .collection('secure_mining_sessions')
          .doc(session.sessionId)
          .set(session.toFirestore(), SetOptions(merge: true));
    } catch (e) {
    }
  }

  /// Load session from local storage
  Future<SecureMiningSession?> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionData = prefs.getString(_sessionKey);
      
      if (sessionData == null) return null;
      
      final session = SecureMiningSession.fromJson(json.decode(sessionData));
      
      // Validate session integrity
      if (!session.isValid || session.isExpired) {
        await _clearSessionLocally();
        return null;
      }
      
      _currentSession = session;
      
      // Restart timers if session is active
      if (session.isActive && !session.isPaused) {
        _startProofTimer();
        _startValidationTimer();
      }
      
      return session;
    } catch (e) {
      await _clearSessionLocally();
      return null;
    }
  }

  /// Clear local session storage
  Future<void> _clearSessionLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (e) {
    }
  }

  /// Save session history
  Future<void> _saveSessionHistory(SecureMiningSessionHistory history) async {
    try {
      await _firestore
          .collection('secure_mining_history')
          .doc(history.userId)
          .collection('sessions')
          .add(history.toFirestore());
    } catch (e) {
    }
  }

  /// Get user's mining statistics with security metrics
  Future<Map<String, dynamic>> getMiningStatistics(String userId) async {
    try {
      final sessions = await _firestore
          .collection('secure_mining_history')
          .doc(userId)
          .collection('sessions')
          .orderBy('sessionEnd', descending: true)
          .limit(100)
          .get();

      int totalSessions = 0;
      double totalEarned = 0.0;
      int flaggedSessions = 0;
      double avgIntegrityScore = 0.0;

      for (final doc in sessions.docs) {
        final data = doc.data();
        totalSessions++;
        totalEarned += (data['earnedAkofa'] ?? 0.0) as double;
        
        if (data['status'] == 'flagged') flaggedSessions++;
        
        final metrics = data['securityMetrics'] as Map<String, dynamic>? ?? {};
        avgIntegrityScore += (metrics['integrityScore'] ?? 0.0) as double;
      }

      if (totalSessions > 0) {
        avgIntegrityScore /= totalSessions;
      }

      return {
        'totalSessions': totalSessions,
        'totalEarned': totalEarned,
        'flaggedSessions': flaggedSessions,
        'integrityScore': avgIntegrityScore,
        'trustLevel': _calculateTrustLevel(flaggedSessions, totalSessions, avgIntegrityScore),
      };
    } catch (e) {
      return {};
    }
  }

  /// Calculate user trust level based on security metrics
  String _calculateTrustLevel(int flaggedSessions, int totalSessions, double avgIntegrityScore) {
    if (totalSessions == 0) return 'new';
    
    final flaggedRatio = flaggedSessions / totalSessions;
    
    if (flaggedRatio > 0.1 || avgIntegrityScore < 0.7) return 'low';
    if (flaggedRatio > 0.05 || avgIntegrityScore < 0.9) return 'medium';
    return 'high';
  }

  /// Get current session
  SecureMiningSession? get currentSession => _currentSession;

  /// Restore mining session from local storage and server
  Future<SecureMiningSession?> restoreSession() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || _deviceId == null) return null;

    try {
      // First try to restore from local storage
      final localSession = await _restoreSessionLocally();
      if (localSession != null && localSession.isActive) {
        // Validate with server
        final serverSession = await _getSessionFromServer(userId, localSession.sessionId);
        if (serverSession != null && serverSession.isActive) {
          _currentSession = serverSession;
          _startProofTimer();
          _startValidationTimer();
          return _currentSession;
        }
      }

      // If local restoration failed, try server restoration
      final activeServerSession = await _getActiveSessionFromServer(userId);
      if (activeServerSession != null) {
        _currentSession = activeServerSession;
        await _saveSessionLocally(_currentSession!);
        _startProofTimer();
        _startValidationTimer();
        return _currentSession;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Restore session from local storage
  Future<SecureMiningSession?> _restoreSessionLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionData = prefs.getString(_sessionKey);
      if (sessionData == null) return null;

      final sessionMap = json.decode(sessionData) as Map<String, dynamic>;
      final session = SecureMiningSession.fromJson(sessionMap);
      
      // Check if session is still valid
      if (session.sessionEnd.isAfter(DateTime.now()) && session.isActive) {
        return session;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get session from server by session ID
  Future<SecureMiningSession?> _getSessionFromServer(String userId, String sessionId) async {
    try {
      final doc = await _firestore
          .collection('secure_mining_sessions')
          .doc(sessionId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      if (data['userId'] != userId || data['deviceId'] != _deviceId) return null;

      return SecureMiningSession.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// Get active session from server for user
  Future<SecureMiningSession?> _getActiveSessionFromServer(String userId) async {
    try {
      final query = await _firestore
          .collection('secure_mining_sessions')
          .where('userId', isEqualTo: userId)
          .where('deviceId', isEqualTo: _deviceId)
          .where('sessionEnd', isGreaterThan: Timestamp.now())
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final doc = query.docs.first;
      return SecureMiningSession.fromJson(doc.data());
    } catch (e) {
      return null;
    }
  }

  /// Check if user can start mining
  Future<bool> canStartMining() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;
    
    return await _canStartNewSession(userId);
  }

  /// Dispose of resources
  void dispose() {
    _proofTimer?.cancel();
    _validationTimer?.cancel();
  }
}
