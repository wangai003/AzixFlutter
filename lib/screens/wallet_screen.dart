import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/stellar_provider.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_layout.dart';
import '../widgets/send_dialog.dart';
import '../widgets/enhanced_buy_akofa_dialog.dart';
import '../widgets/wallet_card.dart';
import '../widgets/quick_actions_row.dart';
import '../widgets/transaction_list.dart';
import '../widgets/stellar_wallet_prompt.dart';
import '../widgets/friendly_bot_funding_dialog.dart';
import '../screens/buy_crypto_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Check wallet status, Akofa trustline, and refresh balance when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stellarProvider = Provider.of<StellarProvider>(
        context,
        listen: false,
      );

      // Always check wallet status to get the public key
      stellarProvider.checkWalletStatus().then((hasWallet) {
        if (hasWallet && stellarProvider.publicKey != null) {
          // Trustline is now handled automatically
          stellarProvider.refreshBalance();
          // Load transactions from blockchain after wallet status is confirmed
          stellarProvider.loadTransactionsFromBlockchain().then((_) {});
        } else {}
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stellarProvider = Provider.of<StellarProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    // Determine layout based on screen size
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);

    // If user doesn't have a wallet, show the wallet creation prompt
    if (!stellarProvider.hasWallet) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Wallet', style: AppTheme.headingMedium),
          backgroundColor: AppTheme.black,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(
                Icons.verified_user,
                color: AppTheme.primaryGold,
              ),
              tooltip: 'Create AKOFA Trustline',
              onPressed: () => _createAkofaTrustline(context, stellarProvider),
            ),
            IconButton(
              icon: const Icon(Icons.bug_report, color: AppTheme.primaryGold),
              tooltip: 'Debug Transactions',
              onPressed: () => _debugTransactions(context, stellarProvider),
            ),
            IconButton(
              icon: const Icon(Icons.build, color: AppTheme.primaryGold),
              tooltip: 'Account Maintenance',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const AccountMaintenanceDialog(),
                ).then((result) {
                  if (result != null) {
                    // Refresh wallet status after maintenance
                    stellarProvider.checkWalletStatus();
                  }
                });
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await stellarProvider.checkWalletStatus();
          },
          color: AppTheme.primaryGold,
          backgroundColor: AppTheme.black,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ResponsiveContainer(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveLayout.getValueForScreenType<double>(
                  context: context,
                  mobile: 16.0,
                  tablet: 32.0,
                  desktop: 48.0,
                  largeDesktop: 64.0,
                ),
                vertical: 24.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 32),
                  const StellarWalletPrompt(),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Wallet', style: AppTheme.headingMedium),
        backgroundColor: AppTheme.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.build, color: AppTheme.primaryGold),
            tooltip: 'Account Maintenance',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const AccountMaintenanceDialog(),
              ).then((result) {
                if (result != null) {
                  // Refresh wallet data after maintenance
                  stellarProvider.refreshBalance();
                  // Trustline is now handled automatically
                  stellarProvider.loadTransactionsFromBlockchain();
                }
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await stellarProvider.refreshBalance();
          await stellarProvider.loadTransactionsFromBlockchain();
        },
        color: AppTheme.primaryGold,
        backgroundColor: AppTheme.black,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ResponsiveContainer(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveLayout.getValueForScreenType<double>(
                context: context,
                mobile: 16.0,
                tablet: 32.0,
                desktop: 48.0,
                largeDesktop: 64.0,
              ),
              vertical: 24.0,
            ),
            child: isDesktop
                ? _buildDesktopLayout(context, stellarProvider, authProvider)
                : _buildMobileTabletLayout(context, stellarProvider, isTablet),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    StellarProvider stellarProvider,
    AuthProvider authProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column - Wallet card and quick actions
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WalletCard(
                    balance: stellarProvider.balance,
                    akofaBalance: stellarProvider.akofaBalance,
                    publicKey: stellarProvider.publicKey,
                    hasAkofaTrustline: stellarProvider.hasAkofaTrustline,
                    onShowQR: () =>
                        _showReceiveSheet(context, stellarProvider.publicKey),
                    onCreateTrustline: () =>
                        _createAkofaTrustline(context, stellarProvider),
                  ),
                  const SizedBox(height: 24),
                  QuickActionsRow(
                    onSend: () => _showSendDialog(context),
                    onReceive: () =>
                        _showReceiveSheet(context, stellarProvider.publicKey),
                    onBuy: () => _showBuyAkofaDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 32),
            // Right column - Transactions
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Transactions',
                        style: AppTheme.headingMedium.copyWith(
                          color: AppTheme.primaryGold,
                          fontSize: 24,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.refresh,
                          color: AppTheme.primaryGold,
                        ),
                        onPressed: () =>
                            stellarProvider.loadTransactionsFromBlockchain(),
                        tooltip: 'Refresh transactions',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 500, // Fixed height for desktop
                    decoration: BoxDecoration(
                      color: AppTheme.black,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.grey.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: TransactionList(
                      transactions: stellarProvider.transactions,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileTabletLayout(
    BuildContext context,
    StellarProvider stellarProvider,
    bool isTablet,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isTablet) _buildHeader(context),
        if (isTablet) const SizedBox(height: 24),
        WalletCard(
          balance: stellarProvider.balance,
          akofaBalance: stellarProvider.akofaBalance,
          publicKey: stellarProvider.publicKey,
          hasAkofaTrustline: stellarProvider.hasAkofaTrustline,
          onShowQR: () => _showReceiveSheet(context, stellarProvider.publicKey),
        ),
        const SizedBox(height: 24),
        QuickActionsRow(
          onSend: () => _showSendDialog(context),
          onReceive: () =>
              _showReceiveSheet(context, stellarProvider.publicKey),
          onBuy: () => _showBuyAkofaDialog(context),
          onBuyCrypto: () => _showBuyCryptoScreen(context),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Transactions',
              style: AppTheme.headingMedium.copyWith(
                color: AppTheme.primaryGold,
                fontSize: isTablet ? 22 : null,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
              onPressed: () => stellarProvider.loadTransactionsFromBlockchain(),
              tooltip: 'Refresh transactions',
            ),
          ],
        ),
        const SizedBox(height: 12),
        TransactionList(transactions: stellarProvider.transactions),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wallet',
              style: AppTheme.headingLarge.copyWith(
                color: AppTheme.primaryGold,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your assets and transactions',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
            ),
          ],
        )
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
        )
        .slideY(
          begin: 0.2,
          end: 0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
        );
  }

  void _showReceiveSheet(BuildContext context, String? publicKey) {
    if (publicKey != null) {
      _showReceiveDialog(context, publicKey);
    }
  }

  void _showSendDialog(BuildContext context) async {
    final stellarProvider = Provider.of<StellarProvider>(
      context,
      listen: false,
    );
    await stellarProvider.loadWalletAssets();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) =>
          SendDialog(assetCode: 'XLM', balance: stellarProvider.balance),
    ).then((success) {
      if (success == true) {
        stellarProvider.refreshBalance();
      }
    });
  }

  void _showBuyAkofaDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => EnhancedBuyAkofaDialog(),
    );
  }

  void _showBuyCryptoScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BuyCryptoScreen()),
    );
  }

  void _showReceiveDialog(BuildContext context, String publicKey) async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.black,
          title: Text(
            'Receive Funds',
            style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Share your public key to receive funds',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.grey),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.darkGrey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      publicKey,
                      style: AppTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: publicKey));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Public key copied to clipboard'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Address'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGold,
                        foregroundColor: AppTheme.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _createAkofaTrustline(
    BuildContext context,
    StellarProvider stellarProvider,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
          ),
        ),
      ),
    );

    try {
      final result = await stellarProvider.createAkofaTrustlineManually();

      // Close the loading dialog
      Navigator.of(context).pop();

      if (result['success'] == true) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Akofa trustline created successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Failed to create Akofa trustline',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close the loading dialog
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _debugTransactions(
    BuildContext context,
    StellarProvider stellarProvider,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.black,
        title: Text(
          'Debugging Transactions',
          style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
            ),
            const SizedBox(height: 16),
            Text(
              'Analyzing transaction loading...',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
            ),
          ],
        ),
      ),
    );

    try {
      final debugInfo = await stellarProvider.debugTransactionLoading();

      // Close loading dialog
      Navigator.of(context).pop();

      // Show debug results
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.black,
          title: Text(
            'Transaction Debug Results',
            style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _debugRow('Has Wallet:', debugInfo['hasWallet'].toString()),
                _debugRow('Public Key:', debugInfo['publicKey'] ?? 'None'),
                _debugRow(
                  'Current Transactions:',
                  debugInfo['currentTransactionCount'].toString(),
                ),
                _debugRow(
                  'Is Loading:',
                  debugInfo['isTransactionLoading'].toString(),
                ),
                _debugRow(
                  'Refresh Successful:',
                  debugInfo['refreshSuccessful'].toString(),
                ),
                _debugRow(
                  'After Refresh:',
                  debugInfo['afterRefreshCount']?.toString() ?? 'N/A',
                ),
                if (debugInfo['refreshError'] != null)
                  _debugRow('Refresh Error:', debugInfo['refreshError']),
                if (debugInfo['sampleTransaction'] != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Sample Transaction:',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _debugRow('ID:', debugInfo['sampleTransaction']['id']),
                  _debugRow('Type:', debugInfo['sampleTransaction']['type']),
                  _debugRow(
                    'Amount:',
                    debugInfo['sampleTransaction']['amount'].toString(),
                  ),
                  _debugRow(
                    'Asset:',
                    debugInfo['sampleTransaction']['assetCode'],
                  ),
                  _debugRow(
                    'Status:',
                    debugInfo['sampleTransaction']['status'],
                  ),
                  _debugRow(
                    'Timestamp:',
                    debugInfo['sampleTransaction']['timestamp'],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text(
                'Close',
                style: TextStyle(color: AppTheme.primaryGold),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Debug failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _debugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.white),
            ),
          ),
        ],
      ),
    );
  }
}
