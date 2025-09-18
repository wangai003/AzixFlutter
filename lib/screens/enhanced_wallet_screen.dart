import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/enhanced_wallet_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/enhanced_transaction_list.dart';
import '../widgets/multi_asset_balance_display.dart';
import '../widgets/mpesa_purchase_dialog.dart';
import '../widgets/send_akofa_dialog.dart';
import '../widgets/qr_code_display.dart';
import '../services/secure_wallet_service.dart';
import '../services/akofa_tag_service.dart';
import '../providers/auth_provider.dart' as local_auth;
import 'secure_wallet_creation_screen.dart';

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
  bool _isLoadingTag = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Refresh wallet data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final walletProvider = Provider.of<EnhancedWalletProvider>(
        context,
        listen: false,
      );
      walletProvider.refreshWallet();
      _loadUserAkofaTag();
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
            onPressed: _showReceiveQR,
            tooltip: 'Receive Address',
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

                const SizedBox(height: 16),

                // Standard Wallet Option
                _buildWalletTypeOption(
                  title: 'Standard Wallet',
                  subtitle: 'Basic security for quick setup',
                  icon: Icons.wallet,
                  features: [
                    'Basic encryption',
                    'Password protection',
                    'Standard security',
                  ],
                  onPressed: walletProvider.isLoading
                      ? null
                      : () => _createWallet(walletProvider),
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
            // Multi-Asset Balance Display
            const MultiAssetBalanceDisplay(),

            const SizedBox(height: 24),

            // Akofa Tag Display
            if (_userAkofaTag != null)
              _buildAkofaTagSection()
            else
              _buildCreateTagPrompt(),

            if (_userAkofaTag != null) const SizedBox(height: 24),

            // Trustline Setup (only show if trustline is missing)
            if (!walletProvider.hasAkofaTrustline)
              _buildTrustlineSetup(walletProvider),

            if (!walletProvider.hasAkofaTrustline) const SizedBox(height: 24),

            // Quick Actions
            _buildQuickActions(walletProvider),

            const SizedBox(height: 24),

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
                  DropdownMenuItem(value: 'mining', child: Text('Mining')),
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
          child: EnhancedTransactionList(
            transactions: walletProvider.transactions,
            onRefresh: _refreshWallet,
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
                'Send AKOFA',
                Icons.send,
                walletProvider.hasAkofaTrustline
                    ? () => _showSendAkofaDialog(walletProvider)
                    : null,
                disabled: !walletProvider.hasAkofaTrustline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Receive',
                Icons.qr_code,
                _showReceiveQR,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
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
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Transaction History',
                Icons.history,
                () => _tabController.animateTo(1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback? onTap, {
    bool disabled = false,
  }) {
    return GestureDetector(
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
    await _loadUserAkofaTag();
    setState(() => _isRefreshing = false);
  }

  Future<void> _loadUserAkofaTag() async {
    final authProvider = Provider.of<local_auth.AuthProvider>(
      context,
      listen: false,
    );

    if (authProvider.user?.uid != null) {
      setState(() => _isLoadingTag = true);

      try {
        final tagResult = await AkofaTagService.getUserTag(
          authProvider.user!.uid,
        );
        if (tagResult['success']) {
          setState(() {
            _userAkofaTag = tagResult['tag'];
            _isLoadingTag = false;
          });
        } else {
          setState(() {
            _userAkofaTag = null;
            _isLoadingTag = false;
          });
          // Prompt user to create a tag if they don't have one
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showCreateTagPrompt();
          });
        }
      } catch (e) {
        setState(() {
          _userAkofaTag = null;
          _isLoadingTag = false;
        });
        // Prompt user to create a tag if there's an error
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showCreateTagPrompt();
        });
      }
    }
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              title: Text('Send XLM', style: TextStyle(color: AppTheme.white)),
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
            // Stablecoins
            ...walletProvider.stablecoins.map(
              (stablecoin) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Text(
                    stablecoin.symbol.substring(0, 1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  'Send ${stablecoin.symbol}',
                  style: TextStyle(color: AppTheme.white),
                ),
                subtitle: Text(
                  '${stablecoin.name} (${stablecoin.peggedCurrency ?? 'Stablecoin'})',
                  style: TextStyle(color: AppTheme.grey, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showSendAssetDialog(walletProvider, stablecoin);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSendAkofaDialog(EnhancedWalletProvider walletProvider) {
    showDialog(
      context: context,
      builder: (context) => SendAkofaDialog(
        walletProvider: walletProvider,
        useBiometrics: walletProvider.hasSecureWallet,
      ),
    );
  }

  void _showSendAssetDialog(
    EnhancedWalletProvider walletProvider,
    dynamic asset,
  ) {
    final recipientController = TextEditingController();
    final amountController = TextEditingController();
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
          content: Column(
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
                        );
                        if (tagResult['success']) {
                          setState(() {
                            resolvedAddress = tagResult['publicKey'];
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
                      // Valid Stellar address
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
                            color: Colors.blue,
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
                  child: Text(
                    'Resolved to: ${resolvedAddress.substring(0, 8)}...${resolvedAddress.substring(resolvedAddress.length - 8)}',
                    style: TextStyle(color: Colors.green, fontSize: 12),
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
              const SizedBox(height: 8),
              Text(
                'Available: ${walletProvider.getAssetBalance(asset.assetId)} ${asset.symbol}',
                style: TextStyle(color: AppTheme.grey, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: AppTheme.grey)),
            ),
            ElevatedButton(
              onPressed: resolvedAddress.isEmpty || isResolvingTag
                  ? null
                  : () async {
                      final amountText = amountController.text.trim();

                      if (amountText.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter amount'),
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

                      Navigator.of(context).pop();

                      // Show loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sending ${amount} ${asset.symbol}...'),
                          backgroundColor: Colors.blue,
                        ),
                      );

                      try {
                        final result = await walletProvider.sendAsset(
                          recipientAddress: resolvedAddress,
                          asset: asset,
                          amount: amount,
                        );

                        if (result['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${asset.symbol} sent successfully!',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to send ${asset.symbol}: ${result['error']}',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error sending ${asset.symbol}: $e'),
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

  void _showReceiveQR() {
    final walletProvider = Provider.of<EnhancedWalletProvider>(
      context,
      listen: false,
    );
    if (walletProvider.publicKey != null) {
      showDialog(
        context: context,
        builder: (context) => QRCodeDisplay(
          address: walletProvider.publicKey!,
          title: 'Receive Assets',
        ),
      );
    }
  }

  void _showPurchaseDialog(EnhancedWalletProvider walletProvider) {
    showDialog(
      context: context,
      builder: (context) => MpesaPurchaseDialog(walletProvider: walletProvider),
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
                  icon: Icon(Icons.copy, color: AppTheme.primaryGold, size: 20),
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

  Widget _buildCreateTagPrompt() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryGold.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: AppTheme.primaryGold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Create Your Akofa Tag',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Get a simple, memorable tag that makes receiving payments easy. No more sharing long wallet addresses!',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Example: john1234',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.primaryGold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Easy to remember, easy to share',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _createAkofaTag,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    foregroundColor: AppTheme.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: const Text(
                    'Create Tag',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateTagPrompt() {
    showDialog(
      context: context,
      barrierDismissible: false, // User must respond
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text(
          'Create Your Akofa Tag',
          style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tag, size: 48, color: AppTheme.primaryGold),
            const SizedBox(height: 16),
            Text(
              'An Akofa Tag makes it easy for others to send you payments. It\'s a simple, memorable identifier that replaces your complex wallet address.',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryGold.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Example Tags:',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'john1234 • sarah5678 • mike9876',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Skip for Now', style: TextStyle(color: AppTheme.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _createAkofaTag();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: AppTheme.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Create Tag',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createAkofaTag() async {
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
              'Creating your Akofa Tag...',
              style: TextStyle(color: AppTheme.white),
            ),
          ],
        ),
      ),
    );

    try {
      // Get user's first name from auth provider or user data
      String firstName = '';

      // Try to get display name from Firebase Auth
      if (authProvider.user?.displayName != null &&
          authProvider.user!.displayName!.isNotEmpty) {
        firstName = authProvider.user!.displayName!
            .split(' ')
            .first
            .toLowerCase();
      } else {
        // Fallback: try to get from Firestore user document
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('USER')
              .doc(authProvider.user!.uid)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data();
            if (userData?['displayName'] != null) {
              firstName = userData!['displayName']
                  .toString()
                  .split(' ')
                  .first
                  .toLowerCase();
            }
          }
        } catch (e) {
          // Continue with empty firstName if we can't get it
        }
      }

      // If we still don't have a first name, use a generic one
      if (firstName.isEmpty) {
        firstName = 'user';
      }

      final result = await AkofaTagService.generateUniqueTag(
        userId: authProvider.user!.uid,
        firstName: firstName,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      if (result['success']) {
        setState(() {
          _userAkofaTag = result['tag'];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Akofa Tag created: ${result['tag']}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create tag: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating tag: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
