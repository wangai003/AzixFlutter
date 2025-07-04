import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

class SecurityProvider extends ChangeNotifier {
  bool _biometricsEnabled = false;
  bool _twoFactorEnabled = false;
  bool _autoBackupEnabled = true;
  bool _isInitialized = false;
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  List<BiometricType> _availableBiometrics = [];

  // Getters
  bool get biometricsEnabled => _biometricsEnabled;
  bool get twoFactorEnabled => _twoFactorEnabled;
  bool get autoBackupEnabled => _autoBackupEnabled;
  bool get isInitialized => _isInitialized;
  bool get canCheckBiometrics => _canCheckBiometrics;
  List<BiometricType> get availableBiometrics => _availableBiometrics;

  // Constructor
  SecurityProvider() {
    _loadSettings();
    _checkBiometrics();
  }

  // Check if device supports biometrics
  Future<void> _checkBiometrics() async {
    try {
      _canCheckBiometrics = await _localAuth.canCheckBiometrics;
      if (_canCheckBiometrics) {
        _availableBiometrics = await _localAuth.getAvailableBiometrics();
      }
      notifyListeners();
    } catch (e) {
      print('Error checking biometrics: $e');
    }
  }

  // Authenticate with biometrics
  Future<bool> authenticateWithBiometrics() async {
    if (!_canCheckBiometrics || !_biometricsEnabled) {
      return false;
    }

    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access secure features',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      print('Error authenticating with biometrics: $e');
      return false;
    }
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _biometricsEnabled = prefs.getBool('biometricsEnabled') ?? false;
      _twoFactorEnabled = prefs.getBool('twoFactorEnabled') ?? false;
      _autoBackupEnabled = prefs.getBool('autoBackupEnabled') ?? true;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('Error loading security settings: $e');
    }
  }

  // Set biometrics enabled
  Future<void> setBiometricsEnabled(bool value) async {
    if (_biometricsEnabled != value) {
      // If enabling biometrics, check if device supports it
      if (value && !_canCheckBiometrics) {
        return;
      }
      
      _biometricsEnabled = value;
      await _saveSettings();
      notifyListeners();
    }
  }

  // Set two-factor authentication enabled
  Future<void> setTwoFactorEnabled(bool value) async {
    if (_twoFactorEnabled != value) {
      _twoFactorEnabled = value;
      await _saveSettings();
      notifyListeners();
    }
  }

  // Set auto backup enabled
  Future<void> setAutoBackupEnabled(bool value) async {
    if (_autoBackupEnabled != value) {
      _autoBackupEnabled = value;
      await _saveSettings();
      notifyListeners();
    }
  }

  // Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometricsEnabled', _biometricsEnabled);
      await prefs.setBool('twoFactorEnabled', _twoFactorEnabled);
      await prefs.setBool('autoBackupEnabled', _autoBackupEnabled);
    } catch (e) {
      print('Error saving security settings: $e');
    }
  }

  // Clear app cache
  Future<bool> clearCache() async {
    try {
      // In a real app, you would implement actual cache clearing logic here
      // For example, clearing image cache, database cache, etc.
      
      // Simulate cache clearing with a delay
      await Future.delayed(const Duration(seconds: 1));
      return true;
    } catch (e) {
      print('Error clearing cache: $e');
      return false;
    }
  }

  // Export user data
  Future<bool> exportUserData() async {
    try {
      // In a real app, you would implement actual data export logic here
      // For example, exporting user data to a file, cloud storage, etc.
      
      // Simulate data export with a delay
      await Future.delayed(const Duration(seconds: 2));
      return true;
    } catch (e) {
      print('Error exporting user data: $e');
      return false;
    }
  }
}