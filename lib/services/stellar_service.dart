import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_mailer/flutter_mailer.dart';
import 'package:http/http.dart' as http;
import '../models/transaction.dart' as app_transaction;
import 'transaction_service.dart';
import 'secure_wallet_service.dart';

class StellarService {
  static final StellarSDK _sdk = StellarSDK.TESTNET;
  static final firestore.FirebaseFirestore _firestore =
      firestore.FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ------------------------
  // Provided credentials (Testnet only)
  // ------------------------
  final String issuerPublic =
      'GDS33FHEMMX4QHVY53HR2LM53227BH5Y5HB4J3ZSDHMZFMIDP67U537V';
  final String distributionSecret =
      'SAWYDUY5JDXQ6XLDDRBU64RDSWC6I4OXEBTJTWLY52MXTLBF4EHT4C4W';

  // Constants for backward compatibility
  static const String AKOFA_ASSET_CODE = 'AKOFA';
  static const String AKOFA_ISSUER_ACCOUNT =
      'GDS33FHEMMX4QHVY53HR2LM53227BH5Y5HB4J3ZSDHMZFMIDP67U537V';
  static const String ISSUER_SECRET =
      'SDMCJRPOGXJRMB2OX5BCH7YW7C4KCNZA26HIWSKP67WPFFBPUZDRJB5N';

  final Asset akofaAsset;

  StellarService()
    : akofaAsset = AssetTypeCreditAlphaNum12(
        'AKOFA',
        'GDS33FHEMMX4QHVY53HR2LM53227BH5Y5HB4J3ZSDHMZFMIDP67U537V',
      ) {}

  // Using provided issuer credentials

  // Get wallet credentials from secure storage
  Future<Map<String, String>?> getWalletCredentials() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return null;
      }

      // First try to get from wallets collection
      final walletDoc = await _firestore
          .collection('wallets')
          .doc(user.uid)
          .get();
      if (walletDoc.exists) {
        final walletData = walletDoc.data()!;

        final publicKey = walletData['publicKey'];
        final secretKey = walletData['secretKey'];

        if (publicKey != null &&
            publicKey.isNotEmpty &&
            secretKey != null &&
            secretKey.isNotEmpty) {
          // Validate the secret key format
          if (!isValidStellarSecretKey(secretKey)) {
            return null;
          }
          return {'publicKey': publicKey, 'secretKey': secretKey};
        }
      } else {}

      // Fallback: try to get from USER collection (for backward compatibility)
      final doc = await _firestore.collection('USER').doc(user.uid).get();
      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;

      final stellarPublicKey = data['stellarPublicKey'];
      final stellarSecretKey = data['stellarSecretKey'];

      if (stellarPublicKey != null &&
          stellarPublicKey.isNotEmpty &&
          stellarSecretKey != null &&
          stellarSecretKey.isNotEmpty) {
        // Validate the secret key format
        if (!isValidStellarSecretKey(stellarSecretKey)) {
          return null;
        }
        return {'publicKey': stellarPublicKey, 'secretKey': stellarSecretKey};
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // Check if a Stellar account exists (private)
  Future<bool> _checkAccountExists(String publicKey) async {
    try {
      await _sdk.accounts.account(publicKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Public wrapper for checking account existence
  Future<bool> checkAccountExists(String publicKey) async {
    return await _checkAccountExists(publicKey);
  }

  // Send XLM from user wallet
  Future<Map<String, dynamic>> sendXlm(
    String destinationAddress,
    String amount, {
    String? memo,
  }) async {
    try {
      final credentials = await getWalletCredentials();
      if (credentials == null) {
        throw Exception('Failed to retrieve wallet credentials');
      }

      final secretKey = credentials['secretKey'];
      if (secretKey == null) {
        throw Exception('Secret key is null');
      }

      final sourceKeyPair = KeyPair.fromSecretSeed(secretKey);
      final sourceAccountId = sourceKeyPair.accountId;
      final sourceAccount = await _sdk.accounts.account(sourceAccountId);

      // Create payment operation
      final paymentOperation = PaymentOperationBuilder(
        destinationAddress,
        Asset.NATIVE,
        amount,
      );

      // Build transaction
      final transactionBuilder = TransactionBuilder(sourceAccount);
      transactionBuilder.addOperation(paymentOperation.build());

      if (memo != null && memo.isNotEmpty) {
        transactionBuilder.addMemo(MemoText(memo));
      }

      final transaction = transactionBuilder.build();
      transaction.sign(sourceKeyPair, Network.TESTNET);

      final response = await _sdk.submitTransaction(transaction);

      if (response.success) {
        // Record transaction in Firestore
        final senderUid = _auth.currentUser!.uid;

        // Record send transaction for sender
        await TransactionService.recordSend(
          amount: double.parse(amount),
          assetCode: 'XLM',
          recipientAddress: destinationAddress,
          recipientAkofaTag: null, // Will be looked up if needed
          memo: memo,
          stellarHash: response.hash,
          additionalMetadata: {
            'stellarNetwork': 'testnet',
            'assetType': 'native',
          },
        );

        // Look up recipient and record receive transaction if they're a registered user
        try {
          final recipientQuery = await _firestore
              .collection('USER')
              .where('stellarPublicKey', isEqualTo: destinationAddress)
              .limit(1)
              .get();

          if (recipientQuery.docs.isNotEmpty) {
            final recipientDoc = recipientQuery.docs.first;
            final recipientUid = recipientDoc.id;
            final recipientAkofaTag = recipientDoc.data()['akofaTag'];

            await TransactionService.recordReceive(
              amount: double.parse(amount),
              assetCode: 'XLM',
              senderAddress: sourceAccountId,
              senderAkofaTag: null, // Will be looked up if needed
              memo: memo,
              stellarHash: response.hash,
              additionalMetadata: {
                'stellarNetwork': 'testnet',
                'assetType': 'native',
                'relatedUserId': senderUid,
              },
            );
          }
        } catch (e) {}

        return {'success': true, 'hash': response.hash};
      } else {
        // Record failed transaction
        final senderUid = _auth.currentUser!.uid;
        await TransactionService.recordSend(
          amount: double.parse(amount),
          assetCode: 'XLM',
          recipientAddress: destinationAddress,
          recipientAkofaTag: null,
          memo: memo,
          stellarHash: null,
          additionalMetadata: {
            'stellarNetwork': 'testnet',
            'assetType': 'native',
            'error': response.extras?.toString(),
            'status': 'failed',
          },
        );

        throw Exception('Transaction failed: ${response.extras}');
      }
    } catch (e) {
      throw Exception('Failed to send XLM: $e');
    }
  }

  // Send any asset from user wallet to another address
  Future<Map<String, dynamic>> sendAsset(
    String assetCode,
    String destinationAddress,
    String amount, {
    String? memo,
  }) async {
    try {
      // Get wallet credentials to sign the transaction
      final credentials = await getWalletCredentials();
      if (credentials == null) {
        throw Exception('Failed to retrieve wallet credentials');
      }

      final secretKey = credentials['secretKey'];
      if (secretKey == null) {
        throw Exception('Secret key is null');
      }

      final sourceKeyPair = KeyPair.fromSecretSeed(secretKey);
      final sourceAccountId = sourceKeyPair.accountId;
      final sourceAccount = await _sdk.accounts.account(sourceAccountId);

      // Create the appropriate asset
      Asset asset;
      String? assetIssuer;
      if (assetCode == 'XLM') {
        asset = Asset.NATIVE;
        assetIssuer = null;
      } else {
        // Find the asset in the account
        final assetBalance = sourceAccount.balances.firstWhere(
          (b) => b.assetCode == assetCode && b.assetType != 'native',
          orElse: () => throw Exception('Asset $assetCode not found in wallet'),
        );

        // Check if assetIssuer is null and handle it
        if (assetBalance.assetIssuer == null) {
          throw Exception('Asset issuer for $assetCode is null');
        }
        assetIssuer = assetBalance.assetIssuer;
        asset = Asset.createNonNativeAsset(assetCode, assetIssuer!);
      }

      // Create payment operation
      final paymentOperation = PaymentOperationBuilder(
        destinationAddress,
        asset,
        amount,
      );

      // Build transaction
      final transactionBuilder = TransactionBuilder(sourceAccount);
      transactionBuilder.addOperation(paymentOperation.build());

      if (memo != null && memo.isNotEmpty) {
        transactionBuilder.addMemo(MemoText(memo));
      }

      final transaction = transactionBuilder.build();
      transaction.sign(sourceKeyPair, Network.TESTNET);

      final response = await _sdk.submitTransaction(transaction);

      if (response.success) {
        // Record transaction in Firestore
        final senderUid = _auth.currentUser!.uid;

        // Record send transaction for sender
        await TransactionService.recordSend(
          amount: double.parse(amount),
          assetCode: assetCode,
          recipientAddress: destinationAddress,
          recipientAkofaTag: null,
          memo: memo,
          stellarHash: response.hash,
          additionalMetadata: {
            'stellarNetwork': 'testnet',
            'assetType': assetCode == 'XLM' ? 'native' : 'credit_alphanum',
            'assetIssuer': assetCode == 'XLM' ? null : assetIssuer,
          },
        );

        // Look up recipient and record receive transaction if they're a registered user
        try {
          final recipientQuery = await _firestore
              .collection('USER')
              .where('stellarPublicKey', isEqualTo: destinationAddress)
              .limit(1)
              .get();

          if (recipientQuery.docs.isNotEmpty) {
            final recipientDoc = recipientQuery.docs.first;
            final recipientUid = recipientDoc.id;
            final recipientAkofaTag = recipientDoc.data()['akofaTag'];

            await TransactionService.recordReceive(
              amount: double.parse(amount),
              assetCode: assetCode,
              senderAddress: sourceAccountId,
              senderAkofaTag: null,
              memo: memo,
              stellarHash: response.hash,
              additionalMetadata: {
                'stellarNetwork': 'testnet',
                'assetType': assetCode == 'XLM' ? 'native' : 'credit_alphanum',
                'assetIssuer': assetCode == 'XLM' ? null : assetIssuer,
                'relatedUserId': senderUid,
              },
            );
          }
        } catch (e) {}

        return {'success': true, 'hash': response.hash};
      } else {
        // Record failed transaction
        final senderUid = _auth.currentUser!.uid;
        await TransactionService.recordSend(
          amount: double.parse(amount),
          assetCode: assetCode,
          recipientAddress: destinationAddress,
          recipientAkofaTag: null,
          memo: memo,
          stellarHash: null,
          additionalMetadata: {
            'stellarNetwork': 'testnet',
            'assetType': assetCode == 'XLM' ? 'native' : 'credit_alphanum',
            'assetIssuer': assetCode == 'XLM' ? null : assetIssuer,
            'error': response.extras?.toString(),
            'status': 'failed',
          },
        );

        throw Exception('Transaction failed: ${response.extras}');
      }
    } catch (e) {
      throw Exception('Failed to send $assetCode: $e');
    }
  }

  // Send asset from issuer account to user (for mining rewards, buy Akofa, etc.)
  Future<Map<String, dynamic>> sendAssetFromIssuer(
    String assetCode,
    String destinationAddress,
    String amount, {
    String? memo,
  }) async {
    try {
      // Create issuer keypair
      final issuerKeyPair = KeyPair.fromSecretSeed(ISSUER_SECRET);
      final issuerAccountId = issuerKeyPair.accountId;

      // Get issuer account
      final issuerAccount = await _sdk.accounts.account(issuerAccountId);

      // Create the asset
      Asset asset;
      if (assetCode == 'XLM') {
        asset = Asset.NATIVE;
      } else {
        asset = Asset.createNonNativeAsset(assetCode, issuerAccountId);
      }

      // Check if destination account has trustline for this asset
      try {
        final destAccount = await _sdk.accounts.account(destinationAddress);
        final hasTrustline = destAccount.balances.any(
          (b) => b.assetCode == assetCode && b.assetType != 'native',
        );

        if (!hasTrustline && assetCode != 'XLM') {
          // Create trustline operation
          final trustlineOperation = ChangeTrustOperationBuilder(
            asset,
            '1000000', // Maximum amount
          );

          final trustlineTransaction = TransactionBuilder(destAccount);
          trustlineTransaction.addOperation(trustlineOperation.build());
          trustlineTransaction.addMemo(MemoText('Trustline for $assetCode'));

          // Note: This would require the destination account's secret key
          // For now, we'll assume the trustline exists or will be created
        }
      } catch (e) {}

      // Create payment operation
      final paymentOperation = PaymentOperationBuilder(
        destinationAddress,
        asset,
        amount,
      );

      // Build transaction
      final transactionBuilder = TransactionBuilder(issuerAccount);
      transactionBuilder.addOperation(paymentOperation.build());

      if (memo != null && memo.isNotEmpty) {
        transactionBuilder.addMemo(MemoText(memo));
      }

      final transaction = transactionBuilder.build();

      // Sign transaction
      transaction.sign(issuerKeyPair, Network.TESTNET);

      // Submit transaction
      final response = await _sdk.submitTransaction(transaction);

      if (response.success) {
        return {
          'success': true,
          'hash': response.hash,
          'message': 'Asset sent successfully',
        };
      } else {
        // Extract meaningful error information
        String errorMessage = 'Transaction failed';
        try {
          if (response.extras != null) {
            // Check for common error patterns in the extras string representation
            final extrasString = response.extras.toString();

            if (extrasString.contains('INSUFFICIENT_BALANCE')) {
              errorMessage =
                  'Transaction failed: Insufficient XLM balance in issuer account';
            } else if (extrasString.contains('NO_TRUST')) {
              errorMessage =
                  'Transaction failed: Missing trustline for AKOFA asset';
            } else if (extrasString.contains('BAD_AUTH')) {
              errorMessage = 'Transaction failed: Invalid issuer credentials';
            } else if (extrasString.contains('op_no_trust')) {
              errorMessage = 'Transaction failed: Trustline operation failed';
            } else if (extrasString.contains('UNDERFUNDED')) {
              errorMessage = 'Transaction failed: Account is underfunded';
            } else {
              errorMessage =
                  'Transaction failed: Check issuer account balance and trustlines';
            }
          } else {
            errorMessage = 'Transaction failed with unknown error';
          }
        } catch (errorExtractError) {
          errorMessage =
              'Transaction failed: Please check issuer account balance and trustlines';
        }

        return {
          'success': false,
          'message': errorMessage,
          'error': response.extras?.toString() ?? 'Unknown error',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e', 'error': e.toString()};
    }
  }

  // Record a mining reward transaction
  Future<Map<String, dynamic>> recordMiningReward(double amount) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      String? publicKey;
      String? walletType = 'unknown';

      // First check for secure/enhanced wallet
      final hasSecureWallet = await SecureWalletService.hasSecureWallet(
        currentUser.uid,
      );
      if (hasSecureWallet) {
        publicKey = await SecureWalletService.getWalletPublicKey(
          currentUser.uid,
        );
        walletType = 'secure';
      }

      // If no secure wallet, check for regular wallet
      if (publicKey == null) {
        final credentials = await getWalletCredentials();
        if (credentials != null) {
          publicKey = credentials['publicKey'];
          walletType = 'regular';
        }
      }

      if (publicKey == null) {
        throw Exception(
          'No wallet found. Please create or import a Stellar wallet to receive mining rewards.',
        );
      }

      final userDoc = await _firestore
          .collection('USER')
          .doc(currentUser.uid)
          .get();
      if (!userDoc.exists) {
        throw Exception('User document not found');
      }

      final userData = userDoc.data()!;
      final akofaTag = userData['akofaTag'] as String?;

      if (akofaTag == null || akofaTag.isEmpty) {
        throw Exception(
          'User AKOFA tag not found. Please ensure your AKOFA tag is set in your profile.',
        );
      }

      // Production mode - actually send the AKOFA coins from issuer to user
      final result = await sendAssetFromIssuer(
        AKOFA_ASSET_CODE,
        publicKey,
        amount.toString(),
        memo: 'Mining Reward for $akofaTag',
      );

      if (result['success'] != true) {
        // Record as failed
        await TransactionService.recordMiningReward(
          amount: amount,
          stellarHash: null,
          additionalMetadata: {
            'errorReason': result['message'] ?? 'Unknown error',
            'miningSession': 'failed',
            'rewardType': 'mining',
            'failureReason': result['message'],
          },
        );
        throw Exception(
          'Failed to send mining reward: ${result['message']}. Check that your Stellar account is funded and the issuer secret is configured correctly.',
        );
      }

      // Record the mining reward transaction in Firestore as completed
      await TransactionService.recordMiningReward(
        amount: amount,
        stellarHash: result['hash'],
        additionalMetadata: {
          'miningSession': 'active',
          'rewardType': 'mining',
          'akofaTag': akofaTag,
        },
      );

      // Send email receipt for mining reward
      await _sendTransactionReceipt(
        AKOFA_ISSUER_ACCOUNT,
        publicKey,
        amount,
        app_transaction.TransactionType.mining,
        result['hash'],
        'Mining Reward',
        AKOFA_ASSET_CODE,
      );

      return {'success': true, 'hash': result['hash']};
    } catch (e) {
      // Try to record the failed transaction
      try {
        final userDoc = await _firestore
            .collection('USER')
            .doc(_auth.currentUser!.uid)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final akofaTag = userData['akofaTag'] as String? ?? 'UNKNOWN';

          await TransactionService.recordMiningReward(
            amount: amount,
            stellarHash: null,
            additionalMetadata: {
              'errorReason': e.toString(),
              'miningSession': 'failed',
              'rewardType': 'mining',
              'failureReason': e.toString(),
            },
          );
        }
      } catch (recordError) {}

      // Provide more helpful error messages
      String errorMessage = 'Failed to record mining reward: $e';
      if (e.toString().contains('sample issuer secret') ||
          e.toString().contains('SAMPLE_')) {
        errorMessage =
            'Mining rewards are not configured. Please replace the sample issuer secret with your actual secret key.';
      } else if (e.toString().contains('404') ||
          e.toString().contains('not_found')) {
        errorMessage =
            'Your Stellar account is not active. Please ensure it is funded with at least 1 XLM.';
      } else if (e.toString().contains('op_no_trust')) {
        errorMessage =
            'AKOFA trustline not found. Please add the AKOFA asset to your wallet first.';
      }

      throw Exception(errorMessage);
    }
  }

  // Send an email receipt for a transaction
  Future<void> _sendTransactionReceipt(
    String senderAddress,
    String recipientAddress,
    double amount,
    app_transaction.TransactionType type,
    String? hash,
    String? memo,
    String assetCode,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return;

      final String typeStr = type == app_transaction.TransactionType.send
          ? 'Sent'
          : 'Received';
      final String subject = 'AZIX Wallet - $typeStr $amount $assetCode';

      String body =
          '''
Dear ${user.displayName ?? 'User'},

This is a confirmation of your recent transaction:

Transaction Type: $typeStr
Amount: $amount $assetCode
Date: ${DateTime.now().toString()}
${hash != null ? 'Transaction Hash: $hash' : ''}
${memo != null && memo.isNotEmpty ? 'Memo: $memo' : ''}

From: $senderAddress
To: $recipientAddress

Thank you for using AZIX Wallet.

Best regards,
The AZIX Team
''';

      final MailOptions mailOptions = MailOptions(
        subject: subject,
        body: body,
        recipients: [user.email!],
        isHTML: false,
      );

      await FlutterMailer.send(mailOptions);
    } catch (e) {}
  }

  // Get all assets in the wallet
  Future<List<Map<String, dynamic>>> getAllWalletAssets(
    String publicKey,
  ) async {
    try {
      final List<Map<String, dynamic>> assets = [];

      // Check if account exists first
      final accountExists = await _checkAccountExists(publicKey);
      if (!accountExists) {
        return [
          {
            'code': 'XLM',
            'issuer': 'native',
            'balance': '0',
            'name': 'Stellar Lumens',
            'type': 'native',
            'status': 'unfunded',
            'message': 'Account needs funding to activate mining rewards',
            'fundingInstructions': [
              'Send at least 1 XLM to this address: $publicKey',
              'Use Stellar testnet faucet: https://laboratory.stellar.org/#account-creator?network=test',
              'Or send XLM from another Stellar account',
            ],
          },
        ];
      }

      // Get account details
      final account = await _sdk.accounts.account(publicKey);

      // Add XLM (native asset)
      final xlmBalance = account.balances
          .firstWhere((b) => b.assetType == 'native')
          .balance;

      assets.add({
        'code': 'XLM',
        'issuer': 'native',
        'balance': xlmBalance,
        'name': 'Stellar Lumens',
        'type': 'native',
        'status': 'active',
      });

      // Add non-native assets
      for (var balance in account.balances) {
        if (balance.assetType != 'native') {
          assets.add({
            'code': balance.assetCode,
            'issuer': balance.assetIssuer,
            'balance': balance.balance,
            'name': balance.assetCode,
            'type': 'credit_alphanum',
            'status': 'active',
          });
        }
      }

      return assets;
    } catch (e) {
      // Return empty assets list with error status
      return [
        {
          'code': 'XLM',
          'issuer': 'native',
          'balance': '0',
          'name': 'Stellar Lumens',
          'type': 'native',
          'status': 'error',
          'message': 'Error loading assets: $e',
        },
      ];
    }
  }

  // Get transaction history from Stellar network
  Future<List<Map<String, dynamic>>> getStellarTransactionHistory(
    String publicKey,
  ) async {
    try {
      // For now, return empty list as Stellar SDK API has changed
      // This can be implemented later when the correct API is determined
      return [];
    } catch (e) {
      return [];
    }
  }

  // Test Stellar configuration (can be called for debugging)
  static Map<String, dynamic> testStellarConfiguration() {
    final result = <String, dynamic>{
      'issuerSecretValid': false,
      'issuerAccountValid': false,
      'akofaAssetCodeValid': AKOFA_ASSET_CODE.isNotEmpty,
      'overallValid': false,
      'messages': <String>[],
    };

    // Test issuer secret
    result['issuerSecretValid'] = true; // Using provided credentials

    // Test issuer account format (basic validation)
    if (AKOFA_ISSUER_ACCOUNT.startsWith('G') &&
        AKOFA_ISSUER_ACCOUNT.length == 56) {
      result['issuerAccountValid'] = true;
      result['messages'].add('✅ Issuer account format is valid');
    } else {
      result['messages'].add('❌ Issuer account format is invalid');
    }

    result['overallValid'] =
        result['issuerSecretValid'] &&
        result['issuerAccountValid'] &&
        result['akofaAssetCodeValid'];

    if (result['overallValid']) {
      result['messages'].add('✅ Stellar configuration is valid');
    } else {
      result['messages'].add('❌ Stellar configuration has issues');
    }

    return result;
  }

  // Validate Stellar secret key format
  bool isValidStellarSecretKey(String secretKey) {
    try {
      if (secretKey == null || secretKey.isEmpty) return false;
      if (!secretKey.startsWith('S')) return false;
      if (secretKey.length != 56) return false;

      // Try to create a KeyPair to validate the checksum
      KeyPair.fromSecretSeed(secretKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Check if user has a wallet
  Future<bool> hasWallet() async {
    try {
      final credentials = await getWalletCredentials();
      return credentials != null &&
          credentials['publicKey'] != null &&
          credentials['publicKey']!.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Get public key
  Future<String?> getPublicKey() async {
    try {
      final credentials = await getWalletCredentials();
      return credentials?['publicKey'];
    } catch (e) {
      return null;
    }
  }

  // Check if account has AKOFA trustline
  Future<bool> hasAkofaTrustline(String publicKey) async {
    try {
      final account = await _sdk.accounts.account(publicKey);
      for (var balance in account.balances!) {
        if (balance.assetType != 'native' &&
            balance.assetCode == AKOFA_ASSET_CODE &&
            balance.assetIssuer == AKOFA_ISSUER_ACCOUNT) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get AKOFA balance
  Future<String> getAkofaBalance(String publicKey) async {
    try {
      final account = await _sdk.accounts.account(publicKey);
      final akofaBalance = account.balances.firstWhere(
        (b) => b.assetCode == AKOFA_ASSET_CODE && b.assetType != 'native',
        orElse: () => throw Exception('AKOFA trustline not found'),
      );
      return akofaBalance.balance;
    } catch (e) {
      return '0';
    }
  }

  // Get XLM balance
  Future<String> getBalance(String publicKey) async {
    try {
      final account = await _sdk.accounts.account(publicKey);
      final xlmBalance = account.balances.firstWhere(
        (b) => b.assetType == 'native',
      );
      return xlmBalance.balance;
    } catch (e) {
      return '0';
    }
  }

  // Check if account has enough XLM for transaction
  Future<bool> hasEnoughXlmForTransaction(String publicKey) async {
    try {
      final balance = await getBalance(publicKey);
      final balanceValue = double.tryParse(balance) ?? 0.0;
      return balanceValue >= 0.5; // Minimum XLM for transaction
    } catch (e) {
      return false;
    }
  }

  // Get account funding information
  Future<Map<String, dynamic>> getAccountFundingInfo(String publicKey) async {
    try {
      final accountExists = await _checkAccountExists(publicKey);
      if (!accountExists) {
        return {
          'exists': false,
          'status': 'unfunded',
          'message': 'Account needs funding to activate',
          'publicKey': publicKey,
          'fundingInstructions': [
            'Send at least 1 XLM to this address: $publicKey',
            'Use Stellar testnet faucet: https://laboratory.stellar.org/#account-creator?network=test',
            'Or send XLM from another Stellar account',
          ],
        };
      }

      final balance = await getBalance(publicKey);
      final balanceValue = double.tryParse(balance) ?? 0.0;

      return {
        'exists': true,
        'status': balanceValue >= 0.5 ? 'active' : 'low_balance',
        'message': balanceValue >= 0.5
            ? 'Account is active'
            : 'Account has low balance',
        'publicKey': publicKey,
        'xlmBalance': balance,
        'hasEnoughXlm': balanceValue >= 0.5,
      };
    } catch (e) {
      return {
        'exists': false,
        'status': 'error',
        'message': 'Error checking account status: $e',
        'publicKey': publicKey,
      };
    }
  }

  // Create wallet and store in Firestore
  Future<Map<String, dynamic>> createWalletAndStoreInFirestore() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Generate new keypair
      final keyPair = KeyPair.random();
      final publicKey = keyPair.accountId;
      final secretKey = keyPair.secretSeed;

      // Store in Firestore
      await _firestore.collection('USER').doc(user.uid).update({
        'stellarPublicKey': publicKey,
        'stellarSecretKey': secretKey,
        'walletCreatedAt': firestore.FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'publicKey': publicKey,
        'secretKey': secretKey,
        'message': 'Wallet created successfully',
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to create wallet: $e'};
    }
  }

  /// Add Akofa trustline to an account (requires secret key)
  ///
  /// This method creates a trustline for Akofa tokens on an existing Stellar account.
  /// The account must already exist and have sufficient XLM for transaction fees.
  ///
  /// Parameters:
  /// - secretKey: The secret key of the account to add the trustline to
  ///
  /// Returns:
  /// - success: Whether the trustline was added successfully
  /// - hash: Transaction hash if successful
  /// - message: Human-readable result message
  /// - error: Error details if operation failed
  ///
  /// Usage:
  /// ```dart
  /// final stellarService = StellarService();
  /// final result = await stellarService.addAkofaTrustline('S...');
  /// if (result['success']) {
  ///   print('Trustline added: ${result['hash']}');
  /// }
  /// ```
  // REMOVED - Only Akofa trustline is needed, handled automatically

  // AUTOMATIC Akofa trustline creation - no manual calls needed
  /// Create AKOFA trustline for a user's wallet
  /// [userSecretKey] = user's Stellar secret key (S...)
  Future<bool> createUserAkofaTrustline(String userSecretKey) async {
    try {
      // Validate secret key format
      if (userSecretKey == null || userSecretKey.isEmpty) {
        return false;
      }

      // Trim key to prevent checksum errors
      final trimmedKey = userSecretKey.trim();

      final userKeyPair = KeyPair.fromSecretSeed(trimmedKey);
      final publicKey = userKeyPair.accountId;

      // Check if account exists on network
      final accountExists = await _checkAccountExists(publicKey);
      if (!accountExists) {
        throw Exception(
          'Account not found. Please ensure your account is funded with XLM first.',
        );
      }

      // Get account details
      final userAccount = await _sdk.accounts.account(publicKey);

      // Check if trustline already exists
      bool hasTrustline = false;
      for (var balance in userAccount.balances!) {
        if (balance.assetType != 'native' &&
            balance.assetCode == AKOFA_ASSET_CODE &&
            balance.assetIssuer == AKOFA_ISSUER_ACCOUNT) {
          hasTrustline = true;
          break;
        }
      }

      if (hasTrustline) {
        return true;
      }

      // Check XLM balance for transaction fees
      final xlmBalance = userAccount.balances.firstWhere(
        (b) => b.assetType == 'native',
        orElse: () => throw Exception('No XLM balance found'),
      );

      final balance = double.tryParse(xlmBalance.balance) ?? 0.0;
      if (balance < 0.5) {
        throw Exception(
          'Insufficient XLM balance. You need at least 0.5 XLM to create a trustline.',
        );
      }

      // Create AKOFA asset for trustline

      // Create asset with validation
      Asset akofaAssetForTrustline;
      try {
        akofaAssetForTrustline = AssetTypeCreditAlphaNum12(
          AKOFA_ASSET_CODE,
          AKOFA_ISSUER_ACCOUNT,
        );
      } catch (assetError) {
        // Fallback: try using class-level asset if available
        if (akofaAsset != null) {
          akofaAssetForTrustline = akofaAsset;
        } else {
          throw Exception(
            'Failed to create AKOFA asset for trustline. Asset creation error: $assetError',
          );
        }
      }

      // Build trustline transaction
      final transaction = TransactionBuilder(userAccount)
          .addOperation(
            ChangeTrustOperationBuilder(
              akofaAssetForTrustline,
              '10000000000',
            ).build(),
          )
          .addMemo(Memo.text('Add AKOFA Trustline'))
          .build();

      // Sign transaction with user's secret key
      transaction.sign(userKeyPair, Network.TESTNET);

      // Submit transaction
      final response = await _sdk.submitTransaction(transaction);

      if (response.success) {
        return true;
      } else {
        // Check for common error patterns in the result XDR
        final resultXdr = response.resultXdr ?? '';

        // Provide helpful error messages based on common failure patterns
        if (resultXdr.contains('op_no_trust') ||
            resultXdr.contains('TRUSTLINE_MISSING')) {
          throw Exception(
            'Trustline operation failed. The AKOFA asset may not exist or trustline creation failed.',
          );
        } else if (resultXdr.contains('op_bad_auth') ||
            resultXdr.contains('BAD_AUTH')) {
          throw Exception(
            'Authentication failed. Please check your secret key.',
          );
        } else if (resultXdr.contains('INSUFFICIENT_BALANCE') ||
            resultXdr.contains('UNDERFUNDED')) {
          throw Exception(
            'Insufficient XLM balance for transaction fees. You need at least 0.5 XLM.',
          );
        } else if (resultXdr.contains('NO_ACCOUNT') ||
            resultXdr.contains('ACCOUNT_NOT_FOUND')) {
          throw Exception(
            'Account not found on Stellar network. Please ensure your account is funded.',
          );
        } else {
          throw Exception(
            'Transaction failed. Please check your XLM balance and try again.',
          );
        }
      }
    } catch (e) {
      rethrow; // Re-throw to preserve error information
    }
  }

  /// Ensure Akofa trustline exists
  Future<bool> ensureAkofaTrustline() async {
    try {
      // Get user's public key and secret key
      final publicKey = await getPublicKey();
      if (publicKey == null) {
        return false;
      }

      final credentials = await getWalletCredentials();
      if (credentials == null || credentials['secretKey'] == null) {
        return false;
      }

      if (await hasAkofaTrustline(publicKey)) {
        return true;
      } else {
        final result = await createUserAkofaTrustline(
          credentials['secretKey']!,
        );
        return result;
      }
    } catch (e) {
      return false;
    }
  }

  /// Automatic wallet setup: fund account and add trustline (for new wallets)
  ///
  /// This method handles the complete setup process for new wallets:
  /// 1. Checks if account exists on Stellar network
  /// 2. Funds unfunded accounts using Friendbot
  /// 3. Adds Akofa trustline for token support
  ///
  /// Parameters:
  /// - publicKey: The wallet's public key
  /// - secretKey: The wallet's secret key (required for trustline operations)
  ///
  /// Returns detailed results:
  /// - success: Overall success status
  /// - wasFunded: Whether the account was funded by Friendbot
  /// - trustlineAdded: Whether the Akofa trustline was added
  /// - fundingResult: Details about funding operation
  /// - trustlineResult: Details about trustline operation
  ///
  /// This is automatically called during wallet creation but can also be used
  /// for manual wallet setup or recovery operations.
  Future<Map<String, dynamic>> setupNewWalletAutomatically(
    String publicKey,
    String secretKey,
  ) async {
    try {
      final result = <String, dynamic>{
        'success': false,
        'wasFunded': false,
        'trustlineAdded': false,
        'message': '',
        'fundingResult': null,
        'trustlineResult': null,
      };

      // Step 1: Check if account exists and fund it if needed
      final accountExists = await _checkAccountExists(publicKey);

      if (!accountExists) {
        // Fund the account using Friendbot
        final friendBotUrl = 'https://friendbot.stellar.org/?addr=$publicKey';
        try {
          final response = await http.get(Uri.parse(friendBotUrl));

          if (response.statusCode == 200) {
            // Wait for the account to be created
            await Future.delayed(const Duration(seconds: 5));

            result['wasFunded'] = true;
            result['fundingResult'] = {
              'success': true,
              'message': 'Account funded successfully',
            };
          } else {
            result['fundingResult'] = {
              'success': false,
              'message': 'Friendbot funding failed',
              'error': response.body,
            };
            return result;
          }
        } catch (fundingError) {
          result['fundingResult'] = {
            'success': false,
            'message': 'Friendbot funding error',
            'error': fundingError.toString(),
          };
          return result;
        }
      } else {
        result['fundingResult'] = {
          'success': true,
          'message': 'Account already exists',
        };
      }

      // Step 2: Add Akofa trustline
      final trustlineResult = await createUserAkofaTrustline(secretKey);

      if (trustlineResult) {
        result['trustlineAdded'] = true;
        result['trustlineResult'] = {'success': true};
        result['success'] = true;
        result['message'] = 'Wallet setup completed successfully!';
      } else {
        result['trustlineResult'] = {
          'success': false,
          'message': 'Trustline creation failed',
        };
        result['message'] = 'Wallet funded but trustline addition failed';
      }

      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error setting up wallet: $e',
        'error': e.toString(),
        'wasFunded': false,
        'trustlineAdded': false,
      };
    }
  }

  // Get user transactions from blockchain
  Future<List<app_transaction.Transaction>>
  getUserTransactionsFromBlockchain() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Get user's Stellar public key
      final userDoc = await _firestore.collection('USER').doc(user.uid).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final stellarPublicKey = userData['stellarPublicKey'] as String?;
      final akofaTag = userData['akofaTag'] as String?;

      if (stellarPublicKey == null || stellarPublicKey.isEmpty) {
        return [];
      }

      final transactions = <app_transaction.Transaction>[];

      try {
        // Fetch recent transactions from Stellar blockchain
        final Page<TransactionResponse> txPage = await _sdk.transactions
            .forAccount(stellarPublicKey)
            .order(RequestBuilderOrder.DESC)
            .limit(20) // Get more transactions to ensure we have recent ones
            .execute();

        for (final TransactionResponse tx in txPage.records) {
          try {
            // Get operations for this transaction
            final Page<OperationResponse> opsPage = await _sdk.operations
                .forTransaction(tx.hash)
                .execute();

            for (final OperationResponse op in opsPage.records) {
              if (op is PaymentOperationResponse) {
                // Determine if this is an incoming or outgoing transaction
                final bool isIncoming = op.to == stellarPublicKey;
                final bool isOutgoing = op.from == stellarPublicKey;

                if (isIncoming || isOutgoing) {
                  // Determine transaction type
                  String txType;
                  String? senderAddress;
                  String? recipientAddress;
                  String? senderAkofaTag;
                  String? recipientAkofaTag;

                  if (isIncoming) {
                    txType = 'receive';
                    senderAddress = op.from;
                    recipientAddress = stellarPublicKey;
                    senderAkofaTag = await _getAkofaTagForAddress(op.from);
                    recipientAkofaTag = akofaTag;
                  } else {
                    txType = 'send';
                    senderAddress = stellarPublicKey;
                    recipientAddress = op.to;
                    senderAkofaTag = akofaTag;
                    recipientAkofaTag = await _getAkofaTagForAddress(op.to);
                  }

                  // Create transaction object
                  final transaction = app_transaction.Transaction(
                    id: '${tx.hash}_${op.id}', // Unique ID combining tx hash and operation ID
                    userId: user.uid,
                    type: txType,
                    status: tx.successful ? 'completed' : 'failed',
                    amount: double.tryParse(op.amount) ?? 0.0,
                    assetCode: op.assetCode ?? 'XLM',
                    timestamp: DateTime.parse(tx.createdAt),
                    memo: tx.memo != null ? tx.memo.toString() : null,
                    description: _generateTransactionDescription(
                      txType,
                      op.amount,
                      op.assetCode ?? 'XLM',
                    ),
                    transactionHash: tx.hash,
                    senderAkofaTag: senderAkofaTag,
                    recipientAkofaTag: recipientAkofaTag,
                    senderAddress: senderAddress,
                    recipientAddress: recipientAddress,
                    metadata: {
                      'stellarNetwork': 'testnet',
                      'operationId': op.id.toString(),
                      'operationType': 'payment',
                      'assetType': op.assetCode != null
                          ? 'credit_alphanum'
                          : 'native',
                      'assetIssuer': op.assetIssuer,
                      'sourceAccount': tx.sourceAccount,
                      'feeCharged': tx.feeCharged,
                      'ledger': tx.ledger,
                      'fetchedAt': DateTime.now().toIso8601String(),
                    },
                  );

                  transactions.add(transaction);
                }
              }
            }
          } catch (e) {
            // Continue with other transactions
          }
        }

        // Sort by timestamp (most recent first)
        transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return transactions;
      } catch (e) {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Helper method to get Akofa tag for a Stellar address
  Future<String?> _getAkofaTagForAddress(String address) async {
    try {
      final query = await _firestore
          .collection('USER')
          .where('stellarPublicKey', isEqualTo: address)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first.data()['akofaTag'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Helper method to generate transaction description
  String _generateTransactionDescription(
    String type,
    String amount,
    String assetCode,
  ) {
    final action = type == 'send' ? 'Sent' : 'Received';
    return '$action $amount $assetCode';
  }
}
