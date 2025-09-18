import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/custom_button.dart';
import '../widgets/google_sign_in_button.dart';
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.black,
              Color(0xFF212121),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                const AppLogo(width: 180, height: 180),
                const SizedBox(height: 40),
                Text(
                  'Welcome to AZIX',
                  style: AppTheme.headingLarge.copyWith(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.w800,
                  ),
                )
                    .animate()
                    .fadeIn(
                      duration: const Duration(milliseconds: 800),
                      delay: const Duration(milliseconds: 300),
                    )
                    .slideY(
                      begin: 0.2,
                      end: 0,
                      curve: Curves.easeOut,
                      duration: const Duration(milliseconds: 800),
                    ),
                const SizedBox(height: 16),
                Text(
                  'Your journey to financial freedom starts here',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.white,
                  ),
                )
                    .animate()
                    .fadeIn(
                      duration: const Duration(milliseconds: 800),
                      delay: const Duration(milliseconds: 500),
                    )
                    .slideY(
                      begin: 0.2,
                      end: 0,
                      curve: Curves.easeOut,
                      duration: const Duration(milliseconds: 800),
                    ),
                const Spacer(),
                
                // Google Sign-In Button
                if (authProvider.error != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authProvider.error!,
                            style: AppTheme.bodyMedium.copyWith(
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().shake().fadeIn(),
                
                GoogleSignInButton(
                  onPressed: () async {
                    final success = await authProvider.signInWithGoogle();
                    if (success && context.mounted) {
                      // After successful Google sign-in, let the Wrapper handle the flow
                      // Don't manually navigate here - let the authentication state change
                      // trigger the proper flow in the Wrapper
                    }
                  },
                  isLoading: authProvider.isLoading,
                ).animate().fadeIn(
                      duration: const Duration(milliseconds: 800),
                      delay: const Duration(milliseconds: 500),
                    ),
                const SizedBox(height: 20),
                
                // Or divider
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: AppTheme.bodyMedium.copyWith(
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ],
                ).animate().fadeIn(
                      duration: const Duration(milliseconds: 800),
                      delay: const Duration(milliseconds: 600),
                    ),
                const SizedBox(height: 20),
                
                CustomButton(
                  text: 'Sign In with Email',
                  onPressed: () async {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                    // After successful login in LoginScreen, navigate to WalletOnboardingScreen
                  },
                  width: double.infinity,
                ).animate().fadeIn(
                      duration: const Duration(milliseconds: 800),
                      delay: const Duration(milliseconds: 700),
                    ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Create Account',
                  width: double.infinity,
                  onPressed: () async {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    );
                    // After successful register in RegisterScreen, navigate to WalletOnboardingScreen
                  },
                  isOutlined: true,
                ).animate().fadeIn(
                      duration: const Duration(milliseconds: 800),
                      delay: const Duration(milliseconds: 900),
                    ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}