import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

void main() async {
  final StellarSDK sdk = StellarSDK.TESTNET; // Change to StellarSDK.PUBLIC for mainnet
  final String publicKey = 'GB6HGK7767CBWJZQFCHS2YNXSKZNUJTQRAE54SWNN5QJWPK4WYQLXUGW'; // Replace with a Stellar account

  print('Fetching 10 most recent transactions for account: $publicKey\n');

  try {
    // Step 1: Retrieve recent transactions (last 10)
    Page<TransactionResponse> txPage = await sdk.transactions
        .forAccount(publicKey)
        .order(RequestBuilderOrder.DESC)
        .limit(10)
        .execute();

    if (txPage.records.isEmpty) {
      print('No transactions found.');
      return;
    }

    for (TransactionResponse tx in txPage.records) {
      print('--- Transaction Hash: ${tx.hash} ---');

      // Step 2: Display transaction details (already available from the query)
      print('Ledger: ${tx.ledger}');
      print('Created At (Ledger Close Time): ${tx.createdAt}');
      print('Successful: ${tx.successful}');
      print('Memo: ${tx.memo ?? "None"}');
      print('Source Account (Sender): ${tx.sourceAccount}');
      print('Operations Count: ${tx.operationCount}');

      // Step 3: Retrieve operations for this transaction
      Page<OperationResponse> opsPage = await sdk.operations.forTransaction(tx.hash).execute();

      for (OperationResponse op in opsPage.records) {
        if (op is PaymentOperationResponse) {
          print('Payment Operation:');
          print('  From: ${op.from}');
          print('  To: ${op.to}');
          print('  Asset: ${op.assetCode ?? 'XLM'}');
          print('  Amount: ${op.amount}');
        }
        // You can handle other operation types here if needed
      }

      print('-------------------------------\n');
    }
  } catch (e) {
    print('Error fetching transaction details: $e');
  }
}
