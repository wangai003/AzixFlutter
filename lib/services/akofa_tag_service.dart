import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing Akofa tags - simplified wallet identifiers
/// Tags are created from user's first name + 4 random digits (e.g., "david2356")
/// Supports multiple blockchain addresses per tag
class AkofaTagService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Supported blockchains
  static const List<String> supportedBlockchains = ['stellar', 'polygon'];

  /// Generate a unique Akofa tag for a user
  static Future<Map<String, dynamic>> generateUniqueTag({
    required String userId,
    required String firstName,
    String? email,
  }) async {
    try {
      // Clean and validate first name, use email as fallback
      String nameToUse = firstName;
      if (nameToUse.trim().isEmpty && email != null && email.isNotEmpty) {
        nameToUse = email.split('@').first;
      }

      final cleanFirstName = _cleanName(nameToUse);
      if (cleanFirstName.isEmpty) {
        return {
          'success': false,
          'error': 'Unable to generate tag: no valid name or email available',
        };
      }

      // Generate tag and ensure uniqueness
      String tag;
      int attempts = 0;
      const maxAttempts = 10;

      do {
        tag = _generateTag(cleanFirstName);
        attempts++;

        if (attempts >= maxAttempts) {
          return {
            'success': false,
            'error':
                'Unable to generate unique tag after $maxAttempts attempts',
          };
        }
      } while (!(await _isTagUnique(tag)));

      // Store the tag mapping in akofaTag collection
      final tagData = {
        'userId': userId,
        'tag': tag,
        'addresses': <String, dynamic>{}, // Multi-blockchain addresses
        'firstName': cleanFirstName,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'version': '2.0',
      };

      // Store in akofaTag collection (as specified)
      await _firestore.collection('akofaTag').doc(tag).set(tagData);

      print('✅ AKOFA tag created and stored: $tag for user $userId');

      return {
        'success': true,
        'tag': tag,
        'message': 'Akofa tag generated successfully',
      };
    } catch (e) {
      return {'success': false, 'error': 'Failed to generate tag: $e'};
    }
  }

  /// Link an existing tag to a wallet address
  static Future<Map<String, dynamic>> linkTagToWallet({
    required String userId,
    required String tag,
    required String publicKey,
    required String blockchain, // 'stellar' or 'polygon'
  }) async {
    try {
      // Validate blockchain
      if (!supportedBlockchains.contains(blockchain)) {
        return {
          'success': false,
          'error': 'Unsupported blockchain: $blockchain',
        };
      }

      // Validate address format
      if (!isValidAddress(publicKey, blockchain)) {
        return {
          'success': false,
          'error': 'Invalid $blockchain address format',
        };
      }

      final tagDoc = await _firestore.collection('akofaTag').doc(tag).get();

      if (!tagDoc.exists) {
        return {'success': false, 'error': 'Tag not found'};
      }

      final tagData = tagDoc.data()!;
      if (tagData['userId'] != userId) {
        return {'success': false, 'error': 'Tag does not belong to this user'};
      }

      // Update the tag with blockchain-specific address
      final addresses = Map<String, dynamic>.from(tagData['addresses'] ?? {});
      addresses[blockchain] = {
        'address': publicKey,
        'linkedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      await _firestore.collection('akofaTag').doc(tag).update({
        'addresses': addresses,
        'linkedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // Also store in USER collection for compatibility
      await _firestore.collection('USER').doc(userId).update({
        'akofaTag': tag,
        'tagLinked': true,
        'tagLinkedAt': FieldValue.serverTimestamp(),
      });

      // Also store in secure_wallets collection for wallet-specific data
      await _firestore.collection('secure_wallets').doc(userId).update({
        'akofaTag': tag,
        'tagLinked': true,
        'tagLinkedAt': FieldValue.serverTimestamp(),
      });

      print(
        '✅ AKOFA tag linked to wallet: $tag -> $publicKey (stored in all collections)',
      );

      return {'success': true, 'message': 'Tag linked to wallet successfully'};
    } catch (e) {
      return {'success': false, 'error': 'Failed to link tag to wallet: $e'};
    }
  }

  /// Resolve an Akofa tag to a wallet address (optimized for instant resolution)
  static Future<Map<String, dynamic>> resolveTag(
    String tag, {
    required String blockchain,
  }) async {
    try {
      // Clean and validate input tag
      final cleanTag = tag.toLowerCase().trim();
      if (!isValidTagFormat(cleanTag)) {
        return {'success': false, 'error': 'Invalid tag format'};
      }

      // Query the akofaTag collection directly by document ID (most efficient)
      final tagDoc = await _firestore
          .collection('akofaTag')
          .doc(cleanTag)
          .get();

      if (!tagDoc.exists) {
        return {'success': false, 'error': 'Tag not found'};
      }

      final tagData = tagDoc.data()!;
      if (!tagData['isActive']) {
        return {'success': false, 'error': 'Tag is inactive'};
      }

      // Get addresses map (support both old and new format)
      final addresses = tagData['addresses'] as Map<String, dynamic>? ?? {};

      // For backward compatibility, check old format
      if (addresses.isEmpty && tagData['publicKey'] != null) {
        final oldAddress = tagData['publicKey'];
        if (isValidAddress(oldAddress, 'stellar')) {
          addresses['stellar'] = {
            'address': oldAddress,
            'linkedAt': tagData['linkedAt'] ?? FieldValue.serverTimestamp(),
            'isActive': true,
          };
        }
      }

      final blockchainData = addresses[blockchain];
      if (blockchainData == null || !blockchainData['isActive']) {
        return {
          'success': false,
          'error': 'No $blockchain address linked to this tag',
        };
      }

      final address = blockchainData['address'];
      if (address == null || address.isEmpty) {
        return {
          'success': false,
          'error': 'Tag is not linked to a $blockchain wallet',
        };
      }

      return {
        'success': true,
        'address': address,
        'userId': tagData['userId'],
        'firstName': tagData['firstName'],
        'tag': cleanTag,
        'blockchain': blockchain,
        'resolvedAt': FieldValue.serverTimestamp(),
      };
    } catch (e) {
      return {'success': false, 'error': 'Failed to resolve tag: $e'};
    }
  }

  /// Resolve a wallet address to an Akofa tag
  static Future<Map<String, dynamic>> resolveTagByAddress(
    String address,
  ) async {
    try {
      // Clean and validate input address
      final cleanAddress = address.trim();
      if (cleanAddress.isEmpty) {
        return {'success': false, 'error': 'Address is required'};
      }

      // Basic Stellar address validation
      if (!cleanAddress.startsWith('G') || cleanAddress.length != 56) {
        return {'success': false, 'error': 'Invalid Stellar address format'};
      }

      // Query the akofaTag collection for tags linked to this address
      final querySnapshot = await _firestore
          .collection('akofaTag')
          .where('publicKey', isEqualTo: cleanAddress)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return {
          'success': false,
          'error': 'No active tag found for this address',
        };
      }

      final tagData = querySnapshot.docs.first.data();
      final tag = querySnapshot.docs.first.id; // Document ID is the tag

      return {
        'success': true,
        'tag': tag,
        'userId': tagData['userId'],
        'firstName': tagData['firstName'],
        'publicKey': cleanAddress,
        'resolvedAt': FieldValue.serverTimestamp(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to resolve address to tag: $e',
      };
    }
  }

  /// Get user's Akofa tag
  static Future<Map<String, dynamic>> getUserTag(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('akofaTag')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return {'success': false, 'error': 'No active tag found for user'};
      }

      final tagData = querySnapshot.docs.first.data();
      final addresses = tagData['addresses'] as Map<String, dynamic>? ?? {};

      // For backward compatibility
      final stellarAddress =
          addresses['stellar']?['address'] ?? tagData['publicKey'];

      return {
        'success': true,
        'tag': tagData['tag'] ?? querySnapshot.docs.first.id,
        'addresses': addresses,
        'stellarAddress': stellarAddress,
        'firstName': tagData['firstName'],
        'createdAt': tagData['createdAt'],
      };
    } catch (e) {
      return {'success': false, 'error': 'Failed to get user tag: $e'};
    }
  }

  /// Validate tag format
  static bool isValidTagFormat(String tag) {
    // Tag should be lowercase letters followed by exactly 4 digits
    final regex = RegExp(r'^[a-z]+\d{4}$');
    return regex.hasMatch(tag) && tag.length >= 5 && tag.length <= 20;
  }

  /// Validate blockchain address format
  static bool isValidAddress(String address, String blockchain) {
    switch (blockchain) {
      case 'stellar':
        return address.startsWith('G') && address.length == 56;
      case 'polygon':
        return address.startsWith('0x') &&
            address.length == 42 &&
            RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address);
      default:
        return false;
    }
  }

  /// Clean and normalize name for tag generation
  static String _cleanName(String name) {
    final cleaned = name.toLowerCase().replaceAll(
      RegExp(r'[^a-z]'),
      '',
    ); // Remove non-letter characters

    if (cleaned.isEmpty) return '';

    return cleaned.substring(0, min(10, cleaned.length)).trim();
  }

  /// Generate a tag from cleaned name + 4 random digits
  static String _generateTag(String cleanName) {
    final random = Random();
    final digits = List.generate(4, (_) => random.nextInt(10)).join();
    return '$cleanName$digits';
  }

  /// Check if a tag is unique in the database
  static Future<bool> _isTagUnique(String tag) async {
    try {
      final tagDoc = await _firestore.collection('akofaTag').doc(tag).get();
      return !tagDoc.exists;
    } catch (e) {
      // If we can't check, assume it's not unique for safety
      return false;
    }
  }

  /// Check if user has an AKOFA tag and if it's linked to a wallet
  static Future<Map<String, dynamic>> checkUserHasTag(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('akofaTag')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return {'hasTag': false, 'isLinked': false, 'tag': null};
      }

      final tagData = querySnapshot.docs.first.data();
      final tag = querySnapshot.docs.first.id;
      final hasTag = true;

      // Check if any blockchain address is linked
      final addresses = tagData['addresses'] as Map<String, dynamic>? ?? {};
      final hasNewFormatLinks = addresses.values.any(
        (addr) =>
            addr is Map && addr['isActive'] == true && addr['address'] != null,
      );

      // For backward compatibility
      final hasOldFormatLink =
          tagData['publicKey'] != null && tagData['publicKey'].isNotEmpty;

      final isLinked = hasNewFormatLinks || hasOldFormatLink;

      return {'hasTag': hasTag, 'isLinked': isLinked, 'tag': tag};
    } catch (e) {
      return {
        'hasTag': false,
        'isLinked': false,
        'tag': null,
        'error': e.toString(),
      };
    }
  }

  /// Ensure user has an AKOFA tag, creating one if needed and linking to wallet if provided
  static Future<Map<String, dynamic>> ensureUserHasTag({
    required String userId,
    required String firstName,
    String? email,
    String? publicKey,
  }) async {
    try {
      final check = await checkUserHasTag(userId);

      if (check['hasTag']) {
        // Already has tag
        if (publicKey != null && !check['isLinked']) {
          // Link it (default to stellar for backward compatibility)
          final linkResult = await linkTagToWallet(
            userId: userId,
            tag: check['tag'],
            publicKey: publicKey,
            blockchain: 'stellar', // Default blockchain
          );

          if (linkResult['success']) {
            return {
              'success': true,
              'tag': check['tag'],
              'message': 'Tag linked to wallet successfully',
            };
          } else {
            return {
              'success': false,
              'error':
                  'Failed to link existing tag to wallet: ${linkResult['error']}',
            };
          }
        } else {
          return {
            'success': true,
            'tag': check['tag'],
            'message': 'Tag already exists',
          };
        }
      } else {
        // Generate new tag
        final generateResult = await generateUniqueTag(
          userId: userId,
          firstName: firstName,
          email: email,
        );

        if (!generateResult['success']) {
          return generateResult;
        }

        final tag = generateResult['tag'];

        if (publicKey != null) {
          // Link the new tag (default to stellar for backward compatibility)
          final linkResult = await linkTagToWallet(
            userId: userId,
            tag: tag,
            publicKey: publicKey,
            blockchain: 'stellar', // Default blockchain
          );

          if (!linkResult['success']) {
            return {
              'success': false,
              'error':
                  'Tag created but failed to link to wallet: ${linkResult['error']}',
            };
          }
        }

        return {
          'success': true,
          'tag': tag,
          'message': 'Tag created successfully',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Failed to ensure tag: $e'};
    }
  }
}
