import 'package:cloud_firestore/cloud_firestore.dart';

class PayoutRequest {
  final String id;
  final String vendorId;
  final double amount;
  final String destination; // Stellar address
  final String status; // pending, approved, rejected, paid
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? adminNote;

  PayoutRequest({
    required this.id,
    required this.vendorId,
    required this.amount,
    required this.destination,
    required this.status,
    required this.requestedAt,
    this.processedAt,
    this.adminNote,
  });

  factory PayoutRequest.fromMap(Map<String, dynamic> map, String id) {
    return PayoutRequest(
      id: id,
      vendorId: map['vendorId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      destination: map['destination'] ?? '',
      status: map['status'] ?? 'pending',
      requestedAt: (map['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      processedAt: (map['processedAt'] as Timestamp?)?.toDate(),
      adminNote: map['adminNote'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId,
      'amount': amount,
      'destination': destination,
      'status': status,
      'requestedAt': requestedAt,
      'processedAt': processedAt,
      'adminNote': adminNote,
    };
  }
} 