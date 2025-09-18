import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WalletAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isAuthenticated = false;
  bool _isAuthenticating = false;
  String? _error;
  bool _biometricsAvailable = false;
  bool _biometricsEnabled = false;

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isAuthenticating => _isAuthenticating;
  String? get error => _error;
  bool get biometricsAvailable => _biometricsAvailable;
  bool get biometricsEnabled => _biometricsEnabled;

  WalletAuthProvider() {
    _init();
  }

  Future<void> _init() async {
    await _checkBiometrics();
    await _checkAuthenticationStatus();
  }

  Future<void> _checkBiometrics() async {
    try {
      _biometricsAvailable = await _localAuth.isDeviceSupported();
      notifyListeners();
    } catch (e) {
      _biometricsAvailable = false;
      notifyListeners();
    }
  }

  Future<void> _checkAuthenticationStatus() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Check if user has wallet authentication enabled
        final userDoc = await _firestore.collection('USER').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          _biometricsEnabled = userData?['walletBiometricsEnabled'] ?? false;
        }
        _isAuthenticated = true;
      } else {
        _isAuthenticated = false;
      }
      notifyListeners();
    } catch (e) {
      _isAuthenticated = false;
      notifyListeners();
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    if (!_biometricsAvailable) {
      _error = 'Biometric authentication not available';
      notifyListeners();
      return false;
    }

    _isAuthenticating = true;
    _error = null;
    notifyListeners();

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your wallet',
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );

      _isAuthenticating = false;
      if (authenticated) {
        _isAuthenticated = true;
        _error = null;
      } else {
        _error = 'Authentication failed';
      }
      notifyListeners();
      return authenticated;
    } catch (e) {
      _isAuthenticating = false;
      _error = 'Authentication error: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> authenticateWithPassword(String password) async {
    _isAuthenticating = true;
    _error = null;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _error = 'No user logged in';
        _isAuthenticating = false;
        notifyListeners();
        return false;
      }

      // For now, we'll use a simple approach. In production, you'd want to
      // use proper password hashing and verification
      final storedPassword = await _secureStorage.read(key: 'wallet_password_${user.uid}');

      if (storedPassword == null) {
        _error = 'No password set for wallet';
        _isAuthenticating = false;
        notifyListeners();
        return false;
      }

      final authenticated = storedPassword == password;

      _isAuthenticating = false;
      if (authenticated) {
        _isAuthenticated = true;
        _error = null;
      } else {
        _error = 'Invalid password';
      }
      notifyListeners();
      return authenticated;
    } catch (e) {
      _isAuthenticating = false;
      _error = 'Authentication error: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> setWalletPassword(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _error = 'No user logged in';
        notifyListeners();
        return false;
      }

      await _secureStorage.write(
        key: 'wallet_password_${user.uid}',
        value: password,
      );

      // Update user document to indicate password is set
      await _firestore.collection('USER').doc(user.uid).update({
        'walletPasswordSet': true,
        'walletLastUpdated': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      _error = 'Failed to set password: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> enableBiometrics() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _error = 'No user logged in';
        notifyListeners();
        return false;
      }

      if (!_biometricsAvailable) {
        _error = 'Biometrics not available on this device';
        notifyListeners();
        return false;
      }

      // Authenticate first to verify the user
      final authenticated = await authenticateWithBiometrics();
      if (!authenticated) {
        return false;
      }

      // Store biometric preference
      await _secureStorage.write(
        key: 'wallet_biometrics_${user.uid}',
        value: 'enabled',
      );

      // Update user document
      await _firestore.collection('USER').doc(user.uid).update({
        'walletBiometricsEnabled': true,
        'walletLastUpdated': FieldValue.serverTimestamp(),
      });

      _biometricsEnabled = true;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to enable biometrics: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> disableBiometrics() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _error = 'No user logged in';
        notifyListeners();
        return false;
      }

      // Remove biometric preference
      await _secureStorage.delete(key: 'wallet_biometrics_${user.uid}');

      // Update user document
      await _firestore.collection('USER').doc(user.uid).update({
        'walletBiometricsEnabled': false,
        'walletLastUpdated': FieldValue.serverTimestamp(),
      });

      _biometricsEnabled = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to disable biometrics: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _error = 'No user logged in';
        notifyListeners();
        return false;
      }

      // Verify current password
      final authenticated = await authenticateWithPassword(currentPassword);
      if (!authenticated) {
        return false;
      }

      // Set new password
      await _secureStorage.write(
        key: 'wallet_password_${user.uid}',
        value: newPassword,
      );

      // Update user document
      await _firestore.collection('USER').doc(user.uid).update({
        'walletLastUpdated': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      _error = 'Failed to change password: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _error = null;
    notifyListeners();
  }

  Future<bool> resetWallet() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _error = 'No user logged in';
        notifyListeners();
        return false;
      }

      // Clear all wallet-related data
      await _secureStorage.deleteAll();

      // Update user document to remove wallet references
      await _firestore.collection('USER').doc(user.uid).update({
        'stellarPublicKey': FieldValue.delete(),
        'stellarSecretKey': FieldValue.delete(),
        'walletPasswordSet': FieldValue.delete(),
        'walletBiometricsEnabled': FieldValue.delete(),
        'walletLastUpdated': FieldValue.serverTimestamp(),
      });

      _isAuthenticated = false;
      _biometricsEnabled = false;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to reset wallet: $e';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>> getSecurityStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'error': 'No user logged in'};
      }

      final userDoc = await _firestore.collection('USER').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final hasPassword = await _secureStorage.containsKey(key: 'wallet_password_${user.uid}');
      final hasBiometrics = userData['walletBiometricsEnabled'] ?? false;

      return {
        'hasPassword': hasPassword,
        'biometricsEnabled': hasBiometrics,
        'biometricsAvailable': _biometricsAvailable,
        'isAuthenticated': _isAuthenticated,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
