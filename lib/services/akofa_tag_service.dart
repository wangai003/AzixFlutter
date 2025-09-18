import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing Akofa tags - simplified wallet identifiers
/// Tags are created from user's first name + 4 random digits (e.g., "david2356")
class AkofaTagService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate a unique Akofa tag for a user
  static Future<Map<String, dynamic>> generateUniqueTag({
    required String userId,
    required String firstName,
  }) async {
    try {
      // Clean and validate first name
      final cleanFirstName = _cleanName(firstName);
      if (cleanFirstName.isEmpty) {
        return {
          'success': false,
          'error': 'First name is required to generate tag',
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

      // Store the tag mapping
      final tagData = {
        'userId': userId,
        'tag': tag,
        'publicKey': null, // Will be set when wallet is created
        'firstName': cleanFirstName,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'version': '1.0',
      };

      await _firestore.collection('akofa_tags').doc(tag).set(tagData);

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
  }) async {
    try {
      final tagDoc = await _firestore.collection('akofa_tags').doc(tag).get();

      if (!tagDoc.exists) {
        return {'success': false, 'error': 'Tag not found'};
      }

      final tagData = tagDoc.data()!;
      if (tagData['userId'] != userId) {
        return {'success': false, 'error': 'Tag does not belong to this user'};
      }

      // Update the tag with wallet address
      await _firestore.collection('akofa_tags').doc(tag).update({
        'publicKey': publicKey,
        'linkedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      return {'success': true, 'message': 'Tag linked to wallet successfully'};
    } catch (e) {
      return {'success': false, 'error': 'Failed to link tag to wallet: $e'};
    }
  }

  /// Resolve an Akofa tag to a wallet address
  static Future<Map<String, dynamic>> resolveTag(String tag) async {
    try {
      final tagDoc = await _firestore.collection('akofa_tags').doc(tag).get();

      if (!tagDoc.exists) {
        return {'success': false, 'error': 'Tag not found'};
      }

      final tagData = tagDoc.data()!;
      if (!tagData['isActive']) {
        return {'success': false, 'error': 'Tag is inactive'};
      }

      final publicKey = tagData['publicKey'];
      if (publicKey == null || publicKey.isEmpty) {
        return {'success': false, 'error': 'Tag is not linked to a wallet'};
      }

      return {
        'success': true,
        'publicKey': publicKey,
        'userId': tagData['userId'],
        'firstName': tagData['firstName'],
        'tag': tag,
      };
    } catch (e) {
      return {'success': false, 'error': 'Failed to resolve tag: $e'};
    }
  }

  /// Get user's Akofa tag
  static Future<Map<String, dynamic>> getUserTag(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('akofa_tags')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return {'success': false, 'error': 'No active tag found for user'};
      }

      final tagData = querySnapshot.docs.first.data();
      return {
        'success': true,
        'tag': tagData['tag'],
        'publicKey': tagData['publicKey'],
        'firstName': tagData['firstName'],
        'createdAt': tagData['createdAt'],
      };
    } catch (e) {
      return {'success': false, 'error': 'Failed to get user tag: $e'};
    }
  }

  /// Update user's tag (regenerate if needed)
  static Future<Map<String, dynamic>> updateUserTag({
    required String userId,
    required String newFirstName,
  }) async {
    try {
      // Get current tag
      final currentTagResult = await getUserTag(userId);
      if (!currentTagResult['success']) {
        // No existing tag, generate new one
        return await generateUniqueTag(userId: userId, firstName: newFirstName);
      }

      final currentTag = currentTagResult['tag'];

      // Deactivate current tag
      await _firestore.collection('akofa_tags').doc(currentTag).update({
        'isActive': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });

      // Generate new tag
      return await generateUniqueTag(userId: userId, firstName: newFirstName);
    } catch (e) {
      return {'success': false, 'error': 'Failed to update tag: $e'};
    }
  }

  /// Validate tag format
  static bool isValidTagFormat(String tag) {
    // Tag should be lowercase letters followed by exactly 4 digits
    final regex = RegExp(r'^[a-z]+\d{4}$');
    return regex.hasMatch(tag) && tag.length >= 5 && tag.length <= 20;
  }

  /// Search for tags (for autocomplete/suggestions)
  static Future<List<Map<String, dynamic>>> searchTags(String query) async {
    try {
      if (query.isEmpty) return [];

      final querySnapshot = await _firestore
          .collection('akofa_tags')
          .where('isActive', isEqualTo: true)
          .where('tag', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('tag', isLessThan: '${query.toLowerCase()}\uf8ff')
          .limit(10)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'tag': data['tag'],
          'firstName': data['firstName'],
          'userId': data['userId'],
        };
      }).toList();
    } catch (e) {
      return [];
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

  /// Public method for testing - clean name
  static String cleanNameForTesting(String name) {
    return _cleanName(name);
  }

  /// Public method for testing - generate tag
  static String generateTagForTesting(String cleanName) {
    return _generateTag(cleanName);
  }

  /// Check if a tag is unique in the database
  static Future<bool> _isTagUnique(String tag) async {
    try {
      final tagDoc = await _firestore.collection('akofa_tags').doc(tag).get();
      return !tagDoc.exists;
    } catch (e) {
      // If we can't check, assume it's not unique for safety
      return false;
    }
  }

  /// Get tag statistics for analytics
  static Future<Map<String, dynamic>> getTagStats() async {
    try {
      final totalTags = await _firestore
          .collection('akofa_tags')
          .where('isActive', isEqualTo: true)
          .count()
          .get();

      final recentTags = await _firestore
          .collection('akofa_tags')
          .where('isActive', isEqualTo: true)
          .where(
            'createdAt',
            isGreaterThan: DateTime.now().subtract(const Duration(days: 7)),
          )
          .count()
          .get();

      return {
        'totalActiveTags': totalTags.count,
        'recentTags': recentTags.count,
        'success': true,
      };
    } catch (e) {
      return {'success': false, 'error': 'Failed to get tag stats: $e'};
    }
  }
}
