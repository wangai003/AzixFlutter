import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/raffle_model.dart';
import '../models/user_model.dart';
import 'notification_service.dart';
import 'ipfs_service.dart';
import 'soroban_raffle_service.dart';

/// Comprehensive raffle management service
class RaffleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Collection references
  static const String _rafflesCollection = 'raffles';
  static const String _entriesCollection = 'raffle_entries';
  static const String _winnersCollection = 'raffle_winners';

  /// Get a raffle by ID
  static Future<RaffleModel?> getRaffle(String raffleId) async {
    try {
      final doc = await _firestore
          .collection(_rafflesCollection)
          .doc(raffleId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        return RaffleModel.fromMap(data, doc.id);
      }
      return null;
    } catch (e) {
      print('Error fetching raffle: $e');
      return null;
    }
  }

  /// Enhanced raffle entry with Soroban integration
  static Future<String> enterRaffle({
    required String raffleId,
    required String userId,
    required String userName,
    String? userEmail,
    required Map<String, dynamic> verificationData,
    String? referralCode,
    String? transactionId,
  }) async {
    try {
      // Check if raffle requires blockchain verification
      final raffle = await getRaffle(raffleId);
      if (raffle == null) throw Exception('Raffle not found');

      // If raffle has blockchain requirements, use Soroban service
      if (raffle.entryRequirements.containsKey('blockchainRequired') &&
          raffle.entryRequirements['blockchainRequired'] == true) {
        final entryAmount =
            (raffle.entryRequirements['akofaAmount'] as num?)?.toDouble() ??
            0.0;

        if (entryAmount > 0) {
          // Use Soroban service for blockchain entry
          final sorobanResult = await SorobanRaffleService.enterRaffle(
            raffleId: raffleId,
            userId: userId,
            password: '', // Password will be prompted in the service
            entryAmount: entryAmount,
          );

          if (!sorobanResult['success']) {
            throw Exception(
              'Blockchain entry failed: ${sorobanResult['error']}',
            );
          }

          // Return the blockchain transaction ID
          return sorobanResult['transactionHash'] as String;
        }
      }

      // Fallback to Firebase-only entry
      return await _enterRaffleFirebase(
        raffleId: raffleId,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        verificationData: verificationData,
        referralCode: referralCode,
        transactionId: transactionId,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Get raffles with optional filtering
  static Stream<List<RaffleModel>> getRaffles({
    String? creatorId,
    RaffleStatus? status,
    bool? isPublic,
    int? limit,
    String? orderBy = 'createdAt',
    bool descending = true,
  }) {
    Query query = _firestore.collection(_rafflesCollection);

    if (creatorId != null) {
      query = query.where('creatorId', isEqualTo: creatorId);
    }

    if (status != null) {
      query = query.where('status', isEqualTo: status.toString());
    }

    if (isPublic != null) {
      query = query.where('isPublic', isEqualTo: isPublic);
    }

    query = query.orderBy(orderBy!, descending: descending);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return RaffleModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Create a new raffle
  static Future<String> createRaffle({
    required String creatorId,
    required String creatorName,
    required String title,
    required String description,
    required Map<String, dynamic> entryRequirements,
    required Map<String, dynamic> prizeDetails,
    required int maxEntries,
    required DateTime startDate,
    required DateTime endDate,
    String? detailedDescription,
    String? imageUrl,
    required bool isPublic,
  }) async {
    try {
      final raffleData = {
        'creatorId': creatorId,
        'creatorName': creatorName,
        'title': title,
        'description': description,
        'detailedDescription': detailedDescription,
        'entryRequirements': entryRequirements,
        'prizeDetails': prizeDetails,
        'maxEntries': maxEntries,
        'currentEntries': 0,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'status': RaffleStatus.upcoming.toString(),
        'isPublic': isPublic,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore
          .collection(_rafflesCollection)
          .add(raffleData);

      // Create IPFS metadata if needed
      try {
        final metadata = IPFSService.createRaffleIPFSMetadata(
          raffleId: docRef.id,
          creatorId: creatorId,
          creatorName: creatorName,
          title: title,
          description: description,
          detailedDescription: detailedDescription,
          prizeDetails: prizeDetails,
          entryRequirements: entryRequirements,
          maxEntries: maxEntries,
          startDate: startDate,
          endDate: endDate,
          galleryImages: imageUrl != null ? [imageUrl] : null,
        );
        await IPFSService.uploadRaffleMetadata(metadata: metadata);
      } catch (e) {
        print('Failed to create IPFS metadata: $e');
        // Don't fail the raffle creation for IPFS issues
      }

      return docRef.id;
    } catch (e) {
      print('Error creating raffle: $e');
      rethrow;
    }
  }

  /// Firebase-only raffle entry (existing implementation)
  static Future<String> _enterRaffleFirebase({
    required String raffleId,
    required String userId,
    required String userName,
    String? userEmail,
    required Map<String, dynamic> verificationData,
    String? referralCode,
    String? transactionId,
  }) async {
    try {
      // Check if raffle exists and is active
      final raffle = await getRaffle(raffleId);
      if (raffle == null) throw Exception('Raffle not found');
      if (!raffle.canEnter) throw Exception('Raffle is not accepting entries');

      // Check if user already entered
      final existingEntry = await _firestore
          .collection(_entriesCollection)
          .where('raffleId', isEqualTo: raffleId)
          .where('userId', isEqualTo: userId)
          .get();

      if (existingEntry.docs.isNotEmpty) {
        throw Exception('User has already entered this raffle');
      }

      // Create entry
      final entryData = {
        'raffleId': raffleId,
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'entryDate': FieldValue.serverTimestamp(),
        'verificationData': verificationData,
        'referralCode': referralCode,
        'transactionId': transactionId,
        'isValid': true,
      };

      final entryRef = await _firestore
          .collection(_entriesCollection)
          .add(entryData);

      // Update raffle entry count
      await _firestore.collection(_rafflesCollection).doc(raffleId).update({
        'currentEntries': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to user
      await NotificationService.createNotification(
        userId: userId,
        type: NotificationType.general,
        title: 'Raffle Entry Confirmed',
        message: 'You have successfully entered the raffle "${raffle.title}"',
        data: {'raffleId': raffleId, 'entryId': entryRef.id},
      );

      return entryRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Update the status of a raffle
  static Future<void> updateRaffleStatus({
    required String raffleId,
    required RaffleStatus newStatus,
    required String creatorId,
  }) async {
    try {
      // Fetch the raffle to verify it exists and check creator
      final raffle = await getRaffle(raffleId);
      if (raffle == null) {
        throw Exception('Raffle not found');
      }

      // Verify that the caller is the creator
      if (raffle.creatorId != creatorId) {
        throw Exception(
          'Unauthorized: Only the creator can update the raffle status',
        );
      }

      // Update the status in Firestore
      await _firestore.collection(_rafflesCollection).doc(raffleId).update({
        'status': newStatus.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating raffle status: $e');
      rethrow;
    }
  }

  /// Get user's entries for a specific raffle
  static Future<List<RaffleEntryModel>> getUserEntries({
    required String raffleId,
    required String userId,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(_entriesCollection)
          .where('raffleId', isEqualTo: raffleId)
          .where('userId', isEqualTo: userId)
          .get();

      return querySnapshot.docs.map((doc) {
        return RaffleEntryModel.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    } catch (e) {
      print('Error fetching user entries: $e');
      return [];
    }
  }

  /// Listen to entries count updates for a raffle
  static Stream<int> listenToEntriesCount(String raffleId) {
    return _firestore
        .collection(_rafflesCollection)
        .doc(raffleId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            return data['currentEntries'] as int? ?? 0;
          }
          return 0;
        });
  }

  /// Listen to raffle updates
  static Stream<RaffleModel?> listenToRaffle(String raffleId) {
    return _firestore
        .collection(_rafflesCollection)
        .doc(raffleId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            return RaffleModel.fromMap(data, doc.id);
          }
          return null;
        });
  }

  /// Get all entries for a raffle
  static Stream<List<RaffleEntryModel>> getRaffleEntries(String raffleId) {
    return _firestore
        .collection(_entriesCollection)
        .where('raffleId', isEqualTo: raffleId)
        .orderBy('entryDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return RaffleEntryModel.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();
        });
  }

  /// Get raffle winners as a stream
  static Stream<List<RaffleWinnerModel>> getRaffleWinners(String raffleId) {
    return _firestore
        .collection(_winnersCollection)
        .where('raffleId', isEqualTo: raffleId)
        .orderBy('winnerPosition')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return RaffleWinnerModel.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();
        });
  }
}
