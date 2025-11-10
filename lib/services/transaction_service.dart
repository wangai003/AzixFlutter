import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction.dart';
import 'akofa_tag_service.dart';

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
        return;
      }

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
    } catch (e) {
      throw Exception('Failed to record transaction: $e');
    }
  }

  // Record a buy Akofa transaction
  static Future<void> recordBuyAkofa({
    required double amount,
    required String paymentMethod,
    required String paymentRef,
    String? stellarHash,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Resolve recipient's Akofa tag
    String? recipientAkofaTag;
    String? recipientAddress;
    try {
      final tagResult = await AkofaTagService.getUserTag(user.uid);
      if (tagResult['success']) {
        recipientAkofaTag = tagResult['tag'];
        recipientAddress = tagResult['publicKey'];
      }
    } catch (e) {
      // If tag resolution fails, use user ID as fallback
      recipientAkofaTag = user.uid;
      recipientAddress = user.uid;
    }

    await recordTransaction(
      type: 'buyAkofa',
      amount: amount,
      assetCode: 'AKOFA',
      description: 'Bought $amount AKOFA via $paymentMethod',
      transactionHash: stellarHash,
      senderAkofaTag: 'PaymentProvider',
      recipientAkofaTag: recipientAkofaTag,
      senderAddress: 'PaymentProvider',
      recipientAddress: recipientAddress,
      additionalMetadata: {
        'paymentMethod': paymentMethod,
        'paymentRef': paymentRef,
        'transactionType': 'onramp',
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

    // Resolve sender's Akofa tag and address
    String? senderAkofaTag;
    String? senderAddress;
    try {
      final tagResult = await AkofaTagService.getUserTag(user.uid);
      if (tagResult['success']) {
        senderAkofaTag = tagResult['tag'];
        senderAddress = tagResult['publicKey'];
      }
    } catch (e) {
      // If tag resolution fails, use user ID as fallback
      senderAkofaTag = user.uid;
      senderAddress = user.uid;
    }

    // Resolve recipient's Akofa tag and address if not provided
    String? resolvedRecipientAddress = recipientAddress;
    if (recipientAkofaTag != null && recipientAkofaTag.isNotEmpty) {
      // If recipient tag is provided, resolve it to address
      try {
        final tagResult = await AkofaTagService.resolveTag(
          recipientAkofaTag,
          blockchain: 'stellar',
        );
        if (tagResult['success']) {
          resolvedRecipientAddress = tagResult['publicKey'];
        }
      } catch (e) {
        // Keep original recipientAddress if resolution fails
      }
    } else {
      // If no recipient tag provided, try to resolve tag from address
      try {
        final recipientTagResult = await AkofaTagService.resolveTagByAddress(
          recipientAddress,
        );
        if (recipientTagResult['success'] == true) {
          recipientAkofaTag = recipientTagResult['tag'];
        }
      } catch (e) {
        // Keep recipientAkofaTag as null if resolution fails
      }
    }

    await recordTransaction(
      type: 'send',
      amount: amount,
      assetCode: assetCode,
      description: 'Sent $amount $assetCode',
      memo: memo,
      transactionHash: stellarHash,
      senderAkofaTag: senderAkofaTag,
      recipientAkofaTag: recipientAkofaTag,
      senderAddress: senderAddress,
      recipientAddress: resolvedRecipientAddress,
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

    // Resolve recipient's Akofa tag and address
    String? recipientAkofaTag;
    String? recipientAddress;
    try {
      final tagResult = await AkofaTagService.getUserTag(user.uid);
      if (tagResult['success']) {
        recipientAkofaTag = tagResult['tag'];
        recipientAddress = tagResult['publicKey'];
      }
    } catch (e) {
      // If tag resolution fails, use user ID as fallback
      recipientAkofaTag = user.uid;
      recipientAddress = user.uid;
    }

    // Resolve sender's Akofa tag and address if not provided
    String? resolvedSenderAddress = senderAddress;
    if (senderAkofaTag != null && senderAkofaTag.isNotEmpty) {
      // If sender tag is provided, resolve it to address
      try {
        final tagResult = await AkofaTagService.resolveTag(
          senderAkofaTag,
          blockchain: 'stellar',
        );
        if (tagResult['success']) {
          resolvedSenderAddress = tagResult['publicKey'];
        }
      } catch (e) {
        // Keep original senderAddress if resolution fails
      }
    } else {
      // If no sender tag provided, try to resolve tag from address
      try {
        final senderTagResult = await AkofaTagService.resolveTagByAddress(
          senderAddress,
        );
        if (senderTagResult['success'] == true) {
          senderAkofaTag = senderTagResult['tag'];
        }
      } catch (e) {
        // Keep senderAkofaTag as null if resolution fails
      }
    }

    await recordTransaction(
      type: 'receive',
      amount: amount,
      assetCode: assetCode,
      description: 'Received $amount $assetCode',
      memo: memo,
      transactionHash: stellarHash,
      senderAkofaTag: senderAkofaTag,
      recipientAkofaTag: recipientAkofaTag,
      senderAddress: resolvedSenderAddress,
      recipientAddress: recipientAddress,
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
        transaction.delete(
          _firestore.collection('transactions').doc(transactionId),
        );

        // Delete from user collection
        transaction.delete(
          _firestore
              .collection('USER')
              .doc(user.uid)
              .collection('transactions')
              .doc(transactionId),
        );
      });
    } catch (e) {
      throw Exception('Failed to delete transaction: $e');
    }
  }

  // Clean up duplicate transactions
  static Future<void> cleanupDuplicateTransactions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

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

      for (final duplicateId in duplicates) {
        await deleteTransaction(duplicateId);
      }
    } catch (e) {}
  }
}
