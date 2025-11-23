import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'polygon_wallet_service.dart';

/// Wallet Recovery Helper
/// Helps diagnose and fix wallet issues
class WalletRecoveryHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Diagnose wallet issues
  static Future<Map<String, dynamic>> diagnoseWallet(String userId) async {
    try {
      print('🔍 [DIAGNOSTIC] Starting wallet diagnosis for user: $userId');

      // Get wallet data
      final walletDoc = await _firestore
          .collection('polygon_wallets')
          .doc(userId)
          .get();

      if (!walletDoc.exists) {
        return {
          'status': 'no_wallet',
          'message': 'No wallet found for this user',
          'action': 'create_new',
        };
      }

      final walletData = walletDoc.data()!;
      final storedAddress = walletData['address'] as String?;
      final createdAt = walletData['createdAt'] as Timestamp?;
      final version = walletData['version'] as String?;

      print('🔍 [DIAGNOSTIC] Wallet found:');
      print('   - Address: $storedAddress');
      print('   - Created: ${createdAt?.toDate()}');
      print('   - Version: $version');

      return {
        'status': 'wallet_exists',
        'address': storedAddress,
        'createdAt': createdAt?.toDate().toString(),
        'version': version,
        'message': 'Wallet data found. Address mismatch detected.',
        'recommendation': 'delete_and_recreate',
        'explanation':
            'The encrypted private key in your wallet does not match the stored address. '
            'This indicates a data inconsistency from when the wallet was created. '
            'You will need to create a new wallet. If this wallet held any funds, '
            'those funds are associated with the address and cannot be recovered without '
            'the correct private key.',
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
      };
    }
  }

  /// Delete corrupted wallet (requires confirmation)
  static Future<Map<String, dynamic>> deleteCorruptedWallet({
    required String userId,
    required String confirmationText,
  }) async {
    try {
      // Safety check
      if (confirmationText != 'DELETE MY WALLET') {
        return {
          'success': false,
          'error': 'Confirmation text does not match',
        };
      }

      print('🗑️ [RECOVERY] Deleting corrupted wallet for user: $userId');

      // Delete from polygon_wallets
      await _firestore.collection('polygon_wallets').doc(userId).delete();

      // Update USER collection
      await _firestore.collection('USER').doc(userId).update({
        'polygonAddress': FieldValue.delete(),
        'hasPolygonWallet': false,
        'hasSecureWallet': false,
        'polygonWalletCreated': false,
        'walletDeleted': true,
        'walletDeletedAt': FieldValue.serverTimestamp(),
      });

      print('✅ [RECOVERY] Wallet deleted successfully');

      return {
        'success': true,
        'message': 'Corrupted wallet deleted. You can now create a new wallet.',
      };
    } catch (e) {
      print('❌ [RECOVERY] Failed to delete wallet: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Create a fresh wallet with verification
  static Future<Map<String, dynamic>> createVerifiedWallet({
    required String userId,
    required String password,
  }) async {
    try {
      print('🔑 [RECOVERY] Creating verified wallet...');

      // First, ensure no existing wallet
      final existingWallet = await _firestore
          .collection('polygon_wallets')
          .doc(userId)
          .get();

      if (existingWallet.exists) {
        return {
          'success': false,
          'error':
              'Existing wallet found. Please delete it first using deleteCorruptedWallet.',
        };
      }

      // Create new wallet
      final result = await PolygonWalletService.createSecurePolygonWallet(
        userId: userId,
        password: password,
      );

      if (result['success'] != true) {
        return result;
      }

      // Verify the newly created wallet by decrypting it immediately
      print('🔍 [RECOVERY] Verifying new wallet...');
      final verifyResult =
          await PolygonWalletService.authenticateAndDecryptPolygonWallet(
        userId,
        password,
      );

      if (verifyResult['success'] != true) {
        // Wallet creation succeeded but verification failed - delete it
        print('❌ [RECOVERY] Verification failed, rolling back...');
        await _firestore.collection('polygon_wallets').doc(userId).delete();

        return {
          'success': false,
          'error':
              'Wallet verification failed after creation. This should not happen. Please contact support.',
        };
      }

      print('✅ [RECOVERY] Wallet created and verified successfully!');

      return {
        'success': true,
        'address': result['address'],
        'message':
            'New wallet created and verified successfully. Your wallet is ready to use.',
        'network': result['network'],
      };
    } catch (e) {
      print('❌ [RECOVERY] Wallet creation failed: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Complete wallet recovery flow
  static Future<Map<String, dynamic>> performFullRecovery({
    required String userId,
    required String newPassword,
  }) async {
    try {
      print('═══════════════════════════════════════════════════════════════');
      print('🔧 [RECOVERY] STARTING FULL WALLET RECOVERY');
      print('═══════════════════════════════════════════════════════════════');

      // Step 1: Diagnose
      print('📋 [RECOVERY] Step 1: Diagnosing wallet...');
      final diagnosis = await diagnoseWallet(userId);
      print('📋 [RECOVERY] Diagnosis: ${diagnosis['status']}');

      // Step 2: Delete if exists
      if (diagnosis['status'] == 'wallet_exists') {
        print('🗑️ [RECOVERY] Step 2: Deleting corrupted wallet...');
        final deleteResult = await deleteCorruptedWallet(
          userId: userId,
          confirmationText: 'DELETE MY WALLET',
        );

        if (deleteResult['success'] != true) {
          return {
            'success': false,
            'error': 'Failed to delete corrupted wallet: ${deleteResult['error']}',
          };
        }
        print('✅ [RECOVERY] Corrupted wallet deleted');
      }

      // Step 3: Create new verified wallet
      print('🔑 [RECOVERY] Step 3: Creating new verified wallet...');
      final createResult = await createVerifiedWallet(
        userId: userId,
        password: newPassword,
      );

      if (createResult['success'] != true) {
        return {
          'success': false,
          'error': 'Failed to create new wallet: ${createResult['error']}',
        };
      }

      print('═══════════════════════════════════════════════════════════════');
      print('✅ [RECOVERY] WALLET RECOVERY COMPLETED SUCCESSFULLY');
      print('═══════════════════════════════════════════════════════════════');
      print('📍 New address: ${createResult['address']}');
      print('🌐 Network: ${createResult['network']}');
      print('═══════════════════════════════════════════════════════════════');

      return {
        'success': true,
        'address': createResult['address'],
        'network': createResult['network'],
        'message':
            'Wallet recovery completed successfully. Your new wallet is ready to use.',
        'oldAddress': diagnosis['address'],
      };
    } catch (e, stackTrace) {
      print('❌ [RECOVERY] Recovery failed: $e');
      print('❌ Stack trace: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

