import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_mailer/flutter_mailer.dart';
import '../models/transaction.dart' as app_transaction;
import 'transaction_service.dart';

class StellarService {
  static final StellarSDK _sdk = StellarSDK.TESTNET;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Constants
  static const String AKOFA_ASSET_CODE = 'AKOFA';
  static const String AKOFA_ISSUER_ACCOUNT = 'GDOMDAYWWHIDWWHIDDETBRW4V36UBJULCCRO3H3FYZODRHUO376KS7SDHLOPU';
  static const String ISSUER_SECRET = 'SATTJCBNQLGSA4TXFCMOWOWDXEOIRY2VGSEBQOH2HWY5RV72YN6AE6FP';

  // Get wallet credentials from secure storage
  Future<Map<String, String>?> getWalletCredentials() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No authenticated user found');
        return null;
      }

      print('🔍 Looking for wallet credentials for user: ${user.uid}');
      
      // First try to get from wallets collection
      final walletDoc = await _firestore.collection('wallets').doc(user.uid).get();
      if (walletDoc.exists) {
        final walletData = walletDoc.data()!;
        print('📋 Wallet document data keys: ${walletData.keys.toList()}');
        
        final publicKey = walletData['publicKey'];
        final secretKey = walletData['secretKey'];
        
        print('🔑 Wallet Public Key: ${publicKey != null ? 'Found' : 'Missing'}');
        print('🔑 Wallet Secret Key: ${secretKey != null ? 'Found' : 'Missing'}');
        
        if (publicKey != null && publicKey.isNotEmpty && secretKey != null && secretKey.isNotEmpty) {
          print('✅ Wallet credentials found in wallets collection');
          return {
            'publicKey': publicKey,
            'secretKey': secretKey,
          };
        }
      } else {
        print('❌ No wallet document found in wallets collection');
      }

      // Fallback: try to get from USER collection (for backward compatibility)
      print('🔍 Trying USER collection as fallback...');
      final doc = await _firestore.collection('USER').doc(user.uid).get();
      if (!doc.exists) {
        print('❌ User document does not exist');
        return null;
      }

      final data = doc.data()!;
      print('📋 User document data keys: ${data.keys.toList()}');
      
      final stellarPublicKey = data['stellarPublicKey'];
      final stellarSecretKey = data['stellarSecretKey'];
      
      print('🔑 Stellar Public Key: ${stellarPublicKey != null ? 'Found' : 'Missing'}');
      print('🔑 Stellar Secret Key: ${stellarSecretKey != null ? 'Found' : 'Missing'}');
      
      if (stellarPublicKey != null && stellarPublicKey.isNotEmpty && stellarSecretKey != null && stellarSecretKey.isNotEmpty) {
        print('✅ Wallet credentials found in USER collection');
        return {
          'publicKey': stellarPublicKey,
          'secretKey': stellarSecretKey,
        };
      }
      
      print('❌ No wallet credentials found in either collection');
      return null;
    } catch (e) {
      print('❌ Error getting wallet credentials: $e');
      return null;
    }
  }

  // Check if a Stellar account exists
  Future<bool> _checkAccountExists(String publicKey) async {
    try {
      await _sdk.accounts.account(publicKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Send XLM from user wallet
  Future<Map<String, dynamic>> sendXlm(String destinationAddress, String amount, {String? memo}) async {
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
        amount
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
        } catch (e) {
          print('Could not record receive transaction for recipient: $e');
        }

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
  Future<Map<String, dynamic>> sendAsset(String assetCode, String destinationAddress, String amount, {String? memo}) async {
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
          orElse: () => throw Exception('Asset $assetCode not found in wallet')
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
        amount
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
        } catch (e) {
          print('Could not record receive transaction for recipient: $e');
        }

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
  Future<Map<String, dynamic>> sendAssetFromIssuer(String assetCode, String destinationAddress, String amount, {String? memo}) async {
    try {
      print('🚀 sendAssetFromIssuer: Starting transaction for $amount $assetCode to $destinationAddress');
      
      // Create issuer keypair
      final issuerKeyPair = KeyPair.fromSecretSeed(ISSUER_SECRET);
      final issuerAccountId = issuerKeyPair.accountId;
      
      print('🔑 Issuer account: $issuerAccountId');
      
      // Get issuer account
      final issuerAccount = await _sdk.accounts.account(issuerAccountId);
      print('✅ Issuer account loaded successfully');
      
      // Create the asset
      Asset asset;
      if (assetCode == 'XLM') {
        asset = Asset.NATIVE;
      } else {
        asset = Asset.createNonNativeAsset(assetCode, issuerAccountId);
      }
      
      print('💰 Asset created: $assetCode (${assetCode == 'XLM' ? 'native' : 'credit_alphanum'})');
      
      // Check if destination account has trustline for this asset
      try {
        final destAccount = await _sdk.accounts.account(destinationAddress);
        final hasTrustline = destAccount.balances.any((b) => 
          b.assetCode == assetCode && b.assetType != 'native'
        );
        
        if (!hasTrustline && assetCode != 'XLM') {
          print('⚠️ Destination account does not have trustline for $assetCode');
          print('🔧 Creating trustline...');
          
          // Create trustline operation
          final trustlineOperation = ChangeTrustOperationBuilder(
            asset,
            '1000000' // Maximum amount
          );
          
          final trustlineTransaction = TransactionBuilder(destAccount);
          trustlineTransaction.addOperation(trustlineOperation.build());
          trustlineTransaction.addMemo(MemoText('Trustline for $assetCode'));
          
          // Note: This would require the destination account's secret key
          // For now, we'll assume the trustline exists or will be created
          print('⚠️ Trustline creation requires destination account secret key');
        }
      } catch (e) {
        print('⚠️ Could not check destination account trustline: $e');
      }
      
      // Create payment operation
      final paymentOperation = PaymentOperationBuilder(
        destinationAddress,
        asset,
        amount
      );
      
      print('💸 Payment operation created');
      
      // Build transaction
      final transactionBuilder = TransactionBuilder(issuerAccount);
      transactionBuilder.addOperation(paymentOperation.build());
      
      if (memo != null && memo.isNotEmpty) {
        transactionBuilder.addMemo(MemoText(memo));
        print('📝 Memo added: $memo');
      }
      
      final transaction = transactionBuilder.build();
      print('🔨 Transaction built successfully');
      
      // Sign transaction
      transaction.sign(issuerKeyPair, Network.TESTNET);
      print('✍️ Transaction signed with issuer key');
      
      // Submit transaction
      print('📡 Submitting transaction to Stellar network...');
      final response = await _sdk.submitTransaction(transaction);
      
      if (response.success) {
        print('✅ Transaction submitted successfully!');
        print('🔗 Transaction hash: ${response.hash}');
        print('📊 Response: ${response.extras}');
        
        return {
          'success': true,
          'hash': response.hash,
          'message': 'Asset sent successfully'
        };
      } else {
        print('❌ Transaction failed!');
        print('🚫 Error: ${response.extras}');
        
        return {
          'success': false,
          'message': 'Transaction failed: ${response.extras}',
          'error': response.extras?.toString()
        };
      }
    } catch (e) {
      print('❌ Error in sendAssetFromIssuer: $e');
      return {
        'success': false,
        'message': 'Error: $e',
        'error': e.toString()
      };
    }
  }

  // Record a mining reward transaction
  Future<Map<String, dynamic>> recordMiningReward(double amount) async {
    try {
      final credentials = await getWalletCredentials();
      if (credentials == null) {
        throw Exception('Failed to retrieve wallet credentials');
      }
      final publicKey = credentials['publicKey'];
      if (publicKey == null) {
        throw Exception('Public key is null');
      }

      // Get the current user's AKOFA tag from the USER collection
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final userDoc = await _firestore.collection('USER').doc(user.uid).get();
      if (!userDoc.exists) {
        throw Exception('User document not found');
      }

      final userData = userDoc.data()!;
      final akofaTag = userData['akofaTag'] as String?;
      
      if (akofaTag == null || akofaTag.isEmpty) {
        throw Exception('User AKOFA tag not found. Please ensure your AKOFA tag is set in your profile.');
      }

      print('🔍 Found user AKOFA tag: $akofaTag for public key: $publicKey');

      // Production mode - actually send the AKOFA coins from issuer to user
      final result = await sendAssetFromIssuer(
        AKOFA_ASSET_CODE,
        publicKey,
        amount.toString(),
        memo: 'Mining Reward for $akofaTag'
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
        throw Exception('Failed to send mining reward: ${result['message']}. Check that your Stellar account is funded and the issuer secret is configured correctly.');
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
        AKOFA_ASSET_CODE
      );
      
      return {'success': true, 'hash': result['hash']};
    } catch (e) {
      print('❌ Error in recordMiningReward: $e');
      
      // Try to record the failed transaction
      try {
        final userDoc = await _firestore.collection('USER').doc(_auth.currentUser!.uid).get();
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
      } catch (recordError) {
        print('Failed to record failed transaction: $recordError');
      }
      
      // Provide more helpful error messages
      String errorMessage = 'Failed to record mining reward: $e';
      if (e.toString().contains('sample issuer secret') || e.toString().contains('SAMPLE_')) {
        errorMessage = 'Mining rewards are not configured. Please replace the sample issuer secret with your actual secret key.';
      } else if (e.toString().contains('404') || e.toString().contains('not_found')) {
        errorMessage = 'Your Stellar account is not active. Please ensure it is funded with at least 1 XLM.';
      } else if (e.toString().contains('op_no_trust')) {
        errorMessage = 'AKOFA trustline not found. Please add the AKOFA asset to your wallet first.';
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
    String assetCode
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return;
      
      final String typeStr = type == app_transaction.TransactionType.send ? 'Sent' : 'Received';
      final String subject = 'AZIX Wallet - $typeStr $amount $assetCode';
      
      String body = '''
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
      print('📧 Transaction receipt email sent successfully');
    } catch (e) {
      print('❌ Failed to send transaction receipt email: $e');
    }
  }

  // Get all assets in the wallet
  Future<List<Map<String, dynamic>>> getAllWalletAssets(String publicKey) async {
    try {
      final List<Map<String, dynamic>> assets = [];
      
      // Check if account exists first
      final accountExists = await _checkAccountExists(publicKey);
      if (!accountExists) {
        print('Stellar account does not exist: $publicKey');
        print('Account needs to be funded with at least 1 XLM to activate');
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
              'Or send XLM from another Stellar account'
            ]
          }
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
        'status': 'active'
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
            'status': 'active'
          });
        }
      }
      
      return assets;
    } catch (e) {
      print('Error getting wallet assets: $e');
      // Return empty assets list with error status
      return [
        {
          'code': 'XLM',
          'issuer': 'native',
          'balance': '0',
          'name': 'Stellar Lumens',
          'type': 'native',
          'status': 'error',
          'message': 'Error loading assets: $e'
        }
      ];
    }
  }

  // Get transaction history from Stellar network
  Future<List<Map<String, dynamic>>> getStellarTransactionHistory(String publicKey) async {
    try {
      // For now, return empty list as Stellar SDK API has changed
      // This can be implemented later when the correct API is determined
      return [];
    } catch (e) {
      print('Error getting Stellar transaction history: $e');
      return [];
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
      return account.balances.any((b) => 
        b.assetCode == AKOFA_ASSET_CODE && b.assetType != 'native'
      );
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
        orElse: () => throw Exception('AKOFA trustline not found')
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
        (b) => b.assetType == 'native'
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
            'Or send XLM from another Stellar account'
          ]
        };
      }

      final balance = await getBalance(publicKey);
      final balanceValue = double.tryParse(balance) ?? 0.0;
      
      return {
        'exists': true,
        'status': balanceValue >= 0.5 ? 'active' : 'low_balance',
        'message': balanceValue >= 0.5 ? 'Account is active' : 'Account has low balance',
        'publicKey': publicKey,
        'xlmBalance': balance,
        'hasEnoughXlm': balanceValue >= 0.5,
      };
    } catch (e) {
      return {
        'exists': false,
        'status': 'error',
        'message': 'Error checking account status: $e',
        'publicKey': publicKey
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
        'walletCreatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'publicKey': publicKey,
        'secretKey': secretKey,
        'message': 'Wallet created successfully'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to create wallet: $e'
      };
    }
  }

  // Get user transactions from blockchain
  Future<List<app_transaction.Transaction>> getUserTransactionsFromBlockchain() async {
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
        print('❌ No Stellar public key found for user');
        return [];
      }

      print('🔍 Fetching transactions from Stellar blockchain for: $stellarPublicKey');

      // For now, return empty list as we need to implement proper Stellar API calls
      // This will be implemented when we have the correct Stellar SDK API
      print('⚠️ Blockchain transaction fetching not yet implemented');
      return [];
    } catch (e) {
      print('❌ Error fetching blockchain transactions: $e');
      return [];
    }
  }
}
