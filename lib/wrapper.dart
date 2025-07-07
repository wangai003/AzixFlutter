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
import 'utils/responsive_layout.dart';
import 'widgets/stellar_wallet_prompt.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({Key? key}) : super(key: key);

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  bool _isCheckingUserRegistration = false;
  bool _userNeedsRegistration = false;

  @override
  void initState() {
    super.initState();
    // Check for Stellar wallet after a short delay to allow the UI to build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserRegistration();
    });
    
    // Listen to authentication state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        // User signed in, check registration
        _checkUserRegistration();
      } else {
        // User signed out, reset state
        setState(() {
          _userNeedsRegistration = false;
          _isCheckingUserRegistration = false;
        });
      }
    });
  }

  Future<void> _checkUserRegistration() async {
    final authProvider = Provider.of<local_auth.AuthProvider>(context, listen: false);
    
    // Only check if user is authenticated
    if (!authProvider.isAuthenticated) return;
    
    setState(() {
      _isCheckingUserRegistration = true;
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('Checking registration for user: ${user.uid}');
        
        // Check if user exists in USER collection
        final userDoc = await FirebaseFirestore.instance
            .collection('USERS')
            .doc(user.uid)
            .get();
        
        if (!userDoc.exists) {
          print('User document does not exist - needs registration');
          setState(() {
            _userNeedsRegistration = true;
          });
          return;
        }
        
        // Check if user needs to complete registration (has incomplete profile)
        final userData = userDoc.data() as Map<String, dynamic>?;
        if (userData != null) {
          final needsRegistration = userData['needsRegistration'] == true || 
                                   userData['phoneNumber']?.isEmpty == true ||
                                   userData['phoneNumber'] == null;
          
          print('User data: $userData');
          print('Needs registration: $needsRegistration');
          
          if (needsRegistration) {
            print('User needs registration - showing registration screen');
            setState(() {
              _userNeedsRegistration = true;
            });
            return;
          }
        }
        
        print('User registration is complete');
        setState(() {
          _userNeedsRegistration = false;
        });
      }
    } catch (e) {
      print('Error checking user registration: $e');
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
    
    // Return either MainNavigation or ModernAuthScreen based on authentication state
    if (authProvider.isAuthenticated) {
      return const MainNavigation();
    } else {
      return const ModernAuthScreen();
    }
  }
}