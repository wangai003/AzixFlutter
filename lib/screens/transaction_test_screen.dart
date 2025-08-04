import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class TransactionTestScreen extends StatefulWidget {
  const TransactionTestScreen({Key? key}) : super(key: key);

  @override
  State<TransactionTestScreen> createState() => _TransactionTestScreenState();
}

class _TransactionTestScreenState extends State<TransactionTestScreen> {
  final List<String> _testResults = [];
  bool _isRunningTests = false;

  // Test script to verify transaction recording
  Future<void> testSendReceiveTransaction() async {
    _addResult('🧪 Testing Send/Receive Transaction Recording...');
    
    try {
      // Get recent transactions
      final transactions = await FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      _addResult('📊 Found ${transactions.docs.length} recent transactions');
      
      // Group transactions by hash to find pairs
      Map<String, List<Map<String, dynamic>>> transactionPairs = {};
      
      for (var doc in transactions.docs) {
        final data = doc.data();
        final hash = data['hash'];
        if (hash != null) {
          if (!transactionPairs.containsKey(hash)) {
            transactionPairs[hash] = [];
          }
          transactionPairs[hash]!.add({
            'id': doc.id,
            'userId': data['userId'],
            'type': data['type'],
            'amount': data['amount'],
            'senderAddress': data['senderAddress'],
            'recipientAddress': data['recipientAddress'],
            'memo': data['memo'],
            'assetCode': data['assetCode'],
          });
        }
      }

      // Check for proper send/receive pairs
      for (var hash in transactionPairs.keys) {
        final transactions = transactionPairs[hash]!;
        if (transactions.length >= 2) {
          _addResult('✅ Found transaction pair for hash: ${hash.substring(0, 8)}...');
          _addResult('   Transactions: ${transactions.length}');
          
          bool hasSend = false;
          bool hasReceive = false;
          
          for (var tx in transactions) {
            _addResult('   - User: ${tx['userId'].substring(0, 8)}... | Type: ${tx['type']} | Amount: ${tx['amount']} ${tx['assetCode']}');
            if (tx['type'] == 'send') hasSend = true;
            if (tx['type'] == 'receive') hasReceive = true;
          }
          
          if (hasSend && hasReceive) {
            _addResult('   ✅ Proper send/receive pair found!');
          } else {
            _addResult('   ❌ Missing send or receive transaction');
          }
        } else if (transactions.length == 1) {
          final tx = transactions.first;
          if (tx['type'] == 'mining') {
            _addResult('✅ Mining reward transaction (single): ${tx['amount']} ${tx['assetCode']}');
          } else {
            _addResult('⚠️  Single transaction found (might be missing pair): ${tx['type']}');
          }
        }
      }
      
    } catch (e) {
      _addResult('❌ Error testing send/receive transactions: $e');
    }
  }

  Future<void> testMiningRewardRecording() async {
    _addResult('\n🧪 Testing Mining Reward Recording...');
    
    try {
      final miningTransactions = await FirebaseFirestore.instance
          .collection('transactions')
          .where('type', isEqualTo: 'mining')
          .where('memo', isEqualTo: 'Mining Reward')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      _addResult('📊 Found ${miningTransactions.docs.length} mining reward transactions');
      
      for (var doc in miningTransactions.docs) {
        final data = doc.data();
        _addResult('✅ Mining Reward: ${data['amount']} ${data['assetCode']} to user ${data['userId'].substring(0, 8)}...');
        _addResult('   Hash: ${data['hash']?.substring(0, 8) ?? 'No hash'}...');
        _addResult('   Status: ${data['status']}');
      }
      
    } catch (e) {
      _addResult('❌ Error testing mining rewards: $e');
    }
  }

  Future<void> testReferralRewardRecording() async {
    _addResult('\n🧪 Testing Referral Reward Recording...');
    
    try {
      final referralTransactions = await FirebaseFirestore.instance
          .collection('transactions')
          .where('memo', isEqualTo: 'Referral Reward')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      _addResult('📊 Found ${referralTransactions.docs.length} referral reward transactions');
      
      for (var doc in referralTransactions.docs) {
        final data = doc.data();
        _addResult('✅ Referral Reward: ${data['amount']} ${data['assetCode']} to user ${data['userId'].substring(0, 8)}...');
        _addResult('   Sender: ${data['senderAddress']}');
        _addResult('   Recipient: ${data['recipientAddress']}');
        _addResult('   Status: ${data['status']}');
      }
      
    } catch (e) {
      _addResult('❌ Error testing referral rewards: $e');
    }
  }

  Future<void> testForDuplicates() async {
    _addResult('\n🧪 Testing for Transaction Duplicates...');
    
    try {
      final recentTransactions = await FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      Map<String, int> hashCounts = {};
      
      for (var doc in recentTransactions.docs) {
        final data = doc.data();
        final hash = data['hash'];
        if (hash != null) {
          hashCounts[hash] = (hashCounts[hash] ?? 0) + 1;
        }
      }

      bool foundDuplicates = false;
      for (var entry in hashCounts.entries) {
        if (entry.value > 2) { // More than 2 transactions with same hash
          _addResult('❌ Duplicate transactions found for hash: ${entry.key.substring(0, 8)}... (${entry.value} times)');
          foundDuplicates = true;
        }
      }

      if (!foundDuplicates) {
        _addResult('✅ No duplicate transactions found');
      }
      
    } catch (e) {
      _addResult('❌ Error checking for duplicates: $e');
    }
  }

  Future<void> testTransactionStructure() async {
    _addResult('\n🧪 Testing Transaction Structure...');
    
    try {
      final recentTransactions = await FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      _addResult('📊 Checking structure of ${recentTransactions.docs.length} recent transactions');
      
      for (var doc in recentTransactions.docs) {
        final data = doc.data();
        _addResult('Transaction ID: ${doc.id}');
        _addResult('  - User ID: ${data['userId']?.substring(0, 8) ?? 'MISSING'}...');
        _addResult('  - Type: ${data['type'] ?? 'MISSING'}');
        _addResult('  - Amount: ${data['amount'] ?? 'MISSING'}');
        _addResult('  - Asset: ${data['assetCode'] ?? 'MISSING'}');
        _addResult('  - Sender: ${data['senderAddress'] ?? 'MISSING'}');
        _addResult('  - Recipient: ${data['recipientAddress'] ?? 'MISSING'}');
        _addResult('  - Hash: ${data['hash']?.substring(0, 8) ?? 'MISSING'}...');
        _addResult('  - Memo: ${data['memo'] ?? 'MISSING'}');
        _addResult('  - Status: ${data['status'] ?? 'MISSING'}');
        _addResult('  - Timestamp: ${data['timestamp'] != null ? 'PRESENT' : 'MISSING'}');
        _addResult('');
      }
      
    } catch (e) {
      _addResult('❌ Error testing transaction structure: $e');
    }
  }

  // Run all tests
  Future<void> runAllTests() async {
    setState(() {
      _isRunningTests = true;
      _testResults.clear();
    });

    _addResult('🚀 Starting Transaction Recording Tests...\n');
    
    await testSendReceiveTransaction();
    await testMiningRewardRecording();
    await testReferralRewardRecording();
    await testForDuplicates();
    await testTransactionStructure();
    
    _addResult('\n✅ All tests completed!');
    
    setState(() {
      _isRunningTests = false;
    });
  }

  void _addResult(String result) {
    setState(() {
      _testResults.add(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: const Text('Transaction Tests'),
        foregroundColor: AppTheme.primaryGold,
      ),
      body: Column(
        children: [
          // Test Controls
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRunningTests ? null : runAllTests,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: AppTheme.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isRunningTests
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.black),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Running Tests...'),
                            ],
                          )
                        : const Text('Run All Tests'),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _testResults.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          
          // Test Results
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.darkGrey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.grey.withOpacity(0.3)),
              ),
              child: _testResults.isEmpty
                  ? Center(
                      child: Text(
                        'No test results yet.\nTap "Run All Tests" to start.',
                        style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _testResults.length,
                      itemBuilder: (context, index) {
                        final result = _testResults[index];
                        Color textColor = AppTheme.white;
                        
                        if (result.contains('✅')) {
                          textColor = Colors.green;
                        } else if (result.contains('❌')) {
                          textColor = Colors.red;
                        } else if (result.contains('⚠️')) {
                          textColor = Colors.orange;
                        } else if (result.contains('🧪') || result.contains('📊')) {
                          textColor = AppTheme.primaryGold;
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            result,
                            style: AppTheme.bodySmall.copyWith(
                              color: textColor,
                              fontFamily: result.startsWith('   ') ? 'Monospace' : null,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
} 