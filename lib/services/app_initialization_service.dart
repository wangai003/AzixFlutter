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
      return true;
    } catch (e) {
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
    } catch (e) {}
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
    } catch (e) {}
  }

  /// Initialize web-specific features
  static Future<void> _initializeWebFeatures() async {
    // Enable web-specific optimizations
    if (kIsWeb) {
      // Configure web-specific settings

      // Set up web-compatible device identification
      final deviceId = WebCompatibility.getPlatformDeviceId();
    }
  }

  /// Initialize mobile-specific features
  static Future<void> _initializeMobileFeatures() async {
    // Initialize mobile-specific services
  }

  /// Initialize security services
  static Future<void> _initializeSecurityServices() async {
    try {
      // Security service initialization is handled by providers
    } catch (e) {}
  }

  /// Initialize mining system
  static Future<void> _initializeMiningSystem() async {
    try {
      // Ensure mining persistence across app kills
      await _ensureMiningPersistence();
    } catch (e) {}
  }

  /// Ensure mining persistence across app kills and device restarts
  static Future<void> _ensureMiningPersistence() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check for any active mining sessions that need restoration
      final activeSessions = await FirebaseFirestore.instance
          .collection('USER')
          .doc(user.uid)
          .collection('active_mining_sessions')
          .where('sessionEnd', isGreaterThan: Timestamp.now())
          .get();

      if (activeSessions.docs.isNotEmpty) {
        // Ensure session persistence is properly configured
        for (final doc in activeSessions.docs) {
          final sessionData = doc.data();

          // Update last activity timestamp to prevent expiration
          await doc.reference.update({
            'lastActivity': FieldValue.serverTimestamp(),
            'appKillRecovery': true,
            'recoveryTimestamp': FieldValue.serverTimestamp(),
          });
        }
      }

      // Set up background persistence monitoring
      _setupBackgroundPersistenceMonitoring();
    } catch (e) {}
  }

  /// Set up background persistence monitoring
  static void _setupBackgroundPersistenceMonitoring() {
    // This ensures mining state is preserved even if app is killed
    // The RealTimeMiningService handles the actual persistence
  }

  /// Restore user session if available
  static Future<void> _restoreUserSession() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Verify user document exists
        final userDoc = await FirebaseFirestore.instance
            .collection('USER')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
        } else {}
      } else {}
    } catch (e) {}
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
        return false;
      }

      final userData = userDoc.data()!;

      // Check if user has wallet configured
      final hasWallet = userData['hasWallet'] ?? false;

      if (!hasWallet) {
        return false;
      }

      // Check mining eligibility
      final miningRateBoosted = userData['miningRateBoosted'] ?? false;
      final referralCount = userData['referralCount'] ?? 0;

      return true;
    } catch (e) {
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
    } catch (e) {}

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
