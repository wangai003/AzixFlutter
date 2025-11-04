import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { send, receive, buyAkofa, swap, funding, withdrawal }

enum TransactionStatus { pending, processing, completed, failed, cancelled }

class Transaction {
  // Core fields
  final String id;
  final String userId;
  final String type;
  final String status;
  final double amount;
  final String assetCode;
  final DateTime timestamp;

  // Transaction details
  final String? memo;
  final String? description;
  final String? transactionHash;

  // User identification
  final String? senderAkofaTag;
  final String? recipientAkofaTag;
  final String? senderAddress;
  final String? recipientAddress;

  // Additional metadata
  final Map<String, dynamic> metadata;

  Transaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.amount,
    required this.assetCode,
    required this.timestamp,
    this.memo,
    this.description,
    this.transactionHash,
    this.senderAkofaTag,
    this.recipientAkofaTag,
    this.senderAddress,
    this.recipientAddress,
    this.metadata = const {},
  });

  // Factory constructor from Firestore
  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Transaction(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] ?? '',
      status: data['status'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      assetCode: data['assetCode'] ?? '',
      timestamp: data['timestamp'] is Timestamp
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      memo: data['memo'],
      description: data['description'],
      transactionHash: data['transactionHash'],
      senderAkofaTag: data['senderAkofaTag'],
      recipientAkofaTag: data['recipientAkofaTag'],
      senderAddress: data['senderAddress'],
      recipientAddress: data['recipientAddress'],
      metadata: data['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type,
      'status': status,
      'amount': amount,
      'assetCode': assetCode,
      'timestamp': timestamp,
      'memo': memo,
      'description': description,
      'transactionHash': transactionHash,
      'senderAkofaTag': senderAkofaTag,
      'recipientAkofaTag': recipientAkofaTag,
      'senderAddress': senderAddress,
      'recipientAddress': recipientAddress,
      'metadata': metadata,
    };
  }

  // Helper getters
  bool get isIncoming => type == 'receive' || type == 'buyAkofa';
  bool get isOutgoing => type == 'send' || type == 'withdrawal';

  String get typeLabel {
    switch (type) {
      case 'send':
        return 'Sent';
      case 'receive':
        return 'Received';
      case 'buyAkofa':
        return 'Bought';
      case 'swap':
        return 'Swapped';
      case 'funding':
        return 'Funded';
      case 'withdrawal':
        return 'Withdrew';
      default:
        return type;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String get otherPartyAkofaTag {
    if (isIncoming) {
      return senderAkofaTag ?? 'Unknown';
    } else {
      return recipientAkofaTag ?? 'Unknown';
    }
  }

  String get direction {
    if (isIncoming) return 'Incoming';
    if (isOutgoing) return 'Outgoing';
    return 'Unknown';
  }

  // Convert to map for compatibility
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'status': status,
      'amount': amount,
      'assetCode': assetCode,
      'timestamp': timestamp.toIso8601String(),
      'memo': memo,
      'description': description,
      'transactionHash': transactionHash,
      'senderAkofaTag': senderAkofaTag,
      'recipientAkofaTag': recipientAkofaTag,
      'senderAddress': senderAddress,
      'recipientAddress': recipientAddress,
      'metadata': metadata,
      'isIncoming': isIncoming,
      'isOutgoing': isOutgoing,
      'typeLabel': typeLabel,
      'statusLabel': statusLabel,
      'otherPartyAkofaTag': otherPartyAkofaTag,
      'direction': direction,
    };
  }
}
