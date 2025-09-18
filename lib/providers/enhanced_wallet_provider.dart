import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/enhanced_stellar_service.dart';
import '../services/enhanced_mpesa_service.dart';
import '../services/secure_wallet_service.dart';
import '../models/transaction.dart' as app_transaction;
import '../models/asset_config.dart';

class EnhancedWalletProvider extends ChangeNotifier {
  final EnhancedStellarService _stellarService = EnhancedStellarService();
  final EnhancedMpesaService _mpesaService = EnhancedMpesaService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State variables
  bool _isLoading = false;
  String? _error;
  bool _hasWallet = false;
  String? _publicKey;
  Map<String, dynamic> _balances = {};
  List<app_transaction.Transaction> _transactions = [];
  bool _isMonitoringActive = false;
  bool _hasAkofaTrustline = false;

  // M-Pesa related state
  bool _isProcessingPayment = false;
  Map<String, dynamic>? _currentPaymentStatus;

  // Secure wallet state
  bool _hasSecureWallet = false;
  bool _isBiometricAuthenticating = false;
  String? _secureWalletPublicKey;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasWallet => _hasWallet;
  String? get publicKey => _publicKey;
  Map<String, dynamic> get balances => _balances;
  List<app_transaction.Transaction> get transactions => _transactions;
  bool get isMonitoringActive => _isMonitoringActive;
  bool get isProcessingPayment => _isProcessingPayment;
  Map<String, dynamic>? get currentPaymentStatus => _currentPaymentStatus;

  // Secure wallet getters
  bool get hasSecureWallet => _hasSecureWallet;
  bool get isBiometricAuthenticating => _isBiometricAuthenticating;
  String? get secureWalletPublicKey => _secureWalletPublicKey;

  // Computed getters
  String get xlmBalance => _balances['xlm'] ?? '0';
  String get akofaBalance => _balances['akofa'] ?? '0';
  bool get hasAkofaTrustline => _hasAkofaTrustline;
  int get transactionCount => _transactions.length;
  List<app_transaction.Transaction> get recentTransactions =>
      _transactions.take(10).toList();

  EnhancedWalletProvider() {
    _initialize();
  }

  void _initialize() {
    // Set up real-time callbacks
    _stellarService.setTransactionCallback(_onTransactionsUpdated);
    _stellarService.setBalanceCallback(_onBalancesUpdated);
    _stellarService.setNewTransactionCallback(_onNewTransaction);

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

  // ==================== WALLET MANAGEMENT ====================

  /// Check wallet status and initialize if needed
  Future<void> checkWalletStatus() async {
    _setLoading(true);
    _setError(null);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _setLoading(false);
        return;
      }

      // Check for secure wallet first
      _hasSecureWallet = await SecureWalletService.hasSecureWallet(user.uid);
      if (_hasSecureWallet) {
        _secureWalletPublicKey = await SecureWalletService.getWalletPublicKey(
          user.uid,
        );
        _publicKey = _secureWalletPublicKey;
        _hasWallet = true;
      } else {
        // Fall back to regular wallet
        _hasWallet = await _stellarService.hasWallet();
        if (_hasWallet) {
          _publicKey = await _stellarService.getPublicKey();
        }
      }

      if (_hasWallet) {
        // Load initial data
        await Future.wait([loadBalances(), loadTransactions()]);

        // Automatically setup wallet (fund with XLM and create AKOFA trustline if needed)
        if (_publicKey != null) {
          await _autoSetupWalletIfNeeded(_publicKey!);
        }

        // Start real-time monitoring
        if (!_isMonitoringActive) {
          _stellarService.startRealTimeMonitoring();
          _isMonitoringActive = true;
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

  /// Create a secure wallet with biometric protection
  Future<Map<String, dynamic>> createSecureWallet({
    required BuildContext context,
    required String password,
    String? recoveryPhrase,
    bool enableBiometrics = false,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final result = await SecureWalletService.createSecureWallet(
        userId: user.uid,
        password: password,
        recoveryPhrase: recoveryPhrase,
        enableBiometrics: enableBiometrics,
      );

      if (result['success'] == true) {
        // Update local state
        _hasSecureWallet = true;
        _secureWalletPublicKey = result['publicKey'];
        _publicKey = _secureWalletPublicKey;
        _hasWallet = true;

        // Load wallet data (this will also check trustline status)
        await Future.wait([loadBalances(), loadTransactions()]);

        // Setup wallet automatically
        if (_publicKey != null) {
          await _autoSetupWalletIfNeeded(_publicKey!);
        }

        // Start monitoring
        if (!_isMonitoringActive) {
          _stellarService.startRealTimeMonitoring();
          _isMonitoringActive = true;
        }
      }

      _setLoading(false);
      return result;
    } catch (e) {
      _setError('Failed to create secure wallet: $e');
      _setLoading(false);
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Check if user has a secure wallet
  Future<bool> checkSecureWalletStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      _hasSecureWallet = await SecureWalletService.hasSecureWallet(user.uid);
      if (_hasSecureWallet) {
        _secureWalletPublicKey = await SecureWalletService.getWalletPublicKey(
          user.uid,
        );
      }
      notifyListeners();
      return _hasSecureWallet;
    } catch (e) {
      return false;
    }
  }

  /// Load wallet balances
  Future<void> loadBalances() async {
    if (_publicKey == null) return;

    try {
      _balances = await _stellarService.getWalletBalances(_publicKey!);
      // Also check trustline status
      _hasAkofaTrustline = await _stellarService.hasAkofaTrustline(_publicKey!);
      notifyListeners();
    } catch (e) {}
  }

  /// Load transactions
  Future<void> loadTransactions({bool forceRefresh = false}) async {
    try {
      _transactions = await _stellarService.getUserTransactionsFromBlockchain(
        forceRefresh: forceRefresh,
      );
      notifyListeners();
    } catch (e) {}
  }

  /// Refresh all wallet data
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

  /// Automatically setup wallet if needed (fund with XLM and create AKOFA trustline)
  Future<void> _autoSetupWalletIfNeeded(String publicKey) async {
    try {
      // Check if account has sufficient XLM
      final hasSufficientXlm = await _stellarService.hasSufficientXlm(
        publicKey,
      );
      final hasAkofaTrustline = await _stellarService.hasAkofaTrustline(
        publicKey,
      );

      if (!hasSufficientXlm || !hasAkofaTrustline) {
        print(
          '🔧 Wallet needs setup - XLM: $hasSufficientXlm, Trustline: $hasAkofaTrustline',
        );

        // Show loading message
        _setError('Setting up your wallet automatically...');

        // Perform automatic setup
        final setupResult = await _stellarService.autoSetupWallet(publicKey);

        if (setupResult['success'] == true) {
          // Clear the loading message
          _setError(null);

          // Refresh balances and trustline status after setup
          await loadBalances();

          // Show success message
          String successMessage = 'Wallet setup completed!';
          if (setupResult['funded'] == true &&
              setupResult['trustlineCreated'] == true) {
            successMessage =
                'Wallet funded with XLM and AKOFA trustline created!';
          } else if (setupResult['funded'] == true) {
            successMessage = 'Wallet funded with test XLM!';
          } else if (setupResult['trustlineCreated'] == true) {
            successMessage = 'AKOFA trustline created!';
          }

          // Set success message temporarily
          _setError(successMessage);

          // Clear success message after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (_error == successMessage) {
              _setError(null);
            }
          });
        } else {
          _setError('Wallet setup failed: ${setupResult['message']}');
        }
      }
    } catch (e) {
      _setError('Failed to setup wallet automatically: $e');
    }
  }

  // ==================== TRANSACTION OPERATIONS ====================

  /// Send AKOFA tokens
  Future<Map<String, dynamic>> sendAkofaTokens({
    required String recipientAddress,
    required double amount,
    String? memo,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final result = await _stellarService.sendAkofaTokens(
        recipientAddress: recipientAddress,
        amount: amount,
        memo: memo,
      );

      if (result['success'] == true) {
        // Refresh data after successful transaction
        await Future.wait([
          loadBalances(),
          loadTransactions(forceRefresh: true),
        ]);
      }

      _setLoading(false);
      return result;
    } catch (e) {
      _setError('Failed to send AKOFA tokens: $e');
      _setLoading(false);
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Send XLM
  Future<Map<String, dynamic>> sendXLM({
    required String recipientAddress,
    required double amount,
    String? memo,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final result = await _stellarService.sendXlm(
        recipientAddress,
        amount.toString(),
        memo: memo,
      );

      if (result['success'] == true) {
        // Refresh data after successful transaction
        await Future.wait([
          loadBalances(),
          loadTransactions(forceRefresh: true),
        ]);
      }

      _setLoading(false);
      return result;
    } catch (e) {
      _setError('Failed to send XLM: $e');
      _setLoading(false);
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Send AKOFA tokens with biometric authentication (secure wallet)
  Future<Map<String, dynamic>> sendAkofaWithBiometrics({
    required String recipientAddress,
    required double amount,
    String? memo,
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

      final result = await SecureWalletService.signTransactionWithBiometrics(
        userId: user.uid,
        recipientAddress: recipientAddress,
        amount: amount,
        assetCode: 'AKOFA',
        memo: memo,
        password: '', // This will be handled by the UI to prompt for password
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

  /// Send XLM with biometric authentication (secure wallet)
  Future<Map<String, dynamic>> sendXLMWithBiometrics({
    required String recipientAddress,
    required double amount,
    String? memo,
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
        password: '', // This will be handled by the UI to prompt for password
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

  /// Get all supported assets
  List<AssetConfig> get supportedAssets => _stellarService.getSupportedAssets();

  /// Get stablecoins only
  List<AssetConfig> get stablecoins => _stellarService.getStablecoins();

  /// Create trustlines for multiple assets
  Future<Map<String, dynamic>> createMultipleTrustlines(
    List<AssetConfig> assets,
  ) async {
    if (_publicKey == null) {
      return {'success': false, 'message': 'No wallet found'};
    }

    _setLoading(true);
    _setError(null);

    try {
      final result = await _stellarService.createMultipleTrustlines(
        _publicKey!,
        assets,
      );

      if (result['success'] == true) {
        // Refresh balances after creating trustlines
        await loadBalances();
      }

      _setLoading(false);
      return result;
    } catch (e) {
      _setError('Failed to create trustlines: $e');
      _setLoading(false);
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Send any asset (generic method)
  Future<Map<String, dynamic>> sendAsset({
    required String recipientAddress,
    required AssetConfig asset,
    required double amount,
    String? memo,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final result = await _stellarService.sendAsset(
        recipientAddress: recipientAddress,
        asset: asset,
        amount: amount,
        memo: memo,
      );

      if (result['success'] == true) {
        // Refresh data after successful transaction
        await Future.wait([
          loadBalances(),
          loadTransactions(forceRefresh: true),
        ]);
      }

      _setLoading(false);
      return result;
    } catch (e) {
      _setError('Failed to send ${asset.symbol}: $e');
      _setLoading(false);
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Send stablecoin with biometric authentication
  Future<Map<String, dynamic>> sendStablecoinWithBiometrics({
    required String recipientAddress,
    required AssetConfig stablecoin,
    required double amount,
    String? memo,
  }) async {
    if (!stablecoin.isStablecoin) {
      return {'success': false, 'error': 'Asset is not a stablecoin'};
    }

    if (!_hasSecureWallet) {
      return await sendAsset(
        recipientAddress: recipientAddress,
        asset: stablecoin,
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

  /// Check if user has trustline for asset
  Future<bool> hasTrustlineForAsset(AssetConfig asset) async {
    if (_publicKey == null) return false;
    return await _stellarService.hasTrustlineForAsset(_publicKey!, asset);
  }

  /// Setup wallet with multiple assets (XLM funding + trustlines)
  Future<Map<String, dynamic>> setupWalletWithMultipleAssets(
    List<AssetConfig> assets,
  ) async {
    if (_publicKey == null) {
      return {'success': false, 'message': 'No wallet found'};
    }

    _setLoading(true);
    _setError(null);

    try {
      // First setup basic wallet (XLM funding + AKOFA trustline)
      await _autoSetupWalletIfNeeded(_publicKey!);

      // Then create trustlines for additional assets
      final trustlineResult = await createMultipleTrustlines(assets);

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

  /// Get purchase statistics
  Future<Map<String, dynamic>> getPurchaseStats() async {
    try {
      return await _mpesaService.getPurchaseStats();
    } catch (e) {
      return {};
    }
  }

  // ==================== REAL-TIME CALLBACKS ====================

  /// Called when transactions are updated
  void _onTransactionsUpdated(List<app_transaction.Transaction> transactions) {
    _transactions = transactions;
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
  List<app_transaction.Transaction> filterTransactions(String type) {
    if (type == 'all') return _transactions;
    return _transactions.where((tx) => tx.type == type).toList();
  }

  /// Search transactions
  List<app_transaction.Transaction> searchTransactions(String query) {
    if (query.isEmpty) return _transactions;

    final lowercaseQuery = query.toLowerCase();
    return _transactions.where((tx) {
      return (tx.description?.toLowerCase().contains(lowercaseQuery) ??
              false) ||
          tx.assetCode.toLowerCase().contains(lowercaseQuery) ||
          (tx.memo?.toLowerCase().contains(lowercaseQuery) ?? false) ||
          (tx.senderAkofaTag?.toLowerCase().contains(lowercaseQuery) ??
              false) ||
          (tx.recipientAkofaTag?.toLowerCase().contains(lowercaseQuery) ??
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
      switch (tx.type) {
        case 'send':
          sentCount++;
          totalSent += tx.amount;
          break;
        case 'receive':
          receivedCount++;
          totalReceived += tx.amount;
          break;
        case 'mining':
          miningCount++;
          totalMined += tx.amount;
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

  /// Manually setup wallet (public method for user-triggered setup)
  Future<Map<String, dynamic>> setupWalletManually() async {
    if (_publicKey == null) {
      return {'success': false, 'message': 'No wallet found'};
    }

    _setLoading(true);
    _setError(null);

    try {
      await _autoSetupWalletIfNeeded(_publicKey!);
      // Refresh balances and trustline status after manual setup
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
    _publicKey = null;
    _balances = {};
    _transactions = [];
    _isMonitoringActive = false;
    _currentPaymentStatus = null;
    _hasAkofaTrustline = false;
    _error = null;
    notifyListeners();
  }

  // ==================== LIFECYCLE ====================

  @override
  void dispose() {
    _stellarService.dispose();
    _mpesaService.dispose();
    super.dispose();
  }
}
