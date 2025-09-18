import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationProvider extends ChangeNotifier {
  bool _notificationsEnabled = true;
  bool _transactionNotificationsEnabled = true;
  bool _marketingNotificationsEnabled = false;
  bool _systemNotificationsEnabled = true;
  bool _isInitialized = false;

  // Getters
  bool get notificationsEnabled => _notificationsEnabled;
  bool get transactionNotificationsEnabled => _transactionNotificationsEnabled;
  bool get marketingNotificationsEnabled => _marketingNotificationsEnabled;
  bool get systemNotificationsEnabled => _systemNotificationsEnabled;
  bool get isInitialized => _isInitialized;

  // Constructor
  NotificationProvider() {
    _loadSettings();
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _transactionNotificationsEnabled = prefs.getBool('transactionNotificationsEnabled') ?? true;
      _marketingNotificationsEnabled = prefs.getBool('marketingNotificationsEnabled') ?? false;
      _systemNotificationsEnabled = prefs.getBool('systemNotificationsEnabled') ?? true;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
    }
  }

  // Set notifications enabled
  Future<void> setNotificationsEnabled(bool value) async {
    if (_notificationsEnabled != value) {
      _notificationsEnabled = value;
      await _saveSettings();
      notifyListeners();
    }
  }

  // Set transaction notifications enabled
  Future<void> setTransactionNotificationsEnabled(bool value) async {
    if (_transactionNotificationsEnabled != value) {
      _transactionNotificationsEnabled = value;
      await _saveSettings();
      notifyListeners();
    }
  }

  // Set marketing notifications enabled
  Future<void> setMarketingNotificationsEnabled(bool value) async {
    if (_marketingNotificationsEnabled != value) {
      _marketingNotificationsEnabled = value;
      await _saveSettings();
      notifyListeners();
    }
  }

  // Set system notifications enabled
  Future<void> setSystemNotificationsEnabled(bool value) async {
    if (_systemNotificationsEnabled != value) {
      _systemNotificationsEnabled = value;
      await _saveSettings();
      notifyListeners();
    }
  }

  // Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notificationsEnabled', _notificationsEnabled);
      await prefs.setBool('transactionNotificationsEnabled', _transactionNotificationsEnabled);
      await prefs.setBool('marketingNotificationsEnabled', _marketingNotificationsEnabled);
      await prefs.setBool('systemNotificationsEnabled', _systemNotificationsEnabled);
    } catch (e) {
    }
  }
}