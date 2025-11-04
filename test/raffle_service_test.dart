import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:azixflutter/services/raffle_service.dart';
import 'package:azixflutter/models/raffle_model.dart';
import 'package:azixflutter/models/raffle_entry_model.dart';
import 'package:azixflutter/services/notification_service.dart';
import 'package:azixflutter/services/soroban_raffle_service.dart';

// Generate mocks
@GenerateMocks([
  FirebaseFirestore,
  FirebaseAuth,
  User,
  DocumentReference,
  CollectionReference,
  QuerySnapshot,
  QueryDocumentSnapshot,
  DocumentSnapshot,
  NotificationService,
  SorobanRaffleService,
])
import 'raffle_service_test.mocks.dart';

void main() {
  late RaffleService raffleService;
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockDocumentReference<Map<String, dynamic>> mockDocRef;
  late MockCollectionReference<Map<String, dynamic>> mockCollectionRef;
  late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
  late MockQueryDocumentSnapshot<Map<String, dynamic>> mockQueryDoc;
  late MockDocumentSnapshot<Map<String, dynamic>> mockDocSnapshot;
  late MockNotificationService mockNotificationService;
  late MockSorobanRaffleService mockSorobanService;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockDocRef = MockDocumentReference();
    mockCollectionRef = MockCollectionReference();
    mockQuerySnapshot = MockQuerySnapshot();
    mockQueryDoc = MockQueryDocumentSnapshot();
    mockDocSnapshot = MockDocumentSnapshot();
    mockNotificationService = MockNotificationService();
    mockSorobanService = MockSorobanRaffleService();

    // Setup Firebase instances
    when(mockFirestore.collection(any)).thenReturn(mockCollectionRef);
    when(mockCollectionRef.doc(any)).thenReturn(mockDocRef);
    when(
      mockCollectionRef.where(any, isEqualTo: anyNamed('isEqualTo')),
    ).thenReturn(mockCollectionRef as Query<Map<String, dynamic>>);
    when(mockCollectionRef.add(any)).thenAnswer((_) async => mockDocRef);
    when(mockDocRef.id).thenReturn('test_doc_id');
    when(mockDocRef.update(any)).thenAnswer((_) async => null);

    raffleService = RaffleService();
  });

  group('RaffleService Unit Tests', () {
    group('Raffle Creation', () {
      test('createRaffle should create raffle successfully', () async {
        // Mock successful document creation
        when(mockDocRef.set(any)).thenAnswer((_) async => null);

        final raffleId = await RaffleService.createRaffle(
          creatorId: 'test_creator',
          creatorName: 'Test Creator',
          title: 'Test Raffle',
          description: 'Test Description',
          entryRequirements: {'type': 'free'},
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          maxEntries: 100,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 7)),
        );

        expect(raffleId, isNotNull);
        expect(raffleId, isA<String>());
        verify(mockDocRef.set(any)).called(1);
      });

      test('createRaffle should handle image upload', () async {
        when(mockDocRef.set(any)).thenAnswer((_) async => null);

        final raffleId = await RaffleService.createRaffle(
          creatorId: 'test_creator',
          creatorName: 'Test Creator',
          title: 'Test Raffle',
          description: 'Test Description',
          entryRequirements: {'type': 'free'},
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          maxEntries: 100,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 7)),
          imageUrl: 'https://example.com/image.jpg',
        );

        expect(raffleId, isNotNull);
        verify(mockDocRef.set(any)).called(1);
      });

      test('createRaffle should handle detailed description', () async {
        when(mockDocRef.set(any)).thenAnswer((_) async => null);

        final raffleId = await RaffleService.createRaffle(
          creatorId: 'test_creator',
          creatorName: 'Test Creator',
          title: 'Test Raffle',
          description: 'Test Description',
          entryRequirements: {'type': 'free'},
          prizeDetails: {'type': 'akofa', 'value': 100.0},
          maxEntries: 100,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 7)),
          detailedDescription: 'Detailed description here',
        );

        expect(raffleId, isNotNull);
        verify(mockDocRef.set(any)).called(1);
      });
    });

    group('Raffle Retrieval', () {
      test('getRaffle should return raffle model when found', () async {
        final mockData = {
          'title': 'Test Raffle',
          'description': 'Test Description',
          'creatorId': 'test_creator',
          'creatorName': 'Test Creator',
          'entryRequirements': {'type': 'free'},
          'prizeDetails': {'type': 'akofa', 'value': 100.0},
          'maxEntries': 100,
          'currentEntries': 0,
          'startDate': Timestamp.fromDate(DateTime.now()),
          'endDate': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7)),
          ),
          'status': 'active',
          'isPublic': true,
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        };

        when(mockDocSnapshot.exists).thenReturn(true);
        when(mockDocSnapshot.data()).thenReturn(mockData);
        when(mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);

        final raffle = await RaffleService.getRaffle('test_raffle_id');

        expect(raffle, isNotNull);
        expect(raffle!.title, 'Test Raffle');
        expect(raffle.creatorId, 'test_creator');
        expect(raffle.maxEntries, 100);
      });

      test('getRaffle should return null when not found', () async {
        when(mockDocSnapshot.exists).thenReturn(false);
        when(mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);

        final raffle = await RaffleService.getRaffle('nonexistent_raffle');

        expect(raffle, isNull);
      });

      test('getRaffles should return list of raffles', () async {
        final mockData = {
          'title': 'Test Raffle',
          'description': 'Test Description',
          'creatorId': 'test_creator',
          'creatorName': 'Test Creator',
          'entryRequirements': {'type': 'free'},
          'prizeDetails': {'type': 'akofa', 'value': 100.0},
          'maxEntries': 100,
          'currentEntries': 0,
          'startDate': Timestamp.fromDate(DateTime.now()),
          'endDate': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7)),
          ),
          'status': 'active',
          'isPublic': true,
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        };

        when(mockQueryDoc.data()).thenReturn(mockData);
        when(mockQueryDoc.id).thenReturn('raffle_1');
        when(mockQuerySnapshot.docs).thenReturn([mockQueryDoc]);
        when(
          mockCollectionRef.get(),
        ).thenAnswer((_) async => mockQuerySnapshot);

        final raffles = await RaffleService.getRaffles();

        expect(raffles, isNotEmpty);
        expect(raffles.first.title, 'Test Raffle');
      });
    });

    group('Raffle Entry', () {
      test('enterRaffle should handle free entry successfully', () async {
        // Mock raffle exists and is active
        final raffleData = {
          'title': 'Test Raffle',
          'description': 'Test Description',
          'creatorId': 'test_creator',
          'creatorName': 'Test Creator',
          'entryRequirements': {'type': 'free'},
          'prizeDetails': {'type': 'akofa', 'value': 100.0},
          'maxEntries': 100,
          'currentEntries': 0,
          'startDate': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 1)),
          ),
          'endDate': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7)),
          ),
          'status': 'active',
          'isPublic': true,
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        };

        when(mockDocSnapshot.exists).thenReturn(true);
        when(mockDocSnapshot.data()).thenReturn(raffleData);
        when(mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);

        // Mock no existing entries
        when(mockQuerySnapshot.docs).thenReturn([]);
        when(
          mockCollectionRef.get(),
        ).thenAnswer((_) async => mockQuerySnapshot);

        // Mock successful entry creation
        when(mockCollectionRef.add(any)).thenAnswer((_) async => mockDocRef);

        final entryId = await RaffleService.enterRaffle(
          raffleId: 'test_raffle',
          userId: 'test_user',
          userName: 'Test User',
          verificationData: {'entryType': 'free'},
        );

        expect(entryId, isNotNull);
        expect(entryId, 'test_doc_id');
        verify(mockCollectionRef.add(any)).called(1);
        verify(mockDocRef.update(any)).called(1); // Update entry count
      });

      test('enterRaffle should reject duplicate entries', () async {
        // Mock raffle exists
        final raffleData = {
          'title': 'Test Raffle',
          'description': 'Test Description',
          'creatorId': 'test_creator',
          'creatorName': 'Test Creator',
          'entryRequirements': {'type': 'free'},
          'prizeDetails': {'type': 'akofa', 'value': 100.0},
          'maxEntries': 100,
          'currentEntries': 0,
          'startDate': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 1)),
          ),
          'endDate': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7)),
          ),
          'status': 'active',
          'isPublic': true,
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        };

        when(mockDocSnapshot.exists).thenReturn(true);
        when(mockDocSnapshot.data()).thenReturn(raffleData);
        when(mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);

        // Mock existing entry
        when(mockQuerySnapshot.docs).thenReturn([mockQueryDoc]);
        when(
          mockCollectionRef.get(),
        ).thenAnswer((_) async => mockQuerySnapshot);

        expect(
          () => RaffleService.enterRaffle(
            raffleId: 'test_raffle',
            userId: 'test_user',
            userName: 'Test User',
            verificationData: {'entryType': 'free'},
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('already entered'),
            ),
          ),
        );
      });

      test('enterRaffle should reject entries for inactive raffles', () async {
        // Mock raffle exists but is completed
        final raffleData = {
          'title': 'Test Raffle',
          'description': 'Test Description',
          'creatorId': 'test_creator',
          'creatorName': 'Test Creator',
          'entryRequirements': {'type': 'free'},
          'prizeDetails': {'type': 'akofa', 'value': 100.0},
          'maxEntries': 100,
          'currentEntries': 0,
          'startDate': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 7)),
          ),
          'endDate': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 1)),
          ),
          'status': 'completed',
          'isPublic': true,
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        };

        when(mockDocSnapshot.exists).thenReturn(true);
        when(mockDocSnapshot.data()).thenReturn(raffleData);
        when(mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);

        expect(
          () => RaffleService.enterRaffle(
            raffleId: 'test_raffle',
            userId: 'test_user',
            userName: 'Test User',
            verificationData: {'entryType': 'free'},
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('not accepting entries'),
            ),
          ),
        );
      });

      test('enterRaffle should handle blockchain entries', () async {
        // Mock raffle with blockchain requirements
        final raffleData = {
          'title': 'Test Raffle',
          'description': 'Test Description',
          'creatorId': 'test_creator',
          'creatorName': 'Test Creator',
          'entryRequirements': {
            'type': 'blockchain',
            'blockchainRequired': true,
            'akofaAmount': 50.0,
          },
          'prizeDetails': {'type': 'akofa', 'value': 100.0},
          'maxEntries': 100,
          'currentEntries': 0,
          'startDate': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 1)),
          ),
          'endDate': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7)),
          ),
          'status': 'active',
          'isPublic': true,
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        };

        when(mockDocSnapshot.exists).thenReturn(true);
        when(mockDocSnapshot.data()).thenReturn(raffleData);
        when(mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);

        // Mock successful Soroban entry
        when(
          mockSorobanService.enterRaffle(
            raffleId: anyNamed('raffleId'),
            userId: anyNamed('userId'),
            password: anyNamed('password'),
            entryAmount: anyNamed('entryAmount'),
          ),
        ).thenAnswer(
          (_) async => {'success': true, 'transactionHash': 'mock_tx_hash'},
        );

        final entryId = await RaffleService.enterRaffle(
          raffleId: 'test_raffle',
          userId: 'test_user',
          userName: 'Test User',
          verificationData: {'entryType': 'blockchain'},
        );

        expect(entryId, 'mock_tx_hash');
        verify(
          mockSorobanService.enterRaffle(
            raffleId: 'test_raffle',
            userId: 'test_user',
            password: '',
            entryAmount: 50.0,
          ),
        ).called(1);
      });
    });

    group('Winner Management', () {
      test('drawWinners should select winners correctly', () async {
        // Mock raffle with entries
        final raffleData = {
          'title': 'Test Raffle',
          'description': 'Test Description',
          'creatorId': 'test_creator',
          'creatorName': 'Test Creator',
          'entryRequirements': {'type': 'free'},
          'prizeDetails': {'type': 'akofa', 'value': 100.0},
          'maxEntries': 100,
          'currentEntries': 3,
          'startDate': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 7)),
          ),
          'endDate': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 1)),
          ),
          'status': 'active',
          'isPublic': true,
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        };

        when(mockDocSnapshot.exists).thenReturn(true);
        when(mockDocSnapshot.data()).thenReturn(raffleData);
        when(mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);

        // Mock raffle entries
        final entryData1 = {
          'raffleId': 'test_raffle',
          'userId': 'user1',
          'userName': 'User 1',
          'entryDate': Timestamp.fromDate(DateTime.now()),
          'verificationData': {},
          'isValid': true,
        };
        final entryData2 = {
          'raffleId': 'test_raffle',
          'userId': 'user2',
          'userName': 'User 2',
          'entryDate': Timestamp.fromDate(DateTime.now()),
          'verificationData': {},
          'isValid': true,
        };
        final entryData3 = {
          'raffleId': 'test_raffle',
          'userId': 'user3',
          'userName': 'User 3',
          'entryDate': Timestamp.fromDate(DateTime.now()),
          'verificationData': {},
          'isValid': true,
        };

        final mockEntryDoc1 = MockQueryDocumentSnapshot();
        final mockEntryDoc2 = MockQueryDocumentSnapshot();
        final mockEntryDoc3 = MockQueryDocumentSnapshot();

        when(mockEntryDoc1.data()).thenReturn(entryData1);
        when(mockEntryDoc1.id).thenReturn('entry1');
        when(mockEntryDoc2.data()).thenReturn(entryData2);
        when(mockEntryDoc2.id).thenReturn('entry2');
        when(mockEntryDoc3.data()).thenReturn(entryData3);
        when(mockEntryDoc3.id).thenReturn('entry3');

        when(
          mockQuerySnapshot.docs,
        ).thenReturn([mockEntryDoc1, mockEntryDoc2, mockEntryDoc3]);
        when(
          mockCollectionRef.get(),
        ).thenAnswer((_) async => mockQuerySnapshot);

        final winners = await RaffleService.drawWinners(
          raffleId: 'test_raffle',
          numberOfWinners: 1,
        );

        expect(winners, isNotEmpty);
        expect(winners.length, 1);
        expect(winners.first.winnerUserId, isIn(['user1', 'user2', 'user3']));
      });

      test('claimPrize should update winner status', () async {
        // Mock successful prize claim
        when(mockDocRef.update(any)).thenAnswer((_) async => null);

        await RaffleService.claimPrize(
          winnerId: 'test_winner',
          userId: 'test_user',
          transactionId: 'test_tx',
        );

        verify(mockDocRef.update(any)).called(1);
      });
    });

    group('Raffle Updates', () {
      test('updateRaffleStatus should update status correctly', () async {
        when(mockDocRef.update(any)).thenAnswer((_) async => null);

        await RaffleService.updateRaffleStatus(
          raffleId: 'test_raffle',
          status: RaffleStatus.completed,
          creatorId: 'test_creator',
        );

        verify(mockDocRef.update(any)).called(1);
      });
    });
  });
}
