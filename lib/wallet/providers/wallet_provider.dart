import 'package:flutter/material.dart';
import '../../services/stellar_service.dart';
import '../../services/blockchain_transaction_service.dart';
import '../../models/transaction.dart' as app_transaction;

class WalletProvider extends ChangeNotifier {
  final StellarService _stellarService = StellarService();

  bool _hasWallet = false;
  bool _isLoading = false;
  String? _error;
  String? _publicKey;
  String _balance = '0';
  String _akofaBalance = '0';
  bool _hasAkofaTrustline = false;
  List<app_transaction.Transaction> _transactions = [];
  bool _isTransactionLoading = false;

  // Wallet creation state
  bool _isCreatingWallet = false;
  String? _walletCreationError;

  // Getters
  bool get hasWallet => _hasWallet;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get publicKey => _publicKey;
  String get balance => _balance;
  String get akofaBalance => _akofaBalance;
  bool get hasAkofaTrustline => _hasAkofaTrustline;
  List<app_transaction.Transaction> get transactions => _transactions;
  bool get isTransactionLoading => _isTransactionLoading;
  bool get isCreatingWallet => _isCreatingWallet;
  String? get walletCreationError => _walletCreationError;

  WalletProvider() {
    _init();
  }

  Future<void> _init() async {
    await checkWalletStatus();
    if (_hasWallet && _publicKey != null) {
      await loadTransactions();
      await _loadBalances();
    }
  }

  Future<void> checkWalletStatus() async {
    _setLoading(true);
    _setError(null);

    try {
      _hasWallet = await _stellarService.hasWallet();
      if (_hasWallet) {
        _publicKey = await _stellarService.getPublicKey();
        await _loadBalances();
      }
    } catch (e) {
      _setError('Failed to check wallet status: $e');
    }

    _setLoading(false);
  }

  Future<void> _loadBalances() async {
    if (_publicKey == null) return;

    try {
      _balance = await _stellarService.getBalance(_publicKey!);
      _hasAkofaTrustline = await _stellarService.hasAkofaTrustline(_publicKey!);
      if (_hasAkofaTrustline) {
        _akofaBalance = await _stellarService.getAkofaBalance(_publicKey!);
      }
    } catch (e) {
      _setError('Failed to load balances: $e');
    }
  }

  Future<bool> createWallet(BuildContext context) async {
    _isCreatingWallet = true;
    _walletCreationError = null;
    notifyListeners();

    try {
      final result = await _stellarService.createWalletAndStoreInFirestore();

      if (result['success'] == true) {
        _hasWallet = true;
        _publicKey = result['publicKey'];
        await _loadBalances();
        _isCreatingWallet = false;
        notifyListeners();
        return true;
      } else {
        _walletCreationError = result['message'];
        _isCreatingWallet = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _walletCreationError = 'Failed to create wallet: $e';
      _isCreatingWallet = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadTransactions() async {
    if (!_hasWallet) return;

    _isTransactionLoading = true;
    notifyListeners();

    try {
      _transactions = await BlockchainTransactionService.getUserTransactionsFromBlockchain();
      _isTransactionLoading = false;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load transactions: $e');
      _isTransactionLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshBalance() async {
    await checkWalletStatus();
  }

  Future<Map<String, dynamic>> sendAsset(String assetCode, String destinationAddress, String amount, {String? memo}) async {
    _setLoading(true);
    _setError(null);

    try {
      final result = await _stellarService.sendAsset(assetCode, destinationAddress, amount, memo: memo);

      if (result['success'] == true) {
        await refreshBalance();
        await loadTransactions();
      }

      _setLoading(false);
      return result;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to send $assetCode: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendXlm(String destinationAddress, String amount, {String? memo}) async {
    return sendAsset('XLM', destinationAddress, amount, memo: memo);
  }

  Future<Map<String, dynamic>> sendAkofa(String destinationAddress, String amount, {String? memo}) async {
    return sendAsset('AKOFA', destinationAddress, amount, memo: memo);
  }

  Future<bool> deleteWallet() async {
    _setLoading(true);
    _setError(null);

    try {
      // Note: This is a basic implementation. In a real app, you'd want to
      // securely delete the wallet credentials and handle any cleanup
      _hasWallet = false;
      _publicKey = null;
      _balance = '0';
      _akofaBalance = '0';
      _transactions = [];
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to delete wallet: $e');
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    _walletCreationError = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>> getWalletCredentials() async {
    try {
      final credentials = await _stellarService.getWalletCredentials();
      return credentials ?? {'error': 'No credentials found'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Debug function to test trustline creation step by step
  Future<Map<String, dynamic>> debugTrustlineCreation() async {
    try {
      final debugInfo = <String, dynamic>{};
      debugInfo['timestamp'] = DateTime.now().toIso8601String();

      // Step 1: Check wallet status
      debugInfo['hasWallet'] = _hasWallet;
      debugInfo['publicKey'] = _publicKey;

      if (!_hasWallet || _publicKey == null) {
        return {
          'success': false,
          'error': 'No wallet found',
          'debugInfo': debugInfo
        };
      }

      // Step 2: Check account existence
      try {
        final accountExists = await _stellarService.checkAccountExists(_publicKey!);
        debugInfo['accountExists'] = accountExists;

        if (!accountExists) {
          return {
            'success': false,
            'error': 'Account does not exist on Stellar network',
            'debugInfo': debugInfo
          };
        }
      } catch (e) {
        debugInfo['accountCheckError'] = e.toString();
      }

      // Step 3: Check current trustline status
      try {
        final hasTrustline = await _stellarService.hasAkofaTrustline(_publicKey!);
        debugInfo['hasTrustline'] = hasTrustline;

        if (hasTrustline) {
          return {
            'success': true,
            'message': 'Trustline already exists',
            'debugInfo': debugInfo
          };
        }
      } catch (e) {
        debugInfo['trustlineCheckError'] = e.toString();
      }

      // Step 4: Check XLM balance
      try {
        final balance = await _stellarService.getBalance(_publicKey!);
        debugInfo['xlmBalance'] = balance;
        final balanceValue = double.tryParse(balance) ?? 0.0;
        debugInfo['sufficientXlm'] = balanceValue >= 0.5;
      } catch (e) {
        debugInfo['balanceCheckError'] = e.toString();
      }

      // Step 5: Check credentials
      try {
        final credentials = await getWalletCredentials();
        debugInfo['hasCredentials'] = credentials['secretKey'] != null;
        debugInfo['credentialsError'] = credentials['error'];
      } catch (e) {
        debugInfo['credentialsError'] = e.toString();
      }

      return {
        'success': false,
        'error': 'Trustline creation ready to attempt',
        'debugInfo': debugInfo
      };

    } catch (e) {
      return {
        'success': false,
        'error': 'Debug failed: $e',
        'debugInfo': {'generalError': e.toString()}
      };
    }
  }

  Future<bool> ensureAkofaTrustline() async {
    try {
      final success = await _stellarService.ensureAkofaTrustline();
      if (success) {
        _hasAkofaTrustline = true;
        await _loadBalances();
      }
      return success;
    } catch (e) {
      _setError('Failed to ensure Akofa trustline: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> createAkofaTrustlineManually() async {
    _setLoading(true);
    _setError(null);

    try {
      // First check if wallet exists
      if (!_hasWallet || _publicKey == null) {
        _setLoading(false);
        return {
          'success': false,
          'message': 'No wallet found. Please create a wallet first.'
        };
      }


      // Check if trustline already exists
      final hasTrustline = await _stellarService.hasAkofaTrustline(_publicKey!);
      if (hasTrustline) {
        _hasAkofaTrustline = true;
        await _loadBalances();
        _setLoading(false);
        return {
          'success': true,
          'message': 'Akofa trustline already exists!'
        };
      }

      // Get credentials
      final credentials = await getWalletCredentials();
      if (credentials['secretKey'] == null) {
        _setLoading(false);
        return {
          'success': false,
          'message': 'Could not retrieve wallet secret key. Please check your authentication.'
        };
      }


      // Create the trustline
      final result = await _stellarService.createUserAkofaTrustline(credentials['secretKey']!);

      if (result) {
        _hasAkofaTrustline = true;
        await _loadBalances();
        _setLoading(false);
        return {
          'success': true,
          'message': 'Akofa trustline created successfully! You can now receive and hold AKOFA tokens.'
        };
      } else {
        _setLoading(false);
        return {
          'success': false,
          'message': 'Failed to create trustline. Please ensure your account has enough XLM (minimum 0.5 XLM) and try again.'
        };
      }
    } catch (e) {
      _setLoading(false);
      _setError('Failed to create Akofa trustline: $e');

      // Provide more helpful error messages
      String userFriendlyMessage = 'Error: $e';
      if (e.toString().contains('insufficient')) {
        userFriendlyMessage = 'Insufficient XLM balance. You need at least 0.5 XLM to create a trustline.';
      } else if (e.toString().contains('not_found')) {
        userFriendlyMessage = 'Account not found on network. Please ensure your account is funded.';
      } else if (e.toString().contains('bad_auth')) {
        userFriendlyMessage = 'Authentication failed. Please check your wallet credentials.';
      }

      return {
        'success': false,
        'message': userFriendlyMessage
      };
    }
  }
}
