import 'package:cloud_firestore/cloud_firestore.dart';

/// Base listing class for both products and services
abstract class Listing {
  final String id;
  final String vendorId;
  final String title;
  final String description;
  final List<String> images;
  final List<String> tags;
  final String category;
  final String subcategory;
  final ListingStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double rating;
  final int reviewCount;
  final int viewCount;
  final int favoriteCount;
  final Map<String, dynamic> metadata;

  Listing({
    required this.id,
    required this.vendorId,
    required this.title,
    required this.description,
    required this.images,
    required this.tags,
    required this.category,
    required this.subcategory,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.viewCount = 0,
    this.favoriteCount = 0,
    this.metadata = const {},
  });

  ListingType get type;
  double get basePrice;
  Map<String, dynamic> toJson();
  
  /// Search score calculation for ranking
  double calculateSearchScore(String query, List<String> filters) {
    double score = 0.0;
    
    // Title relevance (highest weight)
    if (title.toLowerCase().contains(query.toLowerCase())) {
      score += 100.0;
    }
    
    // Description relevance
    if (description.toLowerCase().contains(query.toLowerCase())) {
      score += 50.0;
    }
    
    // Tags relevance
    for (String tag in tags) {
      if (tag.toLowerCase().contains(query.toLowerCase())) {
        score += 30.0;
      }
    }
    
    // Category relevance
    if (category.toLowerCase().contains(query.toLowerCase()) ||
        subcategory.toLowerCase().contains(query.toLowerCase())) {
      score += 20.0;
    }
    
    // Quality factors
    score += rating * 10.0; // Rating boost
    score += (reviewCount > 0) ? 10.0 : 0.0; // Has reviews boost
    score += viewCount * 0.1; // Popularity boost
    
    return score;
  }
}

enum ListingType { product, service }

enum ListingStatus { 
  draft,      // Being created
  pending,    // Awaiting approval
  active,     // Live and visible
  paused,     // Temporarily hidden
  suspended,  // Admin suspended
  archived    // No longer available
}

extension ListingStatusExtension on ListingStatus {
  String get displayName {
    switch (this) {
      case ListingStatus.draft:
        return 'Draft';
      case ListingStatus.pending:
        return 'Pending Review';
      case ListingStatus.active:
        return 'Active';
      case ListingStatus.paused:
        return 'Paused';
      case ListingStatus.suspended:
        return 'Suspended';
      case ListingStatus.archived:
        return 'Archived';
    }
  }
  
  bool get isVisible => this == ListingStatus.active;
  bool get canEdit => [ListingStatus.draft, ListingStatus.paused].contains(this);
}

/// Enhanced Product model
class Product extends Listing {
  final double price;
  final int inventory;
  final List<ProductVariant> variants;
  final ProductShipping shipping;
  final List<String> specifications;
  final String condition; // new, used, refurbished
  final String brand;
  final ProductDimensions? dimensions;
  final double? weight;

  Product({
    required String id,
    required String vendorId,
    required String title,
    required String description,
    required List<String> images,
    required List<String> tags,
    required String category,
    required String subcategory,
    required ListingStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
    required this.price,
    required this.inventory,
    this.variants = const [],
    required this.shipping,
    this.specifications = const [],
    this.condition = 'new',
    this.brand = '',
    this.dimensions,
    this.weight,
    double rating = 0.0,
    int reviewCount = 0,
    int viewCount = 0,
    int favoriteCount = 0,
    Map<String, dynamic> metadata = const {},
  }) : super(
          id: id,
          vendorId: vendorId,
          title: title,
          description: description,
          images: images,
          tags: tags,
          category: category,
          subcategory: subcategory,
          status: status,
          createdAt: createdAt,
          updatedAt: updatedAt,
          rating: rating,
          reviewCount: reviewCount,
          viewCount: viewCount,
          favoriteCount: favoriteCount,
          metadata: metadata,
        );

  @override
  ListingType get type => ListingType.product;

  @override
  double get basePrice => price;

  factory Product.fromJson(Map<String, dynamic> json, String id) {
    return Product(
      id: id,
      vendorId: json['vendorId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      images: List<String>.from(json['images'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      category: json['category'] ?? '',
      subcategory: json['subcategory'] ?? '',
      status: ListingStatus.values.firstWhere(
        (s) => s.toString() == json['status'],
        orElse: () => ListingStatus.draft,
      ),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      price: (json['price'] ?? 0.0).toDouble(),
      inventory: json['inventory'] ?? 0,
      variants: (json['variants'] as List<dynamic>?)
              ?.map((v) => ProductVariant.fromJson(v))
              .toList() ??
          [],
      shipping: ProductShipping.fromJson(json['shipping'] ?? {}),
      specifications: List<String>.from(json['specifications'] ?? []),
      condition: json['condition'] ?? 'new',
      brand: json['brand'] ?? '',
      dimensions: json['dimensions'] != null 
          ? ProductDimensions.fromJson(json['dimensions'])
          : null,
      weight: json['weight']?.toDouble(),
      rating: (json['rating'] ?? 0.0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
      viewCount: json['viewCount'] ?? 0,
      favoriteCount: json['favoriteCount'] ?? 0,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'vendorId': vendorId,
      'title': title,
      'description': description,
      'images': images,
      'tags': tags,
      'category': category,
      'subcategory': subcategory,
      'status': status.toString(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'price': price,
      'inventory': inventory,
      'variants': variants.map((v) => v.toJson()).toList(),
      'shipping': shipping.toJson(),
      'specifications': specifications,
      'condition': condition,
      'brand': brand,
      'dimensions': dimensions?.toJson(),
      'weight': weight,
      'rating': rating,
      'reviewCount': reviewCount,
      'viewCount': viewCount,
      'favoriteCount': favoriteCount,
      'metadata': metadata,
    };
  }

  bool get inStock => inventory > 0;
  bool get lowStock => inventory <= 5 && inventory > 0;
}

class ProductVariant {
  final String name;
  final double priceModifier;
  final int inventory;
  final Map<String, String> attributes; // color, size, etc.

  ProductVariant({
    required this.name,
    required this.priceModifier,
    required this.inventory,
    required this.attributes,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      name: json['name'] ?? '',
      priceModifier: (json['priceModifier'] ?? 0.0).toDouble(),
      inventory: json['inventory'] ?? 0,
      attributes: Map<String, String>.from(json['attributes'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'priceModifier': priceModifier,
      'inventory': inventory,
      'attributes': attributes,
    };
  }
}

class ProductShipping {
  final List<String> methods;
  final Map<String, double> costs;
  final Map<String, int> deliveryDays;
  final List<String> regions;
  final bool freeShippingThreshold;
  final double? freeShippingAmount;

  ProductShipping({
    required this.methods,
    required this.costs,
    required this.deliveryDays,
    required this.regions,
    this.freeShippingThreshold = false,
    this.freeShippingAmount,
  });

  factory ProductShipping.fromJson(Map<String, dynamic> json) {
    return ProductShipping(
      methods: List<String>.from(json['methods'] ?? []),
      costs: Map<String, double>.from(json['costs'] ?? {}),
      deliveryDays: Map<String, int>.from(json['deliveryDays'] ?? {}),
      regions: List<String>.from(json['regions'] ?? []),
      freeShippingThreshold: json['freeShippingThreshold'] ?? false,
      freeShippingAmount: json['freeShippingAmount']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'methods': methods,
      'costs': costs,
      'deliveryDays': deliveryDays,
      'regions': regions,
      'freeShippingThreshold': freeShippingThreshold,
      'freeShippingAmount': freeShippingAmount,
    };
  }
}

class ProductDimensions {
  final double length;
  final double width;
  final double height;
  final String unit; // cm, inch

  ProductDimensions({
    required this.length,
    required this.width,
    required this.height,
    this.unit = 'cm',
  });

  factory ProductDimensions.fromJson(Map<String, dynamic> json) {
    return ProductDimensions(
      length: (json['length'] ?? 0.0).toDouble(),
      width: (json['width'] ?? 0.0).toDouble(),
      height: (json['height'] ?? 0.0).toDouble(),
      unit: json['unit'] ?? 'cm',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'length': length,
      'width': width,
      'height': height,
      'unit': unit,
    };
  }

  double get volume => length * width * height;
}

/// Enhanced Service model (Upwork/Fiverr-inspired)
class Service extends Listing {
  final List<ServicePackage> packages;
  final List<String> skills;
  final ServiceDelivery delivery;
  final List<ServiceFAQ> faqs;
  final List<String> requirements;
  final ServiceComplexity complexity;
  final bool instantDelivery;
  final List<String> portfolioItems;

  Service({
    required String id,
    required String vendorId,
    required String title,
    required String description,
    required List<String> images,
    required List<String> tags,
    required String category,
    required String subcategory,
    required ListingStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
    required this.packages,
    required this.skills,
    required this.delivery,
    this.faqs = const [],
    this.requirements = const [],
    this.complexity = ServiceComplexity.intermediate,
    this.instantDelivery = false,
    this.portfolioItems = const [],
    double rating = 0.0,
    int reviewCount = 0,
    int viewCount = 0,
    int favoriteCount = 0,
    Map<String, dynamic> metadata = const {},
  }) : super(
          id: id,
          vendorId: vendorId,
          title: title,
          description: description,
          images: images,
          tags: tags,
          category: category,
          subcategory: subcategory,
          status: status,
          createdAt: createdAt,
          updatedAt: updatedAt,
          rating: rating,
          reviewCount: reviewCount,
          viewCount: viewCount,
          favoriteCount: favoriteCount,
          metadata: metadata,
        );

  @override
  ListingType get type => ListingType.service;

  @override
  double get basePrice => packages.isNotEmpty ? packages.first.price : 0.0;

  factory Service.fromJson(Map<String, dynamic> json, String id) {
    return Service(
      id: id,
      vendorId: json['vendorId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      images: List<String>.from(json['images'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      category: json['category'] ?? '',
      subcategory: json['subcategory'] ?? '',
      status: ListingStatus.values.firstWhere(
        (s) => s.toString() == json['status'],
        orElse: () => ListingStatus.draft,
      ),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      packages: (json['packages'] as List<dynamic>?)
              ?.map((p) => ServicePackage.fromJson(p))
              .toList() ??
          [],
      skills: List<String>.from(json['skills'] ?? []),
      delivery: ServiceDelivery.fromJson(json['delivery'] ?? {}),
      faqs: (json['faqs'] as List<dynamic>?)
              ?.map((f) => ServiceFAQ.fromJson(f))
              .toList() ??
          [],
      requirements: List<String>.from(json['requirements'] ?? []),
      complexity: ServiceComplexity.values.firstWhere(
        (c) => c.toString() == json['complexity'],
        orElse: () => ServiceComplexity.intermediate,
      ),
      instantDelivery: json['instantDelivery'] ?? false,
      portfolioItems: List<String>.from(json['portfolioItems'] ?? []),
      rating: (json['rating'] ?? 0.0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
      viewCount: json['viewCount'] ?? 0,
      favoriteCount: json['favoriteCount'] ?? 0,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'vendorId': vendorId,
      'title': title,
      'description': description,
      'images': images,
      'tags': tags,
      'category': category,
      'subcategory': subcategory,
      'status': status.toString(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'packages': packages.map((p) => p.toJson()).toList(),
      'skills': skills,
      'delivery': delivery.toJson(),
      'faqs': faqs.map((f) => f.toJson()).toList(),
      'requirements': requirements,
      'complexity': complexity.toString(),
      'instantDelivery': instantDelivery,
      'portfolioItems': portfolioItems,
      'rating': rating,
      'reviewCount': reviewCount,
      'viewCount': viewCount,
      'favoriteCount': favoriteCount,
      'metadata': metadata,
    };
  }
}

class ServicePackage {
  final String name;
  final String description;
  final double price;
  final int deliveryDays;
  final int revisions;
  final List<String> features;
  final bool isPopular;

  ServicePackage({
    required this.name,
    required this.description,
    required this.price,
    required this.deliveryDays,
    required this.revisions,
    required this.features,
    this.isPopular = false,
  });

  factory ServicePackage.fromJson(Map<String, dynamic> json) {
    return ServicePackage(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      deliveryDays: json['deliveryDays'] ?? 0,
      revisions: json['revisions'] ?? 0,
      features: List<String>.from(json['features'] ?? []),
      isPopular: json['isPopular'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'deliveryDays': deliveryDays,
      'revisions': revisions,
      'features': features,
      'isPopular': isPopular,
    };
  }
}

class ServiceDelivery {
  final List<String> formats; // digital, physical
  final int maxRevisions;
  final bool commercialUse;
  final bool sourceFiles;

  ServiceDelivery({
    required this.formats,
    this.maxRevisions = 1,
    this.commercialUse = false,
    this.sourceFiles = false,
  });

  factory ServiceDelivery.fromJson(Map<String, dynamic> json) {
    return ServiceDelivery(
      formats: List<String>.from(json['formats'] ?? []),
      maxRevisions: json['maxRevisions'] ?? 1,
      commercialUse: json['commercialUse'] ?? false,
      sourceFiles: json['sourceFiles'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'formats': formats,
      'maxRevisions': maxRevisions,
      'commercialUse': commercialUse,
      'sourceFiles': sourceFiles,
    };
  }
}

class ServiceFAQ {
  final String question;
  final String answer;

  ServiceFAQ({
    required this.question,
    required this.answer,
  });

  factory ServiceFAQ.fromJson(Map<String, dynamic> json) {
    return ServiceFAQ(
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'answer': answer,
    };
  }
}

enum ServiceComplexity { beginner, intermediate, advanced, expert }

extension ServiceComplexityExtension on ServiceComplexity {
  String get displayName {
    switch (this) {
      case ServiceComplexity.beginner:
        return 'Beginner';
      case ServiceComplexity.intermediate:
        return 'Intermediate';
      case ServiceComplexity.advanced:
        return 'Advanced';
      case ServiceComplexity.expert:
        return 'Expert';
    }
  }
}
