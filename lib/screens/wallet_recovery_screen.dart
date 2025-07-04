import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import '../providers/auth_provider.dart';
import '../providers/stellar_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';

class WalletRecoveryScreen extends StatefulWidget {
  const WalletRecoveryScreen({Key? key}) : super(key: key);

  @override
  State<WalletRecoveryScreen> createState() => _WalletRecoveryScreenState();
}

class _WalletRecoveryScreenState extends State<WalletRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _secretKeyController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _showSecretKey = false;
  bool _createNewWallet = false;

  @override
  void dispose() {
    _secretKeyController.dispose();
    super.dispose();
  }

  Future<void> _recoverWallet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
      
      if (_createNewWallet) {
        // Create a new wallet
        await stellarProvider.createWallet(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New wallet created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pop(true);
      } else {
        // Recover using provided secret key
        final secretKey = _secretKeyController.text.trim();
        
        // Validate the secret key format
        try {
          KeyPair.fromSecretSeed(secretKey);
        } catch (e) {
          setState(() {
            _isLoading = false;
            _error = 'Invalid secret key format';
          });
          return;
        }
        
        // Attempt to recover the wallet
        final success = await stellarProvider.recoverWalletWithSecretKey(secretKey);
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wallet recovered successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _error = 'Failed to recover wallet';
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Recovery'),
        backgroundColor: AppTheme.black,
        foregroundColor: AppTheme.primaryGold,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              
              // Header
              Text(
                'Wallet Recovery',
                style: AppTheme.headingLarge.copyWith(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your wallet encryption appears to be corrupted. You can either recover your wallet using your secret key or create a new wallet.',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.grey,
                ),
              ),
              const SizedBox(height: 24),
              
              // Recovery options
              SwitchListTile(
                title: Text(
                  'Create a new wallet',
                  style: AppTheme.bodyLarge.copyWith(
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  'Warning: You will lose access to your previous wallet',
                  style: AppTheme.bodySmall.copyWith(
                    color: Colors.red[300],
                  ),
                ),
                value: _createNewWallet,
                onChanged: (value) {
                  setState(() {
                    _createNewWallet = value;
                  });
                },
                activeColor: AppTheme.primaryGold,
              ),
              const SizedBox(height: 24),
              
              if (!_createNewWallet) ...[
                // Secret key input
                Text(
                  'Enter your wallet secret key',
                  style: AppTheme.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _secretKeyController,
                  decoration: InputDecoration(
                    hintText: 'S... (51 characters)',
                    filled: true,
                    fillColor: AppTheme.darkGrey,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showSecretKey ? Icons.visibility_off : Icons.visibility,
                        color: AppTheme.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _showSecretKey = !_showSecretKey;
                        });
                      },
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  obscureText: !_showSecretKey,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your secret key';
                    }
                    if (value.length != 56) {
                      return 'Secret key should be 56 characters long';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Your secret key is a 56-character string starting with "S". Never share it with anyone.',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.grey,
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              // Error message
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppTheme.bodyMedium.copyWith(
                            color: Colors.red.shade300,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              // Submit button
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: _createNewWallet ? 'Create New Wallet' : 'Recover Wallet',
                  onPressed: _isLoading ? () {} : _recoverWallet,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}