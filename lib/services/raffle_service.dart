import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:crypto/crypto.dart';
import '../models/raffle_model.dart';
import '../models/user_model.dart';
import 'notification_service.dart';
import 'ipfs_service.dart';

/// Simplified raffle management service for gift voucher raffles
class RaffleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final Random _random = Random.secure();

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

  /// Simple raffle entry - just click to join!
  static Future<String> enterRaffle({
    required String raffleId,
    required String userId,
    required String userName,
    required String userEmail,
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
        throw Exception('You have already entered this raffle');
      }

      // Create entry
      final entryData = {
        'raffleId': raffleId,
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'entryDate': FieldValue.serverTimestamp(),
        'verificationData': {
          'ipAddress': 'mobile',
          'timestamp': DateTime.now().toIso8601String(),
        },
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

      // Send confirmation notification to user
      await NotificationService.createNotification(
        userId: userId,
        type: NotificationType.general,
        title: '🎉 You\'re In!',
        message: 'You have successfully entered the raffle "${raffle.title}". Good luck!',
        data: {'raffleId': raffleId, 'entryId': entryRef.id},
      );

      return entryRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Get raffles with optional filtering (excludes completed raffles by default)
  static Stream<List<RaffleModel>> getRaffles({
    String? creatorId,
    RaffleStatus? status,
    bool? isPublic,
    int? limit,
    String? orderBy = 'createdAt',
    bool descending = true,
    bool includeCompleted = false,
  }) {
    try {
      Query query = _firestore.collection(_rafflesCollection);

      if (creatorId != null) {
        query = query.where('creatorId', isEqualTo: creatorId);
      }

      if (status != null) {
        query = query.where('status', isEqualTo: status.toString());
      }
      // Note: We'll filter out completed/cancelled in the map function
      // to avoid Firestore index requirements

      if (isPublic != null) {
        query = query.where('isPublic', isEqualTo: isPublic);
      }

      query = query.orderBy(orderBy!, descending: descending);

      if (limit != null) {
        query = query.limit(limit);
      }

      return query.snapshots().map((snapshot) {
        final raffles = snapshot.docs.map((doc) {
          try {
            return RaffleModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          } catch (e) {
            print('Error parsing raffle ${doc.id}: $e');
            return null;
          }
        }).whereType<RaffleModel>().toList();

        // Filter out completed and cancelled raffles if requested
        if (!includeCompleted) {
          return raffles.where((raffle) {
            return raffle.status != RaffleStatus.completed &&
                   raffle.status != RaffleStatus.cancelled;
          }).toList();
        }

        return raffles;
      }).handleError((error) {
        print('Error in raffles stream: $error');
        return <RaffleModel>[];
      });
    } catch (e) {
      print('Error setting up raffles query: $e');
      return Stream.value(<RaffleModel>[]);
    }
  }

  /// Create a new raffle (simplified for gift vouchers)
  /// STRICT ADMIN CHECK - Only admins can create raffles
  static Future<String> createRaffle({
    required String creatorId,
    required String creatorName,
    required String title,
    required String description,
    required Map<String, dynamic> prizeDetails,
    required int maxEntries,
    required DateTime startDate,
    required DateTime endDate,
    String? imageUrl,
  }) async {
    try {
      // STRICT SERVER-SIDE ADMIN VERIFICATION
      final userDoc = await _firestore.collection('USER').doc(creatorId).get();
      
      if (!userDoc.exists) {
        throw Exception('User not found. Cannot create raffle.');
      }

      final userData = userDoc.data() as Map<String, dynamic>?;
      final role = userData?['role'] as String? ?? 'user';

      // Only admin or super_admin can create raffles (NOT vendor)
      if (role != 'admin' && role != 'super_admin') {
        throw Exception(
          'Access Denied: Only administrators can create raffles. '
          'Your role: $role'
        );
      }

      // Simple entry requirements - just click to join
      final entryRequirements = {
        'type': 'free',
        'description': 'Click to join - no payment required',
      };

      final raffleData = {
        'creatorId': creatorId,
        'creatorName': creatorName,
        'title': title,
        'description': description,
        'entryRequirements': entryRequirements,
        'prizeDetails': prizeDetails,
        'maxEntries': maxEntries,
        'currentEntries': 0,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'status': startDate.isBefore(DateTime.now())
            ? RaffleStatus.active.toString()
            : RaffleStatus.upcoming.toString(),
        'isPublic': true,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore
          .collection(_rafflesCollection)
          .add(raffleData);

      print('✅ Raffle created successfully by admin ($role): ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Error creating raffle: $e');
      rethrow;
    }
  }

  /// Automatically draw winner for expired raffles
  static Future<void> drawWinnerForRaffle(String raffleId) async {
    try {
      final raffle = await getRaffle(raffleId);
      if (raffle == null) throw Exception('Raffle not found');

      // Check if raffle has ended
      if (!raffle.isExpired) {
        throw Exception('Raffle has not ended yet');
      }

      // Check if winner already drawn
      if (raffle.status == RaffleStatus.completed) {
        throw Exception('Winner already drawn for this raffle');
      }

      // Get all valid entries
      final entriesSnapshot = await _firestore
          .collection(_entriesCollection)
          .where('raffleId', isEqualTo: raffleId)
          .where('isValid', isEqualTo: true)
          .get();

      if (entriesSnapshot.docs.isEmpty) {
        // No participants, cancel the raffle
        await _firestore.collection(_rafflesCollection).doc(raffleId).update({
          'status': RaffleStatus.cancelled.toString(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      // Legitimately randomize winner selection using secure random
      final entries = entriesSnapshot.docs;
      final winnerIndex = _selectRandomWinner(entries.length, raffleId);
      final winnerEntry = entries[winnerIndex];
      final winnerData = winnerEntry.data();

      // Create winner record
      final winnerRecord = {
        'raffleId': raffleId,
        'entryId': winnerEntry.id,
        'winnerUserId': winnerData['userId'],
        'winnerName': winnerData['userName'],
        'winnerEmail': winnerData['userEmail'] ?? '',
        'winnerPosition': 1,
        'prizeDetails': raffle.prizeDetails,
        'drawDate': FieldValue.serverTimestamp(),
        'drawMethod': 'secure_random',
        'drawProof': {
          'timestamp': DateTime.now().toIso8601String(),
          'totalEntries': entries.length,
          'winnerIndex': winnerIndex,
          'algorithm': 'dart_secure_random',
        },
        'claimStatus': PrizeClaimStatus.unclaimed.toString(),
        'metadata': {
          'raffleTitle': raffle.title,
          'raffleImage': raffle.imageUrl,
        },
      };

      await _firestore.collection(_winnersCollection).add(winnerRecord);

      // Update raffle status to completed
      await _firestore.collection(_rafflesCollection).doc(raffleId).update({
        'status': RaffleStatus.completed.toString(),
        'drawDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to winner
      await NotificationService.createNotification(
        userId: winnerData['userId'],
        type: NotificationType.general,
        title: '🎉 Congratulations! You Won!',
        message: 'You won the raffle "${raffle.title}"! Check your prizes.',
        data: {
          'raffleId': raffleId,
          'isWinner': true,
          'prizeDetails': raffle.prizeDetails,
        },
      );

      // Send consolation notifications to non-winners
      for (var entry in entries) {
        if (entry.id != winnerEntry.id) {
          final entryData = entry.data();
          await NotificationService.createNotification(
            userId: entryData['userId'],
            type: NotificationType.general,
            title: 'Raffle Results',
            message: 'The raffle "${raffle.title}" has ended. Better luck next time!',
            data: {'raffleId': raffleId, 'isWinner': false},
          );
        }
      }

      print('✅ Winner drawn for raffle $raffleId: ${winnerData['userName']}');
    } catch (e) {
      print('❌ Error drawing winner for raffle $raffleId: $e');
      rethrow;
    }
  }

  /// Secure random winner selection with additional entropy
  static int _selectRandomWinner(int participantCount, String raffleId) {
    // Use secure random with additional entropy from timestamp and raffle ID
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final raffleHash = raffleId.hashCode;
    
    // Combine multiple sources of entropy
    final entropy1 = _random.nextInt(participantCount);
    final entropy2 = (timestamp % participantCount);
    final entropy3 = (raffleHash.abs() % participantCount);
    
    // XOR the entropy sources for additional randomness
    final combinedEntropy = (entropy1 ^ entropy2 ^ entropy3) % participantCount;
    
    // Final selection with additional random factor
    final finalIndex = (_random.nextInt(participantCount) + combinedEntropy) % participantCount;
    
    return finalIndex;
  }

  /// Check and auto-draw winners for expired raffles
  static Future<void> checkAndDrawExpiredRaffles() async {
    try {
      final now = Timestamp.now();
      
      // Get all active raffles that have ended
      final expiredRaffles = await _firestore
          .collection(_rafflesCollection)
          .where('status', isEqualTo: RaffleStatus.active.toString())
          .where('endDate', isLessThan: now)
          .get();

      for (var doc in expiredRaffles.docs) {
        try {
          await drawWinnerForRaffle(doc.id);
        } catch (e) {
          print('Error drawing winner for raffle ${doc.id}: $e');
        }
      }
    } catch (e) {
      print('Error checking expired raffles: $e');
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

  /// Delete a raffle (admin or creator only)
  /// Also deletes all related entries and winners
  static Future<void> deleteRaffle({
    required String raffleId,
    required String userId,
    required bool isAdmin,
  }) async {
    try {
      // Fetch the raffle to verify it exists
      final raffle = await getRaffle(raffleId);
      if (raffle == null) {
        throw Exception('Raffle not found');
      }

      // Verify that the caller is admin or creator
      if (!isAdmin && raffle.creatorId != userId) {
        throw Exception(
          'Unauthorized: Only admins or the creator can delete raffles',
        );
      }

      // Check if raffle has already been drawn (warn but allow deletion)
      if (raffle.status == RaffleStatus.completed) {
        print('⚠️ Warning: Deleting a completed raffle with winners');
      }

      // Delete all entries for this raffle
      final entriesSnapshot = await _firestore
          .collection(_entriesCollection)
          .where('raffleId', isEqualTo: raffleId)
          .get();

      final batch = _firestore.batch();
      for (var entryDoc in entriesSnapshot.docs) {
        batch.delete(entryDoc.reference);
      }

      // Delete all winners for this raffle
      final winnersSnapshot = await _firestore
          .collection(_winnersCollection)
          .where('raffleId', isEqualTo: raffleId)
          .get();

      for (var winnerDoc in winnersSnapshot.docs) {
        batch.delete(winnerDoc.reference);
      }

      // Delete the raffle itself
      batch.delete(_firestore.collection(_rafflesCollection).doc(raffleId));

      // Commit all deletions
      await batch.commit();

      print('✅ Raffle $raffleId deleted successfully along with ${entriesSnapshot.docs.length} entries and ${winnersSnapshot.docs.length} winners');
    } catch (e) {
      print('❌ Error deleting raffle: $e');
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

  /// Get all recent winners across all raffles
  static Stream<List<RaffleWinnerModel>> getAllRecentWinners({int limit = 10}) {
    return _firestore
        .collection(_winnersCollection)
        .orderBy('drawDate', descending: true)
        .limit(limit)
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

  /// Check if user has entered a specific raffle
  static Future<bool> hasUserEnteredRaffle(String userId, String raffleId) async {
    final entries = await _firestore
        .collection(_entriesCollection)
        .where('userId', isEqualTo: userId)
        .where('raffleId', isEqualTo: raffleId)
        .limit(1)
        .get();
    
    return entries.docs.isNotEmpty;
  }

  /// Get user's entry for a raffle
  static Future<RaffleEntryModel?> getUserRaffleEntry(
    String userId,
    String raffleId,
  ) async {
    final entries = await _firestore
        .collection(_entriesCollection)
        .where('userId', isEqualTo: userId)
        .where('raffleId', isEqualTo: raffleId)
        .limit(1)
        .get();
    
    if (entries.docs.isEmpty) return null;
    
    final doc = entries.docs.first;
    return RaffleEntryModel.fromMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }
}
