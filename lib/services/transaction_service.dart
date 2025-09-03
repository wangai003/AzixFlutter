import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction.dart';

class TransactionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Record a simple transaction
  static Future<void> recordTransaction({
    required String type,
    required double amount,
    required String assetCode,
    String? memo,
    String? description,
    String? transactionHash,
    String? senderAkofaTag,
    String? recipientAkofaTag,
    String? senderAddress,
    String? recipientAddress,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No authenticated user found');
        return;
      }

      print('📝 Recording transaction: $type for user ${user.uid}');
      print('📝 Amount: $amount $assetCode');

      // Create transaction data
      final transactionData = {
        'userId': user.uid,
        'type': type,
        'status': 'completed',
        'amount': amount,
        'assetCode': assetCode,
        'timestamp': FieldValue.serverTimestamp(),
        'memo': memo,
        'description': description,
        'transactionHash': transactionHash,
        'senderAkofaTag': senderAkofaTag,
        'recipientAkofaTag': recipientAkofaTag,
        'senderAddress': senderAddress,
        'recipientAddress': recipientAddress,
        'metadata': {
          'recordedAt': DateTime.now().toIso8601String(),
          'service': 'transaction_service',
          ...?additionalMetadata,
        },
      };

      // Use Firestore transaction for atomicity
      await _firestore.runTransaction((transaction) async {
        // Create main transaction record
        final newDocRef = _firestore.collection('transactions').doc();
        transaction.set(newDocRef, transactionData);

        // Create user-specific view for fast queries
        final userTransactionRef = _firestore
            .collection('USER')
            .doc(user.uid)
            .collection('transactions')
            .doc(newDocRef.id);

        transaction.set(userTransactionRef, {
          ...transactionData,
          'transactionId': newDocRef.id,
          'userView': true,
        });
      });

      print('✅ Transaction recorded successfully');
    } catch (e) {
      print('❌ Error recording transaction: $e');
      throw Exception('Failed to record transaction: $e');
    }
  }

  // Record a buy Akofa transaction
  static Future<void> recordBuyAkofa({
    required double amount,
    required String paymentMethod,
    required String flutterwaveRef,
    String? stellarHash,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    await recordTransaction(
      type: 'buyAkofa',
      amount: amount,
      assetCode: 'AKOFA',
      description: 'Bought $amount AKOFA via $paymentMethod',
      transactionHash: stellarHash,
      senderAkofaTag: 'Flutterwave',
      recipientAkofaTag: _auth.currentUser?.uid,
      senderAddress: 'Flutterwave',
      recipientAddress: _auth.currentUser?.uid,
      additionalMetadata: {
        'paymentMethod': paymentMethod,
        'flutterwaveRef': flutterwaveRef,
        'transactionType': 'onramp',
        ...?additionalMetadata,
      },
    );
  }

  // Record a mining reward transaction
  static Future<void> recordMiningReward({
    required double amount,
    String? stellarHash,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await recordTransaction(
      type: 'mining',
      amount: amount,
      assetCode: 'AKOFA',
      description: 'Mining reward of $amount AKOFA',
      transactionHash: stellarHash,
      senderAkofaTag: 'SYSTEM',
      recipientAkofaTag: user.uid,
      senderAddress: 'SYSTEM_ISSUER',
      recipientAddress: user.uid,
      additionalMetadata: {
        'rewardType': 'mining',
        'miningSession': 'active',
        ...?additionalMetadata,
      },
    );
  }

  // Record a send transaction
  static Future<void> recordSend({
    required double amount,
    required String assetCode,
    required String recipientAddress,
    String? recipientAkofaTag,
    String? memo,
    String? stellarHash,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await recordTransaction(
      type: 'send',
      amount: amount,
      assetCode: assetCode,
      description: 'Sent $amount $assetCode',
      memo: memo,
      transactionHash: stellarHash,
      senderAkofaTag: user.uid,
      recipientAkofaTag: recipientAkofaTag,
      senderAddress: user.uid,
      recipientAddress: recipientAddress,
      additionalMetadata: {
        'transactionType': 'transfer',
        ...?additionalMetadata,
      },
    );
  }

  // Record a receive transaction
  static Future<void> recordReceive({
    required double amount,
    required String assetCode,
    required String senderAddress,
    String? senderAkofaTag,
    String? memo,
    String? stellarHash,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await recordTransaction(
      type: 'receive',
      amount: amount,
      assetCode: assetCode,
      description: 'Received $amount $assetCode',
      memo: memo,
      transactionHash: stellarHash,
      senderAkofaTag: senderAkofaTag,
      recipientAkofaTag: user.uid,
      senderAddress: senderAddress,
      recipientAddress: user.uid,
      additionalMetadata: {
        'transactionType': 'transfer',
        ...?additionalMetadata,
      },
    );
  }

  // Get user's transaction history
  static Future<List<Transaction>> getUserTransactions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final querySnapshot = await _firestore
          .collection('USER')
          .doc(user.uid)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Transaction.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ Error getting user transactions: $e');
      return [];
    }
  }

  // Get transaction by ID
  static Future<Transaction?> getTransaction(String transactionId) async {
    try {
      final doc = await _firestore
          .collection('transactions')
          .doc(transactionId)
          .get();

      if (doc.exists) {
        return Transaction.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('❌ Error getting transaction: $e');
      return null;
    }
  }

  // Delete a transaction (for cleanup)
  static Future<void> deleteTransaction(String transactionId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.runTransaction((transaction) async {
        // Delete from main collection
        transaction.delete(_firestore.collection('transactions').doc(transactionId));

        // Delete from user collection
        transaction.delete(_firestore
            .collection('USER')
            .doc(user.uid)
            .collection('transactions')
            .doc(transactionId));
      });

      print('✅ Transaction deleted successfully');
    } catch (e) {
      print('❌ Error deleting transaction: $e');
      throw Exception('Failed to delete transaction: $e');
    }
  }

  // Clean up duplicate transactions
  static Future<void> cleanupDuplicateTransactions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print('🧹 Cleaning up duplicate transactions...');

      final querySnapshot = await _firestore
          .collection('USER')
          .doc(user.uid)
          .collection('transactions')
          .get();

      final transactions = querySnapshot.docs;
      final seen = <String>{};
      final duplicates = <String>[];

      for (final doc in transactions) {
        final data = doc.data();
        final key = '${data['type']}_${data['amount']}_${data['timestamp']}';
        
        if (seen.contains(key)) {
          duplicates.add(doc.id);
        } else {
          seen.add(key);
        }
      }

      print('🔍 Found ${duplicates.length} duplicate transactions');

      for (final duplicateId in duplicates) {
        await deleteTransaction(duplicateId);
      }

      print('✅ Cleanup completed');
    } catch (e) {
      print('❌ Error during cleanup: $e');
    }
  }
}
