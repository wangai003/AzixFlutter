import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:html' as html;
import 'dart:math';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // Get current user
  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (e) {
      print('DEBUG: Error getting current user: $e');
      return null;
    }
  }

  // Auth state changes stream
  Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (e) {
      print('DEBUG: Error getting auth state changes: $e');
      return Stream.value(null);
    }
  }

  // Get device ID
  Future<String> _getDeviceId() async {
    try {
      if (kIsWeb) {
        // For web, use a combination of user agent and screen info
        final userAgent = html.window.navigator.userAgent;
        final screenInfo = '${html.window.screen?.width ?? 0}x${html.window.screen?.height ?? 0}';
        return '${userAgent}_$screenInfo';
      } else {
        // For mobile platforms
        if (Platform.isAndroid) {
          final androidInfo = await _deviceInfo.androidInfo;
          return androidInfo.id;
        } else if (Platform.isIOS) {
          final iosInfo = await _deviceInfo.iosInfo;
          return iosInfo.identifierForVendor ?? 'unknown';
        }
      }
      return 'unknown_device';
    } catch (e) {
      print('Error getting device ID: $e');
      return 'unknown_device';
    }
  }

  // Validate phone number with robust checks
  Future<bool> _validatePhoneNumber(String phoneNumber) async {
    try {
      print('=== PHONE VALIDATION DEBUG ===');
      print('Validating phone number: $phoneNumber');
      print('Phone number length: ${phoneNumber.length}');
      print('Phone number starts with +: ${phoneNumber.startsWith('+')}');
      
      // Basic format validation
      if (phoneNumber.isEmpty) {
        print('Phone number is empty');
        return false;
      }
      
      // Must start with +
      if (!phoneNumber.startsWith('+')) {
        print('Phone number must start with +');
        return false;
      }
      
      // Remove + and get digits only
      final digitsOnly = phoneNumber.substring(1).replaceAll(RegExp(r'[^\d]'), '');
      print('Digits only: $digitsOnly (length: ${digitsOnly.length})');
      
      // Length validation (international standard: 7-15 digits)
      if (digitsOnly.length < 7) {
        print('Phone number too short: ${digitsOnly.length} digits');
        return false;
      }
      
      if (digitsOnly.length > 15) {
        print('Phone number too long: ${digitsOnly.length} digits');
        return false;
      }
      
      // Basic validation passed - no need for advanced parser validation
      
      // Basic validation passed
      print('Phone number basic validation passed: $phoneNumber');
      print('=== END PHONE VALIDATION ===');
      return true;
    } catch (e) {
      print('Error validating phone number: $e');
      print('=== END PHONE VALIDATION WITH ERROR ===');
      return false;
    }
  }

  // Check if phone number is already in use
  Future<bool> _isPhoneNumberInUse(String phoneNumber) async {
    try {
      final query = await _firestore
          .collection('USER')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking phone number: $e');
      return false;
    }
  }

  // Check if device ID is already in use
  Future<bool> _isDeviceIdInUse(String deviceId) async {
    try {
      final query = await _firestore
          .collection('USER')
          .where('deviceId', isEqualTo: deviceId)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking device ID: $e');
      return false;
    }
  }

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

  // Generate a random 6-character referral code (uppercase letters and numbers)
  Future<String> _generateUniqueReferralCode() async {
    const length = 6;
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    String code;
    bool exists = true;
    do {
      code = List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
      final query = await _firestore.collection('USER').where('referralCode', isEqualTo: code).limit(1).get();
      exists = query.docs.isNotEmpty;
    } while (exists);
    return code;
  }

  // Register with email and password - Robust implementation
  Future<UserCredential> registerWithEmailAndPassword(
      String email, String password, String name, String phoneNumber, {String? referralCode}) async {
    try {
      print('Starting registration process for: $email');
      // Input validation
      if (email.isEmpty || password.isEmpty || name.isEmpty || phoneNumber.isEmpty) {
        throw Exception('All fields are required');
      }
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}\$').hasMatch(email)) {
        throw Exception('Please enter a valid email address');
      }
      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters long');
      }
      if (name.length < 2) {
        throw Exception('Name must be at least 2 characters long');
      }
      final isValidPhone = await _validatePhoneNumber(phoneNumber);
      if (!isValidPhone) {
        throw Exception('Invalid phone number format. Please ensure your phone number includes the country code and is between 7-15 digits (e.g., +254725280695)');
      }
      // Check if phone number is already in use
      final isPhoneInUse = await _isPhoneNumberInUse(phoneNumber);
      if (isPhoneInUse) {
        throw Exception('Phone number is already registered with another account');
      }
      // Check if email is already in use
      try {
        final methods = await _auth.fetchSignInMethodsForEmail(email);
        if (methods.isNotEmpty) {
          throw Exception('Email is already registered with another account');
        }
      } catch (e) {
        print('Email check failed, continuing: $e');
      }
      // Get device ID
      final deviceId = await _getDeviceId();
      // Check if device ID is already in use (strict enforcement)
      final isDeviceInUse = await _isDeviceIdInUse(deviceId);
      if (isDeviceInUse) {
        throw Exception('This device is already registered with another account. Please use a different device or contact support.');
      }
      // Create user with email and password
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = userCredential.user!.uid;
      // Generate unique referral code
      final generatedReferralCode = await _generateUniqueReferralCode();
      // Prepare user data
      final userData = {
        'displayName': name,
        'email': email,
        'phoneNumber': phoneNumber,
        'deviceId': deviceId,
        'createdAt': FieldValue.serverTimestamp(),
        'referralCode': generatedReferralCode, // Use generated code
        'referrals': [],
        'referralCount': 0,
        'miningRateBoosted': false,
        'role': 'user', // Default role - not admin
        'isActive': true,
        'isEmailVerified': false,
        'isPhoneVerified': true, // Mark as verified since they completed registration
        'hasWallet': false,
        'akofaBalance': 0.0,
        'lastLogin': FieldValue.serverTimestamp(),
      };
      // Handle referral if provided
      if (referralCode != null && referralCode.isNotEmpty) {
        try {
          final refQuery = await _firestore.collection('USER').where('referralCode', isEqualTo: referralCode).limit(1).get();
          if (refQuery.docs.isNotEmpty) {
            final referrerDoc = refQuery.docs.first;
            userData['referredBy'] = referrerDoc.id;
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
                  await _creditAkofaToUser(referrerDoc.id, 5.0);
                }
              }
            });
          }
        } catch (e) {
          print('Referral processing error: $e');
        }
      }
      // Save user data to Firestore
      await _firestore.collection('USER').doc(uid).set(userData);
      // Update display name
      await userCredential.user!.updateDisplayName(name);
      print('User registration completed successfully for: $email');
      return userCredential;
    } catch (e) {
      print('Registration error: $e');
      // User-friendly error mapping
      String userMessage = 'Registration failed. Please try again.';
      final error = e.toString();
      if (error.contains('All fields are required')) {
        userMessage = 'Please fill in all required fields.';
      } else if (error.contains('valid email')) {
        userMessage = 'Please enter a valid email address (e.g., user@example.com).';
      } else if (error.contains('Password must be at least')) {
        userMessage = 'Your password must be at least 6 characters long.';
      } else if (error.contains('Name must be at least')) {
        userMessage = 'Your name must be at least 2 characters.';
      } else if (error.contains('Invalid phone number format')) {
        userMessage = 'Please enter a valid phone number with country code (e.g., +254725280695).';
      } else if (error.contains('already registered with another account')) {
        if (error.contains('Phone number')) {
          userMessage = 'This phone number is already registered. Try logging in or use a different number.';
        } else if (error.contains('Email')) {
          userMessage = 'This email is already registered. Try logging in or use a different email.';
        }
      } else if (error.contains('device is already registered')) {
        userMessage = 'This device is already registered with another account. Please use a different device or contact support.';
      } else if (error.contains('network') || error.contains('timeout')) {
        userMessage = 'Network error. Please check your internet connection and try again.';
      } else if (error.contains('permission-denied')) {
        userMessage = 'Registration is currently unavailable. Please contact support.';
      } else if (error.contains('Failed to create new user account')) {
        userMessage = 'Could not create your account. Please check your details and try again.';
      } else if (error.contains('Failed to complete Google user registration')) {
        userMessage = 'Could not complete Google registration. Please try again or use email/password.';
      }
      throw Exception(userMessage);
    }
  }

  // Helper: Credit Akofa coins to a user (referrer)
  Future<void> _creditAkofaToUser(String uid, double amount) async {
    // You may want to use your wallet/stellar service for this in production
    final userDoc = _firestore.collection('USER').doc(uid);
    await userDoc.update({
      'akofaBalance': FieldValue.increment(amount),
    });
    // Record a transaction in your transactions collection for referral reward
    // Get user's public key for proper transaction recording
    final userDocSnapshot = await _firestore.collection('USER').doc(uid).get();
    final userData = userDocSnapshot.data();
    final publicKey = userData?['stellarPublicKey'];
    
    await _firestore.collection('transactions').add({
      'userId': uid,
      'senderAddress': 'SYSTEM_REFERRAL', // System account for referral rewards
      'recipientAddress': publicKey ?? 'UNKNOWN',
      'amount': amount,
      'type': 'mining', // Mining reward type for referral bonuses
      'status': 'completed',
      'timestamp': FieldValue.serverTimestamp(),
      'memo': 'Referral Reward',
      'assetCode': 'AKOFA',
      'senderAkofaTag': 'SYSTEM',
      'recipientAkofaTag': userData?['akofaTag'],
    });
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
          await _firestore.collection('USER').doc(uid).get();
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
        final userDoc = await _firestore.collection('USER').doc(user.uid).get();
        if (!userDoc.exists) {
          // This is a new Google user - they need to complete registration
          final deviceId = await _getDeviceId();
          await _firestore.collection('USER').doc(user.uid).set({
            'displayName': user.displayName ?? '',
            'email': user.email ?? '',
            'phoneNumber': '', // Will be filled during registration
            'deviceId': deviceId,
            'createdAt': FieldValue.serverTimestamp(),
            'role': 'user', // Default role - not admin
            'isActive': true,
            'isEmailVerified': false, // Force Google users to verify through our app
            'isPhoneVerified': false,
            'hasWallet': false,
            'akofaBalance': 0.0,
            'needsRegistration': true, // Flag to indicate incomplete registration
          });
        }
      }
      return userCredential;
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  // Complete Google user registration - Robust implementation
  Future<void> completeGoogleUserRegistration(String uid, String phoneNumber, {String? referralCode}) async {
    try {
      print('Starting Google user registration completion for: $uid');
      
      // Input validation
      if (uid.isEmpty || phoneNumber.isEmpty) {
        throw Exception('User ID and phone number are required');
      }
      
      // Phone number validation
      final isValidPhone = await _validatePhoneNumber(phoneNumber);
      if (!isValidPhone) {
        throw Exception('Invalid phone number format. Please ensure your phone number includes the country code and is between 7-15 digits (e.g., +254725280695)');
      }

      // Check if phone number is already in use
      final isPhoneInUse = await _isPhoneNumberInUse(phoneNumber);
      if (isPhoneInUse) {
        throw Exception('Phone number is already registered with another account');
      }

      // Verify user document exists
      final userDoc = await _firestore.collection('USER').doc(uid).get();
      if (!userDoc.exists) {
        throw Exception('User document not found. Please try signing in again.');
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      
      // Prepare update data
      final updateData = {
        'phoneNumber': phoneNumber,
        'referrals': [],
        'referralCount': 0,
        'miningRateBoosted': false,
        'needsRegistration': false,
        'isPhoneVerified': true,
        'lastLogin': FieldValue.serverTimestamp(),
      };
      // Only generate and assign referralCode if not already set
      if (userData['referralCode'] == null || (userData['referralCode'] as String).isEmpty) {
        final generatedReferralCode = await _generateUniqueReferralCode();
        updateData['referralCode'] = generatedReferralCode;
      }

      // Handle referral if provided
      if (referralCode != null && referralCode.isNotEmpty) {
        try {
          final refQuery = await _firestore.collection('USER').where('referralCode', isEqualTo: referralCode).limit(1).get();
          if (refQuery.docs.isNotEmpty) {
            final referrerDoc = refQuery.docs.first;
            
            // Don't allow self-referral
            if (referrerDoc.id != uid) {
              updateData['referredBy'] = referrerDoc.id;

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
                    
                    // Credit Akofa coins to referrer
                    await _creditAkofaToUser(referrerDoc.id, 5.0);
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
      await _firestore.collection('USER').doc(uid).update(updateData);
      
      print('Google user registration completed successfully for: $uid');
    } catch (e) {
      print('Google registration error: $e');
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
    await _firestore.collection('USER').doc(uid).update(data);
  }

  // Upload profile image to Firebase Storage and return the download URL
  Future<String> uploadProfileImage(String uid, File imageFile) async {
    final ref = FirebaseStorage.instance.ref().child('profile_images/$uid/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}');
    final uploadTask = await ref.putFile(imageFile);
    return await uploadTask.ref.getDownloadURL();
  }

  // Verify phone number (for admin use)
  Future<void> verifyPhoneNumber(String uid) async {
    await _firestore.collection('USER').doc(uid).update({
      'isPhoneVerified': true,
    });
  }

  // Make user admin (for super admin use)
  Future<void> makeUserAdmin(String uid, String role) async {
    if (role != 'admin' && role != 'super_admin') {
      throw Exception('Invalid role. Must be "admin" or "super_admin"');
    }
    await _firestore.collection('USER').doc(uid).update({
      'role': role,
    });
  }

  // Check if user needs to complete registration
  Future<bool> needsRegistration(String uid) async {
    try {
      final doc = await _firestore.collection('USER').doc(uid).get();
      if (!doc.exists) return true;
      final data = doc.data() as Map<String, dynamic>;
      return data['needsRegistration'] == true || data['phoneNumber']?.isEmpty == true;
    } catch (e) {
      return true;
    }
  }

  // Check if user exists in USER collection
  Future<bool> userExistsInCollection(String uid) async {
    try {
      final doc = await _firestore.collection('USER').doc(uid).get();
      return doc.exists;
    } catch (e) {
      print('Error checking if user exists in collection: $e');
      return false;
    }
  }

  // Check if user has completed registration (has phone number and other required fields)
  Future<bool> hasCompletedRegistration(String uid) async {
    try {
      final doc = await _firestore.collection('USER').doc(uid).get();
      if (!doc.exists) return false;
      
      final data = doc.data() as Map<String, dynamic>;
      
      // Check if user has required fields
      final hasPhoneNumber = data['phoneNumber'] != null && 
                            data['phoneNumber'].toString().isNotEmpty;
      final hasDisplayName = data['displayName'] != null && 
                            data['displayName'].toString().isNotEmpty;
      final needsRegistration = data['needsRegistration'] == true;
      
      return hasPhoneNumber && hasDisplayName && !needsRegistration;
    } catch (e) {
      print('Error checking if user has completed registration: $e');
      return false;
    }
  }

  // Update arbitrary fields in the USER document
  Future<void> updateUserFields(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('USER').doc(uid).update(data);
  }

  // Get referral leaderboard data
  Future<List<Map<String, dynamic>>> getReferralLeaderboard() async {
    try {
      final query = await _firestore
          .collection('USER')
          .where('referralCount', isGreaterThan: 0)
          .orderBy('referralCount', descending: true)
          .limit(10)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        return {
          'rank': 0, // Will be calculated below
          'username': data['displayName'] ?? 'Unknown User',
          'referrals': data['referralCount'] ?? 0,
          'earnings': (data['referralCount'] ?? 0) * 5.0, // 5 AKOFA per referral
          'avatar': _getUserAvatar(data['displayName'] ?? ''),
          'userId': doc.id,
        };
      }).toList();
    } catch (e) {
      print('Error fetching referral leaderboard: $e');
      return [];
    }
  }

  // Get recent referrals for a specific user
  Future<List<Map<String, dynamic>>> getRecentReferrals(String userId) async {
    try {
      final userDoc = await _firestore.collection('USER').doc(userId).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data() as Map<String, dynamic>;
      final referrals = List<String>.from(userData['referrals'] ?? []);

      if (referrals.isEmpty) return [];

      // Get details for each referred user
      final referralsData = <Map<String, dynamic>>[];
      for (final referralId in referrals.take(10)) { // Limit to 10 most recent
        try {
          final referralDoc = await _firestore.collection('USER').doc(referralId).get();
          if (referralDoc.exists) {
            final referralData = referralDoc.data() as Map<String, dynamic>;
            referralsData.add({
              'username': referralData['displayName'] ?? 'Unknown User',
              'joined': (referralData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              'status': referralData['isActive'] == true ? 'active' : 'inactive',
              'userId': referralId,
            });
          }
        } catch (e) {
          print('Error fetching referral details for $referralId: $e');
        }
      }

      // Sort by join date (most recent first)
      referralsData.sort((a, b) => (b['joined'] as DateTime).compareTo(a['joined'] as DateTime));
      
      return referralsData;
    } catch (e) {
      print('Error fetching recent referrals: $e');
      return [];
    }
  }

  // Helper method to generate avatar emoji based on username
  String _getUserAvatar(String username) {
    if (username.isEmpty) return '👤';
    
    // Simple hash-based avatar selection
    final hash = username.hashCode;
    final avatars = ['👑', '👸', '⭐', '🚀', '🎯', '💎', '🔥', '🌟', '💫', '✨'];
    return avatars[hash.abs() % avatars.length];
  }
}