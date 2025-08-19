import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType {
  send,
  receive,
  mining
}

enum TransactionStatus {
  pending,
  completed,
  failed
}

class Transaction {
  final String id;
  final String userId;
  final String senderAddress;
  final String recipientAddress;
  final String? senderAkofaTag;
  final String? recipientAkofaTag;
  final double amount;
  final TransactionType type;
  final TransactionStatus status;
  final String? hash;
  final DateTime timestamp;
  final String? memo;
  final String assetCode; // XLM or AKOFA

  Transaction({
    required this.id,
    required this.userId,
    required this.senderAddress,
    required this.recipientAddress,
    this.senderAkofaTag,
    this.recipientAkofaTag,
    required this.amount,
    required this.type,
    required this.status,
    this.hash,
    required this.timestamp,
    this.memo,
    required this.assetCode,
  });

  // Factory constructor to create a Transaction from a Firestore document
  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Handle timestamp conversion safely
    DateTime timestamp;
    try {
      if (data['timestamp'] is Timestamp) {
        timestamp = (data['timestamp'] as Timestamp).toDate();
      } else if (data['timestamp'] is DateTime) {
        timestamp = data['timestamp'] as DateTime;
      } else {
        timestamp = DateTime.now(); // Fallback
      }
    } catch (e) {
      print('Error parsing timestamp for transaction ${doc.id}: $e');
      timestamp = DateTime.now(); // Fallback
    }
    
    return Transaction(
      id: doc.id,
      userId: data['userId'] ?? '',
      senderAddress: data['senderAddress'] ?? '',
      recipientAddress: data['recipientAddress'] ?? '',
      senderAkofaTag: data['senderAkofaTag'],
      recipientAkofaTag: data['recipientAkofaTag'],
      amount: (data['amount'] ?? 0).toDouble(),
      type: _parseTransactionType(data['type']),
      status: _parseTransactionStatus(data['status']),
      hash: data['hash'],
      timestamp: timestamp,
      memo: data['memo'],
      assetCode: data['assetCode'] ?? 'AKOFA',
    );
  }

  // Convert Transaction to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'senderAddress': senderAddress,
      'recipientAddress': recipientAddress,
      'senderAkofaTag': senderAkofaTag,
      'recipientAkofaTag': recipientAkofaTag,
      'amount': amount,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'hash': hash,
      'timestamp': timestamp,
      'memo': memo,
      'assetCode': assetCode,
    };
  }

  // Helper method to parse TransactionType from string
  static TransactionType _parseTransactionType(String? typeStr) {
    if (typeStr == 'send') return TransactionType.send;
    if (typeStr == 'receive') return TransactionType.receive;
    if (typeStr == 'mining') return TransactionType.mining;
    return TransactionType.receive; // Default
  }

  // Helper method to parse TransactionStatus from string
  static TransactionStatus _parseTransactionStatus(String? statusStr) {
    if (statusStr == 'pending') return TransactionStatus.pending;
    if (statusStr == 'completed') return TransactionStatus.completed;
    if (statusStr == 'failed') return TransactionStatus.failed;
    return TransactionStatus.pending; // Default
  }

  // Get a human-readable description of the transaction
  String get description {
    switch (type) {
      case TransactionType.send:
        return 'Sent $amount $assetCode';
      case TransactionType.receive:
        return 'Received $amount $assetCode';
      case TransactionType.mining:
        return 'Mined $amount $assetCode';
    }
  }

  // Get a color based on the transaction type
  // Note: This is just a placeholder, you'll need to implement this in your UI
  String get typeLabel {
    switch (type) {
      case TransactionType.send:
        return 'Sent';
      case TransactionType.receive:
        return 'Received';
      case TransactionType.mining:
        return 'Mining Reward';
    }
  }

  // Get a status label
  String get statusLabel {
    switch (status) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.failed:
        return 'Failed';
    }
  }

  // Convert transaction to map for compatibility
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'senderAddress': senderAddress,
      'recipientAddress': recipientAddress,
      'senderAkofaTag': senderAkofaTag,
      'recipientAkofaTag': recipientAkofaTag,
      'amount': amount,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'hash': hash,
      'timestamp': timestamp.toIso8601String(),
      'memo': memo,
      'assetCode': assetCode,
    };
  }
}