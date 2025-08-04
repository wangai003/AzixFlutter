import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../providers/auth_provider.dart';
import '../providers/stellar_provider.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_layout.dart';
import '../widgets/custom_button.dart';
import '../models/transaction.dart';
import '../widgets/send_dialog.dart';
import '../widgets/buy_dialog.dart';
import '../widgets/wallet_card.dart';
import '../widgets/quick_actions_row.dart';
import '../widgets/transaction_list.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with SingleTickerProviderStateMixin {
  bool _showSecretKey = false;
  Map<String, dynamic>? _credentials;
  bool _isLoading = false;
  String? _error;
  late TabController _tabController;
  final TextEditingController _recipientController = TextEditingController();
  String? _sendError;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Check wallet status, Akofa trustline, and refresh balance when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
      
      // Always check wallet status to get the public key
      stellarProvider.checkWalletStatus().then((hasWallet) {
        if (hasWallet && stellarProvider.publicKey != null) {
          stellarProvider.checkAkofaTrustline();
          stellarProvider.refreshBalance();
        }
      });
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _recipientController.dispose();
    super.dispose();
  }
  
  // Helper method to format DateTime to a readable string
  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final stellarProvider = Provider.of<StellarProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isWebPlatform = kIsWeb;
    
    // Determine layout based on screen size
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    final isLargeDesktop = ResponsiveLayout.isLargeDesktop(context);
    
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await stellarProvider.refreshBalance();
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
  
  Widget _buildDesktopLayout(BuildContext context, StellarProvider stellarProvider, AuthProvider authProvider) {
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
                    onShowQR: () => _showReceiveSheet(context, stellarProvider.publicKey),
                  ),
                  const SizedBox(height: 24),
                  QuickActionsRow(
                    onSend: () => _showSendDialog(context),
                    onReceive: () => _showReceiveSheet(context, stellarProvider.publicKey),
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
                  Text('Recent Transactions', 
                    style: AppTheme.headingMedium.copyWith(
                      color: AppTheme.primaryGold,
                      fontSize: 24,
                    )
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 500, // Fixed height for desktop
                    decoration: BoxDecoration(
                      color: AppTheme.black,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.grey.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: TransactionList(transactions: stellarProvider.transactions),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildMobileTabletLayout(BuildContext context, StellarProvider stellarProvider, bool isTablet) {
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
          onReceive: () => _showReceiveSheet(context, stellarProvider.publicKey),
          onBuy: () => _showBuyAkofaDialog(context),
        ),
        const SizedBox(height: 32),
        Text('Recent Transactions', 
          style: AppTheme.headingMedium.copyWith(
            color: AppTheme.primaryGold,
            fontSize: isTablet ? 22 : null,
          )
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
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.grey,
          ),
        ),
      ],
    ).animate()
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
  
  Widget _buildBalanceCards(StellarProvider stellarProvider) {
    // Load all asset balances when the widget is built
    if (stellarProvider.publicKey != null && stellarProvider.assetBalances.isEmpty) {
      Future.microtask(() => stellarProvider.loadAllAssetBalances());
    }
    
    return Column(
      children: [
        // XLM Balance Card
        _buildAssetCard(
          title: 'Stellar Balance',
          amount: '${stellarProvider.balance}',
          symbol: 'XLM',
          icon: Icons.account_balance_wallet,
          gradient: const LinearGradient(
            colors: [
              Color(0xFF3A7BD5),
              Color(0xFF00D2FF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          animationDelay: 0,
          onTap: () async {
            if (stellarProvider.publicKey != null) {
              // Ensure wallet assets are loaded before showing the dialog
              await stellarProvider.loadWalletAssets();
              
              if (!mounted) return;
              showDialog(
                context: context,
                builder: (context) => SendDialog(
                  assetCode: 'XLM',
                  balance: stellarProvider.balance,
                ),
              ).then((success) {
                if (success == true) {
                  stellarProvider.refreshBalance();
                }
              });
            }
          },
        ),
        const SizedBox(height: 16),
        
        // AKOFA Balance Card
        _buildAssetCard(
          title: 'Akofa Balance',
          amount: stellarProvider.hasAkofaTrustline 
              ? '${stellarProvider.akofaBalance}'
              : '0.00',
          symbol: 'AKOFA',
          icon: Icons.token,
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFD700),
              Color(0xFFDAA520),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          animationDelay: 200,
          showTrustlineButton: !stellarProvider.hasAkofaTrustline,
          onTrustlinePressed: () => _proceedWithTrustlineAddition(context, stellarProvider),
          onTap: stellarProvider.hasAkofaTrustline ? () async {
            // Ensure wallet assets are loaded before showing the dialog
            await stellarProvider.loadWalletAssets();
            
            if (!mounted) return;
            showDialog(
              context: context,
              builder: (context) => SendDialog(
                assetCode: 'AKOFA',
                balance: stellarProvider.akofaBalance,
              ),
            ).then((success) {
              if (success == true) {
                stellarProvider.refreshBalance();
              }
            });
          } : null,
        ),
        
        // Add other supported assets
        if (stellarProvider.publicKey != null && stellarProvider.assetBalances.isNotEmpty)
          ...stellarProvider.supportedAssets
              .where((asset) => 
                  asset['code'] != 'XLM' && 
                  asset['code'] != 'AKOFA' && 
                  (stellarProvider.assetBalances[asset['code']] != null && 
                   double.parse(stellarProvider.assetBalances[asset['code']] ?? '0') > 0))
              .map((asset) {
                final assetCode = asset['code']!;
                final balance = stellarProvider.assetBalances[assetCode] ?? '0.00';
                
                // Skip assets with zero balance
                if (double.parse(balance) <= 0) return const SizedBox.shrink();
                
                return Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildAssetCard(
                      title: '${asset['name']} Balance',
                      amount: balance,
                      symbol: assetCode,
                      icon: assetCode == 'USDC' ? Icons.attach_money 
                          : assetCode == 'BTC' ? Icons.currency_bitcoin
                          : Icons.currency_exchange,
                      gradient: LinearGradient(
                        colors: assetCode == 'USDC' ? [
                          const Color(0xFF2775CA),
                          const Color(0xFF4195EA),
                        ] : assetCode == 'BTC' ? [
                          const Color(0xFFF7931A),
                          const Color(0xFFFFAB40),
                        ] : [
                          const Color(0xFF627EEA),
                          const Color(0xFF8CA3F4),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      animationDelay: 300,
                      onTap: () async {
                        // Ensure wallet assets are loaded before showing the dialog
                        await stellarProvider.loadWalletAssets();
                        
                        if (!mounted) return;
                        showDialog(
                          context: context,
                          builder: (context) => SendDialog(
                            assetCode: assetCode,
                            balance: balance,
                          ),
                        ).then((success) {
                          if (success == true) {
                            stellarProvider.loadAllAssetBalances();
                            stellarProvider.loadWalletAssets();
                          }
                        });
                      },
                    ),
                  ],
                );
              }).toList(),
      ],
    );
  }
  
  Widget _buildAssetCard({
    required String title,
    required String amount,
    required String symbol,
    required IconData icon,
    required Gradient gradient,
    required int animationDelay,
    bool showTrustlineButton = false,
    VoidCallback? onTrustlinePressed,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
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
                title,
                style: AppTheme.headingSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                icon,
                color: Colors.white.withOpacity(0.8),
                size: 28,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: AppTheme.headingLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 36,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  symbol,
                  style: AppTheme.bodyLarge.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          
          if (showTrustlineButton) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTrustlinePressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Add Akofa Trustline',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
    ).animate()
      .fadeIn(
        duration: const Duration(milliseconds: 600),
        delay: Duration(milliseconds: animationDelay),
        curve: Curves.easeOut,
      )
      .slideY(
        begin: 0.2,
        end: 0,
        duration: const Duration(milliseconds: 600),
        delay: Duration(milliseconds: animationDelay),
        curve: Curves.easeOut,
      );
  }
  
  Widget _buildQuickActions(StellarProvider stellarProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
            'Quick Actions',
            style: AppTheme.headingSmall,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton(
                icon: Icons.arrow_upward,
                label: 'Send',
                onTap: () async {
                  if (stellarProvider.publicKey != null) {
                    // Ensure wallet assets are loaded before showing the dialog
                    await stellarProvider.loadWalletAssets();
                    
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      builder: (context) => SendDialog(
                        assetCode: 'XLM',
                        balance: stellarProvider.balance,
                      ),
                    ).then((success) {
                      if (success == true) {
                        // Refresh balances after successful send
                        stellarProvider.refreshBalance();
                      }
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No wallet found'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                delay: 400,
              ),
              _buildActionButton(
                icon: Icons.arrow_downward,
                label: 'Receive',
                onTap: () {
                  // Show public key for receiving
                  if (stellarProvider.publicKey != null) {
                    _showReceiveDialog(context, stellarProvider.publicKey!);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No wallet found'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                delay: 500,
              ),
              _buildActionButton(
                icon: Icons.add,
                label: 'Buy',
                onTap: () {
                  if (stellarProvider.publicKey != null) {
                    // Check if user has Akofa trustline
                    if (!stellarProvider.hasAkofaTrustline) {
                      _showAddTrustlineDialog(context);
                    } else {
                      // Show buy dialog
                      showDialog(
                        context: context,
                        builder: (context) => const BuyDialog(),
                      ).then((success) {
                        if (success == true) {
                          // Refresh balances after successful purchase
                          stellarProvider.refreshBalance();
                        }
                      });
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No wallet found'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                delay: 700,
              ),
            ],
          ),
        ],
      ),
    ).animate()
      .fadeIn(
        duration: const Duration(milliseconds: 600),
        delay: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      )
      .slideY(
        begin: 0.2,
        end: 0,
        duration: const Duration(milliseconds: 600),
        delay: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required int delay,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.darkGrey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppTheme.primaryGold,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.white,
              ),
            ),
          ],
        ),
      ),
    ).animate()
      .fadeIn(
        duration: const Duration(milliseconds: 400),
        delay: Duration(milliseconds: delay),
        curve: Curves.easeOut,
      )
      .scale(
        begin: const Offset(0.8, 0.8),
        end: const Offset(1, 1),
        duration: const Duration(milliseconds: 400),
        delay: Duration(milliseconds: delay),
        curve: Curves.easeOut,
      );
  }
  
  Widget _buildTransactionsTab(StellarProvider stellarProvider) {
    // Placeholder for transaction history
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction History',
            style: AppTheme.headingSmall,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: stellarProvider.isTransactionLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
                    ),
                  )
                : stellarProvider.transactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 48,
                              color: AppTheme.grey.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No transactions yet',
                              style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your transaction history will appear here',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.grey.withOpacity(0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: stellarProvider.transactions.length,
                        itemBuilder: (context, index) {
                          final transaction = stellarProvider.transactions[index];
                          return ListTile(
                            leading: Icon(
                              transaction.type == TransactionType.send ? Icons.arrow_upward : Icons.arrow_downward,
                              color: transaction.type == TransactionType.send ? Colors.red : Colors.green,
                            ),
                            title: Text(
                              transaction.description,
                              style: AppTheme.bodyMedium,
                            ),
                            subtitle: Text(
                              _formatDate(transaction.timestamp),
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.grey,
                              ),
                            ),
                            trailing: Text(
                              transaction.assetCode,
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCredentialsTab(StellarProvider stellarProvider, AuthProvider authProvider) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wallet Credentials',
            style: AppTheme.headingSmall,
          ),
          const SizedBox(height: 16),
          
          // Always show the public key without authentication
          if (stellarProvider.publicKey != null) ...[
            const Divider(color: AppTheme.grey),
            const SizedBox(height: 16),
            _buildCredentialItem(
              label: 'Public Key',
              value: stellarProvider.publicKey!,
              canToggleVisibility: false,
            ),
            const SizedBox(height: 16),
            Text(
              'Your public key is used to receive funds and is safe to share.',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.grey,
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Secret key section - requires authentication
          Text(
            'Your secret key is encrypted and stored securely. You can view it after re-authenticating.',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.grey,
            ),
          ),
          const SizedBox(height: 24),
          
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
              ),
            )
          else if (_credentials != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCredentialItem(
                    label: 'Secret Key',
                    value: _credentials!['secretKey'],
                    isVisible: _showSecretKey,
                    canToggleVisibility: true,
                    onToggleVisibility: () {
                      setState(() {
                        _showSecretKey = !_showSecretKey;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'WARNING: Never share your secret key with anyone. Anyone with your secret key has full control of your wallet.',
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.red,
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: CustomButton(
                      onPressed: () {
                        setState(() {
                          _credentials = null;
                        });
                      },
                      text: 'Hide Secret Key',
                      icon: Icons.visibility_off,
                      isOutlined: true,
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: Center(
                child: CustomButton(
                  onPressed: () async {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    
                    try {
                      // Re-authenticate with Google
                      final success = await authProvider.signInWithGoogle();
                      
                      if (success) {
                        // Get wallet credentials
                        final credentials = await stellarProvider.getFullWalletCredentials();
                        
                        setState(() {
                          _credentials = credentials;
                          _isLoading = false;
                        });
                      } else {
                        setState(() {
                          _error = 'Authentication failed';
                          _isLoading = false;
                        });
                      }
                    } catch (e) {
                      setState(() {
                        _error = 'Failed to retrieve credentials: $e';
                        _isLoading = false;
                      });
                    }
                  },
                  text: 'View Secret Key',
                  icon: Icons.lock_open,
                ),
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
    );
  }
  
  Widget _buildCredentialItem({
    required String label,
    required String value,
    bool isVisible = true,
    bool canToggleVisibility = false,
    VoidCallback? onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.darkGrey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isVisible
                      ? value
                      : '••••••••••••••••••••••••••••••••••••••••••••••••••',
                  style: AppTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (canToggleVisibility)
                IconButton(
                  icon: Icon(
                    isVisible ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  color: AppTheme.grey,
                  onPressed: onToggleVisibility,
                ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                color: AppTheme.grey,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$label copied to clipboard'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildSettingsTab(StellarProvider stellarProvider) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wallet Settings',
            style: AppTheme.headingSmall,
          ),
          const SizedBox(height: 24),
          _buildSettingItem(
            icon: Icons.refresh,
            title: 'Refresh Balance',
            subtitle: 'Update your wallet balance',
            onTap: () async {
              await stellarProvider.refreshBalance();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Balance refreshed'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
          Divider(color: AppTheme.grey.withOpacity(0.3)),
          _buildSettingItem(
            icon: Icons.security,
            title: 'Security Settings',
            subtitle: 'Manage your wallet security',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Security settings coming soon'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
          ),
          // ignore: deprecated_member_use
          Divider(color: AppTheme.grey.withOpacity(0.3)),
          _buildSettingItem(
            icon: Icons.notifications,
            title: 'Notifications',
            subtitle: 'Configure transaction alerts',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notification settings coming soon'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
          ),
          Divider(color: AppTheme.grey.withOpacity(0.3)),
          _buildSettingItem(
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'Get assistance with your wallet',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Help & Support coming soon'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.darkGrey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: AppTheme.primaryGold,
        ),
      ),
      title: Text(
        title,
        style: AppTheme.bodyMedium.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTheme.bodySmall.copyWith(
          color: AppTheme.grey,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: AppTheme.grey,
      ),
      onTap: onTap,
    );
  }
  
  void _showReceiveDialog(BuildContext context, String publicKey) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    String? akofaTag;
    if (authProvider.user != null) {
      final doc = await FirebaseFirestore.instance.collection('USER').doc(authProvider.user!.uid).get();
      akofaTag = doc.data()?['akofaTag'];
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final _tagController = TextEditingController();
        bool _isSaving = false;
        String? _tagError;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            backgroundColor: AppTheme.black,
            title: Text(
              'Receive Funds',
              style: AppTheme.headingSmall.copyWith(
                color: AppTheme.primaryGold,
              ),
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
                const SizedBox(height: 24),
                // Akofa Tag section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkGrey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: akofaTag != null && akofaTag.isNotEmpty
                      ? Column(
                          children: [
                            Text(
                              'Your Akofa Tag',
                              style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('₳$akofaTag', style: AppTheme.bodyLarge.copyWith(color: AppTheme.white, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.copy, color: AppTheme.primaryGold),
                                  tooltip: 'Copy Akofa Tag',
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: '₳$akofaTag'));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Akofa Tag copied!'), backgroundColor: Colors.green),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Text('Create your Akofa Tag', style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('₳', style: TextStyle(fontSize: 20, color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: TextField(
                                    controller: _tagController,
                                    decoration: InputDecoration(
                                      hintText: 'yourtag',
                                      errorText: _tagError,
                                      border: InputBorder.none,
                                    ),
                                    style: const TextStyle(color: AppTheme.white, fontSize: 18),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSaving
                                    ? null
                                    : () async {
                                        String tag = _tagController.text.trim().toLowerCase();
                                        if (tag.isEmpty) {
                                          setState(() => _tagError = 'Required');
                                          return;
                                        }
                                        if (tag.contains(' ')) {
                                          setState(() => _tagError = 'No spaces allowed in Akofa Tag');
                                          return;
                                        }
                                        setState(() {
                                          _isSaving = true;
                                          _tagError = null;
                                        });
                                        // Check uniqueness
                                        final query = await FirebaseFirestore.instance.collection('USER').where('akofaTag', isEqualTo: tag).limit(1).get();
                                        if (query.docs.isNotEmpty) {
                                          setState(() {
                                            _tagError = 'Tag is already taken';
                                            _isSaving = false;
                                          });
                                          return;
                                        }
                                        // Save to Firestore
                                        await FirebaseFirestore.instance.collection('USER').doc(authProvider.user!.uid).update({'akofaTag': tag});
                                        setState(() {
                                          _isSaving = false;
                                        });
                                        Navigator.of(context).pop();
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Akofa Tag created!'), backgroundColor: Colors.green));
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryGold,
                                  foregroundColor: AppTheme.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: _isSaving
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Save Tag', style: TextStyle(fontWeight: FontWeight.bold)),
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
          ),
        );
      },
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
          backgroundColor: AppTheme.black,
          title: Text(
            'Adding Akofa Trustline',
            style: AppTheme.headingSmall.copyWith(
              color: AppTheme.primaryGold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
              ),
              const SizedBox(height: 16),
              const Text(
                'This may take a moment. Please wait...',
                style: TextStyle(color: AppTheme.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Do not close the app or navigate away from this screen.',
                style: TextStyle(
                  fontSize: 12, 
                  fontStyle: FontStyle.italic,
                  color: AppTheme.grey.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
    
    try {
      // First check if the account has enough XLM
      final xlmCheck = await stellarProvider.checkAccountXlmBalance();
      
      // Close the loading dialog
      Navigator.of(context).pop();
      
      if (xlmCheck['hasEnough'] != true) {
        // Show warning dialog about insufficient XLM
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: AppTheme.black,
              title: Text(
                'Insufficient XLM Balance',
                style: AppTheme.headingSmall.copyWith(
                  color: Colors.red,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your account needs more XLM to add a trustline.',
                    style: const TextStyle(color: AppTheme.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Current balance: ${xlmCheck['balance']} XLM',
                    style: const TextStyle(color: AppTheme.white),
                  ),
                  Text(
                    'Required: ${xlmCheck['needed']} XLM',
                    style: const TextStyle(color: AppTheme.white),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'What to do:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Send XLM to your account from another wallet',
                    style: TextStyle(color: AppTheme.white),
                  ),
                  const Text(
                    '• Use the Stellar Testnet Friendbot to get free test XLM',
                    style: TextStyle(color: AppTheme.white),
                  ),
                  const Text(
                    '• Contact support if you need assistance',
                    style: TextStyle(color: AppTheme.white),
                  ),
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
                    // Show loading dialog again
                    _showTrustlineLoadingDialog(context, stellarProvider);
                  },
                  child: const Text('Try Anyway'),
                ),
              ],
            );
          },
        );
      } else {
        // Show loading dialog again
        _showTrustlineLoadingDialog(context, stellarProvider);
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
  
  void _showAddTrustlineDialog(BuildContext context) {
    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.black,
          title: Text(
            'Add Akofa Trustline',
            style: AppTheme.headingSmall.copyWith(
              color: AppTheme.primaryGold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'To swap or buy AKOFA tokens, you need to add a trustline first.',
                style: TextStyle(color: AppTheme.white),
              ),
              const SizedBox(height: 16),
              const Text(
                'A trustline allows your wallet to hold AKOFA tokens. This is a one-time setup.',
                style: TextStyle(color: AppTheme.grey),
              ),
              const SizedBox(height: 16),
              const Text(
                'Note: Adding a trustline requires a small amount of XLM for the network fee.',
                style: TextStyle(
                  color: AppTheme.primaryGold,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showTrustlineLoadingDialog(context, stellarProvider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Add Trustline'),
            ),
          ],
        );
      },
    );
  }
  
  void _showTrustlineLoadingDialog(BuildContext context, StellarProvider stellarProvider) async {
    // Show a loading dialog with progress indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.black,
          title: Text(
            'Adding Akofa Trustline',
            style: AppTheme.headingSmall.copyWith(
              color: AppTheme.primaryGold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
              ),
              const SizedBox(height: 16),
              const Text(
                'This may take a moment. Please wait...',
                style: TextStyle(color: AppTheme.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Do not close the app or navigate away from this screen.',
                style: TextStyle(
                  fontSize: 12, 
                  fontStyle: FontStyle.italic,
                  color: AppTheme.grey.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
    
    try {
      // Call the implementation
      final result = await stellarProvider.addAkofaTrustline();
      
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
              backgroundColor: AppTheme.black,
              title: Text(
                'Trustline Addition Failed',
                style: AppTheme.headingSmall.copyWith(
                  color: Colors.red,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stellarProvider.error ?? 'Failed to add Akofa trustline.',
                    style: const TextStyle(color: AppTheme.white),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'What to try:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Check your internet connection',
                    style: TextStyle(color: AppTheme.white),
                  ),
                  const Text(
                    '• Make sure your account has XLM for fees',
                    style: TextStyle(color: AppTheme.white),
                  ),
                  const Text(
                    '• Wait a few minutes and try again',
                    style: TextStyle(color: AppTheme.white),
                  ),
                  const Text(
                    '• Restart the app if the issue persists',
                    style: TextStyle(color: AppTheme.white),
                  ),
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

  void _showBuyAkofaDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const BuyDialog(),
    );
  }

  void _showReceiveSheet(BuildContext context, String? publicKey) {
    if (publicKey != null) {
      _showReceiveDialog(context, publicKey);
    }
  }

  void _showSendDialog(BuildContext context) async {
    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
    await stellarProvider.loadWalletAssets();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => SendDialog(
        assetCode: 'XLM',
        balance: stellarProvider.balance,
      ),
    ).then((success) {
      if (success == true) {
        stellarProvider.refreshBalance();
      }
    });
  }

  Future<String?> resolveWalletAddress(String input) async {
    if (input.startsWith('₳')) {
      final tag = input.substring(1).trim().toLowerCase();
      debugPrint('Resolving Akofa tag: $tag');
      final query = await FirebaseFirestore.instance
          .collection('USER')
          .where('akofaTag', isEqualTo: tag)
          .limit(1)
          .get();
      debugPrint('USER query result count: ${query.docs.length}');
      if (query.docs.isNotEmpty) {
        final userId = query.docs.first.id;
        debugPrint('Found userId: $userId for tag: $tag');
        final walletDoc = await FirebaseFirestore.instance.collection('wallets').doc(userId).get();
        debugPrint('Wallet doc exists: ${walletDoc.exists}');
        if (walletDoc.exists) {
          final publicKey = walletDoc.data()?['publicKey'];
          debugPrint('Wallet publicKey: $publicKey');
          if (publicKey != null && publicKey is String && publicKey.isNotEmpty) {
            return publicKey;
          } else {
            debugPrint('Recipient has no wallet public key.');
            return null;
          }
        } else {
          debugPrint('Recipient has not set up a wallet.');
          return null;
        }
      } else {
        debugPrint('Akofa Tag not found: $tag');
        return null; // Tag not found
      }
    } else {
      // Assume input is a wallet address
      return input;
    }
  }

  Future<void> _onSendPressed() async {
    final resolvedAddress = await resolveWalletAddress(_recipientController.text.trim());
    if (resolvedAddress == null) {
      setState(() => _sendError = 'Recipient tag not found.');
      return;
    }
    // Proceed with sending to resolvedAddress
    // ... existing send logic ...
  }
}