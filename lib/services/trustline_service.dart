import 'package:flutter/material.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

/// Trustline Service following the provided template pattern
class TrustlineService {
  final StellarSDK sdk = StellarSDK.TESTNET; // Use StellarSDK.PUBLIC for mainnet

  // The asset you want to trust (Akofa Coin)
  Asset akofaAsset = AssetTypeCreditAlphaNum4('AKOFA', 'GDOMDAYWWHIDWWHIDDETBRW4V36UBJULCCRO3H3FYZODRHUO376KS7SDHLOPU');
  // Replace with actual Akofa issuer public key

  /// Create trustline for a given user wallet secret
  Future<bool> createTrustline(String secret) async {
    try {
      KeyPair keyPair = KeyPair.fromSecretSeed(secret);

      // Load account details
      AccountResponse account = await sdk.accounts.account(keyPair.accountId);

      // Build transaction to create trustline
      Transaction transaction = TransactionBuilder(account)
          .addOperation(ChangeTrustOperationBuilder(akofaAsset, '1000000000').build())
          .addMemo(Memo.text('Akofa Trustline'))
          .build();

      // Sign transaction
      transaction.sign(keyPair, Network.TESTNET); // Use Network.PUBLIC for mainnet

      // Submit transaction
      SubmitTransactionResponse response = await sdk.submitTransaction(transaction);

      if (response.success) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Check if account already has Akofa trustline
  Future<bool> hasAkofaTrustline(String publicKey) async {
    try {
      AccountResponse account = await sdk.accounts.account(publicKey);
      return account.balances.any((b) =>
        b.assetCode == 'AKOFA' && b.assetType != 'native'
      );
    } catch (e) {
      return false;
    }
  }

  /// Get Akofa balance for an account
  Future<String> getAkofaBalance(String publicKey) async {
    try {
      AccountResponse account = await sdk.accounts.account(publicKey);
      final akofaBalance = account.balances.firstWhere(
        (b) => b.assetCode == 'AKOFA' && b.assetType != 'native',
        orElse: () => throw Exception('AKOFA trustline not found')
      );
      return akofaBalance.balance;
    } catch (e) {
      return '0';
    }
  }
}

// Example Flutter Widget
class TrustlineScreen extends StatefulWidget {
  @override
  _TrustlineScreenState createState() => _TrustlineScreenState();
}

class _TrustlineScreenState extends State<TrustlineScreen> {
  final TrustlineService trustlineService = TrustlineService();
  final TextEditingController _secretController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Akofa Trustline')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _secretController,
              decoration: InputDecoration(labelText: 'Enter wallet secret'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                bool success = await trustlineService.createTrustline(_secretController.text.trim());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Trustline Created ✅' : 'Failed ❌'),
                  ),
                );
              },
              child: Text('Create Trustline'),
            ),
          ],
        ),
      ),
    );
  }
}
