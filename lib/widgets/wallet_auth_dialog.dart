import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_session_provider.dart';
import '../theme/app_theme.dart';

/// Dialog for wallet authentication after session timeout
/// Supports both password and biometric authentication
class WalletAuthDialog extends StatefulWidget {
  final bool showBiometricOption;
  final String title;
  final String message;

  const WalletAuthDialog({
    Key? key,
    this.showBiometricOption = true,
    this.title = 'Wallet Authentication Required',
    this.message = 'Your wallet session has expired. Please authenticate to continue.',
  }) : super(key: key);

  @override
  State<WalletAuthDialog> createState() => _WalletAuthDialogState();
}

class _WalletAuthDialogState extends State<WalletAuthDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isAuthenticating = false;
  String? _error;
  bool _usePassword = false; // Start with biometric if available

  @override
  void initState() {
    super.initState();
    // Try biometric authentication first if enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sessionProvider = Provider.of<WalletSessionProvider>(
        context,
        listen: false,
      );
      
      if (widget.showBiometricOption && 
          sessionProvider.biometricsEnabled && 
          !_usePassword) {
        _authenticateWithBiometric();
      } else {
        // Show password input
        setState(() => _usePassword = true);
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = Provider.of<WalletSessionProvider>(context);
    final showBiometric = widget.showBiometricOption && 
                          sessionProvider.biometricsEnabled;

    return WillPopScope(
      onWillPop: () async => false, // Prevent dismissing without authentication
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.darkGrey,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryGold.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _usePassword ? Icons.lock : Icons.fingerprint,
                  color: AppTheme.primaryGold,
                  size: 48,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Title
              Text(
                widget.title,
                style: AppTheme.headingMedium.copyWith(
                  color: AppTheme.primaryGold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // Message
              Text(
                widget.message,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.grey,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Authentication UI
              if (_usePassword) ...[
                // Password Input
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  enabled: !_isAuthenticating,
                  style: TextStyle(color: AppTheme.white),
                  decoration: InputDecoration(
                    labelText: 'Wallet Password',
                    labelStyle: TextStyle(color: AppTheme.grey),
                    hintText: 'Enter your wallet password',
                    hintStyle: TextStyle(color: AppTheme.grey.withOpacity(0.5)),
                    filled: true,
                    fillColor: AppTheme.black.withOpacity(0.3),
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
                    prefixIcon: Icon(Icons.lock, color: AppTheme.grey),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppTheme.grey,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  onSubmitted: (_) => _authenticateWithPassword(),
                ),
                
                const SizedBox(height: 24),
                
                // Authenticate Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isAuthenticating ? null : _authenticateWithPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: AppTheme.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isAuthenticating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.black,
                            ),
                          )
                        : Text(
                            'Authenticate',
                            style: AppTheme.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ] else ...[
                // Biometric Authentication UI
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      if (_isAuthenticating) ...[
                        const CircularProgressIndicator(
                          color: AppTheme.primaryGold,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Waiting for biometric authentication...',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ] else ...[
                        Icon(
                          Icons.fingerprint,
                          color: AppTheme.primaryGold,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Touch sensor to authenticate',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Retry Biometric Button
                if (!_isAuthenticating)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _authenticateWithBiometric,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryGold,
                        side: BorderSide(color: AppTheme.primaryGold),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Try Again'),
                    ),
                  ),
              ],
              
              // Error Message
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppTheme.bodySmall.copyWith(
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Switch Authentication Method
              if (showBiometric) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isAuthenticating
                      ? null
                      : () {
                          setState(() {
                            _usePassword = !_usePassword;
                            _error = null;
                          });
                          
                          // If switching to biometric, try authentication immediately
                          if (!_usePassword) {
                            _authenticateWithBiometric();
                          }
                        },
                  child: Text(
                    _usePassword
                        ? 'Use Biometric Authentication'
                        : 'Use Password Instead',
                    style: TextStyle(
                      color: AppTheme.primaryGold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 8),
              
              // Cancel Button (goes back to main app)
              TextButton(
                onPressed: _isAuthenticating
                    ? null
                    : () {
                        Navigator.of(context).pop(false);
                      },
                child: Text(
                  'Go Back to App',
                  style: TextStyle(
                    color: AppTheme.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _authenticateWithPassword() async {
    if (_passwordController.text.trim().isEmpty) {
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
      final sessionProvider = Provider.of<WalletSessionProvider>(
        context,
        listen: false,
      );

      final result = await sessionProvider.authenticateWithPassword(
        _passwordController.text,
      );

      if (result['success'] == true) {
        // Clear password
        _passwordController.clear();
        
        // Close dialog with success
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _error = result['error'] ?? 'Authentication failed';
          _isAuthenticating = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Authentication error: $e';
        _isAuthenticating = false;
      });
    }
  }

  Future<void> _authenticateWithBiometric() async {
    setState(() {
      _isAuthenticating = true;
      _error = null;
    });

    try {
      final sessionProvider = Provider.of<WalletSessionProvider>(
        context,
        listen: false,
      );

      final result = await sessionProvider.authenticateWithBiometrics();

      if (result['success'] == true) {
        // Close dialog with success
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _error = result['error'] ?? 'Biometric authentication failed';
          _isAuthenticating = false;
          
          // Auto-switch to password if biometric fails
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _usePassword = true;
                _error = 'Biometric authentication failed. Please use password.';
              });
            }
          });
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Authentication error: $e';
        _isAuthenticating = false;
        _usePassword = true; // Fall back to password
      });
    }
  }
}

/// Show wallet authentication dialog
/// Returns true if authentication was successful, false otherwise
Future<bool> showWalletAuthDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const WalletAuthDialog(),
  );
  
  return result ?? false;
}

