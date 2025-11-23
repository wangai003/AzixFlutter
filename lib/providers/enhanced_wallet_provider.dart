import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/enhanced_mpesa_service.dart';
import '../services/secure_wallet_service.dart';
import '../services/payment_webhook_service.dart';
import '../services/payment_security_service.dart';
import '../services/moonpay_service.dart';
import '../services/moonpay_callback_service.dart';
import '../services/polygon_wallet_service.dart';
import '../services/blockchain_transaction_service.dart';
import '../models/transaction.dart' as app_transaction;
import '../models/asset_config.dart';

class EnhancedWalletProvider extends ChangeNotifier {
  final EnhancedMpesaService _mpesaService = EnhancedMpesaService();
  final PaymentWebhookService _webhookService = PaymentWebhookService();
  final PaymentSecurityService _securityService = PaymentSecurityService();
  final MoonPayService _moonPayService = MoonPayService();
  final MoonPayCallbackService _moonPayCallbackService =
      MoonPayCallbackService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State variables - now using Polygon as primary wallet
  bool _isLoading = false;
  String? _error;
  bool _hasWallet = false;
  String? _address; // Polygon address (replaces Stellar publicKey)
  Map<String, dynamic> _balances = {}; // Polygon token balances
  List<Map<String, dynamic>> _transactions = []; // Polygon transactions
  bool _isMonitoringActive = false;

  // M-Pesa related state
  bool _isProcessingPayment = false;
  Map<String, dynamic>? _currentPaymentStatus;

  // MoonPay related state
  bool _isProcessingMoonPayPurchase = false;
  Map<String, dynamic>? _currentMoonPayTransaction;
  List<Map<String, dynamic>> _moonPayTransactionHistory = [];
  bool _isMonitoringMoonPayTransactions = false;

  // Secure wallet state (now for Polygon)
  bool _hasSecureWallet = false;
  bool _isBiometricAuthenticating = false;
  String? _secureWalletAddress;

  // Polygon token balances (multi-asset support)
  Map<String, Map<String, dynamic>> _polygonTokens = {};
  bool _isProcessingPolygonTransaction = false;
  
  // Network configuration
  bool _isTestnet = true; // Default to Amoy testnet

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasWallet => _hasWallet;
  String? get address => _address; // Polygon address
  String? get publicKey => _address; // Alias for backward compatibility
  Map<String, dynamic> get balances => _balances;
  List<Map<String, dynamic>> get transactions => _transactions;
  
  /// Get transactions as Transaction objects for UI compatibility
  List<app_transaction.Transaction> get transactionsAsObjects {
    final user = _auth.currentUser;
    if (user == null) return [];
    
    return _transactions.map((tx) {
      return app_transaction.Transaction(
        id: tx['hash'] as String? ?? 'polygon_${tx['hash']}',
        userId: user.uid,
        type: tx['type'] as String? ?? 'send',
        status: tx['status'] == 'success' ? 'completed' : 'pending',
        amount: (tx['value'] as num? ?? 0).toDouble(),
        assetCode: tx['asset'] as String? ?? 'MATIC',
        timestamp: tx['timestamp'] as DateTime? ?? DateTime.now(),
        description: _getPolygonTransactionDescription(tx),
        transactionHash: tx['hash'] as String?,
        senderAddress: tx['from'] as String?,
        recipientAddress: tx['to'] as String?,
        metadata: {
          'network': tx['network'],
          'gasUsed': tx['gasUsed'],
          'gasPrice': tx['gasPrice'],
          'confirmations': tx['confirmations'],
          'provider': 'polygon',
        },
      );
    }).toList();
  }
  bool get isMonitoringActive => _isMonitoringActive;
  bool get isProcessingPayment => _isProcessingPayment;
  Map<String, dynamic>? get currentPaymentStatus => _currentPaymentStatus;

  // MoonPay getters
  bool get isProcessingMoonPayPurchase => _isProcessingMoonPayPurchase;
  Map<String, dynamic>? get currentMoonPayTransaction =>
      _currentMoonPayTransaction;
  List<Map<String, dynamic>> get moonPayTransactionHistory =>
      _moonPayTransactionHistory;
  bool get isMonitoringMoonPayTransactions => _isMonitoringMoonPayTransactions;

  // Secure wallet getters
  bool get hasSecureWallet => _hasSecureWallet;
  bool get isBiometricAuthenticating => _isBiometricAuthenticating;
  String? get secureWalletPublicKey => _secureWalletAddress;
  String? get secureWalletAddress => _secureWalletAddress;

  // Polygon wallet getters
  bool get hasPolygonWallet => _hasWallet; // Unified wallet
  String? get polygonAddress => _address;
  Map<String, dynamic> get polygonBalances => _balances;
  Map<String, Map<String, dynamic>> get polygonTokens => _polygonTokens;
  bool get isProcessingPolygonTransaction => _isProcessingPolygonTransaction;
  String get polygonBalance => _balances['matic']?.toString() ?? '0';
  List<Map<String, dynamic>> get polygonTransactions => _transactions;

  // Computed getters (Polygon equivalents)
  String get maticBalance => _balances['matic']?.toString() ?? '0';
  String get akofaBalance => _polygonTokens['AKOFA']?['balance']?.toString() ?? '0';
  String get xlmBalance => maticBalance; // Alias for backward compatibility
  int get transactionCount => _transactions.length;
  List<Map<String, dynamic>> get recentTransactions =>
      _transactions.take(10).toList();
  
  // Network getters
  bool get isTestnet => _isTestnet;
  Map<String, dynamic> get networkInfo => PolygonWalletService.getNetworkInfo();

  EnhancedWalletProvider() {
    _initialize();
  }

  void _initialize() {
    // Initialize network settings
    final networkInfo = PolygonWalletService.getNetworkInfo();
    _isTestnet = networkInfo['isTestnet'] as bool;
    
    // Check wallet status
    checkWalletStatus();

    // Listen to auth state changes
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        checkWalletStatus();
      } else {
        _resetState();
      }
    });
  }
  
  /// Switch network (mainnet/testnet)
  Future<void> switchNetwork({required bool isTestnet}) async {
    _isTestnet = isTestnet;
    PolygonWalletService.setNetwork(isTestnet: isTestnet);
    
    // Refresh wallet data after network switch
    if (_hasWallet && _address != null) {
      await Future.wait([loadBalances(), loadTransactions(forceRefresh: true)]);
    }
    
    notifyListeners();
  }


  // ==================== WALLET MANAGEMENT ====================

  /// Check wallet status and initialize if needed (Polygon wallet)
  Future<void> checkWalletStatus() async {
    _setLoading(true);
    _setError(null);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _setLoading(false);
        return;
      }

      // Check for Polygon wallet
      _hasWallet = await PolygonWalletService.hasPolygonWallet(user.uid);
      if (_hasWallet) {
        _address = await PolygonWalletService.getPolygonWalletAddress(user.uid);
        _hasSecureWallet = true; // Polygon wallets are secure by default
        _secureWalletAddress = _address;
        
        if (_address != null) {
          // Load initial data
          await Future.wait([loadBalances(), loadTransactions()]);
          
          // Start MoonPay transaction monitoring
          if (!_isMonitoringMoonPayTransactions) {
            await startMoonPayTransactionMonitoring();
          }
        }
      }
    } catch (e) {
      _setError('Failed to check wallet status: $e');
    }

    _setLoading(false);
  }

  /// Create a new wallet
  Future<bool> createWallet(BuildContext context) async {
    _setLoading(true);
    _setError(null);

    try {
      // This would integrate with the existing wallet creation flow
      // For now, we'll assume the wallet creation is handled elsewhere
      await checkWalletStatus();
      return _hasWallet;
    } catch (e) {
      _setError('Failed to create wallet: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Create a Polygon wallet (primary wallet creation method)
  Future<Map<String, dynamic>> createPolygonWallet({
    required String password,
    String? recoveryPhrase,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final result = await PolygonWalletService.createSecurePolygonWallet(
        userId: user.uid,
        password: password,
        recoveryPhrase: recoveryPhrase,
      );

      if (result['success'] == true) {
        // Update local state
        _hasWallet = true;
        _hasSecureWallet = true;
        _address = result['address'];
        _secureWalletAddress = _address;

        // Load initial balances
        await loadBalances();
        await loadTransactions();

        _setLoading(false);
        return result;
      } else {
        throw Exception(result['error'] ?? 'Failed to create Polygon wallet');
      }
    } catch (e) {
      _setError('Failed to create Polygon wallet: $e');
      _setLoading(false);
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Create a secure Polygon wallet with biometric protection
  Future<Map<String, dynamic>> createSecureWallet({
    required BuildContext context,
    required String password,
    String? recoveryPhrase,
    bool enableBiometrics = false,
  }) async {
    // For Polygon, we use the PolygonWalletService which already includes encryption
    // Biometric support can be added via SecureWalletService wrapper if needed
    return await createPolygonWallet(
      password: password,
      recoveryPhrase: recoveryPhrase,
    );
  }

  /// Check if user has a secure wallet (Polygon)
  Future<bool> checkSecureWalletStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      _hasSecureWallet = await PolygonWalletService.hasPolygonWallet(user.uid);
      if (_hasSecureWallet) {
        _address = await PolygonWalletService.getPolygonWalletAddress(user.uid);
        _secureWalletAddress = _address;
      }
      notifyListeners();
      return _hasSecureWallet;
    } catch (e) {
      return false;
    }
  }

  /// Load wallet balances (Polygon)
  Future<void> loadBalances() async {
    if (_address == null) return;

    try {
      final balanceResult = await PolygonWalletService.getAllPolygonTokenBalances(_address!);
      if (balanceResult['success'] == true) {
        final tokens = balanceResult['tokens'] as Map<String, dynamic>;
        _polygonTokens = Map<String, Map<String, dynamic>>.from(tokens);
        
        // Update balances map for backward compatibility
        if (_polygonTokens.containsKey('MATIC')) {
          _balances['matic'] = _polygonTokens['MATIC']!['balance'];
        }
        if (_polygonTokens.containsKey('AKOFA')) {
          _balances['akofa'] = _polygonTokens['AKOFA']!['balance'];
        }
      }
      notifyListeners();
    } catch (e) {
      print('Error loading Polygon balances: $e');
    }
  }

  /// Load transactions (Polygon)
  Future<void> loadTransactions({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) {
      debugPrint('⏸️ Already loading transactions, skipping...');
      return;
    }
    
    if (_address == null) return;
    
    try {
      _isLoading = true;
      notifyListeners();
      
      debugPrint('🔄 Loading Polygon transactions... Address: $_address');
      
      _transactions = await PolygonWalletService.getPolygonTransactionHistory(
        _address!,
        limit: 50,
      );
      
      debugPrint('✅ Loaded ${_transactions.length} Polygon transactions');
      
      _isLoading = false;
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading Polygon transactions: $e');
      debugPrint('Stack trace: $stackTrace');
      _transactions = [];
      _isLoading = false;
      notifyListeners();
    }
  }


  /// Refresh all wallet data (Polygon)
  Future<void> refreshWallet() async {
    _setLoading(true);
    _setError(null);

    try {
      await Future.wait([loadBalances(), loadTransactions(forceRefresh: true)]);
    } catch (e) {
      _setError('Failed to refresh wallet: $e');
    }

    _setLoading(false);
  }

  /// Automatically setup wallet if needed (Polygon - no trustlines needed)
  Future<void> _autoSetupWalletIfNeeded(String address) async {
    try {
      // Polygon doesn't require trustlines - tokens are automatically available
      // Just ensure wallet has been created and has an address
      if (address.isEmpty) {
        print('⚠️ Wallet address is empty');
        return;
      }
      print('✅ Polygon wallet ready: $address');
    } catch (e) {
      print('Error in auto-setup: $e');
    }
  }

  // ==================== TRANSACTION OPERATIONS ====================

  /// Send AKOFA tokens (Polygon ERC-20) - backward compatibility method
  Future<Map<String, dynamic>> sendAkofaTokens({
    required String recipientAddress,
    required double amount,
    String? memo,
    String? password,
  }) async {
    // If password is provided, use the secure method
    if (password != null) {
      return await sendAkofaWithAuthentication(
        recipientAddress: recipientAddress,
        amount: amount,
        memo: memo ?? '',
        password: password,
      );
    }
    
    // Otherwise return error - password required for Polygon
    return {
      'success': false,
      'error': 'Password required for Polygon transactions',
    };
  }

  /// Send XLM (alias for sendMatic - backward compatibility)
  Future<Map<String, dynamic>> sendXLM({
    required String recipientAddress,
    required double amount,
    String? memo,
    String? password,
  }) async {
    // If password is provided, use sendMatic
    if (password != null) {
      return await sendMatic(
        recipientAddress: recipientAddress,
        amount: amount,
        password: password,
      );
    }
    
    // Otherwise return error - password required for Polygon
    return {
      'success': false,
      'error': 'Password required for Polygon transactions',
    };
  }

  /// Send AKOFA tokens with authentication (secure wallet)
  Future<Map<String, dynamic>> sendAkofaWithAuthentication({
    required String recipientAddress,
    required double amount,
    required String memo,
    required String password,
  }) async {
    if (!_hasSecureWallet) {
      return await sendAkofaTokens(
        recipientAddress: recipientAddress,
        amount: amount,
        memo: memo,
      );
    }

    _isBiometricAuthenticating = true;
    _setLoading(true);
    _setError(null);
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final result = await SecureWalletService.signTransactionWithPassword(
        userId: user.uid,
        password: password,
        recipientAddress: recipientAddress,
        amount: amount,
        assetCode: 'AKOFA',
        memo: memo,
      );

      if (result['success'] == true) {
        // Refresh data after successful transaction
        await Future.wait([
          loadBalances(),
          loadTransactions(forceRefresh: true),
        ]);
      }

      _isBiometricAuthenticating = false;
      _setLoading(false);
      notifyListeners();
      return result;
    } catch (e) {
      _isBiometricAuthenticating = false;
      _setError('Authentication failed: $e');
      _setLoading(false);
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Send XLM with biometric authentication (secure wallet)
  Future<Map<String, dynamic>> sendXLMWithBiometrics({
    required String recipientAddress,
    required double amount,
    required String memo,
  }) async {
    if (!_hasSecureWallet) {
      return await sendXLM(
        recipientAddress: recipientAddress,
        amount: amount,
        memo: memo,
      );
    }

    _isBiometricAuthenticating = true;
    _setLoading(true);
    _setError(null);
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final result = await SecureWalletService.signTransactionWithBiometrics(
        userId: user.uid,
        recipientAddress: recipientAddress,
        amount: amount,
        assetCode: 'XLM',
        memo: memo,
      );

      if (result['success'] == true) {
        // Refresh data after successful transaction
        await Future.wait([
          loadBalances(),
          loadTransactions(forceRefresh: true),
        ]);
      }

      _isBiometricAuthenticating = false;
      _setLoading(false);
      notifyListeners();
      return result;
    } catch (e) {
      _isBiometricAuthenticating = false;
      _setError('Biometric transaction failed: $e');
      _setLoading(false);
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==================== MULTI-ASSET SUPPORT ====================

  /// Get all supported assets (Polygon tokens)
  List<AssetConfig> get supportedAssets {
    // Return Polygon token configurations
    // This would be populated from PolygonWalletService token registry
    return [
      AssetConfig(
        code: 'MATIC',
        symbol: 'MATIC',
        name: 'Polygon Matic',
        issuer: '',
        isNative: true,
        decimals: 18,
      ),
      // Add other Polygon tokens as needed
    ];
  }

  /// Get stablecoins only (Polygon)
  List<AssetConfig> get stablecoins {
    return supportedAssets.where((asset) => asset.isStablecoin).toList();
  }

  /// Create multiple trustlines (Polygon - no-op, trustlines not needed)
  /// This method exists for backward compatibility but does nothing on Polygon
  Future<Map<String, dynamic>> createMultipleTrustlines(
    List<AssetConfig> assets,
  ) async {
    // Polygon doesn't require trustlines - tokens are automatically available
    return {
      'success': true,
      'message': 'Polygon doesn\'t require trustlines - tokens are automatically available',
      'assets': assets.map((a) => a.symbol).toList(),
    };
  }

  /// Send any asset (generic method - Polygon)
  Future<Map<String, dynamic>> sendAsset({
    required String recipientAddress,
    required AssetConfig asset,
    required double amount,
    String? memo,
    required String password, // Required password for Polygon transactions
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      debugPrint('🔄 Sending ${asset.symbol} on Polygon - Address: $_address');
      
      if (_address == null) {
        throw Exception('No wallet found');
      }

      // For MATIC (native token)
      if (asset.code == 'MATIC' || asset.isNative) {
        return await sendMatic(
          recipientAddress: recipientAddress,
          amount: amount,
          password: password,
        );
      }

      // For ERC-20 tokens (like AKOFA), implement ERC-20 transfer
      // This requires contract interaction
      _setLoading(false);
      return {
        'success': false,
        'error': 'ERC-20 token transfers not yet implemented. Currently only MATIC transfers are supported.',
      };
    } catch (e, stackTrace) {
      debugPrint('❌ Error sending ${asset.symbol}: $e');
      debugPrint('Stack trace: $stackTrace');
      _setError('Failed to send ${asset.symbol}: $e');
      _setLoading(false);
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Send MATIC tokens (Polygon native token)
  Future<Map<String, dynamic>> sendMatic({
    required String recipientAddress,
    required double amount,
    required String password,
  }) async {
    if (!_hasWallet || _address == null) {
      return {'success': false, 'error': 'No Polygon wallet found'};
    }

    _isProcessingPolygonTransaction = true;
    _setError(null);
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final result = await PolygonWalletService.sendMaticTransaction(
        userId: user.uid,
        password: password,
        toAddress: recipientAddress,
        amountMatic: amount,
      );

      if (result['success'] == true) {
        // Refresh balances and transactions after successful transaction
        await Future.wait([loadBalances(), loadTransactions(forceRefresh: true)]);
      }

      _isProcessingPolygonTransaction = false;
      notifyListeners();
      return result;
    } catch (e) {
      _setError('Failed to send MATIC: $e');
      _isProcessingPolygonTransaction = false;
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Send stablecoin with biometric authentication
  Future<Map<String, dynamic>> sendStablecoinWithBiometrics({
    required String recipientAddress,
    required AssetConfig stablecoin,
    required double amount,
    required String memo,
  }) async {
    if (!stablecoin.isStablecoin) {
      return {'success': false, 'error': 'Asset is not a stablecoin'};
    }

    if (!_hasSecureWallet) {
      // Password is required for Polygon transactions
      return {'success': false, 'error': 'Password required for transactions'};
    }

    _isBiometricAuthenticating = true;
    _setLoading(true);
    _setError(null);
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final result = await SecureWalletService.signTransactionWithPassword(
        userId: user.uid,
        password: '', // This will be handled by the UI to prompt for password
        recipientAddress: recipientAddress,
        amount: amount,
        assetCode: stablecoin.code,
        memo: memo,
      );

      if (result['success'] == true) {
        // Refresh data after successful transaction
        await Future.wait([
          loadBalances(),
          loadTransactions(forceRefresh: true),
        ]);
      }

      _isBiometricAuthenticating = false;
      _setLoading(false);
      notifyListeners();
      return result;
    } catch (e) {
      _isBiometricAuthenticating = false;
      _setError('Biometric stablecoin transaction failed: $e');
      _setLoading(false);
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get balance for specific asset
  String getAssetBalance(String assetId) {
    // All asset balances are now stored with their assetId as the key
    return _balances[assetId] ?? '0';
  }

  /// Get asset configuration by ID
  AssetConfig? getAssetConfig(String assetId) {
    return AssetConfigs.findByAssetId(assetId);
  }

  /// Check if user has trustline for asset (Polygon - always true, no trustlines needed)
  Future<bool> hasTrustlineForAsset(AssetConfig asset) async {
    // Polygon doesn't require trustlines - all tokens are automatically available
    return true;
  }

  /// Setup wallet with multiple assets (Polygon - no setup needed)
  Future<Map<String, dynamic>> setupWalletWithMultipleAssets(
    List<AssetConfig> assets,
  ) async {
    if (_address == null) {
      return {'success': false, 'message': 'No wallet found'};
    }

    _setLoading(true);
    _setError(null);

    try {
      // First setup basic wallet (Polygon doesn't need funding or trustlines)
      await _autoSetupWalletIfNeeded(_address!);

      // Polygon doesn't require trustlines - tokens are automatically available
      // This is a no-op for Polygon
      final trustlineResult = {'success': true, 'message': 'Polygon doesn\'t require trustlines'};

      _setLoading(false);

      return {
        'success': true,
        'message': 'Wallet setup completed with multiple assets',
        'trustlines': trustlineResult,
      };
    } catch (e) {
      _setError('Failed to setup wallet with multiple assets: $e');
      _setLoading(false);
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==================== M-PESA INTEGRATION ====================

  /// Purchase AKOFA tokens using M-Pesa
  Future<Map<String, dynamic>> purchaseAkofaWithMpesa({
    required String phoneNumber,
    required double amountKES,
    String? accountReference,
  }) async {
    _isProcessingPayment = true;
    _setError(null);
    notifyListeners();

    try {
      final result = await _mpesaService.purchaseAkofaTokens(
        phoneNumber: phoneNumber,
        amountKES: amountKES,
        accountReference: accountReference,
      );

      if (result['success'] == true) {
        _currentPaymentStatus = {
          'status': 'pending',
          'checkoutRequestId': result['checkoutRequestId'],
          'akofaAmount': result['akofaAmount'],
          'amountKES': result['amountKES'],
        };
      }

      _isProcessingPayment = false;
      notifyListeners();
      return result;
    } catch (e) {
      _setError('Failed to initiate M-Pesa payment: $e');
      _isProcessingPayment = false;
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Sell AKOFA tokens for M-Pesa
  Future<Map<String, dynamic>> sellAkofaWithMpesa({
    required String phoneNumber,
    required double akofaAmount,
    String? accountReference,
  }) async {
    _isProcessingPayment = true;
    _setError(null);
    notifyListeners();

    try {
      final result = await _mpesaService.sellAkofaTokens(
        phoneNumber: phoneNumber,
        akofaAmount: akofaAmount,
        accountReference: accountReference,
      );

      if (result['success'] == true) {
        _currentPaymentStatus = {
          'status': 'pending',
          'checkoutRequestId': result['checkoutRequestId'],
          'akofaAmount': akofaAmount,
          'amountKES': result['amountKES'],
        };

        // Refresh balances after successful sell initiation
        await Future.wait([
          loadBalances(),
          loadTransactions(forceRefresh: true),
        ]);
      }

      _isProcessingPayment = false;
      notifyListeners();
      return result;
    } catch (e) {
      _setError('Failed to initiate AKOFA sell: $e');
      _isProcessingPayment = false;
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Check M-Pesa payment status
  Future<Map<String, dynamic>> checkPaymentStatus(
    String checkoutRequestId,
  ) async {
    _setLoading(true);
    _setError(null);

    try {
      final result = await _mpesaService.queryPaymentStatus(checkoutRequestId);

      if (result['success'] == true && result['status'] == 'completed') {
        // Payment successful, refresh wallet data
        await Future.wait([
          loadBalances(),
          loadTransactions(forceRefresh: true),
        ]);

        _currentPaymentStatus = {
          'status': 'completed',
          'akofaAmount': _currentPaymentStatus?['akofaAmount'],
          'amountKES': _currentPaymentStatus?['amountKES'],
        };
      }

      _setLoading(false);
      notifyListeners();
      return result;
    } catch (e) {
      _setError('Failed to check payment status: $e');
      _setLoading(false);
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get M-Pesa transaction history
  Future<List<Map<String, dynamic>>> getMpesaHistory() async {
    try {
      return await _mpesaService.getMpesaTransactionHistory();
    } catch (e) {
      return [];
    }
  }

  /// Purchase AKOFA tokens using Flutterwave MTN (multi-country) - REMOVED
  Future<Map<String, dynamic>> purchaseAkofaWithFlutterwaveMtn({
    required String phoneNumber,
    required double amount,
    required String countryCode,
    required String provider,
  }) async {
    return {
      'success': false,
      'error': 'Flutterwave MTN payment processing is no longer available',
    };
  }

  /// Start polling for payment status updates
  void _startPaymentStatusPolling(String txRef) {
    // Poll for status updates (this would be implemented with a timer or stream)
    // For now, we'll just mark it as a background task
    Future.delayed(const Duration(seconds: 30), () async {
      try {
        final statusResult = await _webhookService.pollPaymentStatus(txRef);
        if (statusResult['success'] == true &&
            statusResult['status'] == 'completed') {
          // Payment completed, refresh wallet data
          await Future.wait([
            loadBalances(),
            loadTransactions(forceRefresh: true),
          ]);

          _currentPaymentStatus = {
            'status': 'completed',
            'akofaAmount': _currentPaymentStatus?['akofaAmount'],
            'localAmount': _currentPaymentStatus?['localAmount'],
            'currency': _currentPaymentStatus?['currency'],
          };

          notifyListeners();
        }
      } catch (e) {
        // Polling failed, user can manually check status
        print('Payment status polling failed: $e');
      }
    });
  }

  /// Check Flutterwave MTN payment status - REMOVED
  Future<Map<String, dynamic>> checkFlutterwavePaymentStatus(
    String txRef,
  ) async {
    return {
      'success': false,
      'error': 'Flutterwave payment status checking is no longer available',
    };
  }

  /// Get Flutterwave MTN transaction history - REMOVED
  Future<List<Map<String, dynamic>>> getFlutterwaveMtnHistory() async {
    return [];
  }

  /// Get combined transaction history (M-Pesa + MTN + Sell)
  Future<List<Map<String, dynamic>>> getCombinedTransactionHistory() async {
    try {
      final mpesaHistory = await getMpesaHistory();
      final mtnHistory =
          await getFlutterwaveMtnHistory(); // Will return empty list
      final sellHistory = await getMpesaSellHistory();

      // Combine and sort by timestamp
      final combined = [...mpesaHistory, ...mtnHistory, ...sellHistory];
      combined.sort((a, b) {
        final aTime = a['createdAt'] ?? a['timestamp'];
        final bTime = b['createdAt'] ?? b['timestamp'];

        if (aTime is Timestamp && bTime is Timestamp) {
          return bTime.compareTo(aTime);
        }
        return 0;
      });

      return combined;
    } catch (e) {
      return [];
    }
  }

  /// Get M-Pesa sell transaction history
  Future<List<Map<String, dynamic>>> getMpesaSellHistory() async {
    try {
      return await _mpesaService.getMpesaSellTransactionHistory();
    } catch (e) {
      return [];
    }
  }

  /// Get purchase statistics (combined)
  Future<Map<String, dynamic>> getPurchaseStats() async {
    try {
      final mpesaStats = await _mpesaService.getPurchaseStats();
      final sellStats = await _mpesaService.getSellStats();
      // Flutterwave stats removed - integration no longer available

      // Return combined statistics
      return {
        'mpesa': mpesaStats,
        'sell': sellStats,
        'flutterwaveMtn': {
          'totalTransactions': 0,
          'totalAmount': 0.0,
          'totalAkofa': 0.0,
        },
        'totalTransactions':
            (mpesaStats['totalTransactions'] ?? 0) +
            (sellStats['totalSells'] ?? 0),
        'totalAmount':
            (mpesaStats['totalAmount'] ?? 0.0) +
            (sellStats['totalKESReceived'] ?? 0.0),
        'totalAkofa':
            (mpesaStats['totalAkofa'] ?? 0.0) +
            (sellStats['totalAkofaSold'] ?? 0.0),
      };
    } catch (e) {
      return {};
    }
  }

  // ==================== REAL-TIME CALLBACKS ====================

  /// Called when transactions are updated (not used for Polygon)
  void _onTransactionsUpdated(List<app_transaction.Transaction> transactions) {
    // Not used for Polygon - transactions are Maps
    notifyListeners();
  }

  /// Called when balances are updated
  void _onBalancesUpdated(Map<String, dynamic> balances) {
    _balances = balances;
    notifyListeners();
  }

  /// Called when a new transaction is detected
  void _onNewTransaction(String message) {
    // You could show a notification or snackbar here
  }

  // ==================== UTILITY METHODS ====================

  /// Filter transactions by type
  List<Map<String, dynamic>> filterTransactions(String type) {
    if (type == 'all') return _transactions;
    return _transactions.where((tx) => tx['type'] == type).toList();
  }

  /// Search transactions
  List<Map<String, dynamic>> searchTransactions(String query) {
    if (query.isEmpty) return _transactions;

    final lowercaseQuery = query.toLowerCase();
    return _transactions.where((tx) {
      return ((tx['description'] as String?)?.toLowerCase().contains(lowercaseQuery) ??
              false) ||
          (tx['asset'] as String? ?? tx['assetCode'] as String? ?? '').toLowerCase().contains(lowercaseQuery) ||
          ((tx['memo'] as String?)?.toLowerCase().contains(lowercaseQuery) ?? false) ||
          ((tx['senderAkofaTag'] as String?)?.toLowerCase().contains(lowercaseQuery) ??
              false) ||
          ((tx['recipientAkofaTag'] as String?)?.toLowerCase().contains(lowercaseQuery) ??
              false);
    }).toList();
  }

  /// Get transaction statistics
  Map<String, dynamic> getTransactionStats() {
    int sentCount = 0;
    int receivedCount = 0;
    int miningCount = 0;
    double totalSent = 0;
    double totalReceived = 0;
    double totalMined = 0;

    for (final tx in _transactions) {
      final type = tx['type'] as String? ?? '';
      final amount = (tx['value'] as num? ?? tx['amount'] as num? ?? 0).toDouble();
      
      switch (type) {
        case 'send':
        case 'outgoing':
          sentCount++;
          totalSent += amount;
          break;
        case 'receive':
        case 'incoming':
          receivedCount++;
          totalReceived += amount;
          break;
        case 'mining':
          miningCount++;
          totalMined += amount;
          break;
      }
    }

    return {
      'totalTransactions': _transactions.length,
      'sentCount': sentCount,
      'receivedCount': receivedCount,
      'miningCount': miningCount,
      'totalSent': totalSent,
      'totalReceived': totalReceived,
      'totalMined': totalMined,
    };
  }

  /// Clear current payment status
  void clearPaymentStatus() {
    _currentPaymentStatus = null;
    notifyListeners();
  }

  // ==================== MOONPAY INTEGRATION ====================

  /// Purchase MATIC using MoonPay (Polygon)
  Future<Map<String, dynamic>> purchaseXLMWithMoonPay({
    required double amountUSD,
    String? email,
    String? externalCustomerId,
  }) async {
    if (_address == null) {
      return {'success': false, 'error': 'No wallet found'};
    }

    _isProcessingMoonPayPurchase = true;
    _setError(null);
    notifyListeners();

    try {
      // Validate wallet address (Polygon address format)
      if (!_address!.startsWith('0x') || _address!.length != 42) {
        throw Exception('Invalid Polygon wallet address');
      }

      // Generate MoonPay widget URL for Polygon/MATIC
      final widgetUrl = MoonPayService.generateEnhancedWidgetUrl(
        walletAddress: _address!,
        currencyCode: 'matic_polygon', // MoonPay code for Polygon MATIC
        baseCurrencyAmount: amountUSD,
        baseCurrencyCode: 'USD',
        email: email,
        externalCustomerId: externalCustomerId,
        theme: 'dark',
        language: 'en',
      );

      // Store transaction details for monitoring
      _currentMoonPayTransaction = {
        'widgetUrl': widgetUrl,
        'amountUSD': amountUSD,
        'walletAddress': _address,
        'currencyCode': 'matic_polygon',
        'status': 'initiated',
        'timestamp': DateTime.now().toIso8601String(),
      };

      _isProcessingMoonPayPurchase = false;
      notifyListeners();

      return {
        'success': true,
        'widgetUrl': widgetUrl,
        'transaction': _currentMoonPayTransaction,
      };
    } catch (e) {
      _setError('Failed to initiate MoonPay purchase: $e');
      _isProcessingMoonPayPurchase = false;
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Check MoonPay transaction status
  Future<Map<String, dynamic>> checkMoonPayTransactionStatus(
    String transactionId,
  ) async {
    _setLoading(true);
    _setError(null);

    try {
      final result = await MoonPayService.getTransactionStatusWithRetry(
        transactionId,
      );

      if (result != null) {
        final status = result['status'];

        if (status == 'completed') {
          // Transaction completed, refresh wallet data
          await Future.wait([
            loadBalances(),
            loadTransactions(forceRefresh: true),
          ]);

          _currentMoonPayTransaction = {
            ...?_currentMoonPayTransaction,
            'status': 'completed',
            'completedAt': DateTime.now().toIso8601String(),
          };

          // Record transaction in history
          await _recordMoonPayTransactionCompletion(result);
        } else if (MoonPayService.isTransactionFinal(status)) {
          // Transaction is in final state, update local state
          _currentMoonPayTransaction = {
            ...?_currentMoonPayTransaction,
            'status': status,
            'finalizedAt': DateTime.now().toIso8601String(),
          };
        }
      }

      _setLoading(false);
      return result ?? {'success': false, 'error': 'Transaction not found'};
    } catch (e) {
      _setError('Failed to check MoonPay transaction status: $e');
      _setLoading(false);
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Start monitoring MoonPay transactions
  Future<void> startMoonPayTransactionMonitoring() async {
    if (_isMonitoringMoonPayTransactions || _auth.currentUser == null) return;

    _isMonitoringMoonPayTransactions = true;

    try {
      // Load existing MoonPay transactions
      await loadMoonPayTransactionHistory();

      // Start polling for pending transactions
      _startMoonPayPolling();
    } catch (e) {
      debugPrint('Error starting MoonPay monitoring: $e');
      _isMonitoringMoonPayTransactions = false;
    }

    notifyListeners();
  }

  /// Stop monitoring MoonPay transactions
  void stopMoonPayTransactionMonitoring() {
    _isMonitoringMoonPayTransactions = false;
    notifyListeners();
  }

  /// Load MoonPay transaction history
  Future<void> loadMoonPayTransactionHistory() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      _moonPayTransactionHistory = await _moonPayCallbackService
          .getUserMoonPayTransactions(user.uid);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading MoonPay transaction history: $e');
    }
  }

  /// Get pending MoonPay transactions
  Future<List<Map<String, dynamic>>> getPendingMoonPayTransactions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      return await _moonPayCallbackService.getPendingMoonPayTransactions(
        user.uid,
      );
    } catch (e) {
      debugPrint('Error getting pending MoonPay transactions: $e');
      return [];
    }
  }

  /// Process MoonPay webhook (called from external webhook endpoint)
  Future<Map<String, dynamic>> processMoonPayWebhook(
    Map<String, dynamic> payload,
    String signature,
  ) async {
    try {
      final result = await _moonPayCallbackService.processWebhookPayload(
        payload,
        signature,
      );

      if (result['success'] == true) {
        // Refresh wallet data if transaction was completed
        final data = payload['data'];
        if (data != null && data['status'] == 'completed') {
          await Future.wait([
            loadBalances(),
            loadTransactions(forceRefresh: true),
            loadMoonPayTransactionHistory(),
          ]);
        }
      }

      return result;
    } catch (e) {
      debugPrint('Error processing MoonPay webhook: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Record MoonPay transaction completion
  Future<void> _recordMoonPayTransactionCompletion(
    Map<String, dynamic> transactionData,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // The transaction recording is handled by the webhook service
      // Just refresh the transaction history
      await loadMoonPayTransactionHistory();
    } catch (e) {
      debugPrint('Error recording MoonPay transaction completion: $e');
    }
  }

  /// Start polling for MoonPay transaction updates
  void _startMoonPayPolling() {
    if (!_isMonitoringMoonPayTransactions) return;

    Future.delayed(const Duration(seconds: 30), () async {
      if (!_isMonitoringMoonPayTransactions) return;

      try {
        final pendingTransactions = await getPendingMoonPayTransactions();

        for (final transaction in pendingTransactions) {
          final transactionId = transaction['id'];
          if (transactionId != null) {
            await checkMoonPayTransactionStatus(transactionId);
          }
        }

        // Check for stuck transactions and retry
        await _moonPayCallbackService.checkAndRetryStuckTransactions();

        // Clean up old transactions
        await _moonPayCallbackService.cleanupOldTransactions();
      } catch (e) {
        debugPrint('Error in MoonPay polling: $e');
      }

      // Continue polling if still monitoring
      if (_isMonitoringMoonPayTransactions) {
        _startMoonPayPolling();
      }
    });
  }

  /// Handle timeout for stuck MoonPay transactions
  Future<void> handleMoonPayTransactionTimeout(String transactionId) async {
    try {
      // Mark transaction as potentially stuck
      _setError(
        'Transaction $transactionId may be stuck. Please check status manually.',
      );

      // Attempt to poll the transaction status one more time
      final status = await MoonPayService.pollTransactionStatus(
        transactionId,
        timeout: const Duration(minutes: 5),
        pollInterval: const Duration(seconds: 5),
      );

      if (status != null) {
        // Process the final status
        await _handleMoonPayTransactionStatusUpdate(transactionId, status);
      } else {
        // Transaction is truly stuck
        _setError(
          'Transaction $transactionId is stuck. Please contact support.',
        );
      }
    } catch (e) {
      debugPrint('Error handling MoonPay transaction timeout: $e');
      _setError('Failed to handle transaction timeout: $e');
    }
  }

  /// Handle MoonPay transaction status update
  Future<void> _handleMoonPayTransactionStatusUpdate(
    String transactionId,
    Map<String, dynamic> statusData,
  ) async {
    try {
      final status = statusData['status'];

      if (status == 'completed') {
        // Transaction completed successfully
        await Future.wait([
          loadBalances(),
          loadTransactions(forceRefresh: true),
          loadMoonPayTransactionHistory(),
        ]);

        _currentMoonPayTransaction = {
          ...?_currentMoonPayTransaction,
          'status': 'completed',
          'completedAt': DateTime.now().toIso8601String(),
        };

        // Clear any error messages
        _setError(null);
      } else if (status == 'failed' || status == 'cancelled') {
        // Transaction failed or cancelled
        _currentMoonPayTransaction = {
          ...?_currentMoonPayTransaction,
          'status': status,
          'failedAt': DateTime.now().toIso8601String(),
        };

        _setError(
          'MoonPay transaction $status. Please try again or contact support.',
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error handling MoonPay status update: $e');
    }
  }

  /// Manually check and recover from MoonPay transaction failures
  Future<void> recoverMoonPayTransaction(String transactionId) async {
    _setLoading(true);
    _setError(null);

    try {
      // First try to get the latest status
      final status = await MoonPayService.getTransactionStatusWithRetry(
        transactionId,
      );

      if (status != null) {
        await _handleMoonPayTransactionStatusUpdate(transactionId, status);
      } else {
        // If we can't get status, try webhook polling as fallback
        final polledStatus = await _moonPayCallbackService
            .pollTransactionStatus(transactionId);
        if (polledStatus != null) {
          await _handleMoonPayTransactionStatusUpdate(
            transactionId,
            polledStatus,
          );
        } else {
          throw Exception('Unable to recover transaction status');
        }
      }
    } catch (e) {
      _setError('Failed to recover transaction: $e');
    }

    _setLoading(false);
  }

  /// Sync MoonPay transactions with Stellar transaction monitoring
  Future<void> _syncMoonPayTransactionsWithStellar() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get recent MoonPay transactions
      final moonPayTransactions = await _moonPayCallbackService
          .getUserMoonPayTransactions(user.uid);

      // Filter completed transactions that might not be in Stellar yet
      final completedMoonPayTxs = moonPayTransactions
          .where((tx) => tx['status'] == 'completed' && tx['processed'] != true)
          .toList();

      for (final moonPayTx in completedMoonPayTxs) {
        final transactionId = moonPayTx['id'];
        final walletAddress = moonPayTx['walletAddress'];

        // Check if this transaction is already recorded in Polygon transactions
        final polygonTxs = _transactions
            .where(
              (tx) {
                final metadata = tx['metadata'] as Map<String, dynamic>?;
                return tx['hash'] == transactionId ||
                    tx['transactionHash'] == transactionId ||
                    (metadata?['externalTransactionId'] == transactionId);
              },
            )
            .toList();

        if (polygonTxs.isEmpty && walletAddress == _address) {
          // Transaction not found in Polygon, but MoonPay shows completed
          // This might indicate the transaction is still being processed on Polygon
          // We'll let the regular monitoring handle it, but log for awareness
          debugPrint(
            'MoonPay transaction $transactionId completed but not yet in Polygon transactions',
          );
        }
      }
    } catch (e) {
      debugPrint('Error syncing MoonPay transactions with Stellar: $e');
    }
  }

  /// Get combined blockchain transaction history (Polygon + MoonPay)
  Future<List<app_transaction.Transaction>>
  getCombinedBlockchainTransactionHistory() async {
    try {
      debugPrint('🔄 Getting combined transaction history...');
      debugPrint('   Address: $_address');
      debugPrint('   Has wallet: $_hasWallet');
      
      // Get Stellar transactions with timeout
      try {
        await loadTransactions().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            debugPrint('⚠️ Transaction loading timed out after 30 seconds');
          },
        );
      } catch (e) {
        debugPrint('❌ Error loading transactions: $e');
        // Continue with empty list if loading fails
      }
      
      final polygonTxs = _transactions;
      debugPrint('   Polygon transactions loaded: ${polygonTxs.length}');

      final user = _auth.currentUser;
      final allTransactions = <app_transaction.Transaction>[];

      if (user != null) {
        // Convert Polygon transactions to Transaction format
        if (_hasWallet && polygonTxs.isNotEmpty) {
          final polygonTransactions = polygonTxs.map((polyTx) {
            return app_transaction.Transaction(
              id: 'polygon_${polyTx['hash']}',
              userId: user.uid,
              type: polyTx['type'] == 'receive' ? 'receive' : 'send',
              status: polyTx['status'] == 'success' ? 'completed' : 'pending',
              amount: polyTx['value'] as double,
              assetCode: polyTx['asset'] as String,
              timestamp: polyTx['timestamp'] as DateTime,
              description: _getPolygonTransactionDescription(polyTx),
              memo: 'Polygon transaction',
              transactionHash: polyTx['hash'],
              senderAddress: polyTx['from'],
              recipientAddress: polyTx['to'],
              metadata: {
                'network': polyTx['network'],
                'gasUsed': polyTx['gasUsed'],
                'gasPrice': polyTx['gasPrice'],
                'confirmations': polyTx['confirmations'],
                'provider': 'polygon',
              },
            );
          }).toList();

          allTransactions.addAll(polygonTransactions);
        }

        // Get MoonPay transactions and convert to Transaction format
        final moonPayTxs = await _moonPayCallbackService
            .getUserMoonPayTransactions(user.uid);

        final moonPayTransactions = moonPayTxs.map((mpTx) {
          final currencyCode = mpTx['currency']?['code'] ?? 'MATIC';
          final amount = mpTx['quoteCurrencyAmount']?.toDouble() ?? 0.0;

          return app_transaction.Transaction(
            id: 'moonpay_${mpTx['id']}',
            userId: user.uid,
            type: 'receive',
            status: mpTx['status'] == 'completed' ? 'completed' : 'pending',
            amount: amount,
            assetCode: currencyCode,
            timestamp: mpTx['createdAt'] is DateTime
                ? mpTx['createdAt']
                : DateTime.tryParse(mpTx['createdAt']?.toString() ?? '') ??
                      DateTime.now(),
            description: 'MoonPay Purchase',
            memo: 'MoonPay transaction ${mpTx['id']}',
            transactionHash: mpTx['id'],
            senderAddress: 'MoonPay',
            recipientAddress: mpTx['walletAddress'],
            metadata: {
              'externalTransactionId': mpTx['id'],
              'provider': 'moonpay',
              'baseCurrencyAmount': mpTx['baseCurrencyAmount'],
              'baseCurrencyCode':
                  mpTx['baseCurrencyCode'] ?? mpTx['baseCurrency']?['code'],
              'moonpayStatus': mpTx['status'],
            },
          );
        }).toList();

        allTransactions.addAll(moonPayTransactions);
      }

      // Sort by timestamp (newest first)
      allTransactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      debugPrint('✅ Returning ${allTransactions.length} total transactions');
      return allTransactions;
    } catch (e, stackTrace) {
      debugPrint('❌ Error getting combined transaction history: $e');
      debugPrint('Stack trace: $stackTrace');
      // Convert Polygon transactions to Transaction objects
      final user = _auth.currentUser;
      if (user == null) return [];
      
      return _transactions.map((tx) {
        return app_transaction.Transaction(
          id: tx['hash'] as String? ?? 'polygon_${tx['hash']}',
          userId: user.uid,
          type: tx['type'] as String? ?? 'send',
          status: tx['status'] == 'success' ? 'completed' : 'pending',
          amount: (tx['value'] as num? ?? 0).toDouble(),
          assetCode: tx['asset'] as String? ?? 'MATIC',
          timestamp: tx['timestamp'] as DateTime? ?? DateTime.now(),
          description: _getPolygonTransactionDescription(tx),
          transactionHash: tx['hash'] as String?,
          senderAddress: tx['from'] as String?,
          recipientAddress: tx['to'] as String?,
          metadata: {
            'network': tx['network'],
            'gasUsed': tx['gasUsed'],
            'gasPrice': tx['gasPrice'],
            'confirmations': tx['confirmations'],
            'provider': 'polygon',
          },
        );
      }).toList();
    }
  }

  /// Get description for Polygon transaction
  String _getPolygonTransactionDescription(Map<String, dynamic> polyTx) {
    final type = polyTx['type'];
    final asset = polyTx['asset'];

    switch (type) {
      case 'receive':
        return 'Received $asset';
      case 'send':
        return 'Sent $asset';
      case 'contract_creation':
        return 'Contract Creation';
      case 'self':
        return 'Self Transfer ($asset)';
      default:
        return '$asset Transaction';
    }
  }

  /// Get MoonPay supported currencies
  Future<List<Map<String, dynamic>>> getMoonPaySupportedCurrencies() async {
    try {
      return await MoonPayService.getSupportedCurrencies();
    } catch (e) {
      return [];
    }
  }

  /// Get MoonPay exchange rates
  Future<Map<String, dynamic>?> getMoonPayExchangeRate({
    String baseCurrency = 'USD',
    String quoteCurrency = 'XLM',
  }) async {
    try {
      return await MoonPayService.getExchangeRate(
        baseCurrency: baseCurrency,
        quoteCurrency: quoteCurrency,
      );
    } catch (e) {
      return null;
    }
  }

  /// Clear current MoonPay transaction
  void clearMoonPayTransaction() {
    _currentMoonPayTransaction = null;
    notifyListeners();
  }

  /// Check if MoonPay is available in user's country
  Future<bool> isMoonPayAvailableInCountry(String countryCode) async {
    try {
      return await MoonPayService.isAvailableInCountry(countryCode);
    } catch (e) {
      return false;
    }
  }

  /// Manually setup wallet (public method for user-triggered setup)
  Future<Map<String, dynamic>> setupWalletManually() async {
    if (_address == null) {
      return {'success': false, 'message': 'No wallet found'};
    }

    _setLoading(true);
    _setError(null);

    try {
      await _autoSetupWalletIfNeeded(_address!);
      // Refresh balances after manual setup
      await loadBalances();
      _setLoading(false);
      return {'success': true, 'message': 'Wallet setup completed'};
    } catch (e) {
      _setLoading(false);
      _setError('Manual wallet setup failed: $e');
      return {'success': false, 'message': 'Setup failed: $e'};
    }
  }

  // ==================== PRIVATE METHODS ====================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  void _resetState() {
    _hasWallet = false;
    _address = null;
    _balances = {};
    _transactions = [];
    _isMonitoringActive = false;
    _currentPaymentStatus = null;
    _currentMoonPayTransaction = null;
    _moonPayTransactionHistory = [];
    _isMonitoringMoonPayTransactions = false;
    _hasSecureWallet = false;
    _secureWalletAddress = null;
    _polygonTokens = {};
    _isProcessingPolygonTransaction = false;

    _error = null;
    notifyListeners();
  }

  // ==================== LIFECYCLE ====================

  @override
  void dispose() {
    _mpesaService.dispose();
    super.dispose();
  }
}
