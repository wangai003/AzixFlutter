import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wallet_recovery_helper.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart' as local_auth;
import '../providers/enhanced_wallet_provider.dart';

class WalletRecoveryScreen extends StatefulWidget {
  const WalletRecoveryScreen({super.key});

  @override
  State<WalletRecoveryScreen> createState() => _WalletRecoveryScreenState();
}

class _WalletRecoveryScreenState extends State<WalletRecoveryScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isProcessing = false;
  String? _statusMessage;
  String? _errorMessage;
  Map<String, dynamic>? _diagnosis;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _performDiagnosis();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _performDiagnosis() async {
    final authProvider = Provider.of<local_auth.AuthProvider>(
      context,
      listen: false,
    );
    final user = authProvider.user;

    if (user == null) {
      setState(() {
        _errorMessage = 'User not authenticated';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Diagnosing wallet...';
    });

    try {
      final diagnosis = await WalletRecoveryHelper.diagnoseWallet(user.uid);

      setState(() {
        _diagnosis = diagnosis;
        _isProcessing = false;
        _statusMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Diagnosis failed: $e';
        _isProcessing = false;
        _statusMessage = null;
      });
    }
  }

  Future<void> _performRecovery() async {
    final authProvider = Provider.of<local_auth.AuthProvider>(
      context,
      listen: false,
    );
    final user = authProvider.user;

    if (user == null) {
      setState(() {
        _errorMessage = 'User not authenticated';
      });
      return;
    }

    // Validate password
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a password';
      });
      return;
    }

    if (password.length < 8) {
      setState(() {
        _errorMessage = 'Password must be at least 8 characters';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: const Text(
          '⚠️ Confirm Wallet Recovery',
          style: TextStyle(color: Colors.orange),
        ),
        content: const Text(
          'This will delete your current wallet and create a new one. '
          'Any funds in your current wallet address will NOT be accessible. '
          'Are you sure you want to continue?',
          style: TextStyle(color: AppTheme.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Yes, Recover Wallet'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Performing wallet recovery...';
      _errorMessage = null;
    });

    try {
      final result = await WalletRecoveryHelper.performFullRecovery(
        userId: user.uid,
        newPassword: password,
      );

      if (result['success'] == true) {
        setState(() {
          _statusMessage = 'Wallet recovered successfully!';
          _isProcessing = false;
        });

        // Refresh wallet provider
        final walletProvider = Provider.of<EnhancedWalletProvider>(
          context,
          listen: false,
        );
        await walletProvider.checkWalletStatus();

        // Show success dialog
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.darkGrey,
              title: const Text(
                '✅ Recovery Successful',
                style: TextStyle(color: Colors.green),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your wallet has been recovered and verified!',
                    style: TextStyle(color: AppTheme.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'New Address:',
                    style: TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result['address'] ?? 'N/A',
                    style: const TextStyle(
                      color: AppTheme.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context); // Close recovery screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Recovery failed: ${result['error']}';
          _isProcessing = false;
          _statusMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Recovery failed: $e';
        _isProcessing = false;
        _statusMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Recovery'),
        backgroundColor: AppTheme.black,
      ),
      backgroundColor: AppTheme.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Wallet Recovery Required',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your wallet has a data inconsistency and needs to be recovered.',
                          style: TextStyle(
                            color: AppTheme.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Diagnosis section
            if (_diagnosis != null) ...[
              Text(
                'Diagnosis:',
                style: AppTheme.headingMedium.copyWith(
                  color: AppTheme.primaryGold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.darkGrey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _diagnosis!['message'] ?? 'Unknown',
                      style: const TextStyle(color: AppTheme.white),
                    ),
                    if (_diagnosis!['explanation'] != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _diagnosis!['explanation'],
                        style: const TextStyle(
                          color: AppTheme.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Recovery form
            Text(
              'Create New Wallet',
              style: AppTheme.headingMedium.copyWith(
                color: AppTheme.primaryGold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Enter a new password for your wallet:',
              style: TextStyle(color: AppTheme.grey),
            ),
            const SizedBox(height: 16),

            // Password field
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: AppTheme.white),
              decoration: InputDecoration(
                labelText: 'New Password',
                labelStyle: const TextStyle(color: AppTheme.grey),
                hintText: 'Enter password (min 8 characters)',
                hintStyle: TextStyle(color: AppTheme.grey.withOpacity(0.5)),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.grey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryGold),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Confirm password field
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              style: const TextStyle(color: AppTheme.white),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                labelStyle: const TextStyle(color: AppTheme.grey),
                hintText: 'Re-enter password',
                hintStyle: TextStyle(color: AppTheme.grey.withOpacity(0.5)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: AppTheme.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.grey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryGold),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Recovery button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _performRecovery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Recover Wallet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Status messages
            if (_statusMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: Row(
                  children: [
                    const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
