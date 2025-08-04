import 'package:cloud_firestore/cloud_firestore.dart';

// Test script to verify transaction recording
class TransactionRecordingTest {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Test 1: Verify send/receive transaction recording
  Future<void> testSendReceiveTransaction() async {
    print('🧪 Testing Send/Receive Transaction Recording...');
    
    try {
      // Get recent transactions
      final transactions = await _firestore
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      print('📊 Found ${transactions.docs.length} recent transactions');
      
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
          print('✅ Found transaction pair for hash: $hash');
          print('   Transactions: ${transactions.length}');
          
          bool hasSend = false;
          bool hasReceive = false;
          
          for (var tx in transactions) {
            print('   - User: ${tx['userId']} | Type: ${tx['type']} | Amount: ${tx['amount']} ${tx['assetCode']}');
            if (tx['type'] == 'send') hasSend = true;
            if (tx['type'] == 'receive') hasReceive = true;
          }
          
          if (hasSend && hasReceive) {
            print('   ✅ Proper send/receive pair found!');
          } else {
            print('   ❌ Missing send or receive transaction');
          }
        } else if (transactions.length == 1) {
          final tx = transactions.first;
          if (tx['type'] == 'mining') {
            print('✅ Mining reward transaction (single): ${tx['amount']} ${tx['assetCode']}');
          } else {
            print('⚠️  Single transaction found (might be missing pair): ${tx['type']}');
          }
        }
      }
      
    } catch (e) {
      print('❌ Error testing send/receive transactions: $e');
    }
  }

  // Test 2: Verify mining reward recording
  Future<void> testMiningRewardRecording() async {
    print('\n🧪 Testing Mining Reward Recording...');
    
    try {
      final miningTransactions = await _firestore
          .collection('transactions')
          .where('type', isEqualTo: 'mining')
          .where('memo', isEqualTo: 'Mining Reward')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      print('📊 Found ${miningTransactions.docs.length} mining reward transactions');
      
      for (var doc in miningTransactions.docs) {
        final data = doc.data();
        print('✅ Mining Reward: ${data['amount']} ${data['assetCode']} to user ${data['userId']}');
        print('   Hash: ${data['hash'] ?? 'No hash'}');
        print('   Status: ${data['status']}');
      }
      
    } catch (e) {
      print('❌ Error testing mining rewards: $e');
    }
  }

  // Test 3: Verify referral reward recording
  Future<void> testReferralRewardRecording() async {
    print('\n🧪 Testing Referral Reward Recording...');
    
    try {
      final referralTransactions = await _firestore
          .collection('transactions')
          .where('memo', isEqualTo: 'Referral Reward')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      print('📊 Found ${referralTransactions.docs.length} referral reward transactions');
      
      for (var doc in referralTransactions.docs) {
        final data = doc.data();
        print('✅ Referral Reward: ${data['amount']} ${data['assetCode']} to user ${data['userId']}');
        print('   Sender: ${data['senderAddress']}');
        print('   Recipient: ${data['recipientAddress']}');
        print('   Status: ${data['status']}');
      }
      
    } catch (e) {
      print('❌ Error testing referral rewards: $e');
    }
  }

  // Test 4: Check for transaction duplicates
  Future<void> testForDuplicates() async {
    print('\n🧪 Testing for Transaction Duplicates...');
    
    try {
      final recentTransactions = await _firestore
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
          print('❌ Duplicate transactions found for hash: ${entry.key} (${entry.value} times)');
          foundDuplicates = true;
        }
      }

      if (!foundDuplicates) {
        print('✅ No duplicate transactions found');
      }
      
    } catch (e) {
      print('❌ Error checking for duplicates: $e');
    }
  }

  // Run all tests
  Future<void> runAllTests() async {
    print('🚀 Starting Transaction Recording Tests...\n');
    
    await testSendReceiveTransaction();
    await testMiningRewardRecording();
    await testReferralRewardRecording();
    await testForDuplicates();
    
    print('\n✅ All tests completed!');
  }
}

// Usage example:
// void main() async {
//   final test = TransactionRecordingTest();
//   await test.runAllTests();
// } 