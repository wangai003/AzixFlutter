import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

void main() async {
  print(
    '🚀 Stellar Transaction Test for Account: GB54TILFFB3N3CG4S7ZRLZOENBR564KI43TT5I3MCLLXZEXBHGJFPQCK',
  );
  print('=' * 80);

  final StellarSDK sdk = StellarSDK.TESTNET;
  final String accountId =
      'GB54TILFFB3N3CG4S7ZRLZOENBR564KI43TT5I3MCLLXZEXBHGJFPQCK';

  try {
    print('\n📡 Testing account existence...');
    final account = await sdk.accounts.account(accountId);
    print('✅ Account found successfully!');
    print('📊 Account ID: ${account.accountId}');
    print('💰 Balances:');
    for (var balance in account.balances!) {
      if (balance.assetType == 'native') {
        print('   - XLM: ${balance.balance}');
      } else {
        print(
          '   - ${balance.assetCode}: ${balance.balance} (Issuer: ${balance.assetIssuer})',
        );
      }
    }

    print('\n🔄 Fetching transactions...');
    final Page<TransactionResponse> txPage = await sdk.transactions
        .forAccount(accountId)
        .order(RequestBuilderOrder.DESC)
        .limit(20) // Get up to 20 transactions
        .execute();

    print('✅ Found ${txPage.records.length} transactions');

    if (txPage.records.isNotEmpty) {
      print('\n📋 Transaction Details:');
      print('-' * 80);

      for (int i = 0; i < txPage.records.length; i++) {
        final tx = txPage.records[i];
        print('\n${i + 1}. Transaction Hash: ${tx.hash}');
        print('   📅 Created At: ${tx.createdAt}');
        print('   ✅ Successful: ${tx.successful}');
        print('   💰 Fee: ${tx.feeCharged} stroops');
        print('   📝 Memo: ${tx.memo ?? 'None'}');
        print('   👤 Source Account: ${tx.sourceAccount}');
        print('   🔢 Operation Count: ${tx.operationCount}');

        // Get operations for this transaction
        try {
          final Page<OperationResponse> opsPage = await sdk.operations
              .forTransaction(tx.hash)
              .execute();

          print('   📋 Operations (${opsPage.records.length}):');
          for (final op in opsPage.records) {
            if (op is PaymentOperationResponse) {
              print('     💸 Payment: ${op.amount} ${op.assetCode ?? 'XLM'}');
              print('        From: ${op.from}');
              print('        To: ${op.to}');
            } else if (op is CreateAccountOperationResponse) {
              print('     🆕 Account Creation: ${op.startingBalance} XLM');
              print('        Funder: ${op.funder}');
              print('        New Account: ${op.account}');
            } else if (op is ChangeTrustOperationResponse) {
              print('     🔗 Trustline: ${op.assetCode ?? 'Unknown'}');
              print('        Limit: ${op.limit}');
            } else {
              print('     ⚙️  ${op.runtimeType}');
            }
          }
        } catch (e) {
          print('   ❌ Could not fetch operations: $e');
        }

        print('   ' + '-' * 40);
      }

      print('\n📊 Summary:');
      print('- Total Transactions: ${txPage.records.length}');
      print(
        '- Successful Transactions: ${txPage.records.where((tx) => tx.successful).length}',
      );
      print(
        '- Failed Transactions: ${txPage.records.where((tx) => !tx.successful).length}',
      );
    } else {
      print('\n⚠️  No transactions found for this account');
      print('💡 This could mean:');
      print('   - The account is newly created');
      print('   - All transactions are very old');
      print('   - The account has been merged/removed');
    }

    // Also check operations for the account
    print('\n🔧 Fetching account operations...');
    final Page<OperationResponse> opsPage = await sdk.operations
        .forAccount(accountId)
        .order(RequestBuilderOrder.DESC)
        .limit(10)
        .execute();

    print('✅ Found ${opsPage.records.length} operations for account');

    if (opsPage.records.isNotEmpty) {
      print('\n📋 Recent Operations:');
      for (int i = 0; i < opsPage.records.length; i++) {
        final op = opsPage.records[i];
        print('\n${i + 1}. ${op.runtimeType} at ${op.createdAt}');
        if (op is PaymentOperationResponse) {
          print(
            '   💸 ${op.amount} ${op.assetCode ?? 'XLM'} from ${op.from} to ${op.to}',
          );
        }
      }
    }
  } catch (e) {
    print('❌ Error: $e');
    print('❌ Error type: ${e.runtimeType}');

    if (e.toString().contains('404')) {
      print('💡 Account not found - this could mean:');
      print('   - Wrong account ID');
      print('   - Account doesn\'t exist on testnet');
      print('   - Account was merged or removed');
    } else if (e.toString().contains('SocketException')) {
      print('💡 Network error - check your internet connection');
    }
  }

  print('\n🎉 Test completed!');
  print('=' * 80);
}
