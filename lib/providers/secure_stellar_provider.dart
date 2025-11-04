import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/stellar_service.dart';
import '../services/blockchain_transaction_service.dart';
import '../services/secure_wallet_service.dart';
import '../services/transaction_service.dart';

/// Enhanced Stellar provider with wallet functionality
class SecureStellarProvider extends ChangeNotifier {
  final StellarService _stellarService;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // State management
  bool _hasWallet = false;
  bool _isLoading = false;
  String? _error;
  String? _successMessage;
  String? _publicKey;
  String _balance = '0';
  bool _hasAkofaTrustline = false;
  List<Map<String, dynamic>> _transactions = [];
  bool _isTransactionLoading = false;
  List<Map<String, dynamic>> _walletAssets = [];
  bool _isLoadingWalletAssets = false;

  SecureStellarProvider({
    StellarService? stellarService,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _stellarService = stellarService ?? StellarService(),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance {
    _initialize();
  }

  // Getters
  bool get hasWallet => _hasWallet;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get successMessage => _successMessage;
  String? get publicKey => _publicKey;
  String get balance => _balance;
  bool get hasAkofaTrustline => _hasAkofaTrustline;
  List<Map<String, dynamic>> get transactions => _transactions;
  bool get isTransactionLoading => _isTransactionLoading;
  List<Map<String, dynamic>> get walletAssets => _walletAssets;
  bool get isLoadingWalletAssets => _isLoadingWalletAssets;

  /// Initialize the provider
  Future<void> _initialize() async {
    await _loadWalletState();
  }

  /// Load wallet state
  Future<void> _loadWalletState() async {
    _setLoading(true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _setLoading(false);
        return;
      }

      // First check for secure wallet
      final hasSecureWallet = await SecureWalletService.hasSecureWallet(
        user.uid,
      );
      if (hasSecureWallet) {
        _hasWallet = true;
        _publicKey = await SecureWalletService.getWalletPublicKey(user.uid);
        await refreshBalance();
        _setLoading(false);
        return;
      }

      // Fallback to regular wallet
      final credentials = await _stellarService.getWalletCredentials();
      if (credentials != null) {
        _hasWallet = true;
        _publicKey = credentials['publicKey'];
        await refreshBalance();
      }
    } catch (e) {
      _setError('Failed to load wallet: $e');
    }
    _setLoading(false);
  }

  /// Create wallet
  Future<bool> createWallet() async {
    _setLoading(true);
    _setError(null);

    try {
      final result = await _stellarService.createWalletAndStoreInFirestore();
      final success = result['status'] == 'success';
      if (success) {
        final credentials = await _stellarService.getWalletCredentials();
        if (credentials != null) {
          _hasWallet = true;
          _publicKey = credentials['publicKey'];
          await refreshBalance();
        }
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to create wallet: $e');
      return false;
    }
  }

  /// Refresh balance
  Future<void> refreshBalance() async {
    if (!_hasWallet || _publicKey == null) return;

    try {
      // Try to get AKOFA balance first, fallback to general balance
      try {
        _balance = await _stellarService.getAkofaBalance(_publicKey!);
      } catch (e) {
        // Fallback to general balance method
        _balance = await _stellarService.getBalance(_publicKey!);
      }
      notifyListeners();
    } catch (e) {
      _setError('Failed to refresh balance: $e');
    }
  }

  /// Load transactions
  Future<void> loadTransactions() async {
    if (!_hasWallet) return;

    _isTransactionLoading = true;
    notifyListeners();

    try {
      // Use blockchain service instead of non-existent method
      final blockchainTransactions =
          await BlockchainTransactionService.getUserTransactionsFromBlockchain();
      _transactions = blockchainTransactions.map((tx) => tx.toMap()).toList();
      _isTransactionLoading = false;
      notifyListeners();
    } catch (e) {
      _isTransactionLoading = false;
      _setError('Failed to load transactions: $e');
    }
  }

  /// Check if user can receive rewards
  Future<Map<String, dynamic>> checkRewardEligibility() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'canReceive': false,
          'reason': 'User not authenticated',
          'details': 'Please log in to receive rewards',
        };
      }

      String? publicKey;
      String? walletType = 'unknown';

      // First check for secure/enhanced wallet
      final hasSecureWallet = await SecureWalletService.hasSecureWallet(
        user.uid,
      );
      if (hasSecureWallet) {
        publicKey = await SecureWalletService.getWalletPublicKey(user.uid);
        walletType = 'secure';
      }

      // If no secure wallet, check for regular wallet
      if (publicKey == null) {
        final credentials = await _stellarService.getWalletCredentials();
        if (credentials != null) {
          publicKey = credentials['publicKey'];
          walletType = 'regular';
        } else {
          return {
            'canReceive': false,
            'reason': 'No wallet found',
            'details':
                'Please create or import a Stellar wallet to receive rewards. Both regular and secure wallets are supported.',
          };
        }
      }

      // Check if account exists
      final accountExists = await _stellarService.checkAccountExists(
        publicKey!,
      );
      if (!accountExists) {
        return {
          'canReceive': false,
          'reason': 'Account not funded',
          'details':
              'Your Stellar account needs to be funded with at least 1 XLM.',
        };
      }

      // Check AKOFA trustline
      final hasTrustline = await _stellarService.hasAkofaTrustline(publicKey!);
      if (!hasTrustline) {
        return {
          'canReceive': false,
          'reason': 'Missing AKOFA trustline',
          'details':
              'Your account needs an AKOFA trustline to receive rewards.',
        };
      }

      // Check AKOFA tag
      final userDoc = await _firestore.collection('USER').doc(user.uid).get();
      if (!userDoc.exists) {
        return {
          'canReceive': false,
          'reason': 'User profile incomplete',
          'details':
              'User profile not found. Please complete your profile setup.',
        };
      }

      final userData = userDoc.data()!;
      final akofaTag = userData['akofaTag'] as String?;
      if (akofaTag == null || akofaTag.isEmpty) {
        return {
          'canReceive': false,
          'reason': 'Missing AKOFA tag',
          'details':
              'Please set your AKOFA tag in your profile to receive rewards.',
        };
      }

      return {
        'canReceive': true,
        'reason': 'Eligible for rewards',
        'details': 'Your ${walletType} wallet is ready to receive rewards',
        'walletType': walletType,
        'publicKey': publicKey,
        'akofaTag': akofaTag,
      };
    } catch (e) {
      return {
        'canReceive': false,
        'reason': 'Error checking eligibility',
        'details': 'Error: $e',
      };
    }
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
