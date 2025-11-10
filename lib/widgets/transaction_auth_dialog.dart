import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart' as local_auth;
import '../services/biometric_service.dart';
import '../services/secure_wallet_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TransactionAuthDialog extends StatefulWidget {
  final String amount;
  final String assetCode;
  final String recipient;

  const TransactionAuthDialog({
    Key? key,
    required this.amount,
    required this.assetCode,
    required this.recipient,
  }) : super(key: key);

  @override
  State<TransactionAuthDialog> createState() => _TransactionAuthDialogState();
}

class _TransactionAuthDialogState extends State<TransactionAuthDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isAuthenticating = false;
  String? _error;
  bool _biometricsAvailable = false;
  bool _biometricsEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final authProvider = Provider.of<local_auth.AuthProvider>(
        context,
        listen: false,
      );
      final user = authProvider.user;

      if (user != null) {
        // Check if biometrics are supported on device
        final biometricSupport = await BiometricService.checkBiometricSupport();
        final biometricsSupported =
            biometricSupport['biometricsSupported'] as bool;

        // Check if user has biometrics enabled for their wallet
        final hasSecureWallet = await SecureWalletService.hasSecureWallet(
          user.uid,
        );
        if (hasSecureWallet) {
          final walletDoc = await FirebaseFirestore.instance
              .collection('secure_wallets')
              .doc(user.uid)
              .get();

          if (walletDoc.exists) {
            final walletData = walletDoc.data()!;
            final biometricsEnabled =
                walletData['biometricsEnabled'] as bool? ?? false;
            setState(() {
              _biometricsAvailable = biometricsSupported;
              _biometricsEnabled = biometricsEnabled;
            });
          }
        }
      }
    } catch (e) {
      // Silently fail - biometrics will just not be available
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    setState(() {
      _isAuthenticating = true;
      _error = null;
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

      // Perform biometric authentication
      final biometricResult = await BiometricService.authenticateWithBiometrics(
        localizedReason: 'Authenticate to sign transaction',
      );

      if (biometricResult['success']) {
        // Biometric authentication successful - return biometric auth result
        if (mounted) {
          Navigator.of(context).pop({'method': 'biometric', 'success': true});
        }
      } else {
        setState(() {
          _error =
              biometricResult['error'] ?? 'Biometric authentication failed';
          _isAuthenticating = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Biometric authentication error: $e';
        _isAuthenticating = false;
      });
    }
  }

  Future<void> _authenticateWithPassword() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() {
        _error = 'Please enter your password';
      });
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _error = null;
    });

    try {
      // Verify password with Firebase Auth
      final authProvider = Provider.of<local_auth.AuthProvider>(
        context,
        listen: false,
      );
      final currentUser = authProvider.user;

      if (currentUser == null || currentUser.email == null) {
        throw Exception('Authentication required. Please log in again.');
      }

      // Re-authenticate user with password
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: password,
      );
      await currentUser.reauthenticateWithCredential(credential);

      // Password authentication successful
      if (mounted) {
        Navigator.of(
          context,
        ).pop({'method': 'password', 'password': password, 'success': true});
      }
    } catch (e) {
      setState(() {
        _error = 'Invalid password. Please try again.';
        _isAuthenticating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.black,
      title: Text(
        'Confirm Transaction',
        style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold),
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Transaction details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.grey.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'Send ${widget.amount} ${widget.assetCode}',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To: ${widget.recipient}',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Authentication options
            Text(
              'Choose authentication method:',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Biometric option (if available and enabled)
            if (_biometricsAvailable && _biometricsEnabled) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isAuthenticating
                      ? null
                      : _authenticateWithBiometrics,
                  icon: Icon(Icons.fingerprint, color: AppTheme.black),
                  label: Text(
                    'Use Biometrics',
                    style: TextStyle(color: AppTheme.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    disabledBackgroundColor: AppTheme.grey.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Or use password',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],

            // Password option
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              enabled: !_isAuthenticating,
              decoration: InputDecoration(
                labelText: 'Enter Password',
                labelStyle: TextStyle(color: AppTheme.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.primaryGold),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: AppTheme.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              style: const TextStyle(color: AppTheme.white),
              onSubmitted: (_) => _authenticateWithPassword(),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],

            if (_isAuthenticating) ...[
              const SizedBox(height: 16),
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryGold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isAuthenticating
              ? null
              : () => Navigator.of(context).pop(null),
          child: Text('Cancel', style: TextStyle(color: AppTheme.grey)),
        ),
        ElevatedButton(
          onPressed: _isAuthenticating ? null : _authenticateWithPassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGold,
            foregroundColor: AppTheme.black,
            disabledBackgroundColor: AppTheme.grey.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Confirm with Password'),
        ),
      ],
    );
  }
}
