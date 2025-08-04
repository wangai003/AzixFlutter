import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'providers/auth_provider.dart' as local_auth;
import 'providers/stellar_provider.dart';
import 'screens/main_navigation.dart';
import 'screens/welcome_screen.dart';
import 'screens/auth/modern_auth_screen.dart';
import 'screens/user_registration_screen.dart';
import 'screens/auth/choose_verification_screen.dart';
import 'utils/responsive_layout.dart';
import 'widgets/stellar_wallet_prompt.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({Key? key}) : super(key: key);

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> with WidgetsBindingObserver {
  bool _isCheckingUserRegistration = false;
  bool _userNeedsRegistration = false;
  bool _isAppInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Check for Stellar wallet after a short delay to allow the UI to build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserRegistration();
    });
    
    // Listen to authentication state changes
    try {
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (user != null) {
          // User signed in, check registration
          _checkUserRegistration();
        } else {
          // User signed out, reset state and verification status
          print('DEBUG: User signed out, resetting verification status');
          _resetVerificationStatusOnSessionEnd();
          setState(() {
            _userNeedsRegistration = false;
            _isCheckingUserRegistration = false;
          });
        }
      });

      // Listen to token refresh events
      FirebaseAuth.instance.idTokenChanges().listen((User? user) {
        if (user != null) {
          // Token was refreshed, reset verification status for security
          print('DEBUG: Token refreshed, resetting verification status');
          _resetVerificationStatusOnSessionEnd();
        }
      });
    } catch (e) {
      print('DEBUG: Error setting up Firebase listeners: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App is going to background or being closed
        if (!_isAppInBackground) {
          _isAppInBackground = true;
          _resetVerificationStatusOnSessionEnd();
        }
        break;
      case AppLifecycleState.resumed:
        // App is coming back to foreground
        _isAppInBackground = false;
        break;
    }
  }

  Future<void> _resetVerificationStatusOnSessionEnd() async {
    try {
      final authProvider = Provider.of<local_auth.AuthProvider>(context, listen: false);
      await authProvider.resetVerificationStatusOnSessionEnd();
    } catch (e) {
      print('DEBUG: Error in _resetVerificationStatusOnSessionEnd: $e');
    }
  }

  Future<void> _checkUserRegistration() async {
    final authProvider = Provider.of<local_auth.AuthProvider>(context, listen: false);
    print('DEBUG: Entered _checkUserRegistration');
    // Only check if user is authenticated
    if (!authProvider.isAuthenticated) {
      print('DEBUG: User not authenticated');
      return;
    }
    setState(() {
      _isCheckingUserRegistration = true;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('DEBUG: Checking registration for user: ${user.uid}');
        // Check if user exists in USER collection
        final userDoc = await FirebaseFirestore.instance
            .collection('USER')
            .doc(user.uid)
            .get();
        print('DEBUG: userDoc.exists = ${userDoc.exists}');
        if (!userDoc.exists) {
          print('DEBUG: User document does not exist - needs registration');
          // Automatically create a USER document with minimal info
          // For Google sign-in users, always set isEmailVerified to false to force verification
          final isGoogleUser = user.providerData.any((profile) => profile.providerId == 'google.com');
          await FirebaseFirestore.instance.collection('USER').doc(user.uid).set({
            'displayName': user.displayName ?? '',
            'email': user.email ?? '',
            'phoneNumber': '',
            'createdAt': FieldValue.serverTimestamp(),
            'role': 'user',
            'isActive': true,
            'isEmailVerified': isGoogleUser ? false : user.emailVerified, // Force Google users to verify
            'isPhoneVerified': false,
            'hasWallet': false,
            'akofaBalance': 0.0,
            'needsRegistration': true,
          });
          setState(() {
            _userNeedsRegistration = true;
          });
          return;
        }
        // Check if user needs to complete registration (has incomplete profile)
        final userData = userDoc.data() as Map<String, dynamic>?;
        print('DEBUG: userData = ${userData}');
        if (userData != null) {
          // Check if this is a Google user who needs verification enforcement
          final isGoogleUser = user.providerData.any((profile) => profile.providerId == 'google.com');
          if (isGoogleUser && userData['isEmailVerified'] == true) {
            // Force Google users to go through our verification process
            print('DEBUG: Google user found with isEmailVerified=true, forcing verification');
            await FirebaseFirestore.instance.collection('USER').doc(user.uid).update({
              'isEmailVerified': false,
            });
          }
          
          final needsRegistration = userData['needsRegistration'] == true || 
                                   userData['phoneNumber']?.isEmpty == true ||
                                   userData['phoneNumber'] == null;
          print('DEBUG: needsRegistration = ${needsRegistration}');
          if (needsRegistration) {
            print('DEBUG: User needs registration - showing registration screen');
            setState(() {
              _userNeedsRegistration = true;
            });
            return;
          }
        }
        print('DEBUG: User registration is complete');
        setState(() {
          _userNeedsRegistration = false;
        });
      }
    } catch (e) {
      print('DEBUG: Error checking user registration: ${e}');
      // If there's an error, assume user needs registration
      setState(() {
        _userNeedsRegistration = true;
      });
    } finally {
      setState(() {
        _isCheckingUserRegistration = false;
      });
    }
    // If user doesn't need registration, check for Stellar wallet
    if (!_userNeedsRegistration) {
      _checkStellarWallet();
    }
  }

  Future<void> _checkStellarWallet() async {
    // Skip wallet check on web platform
    if (kIsWeb) {
      return;
    }
    
    final authProvider = Provider.of<local_auth.AuthProvider>(context, listen: false);
    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
    
    // Only check for wallet if user is authenticated
    if (authProvider.isAuthenticated) {
      final hasWallet = await stellarProvider.checkWalletStatus();
      
      // If user doesn't have a wallet, show the prompt
      if (!hasWallet && mounted) {
        // Show the wallet prompt dialog and await its result
        final result = await showDialog(
          context: context,
          barrierDismissible: false, // User must take an action
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: SizedBox(
              width: ResponsiveLayout.getValueForScreenType<double>(
                context: context,
                mobile: MediaQuery.of(context).size.width * 0.85,
                tablet: 500,
                desktop: 600,
              ),
              child: const StellarWalletPrompt(),
            ),
          ),
        );
        // Optionally, handle result if needed
      }
    }
  }

  // Public method to force refresh registration status
  Future<void> refreshRegistrationStatus() async {
    print('Forcing refresh of registration status');
    await _checkUserRegistration();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<local_auth.AuthProvider>(context);
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    // Show loading while checking user registration
    if (authProvider.isAuthenticated && _isCheckingUserRegistration) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
              ),
              const SizedBox(height: 20),
              Text(
                'Verifying your account...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }
    // If user is authenticated but needs registration, show registration screen
    if (authProvider.isAuthenticated && _userNeedsRegistration) {
      return const UserRegistrationScreen();
    }
    // ENFORCE VERIFICATION: If user is authenticated, registration is complete, but neither email nor phone is verified, show verification choice
    if (authProvider.isAuthenticated && !_userNeedsRegistration && uid != null) {
      return FutureBuilder<Map<String, bool>>(
        future: authProvider.getFirestoreVerificationStatus(uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final status = snapshot.data!;
          if (!status['isEmailVerified']! && !status['isPhoneVerified']!) {
            return ChooseVerificationScreen(
              email: user?.email ?? '',
              phoneNumber: user?.phoneNumber ?? '',
            );
          }
          return const MainNavigation();
        },
      );
    }
    // Return either MainNavigation or ModernAuthScreen based on authentication state
    if (authProvider.isAuthenticated) {
      return const MainNavigation();
    } else {
      return const ModernAuthScreen();
    }
  }
}