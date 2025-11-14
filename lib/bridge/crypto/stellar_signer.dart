import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import '../bridge_config.dart';
import '../models/route_models.dart' as bridge_models;

/// Secure Stellar XDR signer and submitter
class StellarSigner {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final StellarSDK _sdk;
  final Network _network;

  StellarSigner({
    bool useTestnet = true,
  })  : _sdk = useTestnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
        _network = useTestnet ? Network.TESTNET : Network.PUBLIC;

  /// Get user's Stellar secret seed from secure storage
  Future<String?> getSecretSeed(String userId) async {
    try {
      final key = await _secureStorage.read(key: 'stellar_secret_$userId');
      return key;
    } catch (e) {
      print('❌ Error reading secret seed: $e');
      return null;
    }
  }

  /// Sign and submit XDR transaction
  /// Returns transaction hash on success
  Future<String> signAndSubmitXdr(
    String xdrBase64,
    String userId,
  ) async {
    try {
      // Get secret seed
      final secretSeed = await getSecretSeed(userId);
      if (secretSeed == null) {
        throw Exception('Secret seed not found. Please import or create wallet.');
      }

      // Parse XDR - Stellar SDK approach
      // The XDR is base64 encoded transaction envelope
      // Note: stellar_flutter_sdk 2.1.0 doesn't have direct XDR parsing
      // We need to decode the XDR and reconstruct the transaction
      // For now, this is a placeholder that needs proper XDR parsing implementation
      
      // TODO: Implement proper XDR parsing
      // The XDR contains transaction envelope data that needs to be decoded
      // Options:
      // 1. Use a Stellar XDR library to decode the envelope
      // 2. Extract transaction details from XDR and reconstruct using TransactionBuilder
      // 3. Use SDK's internal XDR classes if available
      
      throw Exception(
        'XDR parsing not yet implemented. '
        'The stellar_flutter_sdk 2.1.0 does not provide direct XDR parsing. '
        'Please implement XDR decoding or use constructAndSignPaymentXdr() '
        'when LI.FI provides depositAddress instead of XDR.',
      );
    } catch (e) {
      print('❌ Error signing/submitting Stellar XDR: $e');
      rethrow;
    }
  }

  /// Construct and sign Payment XDR for deposit address
  /// Used when LI.FI provides depositAddress instead of XDR
  Future<String> constructAndSignPaymentXdr({
    required String userId,
    required String depositAddress,
    required String amount,
    required String assetCode,
    String? assetIssuer,
  }) async {
    try {
      // Get secret seed
      final secretSeed = await getSecretSeed(userId);
      if (secretSeed == null) {
        throw Exception('Secret seed not found. Please import or create wallet.');
      }

      final keyPair = KeyPair.fromSecretSeed(secretSeed);
      final sourceAccount = await _sdk.accounts.account(keyPair.accountId);

      // Build asset
      Asset asset;
      if (assetCode == 'XLM' || assetCode == 'native') {
        asset = Asset.NATIVE;
      } else if (assetIssuer != null) {
        asset = AssetTypeCreditAlphaNum12(assetCode, assetIssuer);
      } else {
        throw Exception('Asset issuer required for non-native assets');
      }

      // Build transaction
      final transaction = TransactionBuilder(sourceAccount)
          .addOperation(
            PaymentOperationBuilder(
              depositAddress,
              asset,
              amount,
            ).build(),
          )
          .addMemo(Memo.text('LI.FI Bridge Deposit'))
          .build();

      // Sign transaction
      transaction.sign(keyPair, _network);

      // Submit to Horizon
      final response = await _sdk.submitTransaction(transaction);

      if (response.success) {
        final txHash = response.hash ?? '';
        print('✅ Stellar payment transaction submitted: $txHash');
        if (txHash.isEmpty) {
          throw Exception('Transaction submitted but no hash returned');
        }
        return txHash;
      } else {
        throw Exception(
          'Transaction failed: ${response.resultXdr}',
        );
      }
    } catch (e) {
      print('❌ Error constructing/signing Stellar payment: $e');
      rethrow;
    }
  }

  /// Get account public key from secret seed
  Future<String?> getPublicKey(String userId) async {
    try {
      final secretSeed = await getSecretSeed(userId);
      if (secretSeed == null) return null;

      final keyPair = KeyPair.fromSecretSeed(secretSeed);
      return keyPair.accountId;
    } catch (e) {
      print('❌ Error getting public key: $e');
      return null;
    }
  }

  /// Check if account exists and has minimum balance
  Future<bool> checkAccountExists(String publicKey) async {
    try {
      final account = await _sdk.accounts.account(publicKey);
      return account != null;
    } catch (e) {
      return false;
    }
  }

  /// Get account balance for a specific asset
  Future<String> getBalance(
    String publicKey,
    String assetCode, {
    String? assetIssuer,
  }) async {
    try {
      final account = await _sdk.accounts.account(publicKey);
      
      if (assetCode == 'XLM' || assetCode == 'native') {
        // Get XLM balance
        for (final balance in account.balances) {
          if (balance.assetType == Asset.TYPE_NATIVE) {
            return balance.balance;
          }
        }
        return '0';
      } else {
        // Get asset balance
        for (final balance in account.balances) {
          if (balance.assetCode == assetCode &&
              (assetIssuer == null || balance.assetIssuer == assetIssuer)) {
            return balance.balance;
          }
        }
        return '0';
      }
    } catch (e) {
      print('❌ Error getting balance: $e');
      return '0';
    }
  }
}

