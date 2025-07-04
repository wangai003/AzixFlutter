import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      // For web, we need to handle persistence differently
      if (kIsWeb) {
        // Set persistence to SESSION to avoid issues with some browsers
        await _auth.setPersistence(Persistence.SESSION);
      }
      
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
      String email, String password, String name, {String? referralCode}) async {
    try {
      // Create user with email and password
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;
      final userData = {
        'displayName': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'referralCode': uid, // Use UID as referral code
        'referrals': [],
        'referralCount': 0,
        'miningRateBoosted': false,
      };

      String? referredBy;
      if (referralCode != null && referralCode.isNotEmpty) {
        // Check if referral code exists
        final refQuery = await _firestore.collection('users').where('referralCode', isEqualTo: referralCode).limit(1).get();
        if (refQuery.docs.isNotEmpty) {
          referredBy = refQuery.docs.first.id;
          userData['referredBy'] = referredBy;

          // Update referrer's referrals and count
          final referrerDoc = refQuery.docs.first.reference;
          await _firestore.runTransaction((transaction) async {
            final snapshot = await transaction.get(referrerDoc);
            final data = snapshot.data() as Map<String, dynamic>;
            final referrals = List<String>.from(data['referrals'] ?? []);
            if (!referrals.contains(uid)) {
              referrals.add(uid);
              final referralCount = (data['referralCount'] ?? 0) + 1;
              final miningRateBoosted = referralCount > 5;
              transaction.update(referrerDoc, {
                'referrals': referrals,
                'referralCount': referralCount,
                'miningRateBoosted': miningRateBoosted,
              });
              // Credit Akofa coins to referrer
              await _creditAkofaToUser(referrerDoc.id, 5.0); // 5 Akofa per referral
            }
          });
        }
      }

      // Add user details to Firestore
      await _firestore.collection('users').doc(uid).set(userData);

      // Update display name
      await userCredential.user!.updateDisplayName(name);

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Helper: Credit Akofa coins to a user (referrer)
  Future<void> _creditAkofaToUser(String uid, double amount) async {
    // You may want to use your wallet/stellar service for this in production
    final userDoc = _firestore.collection('users').doc(uid);
    await userDoc.update({
      'akofaBalance': FieldValue.increment(amount),
    });
    // Optionally, record a transaction in your transactions collection
    // ...
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Get user details
  Future<Map<String, dynamic>?> getUserDetails(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }
  
  // Sign in with Google (especially useful for web)
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Create a new provider
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      
      // Add scopes if needed
      googleProvider.addScope('https://www.googleapis.com/auth/contacts.readonly');
      
      UserCredential userCredential;
      if (kIsWeb) {
        // Sign in using a popup for web
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // Sign in using redirect for mobile
        userCredential = await _auth.signInWithProvider(googleProvider);
      }
      // Ensure user document exists in Firestore
      final user = userCredential.user;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          await _firestore.collection('users').doc(user.uid).set({
            'name': user.displayName ?? '',
            'email': user.email ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
      return userCredential;
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  // Update user profile (name, bio, photoUrl, preferences)
  Future<void> updateUserProfile(String uid, {String? name, String? bio, String? photoUrl, Map<String, dynamic>? preferences}) async {
    final data = <String, dynamic>{};
    if (name != null) data['displayName'] = name;
    if (bio != null) data['bio'] = bio;
    if (photoUrl != null) data['photoUrl'] = photoUrl;
    if (preferences != null) data['preferences'] = preferences;
    await _firestore.collection('users').doc(uid).update(data);
  }

  // Upload profile image to Firebase Storage and return the download URL
  Future<String> uploadProfileImage(String uid, File imageFile) async {
    final ref = FirebaseStorage.instance.ref().child('profile_images/$uid/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}');
    final uploadTask = await ref.putFile(imageFile);
    return await uploadTask.ref.getDownloadURL();
  }

  // Complete Google user setup with referral code (for new users)
  Future<void> completeGoogleUserSetup(String uid, String? referralCode) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (!userDoc.exists) return;
    final userData = userDoc.data() ?? {};
    // Only update if referralCode is not already set
    if (userData['referralCode'] != null) return;
    final updateData = {
      'referralCode': uid,
      'referrals': [],
      'referralCount': 0,
      'miningRateBoosted': false,
    };
    String? referredBy;
    if (referralCode != null && referralCode.isNotEmpty) {
      // Check if referral code exists
      final refQuery = await _firestore.collection('users').where('referralCode', isEqualTo: referralCode).limit(1).get();
      if (refQuery.docs.isNotEmpty) {
        referredBy = refQuery.docs.first.id;
        updateData['referredBy'] = referredBy;
        // Update referrer's referrals and count
        final referrerDoc = refQuery.docs.first.reference;
        await _firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(referrerDoc);
          final data = snapshot.data() as Map<String, dynamic>;
          final referrals = List<String>.from(data['referrals'] ?? []);
          if (!referrals.contains(uid)) {
            referrals.add(uid);
            final referralCount = (data['referralCount'] ?? 0) + 1;
            final miningRateBoosted = referralCount > 5;
            transaction.update(referrerDoc, {
              'referrals': referrals,
              'referralCount': referralCount,
              'miningRateBoosted': miningRateBoosted,
            });
            // Credit Akofa coins to referrer
            await _creditAkofaToUser(referrerDoc.id, 5.0); // 5 Akofa per referral
          }
        });
      }
    }
    await _firestore.collection('users').doc(uid).update(updateData);
  }
}