import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true;
  String _language = 'English';
  String _currency = 'USD';
  bool _isInitialized = false;

  // Getters
  bool get isDarkMode => _isDarkMode;
  String get language => _language;
  String get currency => _currency;
  bool get isInitialized => _isInitialized;
  ThemeData get currentTheme => _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;

  // Constructor
  ThemeProvider() {
    _loadSettings();
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('isDarkMode') ?? true;
      _language = prefs.getString('language') ?? 'English';
      _currency = prefs.getString('currency') ?? 'USD';
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('Error loading theme settings: $e');
    }
  }

  // Toggle theme
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _saveSettings();
    notifyListeners();
  }

  // Set dark mode
  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode != value) {
      _isDarkMode = value;
      await _saveSettings();
      notifyListeners();
    }
  }

  // Set language
  Future<void> setLanguage(String value) async {
    if (_language != value) {
      _language = value;
      await _saveSettings();
      notifyListeners();
    }
  }

  // Set currency
  Future<void> setCurrency(String value) async {
    if (_currency != value) {
      _currency = value;
      await _saveSettings();
      notifyListeners();
    }
  }

  // Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);
      await prefs.setString('language', _language);
      await prefs.setString('currency', _currency);
    } catch (e) {
      print('Error saving theme settings: $e');
    }
  }
}