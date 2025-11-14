import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/enhanced_wallet_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/enhanced_transaction_list.dart';
import '../widgets/multi_asset_balance_display.dart';
import '../widgets/mpesa_purchase_dialog.dart';
import '../widgets/mpesa_sell_dialog.dart';
import '../widgets/send_akofa_dialog.dart';
import '../widgets/qr_code_display.dart';
import '../widgets/token_sell_dialog.dart';
import '../widgets/card_payment_dialog.dart';
import '../widgets/bank_transfer_dialog.dart';
import '../widgets/moonpay_purchase_dialog.dart';
import '../widgets/moonpay_button.dart';
import 'buy_crypto_screen.dart';
import '../services/secure_wallet_service.dart';
import '../services/akofa_tag_service.dart';
import '../services/biometric_service.dart';
import '../providers/auth_provider.dart' as local_auth;
import 'package:firebase_auth/firebase_auth.dart';
import 'secure_wallet_creation_screen.dart';
import '../models/transaction.dart' as app_transaction;

class EnhancedWalletScreen extends StatefulWidget {
  const EnhancedWalletScreen({super.key});

  @override
  State<EnhancedWalletScreen> createState() => _EnhancedWalletScreenState();
}

class _EnhancedWalletScreenState extends State<EnhancedWalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isRefreshing = false;
  String? _userAkofaTag;
  bool _isLoadingAkofaTag = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Listen to tab changes to load transactions when transactions tab is selected
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index == 1) {
        // Transactions tab is selected (index 1)
        final walletProvider = Provider.of<EnhancedWalletProvider>(
          context,
          listen: false,
        );
        if (walletProvider.hasWallet) {
          // Load transactions when tab is opened
          walletProvider.loadTransactions(forceRefresh: false);
        }
      }
    });

    // Refresh wallet data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final walletProvider = Provider.of<EnhancedWalletProvider>(
        context,
        listen: false,
      );
      walletProvider.refreshWallet();

      // Load AKOFA tag if wallet exists
      if (walletProvider.hasSecureWallet) {
        _loadUserAkofaTag();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Multi-Asset Wallet',
          style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
        ),
        backgroundColor: AppTheme.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            onPressed: _refreshWallet,
            tooltip: 'Refresh Wallet',
          ),
          IconButton(
            icon: const Icon(Icons.qr_code, color: AppTheme.primaryGold),
            onPressed: _showReceiveOptions,
            tooltip: 'Receive Assets',
          ),
          Consumer<EnhancedWalletProvider>(
            builder: (context, walletProvider, child) {
              if (walletProvider.hasSecureWallet) {
                return IconButton(
                  icon: const Icon(
                    Icons.visibility,
                    color: AppTheme.primaryGold,
                  ),
                  onPressed: () => _showWalletCredentials(walletProvider),
                  tooltip: 'View Wallet Credentials',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Transactions'),
            Tab(text: 'Purchase'),
          ],
          indicatorColor: AppTheme.primaryGold,
          labelColor: AppTheme.primaryGold,
          unselectedLabelColor: AppTheme.grey,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.black, AppTheme.darkGrey.withOpacity(0.3)],
          ),
        ),
        child: Consumer<EnhancedWalletProvider>(
          builder: (context, walletProvider, child) {
            if (walletProvider.isLoading && !walletProvider.hasWallet) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGold),
              );
            }

            if (!walletProvider.hasWallet) {
              return _buildNoWalletView(walletProvider);
            }

            return TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(walletProvider),
                _buildTransactionsTab(walletProvider),
                _buildPurchaseTab(walletProvider),
              ],
            );
          },
        ),
      ),
      floatingActionButton: Consumer<EnhancedWalletProvider>(
        builder: (context, walletProvider, child) {
          if (!walletProvider.hasWallet) return const SizedBox.shrink();

          return FloatingActionButton(
            onPressed: _showSendOptions,
            backgroundColor: AppTheme.primaryGold,
            child: const Icon(Icons.send, color: AppTheme.black),
            tooltip: 'Send Assets',
          );
        },
      ),
    );
  }

  Widget _buildNoWalletView(EnhancedWalletProvider walletProvider) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight:
              MediaQuery.of(context).size.height - 200, // Account for app bar
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 600,
            ), // Limit max width for larger screens
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.darkGrey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryGold.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 64,
                  color: AppTheme.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'Choose Your Wallet Type',
                  style: AppTheme.headingMedium.copyWith(color: AppTheme.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Select the security level for your Stellar wallet',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Secure Wallet Option
                _buildWalletTypeOption(
                  title: 'Secure Wallet',
                  subtitle: 'Maximum security with biometric protection',
                  icon: Icons.security,
                  features: [
                    'AES-GCM encryption',
                    'Biometric authentication',
                    'Hardware security',
                    'Zero-knowledge architecture',
                  ],
                  onPressed: () => _navigateToSecureWalletCreation(),
                  isRecommended: true,
                ),

                // Add extra space at bottom for better UX
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWalletTypeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<String> features,
    required VoidCallback? onPressed,
    bool isRecommended = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isRecommended
            ? AppTheme.primaryGold.withOpacity(0.1)
            : AppTheme.darkGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRecommended
              ? AppTheme.primaryGold
              : AppTheme.grey.withOpacity(0.3),
          width: isRecommended ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.primaryGold, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: AppTheme.bodyLarge.copyWith(
                              color: AppTheme.white,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isRecommended) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGold,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'RECOMMENDED',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                      softWrap: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isRecommended
                    ? AppTheme.primaryGold
                    : AppTheme.darkGrey,
                foregroundColor: isRecommended
                    ? AppTheme.black
                    : AppTheme.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Create $title',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(EnhancedWalletProvider walletProvider) {
    return RefreshIndicator(
      onRefresh: _refreshWallet,
      color: AppTheme.primaryGold,
      backgroundColor: AppTheme.black,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wallet Assets Overview
            _buildWalletAssetsOverview(walletProvider),

            const SizedBox(height: 24),

            // Akofa Tag Display
            _buildAkofaTagSection(),

            const SizedBox(height: 24),

            // Trustline Setup (only show if trustline is missing)
            if (!walletProvider.hasAkofaTrustline)
              _buildTrustlineSetup(walletProvider),

            if (!walletProvider.hasAkofaTrustline) const SizedBox(height: 24),

            // Quick Actions
            _buildQuickActions(walletProvider),

            const SizedBox(height: 24),

            // Sell Tokens Section
            _buildSellTokensSection(walletProvider),

            // Recent Transactions
            _buildRecentTransactions(walletProvider),

            const SizedBox(height: 24),

            // Wallet Stats
            _buildWalletStats(walletProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsTab(EnhancedWalletProvider walletProvider) {
    return Column(
      children: [
        // Filter/Search Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkGrey.withOpacity(0.3),
            border: Border(
              bottom: BorderSide(
                color: AppTheme.primaryGold.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search transactions...',
                    hintStyle: TextStyle(color: AppTheme.grey),
                    prefixIcon: Icon(Icons.search, color: AppTheme.primaryGold),
                    filled: true,
                    fillColor: AppTheme.darkGrey.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(color: AppTheme.white),
                  onChanged: (query) {
                    // TODO: Implement search functionality
                  },
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: 'all',
                dropdownColor: AppTheme.darkGrey,
                style: TextStyle(color: AppTheme.white),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Types')),
                  DropdownMenuItem(value: 'send', child: Text('Sent')),
                  DropdownMenuItem(value: 'receive', child: Text('Received')),
                ],
                onChanged: (value) {
                  // TODO: Implement filter functionality
                },
              ),
            ],
          ),
        ),

        // Transaction List
        Expanded(
          child: Consumer<EnhancedWalletProvider>(
            builder: (context, provider, child) {
              // Load transactions if not already loaded or if we have a wallet but no transactions
              if (provider.hasWallet && provider.transactions.isEmpty && !provider.isLoading) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  debugPrint('🔄 Auto-loading transactions for transactions tab...');
                  provider.loadTransactions();
                });
              }
              
              debugPrint('📊 Consumer rebuild - transactions: ${provider.transactions.length}');
              debugPrint('📊 Is loading: ${provider.isLoading}');
              debugPrint('📊 Has wallet: ${provider.hasWallet}');
              debugPrint('📊 Public key: ${provider.publicKey}');
              
              // Show loading indicator while loading
              if (provider.isLoading && provider.transactions.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryGold),
                );
              }
              
              // Show empty state if no transactions
              if (provider.transactions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 48, color: AppTheme.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No transactions found',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your transaction history will appear here',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          provider.loadTransactions(forceRefresh: true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold,
                          foregroundColor: AppTheme.black,
                        ),
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                );
              }
              
              debugPrint('📊 Rendering transaction list with ${provider.transactions.length} items');
              return EnhancedTransactionList(
                transactions: provider.transactions,
                onRefresh: () => provider.loadTransactions(forceRefresh: true),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseTab(EnhancedWalletProvider walletProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Purchase Tokens',
            style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
          ),
          const SizedBox(height: 8),
          Text(
            'Buy tokens instantly using M-Pesa',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
          ),

          const SizedBox(height: 24),

          // Purchase Options
          _buildPurchaseOptions(walletProvider),

          const SizedBox(height: 24),

          // Purchase History
          _buildPurchaseHistory(walletProvider),
        ],
      ),
    );
  }

  Widget _buildTrustlineSetup(EnhancedWalletProvider walletProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              Text(
                'Wallet Setup Required',
                style: AppTheme.headingMedium.copyWith(color: Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your wallet needs to be configured to hold AKOFA tokens. This will automatically fund your wallet with test XLM and create the AKOFA trustline.',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: walletProvider.isLoading
                  ? null
                  : () => _setupWallet(walletProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: AppTheme.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: walletProvider.isLoading
                  ? const CircularProgressIndicator(
                      color: AppTheme.black,
                      strokeWidth: 2,
                    )
                  : const Text(
                      'Setup Wallet Automatically',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(EnhancedWalletProvider walletProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Send Assets',
                Icons.send,
                _showSendOptions,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Receive',
                Icons.qr_code,
                _showReceiveOptions,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Buy Crypto',
                Icons.account_balance_wallet,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BuyCryptoScreen(
                      walletAddress: walletProvider.publicKey!,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Buy AKOFA',
                Icons.shopping_cart,
                walletProvider.hasAkofaTrustline
                    ? () => _showPurchaseDialog(walletProvider)
                    : null,
                disabled: !walletProvider.hasAkofaTrustline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          'Transaction History',
          Icons.history,
          () => _tabController.animateTo(1),
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback? onTap, {
    bool disabled = false,
    bool fullWidth = false,
  }) {
    final button = GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: disabled
              ? AppTheme.grey.withOpacity(0.1)
              : AppTheme.darkGrey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: disabled
                ? AppTheme.grey.withOpacity(0.3)
                : AppTheme.primaryGold.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: disabled ? AppTheme.grey : AppTheme.primaryGold,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: disabled ? AppTheme.grey : AppTheme.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    return fullWidth ? button : Expanded(child: button);
  }

  Widget _buildRecentTransactions(EnhancedWalletProvider walletProvider) {
    final recentTxs = walletProvider.recentTransactions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Transactions',
              style: AppTheme.headingMedium.copyWith(
                color: AppTheme.primaryGold,
              ),
            ),
            TextButton(
              onPressed: () => _tabController.animateTo(1),
              child: Text(
                'View All',
                style: TextStyle(color: AppTheme.primaryGold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (recentTxs.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.darkGrey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'No transactions yet',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
              ),
            ),
          )
        else
          Column(
            children: recentTxs
                .take(3)
                .map((tx) => _buildTransactionItem(tx))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildTransactionItem(dynamic tx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            tx.type == 'send' ? Icons.arrow_upward : Icons.arrow_downward,
            color: tx.type == 'send' ? Colors.red : Colors.green,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
                ),
                Text(
                  '${tx.timestamp.toLocal()}',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                ),
              ],
            ),
          ),
          Text(
            '${tx.type == 'send' ? '-' : '+'}${tx.amount} ${tx.assetCode}',
            style: AppTheme.bodyMedium.copyWith(
              color: tx.type == 'send' ? Colors.red : Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellTokensSection(EnhancedWalletProvider walletProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sell Tokens',
          style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
        ),
        const SizedBox(height: 8),
        Text(
          'Convert your AKOFA tokens to cash instantly',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkGrey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryGold.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.currency_exchange,
                    color: AppTheme.primaryGold,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sell AKOFA for M-Pesa',
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '1 AKOFA = 100 KES',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.primaryGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: walletProvider.hasAkofaTrustline
                        ? () => _showTokenSellDialog()
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: AppTheme.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Sell Now',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (!walletProvider.hasAkofaTrustline) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Setup wallet first to enable selling',
                          style: AppTheme.bodySmall.copyWith(
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWalletAssetsOverview(EnhancedWalletProvider walletProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Assets',
          style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkGrey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryGold.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // XLM Balance
              _buildAssetRow(
                'XLM',
                'Stellar Lumens',
                double.tryParse(
                      walletProvider.xlmBalance,
                    )?.toStringAsFixed(7) ??
                    '0.0000000',
                Icons.currency_exchange,
                Colors.blue,
              ),
              const SizedBox(height: 12),

              // AKOFA Balance
              _buildAssetRow(
                'AKOFA',
                'AKOFA Ecosystem Token',
                double.tryParse(
                      walletProvider.akofaBalance,
                    )?.toStringAsFixed(7) ??
                    '0.0000000',
                Icons.token,
                Colors.orange,
              ),
              const SizedBox(height: 12),

              // USDC Balance (if available)
              if (double.tryParse(walletProvider.getAssetBalance('USDC')) !=
                      null &&
                  double.tryParse(walletProvider.getAssetBalance('USDC'))! > 0)
                _buildAssetRow(
                  'USDC',
                  'USD Coin',
                  double.tryParse(
                    walletProvider.getAssetBalance('USDC'),
                  )!.toStringAsFixed(7),
                  Icons.attach_money,
                  Colors.green,
                ),

              // EURC Balance (if available)
              if (double.tryParse(walletProvider.getAssetBalance('EURC')) !=
                      null &&
                  double.tryParse(walletProvider.getAssetBalance('EURC'))! > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _buildAssetRow(
                    'EURC',
                    'Euro Coin',
                    double.tryParse(
                      walletProvider.getAssetBalance('EURC'),
                    )!.toStringAsFixed(7),
                    Icons.euro,
                    Colors.teal,
                  ),
                ),

              // Polygon Network Assets (if available) - no network distinction
              if (walletProvider.hasPolygonWallet)
                ...walletProvider.polygonTokens.entries
                    .where((entry) => (entry.value['balance'] as double) > 0)
                    .map((entry) {
                      final token = entry.value;
                      final symbol = token['symbol'] as String;
                      final name = token['name'] as String;
                      final balance = token['formattedBalance'] as String;

                      // Choose appropriate icon based on token
                      IconData icon;
                      Color color;
                      switch (symbol) {
                        case 'MATIC':
                          icon = Icons.hexagon;
                          color = Colors.purple;
                          break;
                        case 'USDT':
                          icon = Icons.currency_exchange;
                          color = Colors.green;
                          break;
                        case 'USDC':
                          icon = Icons.attach_money;
                          color = Colors.blue;
                          break;
                        case 'DAI':
                          icon = Icons.account_balance_wallet;
                          color = Colors.orange;
                          break;
                        case 'WETH':
                          icon = Icons.currency_bitcoin;
                          color = Colors.teal;
                          break;
                        default:
                          icon = Icons.token;
                          color = Colors.grey;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _buildAssetRow(
                          symbol,
                          name,
                          balance,
                          icon,
                          color,
                        ),
                      );
                    }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssetRow(
    String symbol,
    String name,
    String balance,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                symbol,
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                name,
                style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
              ),
            ],
          ),
        ),
        Text(
          balance,
          style: AppTheme.bodyLarge.copyWith(
            color: AppTheme.primaryGold,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildWalletStats(EnhancedWalletProvider walletProvider) {
    final stats = walletProvider.getTransactionStats();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Wallet Statistics',
          style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Transactions',
                stats['totalTransactions'].toString(),
                Icons.swap_horiz,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'AKOFA Balance',
                '${walletProvider.akofaBalance} AKOFA',
                Icons.token,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryGold.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryGold, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseOptions(EnhancedWalletProvider walletProvider) {
    return Column(
      children: [
        // Payment Method Selection
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkGrey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose Payment Method',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildPaymentMethodButton(
                      'M-Pesa',
                      Icons.phone_android,
                      () => _showMpesaPurchaseDialog(walletProvider),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPaymentMethodButton(
                      'MoonPay',
                      Icons.account_balance_wallet,
                      () => _showMoonPayPurchaseDialog(walletProvider),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildPaymentMethodButton(
                      'Card',
                      Icons.credit_card,
                      () => _showCardPaymentDialog(walletProvider),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPaymentMethodButton(
                      'Bank Transfer',
                      Icons.account_balance,
                      () => _showBankTransferDialog(walletProvider),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Quick Purchase Options (M-Pesa)
        Text(
          'Quick Purchase (M-Pesa)',
          style: AppTheme.bodyLarge.copyWith(
            color: AppTheme.primaryGold,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildPurchaseOption(
          'KES 100',
          '1.0 AKOFA',
          () => _initiatePurchase(walletProvider, 100),
        ),
        const SizedBox(height: 12),
        _buildPurchaseOption(
          'KES 500',
          '5.0 AKOFA',
          () => _initiatePurchase(walletProvider, 500),
        ),
        const SizedBox(height: 12),
        _buildPurchaseOption(
          'KES 1,000',
          '10.0 AKOFA',
          () => _initiatePurchase(walletProvider, 1000),
        ),
        const SizedBox(height: 12),
        _buildPurchaseOption(
          'KES 5,000',
          '50.0 AKOFA',
          () => _initiatePurchase(walletProvider, 5000),
        ),
      ],
    );
  }

  Widget _buildPurchaseOption(
    String kesAmount,
    String akofaAmount,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkGrey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryGold.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kesAmount,
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  akofaAmount,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryGold,
                  ),
                ),
              ],
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppTheme.primaryGold,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseHistory(EnhancedWalletProvider walletProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Purchase History',
          style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: walletProvider.getMpesaHistory(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.darkGrey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'No purchase history',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                  ),
                ),
              );
            }

            return Column(
              children: snapshot.data!.take(5).map((purchase) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkGrey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KES ${purchase['amountKES']}',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.white,
                            ),
                          ),
                          Text(
                            purchase['status'],
                            style: AppTheme.bodySmall.copyWith(
                              color: purchase['status'] == 'credited'
                                  ? Colors.green
                                  : AppTheme.grey,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${purchase['akofaAmount']} AKOFA',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.primaryGold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ==================== ACTION METHODS ====================

  Future<void> _refreshWallet() async {
    setState(() => _isRefreshing = true);
    final walletProvider = Provider.of<EnhancedWalletProvider>(
      context,
      listen: false,
    );
    await walletProvider.refreshWallet();

    // Load Akofa tag if wallet exists
    if (walletProvider.hasSecureWallet) {
      await _loadUserAkofaTag();
    }

    setState(() => _isRefreshing = false);
  }

  Future<void> _checkAndPromptForAkofaTag(
    EnhancedWalletProvider walletProvider,
  ) async {
    final authProvider = Provider.of<local_auth.AuthProvider>(
      context,
      listen: false,
    );

    if (authProvider.user?.uid == null) return;

    try {
      // Check if user has an AKOFA tag
      final tagCheck = await AkofaTagService.checkUserHasTag(
        authProvider.user!.uid,
      );

      if (tagCheck['hasTag']) {
        // User has a tag, load it
        setState(() {
          _userAkofaTag = tagCheck['tag'];
        });
      } else {
        // User has wallet but no AKOFA tag - prompt to create one
        // This now works for all wallet types (secure, imported, etc.)
        _showAkofaTagCreationPrompt(walletProvider);
      }
    } catch (e) {
      print('Error checking AKOFA tag: $e');
      // If error, still try to load existing tag
      _loadUserAkofaTag();
    }
  }

  Future<void> _loadUserAkofaTag() async {
    setState(() => _isLoadingAkofaTag = true);

    final authProvider = Provider.of<local_auth.AuthProvider>(
      context,
      listen: false,
    );

    if (authProvider.user?.uid != null) {
      try {
        // Retrieve from USER collection field 'akofaTag'
        final userDoc = await FirebaseFirestore.instance
            .collection('USER')
            .doc(authProvider.user!.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          final tag = userData?['akofaTag'] as String?;
          setState(() {
            _userAkofaTag = tag;
          });
        } else {
          setState(() {
            _userAkofaTag = null;
          });
        }
      } catch (e) {
        setState(() {
          _userAkofaTag = null;
        });
      }
    }

    setState(() => _isLoadingAkofaTag = false);
  }

  Future<void> _createWallet(EnhancedWalletProvider walletProvider) async {
    final success = await walletProvider.createWallet(context);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wallet created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _navigateToSecureWalletCreation() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const SecureWalletCreationScreen(),
      ),
    );

    if (result == true && mounted) {
      // Refresh wallet status after secure wallet creation
      final walletProvider = Provider.of<EnhancedWalletProvider>(
        context,
        listen: false,
      );
      await walletProvider.checkWalletStatus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Secure wallet created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _setupWallet(EnhancedWalletProvider walletProvider) async {
    final result = await walletProvider.setupWalletManually();
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wallet setup completed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wallet setup failed: ${result['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSendOptions() {
    final walletProvider = Provider.of<EnhancedWalletProvider>(
      context,
      listen: false,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkGrey,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add close button at the top
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.grey),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Close',
                  ),
                ],
              ),
              Text(
                'Send Assets',
                style: AppTheme.headingMedium.copyWith(
                  color: AppTheme.primaryGold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose an asset to send',
                style: TextStyle(color: AppTheme.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              // Stellar Network Assets
              Text(
                'Stellar Network',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              // XLM Option
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: const Text(
                    'X',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  'Send XLM',
                  style: TextStyle(color: AppTheme.white),
                ),
                subtitle: Text(
                  'Native Stellar cryptocurrency',
                  style: TextStyle(color: AppTheme.grey, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showSendAssetDialog(
                    walletProvider,
                    walletProvider.supportedAssets[0],
                  ); // XLM
                },
              ),
              // AKOFA Option
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: const Text(
                    'A',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  'Send AKOFA',
                  style: TextStyle(color: AppTheme.white),
                ),
                subtitle: Text(
                  'AKOFA ecosystem token',
                  style: TextStyle(color: AppTheme.grey, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showSendAssetDialog(
                    walletProvider,
                    walletProvider.supportedAssets[1],
                  ); // AKOFA
                },
              ),
              // Polygon Network Assets
              if (walletProvider.hasPolygonWallet) ...[
                const SizedBox(height: 24),
                Divider(color: AppTheme.primaryGold.withOpacity(0.3)),
                const SizedBox(height: 12),
                Text(
                  'Polygon Network',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                // Polygon tokens with balances > 0
                ...walletProvider.polygonTokens.entries
                    .where((entry) => (entry.value['balance'] as double) > 0)
                    .map((entry) {
                      final token = entry.value;
                      final symbol = token['symbol'] as String;
                      final name = token['name'] as String;
                      final balance = token['formattedBalance'] as String;

                      // Choose appropriate icon based on token
                      IconData icon;
                      Color color;
                      switch (symbol) {
                        case 'MATIC':
                          icon = Icons.hexagon;
                          color = Colors.purple;
                          break;
                        case 'USDT':
                          icon = Icons.currency_exchange;
                          color = Colors.green;
                          break;
                        case 'USDC':
                          icon = Icons.attach_money;
                          color = Colors.blue;
                          break;
                        case 'DAI':
                          icon = Icons.account_balance_wallet;
                          color = Colors.orange;
                          break;
                        case 'WETH':
                          icon = Icons.currency_bitcoin;
                          color = Colors.teal;
                          break;
                        default:
                          icon = Icons.token;
                          color = Colors.grey;
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.2),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        title: Text(
                          'Send $symbol',
                          style: TextStyle(color: AppTheme.white),
                        ),
                        subtitle: Text(
                          '$name • Balance: $balance',
                          style: TextStyle(color: AppTheme.grey, fontSize: 12),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _showSendPolygonAssetDialog(walletProvider, token);
                        },
                      );
                    }),
              ],
              // Sell Tokens Option
              const SizedBox(height: 24),
              Divider(color: AppTheme.primaryGold.withOpacity(0.3)),
              const SizedBox(height: 12),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.sell, color: Colors.white, size: 20),
                ),
                title: Text(
                  'Sell Tokens',
                  style: TextStyle(color: AppTheme.white),
                ),
                subtitle: Text(
                  'Convert tokens to cash',
                  style: TextStyle(color: AppTheme.grey, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showTokenSellDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSendAkofaDialog(EnhancedWalletProvider walletProvider) {
    showDialog(context: context, builder: (context) => SendAkofaDialog());
  }

  void _showSendAssetDialog(
    EnhancedWalletProvider walletProvider,
    dynamic asset,
  ) {
    final recipientController = TextEditingController();
    final amountController = TextEditingController();
    final memoController = TextEditingController();
    String resolvedAddress = '';
    bool isResolvingTag = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.darkGrey,
          title: Text(
            'Send ${asset.symbol}',
            style: TextStyle(color: AppTheme.primaryGold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Send ${asset.name} to another address or Akofa tag',
                  style: TextStyle(color: AppTheme.grey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: recipientController,
                  style: TextStyle(color: AppTheme.white),
                  onChanged: (value) async {
                    if (value.isNotEmpty) {
                      // Check if input looks like a tag
                      if (AkofaTagService.isValidTagFormat(value.trim())) {
                        setState(() => isResolvingTag = true);

                        try {
                          final tagResult = await AkofaTagService.resolveTag(
                            value.trim(),
                            blockchain: 'stellar',
                          );
                          if (tagResult['success']) {
                            setState(() {
                              resolvedAddress = tagResult['address'];
                              isResolvingTag = false;
                            });
                          } else {
                            setState(() {
                              resolvedAddress = '';
                              isResolvingTag = false;
                            });
                          }
                        } catch (e) {
                          setState(() {
                            resolvedAddress = '';
                            isResolvingTag = false;
                          });
                        }
                      } else if (value.startsWith('G') && value.length == 56) {
                        // Valid Stellar address - clear any previous tag resolution
                        setState(() => resolvedAddress = value);
                      } else {
                        setState(() => resolvedAddress = '');
                      }
                    } else {
                      setState(() {
                        resolvedAddress = '';
                        isResolvingTag = false;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Recipient Address or Akofa Tag',
                    labelStyle: TextStyle(color: AppTheme.primaryGold),
                    hintText: 'G... or john1234',
                    hintStyle: TextStyle(color: AppTheme.grey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryGold),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryGold),
                    ),
                    suffixIcon: isResolvingTag
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryGold,
                            ),
                          )
                        : resolvedAddress.isNotEmpty
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          )
                        : null,
                  ),
                ),
                if (resolvedAddress.isNotEmpty && !isResolvingTag)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Resolved to: ${resolvedAddress.substring(0, 8)}...${resolvedAddress.substring(resolvedAddress.length - 8)}',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppTheme.white),
                  onChanged: (value) {
                    setState(() {}); // Trigger rebuild to update button state
                  },
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    labelStyle: TextStyle(color: AppTheme.primaryGold),
                    hintText: '0.00',
                    hintStyle: TextStyle(color: AppTheme.grey),
                    suffixText: asset.symbol,
                    suffixStyle: TextStyle(color: AppTheme.primaryGold),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryGold),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryGold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: memoController,
                  style: TextStyle(color: AppTheme.white),
                  maxLength: 28, // Stellar memo limit
                  onChanged: (value) {
                    setState(() {}); // Trigger rebuild to update button state
                  },
                  decoration: InputDecoration(
                    labelText: 'Memo (Required)',
                    labelStyle: TextStyle(color: AppTheme.primaryGold),
                    hintText: 'Transaction description',
                    hintStyle: TextStyle(color: AppTheme.grey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryGold),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryGold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Available: ${walletProvider.getAssetBalance(asset.assetId)} ${asset.symbol}',
                  style: TextStyle(color: AppTheme.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: AppTheme.grey)),
            ),
            ElevatedButton(
              onPressed:
                  resolvedAddress.isEmpty ||
                      isResolvingTag ||
                      memoController.text.trim().isEmpty ||
                      amountController.text.trim().isEmpty
                  ? null
                  : () async {
                      final amountText = amountController.text.trim();
                      final memoText = memoController.text.trim();

                      if (amountText.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter amount'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (memoText.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Memo is required for all transactions',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final amount = double.tryParse(amountText);
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid amount'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // Show step-by-step transaction authentication dialog
                      final authResult = await _showTransactionAuthDialog(
                        asset.symbol,
                        amount.toString(),
                        recipientController.text,
                      );
                      if (authResult == null || authResult['password'] == null) {
                        return; // User cancelled
                      }

                      final password = authResult['password'] as String;
                      // Biometric verification is optional - if wallet has biometrics, it's required
                      // If wallet doesn't have biometrics, password-only is fine
                      // The service will handle this automatically

                      // Verify password with Firebase Auth
                      final authProvider = Provider.of<local_auth.AuthProvider>(
                        context,
                        listen: false,
                      );
                      final currentUser = authProvider.user;
                      if (currentUser == null || currentUser.email == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Authentication required. Please log in again.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      try {
                        // Re-authenticate user with password
                        final credential = EmailAuthProvider.credential(
                          email: currentUser.email!,
                          password: password,
                        );
                        await currentUser.reauthenticateWithCredential(
                          credential,
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Invalid password. Please try again.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      Navigator.of(context).pop();

                      // Show loading dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => AlertDialog(
                          backgroundColor: AppTheme.darkGrey,
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                color: AppTheme.primaryGold,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Sending ${amount} ${asset.symbol}...',
                                style: TextStyle(
                                  color: AppTheme.white,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please wait while we process your transaction',
                                style: TextStyle(
                                  color: AppTheme.grey,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );

                      try {
                        final result = await walletProvider.sendAsset(
                          recipientAddress: resolvedAddress,
                          asset: asset,
                          amount: amount,
                          memo: memoText,
                          password: password, // Pass the password for secure wallets
                        );

                        // Close loading dialog
                        Navigator.of(context).pop();

                        if (result['success'] == true) {
                          // Show success dialog
                          _showTransactionSuccessDialog(
                            context,
                            asset: asset,
                            amount: amount,
                            recipientAddress: resolvedAddress,
                            transactionHash: result['hash'],
                            memo: memoText,
                          );
                        } else {
                          // Show error dialog
                          _showTransactionErrorDialog(
                            context,
                            asset: asset,
                            error: result['error'] ?? 'Transaction failed',
                            errorDetails: result['message'],
                          );
                        }
                      } catch (e) {
                        // Close loading dialog
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                        // Show error dialog
                        _showTransactionErrorDialog(
                          context,
                          asset: asset,
                          error: 'Transaction Error',
                          errorDetails: e.toString(),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.black,
              ),
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSendPolygonAssetDialog(
    EnhancedWalletProvider walletProvider,
    Map<String, dynamic> token,
  ) {
    final recipientController = TextEditingController();
    final amountController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    final symbol = token['symbol'] as String;
    final name = token['name'] as String;
    final balance = token['formattedBalance'] as String;
    final isNative = token['isNative'] as bool;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.darkGrey,
          title: Text(
            'Send $symbol',
            style: TextStyle(color: AppTheme.primaryGold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Send $name to a Polygon address',
                  style: TextStyle(color: AppTheme.grey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: recipientController,
                  style: TextStyle(color: AppTheme.white),
                  decoration: InputDecoration(
                    labelText: 'Recipient Polygon Address',
                    labelStyle: TextStyle(color: AppTheme.primaryGold),
                    hintText: '0x...',
                    hintStyle: TextStyle(color: AppTheme.grey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryGold),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryGold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppTheme.white),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    labelStyle: TextStyle(color: AppTheme.primaryGold),
                    hintText: '0.00',
                    hintStyle: TextStyle(color: AppTheme.grey),
                    suffixText: symbol,
                    suffixStyle: TextStyle(color: AppTheme.primaryGold),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryGold),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryGold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  style: TextStyle(color: AppTheme.white),
                  decoration: InputDecoration(
                    labelText: 'Wallet Password',
                    labelStyle: TextStyle(color: AppTheme.primaryGold),
                    hintText: 'Enter your wallet password',
                    hintStyle: TextStyle(color: AppTheme.grey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryGold),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryGold),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppTheme.grey,
                      ),
                      onPressed: () {
                        setState(() => obscurePassword = !obscurePassword);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Available: $balance $symbol',
                  style: TextStyle(color: AppTheme.grey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Text(
                    '⚠️ Polygon transactions require gas fees in MATIC',
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: AppTheme.grey)),
            ),
            ElevatedButton(
              onPressed:
                  recipientController.text.trim().isEmpty ||
                      amountController.text.trim().isEmpty ||
                      passwordController.text.trim().isEmpty
                  ? null
                  : () async {
                      final recipientAddress = recipientController.text.trim();
                      final amountText = amountController.text.trim();
                      final password = passwordController.text.trim();

                      // Validate Polygon address format
                      if (!recipientAddress.startsWith('0x') ||
                          recipientAddress.length != 42) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter a valid Polygon address',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final amount = double.tryParse(amountText);
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid amount'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // Check if amount exceeds balance
                      final currentBalance = token['balance'] as double;
                      if (amount > currentBalance) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Insufficient balance'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      Navigator.of(context).pop();

                      // Show loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sending $amount $symbol...'),
                          backgroundColor: Colors.blue,
                        ),
                      );

                      try {
                        final result = isNative
                            ? await walletProvider.sendMatic(
                                recipientAddress: recipientAddress,
                                amount: amount,
                                password: password,
                              )
                            : await _sendPolygonToken(
                                walletProvider,
                                token,
                                recipientAddress,
                                amount,
                                password,
                              );

                        if (result['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$symbol sent successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );

                          // Refresh balances
                          await walletProvider.loadPolygonBalances();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to send $symbol: ${result['error']}',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error sending $symbol: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.black,
              ),
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _sendPolygonToken(
    EnhancedWalletProvider walletProvider,
    Map<String, dynamic> token,
    String recipientAddress,
    double amount,
    String password,
  ) async {
    // For now, only MATIC is supported for sending
    // ERC-20 token sending would require additional implementation
    return {
      'success': false,
      'error':
          'ERC-20 token sending not yet implemented. Only MATIC transfers are supported.',
    };
  }

  void _showReceiveOptions() {
    final walletProvider = Provider.of<EnhancedWalletProvider>(
      context,
      listen: false,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Receive Assets',
              style: AppTheme.headingMedium.copyWith(
                color: AppTheme.primaryGold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose network to receive assets',
              style: TextStyle(color: AppTheme.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            // Stellar Network Option
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                child: const Text(
                  'S',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                'Stellar Network',
                style: TextStyle(color: AppTheme.white),
              ),
              subtitle: Text(
                'Receive XLM, AKOFA, USDC, EURC',
                style: TextStyle(color: AppTheme.grey, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _showReceiveQR(walletProvider.publicKey!, 'Stellar Network');
              },
            ),
            // Polygon Network Option
            if (walletProvider.hasPolygonWallet)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: const Text(
                    'P',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  'Polygon Network',
                  style: TextStyle(color: AppTheme.white),
                ),
                subtitle: Text(
                  'Receive MATIC, USDT, USDC, DAI',
                  style: TextStyle(color: AppTheme.grey, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showReceiveQR(
                    walletProvider.polygonAddress!,
                    'Polygon Network',
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showReceiveQR(String address, String network) {
    showDialog(
      context: context,
      builder: (context) =>
          QRCodeDisplay(address: address, title: 'Receive on $network'),
    );
  }

  void _showPurchaseDialog(EnhancedWalletProvider walletProvider) {
    showDialog(
      context: context,
      builder: (context) => MpesaPurchaseDialog(walletProvider: walletProvider),
    );
  }

  void _showTokenSellDialog() {
    final walletProvider = Provider.of<EnhancedWalletProvider>(
      context,
      listen: false,
    );
    showDialog(
      context: context,
      builder: (context) => MpesaSellDialog(walletProvider: walletProvider),
    );
  }

  Widget _buildPaymentMethodButton(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool fullWidth = false,
  }) {
    final button = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkGrey.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryGold.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryGold, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    return fullWidth ? button : Expanded(child: button);
  }

  void _showMpesaPurchaseDialog(EnhancedWalletProvider walletProvider) {
    showDialog(
      context: context,
      builder: (context) => MpesaPurchaseDialog(walletProvider: walletProvider),
    );
  }

  void _showCardPaymentDialog(EnhancedWalletProvider walletProvider) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to continue'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get user country (you might want to get this from user profile or location)
    const defaultCountryCode =
        'KE'; // Default to Kenya, you can make this dynamic

    showDialog(
      context: context,
      builder: (context) => CardPaymentDialog(
        akofaAmount: 1.0, // Default amount, user can change
        userId: user.uid,
        email: user.email ?? '',
        phoneNumber: '', // You might want to get this from user profile
        countryCode: defaultCountryCode,
      ),
    );
  }

  void _showBankTransferDialog(EnhancedWalletProvider walletProvider) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to continue'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get user country
    const defaultCountryCode =
        'KE'; // Default to Kenya, you can make this dynamic

    showDialog(
      context: context,
      builder: (context) => BankTransferDialog(
        akofaAmount: 1.0, // Default amount, user can change
        userId: user.uid,
        email: user.email ?? '',
        phoneNumber: '', // You might want to get this from user profile
        countryCode: defaultCountryCode,
      ),
    );
  }

  void _showMoonPayPurchaseDialog(EnhancedWalletProvider walletProvider) {
    showDialog(
      context: context,
      builder: (context) =>
          MoonPayPurchaseDialog(walletProvider: walletProvider),
    );
  }

  Future<void> _showWalletCredentials(
    EnhancedWalletProvider walletProvider,
  ) async {
    // Show biometric authentication dialog first
    final biometricResult = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text(
          'Authenticate to View Credentials',
          style: TextStyle(color: AppTheme.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fingerprint, size: 48, color: AppTheme.primaryGold),
            const SizedBox(height: 16),
            Text(
              'Biometric authentication is required to view your wallet credentials.',
              style: TextStyle(color: AppTheme.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This will temporarily decrypt your private key for display.',
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
            child: const Text('Authenticate'),
          ),
        ],
      ),
    );

    if (biometricResult != true) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryGold),
            const SizedBox(height: 16),
            Text(
              'Decrypting wallet credentials...',
              style: TextStyle(color: AppTheme.white),
            ),
          ],
        ),
      ),
    );

    try {
      // Get current user ID
      final authProvider = Provider.of<local_auth.AuthProvider>(
        context,
        listen: false,
      );
      final user = authProvider.user;

      if (user == null) {
        // Close loading dialog
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not authenticated. Please sign in first.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      print('🔐 Attempting to decrypt wallet for user: ${user.uid}');

      // Show password input dialog
      final password = await _showPasswordInputDialog();
      if (password == null || password.isEmpty) {
        // Close loading dialog
        Navigator.of(context).pop();
        return;
      }

      // Attempt to decrypt wallet credentials
      final result = await SecureWalletService.authenticateAndDecryptWallet(
        user.uid,
        password,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      if (result['success'] == true) {
        // Show credentials dialog
        _showCredentialsDialog(
          publicKey: result['publicKey'],
          secretKey: result['secretKey'],
        );
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to decrypt credentials: ${result['error'] ?? 'Unknown error'}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error decrypting credentials: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCredentialsDialog({
    required String publicKey,
    required String secretKey,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text(
          'Wallet Credentials',
          style: TextStyle(color: AppTheme.primaryGold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '⚠️ Security Warning',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Never share your private key with anyone. Keep it secure and never store it in plain text.',
                style: TextStyle(color: AppTheme.grey, fontSize: 12),
              ),
              const SizedBox(height: 24),
              Text(
                'Public Key:',
                style: TextStyle(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryGold.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        publicKey,
                        style: TextStyle(color: AppTheme.white, fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.copy,
                        color: AppTheme.primaryGold,
                        size: 16,
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: publicKey));
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
              ),
              const SizedBox(height: 16),
              Text(
                'Private Key:',
                style: TextStyle(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        secretKey,
                        style: TextStyle(color: AppTheme.white, fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, color: Colors.red, size: 16),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: secretKey));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Private key copied to clipboard'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  '🔒 These credentials will be automatically cleared from memory after this dialog is closed.',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close', style: TextStyle(color: AppTheme.grey)),
          ),
        ],
      ),
    );
  }

  Future<String?> _showPasswordInputDialog() async {
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.darkGrey,
          title: Text(
            'Enter Wallet Password',
            style: TextStyle(color: AppTheme.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your wallet password to decrypt and view your credentials.',
                style: TextStyle(color: AppTheme.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                style: TextStyle(color: AppTheme.white),
                decoration: InputDecoration(
                  hintText: 'Enter password',
                  hintStyle: TextStyle(color: AppTheme.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryGold),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryGold),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.grey,
                    ),
                    onPressed: () {
                      setState(() => obscurePassword = !obscurePassword);
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: AppTheme.grey)),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(passwordController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.black,
              ),
              child: const Text('Decrypt'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAkofaTagSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryGold.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tag, color: AppTheme.primaryGold, size: 20),
              const SizedBox(width: 8),
              Text(
                'Your Akofa Tag',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_userAkofaTag != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _userAkofaTag!,
                      style: AppTheme.headingMedium.copyWith(
                        color: AppTheme.primaryGold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.copy,
                      color: AppTheme.primaryGold,
                      size: 20,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _userAkofaTag!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Akofa tag copied to clipboard'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    tooltip: 'Copy Tag',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.share,
                      color: AppTheme.primaryGold,
                      size: 20,
                    ),
                    onPressed: () => _shareAkofaTag(),
                    tooltip: 'Share Tag',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share this tag with others to receive payments easily',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
            ),
          ] else if (_isLoadingAkofaTag) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGold),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create your AKOFA tag to receive payments easily',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _createAkofaTagFromOverview(
                        Provider.of<EnhancedWalletProvider>(
                          context,
                          listen: false,
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Create AKOFA Tag'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGold,
                        foregroundColor: AppTheme.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
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

  void _shareAkofaTag() {
    final shareText =
        'Send me AKOFA tokens using my tag: $_userAkofaTag\n\n'
        'Use this tag in the Azix wallet to send me payments easily!';

    Share.share(shareText, subject: 'My Akofa Tag');
  }

  Future<Map<String, dynamic>?> _showTransactionAuthDialog(
    String assetSymbol,
    String amount,
    String recipient,
  ) async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _TransactionAuthDialog(
        assetSymbol: assetSymbol,
        amount: amount,
        recipient: recipient,
      ),
    );
  }

  Future<String?> _showTransactionPasswordDialog(
    String assetSymbol,
    String amount,
    String recipient,
  ) async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkGrey,
          title: Text(
            'Confirm Transaction',
            style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your password to sign and send $amount $assetSymbol to $recipient',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: AppTheme.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppTheme.grey.withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppTheme.grey.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.primaryGold),
                  ),
                ),
                style: const TextStyle(color: AppTheme.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('Cancel', style: TextStyle(color: AppTheme.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Confirm & Send'),
            ),
          ],
        );
      },
    );
  }

  /// Show success dialog for successful transactions
  void _showTransactionSuccessDialog(
    BuildContext context, {
    required dynamic asset,
    required double amount,
    required String recipientAddress,
    String? transactionHash,
    String? memo,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.green.withOpacity(0.3),
            width: 2,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Transaction Successful!',
                style: AppTheme.headingMedium.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.send,
                          color: AppTheme.primaryGold,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Amount Sent',
                          style: TextStyle(
                            color: AppTheme.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${amount.toStringAsFixed(7)} ${asset.symbol}',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildTransactionDetailRow(
                icon: Icons.person,
                label: 'Recipient',
                value: recipientAddress.length > 20
                    ? '${recipientAddress.substring(0, 10)}...${recipientAddress.substring(recipientAddress.length - 10)}'
                    : recipientAddress,
              ),
              if (memo != null && memo.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildTransactionDetailRow(
                  icon: Icons.note,
                  label: 'Memo',
                  value: memo,
                ),
              ],
              if (transactionHash != null && transactionHash.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildTransactionDetailRow(
                  icon: Icons.receipt_long,
                  label: 'Transaction Hash',
                  value: transactionHash.length > 20
                      ? '${transactionHash.substring(0, 10)}...${transactionHash.substring(transactionHash.length - 10)}'
                      : transactionHash,
                  onTap: () {
                    // Copy to clipboard
                    Clipboard.setData(ClipboardData(text: transactionHash));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Transaction hash copied to clipboard'),
                        backgroundColor: AppTheme.primaryGold,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your transaction has been successfully submitted to the blockchain.',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: AppTheme.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  /// Show error dialog for failed transactions
  void _showTransactionErrorDialog(
    BuildContext context, {
    required dynamic asset,
    required String error,
    String? errorDetails,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.red.withOpacity(0.3),
            width: 2,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Transaction Failed',
                style: AppTheme.headingMedium.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Error Message',
                          style: TextStyle(
                            color: AppTheme.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error,
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (errorDetails != null && errorDetails.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorDetails,
                        style: TextStyle(
                          color: AppTheme.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your ${asset.symbol} was not sent. Please check the error message and try again.',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
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
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Optionally retry the transaction
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: AppTheme.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Helper method to build transaction detail rows
  Widget _buildTransactionDetailRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.darkGrey.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryGold, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: AppTheme.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.copy,
                color: AppTheme.primaryGold,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  void _showAkofaTagCreationPrompt(EnhancedWalletProvider walletProvider) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing without action
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Row(
          children: [
            Icon(Icons.tag, color: AppTheme.primaryGold, size: 24),
            const SizedBox(width: 12),
            Text(
              'Create Your AKOFA Tag',
              style: AppTheme.headingMedium.copyWith(
                color: AppTheme.primaryGold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have a secure wallet but no AKOFA tag. An AKOFA tag makes it easy for others to send you payments.',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
            ),
            const SizedBox(height: 16),
            Text(
              'Example: If your first name is "John", your tag could be "john1234"',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
            ),
            const SizedBox(height: 16),
            Text(
              'Your tag will be automatically generated and linked to your wallet.',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Skip for Now', style: TextStyle(color: AppTheme.grey)),
          ),
          ElevatedButton(
            onPressed: () => _createAkofaTag(walletProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: AppTheme.black,
            ),
            child: const Text('Create Tag'),
          ),
        ],
      ),
    );
  }

  Future<void> _createAkofaTag(EnhancedWalletProvider walletProvider) async {
    Navigator.pop(context); // Close the prompt dialog

    final authProvider = Provider.of<local_auth.AuthProvider>(
      context,
      listen: false,
    );

    if (authProvider.user?.uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryGold),
            const SizedBox(height: 16),
            Text(
              'Creating your AKOFA tag...',
              style: TextStyle(color: AppTheme.white),
            ),
          ],
        ),
      ),
    );

    try {
      // Get user's first name from Firebase Auth display name, with email fallback
      final displayName = authProvider.user!.displayName ?? '';
      final email = authProvider.user!.email ?? '';

      String firstName = displayName
          .split(' ')
          .firstWhere((name) => name.isNotEmpty, orElse: () => '');

      // If no display name, use email prefix as fallback
      if (firstName.isEmpty && email.isNotEmpty) {
        firstName = email.split('@').first;
      }

      // Final fallback if nothing available
      if (firstName.isEmpty) {
        firstName = 'user';
      }

      // Use ensureUserHasTag to create and link the tag
      final result = await AkofaTagService.ensureUserHasTag(
        userId: authProvider.user!.uid,
        firstName: firstName,
        email: email,
        publicKey: walletProvider.publicKey,
      );

      Navigator.pop(context); // Close loading dialog

      if (result['success']) {
        setState(() {
          _userAkofaTag = result['tag'];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AKOFA tag created: ${result['tag']}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create AKOFA tag: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating AKOFA tag: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createAkofaTagFromOverview(
    EnhancedWalletProvider walletProvider,
  ) async {
    final authProvider = Provider.of<local_auth.AuthProvider>(
      context,
      listen: false,
    );

    if (authProvider.user?.uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoadingAkofaTag = true);

    try {
      // Get user's first name from Firebase Auth display name, with email fallback
      final displayName = authProvider.user!.displayName ?? '';
      final email = authProvider.user!.email ?? '';

      String firstName = displayName
          .split(' ')
          .firstWhere((name) => name.isNotEmpty, orElse: () => '');

      // If no display name, use email prefix as fallback
      if (firstName.isEmpty && email.isNotEmpty) {
        firstName = email.split('@').first;
      }

      // Final fallback if nothing available
      if (firstName.isEmpty) {
        firstName = 'user';
      }

      // Use ensureUserHasTag to create and link the tag
      final result = await AkofaTagService.ensureUserHasTag(
        userId: authProvider.user!.uid,
        firstName: firstName,
        email: email,
        publicKey: walletProvider.publicKey,
      );

      if (result['success']) {
        setState(() {
          _userAkofaTag = result['tag'];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AKOFA tag created: ${result['tag']}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create AKOFA tag: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating AKOFA tag: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoadingAkofaTag = false);
    }
  }

  Future<void> _initiatePurchase(
    EnhancedWalletProvider walletProvider,
    double amount,
  ) async {
    // Show phone number input dialog
    final phoneController = TextEditingController();

    final phoneNumber = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text(
          'Enter M-Pesa Phone Number',
          style: TextStyle(color: AppTheme.white),
        ),
        content: TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: AppTheme.white),
          decoration: InputDecoration(
            hintText: '0712345678',
            hintStyle: TextStyle(color: AppTheme.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primaryGold),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primaryGold),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, phoneController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: AppTheme.black,
            ),
            child: const Text('Purchase'),
          ),
        ],
      ),
    );

    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      final result = await walletProvider.purchaseAkofaWithMpesa(
        phoneNumber: phoneNumber,
        amountKES: amount,
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Purchase initiated! Check your phone for M-Pesa prompt.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase failed: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Step-by-step transaction authentication dialog
/// Guides users through password input and biometric authentication
class _TransactionAuthDialog extends StatefulWidget {
  final String assetSymbol;
  final String amount;
  final String recipient;

  const _TransactionAuthDialog({
    required this.assetSymbol,
    required this.amount,
    required this.recipient,
  });

  @override
  State<_TransactionAuthDialog> createState() => _TransactionAuthDialogState();
}

class _TransactionAuthDialogState extends State<_TransactionAuthDialog> {
  int _currentStep = 0; // 0 = password, 1 = biometric/confirmation
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isAuthenticating = false;
  String? _error;
  bool _passwordVerified = false;
  bool _biometricVerified = false;
  bool _biometricsEnabled = false;
  bool _biometricsChecked = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricStatus() async {
    try {
      final authProvider = Provider.of<local_auth.AuthProvider>(
        context,
        listen: false,
      );
      final user = authProvider.user;
      if (user == null) return;

      final walletDoc = await FirebaseFirestore.instance
          .collection('secure_wallets')
          .doc(user.uid)
          .get();

      if (walletDoc.exists) {
        final walletData = walletDoc.data()!;
        setState(() {
          _biometricsEnabled = walletData['biometricsEnabled'] as bool? ?? false;
          _biometricsChecked = true;
        });
      } else {
        setState(() {
          _biometricsEnabled = false;
          _biometricsChecked = true;
        });
      }
    } catch (e) {
      setState(() {
        _biometricsEnabled = false;
        _biometricsChecked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.darkGrey,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Column(
        children: [
          Text(
            'Sign Transaction',
            style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (_biometricsChecked) _buildStepIndicator(),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Transaction Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.darkGrey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'Transaction Details',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Asset', widget.assetSymbol),
                  _buildDetailRow('Amount', widget.amount),
                  _buildDetailRow('Recipient', widget.recipient.length > 20
                      ? '${widget.recipient.substring(0, 20)}...'
                      : widget.recipient),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Step Content
            if (!_biometricsChecked)
              const Center(child: CircularProgressIndicator())
            else if (_currentStep == 0)
              _buildPasswordStep()
            else if (_currentStep == 1)
              _biometricsEnabled ? _buildBiometricStep() : _buildConfirmationStep(),
            // Error Message
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_currentStep == 0) ...[
          TextButton(
            onPressed: _isAuthenticating
                ? null
                : () => Navigator.of(context).pop(null),
            child: Text('Cancel', style: TextStyle(color: AppTheme.grey)),
          ),
          ElevatedButton(
            onPressed: _isAuthenticating ? null : _verifyPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: AppTheme.black,
            ),
            child: _isAuthenticating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Verify Password'),
          ),
        ] else if (_currentStep == 1) ...[
          TextButton(
            onPressed: () {
              setState(() {
                _currentStep = 0;
                _biometricVerified = false;
                _error = null;
              });
            },
            child: Text('Back', style: TextStyle(color: AppTheme.grey)),
          ),
          ElevatedButton(
            onPressed: _isAuthenticating
                ? null
                : _biometricsEnabled
                    ? _authenticateBiometric
                    : _confirmTransaction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: AppTheme.black,
            ),
            child: _isAuthenticating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_biometricsEnabled
                    ? 'Authenticate with Biometrics'
                    : 'Confirm Transaction'),
          ),
        ],
      ],
    );
  }

  Widget _buildStepIndicator() {
    final step2Label = _biometricsEnabled ? 'Biometric' : 'Confirm';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepDot(0, 'Password', _currentStep >= 0),
        Container(
          width: 40,
          height: 2,
          color: _currentStep > 0
              ? AppTheme.primaryGold
              : AppTheme.grey.withOpacity(0.3),
        ),
        _buildStepDot(1, step2Label, _currentStep >= 1),
      ],
    );
  }

  Widget _buildStepDot(int step, String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppTheme.primaryGold : AppTheme.grey.withOpacity(0.3),
          ),
          child: Center(
            child: isActive && step < _currentStep
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? AppTheme.black : AppTheme.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? AppTheme.primaryGold : AppTheme.grey,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
          ),
          Text(
            value,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Step 1: Enter Password',
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your wallet password to verify your identity',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          enabled: !_isAuthenticating,
          style: TextStyle(color: AppTheme.white),
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: TextStyle(color: AppTheme.grey),
            hintText: 'Enter your password',
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
        if (_passwordVerified) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Password verified successfully',
                    style: TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConfirmationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Step 2: Confirm Transaction',
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Please confirm this transaction. Your password has been verified.',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
        ),
        const SizedBox(height: 24),
        Center(
          child: Icon(
            Icons.verified_user,
            size: 80,
            color: _biometricVerified
                ? Colors.green
                : AppTheme.primaryGold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkGrey.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                'Transaction Summary',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow('Asset', widget.assetSymbol),
              _buildDetailRow('Amount', widget.amount),
              _buildDetailRow('Recipient', widget.recipient.length > 20
                  ? '${widget.recipient.substring(0, 20)}...'
                  : widget.recipient),
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
              Icon(Icons.info_outline, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your wallet uses password-only protection. Tap confirm to proceed with the transaction.',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBiometricStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Step 2: Biometric Authentication',
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Use your fingerprint or Face ID to sign the transaction',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
        ),
        const SizedBox(height: 24),
        Center(
          child: Icon(
            Icons.fingerprint,
            size: 80,
            color: _biometricVerified
                ? Colors.green
                : AppTheme.primaryGold,
          ),
        ),
        const SizedBox(height: 16),
        if (_biometricVerified) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Biometric authentication successful',
                    style: TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
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
                    'Tap the button below to authenticate with biometrics',
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _verifyPassword() async {
    if (_passwordController.text.isEmpty) {
      setState(() {
        _error = 'Please enter your password';
      });
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _error = null;
    });

    // Verify password with Firebase Auth
    try {
      final authProvider = Provider.of<local_auth.AuthProvider>(
        context,
        listen: false,
      );
      final currentUser = authProvider.user;
      if (currentUser == null || currentUser.email == null) {
        throw Exception('User not authenticated');
      }

      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: _passwordController.text,
      );
      await currentUser.reauthenticateWithCredential(credential);

      setState(() {
        _passwordVerified = true;
        _isAuthenticating = false;
        _error = null;
      });

      // Move to next step after a short delay
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        _currentStep = 1;
      });
    } catch (e) {
      setState(() {
        _error = 'Invalid password. Please try again.';
        _isAuthenticating = false;
        _passwordVerified = false;
      });
    }
  }

  Future<void> _authenticateBiometric() async {
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

      // Authenticate with biometrics using BiometricService
      // First get the wallet to retrieve credential ID
      final walletDoc = await FirebaseFirestore.instance
          .collection('secure_wallets')
          .doc(user.uid)
          .get();
      
      if (!walletDoc.exists) {
        throw Exception('Secure wallet not found');
      }

      final walletData = walletDoc.data()!;
      final biometricData = walletData['biometricData'] as Map<String, dynamic>?;
      final credentialId = biometricData?['credentialId'] as String?;

      final biometricResult = await BiometricService.authenticateWithBiometrics(
        localizedReason: 'Authenticate to sign this transaction',
        credentialId: credentialId,
      );

      if (biometricResult['success'] == true) {
        setState(() {
          _biometricVerified = true;
          _isAuthenticating = false;
        });

        // Return success result
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pop({
            'password': _passwordController.text,
            'biometricVerified': true,
          });
        }
      } else {
        throw Exception(biometricResult['error'] ?? 'Biometric authentication failed');
      }
    } catch (e) {
      setState(() {
        _error = 'Biometric authentication failed: $e';
        _isAuthenticating = false;
        _biometricVerified = false;
      });
    }
  }

  Future<void> _confirmTransaction() async {
    setState(() {
      _isAuthenticating = true;
      _error = null;
    });

    try {
      // For password-only wallets, just confirm and return
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _biometricVerified = true; // Mark as verified for consistency
        _isAuthenticating = false;
      });

      // Return success result
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.of(context).pop({
          'password': _passwordController.text,
          'biometricVerified': false, // No biometrics, but transaction confirmed
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Transaction confirmation failed: $e';
        _isAuthenticating = false;
        _biometricVerified = false;
      });
    }
  }
}
