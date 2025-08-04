import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_logo.dart';
import '../../widgets/google_sign_in_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'verify_email_screen.dart';
import 'phone_verification_screen.dart';
import 'choose_verification_screen.dart';

class ModernAuthScreen extends StatelessWidget {
  const ModernAuthScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width > 700;

    Future<void> _showReferralDialog() async {
      final TextEditingController _referralController = TextEditingController();
      bool submitted = false;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                backgroundColor: AppTheme.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text('Do you have a referral code?', style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _referralController,
                      decoration: const InputDecoration(
                        labelText: 'Referral Code (optional)',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    if (authProvider.isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 16.0),
                        child: CircularProgressIndicator(),
                      ),
                    if (authProvider.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text(authProvider.error!, style: const TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: authProvider.isLoading ? null : () async {
                      setState(() { submitted = true; });
                      final success = await authProvider.submitReferralCode(_referralController.text.trim().isEmpty ? null : _referralController.text.trim());
                      if (success && context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral code applied!')));
                      }
                    },
                    child: const Text('Continue'),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.black, Color(0xFF232526), Color(0xFF414345)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 420 : double.infinity,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Lottie.asset(
                            'assets/animations/login_animation.json',
                            width: 140,
                            height: 140,
                            fit: BoxFit.contain,
                            repeat: true,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Welcome to AZIX',
                            style: AppTheme.headingLarge.copyWith(
                              color: AppTheme.primaryGold,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Sign in securely with Google to continue',
                            style: AppTheme.bodyLarge.copyWith(
                              color: Colors.white.withOpacity(0.92),
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          if (authProvider.error != null)
                            Container(
                              padding: const EdgeInsets.all(14),
                              margin: const EdgeInsets.only(bottom: 18),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.13),
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
                                      style: AppTheme.bodyMedium.copyWith(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          GoogleSignInButton(
                            onPressed: () async {
                              final success = await authProvider.signInWithGoogle();
                              final user = authProvider.user;
                              String? uid = user?.uid;
                              Map<String, bool> status = {'isEmailVerified': false, 'isPhoneVerified': false};
                              if (uid != null) {
                                status = await authProvider.getFirestoreVerificationStatus(uid);
                              }
                              if (success && user != null && !status['isEmailVerified']! && !status['isPhoneVerified']! && context.mounted) {
                                final result = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => ChooseVerificationScreen(
                                      email: user.email ?? '',
                                      phoneNumber: user.phoneNumber ?? '',
                                    ),
                                  ),
                                );
                                if (result == null || result['verified'] != true) {
                                  // Block access if not verified
                                  return;
                                }
                                if (uid != null) {
                                  if (result['method'] == 'email') {
                                    await authProvider.setFirestoreVerificationStatus(uid, email: true);
                                  } else if (result['method'] == 'phone') {
                                    await authProvider.setFirestoreVerificationStatus(uid, phone: true);
                                  }
                                }
                                if (authProvider.isNewUser && context.mounted) {
                                  await _showReferralDialog();
                                }
                              } else if (success && authProvider.isNewUser && context.mounted) {
                                await _showReferralDialog();
                              }
                            },
                            isLoading: authProvider.isLoading,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'By signing in, you agree to our Terms & Privacy Policy.',
                            style: AppTheme.bodySmall.copyWith(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ).animate().fadeIn(duration: 800.ms, delay: 200.ms).slideY(begin: 0.15, end: 0, curve: Curves.easeOut, duration: 800.ms),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 