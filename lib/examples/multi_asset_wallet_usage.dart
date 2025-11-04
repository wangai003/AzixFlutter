// Multi-Asset Wallet Usage Examples
// This file demonstrates how to use the enhanced wallet's multi-asset capabilities

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/enhanced_wallet_provider.dart';
import '../models/asset_config.dart';
import '../widgets/multi_asset_balance_display.dart';

class MultiAssetWalletExample extends StatefulWidget {
  const MultiAssetWalletExample({super.key});

  @override
  State<MultiAssetWalletExample> createState() =>
      _MultiAssetWalletExampleState();
}

class _MultiAssetWalletExampleState extends State<MultiAssetWalletExample> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Multi-Asset Wallet Demo')),
      body: Consumer<EnhancedWalletProvider>(
        builder: (context, walletProvider, child) {
          return Column(
            children: [
              // Multi-asset balance display
              Expanded(child: MultiAssetBalanceDisplay()),

              // Action buttons
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => _setupStablecoins(walletProvider),
                      child: const Text('Setup Stablecoin Trustlines'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _sendStablecoin(walletProvider),
                      child: const Text('Send USDC'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _checkBalances(walletProvider),
                      child: const Text('Refresh Balances'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Example: Setup trustlines for stablecoins
  Future<void> _setupStablecoins(EnhancedWalletProvider walletProvider) async {
    final stablecoins = walletProvider.stablecoins;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Setting up stablecoin trustlines...')),
    );

    final result = await walletProvider.createMultipleTrustlines(stablecoins);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stablecoin trustlines created successfully!'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create trustlines: ${result['error']}'),
        ),
      );
    }
  }

  // Example: Send a stablecoin
  Future<void> _sendStablecoin(EnhancedWalletProvider walletProvider) async {
    final usdcBalance = walletProvider.getAssetBalance(
      'USDC_GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
    );

    if (double.tryParse(usdcBalance) == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No USDC balance to send')));
      return;
    }

    // Show dialog to get recipient address and amount
    _showSendDialog(walletProvider, AssetConfigs.usdc);
  }

  // Example: Check all asset balances
  Future<void> _checkBalances(EnhancedWalletProvider walletProvider) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Refreshing balances...')));

    await walletProvider.refreshWallet();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Balances refreshed!')));
  }

  void _showSendDialog(
    EnhancedWalletProvider walletProvider,
    AssetConfig asset,
  ) {
    final recipientController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send ${asset.symbol}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: recipientController,
              decoration: const InputDecoration(
                labelText: 'Recipient Address',
                hintText: 'G...',
              ),
            ),
            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                hintText: '0.00',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final recipient = recipientController.text.trim();
              final amount = double.tryParse(amountController.text);

              if (recipient.isEmpty || amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid recipient and amount'),
                  ),
                );
                return;
              }

              Navigator.of(context).pop();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sending ${amount} ${asset.symbol}...')),
              );

              final result = await walletProvider.sendAsset(
                recipientAddress: recipient,
                asset: asset,
                amount: amount,
              );

              if (result['success'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${asset.symbol} sent successfully!')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Failed to send ${asset.symbol}: ${result['error']}',
                    ),
                  ),
                );
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}

// Example: Programmatic usage of multi-asset wallet
class MultiAssetWalletProgrammaticExample {
  final EnhancedWalletProvider walletProvider;

  MultiAssetWalletProgrammaticExample(this.walletProvider);

  // Setup wallet with multiple assets
  Future<void> setupMultiAssetWallet() async {
    // 1. Setup basic wallet (XLM + AKOFA)
    await walletProvider.setupWalletWithMultipleAssets([]);

    // 2. Add stablecoin support
    final stablecoins = walletProvider.stablecoins;
    await walletProvider.createMultipleTrustlines(stablecoins);

    // 3. Check balances
    await walletProvider.refreshWallet();
  }

  // Send different types of assets
  Future<void> demonstrateAssetSending() async {
    // Send XLM (native asset)
    await walletProvider.sendXLM(
      recipientAddress: 'GEXAMPLE_RECIPIENT_ADDRESS',
      amount: 10.0,
    );

    // Send AKOFA (custom asset)
    await walletProvider.sendAkofaTokens(
      recipientAddress: 'GEXAMPLE_RECIPIENT_ADDRESS',
      amount: 5.0,
    );

    // Send USDC (stablecoin)
    await walletProvider.sendAsset(
      recipientAddress: 'GEXAMPLE_RECIPIENT_ADDRESS',
      asset: AssetConfigs.usdc,
      amount: 25.0,
    );

    // Send EURC with biometric authentication
    await walletProvider.sendStablecoinWithBiometrics(
      recipientAddress: 'GEXAMPLE_RECIPIENT_ADDRESS',
      stablecoin: AssetConfigs.eurc,
      amount: 15.0,
      memo: 'EURC Transfer',
    );
  }

  // Check asset balances
  void checkAssetBalances() {
    final xlmBalance = walletProvider.getAssetBalance('XLM');
    final akofaBalance = walletProvider.getAssetBalance(
      'AKOFA_GAXGCEV2XGCUORUWQ4B2NTRVLKUVDCOQT2EL5C3GY3X72LFR2G3QKSKW',
    );
    final usdcBalance = walletProvider.getAssetBalance(
      'USDC_GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
    );

    print('XLM Balance: $xlmBalance');
    print('AKOFA Balance: $akofaBalance');
    print('USDC Balance: $usdcBalance');
  }

  // Get asset information
  void demonstrateAssetQueries() {
    final supportedAssets = walletProvider.supportedAssets;
    final stablecoins = walletProvider.stablecoins;

    print('Supported Assets:');
    for (final asset in supportedAssets) {
      print(
        '- ${asset.name} (${asset.symbol}) - ${asset.isStablecoin ? 'Stablecoin' : 'Asset'}',
      );
    }

    print('\nStablecoins:');
    for (final coin in stablecoins) {
      print(
        '- ${coin.name} (${coin.symbol}) - Pegged to: ${coin.peggedCurrency}',
      );
    }
  }
}

// Example: Integration with existing screens
class EnhancedWalletScreenWithMultiAsset extends StatelessWidget {
  const EnhancedWalletScreenWithMultiAsset({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enhanced Multi-Asset Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addNewAsset(context),
          ),
        ],
      ),
      body: const MultiAssetBalanceDisplay(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickActions(context),
        child: const Icon(Icons.flash_on),
      ),
    );
  }

  void _addNewAsset(BuildContext context) {
    // Show dialog to add new asset trustline
    showDialog(context: context, builder: (context) => const AddAssetDialog());
  }

  void _showQuickActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const QuickActionsSheet(),
    );
  }
}

class AddAssetDialog extends StatelessWidget {
  const AddAssetDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Asset'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Enter asset code and issuer to create trustline'),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Asset Code',
              hintText: 'USDC',
            ),
          ),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Issuer Address',
              hintText: 'G...',
            ),
          ),
          const SizedBox(height: 16),
          Consumer<EnhancedWalletProvider>(
            builder: (context, walletProvider, child) {
              return ElevatedButton(
                onPressed: () async {
                  // Create trustline for the new asset
                  // This would be implemented with actual asset data
                  Navigator.of(context).pop();
                },
                child: const Text('Create Trustline'),
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class QuickActionsSheet extends StatelessWidget {
  const QuickActionsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickAction(
                context,
                'Send XLM',
                Icons.send,
                () => _quickSend(context, AssetConfigs.xlm),
              ),
              _buildQuickAction(
                context,
                'Send AKOFA',
                Icons.token,
                () => _quickSend(context, AssetConfigs.akofa),
              ),
              _buildQuickAction(
                context,
                'Send USDC',
                Icons.attach_money,
                () => _quickSend(context, AssetConfigs.usdc),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
          ),
          child: Icon(icon),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  void _quickSend(BuildContext context, AssetConfig asset) {
    Navigator.of(context).pop();
    // Navigate to send screen with pre-selected asset
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Send ${asset.symbol} - Feature coming soon!')),
    );
  }
}
