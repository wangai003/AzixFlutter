import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceOrder {
  final String id;
  final String serviceId;
  final String buyerId;
  final String vendorId;
  final Map<String, dynamic> package;
  final String requirements;
  final String status;
  final double price;
  final List<Map<String, dynamic>>? milestones;
  final List<Map<String, dynamic>>? messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String>? deliveryFiles;
  final String? deliveryMessage;
  final Map<String, dynamic>? review;
  final String? paymentStatus; // e.g., 'pending', 'paid', 'failed'
  final Map<String, dynamic>? paymentDetails;

  ServiceOrder({
    required this.id,
    required this.serviceId,
    required this.buyerId,
    required this.vendorId,
    required this.package,
    required this.requirements,
    required this.status,
    required this.price,
    this.milestones,
    this.messages,
    required this.createdAt,
    required this.updatedAt,
    this.deliveryFiles,
    this.deliveryMessage,
    this.review,
    this.paymentStatus,
    this.paymentDetails,
  });

  factory ServiceOrder.fromJson(Map<String, dynamic> json, String id) {
    return ServiceOrder(
      id: id,
      serviceId: json['serviceId'] ?? '',
      buyerId: json['buyerId'] ?? '',
      vendorId: json['vendorId'] ?? '',
      package: Map<String, dynamic>.from(json['package'] ?? {}),
      requirements: json['requirements'] ?? '',
      status: json['status'] ?? 'pending',
      price: (json['price'] ?? 0).toDouble(),
      milestones: (json['milestones'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList(),
      messages: (json['messages'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList(),
      createdAt: (json['createdAt'] is Timestamp)
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: (json['updatedAt'] is Timestamp)
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      deliveryFiles: (json['deliveryFiles'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      deliveryMessage: json['deliveryMessage'],
      review: json['review'] != null ? Map<String, dynamic>.from(json['review']) : null,
      paymentStatus: json['paymentStatus'],
      paymentDetails: json['paymentDetails'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serviceId': serviceId,
      'buyerId': buyerId,
      'vendorId': vendorId,
      'package': package,
      'requirements': requirements,
      'status': status,
      'price': price,
      'milestones': milestones,
      'messages': messages,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deliveryFiles': deliveryFiles,
      'deliveryMessage': deliveryMessage,
      'review': review,
      'paymentStatus': paymentStatus,
      'paymentDetails': paymentDetails,
    };
  }
} 