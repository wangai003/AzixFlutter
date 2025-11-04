import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
// import 'package:geolocator/geolocator.dart'; // Commented out - requires additional setup
import 'dart:math';

/// Advanced payment security and fraud detection service
/// Implements multiple layers of security for mobile money transactions
class PaymentSecurityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Security thresholds
  static const int _maxTransactionsPerHour = 5;
  static const int _maxTransactionsPerDay = 20;
  static const double _maxAmountPerTransaction = 500000.0; // NGN
  static const double _maxAmountPerDay = 2000000.0; // NGN
  static const int _velocityCheckWindowMinutes = 30;
  static const int _maxSimilarAmountsInWindow = 3;

  // Risk scoring weights
  static const double _deviceRiskWeight = 0.3;
  static const double _locationRiskWeight = 0.2;
  static const double _amountRiskWeight = 0.2;
  static const double _velocityRiskWeight = 0.2;
  static const double _behaviorRiskWeight = 0.1;

  /// Comprehensive pre-transaction security validation
  Future<Map<String, dynamic>> validateTransactionSecurity({
    required String userId,
    required double amount,
    required String countryCode,
    required String phoneNumber,
    required String provider,
  }) async {
    try {
      final securityChecks = <String, dynamic>{};
      double riskScore = 0.0;
      final violations = <String>[];

      // 1. Basic amount validation
      final amountValidation = await _validateTransactionAmount(
        amount,
        countryCode,
      );
      securityChecks['amountValidation'] = amountValidation;
      if (!amountValidation['valid']) {
        violations.add(amountValidation['error']);
        riskScore += 1.0;
      }

      // 2. Velocity checks (transaction frequency)
      final velocityCheck = await _checkTransactionVelocity(userId, amount);
      securityChecks['velocityCheck'] = velocityCheck;
      riskScore += velocityCheck['riskScore'];

      if (!velocityCheck['allowed']) {
        violations.add(velocityCheck['reason']);
      }

      // 3. Daily limits check
      final dailyLimitsCheck = await _checkDailyLimits(
        userId,
        amount,
        countryCode,
      );
      securityChecks['dailyLimitsCheck'] = dailyLimitsCheck;
      riskScore += dailyLimitsCheck['riskScore'];

      if (!dailyLimitsCheck['allowed']) {
        violations.add(dailyLimitsCheck['reason']);
      }

      // 4. Phone number validation and reputation
      final phoneValidation = await _validatePhoneNumber(
        phoneNumber,
        countryCode,
      );
      securityChecks['phoneValidation'] = phoneValidation;
      riskScore += phoneValidation['riskScore'];

      if (!phoneValidation['valid']) {
        violations.add(phoneValidation['error']);
      }

      // 5. Device fingerprinting and risk assessment
      final deviceCheck = await _assessDeviceRisk(userId);
      securityChecks['deviceCheck'] = deviceCheck;
      riskScore += deviceCheck['riskScore'] * _deviceRiskWeight;

      // 6. Location-based risk assessment
      final locationCheck = await _assessLocationRisk(userId);
      securityChecks['locationCheck'] = locationCheck;
      riskScore += locationCheck['riskScore'] * _locationRiskWeight;

      // 7. Behavioral pattern analysis
      final behaviorCheck = await _analyzeBehavioralPatterns(
        userId,
        amount,
        provider,
      );
      securityChecks['behaviorCheck'] = behaviorCheck;
      riskScore += behaviorCheck['riskScore'] * _behaviorRiskWeight;

      // 8. Amount pattern analysis
      final amountPatternCheck = await _checkAmountPatterns(userId, amount);
      securityChecks['amountPatternCheck'] = amountPatternCheck;
      riskScore += amountPatternCheck['riskScore'] * _amountRiskWeight;

      // Determine overall security decision
      final securityDecision = _makeSecurityDecision(riskScore, violations);

      // Log security assessment
      await _logSecurityAssessment(
        userId: userId,
        amount: amount,
        countryCode: countryCode,
        riskScore: riskScore,
        securityChecks: securityChecks,
        decision: securityDecision,
        violations: violations,
      );

      return {
        'allowed': securityDecision['allowed'],
        'riskScore': riskScore,
        'riskLevel': securityDecision['riskLevel'],
        'reason': securityDecision['reason'],
        'violations': violations,
        'securityChecks': securityChecks,
        'recommendations': securityDecision['recommendations'],
      };
    } catch (e) {
      // Fail-safe: allow transaction but flag for manual review
      await _logSecurityError(userId, amount, e.toString());

      return {
        'allowed': true, // Fail-open for UX
        'riskScore': 0.8, // High risk due to error
        'riskLevel': 'high',
        'reason': 'Security validation error - flagged for review',
        'violations': ['Security system error'],
        'flaggedForReview': true,
      };
    }
  }

  /// Validate transaction amount against country-specific limits
  Future<Map<String, dynamic>> _validateTransactionAmount(
    double amount,
    String countryCode,
  ) async {
    // Country-specific limits
    final countryLimits = {
      'NG': {'min': 100.0, 'max': 500000.0},
      'GH': {'min': 5.0, 'max': 5000.0},
      'UG': {'min': 1000.0, 'max': 2500000.0},
      'RW': {'min': 500.0, 'max': 500000.0},
      'ZM': {'min': 10.0, 'max': 5000.0},
      'CI': {'min': 500.0, 'max': 500000.0},
      'CM': {'min': 500.0, 'max': 500000.0},
      'KE': {'min': 100.0, 'max': 50000.0}, // M-Pesa
    };

    final limits = countryLimits[countryCode] ?? {'min': 10.0, 'max': 10000.0};

    if (amount < limits['min']! || amount > limits['max']!) {
      return {
        'valid': false,
        'error':
            'Amount ${amount.toStringAsFixed(2)} is outside allowed range (${limits['min']} - ${limits['max']}) for $countryCode',
        'minAmount': limits['min'],
        'maxAmount': limits['max'],
      };
    }

    return {
      'valid': true,
      'amount': amount,
      'currency': _getCurrencyForCountry(countryCode),
    };
  }

  /// Check transaction velocity and frequency patterns
  Future<Map<String, dynamic>> _checkTransactionVelocity(
    String userId,
    double amount,
  ) async {
    try {
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      final thirtyMinutesAgo = now.subtract(
        const Duration(minutes: _velocityCheckWindowMinutes),
      );

      // Check transactions in the last hour
      final hourlyTransactions = await _firestore
          .collection('mtn_transactions')
          .where('userId', isEqualTo: userId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(oneHourAgo))
          .get();

      // Check transactions in velocity window
      final velocityTransactions = await _firestore
          .collection('mtn_transactions')
          .where('userId', isEqualTo: userId)
          .where(
            'createdAt',
            isGreaterThan: Timestamp.fromDate(thirtyMinutesAgo),
          )
          .get();

      final hourlyCount = hourlyTransactions.docs.length;
      final velocityCount = velocityTransactions.docs.length;

      double riskScore = 0.0;
      final reasons = <String>[];

      // Check hourly limit
      if (hourlyCount >= _maxTransactionsPerHour) {
        riskScore += 0.8;
        reasons.add(
          'Hourly transaction limit exceeded ($hourlyCount transactions in last hour)',
        );
      }

      // Check velocity patterns
      if (velocityCount >= _maxTransactionsPerHour) {
        riskScore += 0.6;
        reasons.add(
          'High velocity detected ($velocityCount transactions in $_velocityCheckWindowMinutes minutes)',
        );
      }

      // Check for rapid-fire transactions
      if (velocityCount > 0) {
        final avgInterval =
            _velocityCheckWindowMinutes *
            60 /
            velocityCount; // seconds between transactions
        if (avgInterval < 60) {
          // Less than 1 minute between transactions
          riskScore += 0.4;
          reasons.add('Rapid transaction pattern detected');
        }
      }

      return {
        'allowed': riskScore < 0.7,
        'hourlyCount': hourlyCount,
        'velocityCount': velocityCount,
        'riskScore': riskScore,
        'reason': reasons.isNotEmpty ? reasons.join('; ') : null,
      };
    } catch (e) {
      return {
        'allowed': true, // Fail-open
        'error': e.toString(),
        'riskScore': 0.3, // Moderate risk due to check failure
      };
    }
  }

  /// Check daily spending limits
  Future<Map<String, dynamic>> _checkDailyLimits(
    String userId,
    double amount,
    String countryCode,
  ) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final dailyTransactions = await _firestore
          .collection('mtn_transactions')
          .where('userId', isEqualTo: userId)
          .where('countryCode', isEqualTo: countryCode)
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('status', whereIn: ['pending', 'credited'])
          .get();

      double dailyTotal = 0.0;
      int dailyCount = 0;

      for (final doc in dailyTransactions.docs) {
        final data = doc.data();
        dailyTotal += (data['amount'] as num?)?.toDouble() ?? 0.0;
        dailyCount++;
      }

      final newTotal = dailyTotal + amount;
      double riskScore = 0.0;
      final reasons = <String>[];

      // Check daily amount limit
      if (newTotal > _maxAmountPerDay) {
        riskScore += 0.9;
        reasons.add(
          'Daily amount limit would be exceeded (₦${newTotal.toStringAsFixed(2)} > ₦${_maxAmountPerDay.toStringAsFixed(2)})',
        );
      }

      // Check daily transaction count
      if (dailyCount >= _maxTransactionsPerDay) {
        riskScore += 0.7;
        reasons.add(
          'Daily transaction count limit exceeded ($dailyCount transactions today)',
        );
      }

      // Progressive risk scoring
      if (newTotal > _maxAmountPerDay * 0.8) {
        riskScore += 0.3;
        reasons.add('Approaching daily limit');
      }

      return {
        'allowed': riskScore < 0.8,
        'dailyTotal': dailyTotal,
        'newTotal': newTotal,
        'dailyCount': dailyCount,
        'riskScore': riskScore,
        'reason': reasons.isNotEmpty ? reasons.join('; ') : null,
      };
    } catch (e) {
      return {
        'allowed': true, // Fail-open
        'error': e.toString(),
        'riskScore': 0.2,
      };
    }
  }

  /// Validate phone number and check reputation
  Future<Map<String, dynamic>> _validatePhoneNumber(
    String phoneNumber,
    String countryCode,
  ) async {
    try {
      // Basic format validation
      final isValidFormat = _validatePhoneFormat(phoneNumber, countryCode);

      if (!isValidFormat) {
        return {
          'valid': false,
          'error': 'Invalid phone number format for $countryCode',
          'riskScore': 0.9,
        };
      }

      // Check for blacklisted numbers (simplified)
      final isBlacklisted = await _checkPhoneBlacklist(phoneNumber);
      if (isBlacklisted) {
        return {
          'valid': false,
          'error': 'Phone number is blacklisted',
          'riskScore': 1.0,
        };
      }

      // Check transaction history for this number
      final phoneHistory = await _getPhoneTransactionHistory(phoneNumber);
      double riskScore = 0.0;

      // Risk factors based on phone history
      if (phoneHistory['totalTransactions'] > 50) {
        riskScore += 0.2; // High volume number
      }

      if (phoneHistory['failureRate'] > 0.3) {
        riskScore += 0.4; // High failure rate
      }

      if (phoneHistory['recentFailures'] > 2) {
        riskScore += 0.3; // Recent failures
      }

      return {
        'valid': true,
        'phoneNumber': phoneNumber,
        'formattedNumber': _formatPhoneNumber(phoneNumber, countryCode),
        'riskScore': riskScore,
        'history': phoneHistory,
      };
    } catch (e) {
      return {
        'valid': false,
        'error': 'Phone validation error: ${e.toString()}',
        'riskScore': 0.5,
      };
    }
  }

  /// Assess device-based risk factors
  Future<Map<String, dynamic>> _assessDeviceRisk(String userId) async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceFingerprint = '';

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceFingerprint = '${iosInfo.identifierForVendor}-${iosInfo.model}';
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceFingerprint = '${androidInfo.id}-${androidInfo.model}';
      }

      // Check device history
      final deviceHistory = await _getDeviceTransactionHistory(
        deviceFingerprint,
      );

      double riskScore = 0.0;

      // New device check
      if (deviceHistory['totalTransactions'] == 0) {
        riskScore += 0.3; // New device
      }

      // Device with high failure rate
      if (deviceHistory['failureRate'] > 0.4) {
        riskScore += 0.5;
      }

      // Multiple users on same device
      if (deviceHistory['uniqueUsers'] > 3) {
        riskScore += 0.4;
      }

      return {
        'deviceFingerprint': deviceFingerprint,
        'riskScore': riskScore,
        'history': deviceHistory,
        'isKnownDevice': deviceHistory['totalTransactions'] > 0,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'riskScore': 0.2, // Moderate risk due to check failure
      };
    }
  }

  /// Assess location-based risk
  Future<Map<String, dynamic>> _assessLocationRisk(String userId) async {
    try {
      // Simplified location risk assessment without geolocator
      // In production, integrate with geolocator package

      // For now, return low risk - location services disabled
      return {
        'locationAvailable': false,
        'riskScore': 0.1, // Slight risk for no location data
        'reason': 'Location services not available',
      };

      // TODO: Uncomment and configure when geolocator is added to pubspec.yaml
      /*
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {
          'locationAvailable': false,
          'riskScore': 0.1, // Slight risk for no location
        };
      }

      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      // Check location history
      final locationHistory = await _getLocationTransactionHistory(
        userId,
        position.latitude,
        position.longitude,
      );

      double riskScore = 0.0;

      // Unusual location check
      if (locationHistory['isUnusualLocation']) {
        riskScore += 0.4;
      }

      // High-risk location
      if (locationHistory['isHighRiskArea']) {
        riskScore += 0.6;
      }

      // Distance from usual locations
      if (locationHistory['distanceFromUsual'] > 500) { // 500km
        riskScore += 0.2;
      }

      return {
        'locationAvailable': true,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'riskScore': riskScore,
        'locationHistory': locationHistory,
      };
      */
    } catch (e) {
      return {
        'locationAvailable': false,
        'error': e.toString(),
        'riskScore': 0.1,
      };
    }
  }

  /// Analyze behavioral patterns
  Future<Map<String, dynamic>> _analyzeBehavioralPatterns(
    String userId,
    double amount,
    String provider,
  ) async {
    try {
      // Get user's transaction history
      final userHistory = await _firestore
          .collection('mtn_transactions')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      double riskScore = 0.0;
      final patterns = <String>[];

      if (userHistory.docs.isNotEmpty) {
        final transactions = userHistory.docs.map((doc) => doc.data()).toList();

        // Check for unusual amount (compared to user's average)
        final avgAmount =
            transactions
                .map((t) => (t['amount'] as num?)?.toDouble() ?? 0.0)
                .reduce((a, b) => a + b) /
            transactions.length;

        if (amount > avgAmount * 3) {
          riskScore += 0.3;
          patterns.add('Unusually high amount');
        }

        // Check for provider switching
        final usualProvider = transactions[0]['provider'];
        if (provider != usualProvider) {
          riskScore += 0.2;
          patterns.add('Provider switching detected');
        }

        // Check for time pattern anomalies
        final now = DateTime.now();
        final hour = now.hour;
        final isUnusualHour = hour < 6 || hour > 22; // Outside 6 AM - 10 PM

        if (isUnusualHour && transactions.length > 5) {
          // Check if user usually transacts during business hours
          final businessHourTransactions = transactions.where((t) {
            final txTime = (t['createdAt'] as Timestamp).toDate();
            final txHour = txTime.hour;
            return txHour >= 6 && txHour <= 22;
          }).length;

          if (businessHourTransactions / transactions.length > 0.8) {
            riskScore += 0.2;
            patterns.add('Unusual transaction time');
          }
        }
      } else {
        // New user
        riskScore += 0.1;
        patterns.add('New user');
      }

      return {
        'riskScore': riskScore,
        'patterns': patterns,
        'isNewUser': userHistory.docs.isEmpty,
      };
    } catch (e) {
      return {'error': e.toString(), 'riskScore': 0.1};
    }
  }

  /// Check for amount pattern anomalies
  Future<Map<String, dynamic>> _checkAmountPatterns(
    String userId,
    double amount,
  ) async {
    try {
      final thirtyMinutesAgo = DateTime.now().subtract(
        const Duration(minutes: 30),
      );

      final recentTransactions = await _firestore
          .collection('mtn_transactions')
          .where('userId', isEqualTo: userId)
          .where(
            'createdAt',
            isGreaterThan: Timestamp.fromDate(thirtyMinutesAgo),
          )
          .get();

      double riskScore = 0.0;
      final patterns = <String>[];

      // Check for identical amounts in short time
      final identicalAmounts = recentTransactions.docs
          .where((doc) => (doc.data()['amount'] as num?)?.toDouble() == amount)
          .length;

      if (identicalAmounts >= _maxSimilarAmountsInWindow) {
        riskScore += 0.4;
        patterns.add('Identical amounts in short time window');
      }

      // Check for round number patterns (potential fraud)
      if (amount % 1000 == 0 && amount >= 10000) {
        riskScore += 0.2;
        patterns.add('Large round number amount');
      }

      // Check for amount progression (increasing amounts)
      if (recentTransactions.docs.length >= 3) {
        final amounts = recentTransactions.docs
            .map((doc) => (doc.data()['amount'] as num?)?.toDouble() ?? 0.0)
            .toList()
            .reversed
            .toList(); // Most recent first

        bool isIncreasing = true;
        for (int i = 1; i < amounts.length; i++) {
          if (amounts[i] <= amounts[i - 1]) {
            isIncreasing = false;
            break;
          }
        }

        if (isIncreasing && amounts.length >= 3) {
          riskScore += 0.3;
          patterns.add('Increasing amount pattern');
        }
      }

      return {
        'riskScore': riskScore,
        'patterns': patterns,
        'identicalAmounts': identicalAmounts,
      };
    } catch (e) {
      return {'error': e.toString(), 'riskScore': 0.1};
    }
  }

  /// Make final security decision based on risk score and violations
  Map<String, dynamic> _makeSecurityDecision(
    double riskScore,
    List<String> violations,
  ) {
    String riskLevel;
    bool allowed = true;
    String reason = 'Approved';
    final recommendations = <String>[];

    if (riskScore >= 0.8 || violations.isNotEmpty) {
      riskLevel = 'high';
      if (violations.isNotEmpty) {
        allowed = false;
        reason = 'Security violations detected: ${violations.join(", ")}';
      } else {
        reason = 'High risk score (${riskScore.toStringAsFixed(2)})';
        recommendations.add('Additional verification required');
      }
    } else if (riskScore >= 0.5) {
      riskLevel = 'medium';
      reason = 'Medium risk - monitoring recommended';
      recommendations.add('Monitor transaction closely');
    } else {
      riskLevel = 'low';
      reason = 'Low risk transaction';
    }

    return {
      'allowed': allowed,
      'riskLevel': riskLevel,
      'reason': reason,
      'recommendations': recommendations,
    };
  }

  /// Log security assessment for audit and analysis
  Future<void> _logSecurityAssessment({
    required String userId,
    required double amount,
    required String countryCode,
    required double riskScore,
    required Map<String, dynamic> securityChecks,
    required Map<String, dynamic> decision,
    required List<String> violations,
  }) async {
    try {
      await _firestore.collection('security_assessments').add({
        'userId': userId,
        'amount': amount,
        'countryCode': countryCode,
        'riskScore': riskScore,
        'riskLevel': decision['riskLevel'],
        'allowed': decision['allowed'],
        'reason': decision['reason'],
        'violations': violations,
        'securityChecks': securityChecks,
        'recommendations': decision['recommendations'],
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to log security assessment: $e');
      }
    }
  }

  /// Log security system errors
  Future<void> _logSecurityError(
    String userId,
    double amount,
    String error,
  ) async {
    try {
      await _firestore.collection('security_errors').add({
        'userId': userId,
        'amount': amount,
        'error': error,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to log security error: $e');
      }
    }
  }

  // Helper methods
  bool _validatePhoneFormat(String phoneNumber, String countryCode) {
    // Remove any non-digit characters except +
    phoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    switch (countryCode) {
      case 'NG':
        return RegExp(r'^(\+?234|0)[789]\d{9}$').hasMatch(phoneNumber);
      case 'GH':
        return RegExp(r'^(\+?233|0)[235]\d{8}$').hasMatch(phoneNumber);
      case 'UG':
        return RegExp(r'^(\+?256|0)[7]\d{8}$').hasMatch(phoneNumber);
      case 'RW':
        return RegExp(r'^(\+?250|0)[7]\d{8}$').hasMatch(phoneNumber);
      case 'ZM':
        return RegExp(r'^(\+?260|0)[9]\d{8}$').hasMatch(phoneNumber);
      case 'CI':
        return RegExp(r'^(\+?225|0)[0]\d{8}$').hasMatch(phoneNumber);
      case 'CM':
        return RegExp(r'^(\+?237|0)[679]\d{7}$').hasMatch(phoneNumber);
      case 'KE':
        return RegExp(r'^(\+?254|0)[17]\d{8}$').hasMatch(phoneNumber);
      default:
        return false;
    }
  }

  String _formatPhoneNumber(String phoneNumber, String countryCode) {
    phoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    final countryCodes = {
      'NG': '+234',
      'GH': '+233',
      'UG': '+256',
      'RW': '+250',
      'ZM': '+260',
      'CI': '+225',
      'CM': '+237',
      'KE': '+254',
    };

    final code = countryCodes[countryCode];
    if (code != null && phoneNumber.startsWith('0')) {
      return code + phoneNumber.substring(1);
    }

    return phoneNumber;
  }

  String _getCurrencyForCountry(String countryCode) {
    final currencies = {
      'NG': 'NGN',
      'GH': 'GHS',
      'UG': 'UGX',
      'RW': 'RWF',
      'ZM': 'ZMW',
      'CI': 'XOF',
      'CM': 'XAF',
      'KE': 'KES',
    };

    return currencies[countryCode] ?? 'USD';
  }

  Future<bool> _checkPhoneBlacklist(String phoneNumber) async {
    try {
      // Check against a blacklist collection
      final blacklistDoc = await _firestore
          .collection('phone_blacklist')
          .doc(phoneNumber)
          .get();

      return blacklistDoc.exists;
    } catch (e) {
      return false; // Fail-open
    }
  }

  Future<Map<String, dynamic>> _getPhoneTransactionHistory(
    String phoneNumber,
  ) async {
    try {
      final transactions = await _firestore
          .collection('mtn_transactions')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .get();

      final totalTransactions = transactions.docs.length;
      int successfulTransactions = 0;
      int failedTransactions = 0;
      int recentFailures = 0;

      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      for (final doc in transactions.docs) {
        final data = doc.data();
        final status = data['status'];
        final createdAt = (data['createdAt'] as Timestamp).toDate();

        if (status == 'credited') {
          successfulTransactions++;
        } else if (status == 'failed') {
          failedTransactions++;
          if (createdAt.isAfter(sevenDaysAgo)) {
            recentFailures++;
          }
        }
      }

      return {
        'totalTransactions': totalTransactions,
        'successfulTransactions': successfulTransactions,
        'failedTransactions': failedTransactions,
        'recentFailures': recentFailures,
        'failureRate': totalTransactions > 0
            ? failedTransactions / totalTransactions
            : 0.0,
      };
    } catch (e) {
      return {
        'totalTransactions': 0,
        'failureRate': 0.0,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _getDeviceTransactionHistory(
    String deviceFingerprint,
  ) async {
    try {
      final transactions = await _firestore
          .collection('mtn_transactions')
          .where('deviceFingerprint', isEqualTo: deviceFingerprint)
          .get();

      final uniqueUsers = transactions.docs
          .map((doc) => doc.data()['userId'] as String?)
          .where((userId) => userId != null)
          .toSet()
          .length;

      int successfulTransactions = 0;
      int failedTransactions = 0;

      for (final doc in transactions.docs) {
        final status = doc.data()['status'];
        if (status == 'credited') {
          successfulTransactions++;
        } else if (status == 'failed') {
          failedTransactions++;
        }
      }

      return {
        'totalTransactions': transactions.docs.length,
        'successfulTransactions': successfulTransactions,
        'failedTransactions': failedTransactions,
        'uniqueUsers': uniqueUsers,
        'failureRate': transactions.docs.length > 0
            ? failedTransactions / transactions.docs.length
            : 0.0,
      };
    } catch (e) {
      return {
        'totalTransactions': 0,
        'failureRate': 0.0,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _getLocationTransactionHistory(
    String userId,
    double latitude,
    double longitude,
  ) async {
    try {
      // Get user's historical transaction locations
      final userTransactions = await _firestore
          .collection('mtn_transactions')
          .where('userId', isEqualTo: userId)
          .where('location', isNotEqualTo: null)
          .limit(20)
          .get();

      final locations = <Map<String, double>>[];
      for (final doc in userTransactions.docs) {
        final data = doc.data();
        final location = data['location'] as Map<String, dynamic>?;
        if (location != null) {
          locations.add({
            'latitude': location['latitude'] as double,
            'longitude': location['longitude'] as double,
          });
        }
      }

      // Calculate if current location is unusual
      bool isUnusualLocation = true;
      double minDistance = double.infinity;

      for (final loc in locations) {
        final distance = _calculateDistance(
          latitude,
          longitude,
          loc['latitude']!,
          loc['longitude']!,
        );

        if (distance < minDistance) {
          minDistance = distance;
        }

        if (distance < 50) {
          // Within 50km
          isUnusualLocation = false;
          break;
        }
      }

      // Simple high-risk area check (this would be more sophisticated in production)
      final isHighRiskArea = _isHighRiskLocation(latitude, longitude);

      return {
        'isUnusualLocation': isUnusualLocation && locations.length > 3,
        'isHighRiskArea': isHighRiskArea,
        'distanceFromUsual': minDistance,
        'historicalLocationsCount': locations.length,
      };
    } catch (e) {
      return {
        'isUnusualLocation': false,
        'isHighRiskArea': false,
        'error': e.toString(),
      };
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  bool _isHighRiskLocation(double latitude, double longitude) {
    // Simplified high-risk area detection
    // In production, this would use a database of known high-risk areas
    // For now, just return false
    return false;
  }
}
