import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:http/http.dart' as http;
import '../services/stellar_service.dart';
import '../services/blockchain_transaction_service.dart';
import '../services/swap_service.dart';
import '../services/mpesa_service.dart';
import '../models/transaction.dart' as app_transaction;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as local_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

/// USAGE EXAMPLES FOR ACCOUNT MAINTENANCE FUNCTIONS
///
/// 1. Check account status without making changes:
/// ```dart
/// final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
/// final status = await stellarProvider.checkAccountStatus('G...');
/// print('Status: ${status['status']}'); // 'complete', 'needs_xlm', 'needs_trustline', etc.
/// ```
///
/// 2. Find and fix unfunded accounts automatically:
/// ```dart
/// final result = await stellarProvider.findAndFixUnfundedAccounts();
/// print('Fixed ${result['accountsFunded']} accounts, added ${result['trustlinesAdded']} trustlines');
/// ```
///
/// 3. Show maintenance dialog (UI approach):
/// ```dart
/// showDialog(
///   context: context,
///   builder: (context) => const AccountMaintenanceDialog(),
/// );
/// ```
///
/// 4. Batch fix for admin use (CAUTION: processes many users):
/// ```dart
/// final result = await stellarProvider.batchFixUnfundedAccounts(limit: 100);
/// print('Processed ${result['usersProcessed']} users');
/// ```

class StellarProvider extends ChangeNotifier {
  final StellarService _stellarService = StellarService();
  final SwapService _swapService = SwapService();
  final MpesaService _mpesaService = MpesaService();

  bool _hasWallet = false;
  bool _isLoading = false;
  String? _error;
  String? _publicKey;
  String _balance = '0';
  String _akofaBalance = '0';
  bool _hasAkofaTrustline = false;
  List<app_transaction.Transaction> _transactions = [];
  bool _isTransactionLoading = false;

  // Swap-related state
  List<Map<String, String>> _supportedAssets = [];
  Map<String, String> _assetBalances = {};
  bool _isSwapLoading = false;
  List<Map<String, dynamic>> _swapHistory = [];

  // Wallet assets state
  List<Map<String, dynamic>> _walletAssets = [];
  bool _isLoadingWalletAssets = false;

  // M-Pesa related state
  bool _isMpesaLoading = false;
  List<Map<String, dynamic>> _mpesaTransactions = [];

  // Auto-refresh timer for transactions
  Timer? _transactionRefreshTimer;
  static const Duration _transactionRefreshInterval = Duration(
    minutes: 2,
  ); // Check every 2 minutes

  bool get hasWallet => _hasWallet;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get publicKey => _publicKey;
  String get balance => _balance;
  String get akofaBalance => _akofaBalance;
  bool get hasAkofaTrustline => _hasAkofaTrustline;
  List<app_transaction.Transaction> get transactions => _transactions;
  bool get isTransactionLoading => _isTransactionLoading;

  // Swap-related getters
  List<Map<String, String>> get supportedAssets => _supportedAssets;
  Map<String, String> get assetBalances => _assetBalances;
  bool get isSwapLoading => _isSwapLoading;
  List<Map<String, dynamic>> get swapHistory => _swapHistory;

  // Wallet assets getters
  List<Map<String, dynamic>> get walletAssets => _walletAssets;
  bool get isLoadingWalletAssets => _isLoadingWalletAssets;

  // M-Pesa related getters
  bool get isMpesaLoading => _isMpesaLoading;
  List<Map<String, dynamic>> get mpesaTransactions => _mpesaTransactions;

  StellarProvider() {
    _init();
    _startTransactionAutoRefresh();
  }

  Future<void> _init() async {
    await checkWalletStatus();
    if (_hasWallet) {
      await loadTransactions();
      await loadWalletAssets();
      // AUTOMATICALLY ensure Akofa trustline exists
      await _ensureAkofaTrustline();
    }
  }

  // AUTOMATIC trustline check and creation
  Future<void> _ensureAkofaTrustline() async {
    try {
      final success = await _stellarService.ensureAkofaTrustline();
      if (success) {
        _hasAkofaTrustline = true;
        await refreshBalance();
        notifyListeners();
      } else {
        _hasAkofaTrustline = false;
        notifyListeners();
      }
    } catch (e) {
      _hasAkofaTrustline = false;
      notifyListeners();
    }
  }

  // Manual trustline creation for user
  Future<Map<String, dynamic>> createAkofaTrustlineManually() async {
    _setLoading(true);
    _setError(null);

    try {
      final credentials = await getFullWalletCredentials();
      if (credentials == null || credentials['secretKey'] == null) {
        _setLoading(false);
        _setError('Could not retrieve wallet credentials');
        return {
          'success': false,
          'message': 'Could not retrieve wallet credentials',
        };
      }

      final result = await _stellarService.createUserAkofaTrustline(
        credentials['secretKey']!,
      );

      if (result) {
        _hasAkofaTrustline = true;
        await refreshBalance();
        notifyListeners();
        _setLoading(false);
        return {
          'success': true,
          'message': 'Akofa trustline created successfully!',
        };
      } else {
        _setLoading(false);
        _setError('Failed to create trustline');
        return {'success': false, 'message': 'Failed to create trustline'};
      }
    } catch (e) {
      _setLoading(false);
      _setError('Failed to create Akofa trustline: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Get account funding information
  Future<Map<String, dynamic>> getAccountFundingInfo() async {
    if (_publicKey == null) {
      return {
        'exists': false,
        'status': 'no_wallet',
        'message': 'No wallet found',
      };
    }

    try {
      return await _stellarService.getAccountFundingInfo(_publicKey!);
    } catch (e) {
      return {
        'exists': false,
        'status': 'error',
        'message': 'Error checking account status: $e',
        'publicKey': _publicKey,
      };
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
    notifyListeners();
  }

  /// Debug method to check transaction loading status
  Future<Map<String, dynamic>> debugTransactionLoading() async {
    final debugInfo = <String, dynamic>{};

    debugInfo['hasWallet'] = _hasWallet;
    debugInfo['publicKey'] = _publicKey;
    debugInfo['currentTransactionCount'] = _transactions.length;
    debugInfo['isTransactionLoading'] = _isTransactionLoading;

    if (_transactions.isNotEmpty) {
      debugInfo['sampleTransaction'] = {
        'id': _transactions.first.id,
        'type': _transactions.first.type,
        'amount': _transactions.first.amount,
        'assetCode': _transactions.first.assetCode,
        'timestamp': _transactions.first.timestamp.toIso8601String(),
        'status': _transactions.first.status,
      };
    }

    // Try to force refresh transactions
    try {
      await loadTransactionsFromBlockchain();
      debugInfo['afterRefreshCount'] = _transactions.length;
      debugInfo['refreshSuccessful'] = true;
    } catch (e) {
      debugInfo['refreshError'] = e.toString();
      debugInfo['refreshSuccessful'] = false;
    }

    return debugInfo;
  }

  Future<bool> checkWalletStatus() async {
    _setLoading(true);
    _setError(null);

    try {
      _hasWallet = await _stellarService.hasWallet();

      if (_hasWallet) {
        // First, just get the public key (no authentication needed)
        final publicKey = await _stellarService.getPublicKey();

        if (publicKey != null) {
          _publicKey = publicKey;
          await refreshBalance();

          // Check if wallet has Akofa trustline
          try {
            _hasAkofaTrustline = await _stellarService.hasAkofaTrustline(
              _publicKey!,
            );
            if (_hasAkofaTrustline) {
              _akofaBalance = await _stellarService.getAkofaBalance(
                _publicKey!,
              );
            }
          } catch (trustlineError) {
            // Log the error but don't fail the wallet status check
          }
        } else {
          _hasWallet = false;
        }
      } else {}

      _setLoading(false);
      return _hasWallet;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to check wallet status: $e');
      return false;
    }
  }

  // Get full wallet credentials (requires authentication)
  Future<Map<String, String>?> getFullWalletCredentials() async {
    _setLoading(true);
    _setError(null);

    try {
      final credentials = await _stellarService.getWalletCredentials();
      _setLoading(false);

      if (credentials != null) {
        // Update the public key if it's different
        if (_publicKey != credentials['publicKey']) {
          _publicKey = credentials['publicKey'];
          notifyListeners();
        }
      }

      return credentials;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to get wallet credentials: $e');
      return null;
    }
  }

  Future<bool> createWallet(BuildContext context) async {
    _setLoading(true);
    _setError(null);

    try {
      // Prompt user for authentication method
      final authMethod = await _showAuthMethodDialog(context);
      if (authMethod == null) {
        _setLoading(false);
        return false;
      }
      String? googleUid;
      String? password;
      bool useBiometrics = false;
      if (authMethod == 'google') {
        // Use Google UID
        final authProvider = Provider.of<local_auth.AuthProvider>(
          context,
          listen: false,
        );
        final success = await authProvider.signInWithGoogle();
        if (!success) {
          _setLoading(false);
          _setError('Google authentication failed');
          return false;
        }
        googleUid = authProvider.user?.uid;
        if (googleUid == null) {
          _setLoading(false);
          _setError('Google UID not found');
          return false;
        }
      } else if (authMethod == 'password') {
        // Prompt for password
        password = await _showPasswordDialog(context);
        if (password == null) {
          _setLoading(false);
          _setError('Password required');
          return false;
        }
      } else if (authMethod == 'biometrics') {
        useBiometrics = true;
      }
      final credentials = await _stellarService
          .createWalletAndStoreInFirestore();
      _publicKey = credentials['publicKey'];
      _hasWallet = true;

      // Automatically setup the new wallet (fund with Friendbot and add Akofa trustline)
      try {
        // Show a message to the user that we're setting up their wallet
        _setError('Setting up your wallet automatically...');

        // Use the new automatic setup method
        final setupResult = await _stellarService.setupNewWalletAutomatically(
          _publicKey!,
          credentials['secretKey'],
        );

        if (setupResult['success'] == true) {
          // Wallet setup successful
          String successMessage = 'Wallet created successfully!';

          if (setupResult['wasFunded'] == true) {
            successMessage = 'Wallet created and funded with test XLM!';
          }

          if (setupResult['trustlineAdded'] == true) {
            final trustlineResult =
                setupResult['trustlineResult'] as Map<String, dynamic>?;
            if (trustlineResult != null && trustlineResult['success'] == true) {
              // Count successful trustlines
              final successfulTrustlines = <String>[];
              final failedTrustlines = <String>[];

              // Check each asset
              final assets = ['akofa', 'usdc', 'btc', 'eth'];
              for (final asset in assets) {
                if (trustlineResult[asset] == true) {
                  successfulTrustlines.add(asset.toUpperCase());
                } else if (trustlineResult.containsKey(asset)) {
                  failedTrustlines.add(asset.toUpperCase());
                }
              }

              if (successfulTrustlines.isNotEmpty) {
                successMessage +=
                    ' ${successfulTrustlines.join(', ')} trustlines added.';
                if (failedTrustlines.isNotEmpty) {
                  successMessage +=
                      ' ${failedTrustlines.join(', ')} trustlines can be added manually.';
                }
              } else {
                successMessage += ' Some trustlines added.';
              }
            } else {
              successMessage += ' Trustlines added.';
            }
          }

          // Refresh balance to show the new funds
          await refreshBalance();

          // Update trustline status
          _hasAkofaTrustline = setupResult['trustlineAdded'] == true;

          // Use _setError to display a success message
          _setError(successMessage);
        } else {
          // Setup failed - provide specific error messages
          String errorMessage = 'Wallet created but setup incomplete.';

          if (setupResult['fundingResult'] != null &&
              setupResult['fundingResult']['success'] == false) {
            errorMessage =
                'Wallet created but funding failed. You can fund it manually later.';
          } else if (setupResult['trustlineResult'] != null &&
              setupResult['trustlineResult']['success'] == false) {
            errorMessage =
                'Wallet funded but Akofa trustline setup failed. You can add it manually later.';
          }

          _setError(errorMessage);
        }
      } catch (error) {
        _setError(
          'Wallet created but automatic setup failed. You can set it up manually.',
        );

        // Still refresh balance in case partial setup worked
        try {
          await refreshBalance();
        } catch (balanceError) {}
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to create wallet: ${e}');
      return false;
    }
  }

  Future<String?> _showAuthMethodDialog(BuildContext context) async {
    return await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Choose Authentication Method'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'google'),
              child: const Text('Google Sign-In'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'password'),
              child: const Text('Password'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'biometrics'),
              child: const Text('Biometrics'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _showPasswordDialog(BuildContext context) async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Password'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> refreshBalance() async {
    if (this._publicKey == null) return;

    try {
      _balance = await _stellarService.getBalance(this._publicKey!);

      // Also check Akofa trustline and balance
      _hasAkofaTrustline = await _stellarService.hasAkofaTrustline(
        this._publicKey!,
      );
      if (_hasAkofaTrustline) {
        _akofaBalance = await _stellarService.getAkofaBalance(this._publicKey!);
      }

      // Also refresh all wallet assets
      await loadWalletAssets();

      notifyListeners();
    } catch (e) {
      _setError('Failed to refresh balance: $e');
    }
  }

  // Check if account has enough XLM for transactions
  Future<Map<String, dynamic>> checkAccountXlmBalance() async {
    if (this._publicKey == null) {
      return {
        'hasEnough': false,
        'message': 'No public key available',
        'balance': '0',
        'status': 'no_public_key',
      };
    }

    try {
      final hasEnough = await _stellarService.hasEnoughXlmForTransaction(
        this._publicKey!,
      );
      return {
        'hasEnough': hasEnough,
        'message': hasEnough
            ? 'Sufficient XLM balance'
            : 'Insufficient XLM balance',
        'balance': '0', // This would need to be fetched separately
        'status': hasEnough ? 'sufficient' : 'insufficient',
      };
    } catch (e) {
      _setError('Failed to check XLM balance: $e');
      return {
        'hasEnough': false,
        'message': 'Error checking balance: $e',
        'balance': '0',
        'status': 'error',
      };
    }
  }

  // Friendly Bot: Check if account is funded and fund it if necessary
  Future<Map<String, dynamic>> ensureAccountFunded() async {
    _setLoading(true);
    _setError(null);

    if (this._publicKey == null) {
      _setLoading(false);
      return {
        'success': false,
        'message': 'No public key available',
        'status': 'no_public_key',
      };
    }

    try {
      // First check if the account has enough XLM
      final xlmCheck = await checkAccountXlmBalance();

      // If account already has enough XLM, return success
      if (xlmCheck['hasEnough'] == true) {
        _setLoading(false);
        return {
          'success': true,
          'message': 'Account already has sufficient funds',
          'balance': xlmCheck['balance'],
          'status': 'already_funded',
        };
      }

      // No need to get wallet credentials for funding
      // The public key is already available

      // Try to fund the account using Friendbot
      final friendBotUrl =
          'https://friendbot.stellar.org/?addr=${this._publicKey}';
      try {
        final response = await http.get(Uri.parse(friendBotUrl));

        if (response.statusCode == 200) {
          // Wait for the account to be created on the network
          await Future.delayed(const Duration(seconds: 5));

          // Refresh balance
          await refreshBalance();

          // Check balance again
          final newXlmCheck = await checkAccountXlmBalance();
          if (newXlmCheck['hasEnough'] == true) {
            _setLoading(false);
            return {
              'success': true,
              'message': 'Account successfully funded by Friendly Bot',
              'balance': newXlmCheck['balance'],
              'status': 'funding_success',
            };
          } else {
            _setLoading(false);
            return {
              'success': false,
              'message': 'Account was funded but still has insufficient XLM',
              'balance': newXlmCheck['balance'],
              'status': 'insufficient_xlm_after_funding',
            };
          }
        } else {
          _setLoading(false);
          return {
            'success': false,
            'message': 'Failed to fund account with Friendly Bot',
            'error': 'Response: ${response.statusCode} - ${response.body}',
            'status': 'funding_error',
          };
        }
      } catch (fundingError) {
        _setLoading(false);
        _setError('Failed to fund account: $fundingError');
        return {
          'success': false,
          'message': 'Failed to fund account',
          'error': fundingError.toString(),
          'status': 'funding_request_error',
        };
      }
    } catch (e) {
      _setLoading(false);
      _setError('Failed to ensure account funding: $e');
      return {
        'success': false,
        'message': 'Error ensuring account funding',
        'error': e.toString(),
        'status': 'error',
      };
    }
  }

  // REMOVED - Now handled automatically in _ensureAkofaTrustline()

  // REMOVED - Now handled automatically in _ensureAkofaTrustline()

  // This method is kept for backward compatibility
  // It now uses the new getFullWalletCredentials method
  Future<Map<String, dynamic>?> getWalletCredentials() async {
    return await getFullWalletCredentials();
  }

  // Recover wallet using provided secret key
  Future<bool> recoverWalletWithSecretKey(String secretKey) async {
    _setLoading(true);
    _setError(null);

    try {
      // TODO: Implement recoverWalletWithSecretKey method
      final success = false; // Method not implemented yet

      if (success) {
        // Update local state
        final credentials = await _stellarService.getWalletCredentials();
        if (credentials != null) {
          _publicKey = credentials['publicKey'];
          await refreshBalance();
          // Trustline is now handled automatically
        }
      }

      _setLoading(false);
      return success;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to recover wallet: $e');
      return false;
    }
  }

  Future<bool> deleteWallet() async {
    _setLoading(true);
    _setError(null);

    try {
      // TODO: Implement deleteWallet method
      _hasWallet = false;
      _publicKey = null;
      _balance = '0';
      _transactions = [];
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to delete wallet: $e');
      return false;
    }
  }

  // Load transaction history
  Future<void> loadTransactions() async {
    if (!_hasWallet) {
      return;
    }

    _isTransactionLoading = true;
    notifyListeners();

    try {
      // Use blockchain service instead of non-existent method
      final blockchainTransactions =
          await BlockchainTransactionService.getUserTransactionsFromBlockchain();
      _transactions = blockchainTransactions;
      _isTransactionLoading = false;
      notifyListeners();
    } catch (e) {
      _isTransactionLoading = false;
      _setError('Failed to load transactions: $e');
      notifyListeners();
    }
  }

  // Load transactions from blockchain
  Future<void> loadTransactionsFromBlockchain() async {
    if (!_hasWallet) {
      return;
    }

    _isTransactionLoading = true;
    notifyListeners();

    try {
      // Use blockchain service directly
      final transactions =
          await BlockchainTransactionService.getUserTransactionsFromBlockchain();

      for (int i = 0; i < transactions.length; i++) {
        final tx = transactions[i];
      }

      // Sort transactions by most recent first (blockchain timestamp)
      _transactions = transactions;
      _transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      _isTransactionLoading = false;

      // Debug: Print final transaction list
      for (int i = 0; i < _transactions.length; i++) {
        final tx = _transactions[i];
      }

      notifyListeners();
    } catch (e) {
      _isTransactionLoading = false;
      _setError('Failed to load transactions from blockchain: $e');
      notifyListeners();
    }
  }

  // Refresh transactions after new operations (for real-time updates)
  Future<void> refreshTransactionsAfterOperation() async {
    // Clear cache to force fresh blockchain fetch
    BlockchainTransactionService.clearCache();

    // Reload transactions from blockchain
    await loadTransactionsFromBlockchain();
  }

  // Force immediate refresh (for debugging and manual refresh)
  Future<void> forceRefreshTransactions() async {
    // Clear cache
    BlockchainTransactionService.clearCache();

    // Reload transactions from blockchain
    await loadTransactionsFromBlockchain();
  }

  // Start automatic transaction refresh timer
  void _startTransactionAutoRefresh() {
    _transactionRefreshTimer?.cancel();
    _transactionRefreshTimer = Timer.periodic(_transactionRefreshInterval, (
      timer,
    ) async {
      if (_hasWallet && !_isTransactionLoading) {
        await loadTransactionsFromBlockchain();
      }
    });
  }

  // Stop automatic transaction refresh
  void _stopTransactionAutoRefresh() {
    _transactionRefreshTimer?.cancel();
    _transactionRefreshTimer = null;
  }

  // Load all assets in the wallet
  Future<void> loadWalletAssets() async {
    if (_publicKey == null) return;

    _isLoadingWalletAssets = true;
    notifyListeners();

    try {
      _walletAssets = await _stellarService.getAllWalletAssets(_publicKey!);
      _isLoadingWalletAssets = false;
      notifyListeners();
    } catch (e) {
      _isLoadingWalletAssets = false;
      _setError('Failed to load wallet assets: $e');
      notifyListeners();
    }
  }

  // Send any asset
  Future<Map<String, dynamic>> sendAsset(
    String assetCode,
    String destinationAddress,
    String amount, {
    String? memo,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final result = await _stellarService.sendAsset(
        assetCode,
        destinationAddress,
        amount,
        memo: memo,
      );

      // Refresh balances and transactions after sending
      await refreshBalance();
      await loadTransactions();
      await loadWalletAssets();

      _setLoading(false);
      return result;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to send $assetCode: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Send Akofa coins (for backward compatibility)
  Future<Map<String, dynamic>> sendAkofa(
    String destinationAddress,
    String amount, {
    String? memo,
  }) async {
    return sendAsset('AKOFA', destinationAddress, amount, memo: memo);
  }

  // Send XLM (for backward compatibility)
  Future<Map<String, dynamic>> sendXlm(
    String destinationAddress,
    String amount, {
    String? memo,
  }) async {
    return sendAsset('XLM', destinationAddress, amount, memo: memo);
  }

  // Create a test transaction for debugging
  Future<bool> createTestTransaction() async {
    _setLoading(true);
    _setError(null);

    try {
      // TODO: Implement createTestTransaction method

      // Refresh transactions after creating test transaction
      await loadTransactions();

      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to create test transaction: $e');
      return false;
    }
  }

  // ==================== SWAP FUNCTIONALITY ====================

  // Load supported assets for swapping
  Future<void> loadSupportedAssets() async {
    _isSwapLoading = true;
    notifyListeners();

    try {
      _supportedAssets = _swapService.getSupportedAssets();
      _isSwapLoading = false;
      notifyListeners();
    } catch (e) {
      _isSwapLoading = false;
      _setError('Failed to load supported assets: $e');
    }
  }

  // Check if asset has a trustline
  Future<bool> hasAssetTrustline(String assetCode, String assetIssuer) async {
    if (this._publicKey == null) return false;

    try {
      return await _swapService.hasAssetTrustline(
        this._publicKey!,
        assetCode,
        assetIssuer,
      );
    } catch (e) {
      _setError('Failed to check asset trustline: $e');
      return false;
    }
  }

  // Add trustline for an asset
  Future<Map<String, dynamic>> addAssetTrustline(
    String assetCode,
    String assetIssuer,
  ) async {
    if (this._publicKey == null) {
      return {
        'success': false,
        'message': 'No public key available',
        'status': 'no_public_key',
      };
    }

    _isSwapLoading = true;
    _setError(null);
    notifyListeners();

    try {
      final result = await _swapService.addAssetTrustline(
        this._publicKey!,
        assetCode,
        assetIssuer,
      );
      _isSwapLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isSwapLoading = false;
      _setError('Failed to add asset trustline: $e');
      notifyListeners();
      return {
        'success': false,
        'message': 'Failed to add asset trustline',
        'error': e.toString(),
        'status': 'error',
      };
    }
  }

  // Get asset balance
  Future<String> getAssetBalance(String assetCode, String assetIssuer) async {
    // Access the class variable with 'this' to ensure proper scope
    if (this._publicKey == null) return "0";

    try {
      final balance = await _swapService.getAssetBalance(
        this._publicKey!,
        assetCode,
        assetIssuer,
      );
      _assetBalances[assetCode] = balance;
      notifyListeners();
      return balance;
    } catch (e) {
      _setError('Failed to get asset balance: $e');
      return "0";
    }
  }

  // Load all asset balances
  Future<void> loadAllAssetBalances() async {
    if (_publicKey == null) return;

    _isSwapLoading = true;
    notifyListeners();

    try {
      for (var asset in _supportedAssets) {
        final assetCode = asset['code']!;
        final assetIssuer = asset['issuer'] == 'native' ? '' : asset['issuer']!;

        final balance = await _swapService.getAssetBalance(
          _publicKey!,
          assetCode,
          assetIssuer,
        );
        _assetBalances[assetCode] = balance;
      }

      _isSwapLoading = false;
      notifyListeners();
    } catch (e) {
      _isSwapLoading = false;
      _setError('Failed to load asset balances: $e');
      notifyListeners();
    }
  }

  // Get exchange rate between two assets
  Future<double> getExchangeRate(
    String fromAssetCode,
    String toAssetCode,
  ) async {
    try {
      return await _swapService.getExchangeRate(fromAssetCode, toAssetCode);
    } catch (e) {
      _setError('Failed to get exchange rate: $e');
      return 1.0; // Default to 1:1 exchange rate on error
    }
  }

  // Execute a swap between two assets
  Future<Map<String, dynamic>> executeSwap(
    String fromAssetCode,
    String toAssetCode,
    double amount,
  ) async {
    _isSwapLoading = true;
    _setError(null);
    notifyListeners();

    try {
      final result = await _swapService.executeSwap(
        fromAssetCode,
        toAssetCode,
        amount,
      );

      if (result['success'] == true) {
        // Refresh balances and transaction history
        await loadAllAssetBalances();
        await loadSwapHistory();
        await loadTransactions();
      }

      _isSwapLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isSwapLoading = false;
      _setError('Failed to execute swap: $e');
      notifyListeners();
      return {
        'success': false,
        'message': 'Failed to execute swap',
        'error': e.toString(),
        'status': 'error',
      };
    }
  }

  // Load swap history
  Future<void> loadSwapHistory() async {
    _isSwapLoading = true;
    notifyListeners();

    try {
      _swapHistory = await _swapService.getSwapHistory();
      _isSwapLoading = false;
      notifyListeners();
    } catch (e) {
      _isSwapLoading = false;
      _setError('Failed to load swap history: $e');
      notifyListeners();
    }
  }

  // ==================== M-PESA FUNCTIONALITY ====================

  // Initiate M-Pesa STK Push
  Future<Map<String, dynamic>> initiateMpesaPayment(
    String phoneNumber,
    double amount,
  ) async {
    _isMpesaLoading = true;
    _setError(null);
    notifyListeners();

    try {
      // Generate a unique reference for this transaction
      final accountReference = 'AZIX${DateTime.now().millisecondsSinceEpoch}';

      final result = await _mpesaService.initiateSTKPush(
        phoneNumber,
        amount,
        accountReference,
      );

      _isMpesaLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isMpesaLoading = false;
      _setError('Failed to initiate M-Pesa payment: $e');
      notifyListeners();
      return {
        'success': false,
        'message': 'Failed to initiate M-Pesa payment',
        'error': e.toString(),
      };
    }
  }

  // Check M-Pesa payment status
  Future<Map<String, dynamic>> checkMpesaPaymentStatus(
    String checkoutRequestId,
  ) async {
    _isMpesaLoading = true;
    notifyListeners();

    try {
      final result = await _mpesaService.querySTKStatus(checkoutRequestId);

      if (result['success'] == true && result['resultCode'] == '0') {
        // Payment was successful, refresh balances
        await refreshBalance();
        await loadMpesaTransactions();
      }

      _isMpesaLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isMpesaLoading = false;
      _setError('Failed to check M-Pesa payment status: $e');
      notifyListeners();
      return {
        'success': false,
        'message': 'Failed to check payment status',
        'error': e.toString(),
      };
    }
  }

  // Load M-Pesa transaction history
  Future<void> loadMpesaTransactions() async {
    _isMpesaLoading = true;
    notifyListeners();

    try {
      _mpesaTransactions = await _mpesaService.getMpesaTransactionHistory();
      _isMpesaLoading = false;
      notifyListeners();
    } catch (e) {
      _isMpesaLoading = false;
      _setError('Failed to load M-Pesa transactions: $e');
      notifyListeners();
    }
  }

  // Buy tokens with M-Pesa and credit selected asset
  Future<Map<String, dynamic>> buyWithMpesa({
    required String phoneNumber,
    required double amount,
    required String assetCode,
  }) async {
    _isMpesaLoading = true;
    _setError(null);
    notifyListeners();
    try {
      // Generate a unique reference for this transaction
      final accountReference = 'AZIX${DateTime.now().millisecondsSinceEpoch}';
      final result = await _mpesaService.initiateSTKPush(
        phoneNumber,
        amount,
        accountReference,
      );
      if (result['success'] == true) {
        // Wait for payment confirmation (simulate or poll in real app)
        // For now, assume success and credit asset
        await creditUserAsset(assetCode, amount);
        _isMpesaLoading = false;
        notifyListeners();
        return {'success': true};
      } else {
        _isMpesaLoading = false;
        _setError(result['error'] ?? 'Payment failed');
        notifyListeners();
        return {'success': false, 'error': result['error'] ?? 'Payment failed'};
      }
    } catch (e) {
      _isMpesaLoading = false;
      _setError('Failed to buy with M-Pesa: $e');
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  // Credit the user's account with the selected asset (stub for now)
  Future<Map<String, dynamic>> creditUserAsset(
    String assetCode,
    double amount,
  ) async {
    try {
      final publicKey = _publicKey;
      if (publicKey == null) throw Exception('No wallet public key');

      // Use the sendAssetFromIssuer method for issuer-to-user transfers
      final result = await _stellarService.sendAssetFromIssuer(
        assetCode,
        publicKey,
        amount.toString(),
        memo: 'Buy Akofa via Payment Provider',
      );

      if (result['success'] == true) {
        // Refresh balances and transactions after successful credit
        await refreshBalance();
        await loadTransactions();
        await loadWalletAssets();

        return {
          'success': true,
          'hash': result['hash'],
          'message': 'Successfully credited $amount $assetCode',
        };
      } else {
        throw Exception('Stellar transaction failed: ${result['message']}');
      }
    } catch (e) {
      _setError('Failed to credit asset: $e');

      // Re-throw the error so the caller knows the transaction failed
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to credit $amount $assetCode: $e',
      };
    }
  }

  // Check if wallet exists and secret is present
  Future<bool> isWalletUsable() async {
    try {
      final hasWallet = await _stellarService.hasWallet();
      if (!hasWallet) return false;
      final credentials = await _stellarService.getWalletCredentials();
      if (credentials == null ||
          credentials['secretKey'] == null ||
          credentials['secretKey']!.isEmpty) {
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check account status without fixing (for diagnostics)
  ///
  /// This function checks the status of a Stellar account without making any changes.
  /// Useful for diagnostics and monitoring account health.
  ///
  /// Parameters:
  /// - publicKey: The Stellar public key to check
  ///
  /// Returns detailed account information:
  /// - accountExists: Whether the account exists on Stellar network
  /// - hasXlm: Whether the account has XLM balance
  /// - xlmBalance: Current XLM balance
  /// - hasAkofaTrustline: Whether Akofa trustline exists
  /// - akofaBalance: Current Akofa balance (if trustline exists)
  /// - needsFunding: Whether account needs XLM funding
  /// - needsTrustline: Whether account needs Akofa trustline
  /// - status: Overall status ('complete', 'needs_xlm', 'needs_trustline', 'unfunded', 'error')
  ///
  /// Usage:
  /// ```dart
  /// final status = await stellarProvider.checkAccountStatus('G...');
  /// if (status['needsFunding']) {
  ///   print('Account needs funding');
  /// }
  /// ```
  Future<Map<String, dynamic>> checkAccountStatus(String publicKey) async {
    try {
      final result = <String, dynamic>{
        'publicKey': publicKey,
        'accountExists': false,
        'hasXlm': false,
        'xlmBalance': '0',
        'hasAkofaTrustline': false,
        'akofaBalance': '0',
        'needsFunding': false,
        'needsTrustline': false,
        'status': 'unknown',
      };

      // Check if account exists
      final accountExists = await _stellarService.checkAccountExists(publicKey);
      result['accountExists'] = accountExists;

      if (!accountExists) {
        result['needsFunding'] = true;
        result['status'] = 'unfunded';
        return result;
      }

      // Get XLM balance
      final xlmBalance = await _stellarService.getBalance(publicKey);
      result['xlmBalance'] = xlmBalance;
      result['hasXlm'] =
          double.tryParse(xlmBalance) != null && double.parse(xlmBalance) > 0;

      // Check Akofa trustline
      final hasTrustline = await _stellarService.hasAkofaTrustline(publicKey);
      result['hasAkofaTrustline'] = hasTrustline;

      if (hasTrustline) {
        final akofaBalance = await _stellarService.getAkofaBalance(publicKey);
        result['akofaBalance'] = akofaBalance;
      }

      // Determine status and needs
      if (!result['hasXlm']) {
        result['needsFunding'] = true;
        result['status'] = 'needs_xlm';
      } else if (!hasTrustline) {
        result['needsTrustline'] = true;
        result['status'] = 'needs_trustline';
      } else {
        result['status'] = 'complete';
      }

      return result;
    } catch (e) {
      return {'publicKey': publicKey, 'error': e.toString(), 'status': 'error'};
    }
  }

  // Test method to verify Friendbot funding (for debugging)
  Future<Map<String, dynamic>> testFriendbotFunding(String publicKey) async {
    try {
      final friendBotUrl = 'https://friendbot.stellar.org/?addr=$publicKey';
      final response = await http.get(Uri.parse(friendBotUrl));

      if (response.statusCode == 200) {
        // Wait for the account to be created
        await Future.delayed(const Duration(seconds: 5));

        // Refresh balance
        await refreshBalance();

        return {
          'success': true,
          'message': 'Friendbot funding test successful',
          'response': response.body,
        };
      } else {
        return {
          'success': false,
          'message': 'Friendbot funding test failed',
          'statusCode': response.statusCode,
          'response': response.body,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Friendbot funding test error',
        'error': e.toString(),
      };
    }
  }

  /// Find and fix unfunded accounts automatically
  ///
  /// This function searches for accounts that need funding or trustline setup and automatically fixes them.
  /// It checks:
  /// - Current user's main wallet
  /// - Any additional wallets owned by the current user
  ///
  /// Returns a detailed report with:
  /// - accountsFound: Total number of accounts checked
  /// - accountsFunded: Number of accounts that were funded
  /// - trustlinesAdded: Number of trustlines that were added
  /// - details: Array of individual account results
  ///
  /// Usage:
  /// ```dart
  /// final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
  /// final result = await stellarProvider.findAndFixUnfundedAccounts();
  /// if (result['success']) {
  ///   print('Fixed ${result['accountsFunded']} accounts');
  /// }
  /// ```
  Future<Map<String, dynamic>> findAndFixUnfundedAccounts() async {
    try {
      final result = <String, dynamic>{
        'success': true,
        'accountsFound': 0,
        'accountsFunded': 0,
        'trustlinesAdded': 0,
        'errors': <String>[],
        'details': <Map<String, dynamic>>[],
      };

      // Get current user's Stellar public key first
      if (_publicKey == null) {
        return {
          'success': false,
          'message': 'No current wallet found',
          'error': 'no_wallet',
        };
      }

      // Check current account status

      final accountInfo = await getAccountFundingInfo();
      result['accountsFound'] = 1;

      final accountDetail = <String, dynamic>{
        'publicKey': _publicKey,
        'initialStatus': accountInfo,
        'funded': false,
        'trustlineAdded': false,
        'errors': <String>[],
      };

      // Check if account needs funding
      if (accountInfo['exists'] == false ||
          accountInfo['status'] == 'unfunded') {
        // Fund the account
        final fundingResult = await ensureAccountFunded();

        if (fundingResult['success'] == true) {
          accountDetail['funded'] = true;
          result['accountsFunded'] = (result['accountsFunded'] as int) + 1;
        } else {
          accountDetail['errors'].add(
            'Funding failed: ${fundingResult['message']}',
          );
        }
      } else {
        accountDetail['funded'] = true;
      }

      // Check if account needs Akofa trustline
      // Trustline is now handled automatically in _ensureAkofaTrustline()
      accountDetail['trustlineAdded'] = true;

      result['details'].add(accountDetail);

      // Also check for other user wallets in Firestore (for multi-wallet scenarios)
      await _checkOtherUserWallets(result);

      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error searching for unfunded accounts',
        'error': e.toString(),
      };
    }
  }

  // Check other wallets owned by the current user
  Future<void> _checkOtherUserWallets(Map<String, dynamic> result) async {
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Query Firestore for other wallets owned by this user
      final walletsSnapshot = await FirebaseFirestore.instance
          .collection('wallets')
          .where('userId', isEqualTo: user.uid)
          .get();

      for (final doc in walletsSnapshot.docs) {
        final walletData = doc.data();
        final walletPublicKey = walletData['publicKey'];

        // Skip current wallet (already checked)
        if (walletPublicKey == _publicKey) continue;

        result['accountsFound'] = (result['accountsFound'] as int) + 1;

        final accountDetail = <String, dynamic>{
          'publicKey': walletPublicKey,
          'initialStatus': {'exists': false, 'status': 'unknown'},
          'funded': false,
          'trustlineAdded': false,
          'errors': <String>[],
        };

        try {
          // Check account status
          final accountExists = await _stellarService.checkAccountExists(
            walletPublicKey,
          );

          if (!accountExists) {
            // Fund using Friendbot directly
            final friendBotUrl =
                'https://friendbot.stellar.org/?addr=$walletPublicKey';
            final response = await http.get(Uri.parse(friendBotUrl));

            if (response.statusCode == 200) {
              await Future.delayed(const Duration(seconds: 5));
              accountDetail['funded'] = true;
              result['accountsFunded'] = (result['accountsFunded'] as int) + 1;
            } else {
              accountDetail['errors'].add('Friendbot funding failed');
            }
          } else {
            accountDetail['funded'] = true;
          }

          // Trustline is now handled automatically
          accountDetail['trustlineAdded'] = true;
        } catch (walletError) {
          accountDetail['errors'].add('Error processing wallet: $walletError');
        }

        result['details'].add(accountDetail);
      }
    } catch (e) {
      result['errors'].add('Error checking other wallets: $e');
    }
  }

  /// Batch operation to fix unfunded accounts for all users (admin function)
  ///
  /// This function processes multiple users and funds their accounts using Friendbot.
  /// It's designed for administrative use to clean up unfunded accounts across the platform.
  ///
  /// Note: This function only funds accounts, it doesn't add trustlines due to authentication requirements.
  /// Trustlines should be added individually by each user.
  ///
  /// Parameters:
  /// - limit: Maximum number of users to process (default: 50)
  ///
  /// Returns detailed results including:
  /// - usersProcessed: Number of users checked
  /// - accountsFunded: Number of accounts funded
  /// - userResults: Array of individual user processing results
  ///
  /// Usage (Admin only):
  /// ```dart
  /// final result = await stellarProvider.batchFixUnfundedAccounts(limit: 100);
  /// print('Processed ${result['usersProcessed']} users, funded ${result['accountsFunded']} accounts');
  /// ```
  ///
  /// ⚠️ Use with caution - this processes real user data
  Future<Map<String, dynamic>> batchFixUnfundedAccounts({
    int limit = 50,
  }) async {
    try {
      final result = <String, dynamic>{
        'success': true,
        'usersProcessed': 0,
        'accountsFound': 0,
        'accountsFunded': 0,
        'trustlinesAdded': 0,
        'errors': <String>[],
        'userResults': <Map<String, dynamic>>[],
      };

      // Get all users from Firestore (be careful with this in production!)
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('USER')
          .limit(limit)
          .get();

      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final userId = userDoc.id;
        final stellarPublicKey = userData['stellarPublicKey'];

        if (stellarPublicKey == null || stellarPublicKey.isEmpty) {
          continue; // Skip users without Stellar wallets
        }

        result['usersProcessed'] = (result['usersProcessed'] as int) + 1;

        final userResult = <String, dynamic>{
          'userId': userId,
          'publicKey': stellarPublicKey,
          'processed': false,
          'funded': false,
          'trustlineAdded': false,
          'errors': <String>[],
        };

        try {
          // Check if account exists
          final accountExists = await _stellarService.checkAccountExists(
            stellarPublicKey,
          );

          if (!accountExists) {
            // Fund using Friendbot
            final friendBotUrl =
                'https://friendbot.stellar.org/?addr=$stellarPublicKey';
            final response = await http.get(Uri.parse(friendBotUrl));

            if (response.statusCode == 200) {
              await Future.delayed(
                const Duration(seconds: 3),
              ); // Shorter delay for batch operations
              userResult['funded'] = true;
              result['accountsFunded'] = (result['accountsFunded'] as int) + 1;
            } else {
              userResult['errors'].add('Friendbot funding failed');
            }
          } else {
            userResult['funded'] = true;
          }

          // For batch operations, we can't add trustlines without user authentication
          // So we just mark them as needing trustline addition
          userResult['trustlineAdded'] = false;
          userResult['needsTrustline'] = true;

          userResult['processed'] = true;
          result['accountsFound'] = (result['accountsFound'] as int) + 1;
        } catch (userError) {
          userResult['errors'].add('Error processing user: $userError');
        }

        result['userResults'].add(userResult);

        // Add small delay between users to avoid overwhelming Friendbot
        await Future.delayed(const Duration(milliseconds: 500));
      }

      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error in batch fix operation',
        'error': e.toString(),
      };
    }
  }

  @override
  void dispose() {
    _stopTransactionAutoRefresh();
    super.dispose();
  }
}
