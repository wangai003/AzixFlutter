import 'product.dart';
import 'service.dart';

/// Unified cart item that can hold either a product or service
class UnifiedCartItem {
  final String id;
  final CartItemType type;
  final Product? product;
  final Service? service;
  final Map<String, dynamic>? servicePackage; // Selected service package
  final Map<String, String>? serviceRequirements; // Service-specific requirements
  int quantity;
  final DateTime addedAt;

  UnifiedCartItem({
    required this.id,
    required this.type,
    this.product,
    this.service,
    this.servicePackage,
    this.serviceRequirements,
    required this.quantity,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now() {
    // Validation
    if (type == CartItemType.product && product == null) {
      throw ArgumentError('Product cannot be null for product cart item');
    }
    if (type == CartItemType.service && (service == null || servicePackage == null)) {
      throw ArgumentError('Service and package cannot be null for service cart item');
    }
  }

  /// Create a product cart item
  factory UnifiedCartItem.product({
    required Product product,
    int quantity = 1,
  }) {
    return UnifiedCartItem(
      id: '${product.id}_product',
      type: CartItemType.product,
      product: product,
      quantity: quantity,
    );
  }

  /// Create a service cart item
  factory UnifiedCartItem.service({
    required Service service,
    required Map<String, dynamic> servicePackage,
    Map<String, String>? requirements,
    int quantity = 1,
  }) {
    return UnifiedCartItem(
      id: '${service.id}_service_${servicePackage['name']?.replaceAll(' ', '_')}',
      type: CartItemType.service,
      service: service,
      servicePackage: servicePackage,
      serviceRequirements: requirements,
      quantity: quantity,
    );
  }

  /// Get the display name
  String get name {
    switch (type) {
      case CartItemType.product:
        return product!.name;
      case CartItemType.service:
        return '${service!.title} - ${servicePackage!['name']}';
    }
  }

  /// Get the vendor ID
  String get vendorId {
    switch (type) {
      case CartItemType.product:
        return product!.vendorId;
      case CartItemType.service:
        return service!.vendorId;
    }
  }

  /// Get the price per unit
  double get unitPrice {
    switch (type) {
      case CartItemType.product:
        return product!.price;
      case CartItemType.service:
        return (servicePackage!['price'] as num?)?.toDouble() ?? 0.0;
    }
  }

  /// Get the total price (unit price × quantity)
  double get totalPrice => unitPrice * quantity;

  /// Get the first image URL
  String? get imageUrl {
    switch (type) {
      case CartItemType.product:
        return product!.images.isNotEmpty ? product!.images.first : null;
      case CartItemType.service:
        return service!.images.isNotEmpty ? service!.images.first : null;
    }
  }

  /// Get the category
  String get category {
    switch (type) {
      case CartItemType.product:
        return product!.category;
      case CartItemType.service:
        return service!.category;
    }
  }

  /// Get delivery info
  String get deliveryInfo {
    switch (type) {
      case CartItemType.product:
        return product!.shippingOptions.isNotEmpty 
            ? 'Ships via ${product!.shippingOptions.first}'
            : 'Shipping info not available';
      case CartItemType.service:
        return 'Delivery in ${servicePackage!['deliveryTime'] ?? service!.deliveryTime}';
    }
  }

  /// Check if item can have quantity > 1
  bool get supportsQuantity {
    switch (type) {
      case CartItemType.product:
        return true; // Products can have multiple quantities
      case CartItemType.service:
        return false; // Services are typically one-time orders
    }
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'product': product?.toJson(),
      'service': service?.toJson(),
      'servicePackage': servicePackage,
      'serviceRequirements': serviceRequirements,
      'quantity': quantity,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory UnifiedCartItem.fromJson(Map<String, dynamic> json) {
    final type = CartItemTypeExtension.fromString(json['type']);
    
    return UnifiedCartItem(
      id: json['id'],
      type: type,
      product: json['product'] != null 
          ? Product.fromJson(json['product'], json['product']['id'])
          : null,
      service: json['service'] != null 
          ? Service.fromJson(json['service'], json['service']['id'] ?? '')
          : null,
      servicePackage: json['servicePackage'] != null 
          ? Map<String, dynamic>.from(json['servicePackage'])
          : null,
      serviceRequirements: json['serviceRequirements'] != null 
          ? Map<String, String>.from(json['serviceRequirements'])
          : null,
      quantity: json['quantity'] ?? 1,
      addedAt: DateTime.parse(json['addedAt']),
    );
  }

  /// Create a copy with updated values
  UnifiedCartItem copyWith({
    int? quantity,
    Map<String, String>? serviceRequirements,
  }) {
    return UnifiedCartItem(
      id: id,
      type: type,
      product: product,
      service: service,
      servicePackage: servicePackage,
      serviceRequirements: serviceRequirements ?? this.serviceRequirements,
      quantity: quantity ?? this.quantity,
      addedAt: addedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnifiedCartItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Type of cart item
enum CartItemType {
  product,
  service,
}

extension CartItemTypeExtension on CartItemType {
  static CartItemType fromString(String value) {
    switch (value) {
      case 'CartItemType.product':
        return CartItemType.product;
      case 'CartItemType.service':
        return CartItemType.service;
      default:
        return CartItemType.product;
    }
  }

  String get displayName {
    switch (this) {
      case CartItemType.product:
        return 'Product';
      case CartItemType.service:
        return 'Service';
    }
  }

  String get icon {
    switch (this) {
      case CartItemType.product:
        return '📦';
      case CartItemType.service:
        return '🛠️';
    }
  }
}
