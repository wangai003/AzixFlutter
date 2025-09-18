import 'dart:async';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:http/http.dart' as http;

/// Test script to create a funded account and test transaction retrieval
void main() async {
  print('🚀 Stellar Friendbot Account Creation & Transaction Test');
  print('=' * 60);

  try {
    final sdk = StellarSDK.TESTNET;
    print('🔗 Using Stellar TESTNET');

    // Step 1: Create and fund an account using Friendbot
    print('\n💰 STEP 1: Creating and funding test account');
    print('-' * 40);

    // Generate a new random keypair
    final keypair = KeyPair.random();
    final publicKey = keypair.accountId;
    final secretKey = keypair.secretSeed;

    print('🔑 Generated new keypair:');
    print('   Public: $publicKey');
    print('   Secret: ${secretKey.substring(0, 10)}...');

    // Fund the account using Friendbot
    print('📡 Funding account with Friendbot...');
    final friendbotUrl = 'https://friendbot.stellar.org/?addr=$publicKey';

    final response = await http.get(Uri.parse(friendbotUrl));

    if (response.statusCode == 200) {
      print('✅ Friendbot funding successful!');

      // Parse the response to get transaction details
      final responseData = response.body;
      print('📄 Friendbot response: ${responseData.substring(0, 100)}...');

      // Wait a moment for the transaction to be processed
      print('⏳ Waiting for transaction to be processed...');
      await Future.delayed(const Duration(seconds: 3));

      // Step 2: Verify the account was funded
      print('\n🔍 STEP 2: Verifying account funding');
      print('-' * 40);

      final account = await sdk.accounts.account(publicKey);
      print('✅ Account found on blockchain!');
      print('📊 Account ID: ${account.accountId}');
      print('💰 Balances: ${account.balances.length}');

      for (final balance in account.balances) {
        if (balance.assetType == 'native') {
          print('   💰 XLM: ${balance.balance}');
        } else {
          print('   🪙 ${balance.assetCode}: ${balance.balance}');
        }
      }

      // Step 3: Test transaction retrieval
      print('\n🔄 STEP 3: Testing transaction retrieval');
      print('-' * 40);

      print('📡 Fetching transactions for the funded account...');
      final transactions = await sdk.transactions.forAccount(publicKey).limit(10).execute();

      print('✅ Found ${transactions.records.length} transactions');

      if (transactions.records.isNotEmpty) {
        print('\n📋 Transaction Details:');
        for (int i = 0; i < transactions.records.length; i++) {
          final tx = transactions.records[i];
          print('${i + 1}. Hash: ${tx.hash}');
          print('   Status: ${tx.successful ? '✅ Success' : '❌ Failed'}');
          print('   Time: ${tx.createdAt}');
          print('   Fee: ${tx.feeCharged} stroops');
          print('   Source: ${tx.sourceAccount}');
          print('');
        }

        // Step 4: Test operation retrieval
        print('\n⚙️ STEP 4: Testing operation retrieval');
        print('-' * 40);

        final firstTx = transactions.records.first;
        print('🔍 Getting operations for transaction: ${firstTx.hash}');

        final operations = await sdk.operations.forTransaction(firstTx.hash).execute();
        print('✅ Found ${operations.records.length} operations');

        for (final op in operations.records) {
          print('📋 Operation ID: ${op.id}');
          print('   Type: ${op.runtimeType}');
          print('   Source: ${op.sourceAccount}');

          if (op is PaymentOperationResponse) {
            print('   💰 Payment: ${op.amount} ${op.assetCode ?? 'XLM'}');
            print('   From: ${op.from}');
            print('   To: ${op.to}');
          }
          print('');
        }
      } else {
        print('⚠️ No transactions found yet - this might be normal for a newly funded account');
      }

      // Step 5: Test operations for account
      print('\n📊 STEP 5: Testing account operations');
      print('-' * 40);

      print('🔍 Getting recent operations for account...');
      final operations = await sdk.operations.forAccount(publicKey).limit(10).execute();
      print('✅ Found ${operations.records.length} operations');

      int paymentCount = 0;
      for (final op in operations.records) {
        if (op is PaymentOperationResponse) {
          paymentCount++;
          print('💰 Payment ${paymentCount}: ${op.amount} ${op.assetCode ?? 'XLM'}');
          print('   From: ${op.from}');
          print('   To: ${op.to}');
          print('   Time: ${op.createdAt ?? 'Unknown'}');
          print('');
        }
      }

      print('📊 Summary:');
      print('- Account funded successfully');
      print('- Total Transactions: ${transactions.records.length}');
      print('- Total Operations: ${operations.records.length}');
      print('- Payment Operations: $paymentCount');

    } else {
      print('❌ Friendbot funding failed!');
      print('📄 Response: ${response.body}');
      print('🔍 Status Code: ${response.statusCode}');
    }

  } catch (e) {
    print('❌ Test failed with error: $e');
    print('❌ Error type: ${e.runtimeType}');

    if (e.toString().contains('SocketException')) {
      print('💡 Network error - check your internet connection');
    } else if (e.toString().contains('404')) {
      print('💡 Account not found - this might be expected for test accounts');
    } else {
      print('💡 Check Stellar testnet status: https://status.stellar.org/');
    }
  }

  print('\n🎉 Test completed!');
  print('=' * 60);
}
