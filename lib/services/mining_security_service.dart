import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Advanced security service for mining operations with rate limiting and fraud detection
class MiningSecurityService {
  static const int _maxAttemptsPerHour = 3;
  static const int _maxSessionsPerDay = 1;
  static const int _maxDevicesPerUser = 3;
  static const double _maxEarningsPerDay = 12.0; // 24h * 0.5 AKOFA/h


  final FirebaseFirestore _firestore;

  
  // Rate limiting cache
  final Map<String, List<DateTime>> _userAttempts = {};


  MiningSecurityService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Validate if user can start a new mining session
  Future<SecurityValidationResult> validateMiningStart({
    required String userId,
    required String deviceId,
    required double requestedRate,
  }) async {
    try {
      // Rate limiting check
      final rateLimitResult = await _checkRateLimit(userId);
      if (!rateLimitResult.isValid) {
        return rateLimitResult;
      }

      // Device limit check
      final deviceResult = await _checkDeviceLimit(userId, deviceId);
      if (!deviceResult.isValid) {
        return deviceResult;
      }

      // Daily session limit check
      final sessionResult = await _checkDailySessionLimit(userId, deviceId);
      if (!sessionResult.isValid) {
        return sessionResult;
      }

      // Mining rate validation
      final rateResult = await _validateMiningRate(userId, requestedRate);
      if (!rateResult.isValid) {
        return rateResult;
      }

      // Fraud detection
      final fraudResult = await _detectFraudulentActivity(userId, deviceId);
      if (!fraudResult.isValid) {
        return fraudResult;
      }

      // All checks passed
      await _recordValidationAttempt(userId, true);
      return SecurityValidationResult.success();

    } catch (e) {
      await _logSecurityEvent('validation_error', {
        'userId': userId,
        'deviceId': deviceId,
        'error': e.toString(),
      });
      
      return SecurityValidationResult.failure(
        'Security validation failed',
        SecurityViolationType.systemError,
      );
    }
  }

  /// Check rate limiting for mining attempts
  Future<SecurityValidationResult> _checkRateLimit(String userId) async {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));

    // Get user attempts from cache or database
    if (!_userAttempts.containsKey(userId)) {
      await _loadUserAttempts(userId);
    }

    final attempts = _userAttempts[userId] ?? [];
    final recentAttempts = attempts.where((time) => time.isAfter(oneHourAgo)).length;

    if (recentAttempts >= _maxAttemptsPerHour) {
      await _logSecurityEvent('rate_limit_exceeded', {
        'userId': userId,
        'attempts': recentAttempts,
        'timeWindow': 'hour',
      });

      return SecurityValidationResult.failure(
        'Too many mining attempts. Please wait before trying again.',
        SecurityViolationType.rateLimitExceeded,
      );
    }

    return SecurityValidationResult.success();
  }

  /// Load user mining attempts from database
  Future<void> _loadUserAttempts(String userId) async {
    try {
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      
      final attempts = await _firestore
          .collection('mining_attempts')
          .doc(userId)
          .collection('attempts')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(oneHourAgo))
          .orderBy('timestamp', descending: true)
          .get();

      _userAttempts[userId] = attempts.docs
          .map((doc) => (doc.data()['timestamp'] as Timestamp).toDate())
          .toList();
    } catch (e) {
      _userAttempts[userId] = [];
    }
  }

  /// Check device limit per user
  Future<SecurityValidationResult> _checkDeviceLimit(String userId, String deviceId) async {
    try {
      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));
      
      final devices = await _firestore
          .collection('secure_mining_sessions')
          .where('userId', isEqualTo: userId)
          .where('sessionStart', isGreaterThan: Timestamp.fromDate(oneDayAgo))
          .get();

      final uniqueDevices = devices.docs
          .map((doc) => doc.data()['deviceId'] as String)
          .toSet();

      if (uniqueDevices.length >= _maxDevicesPerUser && !uniqueDevices.contains(deviceId)) {
        await _logSecurityEvent('device_limit_exceeded', {
          'userId': userId,
          'deviceId': deviceId,
          'uniqueDevices': uniqueDevices.length,
        });

        return SecurityValidationResult.failure(
          'Maximum number of devices reached for this account.',
          SecurityViolationType.deviceLimitExceeded,
        );
      }

      return SecurityValidationResult.success();
    } catch (e) {
      return SecurityValidationResult.failure(
        'Device validation failed',
        SecurityViolationType.systemError,
      );
    }
  }

  /// Check daily session limit
  Future<SecurityValidationResult> _checkDailySessionLimit(String userId, String deviceId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      final sessions = await _firestore
          .collection('secure_mining_sessions')
          .where('userId', isEqualTo: userId)
          .where('deviceId', isEqualTo: deviceId)
          .where('sessionStart', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      if (sessions.docs.length >= _maxSessionsPerDay) {
        return SecurityValidationResult.failure(
          'Daily mining session limit reached.',
          SecurityViolationType.sessionLimitExceeded,
        );
      }

      return SecurityValidationResult.success();
    } catch (e) {
      return SecurityValidationResult.failure(
        'Session validation failed',
        SecurityViolationType.systemError,
      );
    }
  }

  /// Validate mining rate against user eligibility
  Future<SecurityValidationResult> _validateMiningRate(String userId, double requestedRate) async {
    try {
      final userDoc = await _firestore.collection('USER').doc(userId).get();
      if (!userDoc.exists) {
        return SecurityValidationResult.failure(
          'User not found',
          SecurityViolationType.invalidUser,
        );
      }

      final userData = userDoc.data()!;
      final isRateBoosted = userData['miningRateBoosted'] ?? false;
      final referralCount = userData['referralCount'] ?? 0;

      const double baseRate = 0.25;
      const double boostedRate = 0.50;
      
      double maxAllowedRate;
      if (isRateBoosted && referralCount >= 5) {
        maxAllowedRate = boostedRate;
      } else {
        maxAllowedRate = baseRate;
      }

      if (requestedRate > maxAllowedRate + 0.01) { // Small tolerance for float precision
        await _logSecurityEvent('invalid_mining_rate', {
          'userId': userId,
          'requestedRate': requestedRate,
          'maxAllowedRate': maxAllowedRate,
          'isRateBoosted': isRateBoosted,
          'referralCount': referralCount,
        });

        return SecurityValidationResult.failure(
          'Invalid mining rate requested',
          SecurityViolationType.invalidMiningRate,
        );
      }

      return SecurityValidationResult.success();
    } catch (e) {
      return SecurityValidationResult.failure(
        'Mining rate validation failed',
        SecurityViolationType.systemError,
      );
    }
  }

  /// Detect fraudulent activity patterns
  Future<SecurityValidationResult> _detectFraudulentActivity(String userId, String deviceId) async {
    try {
      // Check for suspicious timing patterns
      final timingResult = await _checkSuspiciousTiming(userId);
      if (!timingResult.isValid) return timingResult;

      // Check for excessive earnings
      final earningsResult = await _checkExcessiveEarnings(userId);
      if (!earningsResult.isValid) return earningsResult;

      // Check for device switching patterns
      final deviceResult = await _checkDeviceSwitchingPattern(userId, deviceId);
      if (!deviceResult.isValid) return deviceResult;

      // Check for proxy/VPN usage (simplified check)
      final networkResult = await _checkNetworkSuspicion(userId, deviceId);
      if (!networkResult.isValid) return networkResult;

      return SecurityValidationResult.success();
    } catch (e) {
      return SecurityValidationResult.success(); // Don't block on detection errors
    }
  }

  /// Check for suspicious timing patterns
  Future<SecurityValidationResult> _checkSuspiciousTiming(String userId) async {
    try {
      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));
      
      final sessions = await _firestore
          .collection('secure_mining_history')
          .doc(userId)
          .collection('sessions')
          .where('sessionEnd', isGreaterThan: Timestamp.fromDate(oneDayAgo))
          .orderBy('sessionEnd', descending: true)
          .limit(10)
          .get();

      if (sessions.docs.length < 2) return SecurityValidationResult.success();

      // Check for sessions ending exactly on the hour (automation indicator)
      var exactHourEndings = 0;
      for (final doc in sessions.docs) {
        final endTime = DateTime.parse(doc.data()['sessionEnd']);
        if (endTime.minute == 0 && endTime.second == 0) {
          exactHourEndings++;
        }
      }

      if (exactHourEndings > sessions.docs.length * 0.8) {
        await _logSecurityEvent('suspicious_timing', {
          'userId': userId,
          'exactHourEndings': exactHourEndings,
          'totalSessions': sessions.docs.length,
        });

        return SecurityValidationResult.failure(
          'Suspicious timing pattern detected',
          SecurityViolationType.suspiciousBehavior,
        );
      }

      return SecurityValidationResult.success();
    } catch (e) {
      return SecurityValidationResult.success();
    }
  }

  /// Check for excessive earnings
  Future<SecurityValidationResult> _checkExcessiveEarnings(String userId) async {
    try {
      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));
      
      final sessions = await _firestore
          .collection('secure_mining_history')
          .doc(userId)
          .collection('sessions')
          .where('sessionEnd', isGreaterThan: Timestamp.fromDate(oneDayAgo))
          .get();

      double totalEarnings = 0.0;
      for (final doc in sessions.docs) {
        totalEarnings += (doc.data()['earnedAkofa'] ?? 0.0) as double;
      }

      if (totalEarnings > _maxEarningsPerDay) {
        await _logSecurityEvent('excessive_earnings', {
          'userId': userId,
          'totalEarnings': totalEarnings,
          'maxAllowed': _maxEarningsPerDay,
        });

        return SecurityValidationResult.failure(
          'Daily earning limit exceeded',
          SecurityViolationType.excessiveEarnings,
        );
      }

      return SecurityValidationResult.success();
    } catch (e) {
      return SecurityValidationResult.success();
    }
  }

  /// Check for device switching patterns
  Future<SecurityValidationResult> _checkDeviceSwitchingPattern(String userId, String deviceId) async {
    try {
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
      
      final sessions = await _firestore
          .collection('secure_mining_sessions')
          .where('userId', isEqualTo: userId)
          .where('sessionStart', isGreaterThan: Timestamp.fromDate(oneWeekAgo))
          .orderBy('sessionStart', descending: true)
          .get();

      if (sessions.docs.length < 3) return SecurityValidationResult.success();

      final devices = sessions.docs.map((doc) => doc.data()['deviceId']).toSet();
      
      // If user has used more than 2 different devices in a week, flag as suspicious
      if (devices.length > 2) {
        await _logSecurityEvent('excessive_device_switching', {
          'userId': userId,
          'deviceCount': devices.length,
          'timeFrame': 'week',
        });

        return SecurityValidationResult.failure(
          'Suspicious device switching pattern detected',
          SecurityViolationType.suspiciousBehavior,
        );
      }

      return SecurityValidationResult.success();
    } catch (e) {
      return SecurityValidationResult.success();
    }
  }

  /// Check for network-level suspicion (simplified)
  Future<SecurityValidationResult> _checkNetworkSuspicion(String userId, String deviceId) async {
    // In a real implementation, this would check:
    // - Multiple users from same IP
    // - Known VPN/proxy IP ranges
    // - Geolocation inconsistencies
    // - Connection timing patterns
    
    return SecurityValidationResult.success();
  }

  /// Record validation attempt
  Future<void> _recordValidationAttempt(String userId, bool successful) async {
    try {
      final attempt = {
        'timestamp': FieldValue.serverTimestamp(),
        'successful': successful,
        'deviceId': await _getCurrentDeviceId(),
      };

      await _firestore
          .collection('mining_attempts')
          .doc(userId)
          .collection('attempts')
          .add(attempt);

      // Update cache
      _userAttempts[userId] ??= [];
      _userAttempts[userId]!.add(DateTime.now());
      
      // Keep only recent attempts in cache
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      _userAttempts[userId] = _userAttempts[userId]!
          .where((time) => time.isAfter(oneHourAgo))
          .toList();

    } catch (e) {
    }
  }

  /// Get current device ID (simplified)
  Future<String> _getCurrentDeviceId() async {
    // This should return the same device ID used by SecureMiningService
    return 'current_device_id';
  }

  /// Log security events for audit
  Future<void> _logSecurityEvent(String eventType, Map<String, dynamic> details) async {
    try {
      await _firestore.collection('security_audit').add({
        'eventType': eventType,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
        'severity': _getEventSeverity(eventType),
        'source': 'mining_security_service',
      });
    } catch (e) {
    }
  }

  /// Get event severity level
  String _getEventSeverity(String eventType) {
    switch (eventType) {
      case 'rate_limit_exceeded':
      case 'device_limit_exceeded':
      case 'session_limit_exceeded':
        return 'medium';
      case 'invalid_mining_rate':
      case 'suspicious_timing':
      case 'excessive_earnings':
      case 'excessive_device_switching':
        return 'high';
      case 'validation_error':
        return 'low';
      default:
        return 'medium';
    }
  }

  /// Validate session proof integrity
  Future<bool> validateSessionProof({
    required String sessionId,
    required String userId,
    required Map<String, dynamic> proofData,
  }) async {
    try {
      // Verify proof hash
      final expectedHash = _calculateProofHash(proofData);
      final providedHash = proofData['proofHash'] as String?;
      
      if (expectedHash != providedHash) {
        await _logSecurityEvent('invalid_proof_hash', {
          'sessionId': sessionId,
          'userId': userId,
          'expectedHash': expectedHash,
          'providedHash': providedHash,
        });
        return false;
      }

      // Verify timestamp is recent (within 5 minutes)
      final proofTime = DateTime.parse(proofData['timestamp']);
      final now = DateTime.now();
      final timeDiff = now.difference(proofTime).inMinutes.abs();
      
      if (timeDiff > 5) {
        await _logSecurityEvent('stale_proof', {
          'sessionId': sessionId,
          'userId': userId,
          'timeDiff': timeDiff,
        });
        return false;
      }

      return true;
    } catch (e) {
      await _logSecurityEvent('proof_validation_error', {
        'sessionId': sessionId,
        'userId': userId,
        'error': e.toString(),
      });
      return false;
    }
  }

  /// Calculate proof hash for validation
  String _calculateProofHash(Map<String, dynamic> proofData) {
    final input = '${proofData['sessionId']}:${proofData['action']}:${proofData['seconds']}:${proofData['nonce']}:${proofData['challenge']}:${proofData['timestamp']}';
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Get security statistics for user
  Future<Map<String, dynamic>> getSecurityStatistics(String userId) async {
    try {
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
      
      // Get violation count
      final violations = await _firestore
          .collection('security_audit')
          .where('details.userId', isEqualTo: userId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(oneWeekAgo))
          .where('severity', isEqualTo: 'high')
          .get();

      // Get attempt statistics
      final attempts = await _firestore
          .collection('mining_attempts')
          .doc(userId)
          .collection('attempts')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(oneWeekAgo))
          .get();

      final successfulAttempts = attempts.docs
          .where((doc) => doc.data()['successful'] == true)
          .length;

      return {
        'violations': violations.docs.length,
        'totalAttempts': attempts.docs.length,
        'successfulAttempts': successfulAttempts,
        'successRate': attempts.docs.isEmpty ? 0.0 : successfulAttempts / attempts.docs.length,
        'riskLevel': _calculateRiskLevel(violations.docs.length, attempts.docs.length),
      };
    } catch (e) {
      return {};
    }
  }

  /// Calculate user risk level
  String _calculateRiskLevel(int violations, int totalAttempts) {
    if (violations > 5) return 'high';
    if (violations > 2 || totalAttempts > 20) return 'medium';
    return 'low';
  }
}

/// Security validation result
class SecurityValidationResult {
  final bool isValid;
  final String? errorMessage;
  final SecurityViolationType? violationType;

  SecurityValidationResult._({
    required this.isValid,
    this.errorMessage,
    this.violationType,
  });

  factory SecurityValidationResult.success() {
    return SecurityValidationResult._(isValid: true);
  }

  factory SecurityValidationResult.failure(
    String message,
    SecurityViolationType type,
  ) {
    return SecurityValidationResult._(
      isValid: false,
      errorMessage: message,
      violationType: type,
    );
  }
}

/// Types of security violations
enum SecurityViolationType {
  rateLimitExceeded,
  deviceLimitExceeded,
  sessionLimitExceeded,
  invalidMiningRate,
  excessiveEarnings,
  suspiciousBehavior,
  invalidUser,
  systemError,
}
