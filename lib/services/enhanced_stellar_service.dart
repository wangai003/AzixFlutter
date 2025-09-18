import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/transaction.dart' as app_transaction;
import '../models/asset_config.dart';
import 'transaction_service.dart';

class EnhancedStellarService {
  static final StellarSDK _sdk = StellarSDK.TESTNET;
  static final firestore.FirebaseFirestore _firestore =
      firestore.FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Real-time monitoring
  Timer? _transactionMonitorTimer;
  Timer? _balanceMonitorTimer;
  StreamSubscription? _authStateSubscription;

  // Callbacks for real-time updates
  Function(List<app_transaction.Transaction>)? _onTransactionsUpdated;
  Function(Map<String, dynamic>)? _onBalanceUpdated;
  Function(String)? _onNewTransaction;

  // Cache for performance
  List<app_transaction.Transaction> _cachedTransactions = [];
  Map<String, dynamic> _cachedBalances = {};
  DateTime? _lastTransactionFetch;
  DateTime? _lastBalanceFetch;

  // Configuration
  static const Duration _transactionPollInterval = Duration(seconds: 30);
  static const Duration _balancePollInterval = Duration(seconds: 10);
  static const int _maxCachedTransactions = 100;

  // AKOFA Asset configuration
  final String issuerPublic =
      'GBJGVMBWKGSMPZ4D7QDTW7VPCJUWCJ26OIHFJNRIWVR362NNUU3YCOTQ';
  final String distributionSecret =
      'SCB3ICTKZ3FQX6R6JRBV2427JVPGN7IELDUWQOKDFGT5BGKQKWBURPIR';
  static const String AKOFA_ASSET_CODE = 'AKOFA';
  static const String AKOFA_ISSUER_ACCOUNT =
      'GBJGVMBWKGSMPZ4D7QDTW7VPCJUWCJ26OIHFJNRIWVR362NNUU3YCOTQ';
  static const String ISSUER_SECRET =
      'SCB3ICTKZ3FQX6R6JRBV2427JVPGN7IELDUWQOKDFGT5BGKQKWBURPIR';

  final Asset akofaAsset;

  EnhancedStellarService()
    : akofaAsset = AssetTypeCreditAlphaNum12(
        AKOFA_ASSET_CODE,
        AKOFA_ISSUER_ACCOUNT,
      ) {
    _initialize();
  }

  void _initialize() {
    // Listen to auth state changes
    _authStateSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) {
        startRealTimeMonitoring();
      } else {
        stopRealTimeMonitoring();
      }
    });

    // Start monitoring if user is already authenticated
    if (_auth.currentUser != null) {
      startRealTimeMonitoring();
    }
  }

  // ==================== REAL-TIME MONITORING ====================

  /// Start real-time monitoring of transactions and balances
  void startRealTimeMonitoring() {
    // Stop existing timers
    stopRealTimeMonitoring();

    // Start transaction monitoring
    _transactionMonitorTimer = Timer.periodic(_transactionPollInterval, (_) {
      _monitorTransactions();
    });

    // Start balance monitoring
    _balanceMonitorTimer = Timer.periodic(_balancePollInterval, (_) {
      _monitorBalances();
    });
  }

  /// Stop real-time monitoring
  void stopRealTimeMonitoring() {
    _transactionMonitorTimer?.cancel();
    _balanceMonitorTimer?.cancel();
    _transactionMonitorTimer = null;
    _balanceMonitorTimer = null;
  }

  /// Set callback for transaction updates
  void setTransactionCallback(
    Function(List<app_transaction.Transaction>) callback,
  ) {
    _onTransactionsUpdated = callback;
  }

  /// Set callback for balance updates
  void setBalanceCallback(Function(Map<String, dynamic>) callback) {
    _onBalanceUpdated = callback;
  }

  /// Set callback for new transactions
  void setNewTransactionCallback(Function(String) callback) {
    _onNewTransaction = callback;
  }

  // ==================== TRANSACTION MONITORING ====================

  /// Monitor transactions for changes
  Future<void> _monitorTransactions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final publicKey = await getPublicKey();
      if (publicKey == null) return;

      // Check if we need to fetch new transactions
      final now = DateTime.now();
      if (_lastTransactionFetch != null &&
          now.difference(_lastTransactionFetch!) < _transactionPollInterval) {
        return;
      }

      final newTransactions = await getUserTransactionsFromBlockchain();

      // Check for new transactions
      final existingHashes = _cachedTransactions
          .map((t) => t.transactionHash)
          .toSet();
      final newTxs = newTransactions
          .where(
            (tx) =>
                tx.transactionHash != null &&
                !existingHashes.contains(tx.transactionHash),
          )
          .toList();

      if (newTxs.isNotEmpty) {
        // Add new transactions to cache
        _cachedTransactions.insertAll(0, newTxs);

        // Keep only the most recent transactions
        if (_cachedTransactions.length > _maxCachedTransactions) {
          _cachedTransactions = _cachedTransactions.sublist(
            0,
            _maxCachedTransactions,
          );
        }

        // Notify listeners
        _onTransactionsUpdated?.call(_cachedTransactions);

        // Notify about new transactions
        for (final tx in newTxs) {
          _onNewTransaction?.call(
            'New ${tx.type} transaction: ${tx.amount} ${tx.assetCode}',
          );
        }
      } else if (_cachedTransactions.isEmpty && newTransactions.isNotEmpty) {
        // First time loading transactions
        _cachedTransactions = newTransactions;
        _onTransactionsUpdated?.call(_cachedTransactions);
      }

      _lastTransactionFetch = now;
    } catch (e) {}
  }

  /// Monitor balance changes
  Future<void> _monitorBalances() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final publicKey = await getPublicKey();
      if (publicKey == null) return;

      // Check if we need to fetch new balances
      final now = DateTime.now();
      if (_lastBalanceFetch != null &&
          now.difference(_lastBalanceFetch!) < _balancePollInterval) {
        return;
      }

      final balances = await getWalletBalances(publicKey);
      final hasChanges = !_mapEquals(balances, _cachedBalances);

      if (hasChanges) {
        _cachedBalances = balances;
        _onBalanceUpdated?.call(balances);
      }

      _lastBalanceFetch = now;
    } catch (e) {}
  }

  // ==================== ENHANCED TRANSACTION FETCHING ====================

  /// Get user transactions from blockchain with enhanced caching
  Future<List<app_transaction.Transaction>> getUserTransactionsFromBlockchain({
    bool forceRefresh = false,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Return cached transactions if available and not forcing refresh
      if (!forceRefresh && _cachedTransactions.isNotEmpty) {
        final now = DateTime.now();
        if (_lastTransactionFetch != null &&
            now.difference(_lastTransactionFetch!) < _transactionPollInterval) {
          return _cachedTransactions;
        }
      }

      // Get user's Stellar public key
      final userDoc = await _firestore.collection('USER').doc(user.uid).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final stellarPublicKey = userData['stellarPublicKey'] as String?;
      final akofaTag = userData['akofaTag'] as String?;

      if (stellarPublicKey == null || stellarPublicKey.isEmpty) {
        return [];
      }

      print(
        '🔍 Fetching transactions from Stellar blockchain for: $stellarPublicKey',
      );

      final transactions = <app_transaction.Transaction>[];

      try {
        // Step 1: Retrieve recent transactions (last 10)
        final Page<TransactionResponse> txPage = await _sdk.transactions
            .forAccount(stellarPublicKey)
            .order(RequestBuilderOrder.DESC)
            .limit(10)
            .execute();

        if (txPage.records.isEmpty) {
          return transactions;
        }

        for (final TransactionResponse tx in txPage.records) {
          try {
            // Step 3: Retrieve operations for this transaction
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
                    id: '${tx.hash}_${op.id}',
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
                      'cached': false,
                    },
                  );

                  transactions.add(transaction);
                }
              } else if (op is CreateAccountOperationResponse) {
                // Handle account creation transactions
                final bool isRecipient = op.account == stellarPublicKey;

                if (isRecipient) {
                  // This account was created/received funds
                  final transaction = app_transaction.Transaction(
                    id: '${tx.hash}_${op.id}',
                    userId: user.uid,
                    type: 'receive',
                    status: tx.successful ? 'completed' : 'failed',
                    amount: double.tryParse(op.startingBalance) ?? 0.0,
                    assetCode: 'XLM',
                    timestamp: DateTime.parse(tx.createdAt),
                    memo: tx.memo != null ? tx.memo.toString() : null,
                    description:
                        'Account created with ${op.startingBalance} XLM',
                    transactionHash: tx.hash,
                    senderAkofaTag: await _getAkofaTagForAddress(op.funder),
                    recipientAkofaTag: akofaTag,
                    senderAddress: op.funder,
                    recipientAddress: stellarPublicKey,
                    metadata: {
                      'stellarNetwork': 'testnet',
                      'operationId': op.id.toString(),
                      'operationType': 'create_account',
                      'assetType': 'native',
                      'funder': op.funder,
                      'sourceAccount': tx.sourceAccount,
                      'feeCharged': tx.feeCharged,
                      'ledger': tx.ledger,
                      'fetchedAt': DateTime.now().toIso8601String(),
                      'cached': false,
                    },
                  );

                  transactions.add(transaction);
                }
              }
              // You can handle other operation types here if needed
            }
          } catch (e) {
            // Continue with other transactions
          }
        }

        // Sort by timestamp (most recent first)
        transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        // Update cache
        _cachedTransactions = transactions;
        _lastTransactionFetch = DateTime.now();

        print(
          '✅ Successfully processed ${transactions.length} transactions from blockchain',
        );
        return transactions;
      } catch (e) {
        // Return cached transactions if available
        return _cachedTransactions;
      }
    } catch (e) {
      return _cachedTransactions;
    }
  }

  // ==================== ENHANCED BALANCE MANAGEMENT ====================

  /// Get wallet balances with caching
  Future<Map<String, dynamic>> getWalletBalances(String publicKey) async {
    try {
      final account = await _sdk.accounts.account(publicKey);

      final balances = <String, dynamic>{
        'xlm': '0',
        'akofa': '0',
        'lastUpdated': DateTime.now().toIso8601String(),
        'assets': <Map<String, dynamic>>[],
        'assetConfigs': <String, AssetConfig>{},
      };

      // Process all balances
      for (var balance in account.balances!) {
        if (balance.assetType == 'native') {
          // Store with both legacy key and correct assetId key
          balances['xlm'] = balance.balance;
          balances['XLM'] = balance.balance; // Correct assetId key
          balances['assetConfigs']['XLM'] = AssetConfigs.xlm;
        } else if (balance.assetCode == AKOFA_ASSET_CODE &&
            balance.assetIssuer == AKOFA_ISSUER_ACCOUNT) {
          // Store with both legacy key and correct assetId key
          balances['akofa'] = balance.balance;
          balances['AKOFA_GBJGVMBWKGSMPZ4D7QDTW7VPCJUWCJ26OIHFJNRIWVR362NNUU3YCOTQ'] =
              balance.balance; // Correct assetId key
          balances['assetConfigs']['AKOFA'] = AssetConfigs.akofa;
        }

        // Try to find known asset config and store balance with assetId key
        if (balance.assetCode != null && balance.assetIssuer != null) {
          final assetConfig = AssetConfigs.findAsset(
            balance.assetCode!,
            balance.assetIssuer!,
          );
          if (assetConfig != null) {
            // Store balance with assetId as key for easy lookup
            balances[assetConfig.assetId] = balance.balance;
            balances['assetConfigs'][assetConfig.assetId] = assetConfig;
          }
        }

        // Add to assets list
        balances['assets'].add({
          'code': balance.assetCode ?? 'XLM',
          'issuer': balance.assetIssuer ?? 'native',
          'balance': balance.balance,
          'type': balance.assetType,
          'assetId': balance.assetCode != null && balance.assetIssuer != null
              ? '${balance.assetCode}_${balance.assetIssuer}'
              : 'XLM',
        });
      }

      return balances;
    } catch (e) {
      return _cachedBalances;
    }
  }

  // ==================== ENHANCED AKOFA OPERATIONS ====================

  /// Send AKOFA tokens with enhanced error handling
  Future<Map<String, dynamic>> sendAkofaTokens({
    required String recipientAddress,
    required double amount,
    String? memo,
  }) async {
    try {
      final credentials = await getWalletCredentials();
      if (credentials == null) {
        throw Exception('Wallet credentials not found');
      }

      final secretKey = credentials['secretKey'];
      if (secretKey == null) {
        throw Exception('Secret key not available');
      }

      final sourceKeyPair = KeyPair.fromSecretSeed(secretKey);
      final sourceAccountId = sourceKeyPair.accountId;
      final sourceAccount = await _sdk.accounts.account(sourceAccountId);

      // Check if recipient has AKOFA trustline
      await _ensureRecipientTrustline(recipientAddress);

      // Create payment operation
      final paymentOperation = PaymentOperationBuilder(
        recipientAddress,
        akofaAsset,
        amount.toStringAsFixed(7), // AKOFA has 7 decimal places
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
        // Record transaction
        await TransactionService.recordSend(
          amount: amount,
          assetCode: AKOFA_ASSET_CODE,
          recipientAddress: recipientAddress,
          recipientAkofaTag: await _getAkofaTagForAddress(recipientAddress),
          memo: memo,
          stellarHash: response.hash,
          additionalMetadata: {
            'stellarNetwork': 'testnet',
            'assetType': 'credit_alphanum',
            'assetIssuer': AKOFA_ISSUER_ACCOUNT,
          },
        );

        // Notify recipient if they're a registered user
        await _notifyRecipientOfIncomingTransaction(
          recipientAddress,
          amount,
          response.hash,
        );

        return {
          'success': true,
          'hash': response.hash,
          'message': 'AKOFA tokens sent successfully',
        };
      } else {
        throw Exception('Transaction failed: ${response.extras}');
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Send XLM with enhanced error handling
  Future<Map<String, dynamic>> sendXlm(
    String recipientAddress,
    String amount, {
    String? memo,
  }) async {
    try {
      final credentials = await getWalletCredentials();
      if (credentials == null) {
        throw Exception('Wallet credentials not found');
      }

      final secretKey = credentials['secretKey'];
      if (secretKey == null) {
        throw Exception('Secret key not available');
      }

      final sourceKeyPair = KeyPair.fromSecretSeed(secretKey);
      final sourceAccountId = sourceKeyPair.accountId;
      final sourceAccount = await _sdk.accounts.account(sourceAccountId);

      // Create payment operation for native XLM
      final paymentOperation = PaymentOperationBuilder(
        recipientAddress,
        AssetTypeNative(),
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
        // Record transaction
        await TransactionService.recordSend(
          amount: double.tryParse(amount) ?? 0.0,
          assetCode: 'XLM',
          recipientAddress: recipientAddress,
          recipientAkofaTag: await _getAkofaTagForAddress(recipientAddress),
          memo: memo,
          stellarHash: response.hash,
          additionalMetadata: {
            'stellarNetwork': 'testnet',
            'assetType': 'native',
          },
        );

        // Notify recipient if they're a registered user
        await _notifyRecipientOfIncomingTransaction(
          recipientAddress,
          double.tryParse(amount) ?? 0.0,
          response.hash,
        );

        return {
          'success': true,
          'hash': response.hash,
          'message': 'XLM sent successfully',
        };
      } else {
        throw Exception('Transaction failed: ${response.extras}');
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Send asset from issuer account (used for distributing AKOFA tokens)
  Future<Map<String, dynamic>> sendAssetFromIssuer(
    String assetCode,
    String recipientAddress,
    String amount, {
    String? memo,
  }) async {
    try {
      // Use issuer's secret key
      final issuerKeyPair = KeyPair.fromSecretSeed(ISSUER_SECRET);
      final issuerAccountId = issuerKeyPair.accountId;
      final issuerAccount = await _sdk.accounts.account(issuerAccountId);

      // Determine asset type
      Asset asset;
      if (assetCode == 'XLM') {
        asset = AssetTypeNative();
      } else if (assetCode == AKOFA_ASSET_CODE) {
        asset = akofaAsset;
      } else {
        throw Exception('Unsupported asset: $assetCode');
      }

      // Ensure recipient has trustline for non-native assets
      if (assetCode != 'XLM') {
        await _ensureRecipientTrustline(recipientAddress);
      }

      // Create payment operation
      final paymentOperation = PaymentOperationBuilder(
        recipientAddress,
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
      transaction.sign(issuerKeyPair, Network.TESTNET);

      final response = await _sdk.submitTransaction(transaction);

      if (response.success) {
        // Record transaction as a receive for the recipient
        await TransactionService.recordReceive(
          amount: double.tryParse(amount) ?? 0.0,
          assetCode: assetCode,
          senderAddress: issuerAccountId,
          senderAkofaTag: 'Issuer',
          memo: memo,
          stellarHash: response.hash,
          additionalMetadata: {
            'stellarNetwork': 'testnet',
            'assetType': assetCode == 'XLM' ? 'native' : 'credit_alphanum',
            'assetIssuer': assetCode == 'XLM' ? null : AKOFA_ISSUER_ACCOUNT,
            'fromIssuer': true,
          },
        );

        // Notify recipient if they're a registered user
        await _notifyRecipientOfIncomingTransaction(
          recipientAddress,
          double.tryParse(amount) ?? 0.0,
          response.hash,
        );

        return {
          'success': true,
          'hash': response.hash,
          'message': '$assetCode sent successfully from issuer',
        };
      } else {
        throw Exception('Transaction failed: ${response.extras}');
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Receive AKOFA tokens (monitor for incoming transactions)
  Future<void> monitorIncomingAkofa() async {
    // This is handled by the real-time monitoring system
    // The _monitorTransactions method will detect new incoming transactions
  }

  /// Ensure recipient has AKOFA trustline
  Future<void> _ensureRecipientTrustline(String recipientAddress) async {
    try {
      final recipientAccount = await _sdk.accounts.account(recipientAddress);
      final hasTrustline = recipientAccount.balances!.any(
        (b) =>
            b.assetCode == AKOFA_ASSET_CODE &&
            b.assetIssuer == AKOFA_ISSUER_ACCOUNT,
      );

      if (!hasTrustline) {
        print(
          '⚠️ Recipient does not have AKOFA trustline, but proceeding with transaction',
        );
        // Note: In production, you might want to create the trustline or notify the user
      }
    } catch (e) {}
  }

  // ==================== UTILITY METHODS ====================

  /// Get wallet credentials from secure storage
  Future<Map<String, String>?> getWalletCredentials() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // Try wallets collection first
      final walletDoc = await _firestore
          .collection('wallets')
          .doc(user.uid)
          .get();
      if (walletDoc.exists) {
        final walletData = walletDoc.data()!;
        final publicKey = walletData['publicKey'];
        final secretKey = walletData['secretKey'];

        if (publicKey != null && secretKey != null) {
          return {'publicKey': publicKey, 'secretKey': secretKey};
        }
      }

      // Fallback to USER collection
      final userDoc = await _firestore.collection('USER').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final stellarPublicKey = userData['stellarPublicKey'];
        final stellarSecretKey = userData['stellarSecretKey'];

        if (stellarPublicKey != null && stellarSecretKey != null) {
          return {'publicKey': stellarPublicKey, 'secretKey': stellarSecretKey};
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get public key
  Future<String?> getPublicKey() async {
    final credentials = await getWalletCredentials();
    return credentials?['publicKey'];
  }

  /// Check if user has a wallet
  Future<bool> hasWallet() async {
    return await getPublicKey() != null;
  }

  /// Helper method to get Akofa tag for address
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

  /// Generate transaction description
  String _generateTransactionDescription(
    String type,
    String amount,
    String assetCode,
  ) {
    final action = type == 'send' ? 'Sent' : 'Received';
    return '$action $amount $assetCode';
  }

  /// Notify recipient of incoming transaction
  Future<void> _notifyRecipientOfIncomingTransaction(
    String recipientAddress,
    double amount,
    String? hash,
  ) async {
    try {
      final query = await _firestore
          .collection('USER')
          .where('stellarPublicKey', isEqualTo: recipientAddress)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final recipientDoc = query.docs.first;
        final recipientUid = recipientDoc.id;

        await _firestore.collection('notifications').add({
          'userId': recipientUid,
          'title': 'Incoming Transaction',
          'message': 'You received $amount AKOFA tokens',
          'type': 'transaction',
          'transactionHash': hash ?? '',
          'isRead': false,
          'createdAt': firestore.FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {}
  }

  /// Utility method to compare maps
  bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  // ==================== AUTOMATIC TRUSTLINE MANAGEMENT ====================

  /// Check if account has AKOFA trustline
  Future<bool> hasAkofaTrustline(String publicKey) async {
    try {
      final account = await _sdk.accounts.account(publicKey);
      return account.balances!.any(
        (b) =>
            b.assetCode == AKOFA_ASSET_CODE &&
            b.assetIssuer == AKOFA_ISSUER_ACCOUNT,
      );
    } catch (e) {
      return false;
    }
  }

  /// Check if account has sufficient XLM for transactions
  Future<bool> hasSufficientXlm(String publicKey) async {
    try {
      final account = await _sdk.accounts.account(publicKey);
      final nativeBalance = account.balances!.firstWhere(
        (b) => b.assetType == 'native',
      );
      final balance = double.tryParse(nativeBalance.balance) ?? 0.0;
      // Require at least 2 XLM for transaction fees and minimum balance
      return balance >= 2.0;
    } catch (e) {
      return false;
    }
  }

  /// Fund account with XLM using Friendbot
  Future<Map<String, dynamic>> fundAccountWithFriendbot(
    String publicKey,
  ) async {
    try {
      final friendBotUrl = 'https://friendbot.stellar.org/?addr=$publicKey';
      final response = await http.get(Uri.parse(friendBotUrl));

      if (response.statusCode == 200) {
        // Wait for the account to be created on the network
        await Future.delayed(const Duration(seconds: 5));

        // Verify the account was funded
        final hasSufficientXlm = await this.hasSufficientXlm(publicKey);
        if (hasSufficientXlm) {
          return {
            'success': true,
            'message': 'Account funded with test XLM',
            'funded': true,
          };
        } else {
          return {
            'success': false,
            'message': 'Account was created but funding verification failed',
            'funded': false,
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Friendbot funding failed',
          'error': 'HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error funding account',
        'error': e.toString(),
      };
    }
  }

  /// Create AKOFA trustline for account
  Future<Map<String, dynamic>> createAkofaTrustline(String publicKey) async {
    try {
      final credentials = await getWalletCredentials();
      if (credentials == null || credentials['secretKey'] == null) {
        return {
          'success': false,
          'message': 'Wallet credentials not available',
        };
      }

      final secretKey = credentials['secretKey']!;
      final sourceKeyPair = KeyPair.fromSecretSeed(secretKey);
      final sourceAccountId = sourceKeyPair.accountId;
      final sourceAccount = await _sdk.accounts.account(sourceAccountId);

      // Create trustline operation
      final trustlineOperation = ChangeTrustOperationBuilder(
        akofaAsset,
        '0', // Limit (0 means remove trustline, but we'll set a high limit)
      );

      // Build transaction
      final transactionBuilder = TransactionBuilder(sourceAccount);
      transactionBuilder.addOperation(trustlineOperation.build());

      final transaction = transactionBuilder.build();
      transaction.sign(sourceKeyPair, Network.TESTNET);

      final response = await _sdk.submitTransaction(transaction);

      if (response.success) {
        return {
          'success': true,
          'message': 'AKOFA trustline created successfully',
          'hash': response.hash,
        };
      } else {
        return {
          'success': false,
          'message': 'Trustline creation failed',
          'error': response.extras.toString(),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error creating trustline',
        'error': e.toString(),
      };
    }
  }

  /// Automatically setup wallet (fund with XLM and create AKOFA trustline)
  Future<Map<String, dynamic>> autoSetupWallet(String publicKey) async {
    try {
      final result = <String, dynamic>{
        'success': true,
        'funded': false,
        'trustlineCreated': false,
        'message': '',
      };

      // Step 1: Check if account exists and has sufficient XLM
      final hasSufficientXlm = await this.hasSufficientXlm(publicKey);
      if (!hasSufficientXlm) {
        final fundingResult = await fundAccountWithFriendbot(publicKey);
        if (fundingResult['success'] == true) {
          result['funded'] = true;
        } else {
          result['success'] = false;
          result['message'] =
              'Failed to fund account: ${fundingResult['message']}';
          return result;
        }
      } else {}

      // Step 2: Check if account has AKOFA trustline
      final hasTrustline = await hasAkofaTrustline(publicKey);
      if (!hasTrustline) {
        final trustlineResult = await createAkofaTrustline(publicKey);
        if (trustlineResult['success'] == true) {
          result['trustlineCreated'] = true;
        } else {
          result['success'] = false;
          result['message'] =
              'Failed to create trustline: ${trustlineResult['message']}';
          return result;
        }
      } else {}

      // Success
      result['message'] = 'Wallet setup completed successfully';
      if (result['funded'] == true && result['trustlineCreated'] == true) {
        result['message'] =
            'Wallet funded with XLM and AKOFA trustline created';
      } else if (result['funded'] == true) {
        result['message'] = 'Wallet funded with XLM';
      } else if (result['trustlineCreated'] == true) {
        result['message'] = 'AKOFA trustline created';
      }

      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error during wallet setup',
        'error': e.toString(),
      };
    }
  }

  // ==================== MULTI-ASSET SUPPORT ====================

  /// Create trustlines for multiple assets
  Future<Map<String, dynamic>> createMultipleTrustlines(
    String publicKey,
    List<AssetConfig> assets,
  ) async {
    try {
      final credentials = await getWalletCredentials();
      if (credentials == null || credentials['secretKey'] == null) {
        return {
          'success': false,
          'message': 'Wallet credentials not available',
        };
      }

      final secretKey = credentials['secretKey']!;
      final keyPair = KeyPair.fromSecretSeed(secretKey);
      final sourceAccount = await _sdk.accounts.account(publicKey);

      final results = <String, dynamic>{};
      final operations = <Operation>[];

      for (final asset in assets) {
        if (asset.isNative) continue; // Skip XLM

        // Check if trustline already exists
        final hasTrustline = await hasTrustlineForAsset(publicKey, asset);
        if (hasTrustline) {
          results[asset.assetId] = {
            'success': true,
            'message': 'Trustline already exists',
            'skipped': true,
          };
          continue;
        }

        // Create trustline operation
        final stellarAsset = AssetTypeCreditAlphaNum12(
          asset.code,
          asset.issuer,
        );
        final trustlineOp = ChangeTrustOperationBuilder(
          stellarAsset,
          '10000000', // Set high limit
        );

        operations.add(trustlineOp.build());
        results[asset.assetId] = {'pending': true};
      }

      if (operations.isEmpty) {
        return {
          'success': true,
          'message': 'All trustlines already exist',
          'results': results,
        };
      }

      // Build transaction with all operations
      final transactionBuilder = TransactionBuilder(sourceAccount);
      for (final op in operations) {
        transactionBuilder.addOperation(op);
      }

      final transaction = transactionBuilder.build();
      transaction.sign(keyPair, Network.TESTNET);

      final response = await _sdk.submitTransaction(transaction);

      if (response.success) {
        // Update results
        for (final asset in assets) {
          if (results[asset.assetId]['pending'] == true) {
            results[asset.assetId] = {
              'success': true,
              'message': 'Trustline created successfully',
              'hash': response.hash,
            };
          }
        }

        return {
          'success': true,
          'message': 'Trustlines created successfully',
          'hash': response.hash,
          'results': results,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to create trustlines',
          'error': response.extras.toString(),
          'results': results,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error creating trustlines',
        'error': e.toString(),
      };
    }
  }

  /// Check if account has trustline for specific asset
  Future<bool> hasTrustlineForAsset(String publicKey, AssetConfig asset) async {
    if (asset.isNative) return true; // XLM doesn't need trustline

    try {
      final account = await _sdk.accounts.account(publicKey);
      return account.balances!.any(
        (b) => b.assetCode == asset.code && b.assetIssuer == asset.issuer,
      );
    } catch (e) {
      return false;
    }
  }

  /// Send any asset (generic method)
  Future<Map<String, dynamic>> sendAsset({
    required String recipientAddress,
    required AssetConfig asset,
    required double amount,
    String? memo,
  }) async {
    try {
      final credentials = await getWalletCredentials();
      if (credentials == null) {
        throw Exception('Wallet credentials not found');
      }

      final secretKey = credentials['secretKey'];
      if (secretKey == null) {
        throw Exception('Secret key not available');
      }

      final sourceKeyPair = KeyPair.fromSecretSeed(secretKey);
      final sourceAccountId = sourceKeyPair.accountId;
      final sourceAccount = await _sdk.accounts.account(sourceAccountId);

      // Ensure recipient has trustline for non-native assets
      if (!asset.isNative) {
        await _ensureRecipientTrustlineForAsset(recipientAddress, asset);
      }

      // Create payment operation
      late PaymentOperationBuilder paymentOp;
      if (asset.isNative) {
        paymentOp = PaymentOperationBuilder(
          recipientAddress,
          AssetTypeNative(),
          amount.toStringAsFixed(7),
        );
      } else {
        final stellarAsset = AssetTypeCreditAlphaNum12(
          asset.code,
          asset.issuer,
        );
        paymentOp = PaymentOperationBuilder(
          recipientAddress,
          stellarAsset,
          amount.toStringAsFixed(asset.decimals),
        );
      }

      // Build transaction
      final transactionBuilder = TransactionBuilder(sourceAccount);
      transactionBuilder.addOperation(paymentOp.build());

      if (memo != null && memo.isNotEmpty) {
        transactionBuilder.addMemo(MemoText(memo));
      }

      final transaction = transactionBuilder.build();
      transaction.sign(sourceKeyPair, Network.TESTNET);

      final response = await _sdk.submitTransaction(transaction);

      if (response.success) {
        // Record transaction
        await TransactionService.recordSend(
          amount: amount,
          assetCode: asset.code,
          recipientAddress: recipientAddress,
          recipientAkofaTag: await _getAkofaTagForAddress(recipientAddress),
          memo: memo,
          stellarHash: response.hash,
          additionalMetadata: {
            'stellarNetwork': 'testnet',
            'assetType': asset.isNative ? 'native' : 'credit_alphanum',
            'assetIssuer': asset.isNative ? null : asset.issuer,
            'assetConfig': asset.toString(),
          },
        );

        // Notify recipient if they're a registered user
        await _notifyRecipientOfIncomingTransaction(
          recipientAddress,
          amount,
          response.hash,
        );

        return {
          'success': true,
          'hash': response.hash,
          'message': '${asset.symbol} sent successfully',
        };
      } else {
        throw Exception('Transaction failed: ${response.extras}');
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Ensure recipient has trustline for specific asset
  Future<void> _ensureRecipientTrustlineForAsset(
    String recipientAddress,
    AssetConfig asset,
  ) async {
    if (asset.isNative) return; // No trustline needed for XLM

    try {
      final recipientAccount = await _sdk.accounts.account(recipientAddress);
      final hasTrustline = recipientAccount.balances!.any(
        (b) => b.assetCode == asset.code && b.assetIssuer == asset.issuer,
      );

      if (!hasTrustline) {
        print(
          '⚠️ Recipient does not have ${asset.symbol} trustline, but proceeding with transaction',
        );
        // Note: In production, you might want to create the trustline or notify the user
      }
    } catch (e) {
      // Account might not exist yet, that's okay
    }
  }

  /// Get supported assets for the wallet
  List<AssetConfig> getSupportedAssets() {
    return AssetConfigs.allAssets;
  }

  /// Get stablecoins only
  List<AssetConfig> getStablecoins() {
    return AssetConfigs.stablecoins;
  }

  /// Clean up resources
  void dispose() {
    stopRealTimeMonitoring();
    _authStateSubscription?.cancel();
  }
}
