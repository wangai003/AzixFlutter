import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

// This is a placeholder file for Firebase options
// In a real app, you would generate this file using the FlutterFire CLI
// with the command: flutterfire configure

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // Web-specific Firebase configuration
    return const FirebaseOptions(
      apiKey: "AIzaSyDez-3_pVJepyOkMxvWp5IL5_-cf2fmXdk",
      authDomain: "azix-7ffe4.firebaseapp.com",
      projectId: "azix-7ffe4",
      storageBucket: "azix-7ffe4.firebasestorage.app",
      messagingSenderId: "40354643169",
      appId: "1:40354643169:web:d3cd66059540d3cb36cba0",
      measurementId: "G-D60TVF0VEK"
    );
  }
}