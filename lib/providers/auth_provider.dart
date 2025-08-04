import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;
  String? _error;

  // Store if the user is new after Google sign-in
  bool _isNewUser = false;
  bool get isNewUser => _isNewUser;

  // Store the user UID for referral code submission
  String? _pendingUserUid;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;
  AuthService get authService => _authService;

  // Constructor
  AuthProvider() {
    // Delay initialization to ensure Firebase is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
    });
  }

  // Initialize the provider
  void _init() {
    try {
      _user = _authService.currentUser;
      _authService.authStateChanges.listen((User? user) {
        _user = user;
        notifyListeners();
      });
    } catch (e) {
      print('DEBUG: Error initializing AuthProvider: $e');
      // Don't crash the app, just log the error
    }
  }

  // Set loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Set error
  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Sign in with email and password
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _setError(null);
    
    try {
      await _authService.signInWithEmailAndPassword(email, password);
      final user = _authService.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        _setLoading(false);
        _setError('Please verify your email address. A verification link has been sent.');
        return false;
      }
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      
      switch (e.code) {
        case 'user-not-found':
          _setError('No user found with this email.');
          break;
        case 'wrong-password':
          _setError('Wrong password provided.');
          break;
        case 'invalid-email':
          _setError('The email address is not valid.');
          break;
        case 'user-disabled':
          _setError('This user has been disabled.');
          break;
        default:
          _setError('An error occurred: ${e.message}');
      }
      
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('An unexpected error occurred.');
      return false;
    }
  }

  // Register with email and password
  Future<bool> register(String email, String password, String name, {String? referralCode}) async {
    _setLoading(true);
    _setError(null);
    
    try {
      await _authService.registerWithEmailAndPassword(email, password, name, '', referralCode: referralCode);
      final user = _authService.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        _setLoading(false);
        _setError('Please verify your email address. A verification link has been sent.');
        return false;
      }
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      
      switch (e.code) {
        case 'email-already-in-use':
          _setError('The email address is already in use.');
          break;
        case 'invalid-email':
          _setError('The email address is not valid.');
          break;
        case 'weak-password':
          _setError('The password is too weak.');
          break;
        case 'operation-not-allowed':
          _setError('Email/password accounts are not enabled.');
          break;
        default:
          _setError('An error occurred: ${e.message}');
      }
      
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('An unexpected error occurred.');
      return false;
    }
  }

  // Check Firestore verification status
  Future<Map<String, bool>> getFirestoreVerificationStatus(String uid) async {
    try {
      final doc = await _authService.getUserDetails(uid);
      return {
        'isEmailVerified': doc?['isEmailVerified'] == true,
        'isPhoneVerified': doc?['isPhoneVerified'] == true,
      };
    } catch (e) {
      return {'isEmailVerified': false, 'isPhoneVerified': false};
    }
  }

  // Update Firestore verification status
  Future<void> setFirestoreVerificationStatus(String uid, {bool? email, bool? phone}) async {
    final data = <String, dynamic>{};
    if (email != null) data['isEmailVerified'] = email;
    if (phone != null) data['isPhoneVerified'] = phone;
    await _authService.updateUserFields(uid, data);
  }

  // Sign out
  Future<void> signOut() async {
    _setLoading(true);
    try {
      final user = _authService.currentUser;
      if (user != null) {
        print('DEBUG: Signing out user ${user.uid}, resetting verification status');
        await setFirestoreVerificationStatus(user.uid, email: false, phone: false);
        print('DEBUG: Verification status reset to false for user ${user.uid}');
      }
      await _authService.signOut();
      print('DEBUG: User signed out successfully');
    } catch (e) {
      print('DEBUG: Error during sign out: $e');
      _setError('Failed to sign out.');
    } finally {
      _setLoading(false);
    }
  }

  // Reset verification status when session ends (for session expiration, app closure, etc.)
  Future<void> resetVerificationStatusOnSessionEnd() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        print('DEBUG: Session ended for user ${user.uid}, resetting verification status');
        await setFirestoreVerificationStatus(user.uid, email: false, phone: false);
        print('DEBUG: Verification status reset due to session end for user ${user.uid}');
      }
    } catch (e) {
      print('DEBUG: Error resetting verification status on session end: $e');
    }
  }

  // Handle token refresh and session expiration
  Future<void> handleTokenRefresh() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        print('DEBUG: Token refreshed for user ${user.uid}, checking if verification status should be reset');
        // Check if the user has been inactive for too long (optional enhancement)
        // For now, we'll reset verification status on token refresh to ensure security
        await setFirestoreVerificationStatus(user.uid, email: false, phone: false);
        print('DEBUG: Verification status reset due to token refresh for user ${user.uid}');
      }
    } catch (e) {
      print('DEBUG: Error handling token refresh: $e');
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _setError(null);
    
    try {
      await _authService.resetPassword(email);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      
      switch (e.code) {
        case 'invalid-email':
          _setError('The email address is not valid.');
          break;
        case 'user-not-found':
          _setError('No user found with this email.');
          break;
        default:
          _setError('An error occurred: ${e.message}');
      }
      
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('An unexpected error occurred.');
      return false;
    }
  }
  
  // Sign in with Google and check if new user
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _setError(null);
    try {
      final result = await _authService.signInWithGoogle();
      final user = _authService.currentUser;
      
      if (user != null) {
        // For Google sign-in users, always set isEmailVerified to false in Firestore
        // This ensures they must go through our app's verification process
        await setFirestoreVerificationStatus(user.uid, email: false, phone: false);
        
        // Check if user doc was just created (i.e., new user)
        final userDoc = await _authService.getUserDetails(user.uid);
        // If userDoc has only minimal fields, treat as new user
        if (userDoc != null && userDoc['referralCode'] == null) {
          _isNewUser = true;
          _pendingUserUid = user.uid;
        } else {
          _isNewUser = false;
          _pendingUserUid = null;
        }
      }
      
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      _setError('Authentication failed: ${e.message}');
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('An unexpected error occurred during Google Sign-In.');
      print('Google Sign-In error: $e');
      return false;
    }
  }

  // Submit referral code for new user after Google sign-in
  Future<bool> submitReferralCode(String? referralCode) async {
    if (_pendingUserUid == null) return false;
    _setLoading(true);
    try {
      await _authService.completeGoogleUserRegistration(_pendingUserUid!, '', referralCode: referralCode);
      _isNewUser = false;
      _pendingUserUid = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to apply referral code.');
      return false;
    }
  }

  // Register with email and password (enhanced version with phone)
  Future<bool> registerWithEmailAndPassword(String email, String password, String name, String phoneNumber, {String? referralCode}) async {
    _setLoading(true);
    _setError(null);
    
    try {
      await _authService.registerWithEmailAndPassword(email, password, name, phoneNumber, referralCode: referralCode);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      
      switch (e.code) {
        case 'email-already-in-use':
          _setError('The email address is already in use.');
          break;
        case 'invalid-email':
          _setError('The email address is not valid.');
          break;
        case 'weak-password':
          _setError('The password is too weak.');
          break;
        case 'operation-not-allowed':
          _setError('Email/password accounts are not enabled.');
          break;
        default:
          _setError('An error occurred: ${e.message}');
      }
      
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('An unexpected error occurred: $e');
      return false;
    }
  }

  // Complete Google user registration
  Future<bool> completeGoogleUserRegistration(String uid, String phoneNumber, {String? referralCode}) async {
    _setLoading(true);
    _setError(null);
    
    try {
      await _authService.completeGoogleUserRegistration(uid, phoneNumber, referralCode: referralCode);
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to complete registration: $e');
      return false;
    }
  }

  // Check if user needs registration
  Future<bool> needsRegistration(String uid) async {
    try {
      return await _authService.needsRegistration(uid);
    } catch (e) {
      return true;
    }
  }

  // Check if user exists in USER collection
  Future<bool> userExistsInCollection(String uid) async {
    try {
      return await _authService.userExistsInCollection(uid);
    } catch (e) {
      return false;
    }
  }

  // Check if user has completed registration
  Future<bool> hasCompletedRegistration(String uid) async {
    try {
      return await _authService.hasCompletedRegistration(uid);
    } catch (e) {
      return false;
    }
  }
}