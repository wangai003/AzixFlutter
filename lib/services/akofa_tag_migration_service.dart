import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'akofa_tag_service.dart';

/// Migration service to move from old AKOFA tag system to new simplified one-tag-per-user system
class AkofaTagMigrationService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Run the complete migration process
  static Future<Map<String, dynamic>> runMigration({
    bool dryRun = true,
    String? backupFilePath,
  }) async {
    try {
      print('🚀 Starting AKOFA tag migration (dryRun: $dryRun)...');

      // Step 1: Create backup if requested
      Map<String, dynamic>? backupData;
      if (!dryRun && backupFilePath != null) {
        backupData = await _createBackup();
        await _saveBackupToFile(backupData, backupFilePath);
        print('✅ Backup created and saved to $backupFilePath');
      }

      // Step 2: Analyze current state
      final analysis = await _analyzeCurrentState();
      print('📊 Analysis complete:');
      print('   - Total users: ${analysis['totalUsers']}');
      print(
        '   - Users with multiple tags: ${analysis['usersWithMultipleTags']}',
      );
      print('   - Users with no tags: ${analysis['usersWithNoTags']}');
      print(
        '   - Users with linked wallets: ${analysis['usersWithLinkedWallets']}',
      );

      // Step 3: Process users
      final results = await _processUsers(dryRun);

      // Step 4: Verify migration
      final verification = await _verifyMigration();

      final summary = {
        'success': true,
        'dryRun': dryRun,
        'analysis': analysis,
        'results': results,
        'verification': verification,
        'backupCreated': backupData != null,
        'timestamp': FieldValue.serverTimestamp(),
      };

      print('✅ Migration ${dryRun ? 'dry run' : 'completed'} successfully!');
      print(
        '📈 Summary: ${results['processedUsers']} users processed, '
        '${results['tagsKept']} tags kept, ${results['tagsGenerated']} tags generated',
      );

      return summary;
    } catch (e) {
      print('❌ Migration failed: $e');
      return {
        'success': false,
        'error': 'Migration failed: $e',
        'timestamp': FieldValue.serverTimestamp(),
      };
    }
  }

  /// Rollback migration using backup data
  static Future<Map<String, dynamic>> rollbackMigration(
    String backupFilePath,
  ) async {
    try {
      print('🔄 Starting rollback from $backupFilePath...');

      // Load backup data
      final backupData = await _loadBackupFromFile(backupFilePath);
      if (backupData == null) {
        return {'success': false, 'error': 'Failed to load backup file'};
      }

      // Restore collections
      await _restoreFromBackup(backupData);

      print('✅ Rollback completed successfully!');
      return {
        'success': true,
        'message': 'Rollback completed successfully',
        'timestamp': FieldValue.serverTimestamp(),
      };
    } catch (e) {
      print('❌ Rollback failed: $e');
      return {
        'success': false,
        'error': 'Rollback failed: $e',
        'timestamp': FieldValue.serverTimestamp(),
      };
    }
  }

  /// Analyze current state of the tag system
  static Future<Map<String, dynamic>> _analyzeCurrentState() async {
    final usersSnapshot = await _firestore.collection('USER').get();
    final akofaTagsSnapshot = await _firestore.collection('akofaTag').get();
    final secureWalletsSnapshot = await _firestore
        .collection('secure_wallets')
        .get();

    int totalUsers = usersSnapshot.docs.length;
    int usersWithMultipleTags = 0;
    int usersWithNoTags = 0;
    int usersWithLinkedWallets = 0;

    // Group tags by userId
    final tagsByUser = <String, List<QueryDocumentSnapshot>>{};
    for (final tagDoc in akofaTagsSnapshot.docs) {
      final userId = tagDoc.data()['userId'] as String?;
      if (userId != null) {
        tagsByUser.putIfAbsent(userId, () => []).add(tagDoc);
      }
    }

    for (final userDoc in usersSnapshot.docs) {
      final userId = userDoc.id;
      final userTags = tagsByUser[userId] ?? [];

      if (userTags.length > 1) {
        usersWithMultipleTags++;
      } else if (userTags.isEmpty) {
        usersWithNoTags++;
      }

      // Check if wallet is linked
      final secureWalletDoc = secureWalletsSnapshot.docs
          .where((doc) => doc.id == userId)
          .firstOrNull;
      if (secureWalletDoc != null) {
        final walletData = secureWalletDoc.data();
        if (walletData['akofaTag'] != null && walletData['tagLinked'] == true) {
          usersWithLinkedWallets++;
        }
      }
    }

    return {
      'totalUsers': totalUsers,
      'usersWithMultipleTags': usersWithMultipleTags,
      'usersWithNoTags': usersWithNoTags,
      'usersWithLinkedWallets': usersWithLinkedWallets,
      'totalTags': akofaTagsSnapshot.docs.length,
    };
  }

  /// Process all users for migration
  static Future<Map<String, dynamic>> _processUsers(bool dryRun) async {
    final usersSnapshot = await _firestore.collection('USER').get();
    final akofaTagsSnapshot = await _firestore.collection('akofaTag').get();

    int processedUsers = 0;
    int tagsKept = 0;
    int tagsGenerated = 0;
    int tagsRemoved = 0;
    final errors = <String>[];

    // Group tags by userId
    final tagsByUser = <String, List<QueryDocumentSnapshot>>{};
    for (final tagDoc in akofaTagsSnapshot.docs) {
      final userId = tagDoc.data()['userId'] as String?;
      if (userId != null) {
        tagsByUser.putIfAbsent(userId, () => []).add(tagDoc);
      }
    }

    for (final userDoc in usersSnapshot.docs) {
      try {
        final userId = userDoc.id;
        final userData = userDoc.data();
        final firstName =
            userData['displayName'] ?? userData['firstName'] ?? '';

        final userTags = tagsByUser[userId] ?? [];

        if (userTags.length > 1) {
          // Multiple tags: keep the most recent one
          final sortedTags =
              userTags
                  .where(
                    (tag) =>
                        (tag.data() as Map<String, dynamic>)['isActive'] ==
                        true,
                  )
                  .toList()
                ..sort((a, b) {
                  final aTime =
                      (a.data() as Map<String, dynamic>)['createdAt']
                          as Timestamp?;
                  final bTime =
                      (b.data() as Map<String, dynamic>)['createdAt']
                          as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime); // Most recent first
                });

          final tagToKeep = sortedTags.first;
          final tagsToRemove = sortedTags.skip(1);

          if (!dryRun) {
            // Mark extra tags as inactive
            for (final tagDoc in tagsToRemove) {
              await _firestore.collection('akofaTag').doc(tagDoc.id).update({
                'isActive': false,
                'deactivatedAt': FieldValue.serverTimestamp(),
                'deactivationReason': 'migration_cleanup',
              });
            }
          }

          tagsKept++;
          tagsRemoved += tagsToRemove.length;

          // Update user with the kept tag
          if (!dryRun) {
            await _updateUserWithTag(
              userId,
              tagToKeep.id,
              (tagToKeep.data() as Map<String, dynamic>)['publicKey'],
            );
          }
        } else if (userTags.isEmpty) {
          // No tags: generate new one
          if (!dryRun) {
            final tagResult = await AkofaTagService.generateUniqueTag(
              userId: userId,
              firstName: firstName,
            );

            if (tagResult['success'] == true) {
              tagsGenerated++;
            } else {
              errors.add(
                'Failed to generate tag for user $userId: ${tagResult['error']}',
              );
            }
          } else {
            tagsGenerated++;
          }
        } else {
          // Single tag: ensure it's properly linked
          final tagDoc = userTags.first;
          final tagData = tagDoc.data();

          if (!dryRun) {
            await _updateUserWithTag(
              userId,
              tagDoc.id,
              (tagData as Map<String, dynamic>)['publicKey'],
            );
          }
          tagsKept++;
        }

        processedUsers++;
      } catch (e) {
        errors.add('Error processing user ${userDoc.id}: $e');
      }
    }

    return {
      'processedUsers': processedUsers,
      'tagsKept': tagsKept,
      'tagsGenerated': tagsGenerated,
      'tagsRemoved': tagsRemoved,
      'errors': errors,
    };
  }

  /// Update user with tag information across all collections
  static Future<void> _updateUserWithTag(
    String userId,
    String tag,
    String? publicKey,
  ) async {
    final batch = _firestore.batch();

    // Update USER collection
    batch.update(_firestore.collection('USER').doc(userId), {
      'akofaTag': tag,
      'tagLinked': publicKey != null,
      'tagLinkedAt': publicKey != null ? FieldValue.serverTimestamp() : null,
    });

    // Update secure_wallets collection if wallet exists
    final secureWalletRef = _firestore.collection('secure_wallets').doc(userId);
    final secureWalletDoc = await secureWalletRef.get();
    if (secureWalletDoc.exists) {
      batch.update(secureWalletRef, {
        'akofaTag': tag,
        'tagLinked': publicKey != null,
        'tagLinkedAt': publicKey != null ? FieldValue.serverTimestamp() : null,
      });
    }

    await batch.commit();
  }

  /// Verify migration results
  static Future<Map<String, dynamic>> _verifyMigration() async {
    final analysis = await _analyzeCurrentState();

    bool isValid =
        analysis['usersWithMultipleTags'] == 0 &&
        analysis['usersWithNoTags'] == 0;

    return {
      'isValid': isValid,
      'remainingMultipleTags': analysis['usersWithMultipleTags'],
      'remainingNoTags': analysis['usersWithNoTags'],
      'totalUsers': analysis['totalUsers'],
    };
  }

  /// Create backup of current state
  static Future<Map<String, dynamic>> _createBackup() async {
    final backup = <String, dynamic>{};

    // Backup USER collection (only tag-related fields)
    final usersSnapshot = await _firestore.collection('USER').get();
    backup['USER'] = usersSnapshot.docs
        .map(
          (doc) => {
            'id': doc.id,
            'akofaTag': doc.data()['akofaTag'],
            'tagLinked': doc.data()['tagLinked'],
            'tagLinkedAt': doc.data()['tagLinkedAt'],
            'stellarPublicKey': doc.data()['stellarPublicKey'],
          },
        )
        .toList();

    // Backup akofaTag collection
    final tagsSnapshot = await _firestore.collection('akofaTag').get();
    backup['akofaTag'] = tagsSnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();

    // Backup secure_wallets collection (only tag-related fields)
    final walletsSnapshot = await _firestore.collection('secure_wallets').get();
    backup['secure_wallets'] = walletsSnapshot.docs
        .map(
          (doc) => {
            'id': doc.id,
            'akofaTag': doc.data()['akofaTag'],
            'tagLinked': doc.data()['tagLinked'],
            'tagLinkedAt': doc.data()['tagLinkedAt'],
            'publicKey': doc.data()['publicKey'],
          },
        )
        .toList();

    backup['timestamp'] = FieldValue.serverTimestamp();
    return backup;
  }

  /// Save backup to file
  static Future<void> _saveBackupToFile(
    Map<String, dynamic> backupData,
    String filePath,
  ) async {
    final file = File(filePath);
    await file.writeAsString(jsonEncode(backupData));
  }

  /// Load backup from file
  static Future<Map<String, dynamic>?> _loadBackupFromFile(
    String filePath,
  ) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      print('Error loading backup: $e');
      return null;
    }
  }

  /// Restore from backup
  static Future<void> _restoreFromBackup(
    Map<String, dynamic> backupData,
  ) async {
    final batch = _firestore.batch();

    // Restore USER collection
    for (final userData in backupData['USER'] ?? []) {
      final userId = userData['id'];
      batch.update(_firestore.collection('USER').doc(userId), {
        'akofaTag': userData['akofaTag'],
        'tagLinked': userData['tagLinked'],
        'tagLinkedAt': userData['tagLinkedAt'],
        'stellarPublicKey': userData['stellarPublicKey'],
      });
    }

    // Restore akofaTag collection
    for (final tagData in backupData['akofaTag'] ?? []) {
      final tagId = tagData['id'];
      final data = Map<String, dynamic>.from(tagData)..remove('id');
      batch.set(_firestore.collection('akofaTag').doc(tagId), data);
    }

    // Restore secure_wallets collection
    for (final walletData in backupData['secure_wallets'] ?? []) {
      final walletId = walletData['id'];
      batch.update(_firestore.collection('secure_wallets').doc(walletId), {
        'akofaTag': walletData['akofaTag'],
        'tagLinked': walletData['tagLinked'],
        'tagLinkedAt': walletData['tagLinkedAt'],
        'publicKey': walletData['publicKey'],
      });
    }

    await batch.commit();
  }
}
