import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'lib/providers/stellar_provider.dart';
import 'lib/services/blockchain_transaction_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Debug script to test transaction loading
/// Run this to see what's happening with transaction loading
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🔍 DEBUG: Starting transaction loading test...');
  
  // Test 1: Check if user is authenticated
  final user = FirebaseAuth.instance.currentUser;
  print('🔍 DEBUG: Current user: ${user?.uid ?? "Not authenticated"}');
  
  if (user == null) {
    print('❌ DEBUG: No authenticated user - transactions cannot be loaded');
    return;
  }
  
  // Test 2: Try to load transactions directly from blockchain service
  print('🔍 DEBUG: Testing BlockchainTransactionService.getUserTransactionsFromBlockchain()...');
  try {
    final transactions = await BlockchainTransactionService.getUserTransactionsFromBlockchain();
    print('✅ DEBUG: Blockchain service returned ${transactions.length} transactions');
    
    for (int i = 0; i < transactions.length; i++) {
      final tx = transactions[i];
      print('   📋 Transaction $i: ${tx.type} ${tx.amount} ${tx.assetCode} at ${tx.timestamp}');
    }
  } catch (e) {
    print('❌ DEBUG: Error loading transactions from blockchain service: $e');
    print('❌ DEBUG: Error stack trace: ${StackTrace.current}');
  }
  
  // Test 3: Test Stellar connection
  print('🔍 DEBUG: Testing Stellar connection...');
  try {
    final connectionTest = await BlockchainTransactionService.testStellarConnection();
    print('✅ DEBUG: Stellar connection test: $connectionTest');
  } catch (e) {
    print('❌ DEBUG: Stellar connection test failed: $e');
  }
  
  print('🔍 DEBUG: Transaction loading test completed');
}

/// Widget-based debug test
class TransactionDebugWidget extends StatefulWidget {
  const TransactionDebugWidget({Key? key}) : super(key: key);

  @override
  State<TransactionDebugWidget> createState() => _TransactionDebugWidgetState();
}

class _TransactionDebugWidgetState extends State<TransactionDebugWidget> {
  List<String> debugLogs = [];
  bool isLoading = false;

  void _addLog(String message) {
    setState(() {
      debugLogs.add('${DateTime.now().toIso8601String()}: $message');
    });
    print(message);
  }

  Future<void> _testTransactionLoading() async {
    setState(() {
      isLoading = true;
      debugLogs.clear();
    });

    _addLog('🔍 Starting transaction loading test...');

    // Test 1: Check StellarProvider state
    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
    _addLog('🔍 StellarProvider state:');
    _addLog('   - hasWallet: ${stellarProvider.hasWallet}');
    _addLog('   - publicKey: ${stellarProvider.publicKey}');
    _addLog('   - current transactions: ${stellarProvider.transactions.length}');

    // Test 2: Check wallet status
    _addLog('🔍 Checking wallet status...');
    final hasWallet = await stellarProvider.checkWalletStatus();
    _addLog('   - checkWalletStatus result: $hasWallet');
    _addLog('   - publicKey after check: ${stellarProvider.publicKey}');

    if (hasWallet && stellarProvider.publicKey != null) {
      // Test 3: Load transactions
      _addLog('🔍 Loading transactions from blockchain...');
      try {
        await stellarProvider.loadTransactionsFromBlockchain();
        _addLog('✅ Transaction loading completed');
        _addLog('   - Final transaction count: ${stellarProvider.transactions.length}');
        
        for (int i = 0; i < stellarProvider.transactions.length; i++) {
          final tx = stellarProvider.transactions[i];
          _addLog('   📋 Transaction $i: ${tx.type} ${tx.amount} ${tx.assetCode} at ${tx.timestamp}');
        }
      } catch (e) {
        _addLog('❌ Error loading transactions: $e');
      }
    } else {
      _addLog('❌ No wallet or public key available');
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Debug'),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: isLoading ? null : _testTransactionLoading,
              child: isLoading 
                ? const CircularProgressIndicator()
                : const Text('Test Transaction Loading'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Debug Logs:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    debugLogs.join('\n'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
