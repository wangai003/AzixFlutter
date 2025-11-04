import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:azixflutter/services/raffle_service.dart';
import 'package:azixflutter/services/soroban_raffle_service.dart';
import 'package:azixflutter/models/raffle_model.dart';
import 'package:azixflutter/models/raffle_entry_model.dart';
import 'package:azixflutter/models/raffle_winner_model.dart';

// Mock Firebase Auth user for testing
class MockUser implements User {
  @override
  final String uid;
  @override
  final String? displayName;
  @override
  final String? email;

  MockUser({required this.uid, this.displayName, this.email});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // Integration tests require Firebase to be initialized
  // These tests should be run against a test Firebase project

  group('Raffle System Integration Tests', () {
    late RaffleService raffleService;
    late SorobanRaffleService sorobanService;
    late FirebaseFirestore firestore;
    late FirebaseAuth auth;

    // Test data
    late String testRaffleId;
    late String testUserId;
    late RaffleModel testRaffle;

    setUpAll(() async {
      // Initialize Firebase for testing
      // Note: This requires firebase_test_config.dart or similar setup
      try {
        await Firebase.initializeApp();
        firestore = FirebaseFirestore.instance;
        auth = FirebaseAuth.instance;
        raffleService = RaffleService();
        sorobanService = SorobanRaffleService();

        // Create test user
        testUserId =
            'test_user_integration_${DateTime.now().millisecondsSinceEpoch}';
      } catch (e) {
        // Skip tests if Firebase is not configured for testing
        print('Firebase not configured for integration tests: $e');
      }
    });

    tearDownAll(() async {
      // Clean up test data
      try {
        if (testRaffleId != null) {
          await firestore.collection('raffles').doc(testRaffleId).delete();
          await firestore
              .collection('raffle_entries')
              .where('raffleId', isEqualTo: testRaffleId)
              .get()
              .then((snapshot) {
                for (var doc in snapshot.docs) {
                  doc.reference.delete();
                }
              });
          await firestore
              .collection('raffle_winners')
              .where('raffleId', isEqualTo: testRaffleId)
              .get()
              .then((snapshot) {
                for (var doc in snapshot.docs) {
                  doc.reference.delete();
                }
              });
        }
      } catch (e) {
        print('Error cleaning up test data: $e');
      }
    });

    group('Complete Raffle Lifecycle', () {
      test(
        'should complete full raffle lifecycle from creation to prize claim',
        () async {
          // Skip if Firebase not available
          if (firestore == null) return;

          // 1. Create a raffle
          final raffleId = await RaffleService.createRaffle(
            creatorId: testUserId,
            creatorName: 'Integration Test User',
            title: 'Integration Test Raffle',
            description: 'Testing complete raffle lifecycle',
            entryRequirements: {'type': 'free'},
            prizeDetails: {'type': 'akofa', 'value': 100.0},
            maxEntries: 10,
            startDate: DateTime.now().subtract(const Duration(minutes: 1)),
            endDate: DateTime.now().add(const Duration(hours: 1)),
          );

          expect(raffleId, isNotNull);
          testRaffleId = raffleId;

          // 2. Retrieve the created raffle
          final raffle = await RaffleService.getRaffle(raffleId);
          expect(raffle, isNotNull);
          expect(raffle!.title, 'Integration Test Raffle');
          expect(raffle.canEnter, true);
          testRaffle = raffle;

          // 3. Enter the raffle multiple times
          final entryIds = <String>[];
          for (int i = 0; i < 5; i++) {
            final entryId = await RaffleService.enterRaffle(
              raffleId: raffleId,
              userId: 'participant_$i',
              userName: 'Participant $i',
              verificationData: {'entryType': 'free'},
            );
            entryIds.add(entryId);
          }

          // Verify entries were recorded
          final entries = await RaffleService.getRaffleEntries(raffleId);
          expect(entries.length, 5);

          // 4. Update raffle status to completed
          await RaffleService.updateRaffleStatus(
            raffleId: raffleId,
            status: RaffleStatus.completed,
            creatorId: testUserId,
          );

          // 5. Draw winners
          final winners = await RaffleService.drawWinners(
            raffleId: raffleId,
            numberOfWinners: 2,
          );

          expect(winners, isNotEmpty);
          expect(winners.length, 2);

          // 6. Claim prize for first winner
          final firstWinner = winners.first;
          await RaffleService.claimPrize(
            winnerId: firstWinner.id,
            userId: firstWinner.winnerUserId,
            transactionId:
                'integration_test_claim_${DateTime.now().millisecondsSinceEpoch}',
          );

          // Verify prize was claimed
          final updatedWinner = await RaffleService.getWinner(firstWinner.id);
          expect(updatedWinner?.claimStatus, PrizeClaimStatus.claimed);
        },
      );

      test('should handle blockchain raffle entries', () async {
        // Skip if Firebase not available
        if (firestore == null) return;

        // Create a blockchain raffle
        final raffleId = await RaffleService.createRaffle(
          creatorId: testUserId,
          creatorName: 'Integration Test User',
          title: 'Blockchain Integration Test Raffle',
          description: 'Testing blockchain raffle entries',
          entryRequirements: {
            'type': 'blockchain',
            'blockchainRequired': true,
            'akofaAmount': 50.0,
          },
          prizeDetails: {'type': 'akofa', 'value': 500.0},
          maxEntries: 5,
          startDate: DateTime.now().subtract(const Duration(minutes: 1)),
          endDate: DateTime.now().add(const Duration(hours: 1)),
        );

        expect(raffleId, isNotNull);

        // Attempt blockchain entry (will fail due to mock implementation)
        final result = await RaffleService.enterRaffle(
          raffleId: raffleId,
          userId: testUserId,
          userName: 'Test User',
          verificationData: {'entryType': 'blockchain'},
        );

        // Since Soroban service uses mocks, this should fall back to Firebase
        expect(result, isNotNull);

        // Clean up
        await firestore.collection('raffles').doc(raffleId).delete();
      });
    });

    group('Concurrent Entry Handling', () {
      test('should handle multiple simultaneous entries correctly', () async {
        // Skip if Firebase not available
        if (firestore == null) return;

        // Create a raffle
        final raffleId = await RaffleService.createRaffle(
          creatorId: testUserId,
          creatorName: 'Integration Test User',
          title: 'Concurrent Entry Test Raffle',
          description: 'Testing concurrent entries',
          entryRequirements: {'type': 'free'},
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          maxEntries: 20,
          startDate: DateTime.now().subtract(const Duration(minutes: 1)),
          endDate: DateTime.now().add(const Duration(hours: 1)),
        );

        expect(raffleId, isNotNull);

        // Simulate concurrent entries
        final futures = <Future<String>>[];
        for (int i = 0; i < 10; i++) {
          futures.add(
            RaffleService.enterRaffle(
              raffleId: raffleId,
              userId: 'concurrent_user_$i',
              userName: 'Concurrent User $i',
              verificationData: {'entryType': 'free'},
            ),
          );
        }

        // Wait for all entries to complete
        final results = await Future.wait(futures);

        // Verify all entries succeeded
        expect(results.length, 10);
        expect(results.every((id) => id.isNotEmpty), true);

        // Verify final count
        final raffle = await RaffleService.getRaffle(raffleId);
        expect(raffle?.currentEntries, 10);

        // Clean up
        await firestore.collection('raffles').doc(raffleId).delete();
        await firestore
            .collection('raffle_entries')
            .where('raffleId', isEqualTo: raffleId)
            .get()
            .then((snapshot) {
              for (var doc in snapshot.docs) {
                doc.reference.delete();
              }
            });
      });
    });

    group('Data Consistency', () {
      test('should maintain data consistency across services', () async {
        // Skip if Firebase not available
        if (firestore == null) return;

        // Create raffle
        final raffleId = await RaffleService.createRaffle(
          creatorId: testUserId,
          creatorName: 'Consistency Test User',
          title: 'Data Consistency Test Raffle',
          description: 'Testing data consistency',
          entryRequirements: {'type': 'free'},
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          maxEntries: 5,
          startDate: DateTime.now().subtract(const Duration(minutes: 1)),
          endDate: DateTime.now().add(const Duration(hours: 1)),
        );

        // Add entries
        for (int i = 0; i < 3; i++) {
          await RaffleService.enterRaffle(
            raffleId: raffleId,
            userId: 'consistency_user_$i',
            userName: 'Consistency User $i',
            verificationData: {'entryType': 'free'},
          );
        }

        // Verify consistency between raffle and entries
        final raffle = await RaffleService.getRaffle(raffleId);
        final entries = await RaffleService.getRaffleEntries(raffleId);

        expect(raffle?.currentEntries, entries.length);

        // Draw winners
        final winners = await RaffleService.drawWinners(
          raffleId: raffleId,
          numberOfWinners: 2,
        );

        // Verify winner data consistency
        for (final winner in winners) {
          expect(winner.raffleId, raffleId);
          expect(winner.prizeDetails, raffle?.prizeDetails);
        }

        // Clean up
        await firestore.collection('raffles').doc(raffleId).delete();
        await firestore
            .collection('raffle_entries')
            .where('raffleId', isEqualTo: raffleId)
            .get()
            .then((snapshot) {
              for (var doc in snapshot.docs) {
                doc.reference.delete();
              }
            });
        await firestore
            .collection('raffle_winners')
            .where('raffleId', isEqualTo: raffleId)
            .get()
            .then((snapshot) {
              for (var doc in snapshot.docs) {
                doc.reference.delete();
              }
            });
      });
    });

    group('Error Recovery', () {
      test('should handle network failures gracefully', () async {
        // Skip if Firebase not available
        if (firestore == null) return;

        // Test with invalid raffle ID
        final result = await RaffleService.getRaffle('nonexistent_raffle');
        expect(result, isNull);

        // Test entering non-existent raffle
        expect(
          () => RaffleService.enterRaffle(
            raffleId: 'nonexistent_raffle',
            userId: testUserId,
            userName: 'Test User',
            verificationData: {'entryType': 'free'},
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle invalid data gracefully', () async {
        // Skip if Firebase not available
        if (firestore == null) return;

        // Create raffle with invalid data
        final raffleId = await RaffleService.createRaffle(
          creatorId: testUserId,
          creatorName: 'Error Test User',
          title: '', // Invalid empty title
          description: 'Testing error handling',
          entryRequirements: {'type': 'free'},
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          maxEntries: 10,
          startDate: DateTime.now().subtract(const Duration(minutes: 1)),
          endDate: DateTime.now().add(const Duration(hours: 1)),
        );

        // Should still create successfully (validation happens at UI level)
        expect(raffleId, isNotNull);

        // Clean up
        await firestore.collection('raffles').doc(raffleId).delete();
      });
    });

    group('Soroban Integration', () {
      test('should verify Soroban service integration', () async {
        // Test Soroban service initialization
        await SorobanRaffleService.initialize();

        // Test balance verification (will use mock data)
        final balanceResult = await SorobanRaffleService.verifyAkofaBalance(
          userId: testUserId,
          requiredAmount: 100.0,
        );

        expect(balanceResult, isA<Map<String, dynamic>>());
        expect(balanceResult.containsKey('success'), true);

        // Test network status
        final networkStatus = await SorobanRaffleService.getNetworkStatus();
        expect(networkStatus['success'], true);
        expect(networkStatus.containsKey('contractId'), true);
        expect(networkStatus.containsKey('akofaTokenId'), true);
      });

      test('should handle Soroban transaction status checks', () async {
        // Test transaction status check (will fail for invalid hash)
        final statusResult = await SorobanRaffleService.checkTransactionStatus(
          'invalid_transaction_hash',
        );

        expect(statusResult['success'], false);
        expect(statusResult.containsKey('error'), true);
      });
    });
  });
}
