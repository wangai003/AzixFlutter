import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/secure_wallet_service.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart' as local_auth;

class SecureWalletCreationScreen extends StatefulWidget {
  const SecureWalletCreationScreen({super.key});

  @override
  State<SecureWalletCreationScreen> createState() =>
      _SecureWalletCreationScreenState();
}

class _SecureWalletCreationScreenState
    extends State<SecureWalletCreationScreen> {
  bool _isCreating = false;
  String? _error;
  String? _successMessage;
  bool _acceptTerms = false;
  bool _enableBiometrics = false;

  // Password fields
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Scroll controller for better scrolling behavior
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Add listeners to scroll when keyboard appears
    _passwordController.addListener(_scrollToFocusedField);
    _confirmPasswordController.addListener(_scrollToFocusedField);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToFocusedField() {
    // Small delay to ensure keyboard is fully shown
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent *
              0.3, // Scroll to 30% of max scroll
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'Create Secure Wallet',
          style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
        ),
        backgroundColor: AppTheme.black,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.black, AppTheme.darkGrey.withOpacity(0.3)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Padding(
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    24, // Extra padding for keyboard
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Security Features
                  _buildSecurityFeatures(),

                  const SizedBox(height: 32),

                  // Password Setup
                  _buildPasswordSetup(),

                  const SizedBox(height: 32),

                  // Biometric Options
                  _buildBiometricOptions(),

                  const SizedBox(height: 32),

                  // Terms and Conditions
                  _buildTermsAndConditions(),

                  const SizedBox(height: 32),

                  // Create Wallet Button
                  _buildCreateWalletButton(),

                  const SizedBox(height: 24),

                  // Status Messages
                  if (_error != null) _buildErrorMessage(),
                  if (_successMessage != null) _buildSuccessMessage(),

                  // Extra space at bottom for better UX
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityFeatures() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: AppTheme.primaryGold, size: 28),
              const SizedBox(width: 12),
              Text(
                'Maximum Security Features',
                style: AppTheme.headingMedium.copyWith(
                  color: AppTheme.primaryGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSecurityFeature(
            'AES-GCM Encryption',
            'Your private key is encrypted with military-grade AES-GCM encryption',
            Icons.lock,
          ),
          const SizedBox(height: 12),
          _buildSecurityFeature(
            'Biometric Protection',
            'Access requires fingerprint or Face ID authentication',
            Icons.fingerprint,
          ),
          const SizedBox(height: 12),
          _buildSecurityFeature(
            'Hardware Security',
            'Keys are protected by device hardware security modules',
            Icons.memory,
          ),
          const SizedBox(height: 12),
          _buildSecurityFeature(
            'Zero-Knowledge',
            'Private keys never leave your device in plain text',
            Icons.visibility_off,
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityFeature(
    String title,
    String description,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.green, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordSetup() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock, color: AppTheme.primaryGold, size: 28),
              const SizedBox(width: 12),
              Text(
                'Set Wallet Password',
                style: AppTheme.headingMedium.copyWith(
                  color: AppTheme.primaryGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Choose a strong password to protect your wallet. This password will be required to access your funds.',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
          ),
          const SizedBox(height: 16),

          // Password Field
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: AppTheme.white),
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: TextStyle(color: AppTheme.grey),
              hintText: 'Enter a strong password',
              hintStyle: TextStyle(color: AppTheme.grey.withOpacity(0.5)),
              filled: true,
              fillColor: AppTheme.darkGrey.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.primaryGold.withOpacity(0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.primaryGold.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryGold),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppTheme.grey,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Confirm Password Field
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style: TextStyle(color: AppTheme.white),
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              labelStyle: TextStyle(color: AppTheme.grey),
              hintText: 'Re-enter your password',
              hintStyle: TextStyle(color: AppTheme.grey.withOpacity(0.5)),
              filled: true,
              fillColor: AppTheme.darkGrey.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.primaryGold.withOpacity(0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.primaryGold.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryGold),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: AppTheme.grey,
                ),
                onPressed: () {
                  setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 12),
          Text(
            'Password must be at least 8 characters long',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricOptions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fingerprint, color: AppTheme.primaryGold, size: 28),
              const SizedBox(width: 12),
              Text(
                'Biometric Authentication',
                style: AppTheme.headingMedium.copyWith(
                  color: AppTheme.primaryGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Enable biometric authentication for faster, more secure access to your wallet.',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
          ),
          const SizedBox(height: 16),

          // Biometric Toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkGrey.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _enableBiometrics
                      ? Icons.fingerprint
                      : Icons.fingerprint_outlined,
                  color: _enableBiometrics
                      ? AppTheme.primaryGold
                      : AppTheme.grey,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enable Biometric Login',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Use fingerprint or Face ID for wallet access',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _enableBiometrics,
                  onChanged: (value) {
                    setState(() => _enableBiometrics = value);
                  },
                  activeColor: AppTheme.primaryGold,
                  activeTrackColor: AppTheme.primaryGold.withOpacity(0.3),
                ),
              ],
            ),
          ),

          if (_enableBiometrics) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Biometric authentication will be required for all wallet operations.',
                      style: AppTheme.bodySmall.copyWith(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTermsAndConditions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Terms & Conditions',
            style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
          ),
          const SizedBox(height: 16),
          Text(
            'By creating a secure wallet, you acknowledge that:',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
          ),
          const SizedBox(height: 12),
          _buildTermItem('Your private key is encrypted and stored securely'),
          _buildTermItem(
            'Biometric authentication is required for transactions',
          ),
          _buildTermItem(
            'You are responsible for backing up your recovery phrase',
          ),
          _buildTermItem(
            'Lost biometrics may require wallet recovery procedures',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _acceptTerms,
                onChanged: (value) {
                  setState(() => _acceptTerms = value ?? false);
                },
                activeColor: AppTheme.primaryGold,
                checkColor: AppTheme.black,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'I accept the terms and conditions',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTermItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: AppTheme.primaryGold)),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateWalletButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_isCreating || !_acceptTerms) ? null : _createSecureWallet,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGold,
          foregroundColor: AppTheme.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: AppTheme.grey.withOpacity(0.3),
        ),
        child: _isCreating
            ? const CircularProgressIndicator(color: AppTheme.black)
            : Text(
                'Create Secure Wallet',
                style: AppTheme.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _acceptTerms ? AppTheme.black : AppTheme.grey,
                ),
              ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: AppTheme.bodyMedium.copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _successMessage!,
              style: AppTheme.bodyMedium.copyWith(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createSecureWallet() async {
    setState(() {
      _isCreating = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final authProvider = Provider.of<local_auth.AuthProvider>(
        context,
        listen: false,
      );
      final user = authProvider.user;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Validate password
      final password = _passwordController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();

      if (password.isEmpty) {
        throw Exception('Please enter a password');
      }

      if (password.length < 8) {
        throw Exception('Password must be at least 8 characters long');
      }

      if (password != confirmPassword) {
        throw Exception('Passwords do not match');
      }

      // Show biometric setup dialog if biometrics are enabled
      if (_enableBiometrics) {
        final biometricResult = await _showBiometricSetupDialog();
        if (!biometricResult) {
          setState(() => _isCreating = false);
          return;
        }
      }

      // Create secure wallet with password and biometric settings
      final result = await SecureWalletService.createSecureWallet(
        userId: user.uid,
        password: password,
        recoveryPhrase: null, // Could be generated separately
        enableBiometrics: _enableBiometrics,
      );

      if (result['success'] == true) {
        setState(() {
          _successMessage = result['message'];
        });

        // Clear password fields for security
        _passwordController.clear();
        _confirmPasswordController.clear();

        // Navigate back after success
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop(true); // Return success
        }
      } else {
        setState(() {
          _error = result['message'] ?? 'Failed to create secure wallet';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error creating wallet: $e';
      });
    } finally {
      setState(() => _isCreating = false);
    }
  }

  Future<bool> _showBiometricSetupDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.darkGrey,
            title: Text(
              'Setup Biometric Authentication',
              style: TextStyle(color: AppTheme.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fingerprint, size: 48, color: AppTheme.primaryGold),
                const SizedBox(height: 16),
                Text(
                  'Your wallet will be protected by biometric authentication. Please setup fingerprint or Face ID on your device.',
                  style: TextStyle(color: AppTheme.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Note: This is a simulation. In production, this would use actual WebAuthn API.',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel', style: TextStyle(color: AppTheme.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: AppTheme.black,
                ),
                child: const Text('Setup Biometrics'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
