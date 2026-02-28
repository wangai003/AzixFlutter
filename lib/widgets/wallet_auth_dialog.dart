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
  final TextEditingController _seedPhraseController = TextEditingController();
  bool _obscureSeedPhrase = true;
  bool _isAuthenticating = false;
  String? _error;
  bool _useSeedPhrase = true; // Always use seed phrase for authentication

  @override
  void initState() {
    super.initState();
    // Always show seed phrase input
    setState(() => _useSeedPhrase = true);
  }

  @override
  void dispose() {
    _seedPhraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  Icons.vpn_key,
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
              
              // Seed Phrase Input
              TextField(
                controller: _seedPhraseController,
                obscureText: _obscureSeedPhrase,
                enabled: !_isAuthenticating,
                maxLines: _obscureSeedPhrase ? 1 : 4,
                style: TextStyle(color: AppTheme.white),
                decoration: InputDecoration(
                  labelText: 'Seed Phrase',
                  labelStyle: TextStyle(color: AppTheme.grey),
                  hintText: 'Enter your 12-word recovery phrase',
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
                  prefixIcon: Icon(Icons.vpn_key, color: AppTheme.grey),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureSeedPhrase
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppTheme.grey,
                    ),
                    onPressed: () {
                      setState(() => _obscureSeedPhrase = !_obscureSeedPhrase);
                    },
                  ),
                ),
                onSubmitted: (_) => _authenticateWithSeedPhrase(),
              ),
              
              const SizedBox(height: 16),
              
              // Info text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primaryGold, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Enter your 12-word recovery phrase to access your wallet',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Authenticate Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isAuthenticating ? null : _authenticateWithSeedPhrase,
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

  Future<void> _authenticateWithSeedPhrase() async {
    final seedPhrase = _seedPhraseController.text.trim();
    if (seedPhrase.isEmpty) {
      setState(() {
        _error = 'Please enter your seed phrase';
      });
      return;
    }

    // Validate seed phrase format (should be 12 or 24 words)
    final words = seedPhrase.split(RegExp(r'\s+'));
    if (words.length != 12 && words.length != 24) {
      setState(() {
        _error = 'Seed phrase must be 12 or 24 words';
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

      final result = await sessionProvider.authenticateWithSeedPhrase(seedPhrase);

      if (result['success'] == true) {
        // Clear seed phrase
        _seedPhraseController.clear();
        
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

