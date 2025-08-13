import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // Sign up with email and password
  Future<UserCredential> createUserWithEmailAndPassword(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  // Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Clear any existing auth state
      await _auth.signOut();
      await Future.delayed(const Duration(milliseconds: 500));
      
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.setCustomParameters({
        'prompt': 'select_account',
        'access_type': 'offline',
      });

      if (kIsWeb) {
        // For web, use redirect
        await _auth.signInWithRedirect(googleProvider);
        final result = await _auth.getRedirectResult();
        if (result == null) {
          throw Exception('Failed to get redirect result');
        }
        return result;
      } else {
        // For mobile, use popup
        return await _auth.signInWithPopup(googleProvider);
      }
    } catch (e) {
      if (e is FirebaseAuthException && e.code == 'missing-or-invalid-nonce') {
        throw Exception('Authentication session expired. Please try again.');
      }
      rethrow;
    }
  }

  // Handle redirect result for web
  Future<UserCredential?> handleRedirectResult() async {
    if (!kIsWeb) return null;
    return await _auth.getRedirectResult();
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.sendEmailVerification();
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Update user profile
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updateDisplayName(displayName);
      await user.updatePhotoURL(photoURL);
    }
  }

  // Get user document from Firestore
  Future<Map<String, dynamic>?> getUserDocument(String uid) async {
    try {
      final doc = await _firestore.collection('USER').doc(uid).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      print('Error getting user document: $e');
      return null;
    }
  }

  // Create or update user document
  Future<void> setUserDocument(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('USER').doc(uid).set(data, SetOptions(merge: true));
    } catch (e) {
      print('Error setting user document: $e');
      rethrow;
    }
  }

  // Update specific user fields
  Future<void> updateUserFields(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('USER').doc(uid).update(data);
    } catch (e) {
      print('Error updating user fields: $e');
      rethrow;
    }
  }

  // Check if user document exists
  Future<bool> userDocumentExists(String uid) async {
    try {
      final doc = await _firestore.collection('USER').doc(uid).get();
      return doc.exists;
    } catch (e) {
      print('Error checking user document: $e');
      return false;
    }
  }

  // Generate unique referral code
  Future<String> _generateUniqueReferralCode() async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    const length = 8;
    
    while (true) {
      final code = String.fromCharCodes(
        Iterable.generate(length, (_) => chars.codeUnitAt(Random().nextInt(chars.length)))
      );
      
      // Check if code already exists
      final query = await _firestore
          .collection('USER')
          .where('referralCode', isEqualTo: code)
          .limit(1)
          .get();
      
      if (query.docs.isEmpty) {
        return code;
      }
    }
  }

  // Generate unique AKOFA tag
  Future<String> _generateUniqueAkofaTag() async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    const length = 6;
    
    while (true) {
      final tag = String.fromCharCodes(
        Iterable.generate(length, (_) => chars.codeUnitAt(Random().nextInt(chars.length)))
      );
      
      // Check if tag already exists
      final query = await _firestore
          .collection('USER')
          .where('akofaTag', isEqualTo: tag)
          .limit(1)
          .get();
      
      if (query.docs.isEmpty) {
        return tag;
      }
    }
  }

  // Create complete user document with all required fields
  Future<void> createCompleteUserDocument(String uid, {
    required String email,
    String? displayName,
    String? photoURL,
    String? phoneNumber,
    String? referralCode,
    String role = 'user',
  }) async {
    try {
      // Generate unique referral code and AKOFA tag
      final generatedReferralCode = await _generateUniqueReferralCode();
      final generatedAkofaTag = await _generateUniqueAkofaTag();
      
      // Create complete user document structure
      final userData = {
        'email': email,
        'displayName': displayName ?? '',
        'photoURL': photoURL,
        'phoneNumber': phoneNumber,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'isEmailVerified': false,
        'needsProfileCompletion': true,
        'profileCompletedAt': null,
        
        // Wallet and Stellar integration
        'stellarPublicKey': null,
        'hasWallet': false,
        'akofaBalance': 0.0,
        'pendingBalance': 0.0,
        
        // Mining system integration
        'totalMiningSessions': 0,
        'totalEarnings': 0.0,
        'miningRateBoosted': false,
        
        // Referral system
        'referralCode': generatedReferralCode,
        'akofaTag': generatedAkofaTag,
        'referredBy': null,
        'referrals': [],
        'referralCount': 0,
        
        // Additional fields
        'preferences': {},
        'notificationSettings': ['email', 'push'],
        'profile': {
          'communitiesJoined': 0,
          'bio': '',
          'location': '',
          'website': '',
        },
      };

      // Handle referral if provided
      if (referralCode != null && referralCode.isNotEmpty) {
        try {
          final refQuery = await _firestore
              .collection('USER')
              .where('referralCode', isEqualTo: referralCode)
              .limit(1)
              .get();
          
          if (refQuery.docs.isNotEmpty) {
            final referrerDoc = refQuery.docs.first;
            
            // Don't allow self-referral
            if (referrerDoc.id != uid) {
              userData['referredBy'] = referrerDoc.id;

              // Update referrer's data
              await _firestore.runTransaction((transaction) async {
                final snapshot = await transaction.get(referrerDoc.reference);
                if (snapshot.exists) {
                  final data = snapshot.data() as Map<String, dynamic>;
                  final referrals = List<String>.from(data['referrals'] ?? []);
                  if (!referrals.contains(uid)) {
                    referrals.add(uid);
                    final referralCount = (data['referralCount'] ?? 0) + 1;
                    final miningRateBoosted = referralCount >= 5;
                    
                    transaction.update(referrerDoc.reference, {
                      'referrals': referrals,
                      'referralCount': referralCount,
                      'miningRateBoosted': miningRateBoosted,
                    });
                  }
                }
              });
            }
          }
        } catch (e) {
          print('Referral processing error: $e');
          // Continue without referral if there's an error
        }
      }

      // Create the user document
      await _firestore.collection('USER').doc(uid).set(userData);
      
      print('Complete user document created successfully for: $uid');
    } catch (e) {
      print('User document creation error: $e');
      rethrow;
    }
  }

  // Complete Google user registration with full user data
  Future<void> completeGoogleUserRegistration(String uid, String phoneNumber, {String? referralCode}) async {
    try {
      // Get existing user data
      final userDoc = await getUserDocument(uid);
      if (userDoc == null) {
        throw Exception('User document not found');
      }

      // Generate unique referral code and AKOFA tag if not already present
      String referralCodeToUse = userDoc['referralCode'] ?? await _generateUniqueReferralCode();
      String akofaTagToUse = userDoc['akofaTag'] ?? await _generateUniqueAkofaTag();
      
      // Prepare user data updates
      final userData = {
        'phoneNumber': phoneNumber,
        'referralCode': referralCodeToUse,
        'akofaTag': akofaTagToUse,
        'needsProfileCompletion': false,
        'profileCompletedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      };

      // Handle referral if provided
      if (referralCode != null && referralCode.isNotEmpty) {
        try {
          final refQuery = await _firestore
              .collection('USER')
              .where('referralCode', isEqualTo: referralCode)
              .limit(1)
              .get();
          
          if (refQuery.docs.isNotEmpty) {
            final referrerDoc = refQuery.docs.first;
            
            // Don't allow self-referral
            if (referrerDoc.id != uid) {
              userData['referredBy'] = referrerDoc.id;

              // Update referrer's data
              await _firestore.runTransaction((transaction) async {
                final snapshot = await transaction.get(referrerDoc.reference);
                if (snapshot.exists) {
                  final data = snapshot.data() as Map<String, dynamic>;
                  final referrals = List<String>.from(data['referrals'] ?? []);
                  if (!referrals.contains(uid)) {
                    referrals.add(uid);
                    final referralCount = (data['referralCount'] ?? 0) + 1;
                    final miningRateBoosted = referralCount >= 5;
                    
                    transaction.update(referrerDoc.reference, {
                      'referrals': referrals,
                      'referralCount': referralCount,
                      'miningRateBoosted': miningRateBoosted,
                    });
                  }
                }
              });
            }
          }
        } catch (e) {
          print('Referral processing error: $e');
          // Continue without referral if there's an error
        }
      }

      // Update user document
      await _firestore.collection('USER').doc(uid).update(userData);
      
      print('Google user registration completed successfully for: $uid');
    } catch (e) {
      print('Google registration error: $e');
      rethrow;
    }
  }

  // Check if user needs registration
  Future<bool> needsRegistration(String uid) async {
    try {
      final doc = await _firestore.collection('USER').doc(uid).get();
      if (!doc.exists) return true;
      
      final data = doc.data() as Map<String, dynamic>;
      
      // Check if user has required fields
      final hasPhoneNumber = data['phoneNumber'] != null && 
                            data['phoneNumber'].toString().isNotEmpty;
      final hasDisplayName = data['displayName'] != null && 
                            data['displayName'].toString().isNotEmpty;
      final needsProfileCompletion = data['needsProfileCompletion'] == true;
      
      return !hasPhoneNumber || !hasDisplayName || needsProfileCompletion;
    } catch (e) {
      print('Error checking if user has completed registration: $e');
      return false;
    }
  }

  // Check if user has completed registration
  Future<bool> hasCompletedRegistration(String uid) async {
    try {
      return !(await needsRegistration(uid));
    } catch (e) {
      return false;
    }
  }

  // Get user details
  Future<Map<String, dynamic>?> getUserDetails(String uid) async {
    try {
      final doc = await _firestore.collection('USER').doc(uid).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      print('Error getting user details: $e');
      return null;
    }
  }

  // Update user role (for admin purposes)
  Future<void> updateUserRole(String uid, String newRole) async {
    try {
      await _firestore.collection('USER').doc(uid).update({
        'role': newRole,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user role: $e');
      rethrow;
    }
  }

  // Check if user is admin
  Future<bool> isUserAdmin(String uid) async {
    try {
      final doc = await _firestore.collection('USER').doc(uid).get();
      if (!doc.exists) return false;
      
      final data = doc.data() as Map<String, dynamic>;
      final role = data['role'] ?? 'user';
      
      return role == 'admin' || role == 'super_admin';
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // Check if user needs email verification
  Future<bool> needsEmailVerification(String uid) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      // Check Firebase Auth email verification status
      await user.reload();
      if (!user.emailVerified) {
        return true;
      }
      
      // Update Firestore if email is verified
      await _firestore.collection('USER').doc(uid).update({
        'isEmailVerified': true,
        'emailVerifiedAt': FieldValue.serverTimestamp(),
      });
      
      return false;
    } catch (e) {
      print('Error checking email verification: $e');
      return true;
    }
  }

  // Check if user has completed all verification steps
  Future<bool> hasCompletedVerification(String uid) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      // Check Firebase Auth email verification
      await user.reload();
      if (!user.emailVerified) return false;
      
      // Check Firestore profile completion
      final doc = await _firestore.collection('USER').doc(uid).get();
      if (!doc.exists) return false;
      
      final data = doc.data() as Map<String, dynamic>;
      final needsProfileCompletion = data['needsProfileCompletion'] == true;
      
      return !needsProfileCompletion;
    } catch (e) {
      print('Error checking verification completion: $e');
      return false;
    }
  }
}