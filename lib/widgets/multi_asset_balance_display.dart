import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/enhanced_wallet_provider.dart';
import '../models/asset_config.dart';

class MultiAssetBalanceDisplay extends StatelessWidget {
  const MultiAssetBalanceDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedWalletProvider>(
      builder: (context, walletProvider, child) {
        if (walletProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final supportedAssets = walletProvider.supportedAssets;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Multi-Asset Wallet',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              height: 400, // Fixed height to prevent unbounded constraints
              child: ListView.builder(
                shrinkWrap: true, // Size the list based on content
                physics: const BouncingScrollPhysics(),
                itemCount: supportedAssets.length,
                itemBuilder: (context, index) {
                  final asset = supportedAssets[index];
                  final balance = walletProvider.getAssetBalance(asset.assetId);

                  return AssetBalanceCard(
                    asset: asset,
                    balance: balance,
                    onTap: () =>
                        _showAssetActions(context, asset, walletProvider),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAssetActions(
    BuildContext context,
    AssetConfig asset,
    EnhancedWalletProvider walletProvider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow full height control
      backgroundColor: Colors.transparent, // Remove default background
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: AssetActionsSheet(asset: asset, walletProvider: walletProvider),
      ),
    );
  }
}

class AssetBalanceCard extends StatelessWidget {
  final AssetConfig asset;
  final String balance;
  final VoidCallback onTap;

  const AssetBalanceCard({
    super.key,
    required this.asset,
    required this.balance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: asset.displayColor,
          child: Text(
            asset.symbol.substring(0, 1),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          asset.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${asset.symbol} • ${asset.isStablecoin ? 'Stablecoin' : 'Asset'}',
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: SizedBox(
          width: 100, // Fixed width to prevent overflow
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min, // Minimize height
            children: [
              Flexible(
                child: Text(
                  balance,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (asset.isStablecoin)
                Flexible(
                  child: Text(
                    asset.peggedCurrency ?? '',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class AssetActionsSheet extends StatelessWidget {
  final AssetConfig asset;
  final EnhancedWalletProvider walletProvider;

  const AssetActionsSheet({
    super.key,
    required this.asset,
    required this.walletProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      constraints: const BoxConstraints(
        maxHeight: 300, // Limit height to prevent overflow
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${asset.name} Actions',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  context,
                  'Send',
                  Icons.send,
                  () => _sendAsset(context),
                ),
                _buildActionButton(
                  context,
                  'Receive',
                  Icons.qr_code,
                  () => _receiveAsset(context),
                ),
                if (!asset.isNative)
                  _buildActionButton(
                    context,
                    'Trustline',
                    Icons.link,
                    () => _manageTrustline(context),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
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

  void _sendAsset(BuildContext context) {
    Navigator.of(context).pop();
    // Navigate to send screen with selected asset
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Send ${asset.symbol} - Feature coming soon!')),
    );
  }

  void _receiveAsset(BuildContext context) {
    Navigator.of(context).pop();
    // Show QR code for receiving asset
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Receive ${asset.symbol} - Feature coming soon!')),
    );
  }

  void _manageTrustline(BuildContext context) async {
    Navigator.of(context).pop();

    final hasTrustline = await walletProvider.hasTrustlineForAsset(asset);

    if (hasTrustline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${asset.symbol} trustline already exists')),
      );
    } else {
      // Create trustline
      final result = await walletProvider.createMultipleTrustlines([asset]);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${asset.symbol} trustline created successfully'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create ${asset.symbol} trustline')),
        );
      }
    }
  }
}
