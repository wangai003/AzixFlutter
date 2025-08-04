import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final String initialPhoneNumber;
  final bool isForSignIn;
  const PhoneVerificationScreen({Key? key, required this.initialPhoneNumber, this.isForSignIn = false}) : super(key: key);

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  String? _verificationId;
  bool _isLoading = false;
  bool _otpSent = false;
  String? _error;
  int _resendToken = 0;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.initialPhoneNumber;
  }

  Future<void> _sendOTP() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phoneController.text.trim(),
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-retrieval or instant verification
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) Navigator.of(context).pop({'phone': _phoneController.text.trim(), 'verified': true});
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() { _error = e.message ?? 'Verification failed.'; _isLoading = false; });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
            _isLoading = false;
            _resendToken = resendToken ?? 0;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() { _verificationId = verificationId; _isLoading = false; });
        },
        forceResendingToken: _resendToken == 0 ? null : _resendToken,
      );
    } catch (e) {
      setState(() { _error = 'Failed to send OTP.'; _isLoading = false; });
    }
  }

  Future<void> _verifyOTP() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) Navigator.of(context).pop({'phone': _phoneController.text.trim(), 'verified': true});
    } catch (e) {
      setState(() { _error = 'Invalid OTP. Please try again.'; _isLoading = false; });
    }
  }

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
                Icon(Icons.phone_android, color: AppTheme.primaryGold, size: 64),
                const SizedBox(height: 24),
                Text('Verify Your Phone',
                  style: AppTheme.headingLarge.copyWith(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  enabled: false,
                  keyboardType: TextInputType.phone,
                  style: AppTheme.bodyLarge.copyWith(color: AppTheme.white),
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
                    ),
                    prefixIcon: const Icon(Icons.phone, color: AppTheme.grey),
                  ),
                ),
                const SizedBox(height: 20),
                if (_otpSent)
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    style: AppTheme.bodyLarge.copyWith(color: AppTheme.white),
                    decoration: InputDecoration(
                      labelText: 'Enter OTP',
                      labelStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
                      ),
                      prefixIcon: const Icon(Icons.lock, color: AppTheme.grey),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(_error!, style: AppTheme.bodySmall.copyWith(color: Colors.red)),
                  ),
                const SizedBox(height: 24),
                if (!_otpSent)
                  CustomButton(
                    text: _isLoading ? 'Sending OTP...' : 'Send OTP',
                    onPressed: _isLoading ? () {} : _sendOTP,
                  ),
                if (_otpSent)
                  CustomButton(
                    text: _isLoading ? 'Verifying...' : 'Verify OTP',
                    onPressed: _isLoading ? () {} : _verifyOTP,
                  ),
                if (_otpSent)
                  TextButton(
                    onPressed: _isLoading ? null : _sendOTP,
                    child: const Text('Resend OTP'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 