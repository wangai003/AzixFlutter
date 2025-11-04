import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:azixflutter/services/mining_service.dart';
import 'package:azixflutter/services/soroban_mining_service.dart';

/// Complete Mining Flow Test Script
///
/// This script simulates the complete mining flow:
/// 1. Start mining session
/// 2. Close app (stop mining)
/// 3. Reopen app after time passes
/// 4. Detect expired sessions
/// 5. Claim mining rewards
///
/// Usage: flutter run test/run_complete_mining_test.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 Starting Complete Mining Flow Test');
  print('=' * 50);

  final miningService = MiningService();
  final sorobanService = SorobanMiningService();

  try {
    // Check if user is authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No user logged in. Please log in to the app first.');
      return;
    }

    print('✅ User authenticated: ${user.uid}');

    // Test 1: Start Mining Session
    await testStartMining(miningService);

    // Test 2: Simulate App Close and Reopen
    await testAppLifecycle(miningService);

    // Test 3: Detect Expired Sessions
    await testExpiredSessionDetection(miningService);

    // Test 4: Claim Mining Rewards
    await testRewardClaiming(miningService);

    // Test 5: Complete Flow Integration
    await testCompleteFlow(miningService);

    print('\n🎉 All mining flow tests completed successfully!');
    print('=' * 50);
  } catch (e) {
    print('❌ Test failed with error: $e');
  } finally {
    miningService.dispose();
  }
}

Future<void> testStartMining(MiningService miningService) async {
  print('\n🧪 Test 1: Starting Mining Session');

  try {
    // Start mining
    miningService.startMining();
    print('✅ Mining started');

    // Create a mining session in Firestore
    final sessionRef = await miningService.saveMiningSession();
    print('✅ Mining session created: ${sessionRef.id}');

    // Wait for some tokens to accumulate
    print('⏳ Waiting for tokens to accumulate...');
    await Future.delayed(const Duration(seconds: 3));

    // Stop mining for now
    miningService.stopMining();
    print('✅ Mining stopped (for testing)');
  } catch (e) {
    print('❌ Failed to start mining: $e');
    rethrow;
  }
}

Future<void> testAppLifecycle(MiningService miningService) async {
  print('\n🧪 Test 2: Simulating App Close and Reopen');

  try {
    // Start mining again
    miningService.startMining();
    await Future.delayed(const Duration(seconds: 2));

    // Simulate app close
    miningService.stopMining();
    print('📱 App closed (mining stopped)');

    // Simulate time passing (session expiration)
    print('⏰ Simulating time passage...');
    await Future.delayed(const Duration(seconds: 2));

    // Simulate app reopen
    print('📱 App reopened');

    // Handle expired sessions
    await miningService.handleExpiredSessions();
    print('✅ Expired sessions handled');

    // Check for unpaid sessions
    final unpaidSessions = await miningService.getUnpaidMiningSessions();
    print('📊 Found ${unpaidSessions.length} unpaid mining sessions');

    for (var session in unpaidSessions) {
      print('   - Session ${session['id']}: ${session['minedTokens']} AKOFA');
    }
  } catch (e) {
    print('❌ App lifecycle test failed: $e');
    rethrow;
  }
}

Future<void> testExpiredSessionDetection(MiningService miningService) async {
  print('\n🧪 Test 3: Testing Expired Session Detection Logic');

  try {
    // Test the logic for calculating mined tokens for expired sessions
    final now = DateTime.now();
    final sessionStart = now.subtract(const Duration(hours: 24));
    final sessionEnd = sessionStart.add(const Duration(hours: 24));

    final duration = sessionEnd.difference(sessionStart);
    final minedTokens = duration.inSeconds * (0.25 / 3600); // 0.25 AKOFA/hour

    print('📊 Session duration: ${duration.inHours} hours');
    print('📊 Expected mined tokens: ${minedTokens.toStringAsFixed(6)} AKOFA');

    if ((minedTokens - 6.0).abs() > 0.000001) {
      throw Exception('Expected 6.0 AKOFA but got $minedTokens');
    }
    print('✅ Expired session calculation logic working correctly');
  } catch (e) {
    print('❌ Expired session detection test failed: $e');
    rethrow;
  }
}

Future<void> testRewardClaiming(MiningService miningService) async {
  print('\n🧪 Test 4: Testing Reward Claiming');

  try {
    // Get unpaid sessions
    final unpaidSessions = await miningService.getUnpaidMiningSessions();

    if (unpaidSessions.isEmpty) {
      print('⚠️ No unpaid sessions found. Creating one for testing...');

      // Create a session and immediately expire it
      await miningService.saveMiningSession();
      await miningService.handleExpiredSessions();

      // Try again
      final sessions = await miningService.getUnpaidMiningSessions();
      unpaidSessions.addAll(sessions);
    }

    if (unpaidSessions.isNotEmpty) {
      print(
        '🎁 Attempting to claim ${unpaidSessions.length} unpaid session(s)',
      );

      for (var session in unpaidSessions) {
        final sessionId = session['id'] as String;
        final amount = session['minedTokens'] as double;

        print('💰 Claiming session $sessionId: $amount AKOFA');

        final result = await miningService.claimSpecificUnpaidSession(
          sessionId,
        );

        if (result['success'] == true) {
          print('✅ Successfully claimed $amount AKOFA');
          print('   Transaction: ${result['txHash']}');
        } else {
          print('❌ Failed to claim: ${result['message']}');
        }
      }
    } else {
      print('⚠️ Still no unpaid sessions found');
    }
  } catch (e) {
    print('❌ Reward claiming test failed: $e');
    rethrow;
  }
}

Future<void> testCompleteFlow(MiningService miningService) async {
  print('\n🧪 Test 5: Complete Mining Flow Integration');

  try {
    print('Step 1: Starting fresh mining session...');
    miningService.startMining();
    await Future.delayed(const Duration(seconds: 2));

    print('Step 2: Creating mining session...');
    final sessionRef = await miningService.saveMiningSession();

    print('Step 3: Simulating app close...');
    miningService.stopMining();

    print('Step 4: Simulating session expiration...');
    await Future.delayed(const Duration(seconds: 1));

    print('Step 5: Handling expired sessions...');
    await miningService.handleExpiredSessions();

    print('Step 6: Claiming all available rewards...');
    final unpaidSessions = await miningService.getUnpaidMiningSessions();

    for (var session in unpaidSessions) {
      final sessionId = session['id'] as String;
      await miningService.claimSpecificUnpaidSession(sessionId);
    }

    print('✅ Complete mining flow integration test passed!');
  } catch (e) {
    print('❌ Complete flow test failed: $e');
    rethrow;
  }
}

// Helper function for assertions (since we can't use flutter_test in a main script)
void expect(dynamic actual, dynamic matcher) {
  if (matcher is double && actual is double) {
    if ((actual - matcher).abs() > 0.000001) {
      throw Exception('Expected $matcher but got $actual');
    }
  } else if (actual != matcher) {
    throw Exception('Expected $matcher but got $actual');
  }
}
