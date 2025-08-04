import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'verify_email_screen.dart';
import 'phone_verification_screen.dart';

class ChooseVerificationScreen extends StatelessWidget {
  final String email;
  final String phoneNumber;
  const ChooseVerificationScreen({Key? key, required this.email, required this.phoneNumber}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.verified_user, color: AppTheme.primaryGold, size: 64),
                const SizedBox(height: 24),
                Text('Choose Verification Method',
                  style: AppTheme.headingLarge.copyWith(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'For your security, please verify your identity using one of the methods below.',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    foregroundColor: AppTheme.black,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.email),
                  label: const Text('Verify via Email'),
                  onPressed: () async {
                    final verified = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => VerifyEmailScreen(email: email),
                      ),
                    );
                    if (verified == true && context.mounted) {
                      Navigator.of(context).pop({'method': 'email', 'verified': true});
                    }
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryGold,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.phone_android),
                  label: const Text('Verify via Phone'),
                  onPressed: () async {
                    final otpResult = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PhoneVerificationScreen(initialPhoneNumber: phoneNumber),
                      ),
                    );
                    if (otpResult != null && otpResult['verified'] == true && context.mounted) {
                      Navigator.of(context).pop({'method': 'phone', 'verified': true});
                    }
                  },
                ),
                const SizedBox(height: 32),
                Text(
                  'You only need to verify with one method to access the app.',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 