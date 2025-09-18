import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Enhanced mining session with cryptographic security and proof-of-work
class SecureMiningSession {
  final String sessionId;
  final DateTime sessionStart;
  final DateTime sessionEnd;
  final String userId;
  final String deviceId;
  final double miningRate;
  final String initialChallenge;
  final List<MiningProof> proofs;
  final String sessionHash;

  bool isPaused;
  DateTime? pausedAt;
  DateTime lastResume;
  int accumulatedSeconds;
  int totalProofsSubmitted;
  DateTime lastProofSubmission;
  String? serverValidationHash;

  SecureMiningSession({
    required this.sessionId,
    required this.sessionStart,
    required this.sessionEnd,
    required this.userId,
    required this.deviceId,
    required this.miningRate,
    required this.initialChallenge,
    required this.proofs,
    required this.sessionHash,
    required this.isPaused,
    this.pausedAt,
    required this.lastResume,
    required this.accumulatedSeconds,
    required this.totalProofsSubmitted,
    required this.lastProofSubmission,
    this.serverValidationHash,
  });

  /// Factory constructor for new secure mining session
  factory SecureMiningSession.newSession({
    required String userId,
    required String deviceId,
    required double miningRate,
    int? durationMinutes,
  }) {
    final now = DateTime.now();
    // EXACTLY 24 hours for 6 AKOFA total
    final duration = const Duration(hours: 24);

    final sessionId = _generateSecureSessionId(userId, deviceId, now);
    final initialChallenge = _generateChallenge();
    final sessionHash = _generateSessionHash(userId, deviceId, sessionId, now);

    return SecureMiningSession(
      sessionId: sessionId,
      sessionStart: now,
      sessionEnd: now.add(duration),
      userId: userId,
      deviceId: deviceId,
      miningRate: miningRate,
      initialChallenge: initialChallenge,
      proofs: [],
      sessionHash: sessionHash,
      isPaused: false,
      pausedAt: null,
      lastResume: now,
      accumulatedSeconds: 0,
      totalProofsSubmitted: 0,
      lastProofSubmission: now,
    );
  }

  /// Generate cryptographically secure session ID
  static String _generateSecureSessionId(
    String userId,
    String deviceId,
    DateTime timestamp,
  ) {
    final random = Random.secure();
    final nonce = List.generate(16, (_) => random.nextInt(256));
    final input =
        '$userId:$deviceId:${timestamp.millisecondsSinceEpoch}:${nonce.join('')}';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generate mining challenge for proof-of-work
  static String _generateChallenge() {
    final random = Random.secure();
    final bytes = List.generate(32, (_) => random.nextInt(256));
    return sha256.convert(bytes).toString();
  }

  /// Generate session integrity hash
  static String _generateSessionHash(
    String userId,
    String deviceId,
    String sessionId,
    DateTime timestamp,
  ) {
    final input =
        '$userId:$deviceId:$sessionId:${timestamp.millisecondsSinceEpoch}';
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Start mining with cryptographic proof
  void startMining() {
    if (isPaused) {
      resumeMining();
    } else {
      isPaused = false;
      lastResume = DateTime.now();
      pausedAt = null;
      lastProofSubmission = DateTime.now();
    }
  }

  /// Pause mining with state verification
  void pauseMining() {
    if (!isPaused && isActive) {
      isPaused = true;
      pausedAt = DateTime.now();

      // Calculate accurate accumulated time
      final timeSinceResume = DateTime.now().difference(lastResume).inSeconds;
      accumulatedSeconds += timeSinceResume;

      // Submit pause proof
      submitProof('pause', timeSinceResume);
    }
  }

  /// Resume mining with integrity check
  void resumeMining() {
    if (isPaused && !isExpired) {
      isPaused = false;
      lastResume = DateTime.now();
      pausedAt = null;

      // Submit resume proof
      submitProof('resume', 0);
    }
  }

  /// Submit cryptographic proof of mining work
  void submitProof(String action, int seconds) {
    final timestamp = DateTime.now();
    final nonce = _generateNonce();
    final challenge = getCurrentChallenge();

    final proof = MiningProof(
      timestamp: timestamp,
      action: action,
      seconds: seconds,
      nonce: nonce,
      challenge: challenge,
      proofHash: _calculateProofHash(
        action,
        seconds,
        nonce,
        challenge,
        timestamp,
      ),
    );

    proofs.add(proof);
    totalProofsSubmitted++;
    lastProofSubmission = timestamp;
  }

  /// Submit advanced proof with custom nonce and difficulty
  void submitAdvancedProof(
    String action,
    int seconds,
    String customNonce,
    String customHash,
    int difficulty,
  ) {
    final timestamp = DateTime.now();
    final challenge = getCurrentChallenge();

    final proof = MiningProof(
      timestamp: timestamp,
      action: action,
      seconds: seconds,
      nonce: customNonce,
      challenge: challenge,
      proofHash: customHash,
      difficulty: difficulty,
    );

    proofs.add(proof);
    totalProofsSubmitted++;
    lastProofSubmission = timestamp;
  }

  /// Generate cryptographic nonce for proof
  String _generateNonce() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    return base64.encode(bytes);
  }

  /// Get current mining challenge
  String getCurrentChallenge() {
    // Rotate challenge every hour for security
    final hoursSinceStart = DateTime.now().difference(sessionStart).inHours;
    final input = '$initialChallenge:$hoursSinceStart';
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Calculate proof-of-work hash
  String _calculateProofHash(
    String action,
    int seconds,
    String nonce,
    String challenge,
    DateTime timestamp,
  ) {
    final input =
        '$sessionId:$action:$seconds:$nonce:$challenge:${timestamp.millisecondsSinceEpoch}';
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Validate proof integrity
  bool validateProof(MiningProof proof) {
    final expectedHash = _calculateProofHash(
      proof.action,
      proof.seconds,
      proof.nonce,
      proof.challenge,
      proof.timestamp,
    );
    return expectedHash == proof.proofHash;
  }

  /// Calculate earned AKOFA based on elapsed time (countdown approach)
  double get earnedAkofa {
    // Calculate earnings based on elapsed time since session start
    // miningRate is in AKOFA per hour (0.25 AKOFA/hour)
    final hoursElapsed = accumulatedSeconds / 3600.0;

    // EXACT MINING RATE: 0.25 AKOFA per hour
    // This means 6 AKOFA after 24 hours (0.25 * 24 = 6)
    final baseEarnings = miningRate * hoursElapsed;

    // Ensure earnings don't exceed the maximum possible for the 24-hour session
    final maxPossibleEarnings = miningRate * 24.0; // 24 hours maximum

    // Return earnings clamped to maximum possible
    return baseEarnings.clamp(0.0, maxPossibleEarnings);
  }

  /// Check if session is actively mining
  bool get isActive => !isPaused && DateTime.now().isBefore(sessionEnd);

  /// Check if session has expired
  bool get isExpired => DateTime.now().isAfter(sessionEnd);

  /// Validate session integrity
  bool get isValid {
    // Check session hash integrity
    final expectedSessionHash = _generateSessionHash(
      userId,
      deviceId,
      sessionId,
      sessionStart,
    );
    if (expectedSessionHash != sessionHash) return false;

    // Check proof frequency (should submit proof at least every 5 minutes)
    final now = DateTime.now();
    if (!isPaused && now.difference(lastProofSubmission).inMinutes > 5)
      return false;

    // Validate accumulated time doesn't exceed session duration
    final maxPossibleSeconds = now.difference(sessionStart).inSeconds;
    if (accumulatedSeconds > maxPossibleSeconds) return false;

    return true;
  }

  /// Get security metrics for monitoring
  Map<String, dynamic> get securityMetrics => {
    'totalProofs': totalProofsSubmitted,
    'validProofs': proofs.where((p) => validateProof(p)).length,
    'proofFrequency': proofs.isEmpty ? 0 : accumulatedSeconds / proofs.length,
    'lastProofAge': DateTime.now().difference(lastProofSubmission).inMinutes,
    'integrityScore': isValid ? 1.0 : 0.0,
  };

  /// Get current mining rate (AKOFA per hour)
  double get currentMiningRate => miningRate;

  /// Get current earnings rate (AKOFA per hour based on actual performance)
  double get currentEarningsRate {
    if (accumulatedSeconds == 0) return 0.0;

    final hoursMined = accumulatedSeconds / 3600.0;
    if (hoursMined == 0) return 0.0;

    return earnedAkofa / hoursMined;
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'sessionStart': sessionStart.toIso8601String(),
    'sessionEnd': sessionEnd.toIso8601String(),
    'userId': userId,
    'deviceId': deviceId,
    'miningRate': miningRate,
    'initialChallenge': initialChallenge,
    'proofs': proofs.map((p) => p.toJson()).toList(),
    'sessionHash': sessionHash,
    'isPaused': isPaused,
    'pausedAt': pausedAt?.toIso8601String(),
    'lastResume': lastResume.toIso8601String(),
    'accumulatedSeconds': accumulatedSeconds,
    'totalProofsSubmitted': totalProofsSubmitted,
    'lastProofSubmission': lastProofSubmission.toIso8601String(),
    'serverValidationHash': serverValidationHash,
  };

  /// Create from JSON
  factory SecureMiningSession.fromJson(Map<String, dynamic> json) {
    return SecureMiningSession(
      sessionId: json['sessionId'],
      sessionStart: DateTime.parse(json['sessionStart']),
      sessionEnd: DateTime.parse(json['sessionEnd']),
      userId: json['userId'],
      deviceId: json['deviceId'],
      miningRate: (json['miningRate'] as num).toDouble(),
      initialChallenge: json['initialChallenge'],
      proofs: (json['proofs'] as List)
          .map((p) => MiningProof.fromJson(p))
          .toList(),
      sessionHash: json['sessionHash'],
      isPaused: json['isPaused'],
      pausedAt: json['pausedAt'] != null
          ? DateTime.parse(json['pausedAt'])
          : null,
      lastResume: DateTime.parse(json['lastResume']),
      accumulatedSeconds: json['accumulatedSeconds'],
      totalProofsSubmitted: json['totalProofsSubmitted'],
      lastProofSubmission: DateTime.parse(json['lastProofSubmission']),
      serverValidationHash: json['serverValidationHash'],
    );
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() => {
    ...toJson(),
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

/// Cryptographic proof of mining work
class MiningProof {
  final DateTime timestamp;
  final String action;
  final int seconds;
  final String nonce;
  final String challenge;
  final String proofHash;
  final int? difficulty; // Mining difficulty for advanced algorithms

  const MiningProof({
    required this.timestamp,
    required this.action,
    required this.seconds,
    required this.nonce,
    required this.challenge,
    required this.proofHash,
    this.difficulty,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'action': action,
    'seconds': seconds,
    'nonce': nonce,
    'challenge': challenge,
    'proofHash': proofHash,
    'difficulty': difficulty,
  };

  factory MiningProof.fromJson(Map<String, dynamic> json) {
    return MiningProof(
      timestamp: DateTime.parse(json['timestamp']),
      action: json['action'],
      seconds: json['seconds'],
      nonce: json['nonce'],
      challenge: json['challenge'],
      proofHash: json['proofHash'],
      difficulty: json['difficulty'],
    );
  }
}

/// Enhanced mining session history with security audit trail
class SecureMiningSessionHistory {
  final String id;
  final String userId;
  final String sessionId;
  final DateTime sessionStart;
  final DateTime sessionEnd;
  final double earnedAkofa;
  final String status;
  final String? transactionId;
  final String? stellarHash;
  final Map<String, dynamic> securityMetrics;
  final List<String> securityFlags;
  final String validationHash;

  SecureMiningSessionHistory({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.sessionStart,
    required this.sessionEnd,
    required this.earnedAkofa,
    required this.status,
    this.transactionId,
    this.stellarHash,
    required this.securityMetrics,
    required this.securityFlags,
    required this.validationHash,
  });

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'sessionId': sessionId,
    'sessionStart': sessionStart.toIso8601String(),
    'sessionEnd': sessionEnd.toIso8601String(),
    'earnedAkofa': earnedAkofa,
    'status': status,
    'transactionId': transactionId,
    'stellarHash': stellarHash,
    'securityMetrics': securityMetrics,
    'securityFlags': securityFlags,
    'validationHash': validationHash,
    'createdAt': FieldValue.serverTimestamp(),
  };

  factory SecureMiningSessionHistory.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return SecureMiningSessionHistory(
      id: id,
      userId: data['userId'] ?? '',
      sessionId: data['sessionId'] ?? '',
      sessionStart: DateTime.parse(data['sessionStart']),
      sessionEnd: DateTime.parse(data['sessionEnd']),
      earnedAkofa: (data['earnedAkofa'] ?? 0).toDouble(),
      status: data['status'] ?? 'pending',
      transactionId: data['transactionId'],
      stellarHash: data['stellarHash'],
      securityMetrics: Map<String, dynamic>.from(data['securityMetrics'] ?? {}),
      securityFlags: List<String>.from(data['securityFlags'] ?? []),
      validationHash: data['validationHash'] ?? '',
    );
  }
}
