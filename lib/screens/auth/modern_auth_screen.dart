import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/google_sign_in_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

class ModernAuthScreen extends StatefulWidget {
  const ModernAuthScreen({Key? key}) : super(key: key);

  @override
  State<ModernAuthScreen> createState() => _ModernAuthScreenState();
}

class _ModernAuthScreenState extends State<ModernAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  bool _isSignUp = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool success;

    if (_isSignUp) {
      success = await authProvider.signUpWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
      );
    } else {
      success = await authProvider.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }

    // Success is handled by the Wrapper routing
    // No need to show success message or navigate manually
  }

  Future<void> _handleGoogleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signInWithGoogle();
    
    // Success is handled by the Wrapper routing
    // No need to show success message or navigate manually
  }

  void _toggleAuthMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _emailController.clear();
      _passwordController.clear();
      _firstNameController.clear();
      _lastNameController.clear();
    });
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width > 700;

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
                          // Logo/Animation
                          Lottie.asset(
                            'assets/animations/login_animation.json',
                            height: 120,
                            width: 120,
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Title
                          Text(
                            _isSignUp ? 'Create Account' : 'Welcome Back',
                            style: AppTheme.headingLarge.copyWith(
                              color: AppTheme.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3, end: 0),
                          
                          const SizedBox(height: 8),
                          
                          // Subtitle
                          Text(
                            _isSignUp 
                              ? 'Sign up to get started with AZIX'
                              : 'Sign in to continue to AZIX',
                            style: AppTheme.bodyMedium.copyWith(
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3, end: 0),
                          
                          const SizedBox(height: 32),
                          
                          // Auth Form
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                if (_isSignUp) ...[
                                  // First Name field (only for sign up)
                                  TextFormField(
                                    controller: _firstNameController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'First Name',
                                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                      prefixIcon: Icon(Icons.person, color: Colors.white.withOpacity(0.7)),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppTheme.primaryGold),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (_isSignUp && (value == null || value.trim().isEmpty)) {
                                        return 'Please enter your first name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Last Name field (only for sign up)
                                  TextFormField(
                                    controller: _lastNameController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Last Name',
                                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                      prefixIcon: Icon(Icons.person, color: Colors.white.withOpacity(0.7)),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppTheme.primaryGold),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (_isSignUp && (value == null || value.trim().isEmpty)) {
                                        return 'Please enter your last name';
                                      }
                                      return null;
                                    },
                                  ),
                                ],

                                // Email field
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                    prefixIcon: Icon(Icons.email, color: Colors.white.withOpacity(0.7)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: AppTheme.primaryGold),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Password field
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: !_isPasswordVisible,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                    prefixIcon: Icon(Icons.lock, color: Colors.white.withOpacity(0.7)),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      onPressed: _togglePasswordVisibility,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: AppTheme.primaryGold),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    if (_isSignUp && value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                
                                const SizedBox(height: 24),
                                
                                // Sign In/Up Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: authProvider.isLoading ? null : _handleEmailAuth,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryGold,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: authProvider.isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                            ),
                                          )
                                        : Text(
                                            _isSignUp ? 'Create Account' : 'Sign In',
                                            style: AppTheme.bodyLarge.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Divider
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR',
                                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Google Sign In Button
                          GoogleSignInButton(
                            onPressed: authProvider.isLoading ? () {} : _handleGoogleSignIn,
                            isLoading: authProvider.isLoading,
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Toggle Auth Mode
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isSignUp ? 'Already have an account?' : 'Don\'t have an account?',
                                style: TextStyle(color: Colors.white.withOpacity(0.7)),
                              ),
                              TextButton(
                                onPressed: _toggleAuthMode,
                                child: Text(
                                  _isSignUp ? 'Sign In' : 'Sign Up',
                                  style: TextStyle(
                                    color: AppTheme.primaryGold,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          // Error Message
                          if (authProvider.error != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Text(
                                authProvider.error!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 16),
                          
                          // Terms & Privacy
                          Text(
                            'By signing in, you agree to our Terms & Privacy Policy.',
                            style: AppTheme.bodySmall.copyWith(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
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
} 