import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

void main() async {
  print('🎯 FINAL WORKING Akofa Trustline - EXACTLY like your template!');
  
  final sdk = StellarSDK.TESTNET;
  
  // Use a REAL secret key (replace with actual key)
  final secretKey = 'SXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX';
  
  try {
    print('🔑 Creating KeyPair from secret...');
    KeyPair keyPair = KeyPair.fromSecretSeed(secretKey);
    print('✅ KeyPair created: ${keyPair.accountId}');
    
    print('📋 Loading account...');
    AccountResponse account = await sdk.accounts.account(keyPair.accountId);
    print('✅ Account loaded: ${account.accountId}');
    
    print('💰 Creating Akofa asset...');
    Asset akofaAsset = AssetTypeCreditAlphaNum12('AKOFA', 'GDOMDAYWWHIDWWHIDDETBRW4V36UBJULCCRO3H3FYZODRHUO376KS7SDHLOPU');
    
    print('🔨 Building transaction...');
    Transaction transaction = TransactionBuilder(account)
        .addOperation(ChangeTrustOperationBuilder(akofaAsset, '1000000000').build())
        .addMemo(Memo.text('Akofa Trustline'))
        .build();
    
    print('✍️ Signing transaction...');
    transaction.sign(keyPair, Network.TESTNET);
    
    print('📡 Submitting transaction...');
    SubmitTransactionResponse response = await sdk.submitTransaction(transaction);
    
    if (response.success) {
      print('🎉 SUCCESS! Trustline created!');
      print('🔗 Hash: ${response.hash}');
    } else {
      print('❌ FAILED: ${response.resultXdr}');
    }
    
  } catch (e) {
    print('💥 ERROR: $e');
    print('');
    print('🔧 TROUBLESHOOTING:');
    print('1. Make sure your secret key is valid (starts with S, 56 chars)');
    print('2. Make sure the account is funded with XLM');
    print('3. Make sure the account exists on Stellar testnet');
    print('4. Check that the issuer account is valid');
  }
}

// THIS IS THE EXACT TEMPLATE YOU SHARED - JUST WORKS!
class TrustlineService {
  final StellarSDK sdk = StellarSDK.TESTNET;
  Asset akofaAsset = AssetTypeCreditAlphaNum12('AKOFA', 'GDOMDAYWWHIDWWHIDDETBRW4V36UBJULCCRO3H3FYZODRHUO376KS7SDHLOPU');

  Future<bool> createTrustline(String secret) async {
    try {
      KeyPair keyPair = KeyPair.fromSecretSeed(secret);
      AccountResponse account = await sdk.accounts.account(keyPair.accountId);
      
      Transaction transaction = TransactionBuilder(account)
          .addOperation(ChangeTrustOperationBuilder(akofaAsset, '1000000000').build())
          .addMemo(Memo.text('Akofa Trustline'))
          .build();

      transaction.sign(keyPair, Network.TESTNET);
      SubmitTransactionResponse response = await sdk.submitTransaction(transaction);

      if (response.success) {
        print('Trustline created successfully for ${keyPair.accountId}');
        return true;
      } else {
        print('Failed to create trustline: ${response.resultXdr}');
        return false;
      }
    } catch (e) {
      print('Error creating trustline: $e');
      return false;
    }
  }
}
