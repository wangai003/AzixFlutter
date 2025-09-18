import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stellar_provider.dart';
import '../providers/auth_provider.dart';
import '../services/stellar_service.dart';
import '../theme/app_theme.dart';

class WalletHomeScreen extends StatelessWidget {
  const WalletHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stellarProvider = Provider.of<StellarProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Enhanced Wallet',
          style: AppTheme.headingMedium.copyWith(
            color: AppTheme.primaryGold,
          ),
        ),
        backgroundColor: AppTheme.black,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.black,
              AppTheme.darkGrey.withOpacity(0.3),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.darkGrey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
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
                        Icon(
                          Icons.account_balance_wallet,
                          color: AppTheme.primaryGold,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome to Your Enhanced Wallet',
                                style: AppTheme.headingMedium.copyWith(
                                  color: AppTheme.primaryGold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Secure, fast, and feature-rich crypto wallet',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Wallet Status
              if (!stellarProvider.hasWallet) ...[
                _buildNoWalletSection(context, stellarProvider),
              ] else ...[
                _buildWalletOverview(context, stellarProvider),
                const SizedBox(height: 24),
                _buildQuickActions(context),
                const SizedBox(height: 24),
                _buildFeatures(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoWalletSection(BuildContext context, StellarProvider stellarProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryGold.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.wallet_outlined,
            size: 64,
            color: AppTheme.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No Wallet Found',
            style: AppTheme.headingMedium.copyWith(
              color: AppTheme.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your secure wallet to start managing your crypto assets',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                  onPressed: stellarProvider.isLoading
                  ? null
                  : () => _createWallet(context, stellarProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: stellarProvider.isLoading
                  ? const CircularProgressIndicator()
                  : const Text(
                      'Create Wallet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          if (stellarProvider.error != null) ...[
            const SizedBox(height: 16),
            Text(
              stellarProvider.error!,
              style: AppTheme.bodySmall.copyWith(
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWalletOverview(BuildContext context, StellarProvider stellarProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Wallet Overview',
          style: AppTheme.headingMedium.copyWith(
            color: AppTheme.primaryGold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.darkGrey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
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
                    Icons.account_balance_wallet,
                    color: AppTheme.primaryGold,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'XLM Balance',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${stellarProvider.balance} XLM',
                style: AppTheme.headingLarge.copyWith(
                  color: AppTheme.primaryGold,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 16),
              if (stellarProvider.hasAkofaTrustline) ...[
                Row(
                  children: [
                    Icon(
                      Icons.token,
                      color: AppTheme.primaryGold,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AKOFA Balance',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${stellarProvider.akofaBalance} AKOFA',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.primaryGold.withOpacity(0.8),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: stellarProvider.hasAkofaTrustline
                      ? Colors.green.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  stellarProvider.hasAkofaTrustline
                      ? 'Trustline Active'
                      : 'Trustline Required',
                  style: AppTheme.bodySmall.copyWith(
                    color: stellarProvider.hasAkofaTrustline
                        ? Colors.green
                        : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTheme.headingMedium.copyWith(
            color: AppTheme.primaryGold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context,
                'Send',
                Icons.send,
                () => Navigator.pushNamed(context, '/send'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                context,
                'Receive',
                Icons.qr_code,
                () => Navigator.pushNamed(context, '/receive'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                context,
                'Swap',
                Icons.swap_horiz,
                () => Navigator.pushNamed(context, '/swap'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, VoidCallback onTap) {
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
        child: Column(
          children: [
            Icon(
              icon,
              color: AppTheme.primaryGold,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatures(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Advanced Features',
          style: AppTheme.headingMedium.copyWith(
            color: AppTheme.primaryGold,
          ),
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(
          'Multi-Asset Support',
          'Manage XLM, AKOFA, and other Stellar assets',
          Icons.account_balance,
        ),
        const SizedBox(height: 12),
        _buildFeatureItem(
          'Secure Transactions',
          'Encrypted wallet with biometric authentication',
          Icons.security,
        ),
        const SizedBox(height: 12),
        _buildFeatureItem(
          'Real-time Mining',
          'Earn AKOFA tokens through mining rewards',
            Icons.work,
        ),
        const SizedBox(height: 12),
        _buildFeatureItem(
          'Contact Management',
          'Easy payments to your saved contacts',
          Icons.contacts,
        ),
      ],
    );
  }

  Widget _buildFeatureItem(String title, String description, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryGold.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppTheme.primaryGold,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.grey,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            color: AppTheme.grey,
            size: 16,
          ),
        ],
      ),
    );
  }

  Future<void> _createWallet(BuildContext context, StellarProvider stellarProvider) async {
    final success = await stellarProvider.createWallet(context);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wallet created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
