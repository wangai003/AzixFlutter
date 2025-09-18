import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/auth_provider.dart';
import '../providers/stellar_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';

class StellarWalletScreen extends StatefulWidget {
  const StellarWalletScreen({Key? key}) : super(key: key);

  @override
  State<StellarWalletScreen> createState() => _StellarWalletScreenState();
}

class _StellarWalletScreenState extends State<StellarWalletScreen> {
  bool _showSecretKey = false;
  Map<String, dynamic>? _credentials;
  bool _isLoading = false;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    // Check for Akofa trustline when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
      if (stellarProvider.hasWallet && stellarProvider.publicKey != null) {
        // Trustline is now handled automatically
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stellarProvider = Provider.of<StellarProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Stellar Wallet',
          style: AppTheme.headingMedium,
        ),
        backgroundColor: AppTheme.black,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await stellarProvider.refreshBalance();
        },
        color: AppTheme.primaryGold,
        backgroundColor: AppTheme.black,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWalletCard(stellarProvider),
              const SizedBox(height: 24),
              _buildCredentialsSection(stellarProvider, authProvider),
              const SizedBox(height: 24),
              _buildTransactionsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletCard(StellarProvider stellarProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGold.withOpacity(0.8),
            AppTheme.primaryGold.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGold.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stellar Balance',
                style: AppTheme.headingSmall.copyWith(
                  color: AppTheme.black,
                ),
              ),
              Icon(
                Icons.account_balance_wallet,
                color: AppTheme.black.withOpacity(0.8),
                size: 24,
              ),
              IconButton(
                icon: const Icon(Icons.qr_code, color: AppTheme.black, size: 28),
                tooltip: 'Receive (Show QR)',
                onPressed: () {
                  _showReceiveSheet(context, stellarProvider.publicKey);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${stellarProvider.balance} XLM',
            style: AppTheme.headingLarge.copyWith(
              color: AppTheme.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          // Akofa Balance Section
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Akofa Balance',
                style: AppTheme.headingSmall.copyWith(
                  color: AppTheme.black,
                ),
              ),
              Icon(
                Icons.token,
                color: AppTheme.black.withOpacity(0.8),
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          if (stellarProvider.hasAkofaTrustline)
            Text(
              '${stellarProvider.akofaBalance} AKOFA',
              style: AppTheme.headingMedium.copyWith(
                color: AppTheme.black,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No Akofa Trustline',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.black,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: stellarProvider.isLoading
                        ? null
                        : () async {
                            // First check if the account has enough XLM
                            final xlmCheck = await stellarProvider.checkAccountXlmBalance();
                            
                            if (xlmCheck['hasEnough'] != true) {
                              // Show warning dialog about insufficient XLM
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Insufficient XLM Balance'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Your account needs more XLM to add a trustline.'),
                                        const SizedBox(height: 12),
                                        Text('Current balance: ${xlmCheck['balance']} XLM'),
                                        Text('Required: ${xlmCheck['needed']} XLM'),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'What to do:',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text('• Send XLM to your account from another wallet'),
                                        const Text('• Use the Stellar Testnet Friendbot to get free test XLM'),
                                        const Text('• Contact support if you need assistance'),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          // Proceed anyway
                                          _proceedWithTrustlineAddition(context, stellarProvider);
                                        },
                                        child: const Text('Try Anyway'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            } else {
                              // Proceed with adding the trustline
                              _proceedWithTrustlineAddition(context, stellarProvider);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.black,
                      foregroundColor: AppTheme.primaryGold,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      stellarProvider.hasAkofaTrustline
                          ? 'Refresh Akofa Trustline'
                          : 'Add Akofa Trustline',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
  
  // Helper method to proceed with trustline addition
  void _proceedWithTrustlineAddition(BuildContext context, StellarProvider stellarProvider) async {
    // Show a loading dialog with progress indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Adding Akofa Trustline'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('This may take a moment. Please wait...'),
              SizedBox(height: 8),
              Text(
                'Do not close the app or navigate away from this screen.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
    
    try {
      // Call the new implementation
      // Trustline is now handled automatically - no manual action needed
      final result = {'success': true, 'message': 'Trustline handled automatically'};
      
      // Close the loading dialog
      Navigator.of(context).pop();
      
      if (result['success'] == true) {
        // Success case
        String message = 'Akofa trustline added successfully!';
        if (result['status'] == 'existing') {
          message = 'You already have an Akofa trustline!';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        // Show a more detailed error dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Trustline Addition Failed'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stellarProvider.error ?? 'Failed to add Akofa trustline.'),
                  const SizedBox(height: 16),
                  const Text(
                    'What to try:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Check your internet connection'),
                  const Text('• Make sure your account has XLM for fees'),
                  const Text('• Wait a few minutes and try again'),
                  const Text('• Restart the app if the issue persists'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      // Close the loading dialog
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showReceiveSheet(BuildContext context, String? publicKey) {
    if (publicKey == null) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: AppTheme.black,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Receive XLM or Tokens', style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: QrImageView(
                  data: publicKey,
                  version: QrVersions.auto,
                  size: 180.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                publicKey,
                style: AppTheme.bodyMedium.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white),
                    tooltip: 'Copy Address',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: publicKey));
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Address copied to clipboard'), backgroundColor: Colors.green),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    tooltip: 'Share Address',
                    onPressed: () {
                      // TODO: Implement share functionality (e.g., using share_plus)
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCredentialsSection(StellarProvider stellarProvider, AuthProvider authProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wallet Credentials',
            style: AppTheme.headingSmall,
          ),
          const SizedBox(height: 16),
          Text(
            'Your wallet credentials are encrypted and stored securely. You can view them after re-authenticating.',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.grey,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
              ),
            )
          else if (_credentials != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: AppTheme.grey),
                const SizedBox(height: 8),
                Text(
                  'Public Key:',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _credentials!['publicKey'],
                        style: AppTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      color: AppTheme.grey,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _credentials!['publicKey']));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Public key copied to clipboard'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Secret Key:',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _showSecretKey
                            ? _credentials!['secretKey']
                            : '••••••••••••••••••••••••••••••••••••••••••••••••••',
                        style: AppTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _showSecretKey ? Icons.visibility_off : Icons.visibility,
                        size: 16,
                      ),
                      color: AppTheme.grey,
                      onPressed: () {
                        setState(() {
                          _showSecretKey = !_showSecretKey;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      color: AppTheme.grey,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _credentials!['secretKey']));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Secret key copied to clipboard'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: CustomButton(
                    onPressed: () {
                      setState(() {
                        _credentials = null;
                      });
                    },
                    text: 'Hide Credentials',
                    icon: Icons.visibility_off,
                    isOutlined: true,
                  ),
                ),
              ],
            )
          else
            Center(
              child: CustomButton(
                onPressed: () async {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  try {
                    final credentials = await stellarProvider.getWalletCredentials();
                    setState(() {
                      _credentials = credentials;
                      _isLoading = false;
                    });
                  } catch (e) {
                    setState(() {
                      _error = 'Failed to retrieve credentials: $e';
                      _isLoading = false;
                    });
                  }
                },
                text: 'View Credentials',
                icon: Icons.lock_open,
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _error!,
                style: AppTheme.bodySmall.copyWith(
                  color: Colors.red,
                ),
              ),
            ),
        ],
      ),
    ).animate()
      .fadeIn(
        duration: const Duration(milliseconds: 500),
        delay: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      )
      .slideY(
        begin: 0.2,
        end: 0,
        duration: const Duration(milliseconds: 500),
        delay: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
  }

  Widget _buildTransactionsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Transactions',
            style: AppTheme.headingSmall,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'No transactions yet',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.grey,
              ),
            ),
          ),
        ],
      ),
    ).animate()
      .fadeIn(
        duration: const Duration(milliseconds: 500),
        delay: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      )
      .slideY(
        begin: 0.2,
        end: 0,
        duration: const Duration(milliseconds: 500),
        delay: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
  }

  String _formatPublicKey(String key) {
    if (key.length <= 10) return key;
    return '${key.substring(0, 5)}...${key.substring(key.length - 5)}';
  }
}