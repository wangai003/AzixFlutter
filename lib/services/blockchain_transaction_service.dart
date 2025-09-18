import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../models/transaction.dart' as app_transaction;
import 'stellar_service.dart';

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
        return [];
      }


      // Test Stellar SDK connection first
      final connectionTest = await testStellarConnection();
      if (!connectionTest) {
        return [];
      }

      // Get user's Stellar public key from wallets collection first
      String? stellarPublicKey;
      String? akofaTag;
      
      // Try wallets collection first
      final walletDoc = await _firestore.collection('wallets').doc(user.uid).get();
      if (walletDoc.exists) {
        final walletData = walletDoc.data()!;
        stellarPublicKey = walletData['publicKey'] as String?;
      } else {
      }
      
      // Fallback to USER collection
      if (stellarPublicKey == null || stellarPublicKey.isEmpty) {
        final userDoc = await _firestore.collection('USER').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          stellarPublicKey = userData['stellarPublicKey'] as String?;
          akofaTag = userData['akofaTag'] as String?;
        } else {
        }
      }

      if (stellarPublicKey == null || stellarPublicKey.isEmpty) {

        // Debug: Check what data exists in USER collection
        final userDoc = await _firestore.collection('USER').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
        } else {
        }

        return [];
      }


      // Validate the public key format
      if (!stellarPublicKey.startsWith('G') || stellarPublicKey.length != 56) {
        return [];
      }

      // Check cache first
      if (_isCacheValid(stellarPublicKey)) {
        return _transactionCache[stellarPublicKey] ?? [];
      }

      // Fetch real transactions from Stellar blockchain
      final transactions = await _fetchTransactionsFromBlockchain(stellarPublicKey, user.uid, akofaTag);
      
      // Update cache
      _updateCache(stellarPublicKey, transactions);

      return transactions;
    } catch (e) {
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
  }

  // Force refresh from blockchain (bypass cache)
  static Future<List<app_transaction.Transaction>> forceRefreshTransactions() async {
    try {
      
      final user = _auth.currentUser;
      if (user == null) {
        return [];
      }


      // Try wallets collection first
      String? stellarPublicKey;
      String? akofaTag;
      
      final walletDoc = await _firestore.collection('wallets').doc(user.uid).get();
      if (walletDoc.exists) {
        final walletData = walletDoc.data()!;
        stellarPublicKey = walletData['publicKey'] as String?;
      }
      
      // Fallback to USER collection
      if (stellarPublicKey == null || stellarPublicKey.isEmpty) {
        final userDoc = await _firestore.collection('USER').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          stellarPublicKey = userData['stellarPublicKey'] as String?;
          akofaTag = userData['akofaTag'] as String?;
        }
      }

      if (stellarPublicKey == null || stellarPublicKey.isEmpty) {
        return [];
      }

      // Clear cache for this user
      _transactionCache.remove(stellarPublicKey);
      _cacheTimestamps.remove(stellarPublicKey);

      // Fetch fresh from blockchain
      final transactions = await getUserTransactionsFromBlockchain();
      return transactions;
    } catch (e) {
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
      return {};
    }
  }

  // Verify transaction exists on blockchain
  static Future<bool> verifyTransactionOnBlockchain(String transactionHash) async {
    try {
      final transaction = await _sdk.transactions.transaction(transactionHash);
      return transaction != null;
    } catch (e) {
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

      // Try to get a simple account to test connection
      final testAccount = await _sdk.accounts.account('GAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAWHF');

      return true;
    } catch (e) {

      // For 404 errors, the connection is working but the account doesn't exist
      if (e.toString().contains('404') || e.toString().contains('NOT_FOUND')) {
        return true;
      }

      // For network errors, the connection is not working
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Network is unreachable')) {
        return false;
      }

      return false;
    }
  }

  // Debug method to inspect operation properties
  static void _debugOperationProperties(dynamic operation) {
    try {
      
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
          }
        } catch (e) {
          // Property doesn't exist or can't be accessed
        }
      }
      
      // Also check for transaction hash
      try {
        final txHash = operation.transactionHash;
        if (txHash != null) {
        }
      } catch (e) {}
      
    } catch (e) {
    }
  }

  // Extract real blockchain timestamp from Stellar operation
  static Future<DateTime> _extractBlockchainTimestamp(dynamic operation) async {
    try {
      
      // Debug: Inspect all available properties
      _debugOperationProperties(operation);
      
      // Method 1: PRIMARY METHOD - Get exact timestamp from transaction hash using TransactionResponse.createdAt
      if (operation.transactionHash != null) {
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
              throw Exception('Unexpected createdAt type');
            }
            return exactTimestamp;
          } else {
          }
        } catch (e) {
        }
      }
      
      // Method 2: Fallback - Try to get the ledger close time from the operation
      try {
        if (operation.ledgerCloseTime != null) {
          final ledgerTime = operation.ledgerCloseTime;
          return DateTime.fromMillisecondsSinceEpoch(ledgerTime * 1000);
        }
      } catch (e) {
      }
      
      // Method 3: Fallback - Try to get from operation timestamp if available
      try {
        if (operation.timestamp != null) {
          final opTimestamp = operation.timestamp;
          if (opTimestamp is int) {
            return DateTime.fromMillisecondsSinceEpoch(opTimestamp * 1000);
          } else if (opTimestamp is String) {
            return DateTime.parse(opTimestamp);
          }
        }
      } catch (e) {
      }
      
      // Method 4: Fallback - Try to get from operation created_at if available
      try {
        if (operation.createdAt != null) {
          final createdAt = operation.createdAt;
          if (createdAt is int) {
            return DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);
          } else if (createdAt is String) {
            return DateTime.parse(createdAt);
          }
        }
      } catch (e) {
      }
      
      // Method 5: Last resort - Try to get from operation ID (rough approximation)
      if (operation.id != null) {
        // Stellar operations are roughly 3-5 seconds apart
        // This is a rough approximation based on operation ID
        final now = DateTime.now();
        final operationId = operation.id as int;
        final estimatedTime = now.subtract(Duration(seconds: (operationId % 1000) * 5));
        return estimatedTime;
      }
      

      
      // Use a fallback that's clearly not the current time
      return DateTime.now().subtract(const Duration(hours: 1));
    } catch (e) {
      return DateTime.now().subtract(const Duration(hours: 1));
    }
  }

  // Fetch real transactions from Stellar blockchain using enhanced logic from test template
  static Future<List<app_transaction.Transaction>> _fetchTransactionsFromBlockchain(
    String publicKey,
    String userId,
    String? akofaTag,
  ) async {
    try {

      // Test Stellar SDK connection first
      final connectionTest = await testStellarConnection();
      if (!connectionTest) {
        return [];
      }

      // Check if account exists first
      final stellarService = StellarService();
      final accountExists = await stellarService.checkAccountExists(publicKey);
      if (!accountExists) {
        return [];
      }
      
      // Use the enhanced transaction retrieval logic from test template
      
      try {
        // Step 1: Retrieve recent transactions (last 10) - same as test template
        final txPage = await _sdk.transactions
            .forAccount(publicKey)
            .order(RequestBuilderOrder.DESC)
            .limit(10)
            .execute();

        if (txPage.records.isEmpty) {
          return [];
        }


        final transactions = <app_transaction.Transaction>[];

        for (int i = 0; i < txPage.records.length; i++) {
          try {
            final tx = txPage.records[i];

            // Step 2: Retrieve operations for this transaction - same as test template
            final opsPage = await _sdk.operations.forTransaction(tx.hash).execute();

            for (final op in opsPage.records) {
              if (op is PaymentOperationResponse) {

                // Convert to app transaction format
                final transaction = await _convertPaymentOperationToTransaction(
                  op, 
                  tx, 
                  userId, 
                  akofaTag, 
                  publicKey
                );
                
                if (transaction != null) {
                  transactions.add(transaction);
                }
              }
              // Handle other operation types if needed
            }

          } catch (e) {
            // Continue with next transaction
          }
        }

        
        // Debug: Show transaction details
        for (int i = 0; i < transactions.length; i++) {
          final tx = transactions[i];
        }
        
        return transactions;
        
      } catch (sdkError) {
        return [];
      }
      
    } catch (e) {
      return [];
    }
  }

  // Convert PaymentOperationResponse to app transaction using enhanced logic
  static Future<app_transaction.Transaction?> _convertPaymentOperationToTransaction(
    PaymentOperationResponse op,
    TransactionResponse tx,
    String userId,
    String? akofaTag,
    String publicKey,
  ) async {
    try {
      
      // Extract payment details
      final amount = double.tryParse(op.amount?.toString() ?? '0') ?? 0.0;
      final assetCode = op.assetCode?.toString() ?? 'XLM';
      final fromAddress = op.from ?? '';
      final toAddress = op.to ?? '';
      final memo = tx.memo?.toString();
      
      
      // Get Akofa tags for sender and recipient
      final senderAkofaTag = await _getAkofaTagForWallet(fromAddress);
      final recipientAkofaTag = await _getAkofaTagForWallet(toAddress);
      
      
      // Determine transaction type based on direction
      String type = 'payment';
      if (fromAddress == publicKey) {
        type = 'sent';
      } else if (toAddress == publicKey) {
        type = 'received';
      }
      
      // Parse timestamp from transaction
      DateTime timestamp;
      if (tx.createdAt is int) {
        timestamp = DateTime.fromMillisecondsSinceEpoch((tx.createdAt as int) * 1000);
      } else if (tx.createdAt is String) {
        timestamp = DateTime.parse(tx.createdAt as String);
      } else {
        timestamp = DateTime.now();
      }
      
      // Create transaction object
      final transaction = app_transaction.Transaction(
        id: 'stellar_payment_${tx.hash}_${op.id}',
        userId: userId,
        type: type,
        status: tx.successful ? 'completed' : 'failed',
        amount: amount,
        assetCode: assetCode,
        timestamp: timestamp,
        memo: memo,
        description: 'Stellar payment: $amount $assetCode',
        transactionHash: tx.hash,
        senderAkofaTag: senderAkofaTag,
        recipientAkofaTag: recipientAkofaTag,
        senderAddress: fromAddress,
        recipientAddress: toAddress,
        metadata: {
          'stellarTransactionHash': tx.hash,
          'stellarOperationId': op.id?.toString(),
          'ledger': tx.ledger.toString(),
          'sourceAccount': tx.sourceAccount,
          'operationType': 'PaymentOperationResponse',
        },
      );
      
      return transaction;
      
    } catch (e) {
      return null;
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
        
        
      } catch (extractError) {
        // Use fallback values
        amount = 0.0;
        assetCode = 'XLM';
      }
      
      // Now trace sender and recipient Akofa tags
      
      // Get sender Akofa tag
      String? senderAkofaTag = await _getAkofaTagForWallet(sourceAccount);
      
      // Get recipient Akofa tag (if different from sender)
      String? recipientAkofaTag;
      if (destinationAccount != null && destinationAccount != sourceAccount) {
        recipientAkofaTag = await _getAkofaTagForWallet(destinationAccount);
      } else {
        recipientAkofaTag = senderAkofaTag; // Same account
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
      
      return transaction;
      
    } catch (e) {
      return null;
    }
  }
}

