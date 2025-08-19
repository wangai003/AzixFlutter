import 'package:cloud_firestore/cloud_firestore.dart';

/// Advanced order system for both products and services with escrow
class MarketplaceOrder {
  final String id;
  final String buyerId;
  final String vendorId;
  final OrderType type;
  final List<OrderItem> items;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final OrderShipping? shipping;
  final OrderBilling billing;
  final double subtotal;
  final double shippingCost;
  final double taxAmount;
  final double discountAmount;
  final double totalAmount;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expectedDelivery;
  final DateTime? actualDelivery;
  final List<OrderEvent> timeline;
  final EscrowDetails? escrow;
  final DisputeDetails? dispute;
  final Map<String, dynamic> metadata;

  MarketplaceOrder({
    required this.id,
    required this.buyerId,
    required this.vendorId,
    required this.type,
    required this.items,
    required this.status,
    required this.paymentStatus,
    this.shipping,
    required this.billing,
    required this.subtotal,
    required this.shippingCost,
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
    this.expectedDelivery,
    this.actualDelivery,
    required this.timeline,
    this.escrow,
    this.dispute,
    this.metadata = const {},
  });

  factory MarketplaceOrder.fromJson(Map<String, dynamic> json, String id) {
    return MarketplaceOrder(
      id: id,
      buyerId: json['buyerId'] ?? '',
      vendorId: json['vendorId'] ?? '',
      type: OrderType.values.firstWhere(
        (t) => t.toString() == json['type'],
        orElse: () => OrderType.product,
      ),
      items: (json['items'] as List<dynamic>?)
              ?.map((i) => OrderItem.fromJson(i))
              .toList() ??
          [],
      status: OrderStatus.values.firstWhere(
        (s) => s.toString() == json['status'],
        orElse: () => OrderStatus.pending,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (p) => p.toString() == json['paymentStatus'],
        orElse: () => PaymentStatus.pending,
      ),
      shipping: json['shipping'] != null 
          ? OrderShipping.fromJson(json['shipping'])
          : null,
      billing: OrderBilling.fromJson(json['billing'] ?? {}),
      subtotal: (json['subtotal'] ?? 0.0).toDouble(),
      shippingCost: (json['shippingCost'] ?? 0.0).toDouble(),
      taxAmount: (json['taxAmount'] ?? 0.0).toDouble(),
      discountAmount: (json['discountAmount'] ?? 0.0).toDouble(),
      totalAmount: (json['totalAmount'] ?? 0.0).toDouble(),
      currency: json['currency'] ?? 'AKOFA',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expectedDelivery: (json['expectedDelivery'] as Timestamp?)?.toDate(),
      actualDelivery: (json['actualDelivery'] as Timestamp?)?.toDate(),
      timeline: (json['timeline'] as List<dynamic>?)
              ?.map((t) => OrderEvent.fromJson(t))
              .toList() ??
          [],
      escrow: json['escrow'] != null 
          ? EscrowDetails.fromJson(json['escrow'])
          : null,
      dispute: json['dispute'] != null 
          ? DisputeDetails.fromJson(json['dispute'])
          : null,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'buyerId': buyerId,
      'vendorId': vendorId,
      'type': type.toString(),
      'items': items.map((i) => i.toJson()).toList(),
      'status': status.toString(),
      'paymentStatus': paymentStatus.toString(),
      'shipping': shipping?.toJson(),
      'billing': billing.toJson(),
      'subtotal': subtotal,
      'shippingCost': shippingCost,
      'taxAmount': taxAmount,
      'discountAmount': discountAmount,
      'totalAmount': totalAmount,
      'currency': currency,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'expectedDelivery': expectedDelivery != null 
          ? Timestamp.fromDate(expectedDelivery!)
          : null,
      'actualDelivery': actualDelivery != null 
          ? Timestamp.fromDate(actualDelivery!)
          : null,
      'timeline': timeline.map((t) => t.toJson()).toList(),
      'escrow': escrow?.toJson(),
      'dispute': dispute?.toJson(),
      'metadata': metadata,
    };
  }

  bool get isServiceOrder => type == OrderType.service;
  bool get isProductOrder => type == OrderType.product;
  bool get canCancel => [OrderStatus.pending, OrderStatus.confirmed].contains(status);
  bool get canRefund => [OrderStatus.delivered, OrderStatus.completed].contains(status);
  bool get isInEscrow => escrow != null && escrow!.status == EscrowStatus.held;
  bool get hasDispute => dispute != null;
  
  Duration? get estimatedDeliveryTime {
    if (expectedDelivery == null) return null;
    return expectedDelivery!.difference(DateTime.now());
  }
}

enum OrderType { product, service }

enum OrderStatus {
  pending,      // Order placed, awaiting confirmation
  confirmed,    // Vendor confirmed order
  processing,   // Being prepared/worked on
  shipped,      // Product shipped / Service in progress
  delivered,    // Product delivered / Service delivered
  completed,    // Order completed successfully
  cancelled,    // Order cancelled
  refunded,     // Order refunded
  disputed      // Order under dispute
}

enum PaymentStatus {
  pending,      // Payment initiated
  processing,   // Payment being processed
  paid,         // Payment completed
  escrowed,     // Payment held in escrow
  released,     // Payment released to vendor
  refunded,     // Payment refunded to buyer
  failed,       // Payment failed
  disputed      // Payment disputed
}

extension OrderStatusExtension on OrderStatus {
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
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.refunded:
        return 'Refunded';
      case OrderStatus.disputed:
        return 'Disputed';
    }
  }

  bool get isActive => ![OrderStatus.completed, OrderStatus.cancelled, 
                         OrderStatus.refunded].contains(this);
}

class OrderItem {
  final String listingId;
  final String title;
  final String imageUrl;
  final OrderItemType type;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final Map<String, dynamic> variant; // For products: color, size, etc.
  final Map<String, dynamic> serviceDetails; // For services: package, requirements
  final String? notes;

  OrderItem({
    required this.listingId,
    required this.title,
    required this.imageUrl,
    required this.type,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.variant = const {},
    this.serviceDetails = const {},
    this.notes,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      listingId: json['listingId'] ?? '',
      title: json['title'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      type: OrderItemType.values.firstWhere(
        (t) => t.toString() == json['type'],
        orElse: () => OrderItemType.product,
      ),
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unitPrice'] ?? 0.0).toDouble(),
      totalPrice: (json['totalPrice'] ?? 0.0).toDouble(),
      variant: Map<String, dynamic>.from(json['variant'] ?? {}),
      serviceDetails: Map<String, dynamic>.from(json['serviceDetails'] ?? {}),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'listingId': listingId,
      'title': title,
      'imageUrl': imageUrl,
      'type': type.toString(),
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'variant': variant,
      'serviceDetails': serviceDetails,
      'notes': notes,
    };
  }
}

enum OrderItemType { product, service }

class OrderShipping {
  final String method;
  final double cost;
  final int estimatedDays;
  final ShippingAddress address;
  final String? trackingNumber;
  final String? carrier;
  final DateTime? shippedAt;
  final DateTime? estimatedDelivery;
  final List<ShippingUpdate> updates;

  OrderShipping({
    required this.method,
    required this.cost,
    required this.estimatedDays,
    required this.address,
    this.trackingNumber,
    this.carrier,
    this.shippedAt,
    this.estimatedDelivery,
    this.updates = const [],
  });

  factory OrderShipping.fromJson(Map<String, dynamic> json) {
    return OrderShipping(
      method: json['method'] ?? '',
      cost: (json['cost'] ?? 0.0).toDouble(),
      estimatedDays: json['estimatedDays'] ?? 0,
      address: ShippingAddress.fromJson(json['address'] ?? {}),
      trackingNumber: json['trackingNumber'],
      carrier: json['carrier'],
      shippedAt: (json['shippedAt'] as Timestamp?)?.toDate(),
      estimatedDelivery: (json['estimatedDelivery'] as Timestamp?)?.toDate(),
      updates: (json['updates'] as List<dynamic>?)
              ?.map((u) => ShippingUpdate.fromJson(u))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'cost': cost,
      'estimatedDays': estimatedDays,
      'address': address.toJson(),
      'trackingNumber': trackingNumber,
      'carrier': carrier,
      'shippedAt': shippedAt != null ? Timestamp.fromDate(shippedAt!) : null,
      'estimatedDelivery': estimatedDelivery != null 
          ? Timestamp.fromDate(estimatedDelivery!) 
          : null,
      'updates': updates.map((u) => u.toJson()).toList(),
    };
  }
}

class ShippingAddress {
  final String fullName;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String state;
  final String postalCode;
  final String country;
  final String? phoneNumber;

  ShippingAddress({
    required this.fullName,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
    this.phoneNumber,
  });

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    return ShippingAddress(
      fullName: json['fullName'] ?? '',
      addressLine1: json['addressLine1'] ?? '',
      addressLine2: json['addressLine2'],
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      postalCode: json['postalCode'] ?? '',
      country: json['country'] ?? '',
      phoneNumber: json['phoneNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'state': state,
      'postalCode': postalCode,
      'country': country,
      'phoneNumber': phoneNumber,
    };
  }

  String get formattedAddress {
    final parts = [
      addressLine1,
      if (addressLine2?.isNotEmpty == true) addressLine2!,
      '$city, $state $postalCode',
      country,
    ];
    return parts.join('\n');
  }
}

class ShippingUpdate {
  final DateTime timestamp;
  final String status;
  final String description;
  final String? location;

  ShippingUpdate({
    required this.timestamp,
    required this.status,
    required this.description,
    this.location,
  });

  factory ShippingUpdate.fromJson(Map<String, dynamic> json) {
    return ShippingUpdate(
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: json['status'] ?? '',
      description: json['description'] ?? '',
      location: json['location'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status,
      'description': description,
      'location': location,
    };
  }
}

class OrderBilling {
  final String paymentMethod;
  final String? paymentReference;
  final double paidAmount;
  final String currency;
  final DateTime? paidAt;
  final Map<String, dynamic> paymentDetails;

  OrderBilling({
    required this.paymentMethod,
    this.paymentReference,
    required this.paidAmount,
    required this.currency,
    this.paidAt,
    this.paymentDetails = const {},
  });

  factory OrderBilling.fromJson(Map<String, dynamic> json) {
    return OrderBilling(
      paymentMethod: json['paymentMethod'] ?? '',
      paymentReference: json['paymentReference'],
      paidAmount: (json['paidAmount'] ?? 0.0).toDouble(),
      currency: json['currency'] ?? 'AKOFA',
      paidAt: (json['paidAt'] as Timestamp?)?.toDate(),
      paymentDetails: Map<String, dynamic>.from(json['paymentDetails'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paymentMethod': paymentMethod,
      'paymentReference': paymentReference,
      'paidAmount': paidAmount,
      'currency': currency,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'paymentDetails': paymentDetails,
    };
  }
}

class OrderEvent {
  final DateTime timestamp;
  final String event;
  final String description;
  final String? actorId;
  final String? actorType; // buyer, vendor, admin, system
  final Map<String, dynamic> data;

  OrderEvent({
    required this.timestamp,
    required this.event,
    required this.description,
    this.actorId,
    this.actorType,
    this.data = const {},
  });

  factory OrderEvent.fromJson(Map<String, dynamic> json) {
    return OrderEvent(
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      event: json['event'] ?? '',
      description: json['description'] ?? '',
      actorId: json['actorId'],
      actorType: json['actorType'],
      data: Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'event': event,
      'description': description,
      'actorId': actorId,
      'actorType': actorType,
      'data': data,
    };
  }
}

/// Escrow system for secure transactions
class EscrowDetails {
  final String escrowId;
  final EscrowStatus status;
  final double amount;
  final String currency;
  final DateTime createdAt;
  final DateTime? releaseScheduledAt;
  final DateTime? releasedAt;
  final String? releaseReason;
  final List<EscrowEvent> events;

  EscrowDetails({
    required this.escrowId,
    required this.status,
    required this.amount,
    required this.currency,
    required this.createdAt,
    this.releaseScheduledAt,
    this.releasedAt,
    this.releaseReason,
    this.events = const [],
  });

  factory EscrowDetails.fromJson(Map<String, dynamic> json) {
    return EscrowDetails(
      escrowId: json['escrowId'] ?? '',
      status: EscrowStatus.values.firstWhere(
        (s) => s.toString() == json['status'],
        orElse: () => EscrowStatus.held,
      ),
      amount: (json['amount'] ?? 0.0).toDouble(),
      currency: json['currency'] ?? 'AKOFA',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      releaseScheduledAt: (json['releaseScheduledAt'] as Timestamp?)?.toDate(),
      releasedAt: (json['releasedAt'] as Timestamp?)?.toDate(),
      releaseReason: json['releaseReason'],
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => EscrowEvent.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'escrowId': escrowId,
      'status': status.toString(),
      'amount': amount,
      'currency': currency,
      'createdAt': Timestamp.fromDate(createdAt),
      'releaseScheduledAt': releaseScheduledAt != null 
          ? Timestamp.fromDate(releaseScheduledAt!)
          : null,
      'releasedAt': releasedAt != null 
          ? Timestamp.fromDate(releasedAt!)
          : null,
      'releaseReason': releaseReason,
      'events': events.map((e) => e.toJson()).toList(),
    };
  }
}

enum EscrowStatus {
  held,         // Money held in escrow
  released,     // Money released to vendor
  refunded,     // Money refunded to buyer
  disputed,     // Under dispute
  expired       // Escrow expired
}

class EscrowEvent {
  final DateTime timestamp;
  final String action;
  final String description;
  final String? actorId;

  EscrowEvent({
    required this.timestamp,
    required this.action,
    required this.description,
    this.actorId,
  });

  factory EscrowEvent.fromJson(Map<String, dynamic> json) {
    return EscrowEvent(
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      action: json['action'] ?? '',
      description: json['description'] ?? '',
      actorId: json['actorId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'action': action,
      'description': description,
      'actorId': actorId,
    };
  }
}

/// Dispute resolution system
class DisputeDetails {
  final String disputeId;
  final DisputeStatus status;
  final DisputeReason reason;
  final String description;
  final String reportedBy; // buyer or vendor
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolution;
  final String? resolvedBy; // admin ID
  final List<DisputeMessage> messages;
  final List<String> evidence; // URLs to evidence files

  DisputeDetails({
    required this.disputeId,
    required this.status,
    required this.reason,
    required this.description,
    required this.reportedBy,
    required this.createdAt,
    this.resolvedAt,
    this.resolution,
    this.resolvedBy,
    this.messages = const [],
    this.evidence = const [],
  });

  factory DisputeDetails.fromJson(Map<String, dynamic> json) {
    return DisputeDetails(
      disputeId: json['disputeId'] ?? '',
      status: DisputeStatus.values.firstWhere(
        (s) => s.toString() == json['status'],
        orElse: () => DisputeStatus.open,
      ),
      reason: DisputeReason.values.firstWhere(
        (r) => r.toString() == json['reason'],
        orElse: () => DisputeReason.other,
      ),
      description: json['description'] ?? '',
      reportedBy: json['reportedBy'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (json['resolvedAt'] as Timestamp?)?.toDate(),
      resolution: json['resolution'],
      resolvedBy: json['resolvedBy'],
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) => DisputeMessage.fromJson(m))
              .toList() ??
          [],
      evidence: List<String>.from(json['evidence'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'disputeId': disputeId,
      'status': status.toString(),
      'reason': reason.toString(),
      'description': description,
      'reportedBy': reportedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'resolution': resolution,
      'resolvedBy': resolvedBy,
      'messages': messages.map((m) => m.toJson()).toList(),
      'evidence': evidence,
    };
  }
}

enum DisputeStatus {
  open,         // Dispute opened
  investigating, // Under admin review
  resolved,     // Dispute resolved
  closed        // Dispute closed
}

enum DisputeReason {
  notDelivered,     // Order not delivered
  notAsDescribed,   // Product/service not as described
  damaged,          // Product damaged
  incomplete,       // Service incomplete
  unauthorized,     // Unauthorized transaction
  other            // Other reason
}

class DisputeMessage {
  final String senderId;
  final String senderType; // buyer, vendor, admin
  final String message;
  final DateTime timestamp;
  final List<String> attachments;

  DisputeMessage({
    required this.senderId,
    required this.senderType,
    required this.message,
    required this.timestamp,
    this.attachments = const [],
  });

  factory DisputeMessage.fromJson(Map<String, dynamic> json) {
    return DisputeMessage(
      senderId: json['senderId'] ?? '',
      senderType: json['senderType'] ?? '',
      message: json['message'] ?? '',
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      attachments: List<String>.from(json['attachments'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'senderType': senderType,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'attachments': attachments,
    };
  }
}
