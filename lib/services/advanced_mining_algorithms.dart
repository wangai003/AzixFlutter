import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/secure_mining_session.dart';

/// Advanced mining algorithms with dynamic difficulty and proof-of-work verification
class AdvancedMiningAlgorithms {
  // Difficulty parameters
  static const int _minDifficulty = 1;
  static const int _maxDifficulty = 24;
  static const int _targetBlockTimeSeconds = 300; // 5 minutes
  static const int _difficultyAdjustmentInterval = 10; // Adjust every 10 proofs

  // Algorithm parameters
  static const int _scryptRounds = 2;
  static const int _argon2Rounds = 3;
  static const int _multiHashRounds = 3;

  // Performance tracking
  final Map<String, MiningPerformance> _performanceMetrics = {};
  final List<int> _recentBlockTimes = [];
  int _currentDifficulty = 8; // Start with moderate difficulty
  int _proofCount = 0;

  // Security enhancements
  final Map<String, Map<String, dynamic>> _proofTimestamps = {};
  final Map<String, Map<String, dynamic>> _deviceFingerprints = {};
  final Map<String, Map<String, dynamic>> _poolPatterns = {};
  static const int _maxProofAgeMinutes = 30; // Maximum age for proof validation
  static const int _minProofIntervalSeconds = 10; // Minimum time between proofs
  static const int _poolDetectionThreshold = 5; // Suspicious pattern threshold

  /// Mine with advanced proof-of-work algorithm
  Future<MiningResult> mineAdvanced({
    required String sessionId,
    required String challenge,
    required int targetDifficulty,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final startTime = DateTime.now();
    int iterations = 0;
    String? winningNonce;
    String? winningHash;

    try {
      // Use true random nonce generation for enhanced security
      final nonceGenerator = TrueRandomNonceGenerator(sessionId, challenge);

      await Future.doWhile(() async {
        if (DateTime.now().difference(startTime) > timeout) {
          return false; // Timeout
        }

        final nonce = nonceGenerator.next();
        final hash = await _computeAdvancedHash(sessionId, challenge, nonce);
        iterations++;

        // Check if hash meets difficulty requirement
        if (_meetsDifficulty(hash, targetDifficulty)) {
          winningNonce = nonce;
          winningHash = hash;
          return false; // Found solution
        }

        return true; // Continue mining
      });

      final duration = DateTime.now().difference(startTime);

      return MiningResult(
        success: winningNonce != null,
        nonce: winningNonce,
        hash: winningHash,
        iterations: iterations,
        duration: duration,
        difficulty: targetDifficulty,
        hashrate: iterations / duration.inSeconds,
      );
    } catch (e) {
      return MiningResult(
        success: false,
        nonce: null,
        hash: null,
        iterations: iterations,
        duration: DateTime.now().difference(startTime),
        difficulty: targetDifficulty,
        hashrate: 0,
        error: e.toString(),
      );
    }
  }

  /// Compute advanced multi-algorithm hash
  Future<String> _computeAdvancedHash(
    String sessionId,
    String challenge,
    String nonce,
  ) async {
    // Multi-round hashing for increased computational complexity
    String currentHash = '$sessionId:$challenge:$nonce';

    for (int round = 0; round < _multiHashRounds; round++) {
      // Round 1: SHA256
      final sha256Hash = sha256.convert(utf8.encode(currentHash)).toString();

      // Round 2: Scrypt-like (simplified for mobile performance)
      final scryptHash = await _scryptLike(sha256Hash, round);

      // Round 3: Argon2-like (simplified)
      final argonHash = await _argon2Like(scryptHash, round);

      currentHash = argonHash;
    }

    return currentHash;
  }

  /// Scrypt-like algorithm (simplified for performance)
  Future<String> _scryptLike(String input, int round) async {
    final inputBytes = utf8.encode(input);
    final salt = Uint8List.fromList(
      inputBytes.sublist(0, min(16, inputBytes.length)),
    );

    // Simplified scrypt-like: multiple rounds of PBKDF2-like operations
    var result = input;
    for (int i = 0; i < _scryptRounds; i++) {
      final key = '$result:${salt.join()}:$i:$round';
      result = sha256.convert(utf8.encode(key)).toString();
    }

    return result;
  }

  /// Argon2-like algorithm (simplified for performance)
  Future<String> _argon2Like(String input, int round) async {
    final bytes = utf8.encode(input);

    // Simplified Argon2-like: memory-hard function simulation
    var result = input;
    final blocks = <String>[];

    // Create memory blocks
    for (int i = 0; i < _argon2Rounds; i++) {
      final block = sha256.convert(utf8.encode('$result:$i:$round')).toString();
      blocks.add(block);
    }

    // Mix blocks (simplified Argon2 approach)
    for (int i = 1; i < blocks.length; i++) {
      final prevBlock = blocks[i - 1];
      final currentBlock = blocks[i];
      final mixed = sha256
          .convert(utf8.encode('$prevBlock:$currentBlock:$round'))
          .toString();
      blocks[i] = mixed;
    }

    return blocks.last;
  }

  /// Check if hash meets difficulty requirement (optimized)
  bool _meetsDifficulty(String hash, int difficulty) {
    if (difficulty <= 0) return true;
    if (hash.length < difficulty) return false;

    // Fast check: use substring comparison for better performance
    final requiredPrefix = '0' * difficulty;
    return hash.startsWith(requiredPrefix);
  }

  /// Fast difficulty check using byte comparison
  bool meetsDifficultyFast(Uint8List hashBytes, int difficulty) {
    if (difficulty <= 0) return true;
    if (hashBytes.isEmpty) return false;

    int remainingBits = difficulty;

    for (final byte in hashBytes) {
      if (byte == 0) {
        remainingBits -= 8;
        if (remainingBits <= 0) return true;
      } else {
        // Count leading zeros in this byte
        int leadingZeros = 0;
        int mask = 0x80; // 10000000
        while ((byte & mask) == 0 && leadingZeros < 8) {
          leadingZeros++;
          mask >>= 1;
        }
        remainingBits -= leadingZeros;
        if (remainingBits <= 0) return true;
        break; // Non-zero byte found, stop checking
      }
    }

    return false;
  }

  /// Adjust difficulty based on recent performance
  int adjustDifficulty() {
    if (_recentBlockTimes.length < _difficultyAdjustmentInterval) {
      return _currentDifficulty;
    }

    // Calculate average block time
    final avgBlockTime =
        _recentBlockTimes.reduce((a, b) => a + b) / _recentBlockTimes.length;

    // Target adjustment
    const targetTime = _targetBlockTimeSeconds;
    final ratio = avgBlockTime / targetTime;

    // Adjust difficulty (dampened adjustment)
    if (ratio < 0.8) {
      // Blocks too fast, increase difficulty
      _currentDifficulty = min(_currentDifficulty + 1, _maxDifficulty);
    } else if (ratio > 1.2) {
      // Blocks too slow, decrease difficulty
      _currentDifficulty = max(_currentDifficulty - 1, _minDifficulty);
    }

    // Clear old block times
    _recentBlockTimes.clear();

    return _currentDifficulty;
  }

  /// Record block time for difficulty adjustment
  void recordBlockTime(int seconds) {
    _recentBlockTimes.add(seconds);
    _proofCount++;

    // Adjust difficulty periodically
    if (_proofCount % _difficultyAdjustmentInterval == 0) {
      adjustDifficulty();
    }
  }

  /// Get current mining statistics
  MiningStats getMiningStats() {
    final totalTime = _recentBlockTimes.isNotEmpty
        ? _recentBlockTimes.reduce((a, b) => a + b)
        : 0;

    final avgBlockTime = _recentBlockTimes.isNotEmpty
        ? totalTime / _recentBlockTimes.length
        : 0.0;

    return MiningStats(
      currentDifficulty: _currentDifficulty,
      averageBlockTime: avgBlockTime,
      totalProofs: _proofCount,
      performanceMetrics: Map.from(_performanceMetrics),
    );
  }

  /// Benchmark mining performance
  Future<MiningBenchmark> benchmarkMining({
    int testDurationSeconds = 10,
    int difficulty = 8,
  }) async {
    final startTime = DateTime.now();
    int totalIterations = 0;
    final results = <MiningResult>[];

    final testChallenge = _generateTestChallenge();
    final sessionId = 'benchmark_${DateTime.now().millisecondsSinceEpoch}';

    // Run multiple mining operations
    while (DateTime.now().difference(startTime).inSeconds <
        testDurationSeconds) {
      final result = await mineAdvanced(
        sessionId: sessionId,
        challenge: testChallenge,
        targetDifficulty: difficulty,
        timeout: const Duration(seconds: 2),
      );

      if (result.success) {
        results.add(result);
        totalIterations += result.iterations;
      }
    }

    final totalDuration = DateTime.now().difference(startTime);
    final hashrate = totalIterations / totalDuration.inSeconds;

    return MiningBenchmark(
      totalIterations: totalIterations,
      totalDuration: totalDuration,
      hashrate: hashrate,
      successfulProofs: results.length,
      averageDifficulty: difficulty,
      results: results,
    );
  }

  /// Generate test challenge for benchmarking
  String _generateTestChallenge() {
    final random = Random.secure();
    final bytes = List.generate(32, (_) => random.nextInt(256));
    return sha256.convert(bytes).toString();
  }

  /// Get optimal difficulty for target performance
  Future<int> getOptimalDifficulty({
    required Duration targetTime,
    int maxAttempts = 5,
  }) async {
    int testDifficulty = _currentDifficulty;
    final results = <Map<String, dynamic>>[];

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final benchmark = await benchmarkMining(
        testDurationSeconds: 5,
        difficulty: testDifficulty,
      );

      results.add({
        'difficulty': testDifficulty,
        'hashrate': benchmark.hashrate,
        'duration': benchmark.totalDuration.inSeconds,
      });

      // Adjust difficulty based on performance
      if (benchmark.totalDuration > targetTime) {
        testDifficulty = max(1, testDifficulty - 1);
      } else {
        testDifficulty = min(_maxDifficulty, testDifficulty + 1);
      }
    }

    return testDifficulty;
  }

  /// Batch validate multiple proofs for better performance
  Future<List<bool>> validateProofsBatch(List<MiningProof> proofs) async {
    final results = <bool>[];
    const batchSize = 10; // Process in batches to avoid blocking UI

    for (int i = 0; i < proofs.length; i += batchSize) {
      final end = min(i + batchSize, proofs.length);
      final batch = proofs.sublist(i, end);

      final batchResults = await Future.wait(
        batch.map((proof) => _validateProofOptimized(proof)),
      );

      results.addAll(batchResults);

      // Yield control to UI thread
      if (i % (batchSize * 5) == 0) {
        await Future.delayed(Duration.zero);
      }
    }

    return results;
  }

  /// Optimized single proof validation with enhanced security
  Future<bool> _validateProofOptimized(MiningProof proof) async {
    try {
      // Enhanced timestamp validation (prevent replay attacks)
      if (!await _validateProofTimestamp(proof)) {
        return false;
      }

      // Check for mining pool patterns
      if (await _detectMiningPoolActivity(proof)) {
        return false; // Suspicious pool activity detected
      }

      // Validate hash format
      if (proof.proofHash.length != 64) {
        return false; // Invalid hash length
      }

      // Reconstruct expected hash using available proof data
      final input =
          '${proof.action}:${proof.seconds}:${proof.nonce}:${proof.challenge}:${proof.timestamp.millisecondsSinceEpoch}';
      final expectedHash = sha256.convert(utf8.encode(input)).toString();

      return expectedHash == proof.proofHash;
    } catch (e) {
      return false;
    }
  }

  /// Validate proof timestamp to prevent replay attacks
  Future<bool> _validateProofTimestamp(MiningProof proof) async {
    final now = DateTime.now();
    final age = now.difference(proof.timestamp);

    // Check maximum age
    if (age > const Duration(minutes: _maxProofAgeMinutes)) {
      return false; // Proof too old
    }

    // Check minimum interval between proofs (prevent spam)
    final proofKey = '${proof.action}_${proof.challenge}';
    final lastProofTime = _proofTimestamps[proofKey]?['timestamp'] as DateTime?;

    if (lastProofTime != null) {
      final interval = proof.timestamp.difference(lastProofTime);
      if (interval < const Duration(seconds: _minProofIntervalSeconds)) {
        return false; // Proof submitted too quickly
      }
    }

    // Update timestamp tracking
    _proofTimestamps[proofKey] = {
      'timestamp': proof.timestamp,
      'count': ((_proofTimestamps[proofKey]?['count'] as int?) ?? 0) + 1,
    };

    // Clean old entries
    _cleanupOldTimestamps();

    return true;
  }

  /// Detect mining pool activity patterns
  Future<bool> _detectMiningPoolActivity(MiningProof proof) async {
    final deviceId = await _getDeviceFingerprint();
    final patternKey = '${proof.challenge}_${deviceId}';

    // Track proof patterns
    if (!_poolPatterns.containsKey(patternKey)) {
      _poolPatterns[patternKey] = {
        'proofs': <DateTime>[],
        'frequency': 0.0,
        'lastActivity': DateTime.now(),
      };
    }

    final pattern = _poolPatterns[patternKey]!;
    final proofs = pattern['proofs'] as List<DateTime>;
    proofs.add(proof.timestamp);

    // Keep only recent proofs (last hour)
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    proofs.removeWhere((time) => time.isBefore(oneHourAgo));

    // Calculate frequency (proofs per minute)
    final frequency = proofs.length / 60.0; // per minute
    pattern['frequency'] = frequency;

    // Detect suspicious patterns
    if (frequency > _poolDetectionThreshold) {
      // High frequency suggests automated mining (pool)
      return true;
    }

    // Check for identical timing patterns (coordinated mining)
    if (proofs.length >= 3) {
      final intervals = <int>[];
      for (int i = 1; i < proofs.length; i++) {
        intervals.add(proofs[i].difference(proofs[i - 1]).inSeconds);
      }

      // Check if intervals are too regular (automated pattern)
      final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
      final variance =
          intervals
              .map((i) => (i - avgInterval).abs())
              .reduce((a, b) => a + b) /
          intervals.length;

      if (variance < 2.0) {
        // Very regular intervals suggest automation
        return true;
      }
    }

    return false;
  }

  /// Get device fingerprint for enhanced tracking
  Future<String> _getDeviceFingerprint() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final fingerprint =
            '${androidInfo.id}_${androidInfo.brand}_${androidInfo.model}';
        return sha256.convert(utf8.encode(fingerprint)).toString();
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        final fingerprint = '${iosInfo.identifierForVendor}_${iosInfo.model}';
        return sha256.convert(utf8.encode(fingerprint)).toString();
      } else {
        // Web or other platforms
        final webFingerprint =
            '${Platform.operatingSystem}_${Platform.localHostname}';
        return sha256.convert(utf8.encode(webFingerprint)).toString();
      }
    } catch (e) {
      // Fallback fingerprint
      final fallback =
          '${Platform.operatingSystem}_${DateTime.now().millisecondsSinceEpoch}';
      return sha256.convert(utf8.encode(fallback)).toString();
    }
  }

  /// Clean up old timestamp entries
  void _cleanupOldTimestamps() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    _proofTimestamps.removeWhere((key, value) {
      final timestamp = value['timestamp'] as DateTime?;
      return timestamp == null || timestamp.isBefore(cutoff);
    });

    _poolPatterns.removeWhere((key, value) {
      final lastActivity = value['lastActivity'] as DateTime?;
      return lastActivity == null || lastActivity.isBefore(cutoff);
    });
  }

  /// Get security metrics for monitoring
  Map<String, dynamic> getSecurityMetrics() {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));

    // Count suspicious activities in last hour
    int suspiciousTimestamps = 0;
    int poolPatterns = 0;

    for (final entry in _proofTimestamps.values) {
      final timestamp = entry['timestamp'] as DateTime?;
      if (timestamp != null && timestamp.isAfter(oneHourAgo)) {
        final count = entry['count'] as int? ?? 0;
        if (count > _poolDetectionThreshold) {
          suspiciousTimestamps++;
        }
      }
    }

    for (final pattern in _poolPatterns.values) {
      final frequency = pattern['frequency'] as double? ?? 0.0;
      if (frequency > _poolDetectionThreshold) {
        poolPatterns++;
      }
    }

    return {
      'totalProofsTracked': _proofTimestamps.length,
      'suspiciousTimestamps': suspiciousTimestamps,
      'miningPoolPatterns': poolPatterns,
      'deviceFingerprints': _deviceFingerprints.length,
      'securityStatus': (suspiciousTimestamps + poolPatterns) == 0
          ? 'secure'
          : 'warning',
    };
  }

  /// Validate proof with difficulty check
  Future<bool> validateProofWithDifficulty(
    MiningProof proof,
    int requiredDifficulty,
  ) async {
    final isValid = await _validateProofOptimized(proof);

    if (!isValid) return false;

    // Additional difficulty validation if proof has difficulty info
    if (proof.difficulty != null) {
      return proof.difficulty! >= requiredDifficulty;
    }

    // Fallback: check hash difficulty
    return _meetsDifficulty(proof.proofHash, requiredDifficulty);
  }
}

/// True random nonce generator with entropy mixing
class TrueRandomNonceGenerator {
  final String sessionId;
  final String challenge;
  int _counter = 0;

  TrueRandomNonceGenerator(this.sessionId, this.challenge);

  String next() {
    _counter++;

    // Generate true random nonce with multiple entropy sources
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random1 = Random.secure();
    final random2 = Random(
      timestamp,
    ); // Seed with timestamp for additional entropy

    // Generate 32 bytes of entropy (256-bit security)
    final entropy = List<int>.generate(32, (i) {
      // Mix multiple random sources
      final byte1 = random1.nextInt(256);
      final byte2 = random2.nextInt(256);
      final byte3 =
          (timestamp >> (i * 8)) & 0xFF; // Extract bytes from timestamp

      // XOR all sources together for maximum entropy
      return byte1 ^ byte2 ^ byte3;
    });

    // Add process-specific entropy if available
    final processId = pid ?? 0;
    for (int i = 0; i < entropy.length; i++) {
      entropy[i] = entropy[i] ^ ((processId >> (i % 4) * 8) & 0xFF);
    }

    // Add session and challenge data for uniqueness
    final sessionBytes = utf8.encode(sessionId);
    final challengeBytes = utf8.encode(challenge);
    final counterBytes = utf8.encode(_counter.toString());

    final combined = [
      ...entropy,
      ...sessionBytes,
      ...challengeBytes,
      ...counterBytes,
    ];

    return base64.encode(combined);
  }
}

/// Structured nonce generator for optimized mining (legacy)
class StructuredNonceGenerator {
  final String sessionId;
  final String challenge;
  int _counter = 0;
  final Random _random = Random.secure();

  StructuredNonceGenerator(this.sessionId, this.challenge);

  String next() {
    _counter++;

    // Combine counter with random bytes for structured nonce
    final counterBytes = utf8.encode(_counter.toString());
    final randomBytes = List.generate(8, (_) => _random.nextInt(256));
    final sessionBytes = utf8.encode(sessionId);
    final challengeBytes = utf8.encode(challenge);

    final combined = [
      ...counterBytes,
      ...randomBytes,
      ...sessionBytes,
      ...challengeBytes,
    ];
    return base64.encode(combined);
  }
}

/// Mining result data class
class MiningResult {
  final bool success;
  final String? nonce;
  final String? hash;
  final int iterations;
  final Duration duration;
  final int difficulty;
  final double hashrate;
  final String? error;

  const MiningResult({
    required this.success,
    this.nonce,
    this.hash,
    required this.iterations,
    required this.duration,
    required this.difficulty,
    required this.hashrate,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'nonce': nonce,
    'hash': hash,
    'iterations': iterations,
    'durationMs': duration.inMilliseconds,
    'difficulty': difficulty,
    'hashrate': hashrate,
    'error': error,
  };
}

/// Mining performance tracking
class MiningPerformance {
  final DateTime timestamp;
  final int difficulty;
  final double hashrate;
  final Duration duration;
  final bool success;

  const MiningPerformance({
    required this.timestamp,
    required this.difficulty,
    required this.hashrate,
    required this.duration,
    required this.success,
  });
}

/// Mining statistics
class MiningStats {
  final int currentDifficulty;
  final double averageBlockTime;
  final int totalProofs;
  final Map<String, MiningPerformance> performanceMetrics;

  const MiningStats({
    required this.currentDifficulty,
    required this.averageBlockTime,
    required this.totalProofs,
    required this.performanceMetrics,
  });
}

/// Mining benchmark results
class MiningBenchmark {
  final int totalIterations;
  final Duration totalDuration;
  final double hashrate;
  final int successfulProofs;
  final int averageDifficulty;
  final List<MiningResult> results;

  const MiningBenchmark({
    required this.totalIterations,
    required this.totalDuration,
    required this.hashrate,
    required this.successfulProofs,
    required this.averageDifficulty,
    required this.results,
  });

  Map<String, dynamic> toJson() => {
    'totalIterations': totalIterations,
    'totalDurationMs': totalDuration.inMilliseconds,
    'hashrate': hashrate,
    'successfulProofs': successfulProofs,
    'averageDifficulty': averageDifficulty,
    'results': results.map((r) => r.toJson()).toList(),
  };
}
