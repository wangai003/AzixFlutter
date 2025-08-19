import 'package:flutter/foundation.dart';

/// Web compatibility utilities for the enhanced mining system
class WebCompatibility {
  
  /// Check if running on web platform
  static bool get isWeb => kIsWeb;
  
  /// Check if device info is available (limited on web)
  static bool get hasDeviceInfo => !kIsWeb;
  
  /// Get platform-appropriate device ID
  static String getPlatformDeviceId() {
    if (kIsWeb) {
      // For web, use browser fingerprinting approach
      return _generateWebDeviceId();
    } else {
      // For mobile, use actual device ID
      return 'mobile_device';
    }
  }
  
  /// Generate a web-compatible device ID
  static String _generateWebDeviceId() {
    // Use a combination of browser properties for consistent ID
    final userAgent = 'web_browser';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp % 100000;
    
    return 'web_${userAgent}_$random';
  }
  
  /// Check if biometric authentication is available
  static bool get hasBiometrics => !kIsWeb;
  
  /// Check if local notifications are supported
  static bool get hasNotifications => !kIsWeb;
  
  /// Check if background processing is available
  static bool get hasBackgroundProcessing => !kIsWeb;
  
  /// Get platform-specific storage limitations
  static Map<String, dynamic> get storageLimits => {
    'maxSessionData': kIsWeb ? 5 * 1024 * 1024 : 50 * 1024 * 1024, // 5MB web, 50MB mobile
    'maxHistory': kIsWeb ? 100 : 1000, // 100 sessions web, 1000 mobile
    'maxProofData': kIsWeb ? 1000 : 10000, // Proof storage limits
  };
  
  /// Platform-appropriate initialization delays
  static Duration get initializationDelay => kIsWeb 
    ? const Duration(milliseconds: 500) 
    : const Duration(milliseconds: 100);
  
  /// Check if crypto operations are supported efficiently
  static bool get hasHardwareCrypto => !kIsWeb;
  
  /// Platform-appropriate mining intervals
  static Duration get miningProofInterval => kIsWeb
    ? const Duration(seconds: 120) // Longer interval for web
    : const Duration(seconds: 60);  // Normal interval for mobile
  
  /// Web-safe error handling
  static void handleWebError(dynamic error, {String? context}) {
    if (kIsWeb) {
      // Web-specific error handling
      print('Web Error${context != null ? ' in $context' : ''}: $error');
      // Could send to web analytics here
    } else {
      // Mobile error handling
      print('Mobile Error${context != null ? ' in $context' : ''}: $error');
    }
  }
  
  /// Check if feature is supported on current platform
  static bool isFeatureSupported(String feature) {
    switch (feature) {
      case 'device_fingerprinting':
        return true; // Supported on both platforms
      case 'background_sync':
        return !kIsWeb; // Only mobile
      case 'push_notifications':
        return !kIsWeb; // Only mobile
      case 'biometric_auth':
        return !kIsWeb; // Only mobile
      case 'crypto_operations':
        return true; // Both platforms support crypto
      case 'local_storage':
        return true; // Both platforms have storage
      default:
        return false;
    }
  }
  
  /// Get platform-specific configuration
  static Map<String, dynamic> get platformConfig => {
    'platform': kIsWeb ? 'web' : 'mobile',
    'crypto_provider': kIsWeb ? 'web_crypto' : 'dart_crypto',
    'storage_provider': kIsWeb ? 'web_storage' : 'device_storage',
    'max_session_duration': const Duration(hours: 24),
    'proof_validation_interval': miningProofInterval,
    'ui_update_interval': const Duration(seconds: 1),
    'security_check_interval': const Duration(minutes: 5),
  };
}
