import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:azixflutter/models/raffle_model.dart';

void main() {
  group('RaffleModel Tests', () {
    group('RaffleModel Construction', () {
      test('should create RaffleModel with required fields', () {
        final startDate = DateTime.now();
        final endDate = startDate.add(const Duration(days: 7));
        final createdAt = DateTime.now();
        final updatedAt = DateTime.now();

        final raffle = RaffleModel(
          id: 'test_id',
          title: 'Test Raffle',
          description: 'Test Description',
          creatorId: 'creator_123',
          creatorName: 'Test Creator',
          entryRequirements: {'type': 'free'},
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          maxEntries: 100,
          startDate: startDate,
          endDate: endDate,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

        expect(raffle.id, 'test_id');
        expect(raffle.title, 'Test Raffle');
        expect(raffle.description, 'Test Description');
        expect(raffle.creatorId, 'creator_123');
        expect(raffle.creatorName, 'Test Creator');
        expect(raffle.entryRequirements, {'type': 'free'});
        expect(raffle.prizeDetails, {'type': 'akofa', 'value': 100.0});
        expect(raffle.maxEntries, 100);
        expect(raffle.currentEntries, 0); // default value
        expect(raffle.startDate, startDate);
        expect(raffle.endDate, endDate);
        expect(raffle.status, RaffleStatus.draft); // default value
        expect(raffle.isPublic, true); // default value
        expect(raffle.createdAt, createdAt);
        expect(raffle.updatedAt, updatedAt);
      });

      test('should create RaffleModel with all optional fields', () {
        final startDate = DateTime.now();
        final endDate = startDate.add(const Duration(days: 7));
        final drawDate = endDate.add(const Duration(days: 1));
        final createdAt = DateTime.now();
        final updatedAt = DateTime.now();

        final raffle = RaffleModel(
          id: 'test_id',
          title: 'Test Raffle',
          description: 'Test Description',
          detailedDescription: 'Detailed description',
          creatorId: 'creator_123',
          creatorName: 'Test Creator',
          imageUrl: 'https://example.com/image.jpg',
          galleryImages: ['image1.jpg', 'image2.jpg'],
          entryRequirements: {'type': 'purchase', 'cost': 50.0},
          prizeDetails: {
            'type': 'akofa',
            'value': 1000.0,
            'description': 'Grand prize',
          },
          maxEntries: 500,
          currentEntries: 150,
          startDate: startDate,
          endDate: endDate,
          drawDate: drawDate,
          status: RaffleStatus.active,
          isPublic: false,
          allowedUserIds: ['user1', 'user2'],
          metadata: {'category': 'gaming', 'difficulty': 'hard'},
          createdAt: createdAt,
          updatedAt: updatedAt,
          ipfsHash: 'QmTestHash123',
        );

        expect(raffle.detailedDescription, 'Detailed description');
        expect(raffle.imageUrl, 'https://example.com/image.jpg');
        expect(raffle.galleryImages, ['image1.jpg', 'image2.jpg']);
        expect(raffle.currentEntries, 150);
        expect(raffle.drawDate, drawDate);
        expect(raffle.status, RaffleStatus.active);
        expect(raffle.isPublic, false);
        expect(raffle.allowedUserIds, ['user1', 'user2']);
        expect(raffle.metadata, {'category': 'gaming', 'difficulty': 'hard'});
        expect(raffle.ipfsHash, 'QmTestHash123');
      });
    });

    group('RaffleModel Computed Properties', () {
      test(
        'isActive should return true for active raffle within date range',
        () {
          final now = DateTime.now();
          final raffle = RaffleModel(
            id: 'test_id',
            title: 'Test Raffle',
            description: 'Test Description',
            creatorId: 'creator_123',
            creatorName: 'Test Creator',
            entryRequirements: {'type': 'free'},
            prizeDetails: {'type': 'akofa', 'value': 100.0},
            maxEntries: 100,
            startDate: now.subtract(const Duration(hours: 1)),
            endDate: now.add(const Duration(hours: 1)),
            status: RaffleStatus.active,
            createdAt: now,
            updatedAt: now,
          );

          expect(raffle.isActive, true);
        },
      );

      test('isActive should return false for draft raffle', () {
        final now = DateTime.now();
        final raffle = RaffleModel(
          id: 'test_id',
          title: 'Test Raffle',
          description: 'Test Description',
          creatorId: 'creator_123',
          creatorName: 'Test Creator',
          entryRequirements: {'type': 'free'},
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          maxEntries: 100,
          startDate: now.subtract(const Duration(hours: 1)),
          endDate: now.add(const Duration(hours: 1)),
          status: RaffleStatus.draft,
          createdAt: now,
          updatedAt: now,
        );

        expect(raffle.isActive, false);
      });

      test('isActive should return false for raffle before start date', () {
        final now = DateTime.now();
        final raffle = RaffleModel(
          id: 'test_id',
          title: 'Test Raffle',
          description: 'Test Description',
          creatorId: 'creator_123',
          creatorName: 'Test Creator',
          entryRequirements: {'type': 'free'},
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          maxEntries: 100,
          startDate: now.add(const Duration(hours: 1)),
          endDate: now.add(const Duration(hours: 2)),
          status: RaffleStatus.active,
          createdAt: now,
          updatedAt: now,
        );

        expect(raffle.isActive, false);
      });

      test('isActive should return false for raffle after end date', () {
        final now = DateTime.now();
        final raffle = RaffleModel(
          id: 'test_id',
          title: 'Test Raffle',
          description: 'Test Description',
          creatorId: 'creator_123',
          creatorName: 'Test Creator',
          entryRequirements: {'type': 'free'},
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          maxEntries: 100,
          startDate: now.subtract(const Duration(hours: 2)),
          endDate: now.subtract(const Duration(hours: 1)),
          status: RaffleStatus.active,
          createdAt: now,
          updatedAt: now,
        );

        expect(raffle.isActive, false);
      });

      test('isExpired should return true for raffle after end date', () {
        final now = DateTime.now();
        final raffle = RaffleModel(
          id: 'test_id',
          title: 'Test Raffle',
          description: 'Test Description',
          creatorId: 'creator_123',
          creatorName: 'Test Creator',
          entryRequirements: {'type': 'free'},
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          maxEntries: 100,
          startDate: now.subtract(const Duration(hours: 2)),
          endDate: now.subtract(const Duration(hours: 1)),
          createdAt: now,
          updatedAt: now,
        );

        expect(raffle.isExpired, true);
      });

      test('isExpired should return false for active raffle', () {
        final now = DateTime.now();
        final raffle = RaffleModel(
          id: 'test_id',
          title: 'Test Raffle',
          description: 'Test Description',
          creatorId: 'creator_123',
          creatorName: 'Test Creator',
          entryRequirements: {'type': 'free'},
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          maxEntries: 100,
          startDate: now.subtract(const Duration(hours: 1)),
          endDate: now.add(const Duration(hours: 1)),
          createdAt: now,
          updatedAt: now,
        );

        expect(raffle.isExpired, false);
      });

      test(
        'canEnter should return true for active raffle with available slots',
        () {
          final now = DateTime.now();
          final raffle = RaffleModel(
            id: 'test_id',
            title: 'Test Raffle',
            description: 'Test Description',
            creatorId: 'creator_123',
            creatorName: 'Test Creator',
            entryRequirements: {'type': 'free'},
            prizeDetails: {'type': 'akofa', 'value': 100.0},
            maxEntries: 100,
            currentEntries: 50,
            startDate: now.subtract(const Duration(hours: 1)),
            endDate: now.add(const Duration(hours: 1)),
            status: RaffleStatus.active,
            createdAt: now,
            updatedAt: now,
          );

          expect(raffle.canEnter, true);
        },
      );

      test('canEnter should return false for raffle at max capacity', () {
        final now = DateTime.now();
        final raffle = RaffleModel(
          id: 'test_id',
          title: 'Test Raffle',
          description: 'Test Description',
          creatorId: 'creator_123',
          creatorName: 'Test Creator',
          entryRequirements: {'type': 'free'},
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          maxEntries: 100,
          currentEntries: 100,
          startDate: now.subtract(const Duration(hours: 1)),
          endDate: now.add(const Duration(hours: 1)),
          status: RaffleStatus.active,
          createdAt: now,
          updatedAt: now,
        );

        expect(raffle.canEnter, false);
      });

      test('entriesRemaining should calculate correctly', () {
        final now = DateTime.now();
        final raffle = RaffleModel(
          id: 'test_id',
          title: 'Test Raffle',
          description: 'Test Description',
          creatorId: 'creator_123',
          creatorName: 'Test Creator',
          entryRequirements: {'type': 'free'},
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          maxEntries: 100,
          currentEntries: 75,
          startDate: now.subtract(const Duration(hours: 1)),
          endDate: now.add(const Duration(hours: 1)),
          status: RaffleStatus.active,
          createdAt: now,
          updatedAt: now,
        );

        expect(raffle.entriesRemaining, 25);
      });
    });

    group('RaffleModel Serialization', () {
      test('toMap should convert RaffleModel to Map correctly', () {
        final startDate = DateTime(2024, 1, 1, 10, 0, 0);
        final endDate = DateTime(2024, 1, 8, 10, 0, 0);
        final createdAt = DateTime(2024, 1, 1, 9, 0, 0);
        final updatedAt = DateTime(2024, 1, 1, 9, 30, 0);

        final raffle = RaffleModel(
          id: 'test_id',
          title: 'Test Raffle',
          description: 'Test Description',
          creatorId: 'creator_123',
          creatorName: 'Test Creator',
          entryRequirements: {'type': 'free'},
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          maxEntries: 100,
          startDate: startDate,
          endDate: endDate,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

        final map = raffle.toMap();

        expect(map['title'], 'Test Raffle');
        expect(map['description'], 'Test Description');
        expect(map['creatorId'], 'creator_123');
        expect(map['creatorName'], 'Test Creator');
        expect(map['entryRequirements'], {'type': 'free'});
        expect(map['prizeDetails'], {'type': 'akofa', 'value': 100.0});
        expect(map['maxEntries'], 100);
        expect(map['currentEntries'], 0);
        expect(map['startDate'], Timestamp.fromDate(startDate));
        expect(map['endDate'], Timestamp.fromDate(endDate));
        expect(map['status'], 'RaffleStatus.draft');
        expect(map['isPublic'], true);
        expect(map['createdAt'], Timestamp.fromDate(createdAt));
        expect(map['updatedAt'], Timestamp.fromDate(updatedAt));
      });

      test('fromMap should create RaffleModel from Map correctly', () {
        final startDate = DateTime(2024, 1, 1, 10, 0, 0);
        final endDate = DateTime(2024, 1, 8, 10, 0, 0);
        final createdAt = DateTime(2024, 1, 1, 9, 0, 0);
        final updatedAt = DateTime(2024, 1, 1, 9, 30, 0);

        final map = {
          'title': 'Test Raffle',
          'description': 'Test Description',
          'creatorId': 'creator_123',
          'creatorName': 'Test Creator',
          'entryRequirements': {'type': 'free'},
          'prizeDetails': {'type': 'akofa', 'value': 100.0},
          'maxEntries': 100,
          'currentEntries': 50,
          'startDate': Timestamp.fromDate(startDate),
          'endDate': Timestamp.fromDate(endDate),
          'status': 'RaffleStatus.active',
          'isPublic': false,
          'createdAt': Timestamp.fromDate(createdAt),
          'updatedAt': Timestamp.fromDate(updatedAt),
        };

        final raffle = RaffleModel.fromMap(map, 'test_id');

        expect(raffle.id, 'test_id');
        expect(raffle.title, 'Test Raffle');
        expect(raffle.description, 'Test Description');
        expect(raffle.creatorId, 'creator_123');
        expect(raffle.creatorName, 'Test Creator');
        expect(raffle.entryRequirements, {'type': 'free'});
        expect(raffle.prizeDetails, {'type': 'akofa', 'value': 100.0});
        expect(raffle.maxEntries, 100);
        expect(raffle.currentEntries, 50);
        expect(raffle.startDate, startDate);
        expect(raffle.endDate, endDate);
        expect(raffle.status, RaffleStatus.active);
        expect(raffle.isPublic, false);
        expect(raffle.createdAt, createdAt);
        expect(raffle.updatedAt, updatedAt);
      });

      test('fromMap should handle null values gracefully', () {
        final map = {
          'title': 'Test Raffle',
          'description': 'Test Description',
          'creatorId': 'creator_123',
          'creatorName': 'Test Creator',
          'entryRequirements': {'type': 'free'},
          'prizeDetails': {'type': 'akofa', 'value': 100.0},
          'maxEntries': 100,
          'startDate': null,
          'endDate': null,
          'createdAt': null,
          'updatedAt': null,
        };

        final raffle = RaffleModel.fromMap(map, 'test_id');

        expect(
          raffle.startDate,
          isNotNull,
        ); // Should use DateTime.now() as fallback
        expect(raffle.endDate, isNotNull);
        expect(raffle.createdAt, isNotNull);
        expect(raffle.updatedAt, isNotNull);
      });
    });

    group('RaffleModel CopyWith', () {
      test('copyWith should create new instance with updated fields', () {
        final original = RaffleModel(
          id: 'test_id',
          title: 'Original Title',
          description: 'Original Description',
          creatorId: 'creator_123',
          creatorName: 'Test Creator',
          entryRequirements: {'type': 'free'},
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          maxEntries: 100,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 7)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final updated = original.copyWith(
          title: 'Updated Title',
          maxEntries: 200,
          status: RaffleStatus.active,
        );

        expect(updated.id, 'test_id'); // Unchanged
        expect(updated.title, 'Updated Title'); // Changed
        expect(updated.description, 'Original Description'); // Unchanged
        expect(updated.maxEntries, 200); // Changed
        expect(updated.status, RaffleStatus.active); // Changed
        expect(updated.creatorId, 'creator_123'); // Unchanged
      });

      test('copyWith should handle null values correctly', () {
        final original = RaffleModel(
          id: 'test_id',
          title: 'Original Title',
          description: 'Original Description',
          creatorId: 'creator_123',
          creatorName: 'Test Creator',
          entryRequirements: {'type': 'free'},
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          maxEntries: 100,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 7)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final updated = original.copyWith(
          imageUrl: null,
          detailedDescription: null,
        );

        expect(updated.imageUrl, null);
        expect(updated.detailedDescription, null);
      });
    });
  });

  group('RaffleEntryModel Tests', () {
    group('RaffleEntryModel Construction', () {
      test('should create RaffleEntryModel with required fields', () {
        final entryDate = DateTime.now();

        final entry = RaffleEntryModel(
          id: 'entry_id',
          raffleId: 'raffle_id',
          userId: 'user_id',
          userName: 'Test User',
          entryDate: entryDate,
          verificationData: {'type': 'free'},
        );

        expect(entry.id, 'entry_id');
        expect(entry.raffleId, 'raffle_id');
        expect(entry.userId, 'user_id');
        expect(entry.userName, 'Test User');
        expect(entry.entryDate, entryDate);
        expect(entry.verificationData, {'type': 'free'});
        expect(entry.isValid, true); // default value
      });

      test('should create RaffleEntryModel with all optional fields', () {
        final entryDate = DateTime.now();
        final verifiedAt = entryDate.add(const Duration(minutes: 5));

        final entry = RaffleEntryModel(
          id: 'entry_id',
          raffleId: 'raffle_id',
          userId: 'user_id',
          userName: 'Test User',
          userEmail: 'test@example.com',
          entryDate: entryDate,
          verificationData: {'type': 'purchase', 'txId': 'tx_123'},
          referralCode: 'REF123',
          transactionId: 'tx_456',
          isValid: false,
          invalidReason: 'Insufficient balance',
          verifiedAt: verifiedAt,
          metadata: {'source': 'mobile_app'},
        );

        expect(entry.userEmail, 'test@example.com');
        expect(entry.referralCode, 'REF123');
        expect(entry.transactionId, 'tx_456');
        expect(entry.isValid, false);
        expect(entry.invalidReason, 'Insufficient balance');
        expect(entry.verifiedAt, verifiedAt);
        expect(entry.metadata, {'source': 'mobile_app'});
      });
    });

    group('RaffleEntryModel Serialization', () {
      test('toMap should convert RaffleEntryModel to Map correctly', () {
        final entryDate = DateTime(2024, 1, 1, 10, 0, 0);
        final verifiedAt = DateTime(2024, 1, 1, 10, 5, 0);

        final entry = RaffleEntryModel(
          id: 'entry_id',
          raffleId: 'raffle_id',
          userId: 'user_id',
          userName: 'Test User',
          userEmail: 'test@example.com',
          entryDate: entryDate,
          verificationData: {'type': 'purchase', 'txId': 'tx_123'},
          referralCode: 'REF123',
          transactionId: 'tx_456',
          isValid: true,
          verifiedAt: verifiedAt,
          metadata: {'source': 'mobile_app'},
        );

        final map = entry.toMap();

        expect(map['raffleId'], 'raffle_id');
        expect(map['userId'], 'user_id');
        expect(map['userName'], 'Test User');
        expect(map['userEmail'], 'test@example.com');
        expect(map['entryDate'], Timestamp.fromDate(entryDate));
        expect(map['verificationData'], {'type': 'purchase', 'txId': 'tx_123'});
        expect(map['referralCode'], 'REF123');
        expect(map['transactionId'], 'tx_456');
        expect(map['isValid'], true);
        expect(map['verifiedAt'], Timestamp.fromDate(verifiedAt));
        expect(map['metadata'], {'source': 'mobile_app'});
      });

      test('fromMap should create RaffleEntryModel from Map correctly', () {
        final entryDate = DateTime(2024, 1, 1, 10, 0, 0);
        final verifiedAt = DateTime(2024, 1, 1, 10, 5, 0);

        final map = {
          'raffleId': 'raffle_id',
          'userId': 'user_id',
          'userName': 'Test User',
          'userEmail': 'test@example.com',
          'entryDate': Timestamp.fromDate(entryDate),
          'verificationData': {'type': 'purchase', 'txId': 'tx_123'},
          'referralCode': 'REF123',
          'transactionId': 'tx_456',
          'isValid': true,
          'verifiedAt': Timestamp.fromDate(verifiedAt),
          'metadata': {'source': 'mobile_app'},
        };

        final entry = RaffleEntryModel.fromMap(map, 'entry_id');

        expect(entry.id, 'entry_id');
        expect(entry.raffleId, 'raffle_id');
        expect(entry.userId, 'user_id');
        expect(entry.userName, 'Test User');
        expect(entry.userEmail, 'test@example.com');
        expect(entry.entryDate, entryDate);
        expect(entry.verificationData, {'type': 'purchase', 'txId': 'tx_123'});
        expect(entry.referralCode, 'REF123');
        expect(entry.transactionId, 'tx_456');
        expect(entry.isValid, true);
        expect(entry.verifiedAt, verifiedAt);
        expect(entry.metadata, {'source': 'mobile_app'});
      });
    });
  });

  group('RaffleWinnerModel Tests', () {
    group('RaffleWinnerModel Construction', () {
      test('should create RaffleWinnerModel with required fields', () {
        final drawDate = DateTime.now();

        final winner = RaffleWinnerModel(
          id: 'winner_id',
          raffleId: 'raffle_id',
          entryId: 'entry_id',
          winnerUserId: 'user_id',
          winnerName: 'Winner Name',
          winnerEmail: 'winner@example.com',
          winnerPosition: 1,
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          drawDate: drawDate,
          drawMethod: 'random',
        );

        expect(winner.id, 'winner_id');
        expect(winner.raffleId, 'raffle_id');
        expect(winner.entryId, 'entry_id');
        expect(winner.winnerUserId, 'user_id');
        expect(winner.winnerName, 'Winner Name');
        expect(winner.winnerEmail, 'winner@example.com');
        expect(winner.winnerPosition, 1);
        expect(winner.prizeDetails, {'type': 'akofa', 'value': 100.0});
        expect(winner.drawDate, drawDate);
        expect(winner.drawMethod, 'random');
        expect(winner.claimStatus, PrizeClaimStatus.unclaimed); // default value
      });

      test('should create RaffleWinnerModel with all optional fields', () {
        final drawDate = DateTime.now();
        final claimedAt = drawDate.add(const Duration(hours: 1));
        final claimExpiryDate = drawDate.add(const Duration(days: 30));

        final winner = RaffleWinnerModel(
          id: 'winner_id',
          raffleId: 'raffle_id',
          entryId: 'entry_id',
          winnerUserId: 'user_id',
          winnerName: 'Winner Name',
          winnerEmail: 'winner@example.com',
          winnerPosition: 2,
          prizeDetails: {'type': 'akofa', 'value': 500.0},
          drawDate: drawDate,
          drawMethod: 'manual',
          drawProof: {'seed': 'abc123', 'algorithm': 'sha256'},
          claimStatus: PrizeClaimStatus.claimed,
          claimedAt: claimedAt,
          claimTransactionId: 'claim_tx_123',
          claimExpiryDate: claimExpiryDate,
          metadata: {'notificationSent': true},
        );

        expect(winner.winnerPosition, 2);
        expect(winner.drawMethod, 'manual');
        expect(winner.drawProof, {'seed': 'abc123', 'algorithm': 'sha256'});
        expect(winner.claimStatus, PrizeClaimStatus.claimed);
        expect(winner.claimedAt, claimedAt);
        expect(winner.claimTransactionId, 'claim_tx_123');
        expect(winner.claimExpiryDate, claimExpiryDate);
        expect(winner.metadata, {'notificationSent': true});
      });
    });

    group('RaffleWinnerModel Computed Properties', () {
      test('isClaimed should return true for claimed prizes', () {
        final drawDate = DateTime.now();

        final winner = RaffleWinnerModel(
          id: 'winner_id',
          raffleId: 'raffle_id',
          entryId: 'entry_id',
          winnerUserId: 'user_id',
          winnerName: 'Winner Name',
          winnerEmail: 'winner@example.com',
          winnerPosition: 1,
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          drawDate: drawDate,
          drawMethod: 'random',
          claimStatus: PrizeClaimStatus.claimed,
        );

        expect(winner.isClaimed, true);
      });

      test('isClaimed should return false for unclaimed prizes', () {
        final drawDate = DateTime.now();

        final winner = RaffleWinnerModel(
          id: 'winner_id',
          raffleId: 'raffle_id',
          entryId: 'entry_id',
          winnerUserId: 'user_id',
          winnerName: 'Winner Name',
          winnerEmail: 'winner@example.com',
          winnerPosition: 1,
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          drawDate: drawDate,
          drawMethod: 'random',
          claimStatus: PrizeClaimStatus.unclaimed,
        );

        expect(winner.isClaimed, false);
      });

      test('isExpired should return true for expired claims', () {
        final drawDate = DateTime.now();
        final claimExpiryDate = drawDate.subtract(
          const Duration(days: 1),
        ); // Already expired

        final winner = RaffleWinnerModel(
          id: 'winner_id',
          raffleId: 'raffle_id',
          entryId: 'entry_id',
          winnerUserId: 'user_id',
          winnerName: 'Winner Name',
          winnerEmail: 'winner@example.com',
          winnerPosition: 1,
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          drawDate: drawDate,
          drawMethod: 'random',
          claimExpiryDate: claimExpiryDate,
        );

        expect(winner.isExpired, true);
      });

      test('isExpired should return false for non-expired claims', () {
        final drawDate = DateTime.now();
        final claimExpiryDate = drawDate.add(
          const Duration(days: 30),
        ); // Not expired yet

        final winner = RaffleWinnerModel(
          id: 'winner_id',
          raffleId: 'raffle_id',
          entryId: 'entry_id',
          winnerUserId: 'user_id',
          winnerName: 'Winner Name',
          winnerEmail: 'winner@example.com',
          winnerPosition: 1,
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          drawDate: drawDate,
          drawMethod: 'random',
          claimExpiryDate: claimExpiryDate,
        );

        expect(winner.isExpired, false);
      });

      test('canClaim should return true for unclaimed non-expired prizes', () {
        final drawDate = DateTime.now();
        final claimExpiryDate = drawDate.add(const Duration(days: 30));

        final winner = RaffleWinnerModel(
          id: 'winner_id',
          raffleId: 'raffle_id',
          entryId: 'entry_id',
          winnerUserId: 'user_id',
          winnerName: 'Winner Name',
          winnerEmail: 'winner@example.com',
          winnerPosition: 1,
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          drawDate: drawDate,
          drawMethod: 'random',
          claimStatus: PrizeClaimStatus.unclaimed,
          claimExpiryDate: claimExpiryDate,
        );

        expect(winner.canClaim, true);
      });

      test('canClaim should return false for claimed prizes', () {
        final drawDate = DateTime.now();

        final winner = RaffleWinnerModel(
          id: 'winner_id',
          raffleId: 'raffle_id',
          entryId: 'entry_id',
          winnerUserId: 'user_id',
          winnerName: 'Winner Name',
          winnerEmail: 'winner@example.com',
          winnerPosition: 1,
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          drawDate: drawDate,
          drawMethod: 'random',
          claimStatus: PrizeClaimStatus.claimed,
        );

        expect(winner.canClaim, false);
      });

      test('canClaim should return false for expired prizes', () {
        final drawDate = DateTime.now();
        final claimExpiryDate = drawDate.subtract(
          const Duration(days: 1),
        ); // Expired

        final winner = RaffleWinnerModel(
          id: 'winner_id',
          raffleId: 'raffle_id',
          entryId: 'entry_id',
          winnerUserId: 'user_id',
          winnerName: 'Winner Name',
          winnerEmail: 'winner@example.com',
          winnerPosition: 1,
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          drawDate: drawDate,
          drawMethod: 'random',
          claimStatus: PrizeClaimStatus.unclaimed,
          claimExpiryDate: claimExpiryDate,
        );

        expect(winner.canClaim, false);
      });
    });

    group('RaffleWinnerModel Serialization', () {
      test('toMap should convert RaffleWinnerModel to Map correctly', () {
        final drawDate = DateTime(2024, 1, 1, 10, 0, 0);
        final claimedAt = DateTime(2024, 1, 1, 11, 0, 0);
        final claimExpiryDate = DateTime(2024, 1, 31, 10, 0, 0);

        final winner = RaffleWinnerModel(
          id: 'winner_id',
          raffleId: 'raffle_id',
          entryId: 'entry_id',
          winnerUserId: 'user_id',
          winnerName: 'Winner Name',
          winnerEmail: 'winner@example.com',
          winnerPosition: 1,
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          drawDate: drawDate,
          drawMethod: 'random',
          drawProof: {'seed': 'abc123'},
          claimStatus: PrizeClaimStatus.claimed,
          claimedAt: claimedAt,
          claimTransactionId: 'claim_tx_123',
          claimExpiryDate: claimExpiryDate,
          metadata: {'notificationSent': true},
        );

        final map = winner.toMap();

        expect(map['raffleId'], 'raffle_id');
        expect(map['entryId'], 'entry_id');
        expect(map['winnerUserId'], 'user_id');
        expect(map['winnerName'], 'Winner Name');
        expect(map['winnerEmail'], 'winner@example.com');
        expect(map['winnerPosition'], 1);
        expect(map['prizeDetails'], {'type': 'akofa', 'value': 100.0});
        expect(map['drawDate'], Timestamp.fromDate(drawDate));
        expect(map['drawMethod'], 'random');
        expect(map['drawProof'], {'seed': 'abc123'});
        expect(map['claimStatus'], 'PrizeClaimStatus.claimed');
        expect(map['claimedAt'], Timestamp.fromDate(claimedAt));
        expect(map['claimTransactionId'], 'claim_tx_123');
        expect(map['claimExpiryDate'], Timestamp.fromDate(claimExpiryDate));
        expect(map['metadata'], {'notificationSent': true});
      });

      test('fromMap should create RaffleWinnerModel from Map correctly', () {
        final drawDate = DateTime(2024, 1, 1, 10, 0, 0);
        final claimedAt = DateTime(2024, 1, 1, 11, 0, 0);
        final claimExpiryDate = DateTime(2024, 1, 31, 10, 0, 0);

        final map = {
          'raffleId': 'raffle_id',
          'entryId': 'entry_id',
          'winnerUserId': 'user_id',
          'winnerName': 'Winner Name',
          'winnerEmail': 'winner@example.com',
          'winnerPosition': 1,
          'prizeDetails': {'type': 'akofa', 'value': 100.0},
          'drawDate': Timestamp.fromDate(drawDate),
          'drawMethod': 'random',
          'drawProof': {'seed': 'abc123'},
          'claimStatus': 'PrizeClaimStatus.claimed',
          'claimedAt': Timestamp.fromDate(claimedAt),
          'claimTransactionId': 'claim_tx_123',
          'claimExpiryDate': Timestamp.fromDate(claimExpiryDate),
          'metadata': {'notificationSent': true},
        };

        final winner = RaffleWinnerModel.fromMap(map, 'winner_id');

        expect(winner.id, 'winner_id');
        expect(winner.raffleId, 'raffle_id');
        expect(winner.entryId, 'entry_id');
        expect(winner.winnerUserId, 'user_id');
        expect(winner.winnerName, 'Winner Name');
        expect(winner.winnerEmail, 'winner@example.com');
        expect(winner.winnerPosition, 1);
        expect(winner.prizeDetails, {'type': 'akofa', 'value': 100.0});
        expect(winner.drawDate, drawDate);
        expect(winner.drawMethod, 'random');
        expect(winner.drawProof, {'seed': 'abc123'});
        expect(winner.claimStatus, PrizeClaimStatus.claimed);
        expect(winner.claimedAt, claimedAt);
        expect(winner.claimTransactionId, 'claim_tx_123');
        expect(winner.claimExpiryDate, claimExpiryDate);
        expect(winner.metadata, {'notificationSent': true});
      });
    });
  });
}
