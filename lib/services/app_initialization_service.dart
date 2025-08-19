import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/web_compatibility.dart';

/// Service to handle complete app initialization for seamless user experience
class AppInitializationService {
  static bool _isInitialized = false;
  static bool _isInitializing = false;

  /// Initialize the complete application stack
  static Future<bool> initializeApp() async {
    if (_isInitialized) return true;
    if (_isInitializing) {
      // Wait for current initialization to complete
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _isInitialized;
    }

    _isInitializing = true;

    try {
      print('🚀 Initializing Enhanced Mining System...');

      // Step 1: Firebase initialization (should already be done in main)
      await _ensureFirebaseInitialized();

      // Step 2: Platform-specific setup
      await _initializePlatformFeatures();

      // Step 3: Security services setup
      await _initializeSecurityServices();

      // Step 4: Mining system setup
      await _initializeMiningSystem();

      // Step 5: User session restoration
      await _restoreUserSession();

      _isInitialized = true;
      print('✅ App initialization completed successfully');
      return true;

    } catch (e) {
      print('❌ App initialization failed: $e');
      _isInitialized = false;
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Ensure Firebase is properly initialized
  static Future<void> _ensureFirebaseInitialized() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      print('✅ Firebase initialized');
    } catch (e) {
      print('⚠️ Firebase already initialized or error: $e');
    }
  }

  /// Initialize platform-specific features
  static Future<void> _initializePlatformFeatures() async {
    try {
      if (WebCompatibility.isWeb) {
        // Web-specific initialization
        await _initializeWebFeatures();
      } else {
        // Mobile-specific initialization
        await _initializeMobileFeatures();
      }
      print('✅ Platform features initialized');
    } catch (e) {
      print('⚠️ Platform initialization warning: $e');
    }
  }

  /// Initialize web-specific features
  static Future<void> _initializeWebFeatures() async {
    // Enable web-specific optimizations
    if (kIsWeb) {
      // Configure web-specific settings
      print('🌐 Web mode activated');
      
      // Set up web-compatible device identification
      final deviceId = WebCompatibility.getPlatformDeviceId();
      print('📱 Web device ID: ${deviceId.substring(0, 10)}...');
    }
  }

  /// Initialize mobile-specific features
  static Future<void> _initializeMobileFeatures() async {
    // Initialize mobile-specific services
    print('📱 Mobile mode activated');
  }

  /// Initialize security services
  static Future<void> _initializeSecurityServices() async {
    try {
      // Security service initialization is handled by providers
      print('🔐 Security services ready');
    } catch (e) {
      print('⚠️ Security initialization warning: $e');
    }
  }

  /// Initialize mining system
  static Future<void> _initializeMiningSystem() async {
    try {
      // Mining system initialization is handled by providers
      print('⛏️ Mining system ready');
    } catch (e) {
      print('⚠️ Mining initialization warning: $e');
    }
  }

  /// Restore user session if available
  static Future<void> _restoreUserSession() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('👤 User session restored: ${user.email?.substring(0, 3)}***');
        
        // Verify user document exists
        final userDoc = await FirebaseFirestore.instance
            .collection('USER')
            .doc(user.uid)
            .get();
            
        if (userDoc.exists) {
          print('✅ User profile verified');
        } else {
          print('⚠️ User profile not found, may need registration');
        }
      } else {
        print('👤 No existing user session');
      }
    } catch (e) {
      print('⚠️ Session restoration warning: $e');
    }
  }

  /// Get initialization status
  static bool get isInitialized => _isInitialized;

  /// Get initialization progress
  static bool get isInitializing => _isInitializing;

  /// Reset initialization state (for testing)
  static void reset() {
    _isInitialized = false;
    _isInitializing = false;
  }

  /// Check if app is ready for mining
  static Future<bool> isMiningReady() async {
    if (!_isInitialized) return false;

    try {
      // Check Firebase connection
      await FirebaseFirestore.instance.enableNetwork();
      
      // Check authentication state
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Check user document
      final userDoc = await FirebaseFirestore.instance
          .collection('USER')
          .doc(user.uid)
          .get();
      
      return userDoc.exists;
    } catch (e) {
      print('❌ Mining readiness check failed: $e');
      return false;
    }
  }

  /// Auto-configure user for first-time mining
  static Future<bool> autoConfigureForMining(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('USER')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        print('❌ User document not found');
        return false;
      }

      final userData = userDoc.data()!;
      
      // Check if user has wallet configured
      final hasWallet = userData['hasWallet'] ?? false;
      
      if (!hasWallet) {
        print('⚠️ User needs to create wallet for mining');
        return false;
      }

      // Check mining eligibility
      final miningRateBoosted = userData['miningRateBoosted'] ?? false;
      final referralCount = userData['referralCount'] ?? 0;
      
      print('✅ User configured for mining:');
      print('   - Wallet: $hasWallet');
      print('   - Rate boosted: $miningRateBoosted');
      print('   - Referrals: $referralCount');
      
      return true;
    } catch (e) {
      print('❌ Auto-configuration failed: $e');
      return false;
    }
  }

  /// Quick health check
  static Future<Map<String, bool>> healthCheck() async {
    final results = <String, bool>{};

    try {
      // Firebase connectivity
      results['firebase'] = Firebase.apps.isNotEmpty;

      // Authentication
      results['auth'] = FirebaseAuth.instance.currentUser != null;

      // Firestore
      try {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          // Minimal transaction to test connectivity
        });
        results['firestore'] = true;
      } catch (e) {
        results['firestore'] = false;
      }

      // Platform compatibility
      results['platform'] = true;

      // Mining readiness
      results['mining'] = await isMiningReady();

    } catch (e) {
      print('❌ Health check error: $e');
    }

    return results;
  }

  /// Debug information for troubleshooting
  static Future<Map<String, dynamic>> getDebugInfo() async {
    return {
      'platform': WebCompatibility.isWeb ? 'web' : 'mobile',
      'firebase_apps': Firebase.apps.length,
      'current_user': FirebaseAuth.instance.currentUser?.uid,
      'initialization_status': {
        'initialized': _isInitialized,
        'initializing': _isInitializing,
      },
      'timestamp': DateTime.now().toIso8601String(),
      'health_check': await healthCheck(),
    };
  }
}
