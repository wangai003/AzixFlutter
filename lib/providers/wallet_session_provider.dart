import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/biometric_service.dart';
import '../services/secure_wallet_service.dart';
import '../services/polygon_wallet_service.dart';

/// Manages wallet session timeout and authentication state
/// Logs users out of wallet feature after 3 minutes of inactivity
class WalletSessionProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Session state
  bool _isWalletAuthenticated = false;
  DateTime? _lastActivity;
  Timer? _sessionTimer;
  Timer? _inactivityCheckTimer;

  // Wallet authentication preferences (loaded from Firestore)
  bool _biometricsEnabled = false;
  bool _passwordEnabled = true;
  String? _authMethod; // 'biometric', 'password', or 'both'

  // Session timeout duration (3 minutes)
  static const Duration sessionTimeout = Duration(minutes: 3);
  static const Duration checkInterval = Duration(seconds: 10);

  // Getters
  bool get isWalletAuthenticated => _isWalletAuthenticated;
  DateTime? get lastActivity => _lastActivity;
  bool get biometricsEnabled => _biometricsEnabled;
  bool get passwordEnabled => _passwordEnabled;
  String? get authMethod => _authMethod;
  
  /// Get time remaining until session expires
  Duration? get timeUntilExpiry {
    if (_lastActivity == null || !_isWalletAuthenticated) return null;
    final expiry = _lastActivity!.add(sessionTimeout);
    final remaining = expiry.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  WalletSessionProvider() {
    _init();
  }

  Future<void> _init() async {
    await _loadWalletAuthPreferences();
    _startInactivityChecker();
  }

  /// Load wallet authentication preferences from Firestore
  Future<void> _loadWalletAuthPreferences() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Check Polygon wallet first (primary wallet)
      final polygonWalletDoc = await _firestore
          .collection('polygon_wallets')
          .doc(user.uid)
          .get();

      if (polygonWalletDoc.exists) {
        final walletData = polygonWalletDoc.data()!;
        _biometricsEnabled = walletData['biometricsEnabled'] as bool? ?? false;
        _passwordEnabled = true; // Password always enabled
        
        // Determine auth method
        if (_biometricsEnabled) {
          _authMethod = 'both'; // Both biometric and password available
        } else {
          _authMethod = 'password'; // Password only
        }
        
        print('🔐 [SESSION] Wallet auth preferences loaded: $_authMethod');
        notifyListeners();
        return;
      }

      // Fallback to Stellar secure wallet
      final stellarWalletDoc = await _firestore
          .collection('secure_wallets')
          .doc(user.uid)
          .get();

      if (stellarWalletDoc.exists) {
        final walletData = stellarWalletDoc.data()!;
        _biometricsEnabled = walletData['biometricsEnabled'] as bool? ?? false;
        _passwordEnabled = true;
        
        if (_biometricsEnabled) {
          _authMethod = 'both';
        } else {
          _authMethod = 'password';
        }
        
        print('🔐 [SESSION] Wallet auth preferences loaded: $_authMethod');
        notifyListeners();
      }
    } catch (e) {
      print('⚠️ [SESSION] Error loading wallet auth preferences: $e');
    }
  }

  /// Start the inactivity checker that runs every 10 seconds
  void _startInactivityChecker() {
    _inactivityCheckTimer?.cancel();
    _inactivityCheckTimer = Timer.periodic(checkInterval, (_) {
      _checkInactivity();
    });
  }

  /// Check if session has expired due to inactivity
  void _checkInactivity() {
    if (!_isWalletAuthenticated || _lastActivity == null) return;

    final now = DateTime.now();
    final inactiveDuration = now.difference(_lastActivity!);

    if (inactiveDuration >= sessionTimeout) {
      print('⏰ [SESSION] Wallet session expired after ${inactiveDuration.inMinutes} minutes');
      _logoutWallet();
    }
  }

  /// Authenticate wallet with password
  Future<Map<String, dynamic>> authenticateWithPassword(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
        };
      }

      print('🔐 [SESSION] Attempting password authentication...');

      // Try Polygon wallet authentication first
      try {
        final polygonResult = await PolygonWalletService.authenticateAndDecryptPolygonWallet(
          user.uid,
          password,
        );
        
        if (polygonResult['success'] == true) {
          _setWalletAuthenticated();
          print('✅ [SESSION] Polygon wallet authenticated successfully');
          return {'success': true, 'message': 'Wallet authenticated successfully'};
        }
      } catch (polygonError) {
        print('⚠️ [SESSION] Polygon wallet auth failed: $polygonError');
      }

      // Fallback to Stellar wallet authentication
      try {
        final stellarResult = await SecureWalletService.authenticateAndDecryptWallet(
          user.uid,
          password,
        );
        
        if (stellarResult['success'] == true) {
          _setWalletAuthenticated();
          print('✅ [SESSION] Stellar wallet authenticated successfully');
          return {'success': true, 'message': 'Wallet authenticated successfully'};
        }
      } catch (stellarError) {
        print('⚠️ [SESSION] Stellar wallet auth failed: $stellarError');
      }

      return {
        'success': false,
        'error': 'Invalid password',
      };
    } catch (e) {
      print('❌ [SESSION] Password authentication error: $e');
      return {
        'success': false,
        'error': 'Authentication failed: $e',
      };
    }
  }

  /// Authenticate wallet with biometrics
  Future<Map<String, dynamic>> authenticateWithBiometrics() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
        };
      }

      if (!_biometricsEnabled) {
        return {
          'success': false,
          'error': 'Biometric authentication not enabled',
        };
      }

      print('🔐 [SESSION] Attempting biometric authentication...');

      // Get credential ID from wallet data
      String? credentialId;
      
      // Try Polygon wallet first
      final polygonWalletDoc = await _firestore
          .collection('polygon_wallets')
          .doc(user.uid)
          .get();

      if (polygonWalletDoc.exists) {
        final walletData = polygonWalletDoc.data()!;
        final biometricData = walletData['biometricData'] as Map<String, dynamic>?;
        credentialId = biometricData?['credentialId'] as String?;
      }

      // Fallback to Stellar wallet
      if (credentialId == null) {
        final stellarWalletDoc = await _firestore
            .collection('secure_wallets')
            .doc(user.uid)
            .get();

        if (stellarWalletDoc.exists) {
          final walletData = stellarWalletDoc.data()!;
          final biometricData = walletData['biometricData'] as Map<String, dynamic>?;
          credentialId = biometricData?['credentialId'] as String?;
        }
      }

      // Authenticate with biometrics
      final biometricResult = await BiometricService.authenticateWithBiometrics(
        localizedReason: 'Authenticate to access your wallet',
        credentialId: credentialId,
      );

      if (biometricResult['success'] == true) {
        _setWalletAuthenticated();
        print('✅ [SESSION] Biometric authentication successful');
        return {'success': true, 'message': 'Wallet authenticated successfully'};
      } else {
        return {
          'success': false,
          'error': biometricResult['error'] ?? 'Biometric authentication failed',
        };
      }
    } catch (e) {
      print('❌ [SESSION] Biometric authentication error: $e');
      return {
        'success': false,
        'error': 'Authentication failed: $e',
      };
    }
  }

  /// Set wallet as authenticated and start session
  void _setWalletAuthenticated() {
    _isWalletAuthenticated = true;
    _lastActivity = DateTime.now();
    
    // Start session timeout timer
    _resetSessionTimer();
    
    print('✅ [SESSION] Wallet session started at ${_lastActivity}');
    notifyListeners();
  }

  /// Reset the session timer
  void _resetSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(sessionTimeout, () {
      print('⏰ [SESSION] Session timeout reached');
      _logoutWallet();
    });
  }

  /// Record user activity to reset inactivity timer
  void recordActivity() {
    if (!_isWalletAuthenticated) return;
    
    _lastActivity = DateTime.now();
    _resetSessionTimer();
    
    // Don't notify listeners for every activity to avoid excessive rebuilds
  }

  /// Log out from wallet feature (not the entire app)
  void _logoutWallet() {
    _isWalletAuthenticated = false;
    _lastActivity = null;
    _sessionTimer?.cancel();
    
    print('🚪 [SESSION] Wallet session ended');
    notifyListeners();
  }

  /// Manual wallet logout
  void logoutWallet() {
    _logoutWallet();
  }

  /// Check if wallet session is valid
  bool isSessionValid() {
    if (!_isWalletAuthenticated || _lastActivity == null) return false;
    
    final now = DateTime.now();
    final inactiveDuration = now.difference(_lastActivity!);
    
    return inactiveDuration < sessionTimeout;
  }

  /// Force session refresh (useful when user returns to wallet screen)
  Future<void> refreshSession() async {
    if (_isWalletAuthenticated && isSessionValid()) {
      recordActivity();
      print('🔄 [SESSION] Session refreshed');
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _inactivityCheckTimer?.cancel();
    super.dispose();
  }
}

