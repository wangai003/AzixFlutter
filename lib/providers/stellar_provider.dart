import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:http/http.dart' as http;
import '../services/stellar_service.dart';
import '../services/swap_service.dart';
import '../services/mpesa_service.dart';
import '../models/transaction.dart' as app_transaction;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import '../models/mining_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Mining session state
  List<MiningSession> _miningSessions = [];
  bool _isLoadingMiningSessions = false;
  Timer? _miningTimer;
  int _currentMiningSessionId = 0;

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

  // Mining session getters
  List<MiningSession> get miningSessions => _miningSessions;
  bool get isLoadingMiningSessions => _isLoadingMiningSessions;

  StellarProvider() {
    _init();
  }

  Future<void> _init() async {
    await checkWalletStatus();
    if (_hasWallet) {
      await loadTransactions();
      await loadWalletAssets();
      await loadMiningSessions();
      // Remove automatic mining timer start - mining will only start when user manually initiates
      // await startMiningTimer();
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
            _hasAkofaTrustline = await _stellarService.hasAkofaTrustline(_publicKey!);
            if (_hasAkofaTrustline) {
              _akofaBalance = await _stellarService.getAkofaBalance(_publicKey!);
            }
          } catch (trustlineError) {
            // Log the error but don't fail the wallet status check
            print('Failed to check Akofa trustline: $trustlineError');
          }
        } else {
          _hasWallet = false;
        }
      }

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
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
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
      final credentials = await _stellarService.createWalletAndStoreInFirestore(
        googleUid: googleUid,
        password: password,
        useBiometrics: useBiometrics,
      );
      _publicKey = credentials['publicKey'];
      _hasWallet = true;
      await refreshBalance();
      
      // Add Akofa trustline to new wallets (this will also ensure account is funded by FriendlyBot)
      try {
        // Show a message to the user that we're setting up their wallet
        _setError('Setting up your wallet with Akofa token...');
        // Note: We're already in loading state from the beginning of createWallet
        
        final trustlineResult = await addAkofaTrustline();
        if (trustlineResult['success'] == true) {
          // Set a success message for the user
          String successMessage = 'Wallet setup complete!';
          if (trustlineResult['wasFunded'] == true) {
            successMessage = 'Your account was funded and Akofa token was added successfully!';
          } else {
            successMessage = 'Your wallet is ready with Akofa token added!';
          }
          
          // Use _setError to display a success message (consider renaming this method in the future)
          _setError(successMessage);
          
          print('Wallet setup complete: Account funded and Akofa trustline added successfully');
          if (trustlineResult['wasFunded'] == true) {
            print('Account was funded by FriendlyBot');
          }
        } else {
          // Set a user-friendly error message
          String errorMessage = 'Could not complete wallet setup.';
          if (trustlineResult['status'] == 'funding_failed') {
            errorMessage = 'Could not fund your account. Please try again later.';
            print('Failed to fund account: ${trustlineResult['fundingResult']?['message'] ?? 'Unknown funding error'}');
          } else {
            errorMessage = 'Could not add Akofa token to your wallet. Please try again later.';
            print('Failed to add Akofa trustline: ${trustlineResult['message']}');
          }
          
          _setError(errorMessage);
          print('Failed to complete wallet setup: ${trustlineResult['error'] ?? trustlineResult['message']}');
        }
      } catch (error) {
        _setError('An unexpected error occurred during wallet setup. Please try again.');
        print('Exception during wallet setup: $error');
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
      _hasAkofaTrustline = await _stellarService.hasAkofaTrustline(this._publicKey!);
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
        'status': 'no_public_key'
      };
    }
    
    try {
      final result = await _stellarService.hasEnoughXlmForTransaction(this._publicKey!);
      return result;
    } catch (e) {
      _setError('Failed to check XLM balance: $e');
      return {
        'hasEnough': false,
        'message': 'Error checking balance: $e',
        'balance': '0',
        'status': 'error'
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
        'status': 'no_public_key'
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
          'status': 'already_funded'
        };
      }
      
      // No need to get wallet credentials for funding
      // The public key is already available
      
      // Try to fund the account using Friendbot
      final friendBotUrl = 'https://friendbot.stellar.org/?addr=${this._publicKey}';
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
              'status': 'funding_success'
            };
          } else {
            _setLoading(false);
            return {
              'success': false,
              'message': 'Account was funded but still has insufficient XLM',
              'balance': newXlmCheck['balance'],
              'status': 'insufficient_xlm_after_funding'
            };
          }
        } else {
          _setLoading(false);
          return {
            'success': false,
            'message': 'Failed to fund account with Friendly Bot',
            'error': 'Response: ${response.statusCode} - ${response.body}',
            'status': 'funding_error'
          };
        }
      } catch (fundingError) {
        _setLoading(false);
        _setError('Failed to fund account: $fundingError');
        return {
          'success': false,
          'message': 'Failed to fund account',
          'error': fundingError.toString(),
          'status': 'funding_request_error'
        };
      }
    } catch (e) {
      _setLoading(false);
      _setError('Failed to ensure account funding: $e');
      return {
        'success': false,
        'message': 'Error ensuring account funding',
        'error': e.toString(),
        'status': 'error'
      };
    }
  }
  
  // Check if wallet has Akofa trustline
  Future<bool> checkAkofaTrustline() async {
    if (this._publicKey == null) return false;
    
    _setLoading(true);
    _setError(null);
    
    try {
      _hasAkofaTrustline = await _stellarService.hasAkofaTrustline(this._publicKey!);
      
      if (_hasAkofaTrustline) {
        _akofaBalance = await _stellarService.getAkofaBalance(this._publicKey!);
      }
      
      _setLoading(false);
      notifyListeners();
      return _hasAkofaTrustline;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to check Akofa trustline: $e');
      return false;
    }
  }
  
  // Add Akofa trustline to wallet - new implementation with automatic funding
  Future<Map<String, dynamic>> addAkofaTrustline() async {
    if (this._publicKey == null) {
      return {
        'success': false,
        'message': 'No public key available',
        'status': 'no_public_key'
      };
    }
    
    _setLoading(true);
    _setError(null);

    try {
      // First, check if the account is funded and fund it if necessary
      final fundingResult = await ensureAccountFunded();
      
      // If funding failed and it wasn't because the account is already funded, return the error
      if (fundingResult['success'] != true && fundingResult['status'] != 'already_funded') {
        _setLoading(false);
        _setError('Account funding required: ${fundingResult['message']}');
        return {
          'success': false,
          'message': 'Could not fund your account: ${fundingResult['message']}',
          'status': 'funding_failed',
          'fundingResult': fundingResult
        };
      }
      
      // Get the full wallet credentials (this will require authentication)
      final credentials = await getFullWalletCredentials();
      if (credentials == null) {
        _setLoading(false);
        _setError('Could not retrieve wallet credentials');
        return {
          'success': false,
          'message': 'Could not retrieve wallet credentials',
          'status': 'credential_error'
        };
      }
      
      // Now that the account is funded and we have the credentials, try to add the trustline
      final result = await _stellarService.addAkofaTrustline(this._publicKey!, credentials: credentials);
      
      if (result['success'] == true) {
        // If trustline was added successfully or already exists
        _hasAkofaTrustline = true;
        await refreshBalance(); // Refresh balance after adding trustline
        
        // If we just funded the account, include that in the success message
        if (fundingResult['status'] == 'funding_success') {
          result['message'] = 'Your account was funded and Akofa trustline was added successfully!';
          result['wasFunded'] = true;
        }
      } else {
        // Set a user-friendly error message based on the error status
        String errorMessage = 'Failed to add Akofa trustline';
        
        switch (result['status']) {
          case 'credential_error':
            errorMessage = 'Could not access your wallet credentials. Please try again.';
            break;
          case 'encryption_error':
          case 'encryption_fix_error':
            errorMessage = 'There was a problem with your wallet encryption. Please contact support.';
            break;
          case 'secret_key_error':
            errorMessage = 'Your wallet secret key could not be retrieved. Please try again.';
            break;
          case 'key_mismatch':
            errorMessage = 'There was a mismatch with your wallet keys. Please contact support.';
            break;
          case 'keypair_error':
            errorMessage = 'Could not create a valid key pair from your wallet. Please try again.';
            break;
          case 'account_load_error':
          case 'account_load_error_after_funding':
            errorMessage = 'Could not load your account from the Stellar network. Please try again later.';
            break;
          case 'funding_error':
          case 'funding_request_error':
            errorMessage = 'Could not fund your account on the Stellar network. Please try again later.';
            break;
          case 'transaction_failed':
            errorMessage = 'The transaction to add the trustline failed. Please try again.';
            break;
          case 'transaction_error':
            errorMessage = 'There was an error creating or submitting the transaction. Please try again.';
            break;
          default:
            errorMessage = result['message'] ?? 'An unexpected error occurred. Please try again.';
        }
        
        _setError(errorMessage);
        
        // Add detailed error for debugging
        if (kDebugMode && result['error'] != null) {
          print('Detailed error: ${result['error']}');
        }
      }
      
      _setLoading(false);
      return result;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to add Akofa trustline: $e');
      return {
        'success': false,
        'message': 'Exception occurred',
        'error': e.toString(),
        'status': 'exception'
      };
    }
  }


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
      final success = await _stellarService.recoverWalletWithSecretKey(secretKey);
      
      if (success) {
        // Update local state
        final credentials = await _stellarService.getWalletCredentials();
        if (credentials != null) {
          _publicKey = credentials['publicKey'];
          await refreshBalance();
          await checkAkofaTrustline();
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
      await _stellarService.deleteWallet();
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
    if (!_hasWallet) return;
    
    _isTransactionLoading = true;
    notifyListeners();
    
    try {
      _transactions = await _stellarService.getTransactionHistory();
      _isTransactionLoading = false;
      notifyListeners();
    } catch (e) {
      _isTransactionLoading = false;
      _setError('Failed to load transactions: $e');
    }
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
  Future<Map<String, dynamic>> sendAsset(String assetCode, String destinationAddress, String amount, {String? memo}) async {
    _setLoading(true);
    _setError(null);
    
    try {
      final result = await _stellarService.sendAsset(assetCode, destinationAddress, amount, memo: memo);
      
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
  Future<Map<String, dynamic>> sendAkofa(String destinationAddress, String amount, {String? memo}) async {
    return sendAsset('AKOFA', destinationAddress, amount, memo: memo);
  }
  
  // Send XLM (for backward compatibility)
  Future<Map<String, dynamic>> sendXlm(String destinationAddress, String amount, {String? memo}) async {
    return sendAsset('XLM', destinationAddress, amount, memo: memo);
  }
  
  // Record a mining reward
  Future<bool> recordMiningReward(double amount) async {
    _setLoading(true);
    _setError(null);
    try {
      final result = await _stellarService.recordMiningReward(amount);
      await loadTransactions();
      _setLoading(false);
      return result['success'] == true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to record mining reward: $e');
      return false;
    }
  }

  // Reconcile uncredited mining sessions for the current user
  Future<void> reconcileUncreditedMiningSessions(String userId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final sessionsRef = firestore.collection('mining_history').doc(userId).collection('sessions');
      final sessions = await sessionsRef.get();
      for (final doc in sessions.docs) {
        final data = doc.data();
        final status = data['status'] ?? '';
        final amount = (data['earned'] ?? 0).toDouble();
        if (status != 'completed' && amount > 0) {
          // Try to credit the reward again
          final result = await recordMiningReward(amount);
          if (result) {
            await doc.reference.update({'status': 'completed'});
          } else {
            await doc.reference.update({'status': 'failed'});
          }
        }
      }
    } catch (e) {
      print('Error reconciling mining sessions: $e');
    }
  }

  // Create a test transaction for debugging
  Future<bool> createTestTransaction() async {
    _setLoading(true);
    _setError(null);
    
    try {
      await _stellarService.createTestTransaction();
      
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
      return await _swapService.hasAssetTrustline(this._publicKey!, assetCode, assetIssuer);
    } catch (e) {
      _setError('Failed to check asset trustline: $e');
      return false;
    }
  }
  
  // Add trustline for an asset
  Future<Map<String, dynamic>> addAssetTrustline(String assetCode, String assetIssuer) async {
    if (this._publicKey == null) {
      return {
        'success': false,
        'message': 'No public key available',
        'status': 'no_public_key'
      };
    }
    
    _isSwapLoading = true;
    _setError(null);
    notifyListeners();
    
    try {
      final result = await _swapService.addAssetTrustline(this._publicKey!, assetCode, assetIssuer);
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
        'status': 'error'
      };
    }
  }
  
  // Get asset balance
  Future<String> getAssetBalance(String assetCode, String assetIssuer) async {
    // Access the class variable with 'this' to ensure proper scope
    if (this._publicKey == null) return "0";
    
    try {
      final balance = await _swapService.getAssetBalance(this._publicKey!, assetCode, assetIssuer);
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
        
        final balance = await _swapService.getAssetBalance(_publicKey!, assetCode, assetIssuer);
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
  Future<double> getExchangeRate(String fromAssetCode, String toAssetCode) async {
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
    double amount
  ) async {
    _isSwapLoading = true;
    _setError(null);
    notifyListeners();
    
    try {
      final result = await _swapService.executeSwap(fromAssetCode, toAssetCode, amount);
      
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
        'status': 'error'
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
  Future<Map<String, dynamic>> initiateMpesaPayment(String phoneNumber, double amount) async {
    _isMpesaLoading = true;
    _setError(null);
    notifyListeners();
    
    try {
      // Generate a unique reference for this transaction
      final accountReference = 'AZIX${DateTime.now().millisecondsSinceEpoch}';
      
      final result = await _mpesaService.initiateSTKPush(phoneNumber, amount, accountReference);
      
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
        'error': e.toString()
      };
    }
  }
  
  // Check M-Pesa payment status
  Future<Map<String, dynamic>> checkMpesaPaymentStatus(String checkoutRequestId) async {
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
        'error': e.toString()
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
  Future<Map<String, dynamic>> buyWithMpesa({required String phoneNumber, required double amount, required String assetCode}) async {
    _isMpesaLoading = true;
    _setError(null);
    notifyListeners();
    try {
      // Generate a unique reference for this transaction
      final accountReference = 'AZIX${DateTime.now().millisecondsSinceEpoch}';
      final result = await _mpesaService.initiateSTKPush(phoneNumber, amount, accountReference);
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
  Future<void> creditUserAsset(String assetCode, double amount) async {
    try {
      final publicKey = _publicKey;
      if (publicKey == null) throw Exception('No wallet public key');
      
      // Use the sendAssetFromIssuer method for issuer-to-user transfers
      await _stellarService.sendAssetFromIssuer(assetCode, publicKey, amount.toString(), memo: 'M-Pesa Top Up');
      
      await refreshBalance();
      await loadTransactions();
      await loadWalletAssets();
    } catch (e) {
      _setError('Failed to credit asset: $e');
    }
  }

  // Check if wallet exists and secret is present
  Future<bool> isWalletUsable() async {
    try {
      final hasWallet = await _stellarService.hasWallet();
      if (!hasWallet) return false;
      final credentials = await _stellarService.getWalletCredentials();
      if (credentials == null || credentials['secretKey'] == null || credentials['secretKey']!.isEmpty) {
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== MINING FUNCTIONALITY ====================

  // Manual method to start mining - only works when no active session exists
  Future<bool> startMining() async {
    if (_publicKey == null) return false;
    
    // Check if there's already an active session
    final currentSession = this.currentMiningSession;
    if (currentSession != null && currentSession.isActive && !currentSession.isExpired) {
      // Can't start mining if there's already an active session
      return false;
    }
    
    // Create new mining session
    final newSession = MiningSession.newSession(miningRate: 0.25);
    _miningSessions = [newSession];
    
    // Start the mining timer
    await startMiningTimer();
    
    // Save the new session
    await saveMiningSession(newSession);
    
    notifyListeners();
    return true;
  }

  Future<void> startMiningTimer() async {
    if (_publicKey == null) return;
    
    // Cancel existing timer if any
    _miningTimer?.cancel();
    
    // Start the mining timer that runs every second
    _miningTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateMiningProgress();
    });
    
    print('Mining timer started - will persist across app restarts');
  }

  void stopMiningTimer() {
    _miningTimer?.cancel();
    _miningTimer = null;
    print('Mining timer stopped');
  }

  void _updateMiningProgress() {
    if (_miningSessions.isEmpty) return;
    
    final activeSession = _miningSessions.lastWhere(
      (session) => session.isActive,
      orElse: () => MiningSession.newSession(miningRate: 0.25),
    );
    
    if (activeSession.isActive && !activeSession.isPaused) {
      // Update session progress in real-time
      final now = DateTime.now();
      final timeSinceResume = now.difference(activeSession.lastResume).inSeconds;
      
      // Check if session should end (24 hours)
      if (now.isAfter(activeSession.sessionEnd)) {
        _endMiningSession(activeSession);
      } else {
        // Update accumulated time and notify listeners every second
        activeSession.accumulatedSeconds = activeSession.accumulatedSeconds + timeSinceResume;
        activeSession.lastResume = now;
        
        // Save state every 10 seconds to ensure persistence
        if (activeSession.accumulatedSeconds % 10 == 0) {
          saveMiningSession(activeSession);
        }
        
        notifyListeners();
      }
    }
  }

  void _endMiningSession(MiningSession session) {
    session.isPaused = true;
    
    // Calculate and record mining reward
    final earned = session.earnedAkofa;
    
    if (earned > 0) {
      recordMiningReward(earned);
    }
    
    // Save session to storage
    saveMiningSession(session);
    
    // Don't automatically start new session - user must manually start
    // _startNewMiningSession();
    
    notifyListeners();
  }

  void _startNewMiningSession() {
    final newSession = MiningSession.newSession(miningRate: 0.25);
    
    _miningSessions.add(newSession);
    saveMiningSession(newSession);
    notifyListeners();
  }

  Future<void> saveMiningSession(MiningSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionData = {
        'sessionId': session.sessionId,
        'sessionStart': session.sessionStart.millisecondsSinceEpoch,
        'sessionEnd': session.sessionEnd.millisecondsSinceEpoch,
        'isPaused': session.isPaused,
        'pausedAt': session.pausedAt?.millisecondsSinceEpoch,
        'accumulatedSeconds': session.accumulatedSeconds,
        'lastResume': session.lastResume.millisecondsSinceEpoch,
        'miningRate': session.miningRate,
      };
      
      // Save as JSON string for proper parsing
      await prefs.setString('current_mining_session', json.encode(sessionData));
      
      // Also save to Firestore for cloud backup (optional)
      await _saveMiningSessionToFirestore(session);
    } catch (e) {
      print('Failed to save mining session: $e');
    }
  }

  Future<void> _saveMiningSessionToFirestore(MiningSession session) async {
    try {
      // For now, we'll skip Firestore save to avoid context issues
      // This can be implemented later with proper context management
      // The local storage is sufficient for persistence
    } catch (e) {
      print('Failed to save mining session to Firestore: $e');
      // Don't fail the local save if Firestore fails
    }
  }

  Future<void> loadMiningSessions() async {
    if (_publicKey == null) return;
    
    _isLoadingMiningSessions = true;
    notifyListeners();
    
    try {
      // Load from local storage
      final prefs = await SharedPreferences.getInstance();
      final sessionData = prefs.getString('current_mining_session');
      
      if (sessionData != null) {
        try {
          final sessionMap = Map<String, dynamic>.from(
            json.decode(sessionData) as Map<String, dynamic>
          );
          
          // Convert stored timestamps back to DateTime objects
          final session = MiningSession(
            sessionId: sessionMap['sessionId'] ?? '',
            sessionStart: DateTime.fromMillisecondsSinceEpoch(sessionMap['sessionStart'] ?? 0),
            sessionEnd: DateTime.fromMillisecondsSinceEpoch(sessionMap['sessionEnd'] ?? 0),
            isPaused: sessionMap['isPaused'] ?? false,
            pausedAt: sessionMap['pausedAt'] != null 
                ? DateTime.fromMillisecondsSinceEpoch(sessionMap['pausedAt'])
                : null,
            accumulatedSeconds: sessionMap['accumulatedSeconds'] ?? 0,
            lastResume: DateTime.fromMillisecondsSinceEpoch(sessionMap['lastResume'] ?? 0),
            miningRate: (sessionMap['miningRate'] as num?)?.toDouble() ?? 0.25,
          );
          
          _miningSessions = [session];
          
          // Check if session is still valid and restore state
          await _restoreMiningState(session);
        } catch (parseError) {
          print('Error parsing mining session: $parseError');
          // Don't automatically create new session - user must manually start
          _miningSessions = [];
        }
      } else {
        // No session exists - don't create one automatically
        // User must manually start mining
        _miningSessions = [];
      }
      
      _isLoadingMiningSessions = false;
      notifyListeners();
    } catch (e) {
      _isLoadingMiningSessions = false;
      _setError('Failed to load mining sessions: $e');
      notifyListeners();
    }
  }

  Future<void> _restoreMiningState(MiningSession session) async {
    final now = DateTime.now();
    
    // Check if session has expired
    if (now.isAfter(session.sessionEnd)) {
      // Session expired, mark it as expired but don't start new one automatically
      session.isPaused = true;
      session.pausedAt = now;
      await saveMiningSession(session);
      return;
    }
    
    // If session was paused, keep it paused
    if (session.isPaused) {
      // Update accumulated time from when it was paused
      if (session.pausedAt != null) {
        final timeSincePause = session.pausedAt!.difference(session.lastResume).inSeconds;
        session.accumulatedSeconds += timeSincePause;
      }
    } else {
      // Session was active, calculate accumulated time since last resume
      final timeSinceResume = now.difference(session.lastResume).inSeconds;
      session.accumulatedSeconds += timeSinceResume;
      session.lastResume = now;
    }
    
    // Save the restored state
    await saveMiningSession(session);
    
    // Don't automatically start timer - user must manually resume mining
    // if (session.isActive && !session.isPaused) {
    //   await startMiningTimer();
    // }
  }

  Future<void> stopMiningSession(String sessionId) async {
    final sessionToStop = _miningSessions.firstWhere(
      (session) => session.sessionId == sessionId,
      orElse: () => MiningSession.newSession(miningRate: 0.25),
    );
    
    if (sessionToStop.isActive) {
      sessionToStop.pauseMining();
      await saveMiningSession(sessionToStop);
      notifyListeners();
    }
  }

  Future<void> deleteMiningSession(String sessionId) async {
    _miningSessions.removeWhere((session) => session.sessionId == sessionId);
    notifyListeners();
  }

  // Get current active mining session
  MiningSession? get currentMiningSession {
    if (_miningSessions.isEmpty) return null;
    return _miningSessions.lastWhere(
      (session) => session.isActive,
      orElse: () => _miningSessions.last,
    );
  }

  // Get mining progress (0.0 to 1.0)
  double get miningProgress {
    final session = currentMiningSession;
    if (session == null || !session.isActive) return 0.0;
    
    final now = DateTime.now();
    final elapsed = now.difference(session.sessionStart).inSeconds;
    final total = session.sessionEnd.difference(session.sessionStart).inSeconds;
    
    return (elapsed / total).clamp(0.0, 1.0);
  }

  // Get current mining earnings
  double get currentMiningEarnings {
    final session = currentMiningSession;
    if (session == null || !session.isActive) return 0.0;
    
    return session.earnedAkofa;
  }

  // Get time remaining in current session
  Duration get timeRemaining {
    final session = currentMiningSession;
    if (session == null || session.isExpired) return Duration.zero;
    
    final now = DateTime.now();
    final remaining = session.sessionEnd.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  // Get formatted time remaining string
  String get formattedTimeRemaining {
    final remaining = timeRemaining;
    if (remaining.inSeconds <= 0) return 'Session Ended';
    
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;
    
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Check if mining can be started (no active session exists)
  bool get canStartMining {
    final session = currentMiningSession;
    return session == null || session.isExpired;
  }

  @override
  void dispose() {
    _miningTimer?.cancel();
    super.dispose();
  }
}
