import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../main_navigation.dart';
import 'dart:async'; // Added for Timer
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth; // Added for User

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  late final AuthProvider _authProvider;
  late final String _email;
  bool _navigated = false;
  bool _isLoading = false;
  String? _error;
  bool _resent = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _email = widget.email;
    _sendVerificationEmailOnInit();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _sendVerificationEmailOnInit() async {
    try {
      await _authProvider.authService.currentUser?.sendEmailVerification();
      setState(() { _resent = true; });
    } catch (e) {
      setState(() { _error = 'Failed to send verification email.'; });
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (mounted && !_navigated) {
        await _checkVerificationStatus();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _checkVerificationStatus() async {
    try {
      final user = _authProvider.authService.currentUser;
      if (user != null && user.email != null) {
        // Force a complete reload of the user to get the latest verification status
        await user.reload();
        
        // Get the fresh user object after reload
        final freshUser = _authProvider.authService.currentUser;
        
        // Check if this is a Google user
        final isGoogleUser = freshUser?.providerData.any((profile) => profile.providerId == 'google.com') ?? false;
        
        // Check Firestore status
        final status = await _authProvider.getFirestoreVerificationStatus(user.uid);
        
        // For Google users, NEVER trust Firebase's emailVerified status
        // For non-Google users, we can check Firebase's emailVerified status
        if (!isGoogleUser && freshUser != null && freshUser.emailVerified && !status['isEmailVerified']!) {
          print('Non-Google user verified via Firebase, updating Firestore...');
          await _authProvider.setFirestoreVerificationStatus(user.uid, email: true);
        }
        
        // Check if verified in Firestore
        final updatedStatus = await _authProvider.getFirestoreVerificationStatus(user.uid);
        if (updatedStatus['isEmailVerified']!) {
          print('Email verified successfully! Navigating...');
          _navigated = true;
          _pollingTimer?.cancel();
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MainNavigation()),
              (route) => false,
            );
          }
          return;
        }
        
        // For Google users, we need explicit verification through the app
        if (isGoogleUser) {
          print('Google user detected - requiring explicit verification through app');
          // Don't auto-navigate for Google users
          return;
        }
      }
    } catch (e) {
      print('Error checking verification status: $e');
    }
  }

  Future<void> _manualCheckVerification() async {
    setState(() { _isLoading = true; });
    try {
      final user = _authProvider.authService.currentUser;
      if (user != null) {
        // Force reload to get the latest verification status
        await user.reload();
        
        // Check if this is a Google user
        final isGoogleUser = user.providerData.any((profile) => profile.providerId == 'google.com');
        
        if (isGoogleUser) {
          // For Google users, we need to manually set verification status
          // since they've clicked the verification link and returned to the app
          print('Google user checking verification status - setting verification to true');
          await _authProvider.setFirestoreVerificationStatus(user.uid, email: true);
          
          _navigated = true;
          _pollingTimer?.cancel();
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MainNavigation()),
              (route) => false,
            );
          }
          return;
        } else {
          // For non-Google users, use the existing verification check
          await _checkVerificationStatus();
          if (!_navigated) {
            setState(() { 
              _error = 'Email not verified yet. Please check your inbox and click the verification link.';
            });
          }
        }
      }
    } catch (e) {
      setState(() { _error = 'Error checking verification status.'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _confirmEmailVerified() async {
    setState(() { _isLoading = true; });
    try {
      final user = _authProvider.authService.currentUser;
      if (user != null) {
        // Force reload to get the latest verification status
        await user.reload();
        
        // Check if this is a Google user
        final isGoogleUser = user.providerData.any((profile) => profile.providerId == 'google.com');
        
        if (isGoogleUser) {
          // For Google users, we need to implement a custom verification process
          // since Firebase's emailVerified is often true by default
          setState(() { 
            _error = 'For Google accounts, please use the "Check Verification Status" button after clicking the verification link.';
          });
          return;
        } else {
          // For non-Google users, check Firebase's emailVerified status
          if (!user.emailVerified) {
            setState(() { 
              _error = 'Email not verified. Please check your inbox and click the verification link before confirming.';
            });
            return;
          }
        }
        
        // Only set verification status to true if email is actually verified
        await _authProvider.setFirestoreVerificationStatus(user.uid, email: true);
        print('User manually confirmed email verification - email was actually verified');
        
        _navigated = true;
        _pollingTimer?.cancel();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainNavigation()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      setState(() { _error = 'Error confirming verification status.'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _resendVerificationEmail() async {
    setState(() { _isLoading = true; });
    try {
      await _authProvider.authService.currentUser?.sendEmailVerification();
      setState(() { 
        _resent = true;
        _error = null;
      });
    } catch (e) {
      setState(() { _error = 'Failed to resend verification email.'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _showNotVerifiedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.black,
        title: Text('Email Not Verified', style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold)),
        content: Text('Please check your inbox and verify your email to continue. You can also try the manual check button.', style: AppTheme.bodyMedium.copyWith(color: AppTheme.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a1a1a), Color(0xFF000000)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom - 48, // 48 for padding
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo or Icon
                    Icon(
                      Icons.mark_email_unread_outlined,
                      size: 80,
                      color: AppTheme.primaryGold,
                    ),
                    const SizedBox(height: 32),
                    
                    // Title
                    Text(
                      'Verify Your Email',
                      style: AppTheme.headingLarge.copyWith(
                        color: AppTheme.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    Text(
                      'We\'ve sent a verification link to:',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    
                    // Email
                    Text(
                      _email,
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
                      ),
                      child: FutureBuilder<firebase_auth.User?>(
                        future: Future.value(_authProvider.authService.currentUser),
                        builder: (context, snapshot) {
                          final user = snapshot.data;
                          final isGoogleUser = user?.providerData.any((profile) => profile.providerId == 'google.com') ?? false;
                          
                          return Column(
                            children: [
                              Text(
                                '📧 Check your email inbox',
                                style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '📱 Click the verification link',
                                style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '🔄 Return to this app',
                                style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
                              ),
                              if (isGoogleUser) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '📧 Check your email inbox',
                                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '📱 Click the verification link',
                                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '🔄 Return to this app',
                                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '✅ Tap "Check Verification Status" button',
                                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Error message
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Text(
                          _error!,
                          style: AppTheme.bodySmall.copyWith(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    
                    // Success message
                    if (_resent)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Text(
                          'Verification email sent successfully!',
                          style: AppTheme.bodySmall.copyWith(color: Colors.green),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    
                    // Manual Check Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _manualCheckVerification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isLoading 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.refresh),
                        label: Text(
                          _isLoading ? 'Checking...' : 'Check Verification Status',
                          style: AppTheme.bodyLarge.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Confirm Verification Button (for Google users)
                    FutureBuilder<firebase_auth.User?>(
                      future: Future.value(_authProvider.authService.currentUser),
                      builder: (context, snapshot) {
                        final user = snapshot.data;
                        final isGoogleUser = user?.providerData.any((profile) => profile.providerId == 'google.com') ?? false;
                        
                        if (isGoogleUser) {
                          return Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                ),
                                child: Text(
                                  'For Google accounts, use the "Check Verification Status" button after clicking the verification link.',
                                  style: AppTheme.bodySmall.copyWith(color: Colors.blue),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          );
                        } else {
                          // For non-Google users, show the confirmation button
                          return Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _confirmEmailVerified,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.check_circle),
                                  label: Text(
                                    'Confirm Email Verification',
                                    style: AppTheme.bodyLarge.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          );
                        }
                      },
                    ),
                    
                    // Resend Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _resendVerificationEmail,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryGold,
                          side: BorderSide(color: AppTheme.primaryGold),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.email_outlined),
                        label: Text(
                          'Resend Verification Email',
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.primaryGold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Auto-checking indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryGold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Auto-checking every 3 seconds...',
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 