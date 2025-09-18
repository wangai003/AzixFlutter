import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../screens/user_registration_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'dart:async';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({Key? key}) : super(key: key);

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> with WidgetsBindingObserver {
  bool _isResending = false;
  bool _isChecking = false;
  Timer? _verificationTimer;
  bool _isAutoChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startAutoVerification();
  }

  @override
  void dispose() {
    _verificationTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Check verification when app comes back to foreground
      _checkVerificationStatus();
    }
  }

  void _startAutoVerification() {
    _isAutoChecking = true;
    // Check immediately
    _checkVerificationStatus();
    
    // Then check every 3 seconds
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _checkVerificationStatus();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _checkVerificationStatus() async {
    if (!mounted || _isChecking) return;
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final needsVerification = await authProvider.needsEmailVerification();
      
      if (!needsVerification && mounted) {
        // Email verified, automatically proceed
        _verificationTimer?.cancel();
        _navigateToProfileCompletion();
      }
    } catch (e) {
      // Silently handle errors during auto-check
    }
  }

  void _navigateToProfileCompletion() {
    // Stop auto-verification
    _verificationTimer?.cancel();
    setState(() {
      _isAutoChecking = false;
    });
    
    // Navigate to profile completion
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const UserRegistrationScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    
    return Scaffold(
      backgroundColor: AppTheme.black,
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
                constraints: const BoxConstraints(maxWidth: 420),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Verification Animation
                          Lottie.asset(
                            'assets/animations/login_animation.json',
                            height: 120,
                            width: 120,
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Title
                          Text(
                            'Verify Your Email',
                            style: AppTheme.headingLarge.copyWith(
                              color: AppTheme.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3, end: 0),
                          
                          const SizedBox(height: 16),
                          
                          // Subtitle
                          Text(
                            'We\'ve sent a verification link to:',
                            style: AppTheme.bodyMedium.copyWith(
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3, end: 0),
                          
                          const SizedBox(height: 8),
                          
                          // Email Display
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGold.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primaryGold.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              user?.email ?? 'user@example.com',
                              style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.primaryGold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3, end: 0),
                          
                          const SizedBox(height: 24),
                          
                          // Instructions
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.darkGrey.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.blue,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Check your email inbox',
                                        style: AppTheme.bodyLarge.copyWith(
                                          color: AppTheme.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.link,
                                      color: Colors.blue,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Click the verification link',
                                        style: AppTheme.bodyLarge.copyWith(
                                          color: AppTheme.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.refresh,
                                      color: Colors.blue,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Return here and continue',
                                        style: AppTheme.bodyLarge.copyWith(
                                          color: AppTheme.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.3, end: 0),
                          
                          const SizedBox(height: 32),
                          
                          // Auto-verification Status
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGold.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primaryGold.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isAutoChecking) ...[
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Automatically checking verification status...',
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: AppTheme.primaryGold,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ] else ...[
                                  Icon(
                                    Icons.check_circle,
                                    color: AppTheme.primaryGold,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Verification complete!',
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: AppTheme.primaryGold,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ).animate().fadeIn(delay: 1000.ms).slideY(begin: 0.3, end: 0),
                          
                          const SizedBox(height: 16),
                          
                          // Manual Check Button (Fallback)
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: _isChecking ? null : _manualCheckVerification,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryGold,
                                side: BorderSide(color: AppTheme.primaryGold),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isChecking
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
                                      ),
                                    )
                                  : Text(
                                      'Check Verification Status',
                                      style: AppTheme.bodyLarge.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ).animate().fadeIn(delay: 1200.ms).slideY(begin: 0.3, end: 0),
                          
                          const SizedBox(height: 16),
                          
                          // Resend Button
                          TextButton(
                            onPressed: _isResending ? null : _resendVerification,
                            child: _isResending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
                                    ),
                                  )
                                : Text(
                                    'Resend Verification Email',
                                    style: TextStyle(
                                      color: AppTheme.primaryGold,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ).animate().fadeIn(delay: 1200.ms).slideY(begin: 0.3, end: 0),
                          
                          const SizedBox(height: 24),
                          
                          // Help Text
                          Text(
                            'The system automatically checks your verification status every 3 seconds. You can also manually check or resend the email.',
                            style: AppTheme.bodySmall.copyWith(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ).animate().fadeIn(delay: 1400.ms).slideY(begin: 0.3, end: 0),
                        ],
                      ),
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

  Future<void> _manualCheckVerification() async {
    setState(() => _isChecking = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final needsVerification = await authProvider.needsEmailVerification();
      
      if (!needsVerification && mounted) {
        // Email verified, show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to profile completion
        _navigateToProfileCompletion();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email not verified yet. Please check your inbox and click the verification link.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking verification: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _resendVerification() async {
    setState(() => _isResending = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.sendEmailVerification();
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? 'Failed to send verification email'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }
}
