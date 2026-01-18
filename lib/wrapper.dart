import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/auth_provider.dart' as local_auth;
import 'screens/main_navigation.dart';
import 'screens/auth/modern_auth_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/user_registration_screen.dart';
import 'screens/landing_screen.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({Key? key}) : super(key: key);

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  bool _hasSeenLanding = false;
  bool _isCheckingLanding = true;

  @override
  void initState() {
    super.initState();
    _checkLandingStatus();
    
    // Handle redirect results for web users
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final authProvider = Provider.of<local_auth.AuthProvider>(context, listen: false);
        authProvider.handleRedirectResult();
      });
    }
  }

  Future<void> _checkLandingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenLanding = prefs.getBool('has_seen_landing') ?? false;
    setState(() {
      _hasSeenLanding = hasSeenLanding;
      _isCheckingLanding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking landing status
    if (_isCheckingLanding) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
          ),
        ),
      );
    }

    // Show landing page if user hasn't seen it
    if (!_hasSeenLanding) {
      return const LandingScreen();
    }

    return Consumer<local_auth.AuthProvider>(
      builder: (context, authProvider, _) {
        // Show loading while initializing
        if (authProvider.authState == local_auth.AuthState.initial) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
              ),
            ),
          );
        }

        // Show loading while processing
        if (authProvider.isLoading) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Processing...',
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

        // User is not authenticated
        if (!authProvider.isAuthenticated) {
          return const ModernAuthScreen();
        }

        // User is authenticated but needs email verification
        if (authProvider.user != null) {
          return FutureBuilder<bool>(
            future: authProvider.needsEmailVerification(),
            builder: (context, emailSnapshot) {
              if (emailSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Colors.black,
                  body: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                  ),
                );
              }

              // If email verification is needed, show verification screen
              if (emailSnapshot.hasData && emailSnapshot.data == true) {
                return const EmailVerificationScreen();
              }

              // Email verified, check if profile completion is needed
              return FutureBuilder<bool>(
                future: authProvider.needsProfileCompletion(),
                builder: (context, profileSnapshot) {
                  if (profileSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      backgroundColor: Colors.black,
                      body: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                        ),
                      ),
                    );
                  }

                  if (profileSnapshot.hasData && profileSnapshot.data == true) {
                    return const UserRegistrationScreen();
                  }

                  // User is fully authenticated and profile is complete
                  return const MainNavigation();
                },
              );
            },
          );
        }

        // Fallback to auth screen
        return const ModernAuthScreen();
      },
    );
  }
}