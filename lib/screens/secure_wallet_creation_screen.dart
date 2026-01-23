import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:provider/provider.dart';
import '../services/secure_wallet_service.dart';
import '../services/akofa_tag_service.dart';
import '../services/polygon_wallet_service.dart';
import '../services/biometric_service.dart';
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
  bool _enableBiometrics = true; // Preferred, but not mandatory
  int _currentStep = 0; // Step-by-step progress: 0=password, 1=biometric, 2=creating
  bool _biometricsSupported = false;
  bool _biometricsChecked = false;
  String? _biometricSupportError;
  String? _seedPhrase;
  bool _seedPhraseAcknowledged = false;

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
    // Check biometric support early
    _checkBiometricSupport();
  }

  Future<void> _checkBiometricSupport() async {
    final supportCheck = await BiometricService.checkBiometricSupport();
    setState(() {
      _biometricsSupported = supportCheck['biometricsSupported'] == true;
      _biometricsChecked = true;
      _biometricSupportError = supportCheck['error'] as String?;
      // If biometrics not supported, disable by default
      if (!_biometricsSupported) {
        _enableBiometrics = false;
      }
    });
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
                  // Step-by-step Progress Indicator
                  _buildStepIndicator(),

                  const SizedBox(height: 24),

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

  Widget _buildStepIndicator() {
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
          Text(
            'Wallet Creation Steps',
            style: AppTheme.headingMedium.copyWith(
              color: AppTheme.primaryGold,
            ),
          ),
          const SizedBox(height: 16),
          _buildStepItem(
            step: 1,
            title: 'Set Password',
            description: 'Create a strong password (min 8 characters)',
            isActive: _currentStep == 0,
            isCompleted: _currentStep > 0,
          ),
          const SizedBox(height: 12),
          _buildStepItem(
            step: 2,
            title: 'Setup Biometrics',
            description: 'Enable fingerprint or Face ID authentication',
            isActive: _currentStep == 1,
            isCompleted: _currentStep > 1,
          ),
          const SizedBox(height: 12),
          _buildStepItem(
            step: 3,
            title: 'Create Wallet',
            description: 'Generate keys, fund wallet, and setup trustlines',
            isActive: _currentStep == 2,
            isCompleted: _currentStep > 2,
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required int step,
    required String title,
    required String description,
    required bool isActive,
    required bool isCompleted,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? Colors.green
                : isActive
                    ? AppTheme.primaryGold
                    : AppTheme.grey.withOpacity(0.3),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '$step',
                    style: TextStyle(
                      color: isActive ? AppTheme.black : AppTheme.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.bodyMedium.copyWith(
                  color: isActive ? AppTheme.primaryGold : AppTheme.white,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.grey,
                ),
              ),
            ],
          ),
        ),
      ],
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
    if (!_biometricsChecked) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.darkGrey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
              const SizedBox(width: 8),
              if (_biometricsSupported)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Text(
                    'AVAILABLE',
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Text(
                    'NOT AVAILABLE',
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_biometricsSupported) ...[
            Text(
              'Biometric authentication is strongly recommended for maximum security. Your wallet will be protected by both password and biometric authentication.',
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
                          'Enable Biometric Protection',
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
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You will be prompted to set up biometric authentication during wallet creation.',
                        style: AppTheme.bodySmall.copyWith(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.5), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Security Warning',
                            style: AppTheme.bodyMedium.copyWith(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You have disabled biometric authentication. This significantly reduces your wallet security.',
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.red.shade200,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSecurityRiskItem(
                      'Password-only wallets are more vulnerable to unauthorized access',
                    ),
                    _buildSecurityRiskItem(
                      'If someone gains access to your password, they can access your funds',
                    ),
                    _buildSecurityRiskItem(
                      'Biometric authentication adds an extra layer of protection',
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: Colors.orange, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Recommendation: Enable biometrics for maximum security. Your fingerprint or Face ID cannot be stolen or guessed.',
                              style: AppTheme.bodySmall.copyWith(
                                color: Colors.orange.shade200,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Biometric Authentication Not Available',
                          style: AppTheme.bodyMedium.copyWith(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your device or browser does not support biometric authentication. Your wallet will be created with password-only protection.',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                  ),
                  if (_biometricSupportError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Reason: $_biometricSupportError',
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.orange,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You can add biometric protection later from wallet settings if you enable it on your device.',
                            style: AppTheme.bodySmall.copyWith(color: Colors.blue),
                          ),
                        ),
                      ],
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

  Widget _buildSecurityRiskItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade300, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodySmall.copyWith(
                color: Colors.red.shade200,
                fontSize: 11,
              ),
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

      // Try to setup biometrics if supported and enabled
      bool biometricSetupSuccess = false;
      if (_biometricsSupported && _enableBiometrics) {
        setState(() => _currentStep = 1);
        final biometricResult = await _showBiometricSetupDialog();
        if (biometricResult) {
          biometricSetupSuccess = true;
        } else {
          // User cancelled or setup failed - ask if they want to continue without biometrics
          final continueWithout = await _showContinueWithoutBiometricsDialog();
          if (!continueWithout) {
            setState(() {
              _isCreating = false;
              _currentStep = 0;
            });
            return;
          }
        }
      } else if (!_biometricsSupported) {
        // Biometrics not available - show explanation and continue
        final continueWithout = await _showBiometricNotAvailableDialog();
        if (!continueWithout) {
          setState(() {
            _isCreating = false;
            _currentStep = 0;
          });
          return;
        }
      }

      // Generate and show seed phrase (one-time display)
      if (!_seedPhraseAcknowledged) {
        _seedPhrase ??= bip39.generateMnemonic();
        final seedConfirmed = await _showSeedPhraseDialog(_seedPhrase!);
        if (!seedConfirmed) {
          setState(() {
            _isCreating = false;
            _currentStep = 0;
          });
          return;
        }
        _seedPhraseAcknowledged = true;
      }

      // Create secure wallet with biometric settings (if available and enabled)
      setState(() => _currentStep = 2);
      final stellarResult = await SecureWalletService.createSecureWallet(
        userId: user.uid,
        password: password,
        recoveryPhrase: _seedPhrase,
        enableBiometrics: _biometricsSupported && _enableBiometrics && biometricSetupSuccess,
      );

      // Create Polygon wallet if Stellar wallet creation was successful
      Map<String, dynamic>? polygonResult;
      if (stellarResult['success'] == true) {
        print('🔑 Creating Polygon wallet...');
        polygonResult = await PolygonWalletService.createSecurePolygonWallet(
          userId: user.uid,
          password: password,
          recoveryPhrase: _seedPhrase,
        );

        if (polygonResult['success'] == true) {
          print('✅ Polygon wallet created successfully');
        } else {
          print('⚠️ Polygon wallet creation failed: ${polygonResult['error']}');
          // Don't fail the entire process for Polygon wallet issues
        }
      }

      final result = stellarResult; // Use Stellar result as primary

      if (result['success'] == true) {
        // Check AKOFA tag creation and linking
        await _verifyAkofaTagCreation(user.uid);
        _seedPhrase = null;
        _seedPhraseAcknowledged = false;

        // Update success message to include both wallets
        String successMsg = result['message'];
        if (polygonResult != null && polygonResult['success'] == true) {
          successMsg +=
              ' Both Stellar and Polygon wallets created successfully!';
        } else {
          successMsg += ' Stellar wallet created successfully!';
        }

        setState(() {
          _successMessage = successMsg;
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

  Future<bool> _showSeedPhraseDialog(String seedPhrase) async {
    return (await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            bool confirmed = false;
            bool copied = false;
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: const Text('Write down your recovery phrase'),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'This 12-word recovery phrase can restore your wallet if you lose access.',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'You will only see this once. Store it offline and keep it private.',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: SelectableText(
                            seedPhrase,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: seedPhrase),
                                );
                                setDialogState(() {
                                  copied = true;
                                });
                              },
                              icon: const Icon(Icons.copy),
                              label: const Text('Copy'),
                            ),
                            const SizedBox(width: 12),
                            if (copied)
                              const Text(
                                'Copied',
                                style: TextStyle(color: Colors.green),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Important:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• Anyone with this phrase can access your wallet.\n'
                          '• We cannot recover it for you.\n'
                          '• Do not store it in screenshots or cloud notes.',
                        ),
                        const SizedBox(height: 16),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'I have written down my recovery phrase and understand it is the only way to recover my wallet.',
                          ),
                          value: confirmed,
                          onChanged: (value) {
                            setDialogState(() {
                              confirmed = value ?? false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: confirmed
                          ? () => Navigator.of(context).pop(true)
                          : null,
                      child: const Text('Continue'),
                    ),
                  ],
                );
              },
            );
          },
        )) ??
        false;
  }

  /// Verify AKOFA tag creation and linking during wallet creation
  Future<void> _verifyAkofaTagCreation(String userId) async {
    try {
      print('🔍 Verifying AKOFA tag creation and linking...');

      // Check if tag was created and linked
      final tagResult = await AkofaTagService.getUserTag(userId);

      if (tagResult['success'] == true) {
        final tag = tagResult['tag'];
        final publicKey = tagResult['publicKey'];

        print('✅ AKOFA tag verified: $tag linked to wallet $publicKey');

        // Additional verification: check if tag resolves correctly
        final resolveResult = await AkofaTagService.resolveTag(
          tag,
          blockchain: 'stellar',
        );

        if (resolveResult['success'] == true &&
            resolveResult['publicKey'] == publicKey) {
          print('✅ AKOFA tag resolution verified');
        } else {
          print(
            '⚠️ AKOFA tag resolution failed - this may cause issues with payments',
          );
        }
      } else {
        print(
          '⚠️ AKOFA tag creation failed - wallet created but tag not linked',
        );
        print('   Error: ${tagResult['error']}');
      }
    } catch (e) {
      print('⚠️ AKOFA tag verification failed: $e');
      // Don't fail wallet creation for tag issues
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
              style: TextStyle(color: AppTheme.primaryGold),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fingerprint, size: 64, color: AppTheme.primaryGold),
                const SizedBox(height: 16),
                Text(
                  'Step 2: Setup Biometrics',
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Biometric authentication provides maximum security. Please authenticate using your fingerprint or Face ID.',
                  style: TextStyle(color: AppTheme.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This step is recommended for enhanced security. You can skip if needed.',
                          style: TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Skip', style: TextStyle(color: AppTheme.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop(true);
                },
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

  Future<bool> _showContinueWithoutBiometricsDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.darkGrey,
            title: Text(
              'Security Risk Warning',
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Biometric setup was skipped or failed.',
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.5), width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚠️ Security Risks of Password-Only Protection:',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildRiskItem('Passwords can be stolen through phishing or keyloggers'),
                        _buildRiskItem('Passwords can be guessed or brute-forced'),
                        _buildRiskItem('If your device is compromised, your password may be exposed'),
                        _buildRiskItem('No additional verification layer for transactions'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Biometric authentication uses your unique fingerprint or face, which cannot be stolen or replicated.',
                            style: TextStyle(color: Colors.orange, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You can add biometric protection later from wallet settings.',
                            style: TextStyle(color: Colors.blue, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Go Back',
                  style: TextStyle(color: AppTheme.grey, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: AppTheme.white,
                ),
                child: const Text('I Understand the Risks - Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildRiskItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.close, color: Colors.red.shade300, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.red.shade200, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showBiometricNotAvailableDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.darkGrey,
            title: Text(
              'Biometrics Not Available',
              style: TextStyle(color: Colors.orange),
              textAlign: TextAlign.center,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 64, color: Colors.orange),
                  const SizedBox(height: 16),
                  Text(
                    'Your device or browser does not support biometric authentication.',
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚠️ Password-Only Protection Limitations:',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildRiskItem('More vulnerable to unauthorized access'),
                        _buildRiskItem('Passwords can be stolen or compromised'),
                        _buildRiskItem('No additional verification for transactions'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tip: Use a strong, unique password and never share it. Consider enabling biometrics on your device if possible.',
                            style: TextStyle(color: Colors.blue, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your wallet will be created with password-only protection. You can add biometric protection later if you enable it on your device.',
                    style: TextStyle(color: AppTheme.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
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
                child: const Text('Continue with Password Only'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
