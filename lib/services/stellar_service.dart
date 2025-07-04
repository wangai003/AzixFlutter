import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:flutter_mailer/flutter_mailer.dart';
import 'package:http/http.dart' as http;
import '../models/transaction.dart' as app_transaction;
import 'swap_service.dart';
import '../secrets.dart'; // <-- Add this import for secrets

class StellarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StellarSDK _sdk = StellarSDK.TESTNET; // or StellarSDK.PUBLIC
  
  // Akofa coin asset details
  static const String AKOFA_ASSET_CODE = "AKOFA";
  static const String AKOFA_ISSUER_ACCOUNT = "GDOMDAYWWHIDDETBRW4V36UBJULCCRO3H3FYZODRHUO376KS7SDHLOPU"; // Replace with actual issuer account

  // Create and store wallet in Firestore (store secret as plain text)
  Future<Map<String, String>> createWalletAndStoreInFirestore({String? googleUid, String? password, bool useBiometrics = false}) async {
    try {
      if (kDebugMode) {
        print('Creating new wallet');
      }
      
      final KeyPair keyPair = KeyPair.random();
      final String publicKey = keyPair.accountId;
      final String secretKey = keyPair.secretSeed;
      
      if (kDebugMode) {
        print('Generated new KeyPair with public key: $publicKey');
        print('Secret key length: ${secretKey.length}');
      }
      
      final String uid = _auth.currentUser!.uid;
      if (kDebugMode) {
        print('Storing wallet for user: $uid');
      }
      
      try {
        await _firestore.collection('wallets').doc(uid).set({
          'publicKey': publicKey,
          'secretKey': secretKey, // Store as plain text
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (kDebugMode) {
          print('Wallet stored in Firestore successfully');
        }
      } catch (firestoreError) {
        if (kDebugMode) {
          print('Error storing wallet in Firestore: $firestoreError');
        }
        throw Exception('Failed to store wallet in Firestore: $firestoreError');
      }
      
      return {
        'publicKey': publicKey,
        'secretKey': secretKey,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error in createWalletAndStoreInFirestore: $e');
      }
      throw Exception('Failed to create and store wallet: $e');
    }
  }

  // Get wallet credentials from Firestore (no decryption)
  Future<Map<String, String>?> getWalletCredentials() async {
    try {
      final String uid = _auth.currentUser!.uid;
      print('Getting wallet credentials for user: $uid');
      final doc = await _firestore.collection('wallets').doc(uid).get();
      if (!doc.exists) {
        print('No wallet found for user: $uid');
        return null;
      }
      final data = doc.data()!;
      final String publicKey = data['publicKey'];
      final String secretKey = data['secretKey'];
      print('Retrieved secret from Firestore');
      return {
        'publicKey': publicKey,
        'secretKey': secretKey,
      };
    } catch (e) {
      print('Error in getWalletCredentials: $e');
      throw Exception('Failed to retrieve wallet credentials: $e');
    }
  }

  // Check if wallet exists and is valid
  Future<bool> hasWallet() async {
    final String uid = _auth.currentUser!.uid;
    final doc = await _firestore.collection('wallets').doc(uid).get();
    if (!doc.exists) return false;
    final data = doc.data();
    if (data == null) return false;
    final publicKey = data['publicKey'];
    final secretKey = data['secretKey'];
    if (publicKey == null || publicKey.toString().isEmpty) return false;
    if (secretKey == null || secretKey.toString().isEmpty) return false;
    return true;
  }

  // Get just the public key without authentication (no decryption needed)
  Future<String?> getPublicKey() async {
    try {
      final String uid = _auth.currentUser!.uid;
      if (kDebugMode) {
        print('Getting public key for user: $uid');
      }
      
      final doc = await _firestore.collection('wallets').doc(uid).get();
      if (!doc.exists) {
        if (kDebugMode) {
          print('No wallet found for user: $uid');
        }
        return null;
      }
      
      final data = doc.data()!;
      final String publicKey = data['publicKey'];
      
      if (kDebugMode) {
        print('Retrieved public key: $publicKey');
      }
      
      return publicKey;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting public key: $e');
      }
      return null;
    }
  }

  // Get balance
  Future<String> getBalance(String publicKey) async {
    try {
      final account = await _sdk.accounts.account(publicKey);
      final balance = account.balances
          .firstWhere((b) => b.assetType == 'native')
          .balance;
      return balance;
    } catch (e) {
      if (e.toString().contains('404')) {
        // Account doesn't exist on the network yet
        return "0";
      }
      throw Exception('Failed to fetch balance: $e');
    }
  }
  
  // Check if account has enough XLM for a transaction
  Future<Map<String, dynamic>> hasEnoughXlmForTransaction(String publicKey) async {
    try {
      // Minimum amount needed for transaction fees and trustline reserve
      const double minXlmNeeded = 1.5; // 0.5 XLM for transaction fee + 1 XLM for trustline reserve
      
      final String balanceStr = await getBalance(publicKey);
      final double balance = double.tryParse(balanceStr) ?? 0.0;
      
      if (balance < minXlmNeeded) {
        return {
          'hasEnough': false,
          'balance': balance,
          'needed': minXlmNeeded,
          'message': 'Account needs at least $minXlmNeeded XLM for this operation (current balance: $balance XLM)'
        };
      }
      
      return {
        'hasEnough': true,
        'balance': balance,
        'needed': minXlmNeeded,
        'message': 'Account has enough XLM for the operation'
      };
    } catch (e) {
      return {
        'hasEnough': false,
        'balance': 0.0,
        'needed': 1.5,
        'message': 'Failed to check XLM balance: ${e.toString()}'
      };
    }
  }
  
  // Check if wallet has Akofa trustline
  Future<bool> hasAkofaTrustline(String publicKey) async {
    try {
      final account = await _sdk.accounts.account(publicKey);
      
      // Check if any balance entry matches the Akofa asset
      return account.balances.any((balance) => 
        balance.assetType != 'native' && 
        balance.assetCode == AKOFA_ASSET_CODE && 
        balance.assetIssuer == AKOFA_ISSUER_ACCOUNT
      );
    } catch (e) {
      // If account doesn't exist yet on the network, it definitely doesn't have a trustline
      if (e.toString().contains('404')) {
        return false;
      }
      throw Exception('Failed to check Akofa trustline: $e');
    }
  }
  
  // Add Akofa trustline to wallet - new implementation
  Future<Map<String, dynamic>> addAkofaTrustline(String publicKey, {Map<String, String>? credentials}) async {
    try {
      if (kDebugMode) {
        print('🚀 Starting new addAkofaTrustline for public key: $publicKey');
      }

      // Step 1: Check if trustline already exists
      bool hasTrustline = false;
      try {
        hasTrustline = await hasAkofaTrustline(publicKey);
        if (hasTrustline) {
          if (kDebugMode) {
            print('✅ Trustline already exists for $publicKey');
          }
          return {
            'success': true,
            'message': 'Trustline already exists',
            'status': 'existing'
          };
        }
      } catch (checkError) {
        if (kDebugMode) {
          print('⚠️ Error checking trustline: $checkError');
        }
        // We'll continue and try to add the trustline anyway
      }

      // Step 2: Get wallet credentials if not provided
      if (credentials == null) {
        try {
          credentials = await getWalletCredentials();
        } catch (credentialsError) {
          return {
            'success': false,
            'message': 'Failed to retrieve wallet credentials',
            'error': credentialsError.toString(),
            'status': 'credential_error'
          };
        }
        if (credentials == null) {
          return {
            'success': false,
            'message': 'Failed to retrieve wallet credentials',
            'error': 'Credentials are null',
            'status': 'credential_error'
          };
        }
      }

      // Step 3: Validate secret key
      final secretKey = credentials['secretKey'];
      if (secretKey == null || secretKey.isEmpty) {
        return {
          'success': false,
          'message': 'Secret key is missing or invalid',
          'error': 'Secret key is null or empty',
          'status': 'secret_key_error'
        };
      }

      // Step 4: Create key pair and validate
      KeyPair sourceKeyPair;
      try {
        sourceKeyPair = KeyPair.fromSecretSeed(secretKey);
        if (sourceKeyPair.accountId != publicKey) {
          return {
            'success': false,
            'message': 'Key pair mismatch',
            'error': 'Generated public key does not match stored public key',
            'status': 'key_mismatch'
          };
        }
      } catch (keyPairError) {
        return {
          'success': false,
          'message': 'Failed to create key pair from secret',
          'error': keyPairError.toString(),
          'status': 'keypair_error'
        };
      }

      // Step 5: Check if account has enough XLM for the transaction
      final xlmCheck = await hasEnoughXlmForTransaction(sourceKeyPair.accountId);
      if (!xlmCheck['hasEnough']) {
        if (kDebugMode) {
          print('⚠️ Not enough XLM: ${xlmCheck['message']}');
        }
        
        // If account doesn't exist or has insufficient XLM, try to fund it with Friendbot (only on testnet)
        if (xlmCheck['balance'] < 0.1) { // Account likely doesn't exist or has almost no XLM
          if (kDebugMode) {
            print('⚠️ Account needs funding. Attempting to fund with Friendbot...');
          }
          
          try {
            final friendBotUrl = 'https://friendbot.stellar.org/?addr=${sourceKeyPair.accountId}';
            final response = await http.get(Uri.parse(friendBotUrl));
            
            if (response.statusCode == 200) {
              if (kDebugMode) {
                print('✅ Account funded by Friendbot. Waiting for account to be created...');
              }
              
              // Wait for the account to be created on the network
              await Future.delayed(const Duration(seconds: 5));
              
              // Check balance again
              final newXlmCheck = await hasEnoughXlmForTransaction(sourceKeyPair.accountId);
              if (!newXlmCheck['hasEnough']) {
                return {
                  'success': false,
                  'message': 'Account was funded but still has insufficient XLM',
                  'error': newXlmCheck['message'],
                  'status': 'insufficient_xlm_after_funding'
                };
              }
            } else {
              return {
                'success': false,
                'message': 'Failed to fund account with Friendbot',
                'error': 'Friendbot response: ${response.statusCode} - ${response.body}',
                'status': 'funding_error'
              };
            }
          } catch (fundingError) {
            return {
              'success': false,
              'message': 'Failed to fund account',
              'error': fundingError.toString(),
              'status': 'funding_request_error'
            };
          }
        } else {
          // Account exists but doesn't have enough XLM
          return {
            'success': false,
            'message': 'Insufficient XLM balance for adding trustline',
            'error': xlmCheck['message'],
            'status': 'insufficient_xlm'
          };
        }
      }
      
      // Step 6: Load source account
      AccountResponse sourceAccount;
      try {
        sourceAccount = await _sdk.accounts.account(sourceKeyPair.accountId);
      } catch (accountError) {
        return {
          'success': false,
          'message': 'Failed to load account from network',
          'error': accountError.toString(),
          'status': 'account_load_error'
        };
      }

      // Step 7: Create and submit the ChangeTrust transaction with improved reliability
      try {
        // Create the Akofa asset
        final akofaAsset = Asset.createNonNativeAsset(AKOFA_ASSET_CODE, AKOFA_ISSUER_ACCOUNT);
        
        // Create the ChangeTrust operation
        final changeTrustOp = ChangeTrustOperationBuilder(akofaAsset, "922337203685.4775807");
        
        // Add a memo to identify the transaction
        final memo = MemoText("Add Akofa Trustline");
        
        // Build the transaction with proper sequence number
        final transaction = TransactionBuilder(sourceAccount)
          ..addOperation(changeTrustOp.build())
          ..addMemo(memo); // Build with default timeout
        
        // Build the transaction
        final builtTx = transaction.build();
        
        // Sign the transaction
        builtTx.sign(sourceKeyPair, Network.TESTNET);
        
        if (kDebugMode) {
          print('🔄 Submitting transaction to add Akofa trustline...');
        }
        
        // Submit the transaction with retry logic
        SubmitTransactionResponse? txResponse;
        int retryCount = 0;
        const maxRetries = 3;
        
        while (retryCount < maxRetries) {
          try {
            txResponse = await _sdk.submitTransaction(builtTx);
            break; // If successful, exit the retry loop
          } catch (submitError) {
            retryCount++;
            if (kDebugMode) {
              print('⚠️ Transaction submission attempt $retryCount failed: $submitError');
            }
            
            if (retryCount < maxRetries) {
              // Wait before retrying with exponential backoff
              await Future.delayed(Duration(seconds: 2 * retryCount));
            } else {
              rethrow; // Re-throw the error after max retries
            }
          }
        }
        
        if (txResponse == null) {
          return {
            'success': false,
            'message': 'Failed to submit transaction after multiple attempts',
            'status': 'submission_failed'
          };
        }
        
        if (txResponse.success) {
          if (kDebugMode) {
            print('✅ Akofa trustline added successfully for $publicKey');
            print('Transaction hash: ${txResponse.hash}');
          }
          
          // Record the successful trustline addition in Firestore for reference
          try {
            final String uid = _auth.currentUser!.uid;
            await _firestore.collection('trustlines').doc(uid).set({
              'publicKey': publicKey,
              'assetCode': AKOFA_ASSET_CODE,
              'assetIssuer': AKOFA_ISSUER_ACCOUNT,
              'transactionHash': txResponse.hash,
              'createdAt': FieldValue.serverTimestamp(),
            });
          } catch (recordError) {
            // Just log the error, don't fail the operation
            if (kDebugMode) {
              print('⚠️ Failed to record trustline in Firestore: $recordError');
            }
          }
          
          return {
            'success': true,
            'message': 'Akofa trustline added successfully',
            'hash': txResponse.hash,
            'status': 'success'
          };
        } else {
          if (kDebugMode) {
            print('❌ Transaction failed: ${txResponse.extras}');
          }
          
          // Try to extract a more specific error message
          String errorDetail = 'Unknown error';
          try {
            if (txResponse.extras != null) {
              errorDetail = txResponse.extras.toString();
            }
          } catch (e) {
            // Ignore parsing errors
          }
          
          return {
            'success': false,
            'message': 'Transaction failed',
            'error': errorDetail,
            'status': 'transaction_failed'
          };
        }
      } catch (transactionError) {
        // Check for specific error types and provide better messages
        String errorStatus = 'transaction_error';
        String errorMessage = 'Failed to create or submit transaction';
        
        if (transactionError.toString().contains('op_no_trust')) {
          errorStatus = 'no_trustline';
          errorMessage = 'The trustline operation failed';
        } else if (transactionError.toString().contains('tx_bad_seq')) {
          errorStatus = 'sequence_error';
          errorMessage = 'Transaction sequence number error';
        } else if (transactionError.toString().contains('tx_fee_bump_inner_failed')) {
          errorStatus = 'fee_bump_failed';
          errorMessage = 'Fee bump transaction failed';
        }
        
        return {
          'success': false,
          'message': errorMessage,
          'error': transactionError.toString(),
          'status': errorStatus
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Unexpected error in addAkofaTrustline: $e');
      }
      
      return {
        'success': false,
        'message': 'Unexpected error occurred',
        'error': e.toString(),
        'status': 'unexpected_error'
      };
    }
  }

  
  // Get Akofa balance
  Future<String> getAkofaBalance(String publicKey) async {
    try {
      final account = await _sdk.accounts.account(publicKey);
      
      // Find the Akofa balance
      for (var balance in account.balances) {
        if (balance.assetType != 'native' && 
            balance.assetCode == AKOFA_ASSET_CODE && 
            balance.assetIssuer == AKOFA_ISSUER_ACCOUNT) {
          return balance.balance;
        }
      }
      
      return "0"; // No Akofa balance found
    } catch (e) {
      return "0"; // Return 0 if account doesn't exist or has no Akofa balance
    }
  }

  // Send Akofa coins to another address
  Future<Map<String, dynamic>> sendAkofa(String destinationAddress, String amount, {String? memo}) async {
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
      
      // Load account details
      final sourceAccount = await _sdk.accounts.account(sourceAccountId);
      
      // Create the payment operation
      final paymentOperation = PaymentOperationBuilder(
        destinationAddress,
        Asset.createNonNativeAsset(AKOFA_ASSET_CODE, AKOFA_ISSUER_ACCOUNT),
        amount
      );
      
      // Create the transaction builder
      final transactionBuilder = TransactionBuilder(sourceAccount);
      
      // Add the payment operation
      transactionBuilder.addOperation(paymentOperation.build());
      
      // Add memo if provided
      if (memo != null && memo.isNotEmpty) {
        transactionBuilder.addMemo(MemoText(memo));
      }
      
      // Build and sign the transaction
      final transaction = transactionBuilder.build();
      transaction.sign(sourceKeyPair, Network.TESTNET);
      
      // Submit the transaction
      final response = await _sdk.submitTransaction(transaction);
      
      if (response.success) {
        // Create a transaction record in Firestore
        final transactionRecord = await _recordTransaction(
          sourceAccountId,
          destinationAddress,
          double.parse(amount),
          app_transaction.TransactionType.send,
          app_transaction.TransactionStatus.completed,
          response.hash,
          memo,
          AKOFA_ASSET_CODE
        );
        
        // Send email receipt
        await _sendTransactionReceipt(
          sourceAccountId,
          destinationAddress,
          double.parse(amount),
          app_transaction.TransactionType.send,
          response.hash,
          memo,
          AKOFA_ASSET_CODE
        );
        
        return {
          'success': true,
          'hash': response.hash,
          'transactionId': transactionRecord.id
        };
      } else {
        // Record failed transaction
        await _recordTransaction(
          sourceAccountId,
          destinationAddress,
          double.parse(amount),
          app_transaction.TransactionType.send,
          app_transaction.TransactionStatus.failed,
          null,
          memo,
          AKOFA_ASSET_CODE
        );
        
        throw Exception('Transaction failed: ${response.extras}');
      }
    } catch (e) {
      throw Exception('Failed to send Akofa: $e');
    }
  }
  
  // Send XLM to another address
  Future<Map<String, dynamic>> sendXlm(String destinationAddress, String amount, {String? memo}) async {
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
      
      // Load account details
      final sourceAccount = await _sdk.accounts.account(sourceAccountId);
      
      // Create the payment operation with native XLM asset
      final paymentOperation = PaymentOperationBuilder(
        destinationAddress,
        Asset.NATIVE, // XLM is the native asset
        amount
      );
      
      // Create the transaction builder
      final transactionBuilder = TransactionBuilder(sourceAccount);
      
      // Add the payment operation
      transactionBuilder.addOperation(paymentOperation.build());
      
      // Add memo if provided
      if (memo != null && memo.isNotEmpty) {
        transactionBuilder.addMemo(MemoText(memo));
      }
      
      // Build and sign the transaction
      final transaction = transactionBuilder.build();
      transaction.sign(sourceKeyPair, Network.TESTNET);
      
      // Submit the transaction
      final response = await _sdk.submitTransaction(transaction);
      
      if (response.success) {
        // Create a transaction record in Firestore
        final transactionRecord = await _recordTransaction(
          sourceAccountId,
          destinationAddress,
          double.parse(amount),
          app_transaction.TransactionType.send,
          app_transaction.TransactionStatus.completed,
          response.hash,
          memo,
          "XLM" // XLM asset code
        );
        
        // Send email receipt
        await _sendTransactionReceipt(
          sourceAccountId,
          destinationAddress,
          double.parse(amount),
          app_transaction.TransactionType.send,
          response.hash,
          memo,
          "XLM" // XLM asset code
        );
        
        return {
          'success': true,
          'hash': response.hash,
          'transactionId': transactionRecord.id
        };
      } else {
        // Record failed transaction
        await _recordTransaction(
          sourceAccountId,
          destinationAddress,
          double.parse(amount),
          app_transaction.TransactionType.send,
          app_transaction.TransactionStatus.failed,
          null,
          memo,
          "XLM" // XLM asset code
        );
        
        throw Exception('Transaction failed: ${response.extras}');
      }
    } catch (e) {
      throw Exception('Failed to send XLM: $e');
    }
  }
  
  // Record a transaction in Firestore
  Future<DocumentReference> _recordTransaction(
    String senderAddress,
    String recipientAddress,
    double amount,
    app_transaction.TransactionType type,
    app_transaction.TransactionStatus status,
    String? hash,
    String? memo,
    String assetCode
  ) async {
    final String uid = _auth.currentUser!.uid;
    
    return await _firestore.collection('transactions').add({
      'userId': uid,
      'senderAddress': senderAddress,
      'recipientAddress': recipientAddress,
      'amount': amount,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'hash': hash,
      'timestamp': FieldValue.serverTimestamp(),
      'memo': memo,
      'assetCode': assetCode,
    });
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
    } catch (e) {
      print('Failed to send email receipt: $e');
      // Don't throw an exception here, as this is a non-critical operation
    }
  }
  
  // Get user's transaction history
  Future<List<app_transaction.Transaction>> getTransactionHistory() async {
    try {
      final String uid = _auth.currentUser!.uid;
      // Get the user's wallet public key
      final credentials = await getWalletCredentials();
      if (credentials == null) {
        throw Exception('Failed to retrieve wallet credentials');
      }
      final publicKey = credentials['publicKey'];
      // Query transactions where the user is either sender or recipient
      final querySnapshot = await _firestore.collection('transactions')
        .where(Filter.or(
          Filter('senderAddress', isEqualTo: publicKey),
          Filter('recipientAddress', isEqualTo: publicKey),
        ))
        .orderBy('timestamp', descending: true)
        .get();
      return querySnapshot.docs
        .map((doc) => app_transaction.Transaction.fromFirestore(doc))
        .toList();
    } catch (e) {
      throw Exception('Failed to get transaction history: $e');
    }
  }
  
  // Record a mining reward transaction
  Future<DocumentReference> recordMiningReward(double amount) async {
    try {
      final credentials = await getWalletCredentials();
      if (credentials == null) {
        throw Exception('Failed to retrieve wallet credentials');
      }
      
      final publicKey = credentials['publicKey'];
      if (publicKey == null) {
        throw Exception('Public key is null');
      }
      
      return await _recordTransaction(
        AKOFA_ISSUER_ACCOUNT, // Sender is the issuer account
        publicKey,
        amount,
        app_transaction.TransactionType.mining,
        app_transaction.TransactionStatus.completed,
        null, // No hash for mining rewards
        'Mining Reward',
        AKOFA_ASSET_CODE
      );
    } catch (e) {
      throw Exception('Failed to record mining reward: $e');
    }
  }

  // Get all assets in the wallet
  Future<List<Map<String, dynamic>>> getAllWalletAssets(String publicKey) async {
    try {
      final List<Map<String, dynamic>> assets = [];
      
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
        'type': 'native'
      });
      
      // Add non-native assets
      for (var balance in account.balances) {
        if (balance.assetType != 'native') {
          assets.add({
            'code': balance.assetCode,
            'issuer': balance.assetIssuer,
            'balance': balance.balance,
            'name': balance.assetCode,
            'type': 'credit_alphanum'
          });
        }
      }
      
      return assets;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting wallet assets: $e');
      }
      return []; // Return empty list on error
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
      if (assetCode == 'XLM') {
        asset = Asset.NATIVE;
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
        asset = Asset.createNonNativeAsset(assetCode, assetBalance.assetIssuer!);
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
        await _recordTransaction(
          sourceAccountId,
          destinationAddress,
          double.parse(amount),
          app_transaction.TransactionType.send,
          app_transaction.TransactionStatus.completed,
          response.hash,
          memo,
          assetCode
        );
        return {'success': true, 'hash': response.hash};
      } else {
        await _recordTransaction(
          sourceAccountId,
          destinationAddress,
          double.parse(amount),
          app_transaction.TransactionType.send,
          app_transaction.TransactionStatus.failed,
          null,
          memo,
          assetCode
        );
        throw Exception('Transaction failed: ${response.extras}');
      }
    } catch (e) {
      throw Exception('Failed to send $assetCode: $e');
    }
  }
  
  // Send any supported non-native asset from issuer to user (for admin/issuer use)
  Future<Map<String, dynamic>> sendAssetFromIssuer(String assetCode, String destinationAddress, String amount, {String? memo}) async {
    try {
      // Get issuer account details for the asset
      final assetInfo = SwapService.supportedAssets[assetCode];
      if (assetInfo == null) throw Exception('Unsupported asset');
      // WARNING: This is for testnet/demo only! Never store secrets in production apps.
      final issuerSecret = assetIssuerSecrets[assetCode];
      if (issuerSecret == null) throw Exception('No issuer secret for $assetCode');
      final issuerKeyPair = KeyPair.fromSecretSeed(issuerSecret);
      final issuerAccountId = issuerKeyPair.accountId;
      final issuerAccount = await _sdk.accounts.account(issuerAccountId);
      final asset = Asset.createNonNativeAsset(assetInfo['code']!, assetInfo['issuer']!);
      final paymentOperation = PaymentOperationBuilder(
        destinationAddress,
        asset,
        amount
      );
      final transactionBuilder = TransactionBuilder(issuerAccount);
      transactionBuilder.addOperation(paymentOperation.build());
      if (memo != null && memo.isNotEmpty) {
        transactionBuilder.addMemo(MemoText(memo));
      }
      final transaction = transactionBuilder.build();
      transaction.sign(issuerKeyPair, Network.TESTNET);
      final response = await _sdk.submitTransaction(transaction);
      if (response.success) {
        // Record transaction in Firestore
        await _recordTransaction(
          issuerAccountId,
          destinationAddress,
          double.parse(amount),
          app_transaction.TransactionType.send,
          app_transaction.TransactionStatus.completed,
          response.hash,
          memo,
          assetCode
        );
        return {'success': true, 'hash': response.hash};
      } else {
        await _recordTransaction(
          issuerAccountId,
          destinationAddress,
          double.parse(amount),
          app_transaction.TransactionType.send,
          app_transaction.TransactionStatus.failed,
          null,
          memo,
          assetCode
        );
        throw Exception('Transaction failed: ${response.extras}');
      }
    } catch (e) {
      throw Exception('Failed to send $assetCode: $e');
    }
  }

  // Delete the current user's wallet document from Firestore
  Future<void> deleteWallet() async {
    final String uid = _auth.currentUser!.uid;
    await _firestore.collection('wallets').doc(uid).delete();
  }

  // Recover wallet using provided secret key
  Future<bool> recoverWalletWithSecretKey(String secretKey) async {
    final String uid = _auth.currentUser!.uid;
    final KeyPair keyPair = KeyPair.fromSecretSeed(secretKey);
    await _firestore.collection('wallets').doc(uid).set({
      'publicKey': keyPair.accountId,
      'secretKey': secretKey,
      'updatedAt': FieldValue.serverTimestamp(),
      'recoveredAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return true;
  }
}
