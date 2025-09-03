import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../models/transaction.dart' as app_transaction;

class BlockchainTransactionService {
  static final StellarSDK _sdk = StellarSDK.TESTNET;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for performance (in-memory)
  static final Map<String, List<app_transaction.Transaction>> _transactionCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Get user's transactions directly from Stellar blockchain
  static Future<List<app_transaction.Transaction>> getUserTransactionsFromBlockchain() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No authenticated user found');
        return [];
      }

      print('👤 User ID: ${user.uid}');

      // Get user's Stellar public key from wallets collection first
      String? stellarPublicKey;
      String? akofaTag;
      
      // Try wallets collection first
      final walletDoc = await _firestore.collection('wallets').doc(user.uid).get();
      if (walletDoc.exists) {
        final walletData = walletDoc.data()!;
        stellarPublicKey = walletData['publicKey'] as String?;
        print('✅ Found public key in wallets collection: $stellarPublicKey');
        print('📋 Wallet data keys: ${walletData.keys.toList()}');
      } else {
        print('❌ No wallet document found in wallets collection');
      }
      
      // Fallback to USER collection
      if (stellarPublicKey == null || stellarPublicKey.isEmpty) {
        print('🔍 Trying USER collection as fallback...');
        final userDoc = await _firestore.collection('USER').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          stellarPublicKey = userData['stellarPublicKey'] as String?;
          akofaTag = userData['akofaTag'] as String?;
          print('✅ Found public key in USER collection: $stellarPublicKey');
          print('📋 User data keys: ${userData.keys.toList()}');
        } else {
          print('❌ No user document found in USER collection');
        }
      }

      if (stellarPublicKey == null || stellarPublicKey.isEmpty) {
        print('❌ No Stellar public key found for user');
        return [];
      }

      print('🔍 Fetching transactions from Stellar blockchain for: $stellarPublicKey');
      print('🏷️ Akofa Tag: $akofaTag');

      // Check cache first
      if (_isCacheValid(stellarPublicKey)) {
        print('📦 Using cached transactions');
        return _transactionCache[stellarPublicKey] ?? [];
      }

      // Fetch real transactions from Stellar blockchain
      final transactions = await _fetchTransactionsFromBlockchain(stellarPublicKey, user.uid, akofaTag);
      
      // Update cache
      _updateCache(stellarPublicKey, transactions);

      print('✅ Fetched ${transactions.length} transactions from blockchain');
      return transactions;
    } catch (e) {
      print('❌ Error fetching blockchain transactions: $e');
      print('❌ Error stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Cache management
  static bool _isCacheValid(String publicKey) {
    final timestamp = _cacheTimestamps[publicKey];
    if (timestamp == null) return false;
    
    return DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  static void _updateCache(String publicKey, List<app_transaction.Transaction> transactions) {
    _transactionCache[publicKey] = transactions;
    _cacheTimestamps[publicKey] = DateTime.now();
  }

  // Clear cache (useful for testing or manual refresh)
  static void clearCache() {
    _transactionCache.clear();
    _cacheTimestamps.clear();
    print('🧹 Transaction cache cleared');
  }

  // Force refresh from blockchain (bypass cache)
  static Future<List<app_transaction.Transaction>> forceRefreshTransactions() async {
    try {
      print('🔄 Force refreshing transactions from blockchain...');
      
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No authenticated user found for force refresh');
        return [];
      }

      print('👤 Force refresh for user: ${user.uid}');

      // Try wallets collection first
      String? stellarPublicKey;
      String? akofaTag;
      
      final walletDoc = await _firestore.collection('wallets').doc(user.uid).get();
      if (walletDoc.exists) {
        final walletData = walletDoc.data()!;
        stellarPublicKey = walletData['publicKey'] as String?;
        print('✅ Found public key in wallets collection for force refresh: $stellarPublicKey');
      }
      
      // Fallback to USER collection
      if (stellarPublicKey == null || stellarPublicKey.isEmpty) {
        final userDoc = await _firestore.collection('USER').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          stellarPublicKey = userData['stellarPublicKey'] as String?;
          akofaTag = userData['akofaTag'] as String?;
          print('✅ Found public key in USER collection for force refresh: $stellarPublicKey');
        }
      }

      if (stellarPublicKey == null || stellarPublicKey.isEmpty) {
        print('❌ No Stellar public key found for force refresh');
        return [];
      }

      // Clear cache for this user
      _transactionCache.remove(stellarPublicKey);
      _cacheTimestamps.remove(stellarPublicKey);
      print('🧹 Cache cleared for: $stellarPublicKey');

      // Fetch fresh from blockchain
      final transactions = await getUserTransactionsFromBlockchain();
      print('🔄 Force refresh completed, found ${transactions.length} transactions');
      return transactions;
    } catch (e) {
      print('❌ Error forcing refresh: $e');
      print('❌ Force refresh error stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get account balance directly from blockchain
  static Future<Map<String, String>> getAccountBalancesFromBlockchain(String publicKey) async {
    try {
      final account = await _sdk.accounts.account(publicKey);
      final balances = <String, String>{};

      for (final balance in account.balances) {
        if (balance.assetType == 'native') {
          balances['XLM'] = balance.balance;
        } else {
          balances[balance.assetCode ?? 'UNKNOWN'] = balance.balance;
        }
      }

      return balances;
    } catch (e) {
      print('❌ Error getting blockchain balances: $e');
      return {};
    }
  }

  // Verify transaction exists on blockchain
  static Future<bool> verifyTransactionOnBlockchain(String transactionHash) async {
    try {
      final transaction = await _sdk.transactions.transaction(transactionHash);
      return transaction != null;
    } catch (e) {
      print('❌ Error verifying transaction: $e');
      return false;
    }
  }

  // Get transaction details from blockchain
  static Future<Map<String, dynamic>?> getTransactionDetails(String transactionHash) async {
    try {
      final transaction = await _sdk.transactions.transaction(transactionHash);
      if (transaction != null) {
        return {
          'hash': transaction.hash,
          'ledger': transaction.ledger,
          'timestamp': transaction.createdAt,
          'memo': transaction.memo?.toString(),
        };
      }
      return null;
    } catch (e) {
      print('❌ Error getting transaction details: $e');
      return null;
    }
  }



  // Get Akofa tag for a wallet address
  static Future<String?> _getAkofaTagForWallet(String? walletAddress) async {
    if (walletAddress == null || walletAddress.isEmpty) {
      return null;
    }
    
    try {
      // Step 1: Check if this is the Akofa issuing account (SYSTEM)
      if (_isAkofaIssuingAccount(walletAddress)) {
        return 'SYSTEM';
      }
      
      // Step 2: Look up in wallets collection by publicKey
      final walletQuery = await _firestore
          .collection('wallets')
          .where('publicKey', isEqualTo: walletAddress)
          .limit(1)
          .get();
      
      if (walletQuery.docs.isNotEmpty) {
        final walletData = walletQuery.docs.first.data();
        final userId = walletData['userId'] as String?;
        
        if (userId != null && userId.isNotEmpty) {
          // Step 3: Get user's Akofa tag from USER collection
          final userDoc = await _firestore.collection('USER').doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            final akofaTag = userData['akofaTag'] as String?;
            
            if (akofaTag != null && akofaTag.toString().isNotEmpty) {
              return akofaTag.toString();
            }
          }
        }
      }
      
      return null;
      
    } catch (e) {
      return null;
    }
  }
  
  // Check if wallet is the Akofa issuing account
  static bool _isAkofaIssuingAccount(String walletAddress) {
    // The actual Akofa issuing account address
    const akofaIssuingAccounts = [
      'GDOMDAYWWHIDDETBRW4V36UBJULCCRO3H3FYZODRHUO376KS7SDHLOPU',
    ];
    
    return akofaIssuingAccounts.contains(walletAddress);
  }

  // Test Stellar SDK connection
  static Future<bool> testStellarConnection() async {
    try {
      print('🧪 Testing Stellar SDK connection...');
      
      // Try to get a simple account to test connection
      final testAccount = await _sdk.accounts.account('GAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAWHF');
      print('✅ Stellar SDK connection successful (tested with dummy account)');
      
      return true;
    } catch (e) {
      if (e.toString().contains('404')) {
        print('✅ Stellar SDK connection successful (404 expected for dummy account)');
        return true;
      }
      print('❌ Stellar SDK connection failed: $e');
      return false;
    }
  }

  // Debug method to inspect operation properties
  static void _debugOperationProperties(dynamic operation) {
    try {
      print('   🔍 Operation properties for ${operation.id}:');
      print('   - Runtime type: ${operation.runtimeType}');
      
      // Try to get all possible timestamp-related properties
      final properties = [
        'ledgerCloseTime',
        'timestamp', 
        'createdAt',
        'created_at',
        'time',
        'date',
        'ledgerTime',
        'closeTime',
        'close_time'
      ];
      
      for (final prop in properties) {
        try {
          final value = operation.$prop;
          if (value != null) {
            print('   - $prop: $value (${value.runtimeType})');
          }
        } catch (e) {
          // Property doesn't exist or can't be accessed
        }
      }
      
      // Also check for transaction hash
      try {
        final txHash = operation.transactionHash;
        if (txHash != null) {
          print('   - transactionHash: $txHash');
        }
      } catch (e) {}
      
    } catch (e) {
      print('   ❌ Error debugging operation: $e');
    }
  }

  // Extract real blockchain timestamp from Stellar operation
  static Future<DateTime> _extractBlockchainTimestamp(dynamic operation) async {
    try {
      print('   🔍 Extracting timestamp for operation: ${operation.id}');
      
      // Debug: Inspect all available properties
      _debugOperationProperties(operation);
      
      // Method 1: PRIMARY METHOD - Get exact timestamp from transaction hash using TransactionResponse.createdAt
      if (operation.transactionHash != null) {
        print('   🕐 Method 1 (PRIMARY): Fetching exact timestamp from transaction hash: ${operation.transactionHash}');
        try {
          // Use the direct approach as shown in your sample code
          final transaction = await _sdk.transactions.transaction(operation.transactionHash);
          if (transaction != null && transaction.createdAt != null) {
            DateTime exactTimestamp;
            if (transaction.createdAt is int) {
              exactTimestamp = DateTime.fromMillisecondsSinceEpoch((transaction.createdAt as int) * 1000);
            } else if (transaction.createdAt is String) {
              exactTimestamp = DateTime.parse(transaction.createdAt as String);
            } else {
              print('   ⚠️ Method 1 (PRIMARY): Unexpected createdAt type: ${transaction.createdAt.runtimeType}');
              throw Exception('Unexpected createdAt type');
            }
            print('   ✅ Method 1 (PRIMARY): Got EXACT blockchain timestamp: $exactTimestamp');
            print('   📊 Transaction details: Hash=${transaction.hash}, Ledger=${transaction.ledger}');
            return exactTimestamp;
          } else {
            print('   ⚠️ Method 1 (PRIMARY): Transaction found but no createdAt timestamp');
          }
        } catch (e) {
          print('   ⚠️ Method 1 (PRIMARY): Failed to fetch transaction: $e');
        }
      }
      
      // Method 2: Fallback - Try to get the ledger close time from the operation
      try {
        if (operation.ledgerCloseTime != null) {
          final ledgerTime = operation.ledgerCloseTime;
          print('   🕐 Method 2 (FALLBACK): Using ledger close time: $ledgerTime');
          return DateTime.fromMillisecondsSinceEpoch(ledgerTime * 1000);
        }
      } catch (e) {
        print('   ⚠️ Method 2 (FALLBACK) failed: $e');
      }
      
      // Method 3: Fallback - Try to get from operation timestamp if available
      try {
        if (operation.timestamp != null) {
          final opTimestamp = operation.timestamp;
          print('   🕐 Method 3 (FALLBACK): Using operation timestamp: $opTimestamp');
          if (opTimestamp is int) {
            return DateTime.fromMillisecondsSinceEpoch(opTimestamp * 1000);
          } else if (opTimestamp is String) {
            return DateTime.parse(opTimestamp);
          }
        }
      } catch (e) {
        print('   ⚠️ Method 3 (FALLBACK) failed: $e');
      }
      
      // Method 4: Fallback - Try to get from operation created_at if available
      try {
        if (operation.createdAt != null) {
          final createdAt = operation.createdAt;
          print('   🕐 Method 4 (FALLBACK): Using operation created_at: $createdAt');
          if (createdAt is int) {
            return DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);
          } else if (createdAt is String) {
            return DateTime.parse(createdAt);
          }
        }
      } catch (e) {
        print('   ⚠️ Method 4 (FALLBACK) failed: $e');
      }
      
      // Method 5: Last resort - Try to get from operation ID (rough approximation)
      if (operation.id != null) {
        // Stellar operations are roughly 3-5 seconds apart
        // This is a rough approximation based on operation ID
        final now = DateTime.now();
        final operationId = operation.id as int;
        final estimatedTime = now.subtract(Duration(seconds: (operationId % 1000) * 5));
        print('   ⚠️ Method 5 (LAST RESORT): Using estimated time from operation ID: $estimatedTime');
        return estimatedTime;
      }
      

      
      print('   ❌ All methods failed, using fallback time');
      // Use a fallback that's clearly not the current time
      return DateTime.now().subtract(const Duration(hours: 1));
    } catch (e) {
      print('   ❌ Error extracting timestamp: $e, using fallback time');
      return DateTime.now().subtract(const Duration(hours: 1));
    }
  }

  // Fetch real transactions from Stellar blockchain
  static Future<List<app_transaction.Transaction>> _fetchTransactionsFromBlockchain(
    String publicKey,
    String userId,
    String? akofaTag,
  ) async {
    try {
      print('🔍 Fetching transactions for public key: $publicKey');
      
      // Test Stellar SDK connection first
      final connectionTest = await testStellarConnection();
      if (!connectionTest) {
        print('❌ Stellar SDK connection failed, cannot fetch transactions');
        return [];
      }
      
      // Get account operations from Stellar
      print('📡 Calling Stellar SDK operations.forAccount...');
      
      try {
        // Request more operations (Stellar SDK default is usually 10)
        final operationsResponse = await _sdk.operations.forAccount(publicKey).limit(100).execute();
        print('📡 SDK response received: ${operationsResponse.runtimeType}');
        
        final operations = operationsResponse.records;
        print('📊 Found ${operations.length} operations (requested up to 100)');
        
        if (operations.isEmpty) {
          print('⚠️ No operations found - this might mean:');
          print('   - Account is new and has no transactions');
          print('   - Network issue with Stellar SDK');
          print('   - Wrong network (testnet vs mainnet)');
          
          // Try to get account info to verify the account exists
          try {
            final account = await _sdk.accounts.account(publicKey);
            print('✅ Account exists on blockchain');
            print('   - Sequence: ${account.sequenceNumber}');
            print('   - Balances: ${account.balances.length}');
            for (final balance in account.balances) {
              print('     - ${balance.assetType}: ${balance.balance}');
            }
          } catch (accountError) {
            print('❌ Account not found or error: $accountError');
          }
          
          return [];
        }
        
        final transactions = <app_transaction.Transaction>[];
        
        for (int i = 0; i < operations.length; i++) {
          try {
            final operation = operations[i];
            print('🔍 Processing operation ${i + 1}/${operations.length}:');
            print('   - Type: ${operation.runtimeType}');
            print('   - Source: ${operation.sourceAccount}');
            print('   - Operation ID: ${operation.id}');
            
                         final transaction = await _convertOperationToTransaction(operation, userId, akofaTag, publicKey);
            if (transaction != null) {
              transactions.add(transaction);
              print('   ✅ Converted successfully');
            } else {
              print('   ❌ Conversion failed');
            }
          } catch (e) {
            print('⚠️ Error processing operation ${i + 1}: $e');
            // Continue with next operation
          }
        }
        
        print('✅ Successfully converted ${transactions.length} operations to transactions');
        
        // Debug: Show transaction details
        for (int i = 0; i < transactions.length; i++) {
          final tx = transactions[i];
          print('   📋 Transaction ${i + 1}: ${tx.type} ${tx.amount} ${tx.assetCode} at ${tx.timestamp}');
        }
        
        return transactions;
        
      } catch (sdkError) {
        print('❌ Stellar SDK error: $sdkError');
        print('❌ SDK error type: ${sdkError.runtimeType}');
        
        // Try alternative approach - get account first
        try {
          print('🔄 Trying alternative approach - get account first...');
          final account = await _sdk.accounts.account(publicKey);
          print('✅ Account found: ${account.accountId}');
          
          // Try to get transactions instead of operations
          print('🔄 Trying transactions.forAccount...');
          final transactionsResponse = await _sdk.transactions.forAccount(publicKey).execute();
          print('📡 Transactions response: ${transactionsResponse.runtimeType}');
          print('📊 Found ${transactionsResponse.records.length} transactions');
          
          // Convert transactions to our format
          final transactions = <app_transaction.Transaction>[];
          for (int i = 0; i < transactionsResponse.records.length; i++) {
            final tx = transactionsResponse.records[i];
            print('🔍 Processing transaction ${i + 1}: ${tx.hash}');
            
            final transaction = app_transaction.Transaction(
              id: 'stellar_tx_${tx.hash}',
              userId: userId,
              type: 'blockchain_transaction',
              status: 'completed',
              amount: 0.0,
              assetCode: 'XLM',
              timestamp: DateTime.now(),
              memo: tx.memo?.toString(),
              description: 'Stellar transaction: ${tx.hash}',
              transactionHash: tx.hash,
              senderAkofaTag: akofaTag,
              recipientAkofaTag: akofaTag,
              senderAddress: tx.sourceAccount,
              recipientAddress: tx.sourceAccount,
              metadata: {
                'stellarTransactionHash': tx.hash,
                'ledger': tx.ledger.toString(),
                'sourceAccount': tx.sourceAccount,
              },
            );
            
            transactions.add(transaction);
            print('   ✅ Transaction converted');
          }
          
          return transactions;
          
        } catch (alternativeError) {
          print('❌ Alternative approach also failed: $alternativeError');
          return [];
        }
      }
      
    } catch (e) {
      print('❌ Error fetching transactions from blockchain: $e');
      print('❌ Error details: ${e.toString()}');
      print('❌ Error type: ${e.runtimeType}');
      return [];
    }
  }

    // Convert Stellar operation to app transaction - NO FILTERING
  static Future<app_transaction.Transaction?> _convertOperationToTransaction(
    dynamic operation,
    String userId,
    String? akofaTag,
    String publicKey,
  ) async {
    try {
      final operationType = operation.runtimeType.toString();
      print('🔍 Converting operation: ${operation.id}');
      
      // Generate a unique ID for the transaction
      final transactionId = 'stellar_${operation.id ?? DateTime.now().millisecondsSinceEpoch}';
      
      // Extract basic transaction info - NO TYPE FILTERING
      String type = 'blockchain_operation';
      double amount = 0.0;
      String assetCode = 'XLM';
      String? memo;
      String? transactionHash;
      String? sourceAccount;
      String? destinationAccount;
      
      try {
        // Get common properties - use the correct Stellar SDK properties
        sourceAccount = operation.sourceAccount ?? operation.accountId;
        transactionHash = operation.transactionHash;
        
        print('   📋 Raw sourceAccount: $sourceAccount (type: ${sourceAccount.runtimeType})');
        print('   📋 Raw transactionHash: $transactionHash (type: ${transactionHash.runtimeType})');
        
        // For ALL operation types, just extract what we can
        if (operationType.contains('PaymentOperationResponse')) {
          amount = double.tryParse(operation.amount?.toString() ?? '0') ?? 0.0;
          
          // Determine asset code
          if (operation.assetType == 'native') {
            assetCode = 'XLM';
          } else {
            assetCode = operation.assetCode?.toString() ?? 'UNKNOWN';
          }
          
          // Use the correct property for destination account
          destinationAccount = operation.to ?? operation.destinationAccount;
          print('   📋 Raw destinationAccount (to): $destinationAccount (type: ${destinationAccount.runtimeType})');
          
          // Try to get memo safely
          try {
            memo = operation.memo?.toString();
          } catch (memoError) {
            memo = null;
          }
          
        } else if (operationType.contains('ChangeTrustOperationResponse')) {
          assetCode = operation.assetCode?.toString() ?? 'UNKNOWN';
          
        } else if (operationType.contains('CreateAccountOperationResponse')) {
          amount = double.tryParse(operation.startingBalance?.toString() ?? '0') ?? 0.0;
          assetCode = 'XLM';
        }
        
        print('   - Extracted: amount=$amount, asset=$assetCode');
        print('   - Final sourceAccount: $sourceAccount');
        print('   - Final destinationAccount: $destinationAccount');
        
      } catch (extractError) {
        print('   ⚠️ Error extracting operation details: $extractError');
        print('   ⚠️ Error stack trace: ${StackTrace.current}');
        // Use fallback values
        amount = 0.0;
        assetCode = 'XLM';
      }
      
      // Now trace sender and recipient Akofa tags
      print('   🔍 Tracing sender and recipient Akofa tags...');
      print('   📋 Source Account: $sourceAccount');
      print('   📋 Destination Account: $destinationAccount');
      
      // Get sender Akofa tag
      String? senderAkofaTag = await _getAkofaTagForWallet(sourceAccount);
      print('   - Sender ${sourceAccount}: ${senderAkofaTag ?? 'No tag found'}');
      
      // Get recipient Akofa tag (if different from sender)
      String? recipientAkofaTag;
      if (destinationAccount != null && destinationAccount != sourceAccount) {
        recipientAkofaTag = await _getAkofaTagForWallet(destinationAccount);
        print('   - Recipient ${destinationAccount}: ${recipientAkofaTag ?? 'No tag found'}');
      } else {
        recipientAkofaTag = senderAkofaTag; // Same account
        print('   - Same account, using sender tag: $senderAkofaTag');
      }
      
      // Create transaction object - NO TYPE FILTERING
      final timestamp = await _extractBlockchainTimestamp(operation);
      final transaction = app_transaction.Transaction(
        id: transactionId,
        userId: userId,
        type: type, // Always 'blockchain_operation'
        status: 'completed',
        amount: amount,
        assetCode: assetCode,
        timestamp: timestamp, // Real blockchain timestamp
        memo: memo,
        description: 'Stellar operation: $operationType',
        transactionHash: transactionHash,
        senderAkofaTag: senderAkofaTag,
        recipientAkofaTag: recipientAkofaTag,
        senderAddress: sourceAccount,
        recipientAddress: destinationAccount ?? sourceAccount,
        metadata: {
          'stellarOperationType': operationType,
          'sourceAccount': sourceAccount,
          'operationId': operation.id?.toString(),
          'pagingToken': operation.pagingToken?.toString(),
        },
      );
      
      print('✅ Converted operation to transaction: $amount $assetCode');
      print('   📋 Sender: ${senderAkofaTag ?? 'Unknown'} (${sourceAccount})');
      print('   📋 Recipient: ${recipientAkofaTag ?? 'Unknown'} (${destinationAccount ?? sourceAccount})');
      return transaction;
      
    } catch (e) {
      print('❌ Error converting operation to transaction: $e');
      return null;
    }
  }
}

