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
import 'package:cloud_firestore/cloud_firestore.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
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
          // Load transactions from blockchain after wallet status is confirmed
          stellarProvider.loadTransactionsFromBlockchain();
        }
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Transactions', 
                        style: AppTheme.headingMedium.copyWith(
                          color: AppTheme.primaryGold,
                          fontSize: 24,
                        )
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
                        onPressed: () => stellarProvider.loadTransactionsFromBlockchain(),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Transactions', 
              style: AppTheme.headingMedium.copyWith(
                color: AppTheme.primaryGold,
                fontSize: isTablet ? 22 : null,
              )
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
              onPressed: () => stellarProvider.loadTransactionsFromBlockchain(),
              tooltip: 'Refresh transactions',
            ),
          ],
        ),
        const SizedBox(height: 12),
        TransactionList(
          transactions: stellarProvider.transactions,
        ),
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

  void _showBuyAkofaDialog(BuildContext context) {
                      showDialog(
                        context: context,
                        builder: (context) => EnhancedBuyAkofaDialog(),
    );
  }
  
  void _showReceiveDialog(BuildContext context, String publicKey) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    String? akofaTag;
    if (authProvider.user != null) {
      final doc = await FirebaseFirestore.instance.collection('USER').doc(authProvider.user!.uid).get();
      akofaTag = doc.data()?['akofaTag'];
    }
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final tagController = TextEditingController();
        bool isSaving = false;
        String? tagError;
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
                    color: AppTheme.darkGrey.withValues(alpha: 0.3),
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
                    color: AppTheme.darkGrey.withValues(alpha: 0.3),
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
                                    controller: tagController,
                                    decoration: InputDecoration(
                                      hintText: 'yourtag',
                                      errorText: tagError,
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
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        String tag = tagController.text.trim().toLowerCase();
                                        if (tag.isEmpty) {
                                          setState(() => tagError = 'Required');
                                          return;
                                        }
                                        if (tag.contains(' ')) {
                                          setState(() => tagError = 'No spaces allowed in Akofa Tag');
                                          return;
                                        }
                                        setState(() {
                                          isSaving = true;
                                          tagError = null;
                                        });
                                        
                                        try {
                                        // Check uniqueness
                                        final query = await FirebaseFirestore.instance.collection('USER').where('akofaTag', isEqualTo: tag).limit(1).get();
                                        if (query.docs.isNotEmpty) {
                                          setState(() {
                                              tagError = 'Tag is already taken';
                                              isSaving = false;
                                          });
                                          return;
                                        }
                                        // Save to Firestore
                                        await FirebaseFirestore.instance.collection('USER').doc(authProvider.user!.uid).update({'akofaTag': tag});
                                        setState(() {
                                            isSaving = false;
                                        });
                                        Navigator.of(context).pop();
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Akofa Tag created!'), backgroundColor: Colors.green));
                                        } catch (e) {
                                          setState(() {
                                            tagError = 'Error: $e';
                                            isSaving = false;
                                          });
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryGold,
                                  foregroundColor: AppTheme.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: isSaving
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
}
