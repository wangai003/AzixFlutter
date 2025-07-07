import 'dart:convert';

class MiningSession {
  final String sessionId;
  final DateTime sessionStart;
  final DateTime sessionEnd;
  bool isPaused;
  DateTime? pausedAt;
  int accumulatedSeconds; // Total seconds mined so far in this session
  DateTime lastResume;
  final double miningRate; // Akofa/hour

  MiningSession({
    required this.sessionId,
    required this.sessionStart,
    required this.sessionEnd,
    required this.isPaused,
    this.pausedAt,
    required this.accumulatedSeconds,
    required this.lastResume,
    required this.miningRate,
  });

  factory MiningSession.newSession({required double miningRate, int? durationMinutes}) {
    final now = DateTime.now();
    final duration = durationMinutes != null 
        ? Duration(minutes: durationMinutes)
        : const Duration(hours: 24);
    
    return MiningSession(
      sessionId: now.millisecondsSinceEpoch.toString(),
      sessionStart: now,
      sessionEnd: now.add(duration),
      isPaused: false,
      pausedAt: null,
      accumulatedSeconds: 0,
      lastResume: now,
      miningRate: miningRate,
    );
  }

  // Start mining
  void startMining() {
    if (isPaused) {
      resumeMining();
    } else {
      isPaused = false;
      lastResume = DateTime.now();
      pausedAt = null;
    }
  }

  // Pause mining
  void pauseMining() {
    if (!isPaused && isActive) {
      isPaused = true;
      pausedAt = DateTime.now();
      // Add accumulated time from last resume to now
      final timeSinceResume = DateTime.now().difference(lastResume).inSeconds;
      accumulatedSeconds += timeSinceResume;
    }
  }

  // Resume mining
  void resumeMining() {
    if (isPaused && !isExpired) {
      isPaused = false;
      lastResume = DateTime.now();
      pausedAt = null;
    }
  }

  double get earnedAkofa {
    return miningRate * (accumulatedSeconds / 3600.0);
  }

  bool get isActive => !isPaused && DateTime.now().isBefore(sessionEnd);
  bool get isExpired => DateTime.now().isAfter(sessionEnd);

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'sessionStart': sessionStart.toIso8601String(),
        'sessionEnd': sessionEnd.toIso8601String(),
        'isPaused': isPaused,
        'pausedAt': pausedAt?.toIso8601String(),
        'accumulatedSeconds': accumulatedSeconds,
        'lastResume': lastResume.toIso8601String(),
        'miningRate': miningRate,
      };

  factory MiningSession.fromJson(Map<String, dynamic> json) {
    return MiningSession(
      sessionId: json['sessionId'],
      sessionStart: DateTime.parse(json['sessionStart']),
      sessionEnd: DateTime.parse(json['sessionEnd']),
      isPaused: json['isPaused'],
      pausedAt: json['pausedAt'] != null ? DateTime.parse(json['pausedAt']) : null,
      accumulatedSeconds: json['accumulatedSeconds'],
      lastResume: DateTime.parse(json['lastResume']),
      miningRate: (json['miningRate'] as num).toDouble(),
    );
  }

  String toRawJson() => jsonEncode(toJson());
  factory MiningSession.fromRawJson(String str) => MiningSession.fromJson(jsonDecode(str));

  Map<String, dynamic> toJsonForFirestore(String userId) => {
        'userId': userId,
        'sessionId': sessionId,
        'sessionStart': sessionStart.toIso8601String(),
        'sessionEnd': sessionEnd.toIso8601String(),
        'isPaused': isPaused,
        'pausedAt': pausedAt?.toIso8601String(),
        'accumulatedSeconds': accumulatedSeconds,
        'lastResume': lastResume.toIso8601String(),
        'miningRate': miningRate,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  static MiningSession fromFirestore(Map<String, dynamic> json) {
    return MiningSession(
      sessionId: json['sessionId'],
      sessionStart: DateTime.parse(json['sessionStart']),
      sessionEnd: DateTime.parse(json['sessionEnd']),
      isPaused: json['isPaused'],
      pausedAt: json['pausedAt'] != null ? DateTime.parse(json['pausedAt']) : null,
      accumulatedSeconds: json['accumulatedSeconds'],
      lastResume: DateTime.parse(json['lastResume']),
      miningRate: (json['miningRate'] as num).toDouble(),
    );
  }
}

class MiningSessionHistory {
  final String id;
  final String userId;
  final DateTime sessionStart;
  final DateTime sessionEnd;
  final double earnedAkofa;
  final String status; // completed, failed, etc.
  final String? transactionId; // Firestore transaction doc id
  final String? stellarHash; // Stellar transaction hash if available

  MiningSessionHistory({
    required this.id,
    required this.userId,
    required this.sessionStart,
    required this.sessionEnd,
    required this.earnedAkofa,
    required this.status,
    this.transactionId,
    this.stellarHash,
  });

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'sessionStart': sessionStart.toIso8601String(),
        'sessionEnd': sessionEnd.toIso8601String(),
        'earnedAkofa': earnedAkofa,
        'status': status,
        'transactionId': transactionId,
        'stellarHash': stellarHash,
      };

  factory MiningSessionHistory.fromFirestore(String id, Map<String, dynamic> data) {
    return MiningSessionHistory(
      id: id,
      userId: data['userId'] ?? '',
      sessionStart: DateTime.parse(data['sessionStart']),
      sessionEnd: DateTime.parse(data['sessionEnd']),
      earnedAkofa: (data['earnedAkofa'] ?? 0).toDouble(),
      status: data['status'] ?? 'completed',
      transactionId: data['transactionId'],
      stellarHash: data['stellarHash'],
    );
  }
} 