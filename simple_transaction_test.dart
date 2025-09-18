import 'dart:async';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:http/http.dart' as http;

/// Simple test script to verify Stellar SDK transaction retrieval
/// This can be run independently without Firebase dependencies
void main() async {
  print('🚀 Simple Stellar Transaction Retrieval Test');
  print('=' * 50);

  try {
    // Test 1: Basic SDK Connection
    print('\n📡 TEST 1: Stellar SDK Connection');
    print('-' * 30);

    final sdk = StellarSDK.TESTNET;
    print('🔗 Using Stellar TESTNET');

    // Test connection by trying to get a known account
    // Let's try a simpler approach first - just test network connectivity
    print('🔍 Testing basic network connectivity...');

    try {
      // Try to get a non-existent account - should get a 404 but prove network works
      await sdk.accounts.account('GAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAWHF');
      print('⚠️ Unexpected success with dummy account');
    } catch (e) {
      if (e.toString().contains('404') || e.toString().contains('NOT_FOUND')) {
        print('✅ Network connection successful (404 expected for dummy account)');
      } else {
        print('❌ Network test failed: $e');
        return;
      }
    }

    // Now try with a real account that should exist
    // Using the SDF distribution account
    final testAccount = 'GB6NVEN5HSUBKMYCE5ZOWSK5K23TBWRUQLZY3KNMXUZ3AQ2ESC4MY4AQ';
    print('🔍 Testing with SDF distribution account: $testAccount');

    final account = await sdk.accounts.account(testAccount);
    print('✅ Account found successfully!');
    print('📊 Account ID: ${account.accountId}');
    print('💰 Balances: ${account.balances.length}');

    for (final balance in account.balances) {
      if (balance.assetType == 'native') {
        print('   - XLM: ${balance.balance}');
      } else {
        print('   - ${balance.assetCode}: ${balance.balance}');
      }
    }

    // Test 2: Transaction Retrieval
    print('\n🔄 TEST 2: Transaction Retrieval');
    print('-' * 30);

    print('📡 Fetching recent transactions...');
    final transactions = await sdk.transactions.forAccount(testAccount).limit(5).execute();

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

      // Test 3: Operation Retrieval
      print('\n⚙️ TEST 3: Operation Retrieval');
      print('-' * 30);

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
    }

    // Test 4: Operations for Account
    print('\n📊 TEST 4: Account Operations');
    print('-' * 30);

    print('🔍 Getting recent operations for account...');
    final operations = await sdk.operations.forAccount(testAccount).limit(10).execute();
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
    print('- Total Operations: ${operations.records.length}');
    print('- Payment Operations: $paymentCount');

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
  print('=' * 50);
}
