import 'package:cloud_firestore/cloud_firestore.dart';

/// Comprehensive order model for marketplace products
class Order {
  final String id;
  final String buyerId;
  final List<OrderItem> items;
  final OrderShippingInfo shippingInfo;
  final double totalAmount;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final String paymentMethod;
  final Map<String, dynamic>? paymentResults;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? paidAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final String? trackingNumber;
  final List<OrderEvent> events;
  final OrderRating? rating;

  Order({
    required this.id,
    required this.buyerId,
    required this.items,
    required this.shippingInfo,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    this.paymentResults,
    required this.createdAt,
    required this.updatedAt,
    this.paidAt,
    this.shippedAt,
    this.deliveredAt,
    this.trackingNumber,
    this.events = const [],
    this.rating,
  });

  factory Order.fromFirestore(String id, Map<String, dynamic> data) {
    return Order(
      id: id,
      buyerId: data['buyerId'] ?? '',
      items: (data['items'] as List<dynamic>? ?? [])
          .map((item) => OrderItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      shippingInfo: OrderShippingInfo.fromMap(
        Map<String, dynamic>.from(data['shippingInfo'] ?? {}),
      ),
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      status: OrderStatusExtension.fromString(data['status'] ?? 'pending'),
      paymentStatus: PaymentStatusExtension.fromString(data['paymentStatus'] ?? 'pending'),
      paymentMethod: data['paymentMethod'] ?? '',
      paymentResults: data['paymentResults'] != null 
          ? Map<String, dynamic>.from(data['paymentResults'])
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
      shippedAt: (data['shippedAt'] as Timestamp?)?.toDate(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      trackingNumber: data['trackingNumber'],
      events: (data['events'] as List<dynamic>? ?? [])
          .map((event) => OrderEvent.fromMap(Map<String, dynamic>.from(event)))
          .toList(),
      rating: data['rating'] != null 
          ? OrderRating.fromMap(Map<String, dynamic>.from(data['rating']))
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'buyerId': buyerId,
      'items': items.map((item) => item.toMap()).toList(),
      'shippingInfo': shippingInfo.toMap(),
      'totalAmount': totalAmount,
      'status': status.toString(),
      'paymentStatus': paymentStatus.toString(),
      'paymentMethod': paymentMethod,
      'paymentResults': paymentResults,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'paidAt': paidAt,
      'shippedAt': shippedAt,
      'deliveredAt': deliveredAt,
      'trackingNumber': trackingNumber,
      'events': events.map((event) => event.toMap()).toList(),
      'rating': rating?.toMap(),
    };
  }

  /// Get all vendor IDs involved in this order
  List<String> get vendorIds => items.map((item) => item.vendorId).toSet().toList();

  /// Get items for a specific vendor
  List<OrderItem> getItemsForVendor(String vendorId) {
    return items.where((item) => item.vendorId == vendorId).toList();
  }

  /// Get subtotal for a specific vendor
  double getSubtotalForVendor(String vendorId) {
    return getItemsForVendor(vendorId)
        .fold(0.0, (sum, item) => sum + item.subtotal);
  }

  /// Check if order can be cancelled
  bool get canBeCancelled {
    return status == OrderStatus.pending || 
           status == OrderStatus.confirmed ||
           (status == OrderStatus.processing && shippedAt == null);
  }

  /// Check if order can be shipped
  bool get canBeShipped {
    return status == OrderStatus.processing && 
           paymentStatus == PaymentStatus.paid &&
           shippedAt == null;
  }

  /// Check if order can be delivered
  bool get canBeDelivered {
    return status == OrderStatus.shipped && deliveredAt == null;
  }

  /// Get order progress percentage
  double get progressPercentage {
    switch (status) {
      case OrderStatus.pending:
        return 0.1;
      case OrderStatus.confirmed:
        return 0.25;
      case OrderStatus.processing:
        return 0.5;
      case OrderStatus.shipped:
        return 0.75;
      case OrderStatus.delivered:
        return 1.0;
      case OrderStatus.cancelled:
        return 0.0;
      case OrderStatus.refunded:
        return 0.0;
    }
  }
}

/// Individual item in an order
class OrderItem {
  final String productId;
  final String productName;
  final String vendorId;
  final int quantity;
  final double price;
  final double subtotal;
  final String? imageUrl;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.vendorId,
    required this.quantity,
    required this.price,
    required this.subtotal,
    this.imageUrl,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      vendorId: map['vendorId'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: (map['price'] ?? 0.0).toDouble(),
      subtotal: (map['subtotal'] ?? 0.0).toDouble(),
      imageUrl: map['imageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'vendorId': vendorId,
      'quantity': quantity,
      'price': price,
      'subtotal': subtotal,
      'imageUrl': imageUrl,
    };
  }
}

/// Shipping information for an order
class OrderShippingInfo {
  final String name;
  final String address;
  final String phone;
  final String? email;
  final String? notes;

  OrderShippingInfo({
    required this.name,
    required this.address,
    required this.phone,
    this.email,
    this.notes,
  });

  factory OrderShippingInfo.fromMap(Map<String, dynamic> map) {
    return OrderShippingInfo(
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'],
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'notes': notes,
    };
  }
}

/// Order status enumeration
enum OrderStatus {
  pending,
  confirmed,
  processing,
  shipped,
  delivered,
  cancelled,
  refunded,
}

extension OrderStatusExtension on OrderStatus {
  static OrderStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'processing':
        return OrderStatus.processing;
      case 'shipped':
        return OrderStatus.shipped;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'refunded':
        return OrderStatus.refunded;
      default:
        return OrderStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.shipped:
        return 'Shipped';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.refunded:
        return 'Refunded';
    }
  }

  String get description {
    switch (this) {
      case OrderStatus.pending:
        return 'Order placed, awaiting confirmation';
      case OrderStatus.confirmed:
        return 'Order confirmed by vendor';
      case OrderStatus.processing:
        return 'Order is being prepared';
      case OrderStatus.shipped:
        return 'Order has been shipped';
      case OrderStatus.delivered:
        return 'Order delivered successfully';
      case OrderStatus.cancelled:
        return 'Order has been cancelled';
      case OrderStatus.refunded:
        return 'Order refunded';
    }
  }
}

/// Payment status enumeration
enum PaymentStatus {
  pending,
  processing,
  paid,
  failed,
  refunded,
}

extension PaymentStatusExtension on PaymentStatus {
  static PaymentStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'processing':
        return PaymentStatus.processing;
      case 'paid':
        return PaymentStatus.paid;
      case 'failed':
        return PaymentStatus.failed;
      case 'refunded':
        return PaymentStatus.refunded;
      default:
        return PaymentStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Payment Pending';
      case PaymentStatus.processing:
        return 'Processing Payment';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Payment Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }
}

/// Order event for tracking order history
class OrderEvent {
  final String type;
  final DateTime timestamp;
  final String userId;
  final String userName;
  final String details;
  final Map<String, dynamic>? metadata;

  OrderEvent({
    required this.type,
    required this.timestamp,
    required this.userId,
    required this.userName,
    required this.details,
    this.metadata,
  });

  factory OrderEvent.fromMap(Map<String, dynamic> map) {
    return OrderEvent(
      type: map['type'] ?? '',
      timestamp: map['timestamp'] is Timestamp 
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      details: map['details'] ?? '',
      metadata: map['metadata'] != null 
          ? Map<String, dynamic>.from(map['metadata'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'timestamp': timestamp,
      'userId': userId,
      'userName': userName,
      'details': details,
      'metadata': metadata,
    };
  }
}

/// Order rating and review
class OrderRating {
  final double rating;
  final String? review;
  final DateTime createdAt;
  final List<String>? images;

  OrderRating({
    required this.rating,
    this.review,
    required this.createdAt,
    this.images,
  });

  factory OrderRating.fromMap(Map<String, dynamic> map) {
    return OrderRating(
      rating: (map['rating'] ?? 0.0).toDouble(),
      review: map['review'],
      createdAt: map['createdAt'] is Timestamp 
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      images: map['images'] != null 
          ? List<String>.from(map['images'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rating': rating,
      'review': review,
      'createdAt': createdAt,
      'images': images,
    };
  }
}
