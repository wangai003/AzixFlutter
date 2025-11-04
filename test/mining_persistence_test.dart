import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:azixflutter/services/mining_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mining Persistence Tests', () {
    late MiningService miningService;

    setUpAll(() async {
      // Initialize Firebase for testing
      await Firebase.initializeApp();
    });

    setUp(() {
      miningService = MiningService();
    });

    tearDown(() {
      miningService.dispose();
    });

    test('Test mining persistence on service restart', () async {
      print('🧪 Testing mining persistence...');

      // Start mining
      miningService.startMining();
      await Future.delayed(const Duration(seconds: 2));
      miningService.stopMining();

      // Get current mined tokens
      double initialTokens = 0.0;
      final subscription = miningService.minedTokenStream.listen((tokens) {
        initialTokens = tokens;
      });

      await Future.delayed(const Duration(milliseconds: 100));
      subscription.cancel();

      expect(initialTokens, greaterThan(0.0));
      print('✅ Initial mining accumulated: $initialTokens tokens');

      // Simulate app restart by creating new service instance
      final newMiningService = MiningService();

      // Set initial tokens (simulating restoration from Firestore)
      newMiningService.setInitialMinedTokens(initialTokens);

      // Verify tokens are set
      double restoredTokens = 0.0;
      final restoredSubscription = newMiningService.minedTokenStream.listen((
        tokens,
      ) {
        restoredTokens = tokens;
      });

      await Future.delayed(const Duration(milliseconds: 100));
      restoredSubscription.cancel();

      expect(restoredTokens, equals(initialTokens));
      print('✅ Tokens successfully restored: $restoredTokens');

      newMiningService.dispose();
    });

    test('Test mining continuation after restoration', () async {
      print('🧪 Testing mining continuation after restoration...');

      final miningService = MiningService();
      miningService.setInitialMinedTokens(1.0); // Simulate restored session

      double tokensBefore = 0.0;
      double tokensAfter = 0.0;

      final subscription = miningService.minedTokenStream.listen((tokens) {
        tokensBefore = tokens;
      });

      await Future.delayed(const Duration(milliseconds: 100));
      subscription.cancel();

      expect(tokensBefore, equals(1.0));

      // Start mining again
      miningService.startMining();
      await Future.delayed(const Duration(seconds: 1));

      final afterSubscription = miningService.minedTokenStream.listen((tokens) {
        tokensAfter = tokens;
      });

      await Future.delayed(const Duration(milliseconds: 100));
      afterSubscription.cancel();

      miningService.stopMining();

      expect(tokensAfter, greaterThan(tokensBefore));
      print('✅ Mining continued successfully: $tokensBefore -> $tokensAfter');

      miningService.dispose();
    });
  });
}
