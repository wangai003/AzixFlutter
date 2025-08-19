import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart' as local_auth;

enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final local_auth.AuthService _authService = local_auth.AuthService();
  
  AuthState _authState = AuthState.initial;
  User? _user;
  String? _error;
  bool _isLoading = false;

  AuthState get authState => _authState;
  User? get user => _user;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  local_auth.AuthService get authService => _authService;

  AuthProvider() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      if (user != null) {
        _authState = AuthState.authenticated;
        _error = null;
      } else {
        _authState = AuthState.unauthenticated;
      }
      notifyListeners();
    });
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Sign in with email and password
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    _setLoading(true);
    _setError(null);
    
    try {
      final userCredential = await _authService.signInWithEmailAndPassword(email, password);
      final user = userCredential.user;
      
      if (user != null) {
        // Check if user document exists
        final userDoc = await _authService.getUserDocument(user.uid);
        
        if (userDoc == null) {
          // Create complete user document
          await _authService.createCompleteUserDocument(
            user.uid,
            email: email,
            displayName: user.displayName,
            phoneNumber: null, // Will be completed in registration screen
            role: 'user',
          );
        }
        
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found with this email address.';
          break;
        case 'wrong-password':
          message = 'Wrong password provided.';
          break;
        case 'invalid-email':
          message = 'The email address is not valid.';
          break;
        case 'user-disabled':
          message = 'This user account has been disabled.';
          break;
        default:
          message = 'An error occurred: ${e.message}';
      }
      _setError(message);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign up with email and password
  Future<bool> signUpWithEmailAndPassword(String email, String password, String name) async {
    _setLoading(true);
    _setError(null);
    
    try {
      final userCredential = await _authService.createUserWithEmailAndPassword(email, password);
      final user = userCredential.user;
      
      if (user != null) {
        // Update display name
        await user.updateDisplayName(name);
        
        // Send email verification
        await _authService.sendEmailVerification();
        
        // Create complete user document in Firestore
        await _authService.createCompleteUserDocument(
          user.uid,
          email: email,
          displayName: name,
          phoneNumber: null, // Will be completed in registration screen
          role: 'user',
        );
        
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'The email address is already in use.';
          break;
        case 'invalid-email':
          message = 'The email address is not valid.';
          break;
        case 'weak-password':
          message = 'The password is too weak.';
          break;
        default:
          message = 'An error occurred: ${e.message}';
      }
      _setError(message);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _setError(null);
    
    try {
      final userCredential = await _authService.signInWithGoogle();
      final user = userCredential.user;
      
      if (user != null) {
        // Check if user document exists
        final userDoc = await _authService.getUserDocument(user.uid);
        
        if (userDoc == null) {
          // Create complete user document for new Google user
          await _authService.createCompleteUserDocument(
            user.uid,
            email: user.email ?? '',
            displayName: user.displayName ?? '',
            photoURL: user.photoURL,
            phoneNumber: null, // Will be completed in registration screen
            role: 'user',
          );
        } else {
          // Update last login for existing user
          await _authService.updateUserFields(user.uid, {
            'lastLoginAt': FieldValue.serverTimestamp(),
          });
        }
        
        return true;
      }
      return false;
    } catch (e) {
      _setError('Google sign-in failed: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Handle redirect result for web
  Future<bool> handleRedirectResult() async {
    try {
      final userCredential = await _authService.handleRedirectResult();
      if (userCredential != null) {
        final user = userCredential.user;
        if (user != null) {
          // Check if user document exists
          final userDoc = await _authService.getUserDocument(user.uid);
          
          if (userDoc == null) {
            // Create complete user document for new Google user
            await _authService.createCompleteUserDocument(
              user.uid,
              email: user.email ?? '',
              displayName: user.displayName ?? '',
              photoURL: user.photoURL,
              phoneNumber: null, // Will be completed in registration screen
              role: 'user',
            );
          } else {
            // Update last login for existing user
            await _authService.updateUserFields(user.uid, {
              'lastLoginAt': FieldValue.serverTimestamp(),
            });
          }
          
          return true;
        }
      }
      return false;
    } catch (e) {
      _setError('Failed to handle redirect result: ${e.toString()}');
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      _setError('Failed to sign out: ${e.toString()}');
    }
  }

  // Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (e) {
      _setError('Failed to send password reset email: ${e.toString()}');
      return false;
    }
  }

  // Send email verification
  Future<bool> sendEmailVerification() async {
    try {
      await _authService.sendEmailVerification();
      return true;
    } catch (e) {
      _setError('Failed to send verification email: ${e.toString()}');
      return false;
    }
  }

  // Check if user needs email verification
  Future<bool> needsEmailVerification() async {
    if (_user == null) return false;
    
    try {
      return await _authService.needsEmailVerification(_user!.uid);
    } catch (e) {
      print('Error checking email verification: $e');
      return false;
    }
  }

  // Check if user needs profile completion
  Future<bool> needsProfileCompletion() async {
    if (_user == null) return false;
    
    try {
      return await _authService.needsRegistration(_user!.uid);
    } catch (e) {
      return false;
    }
  }

  // Mark profile as complete
  Future<void> markProfileComplete() async {
    if (_user == null) return;
    
    try {
      await _authService.updateUserFields(_user!.uid, {
        'needsProfileCompletion': false,
      });
    } catch (e) {
      _setError('Failed to update profile: ${e.toString()}');
    }
  }

  // Complete Google user registration
  Future<bool> completeGoogleUserRegistration(String phoneNumber, {String? referralCode}) async {
    if (_user == null) return false;
    
    try {
      await _authService.completeGoogleUserRegistration(_user!.uid, phoneNumber, referralCode: referralCode);
      return true;
    } catch (e) {
      _setError('Failed to complete registration: ${e.toString()}');
      return false;
    }
  }

  // Check if user is admin
  Future<bool> isUserAdmin() async {
    if (_user == null) return false;
    
    try {
      return await _authService.isUserAdmin(_user!.uid);
    } catch (e) {
      return false;
    }
  }

  // Update user role (admin only)
  Future<bool> updateUserRole(String newRole) async {
    if (_user == null) return false;
    
    try {
      await _authService.updateUserRole(_user!.uid, newRole);
      return true;
    } catch (e) {
      _setError('Failed to update user role: ${e.toString()}');
      return false;
    }
  }

  // Refresh user data
  Future<void> refreshUserData() async {
    if (_user != null) {
      // Trigger a refresh by notifying listeners
      notifyListeners();
    }
  }
}