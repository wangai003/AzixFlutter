import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String vendorId;
  final String name;
  final String description;
  final List<String> images;
  final double price;
  final int inventory;
  final String category;
  final String subcategory;
  final List<String> shippingOptions;
  final DateTime? createdAt;

  Product({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.description,
    required this.images,
    required this.price,
    required this.inventory,
    required this.category,
    required this.subcategory,
    required this.shippingOptions,
    this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json, String id) => Product(
        id: id,
        vendorId: json['vendorId'] ?? '',
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        images: List<String>.from(json['images'] ?? []),
        price: (json['price'] ?? 0).toDouble(),
        inventory: json['inventory'] ?? 0,
        category: json['category'] ?? '',
        subcategory: json['subcategory'] ?? '',
        shippingOptions: List<String>.from(json['shippingOptions'] ?? []),
        createdAt: json['createdAt'] != null ? (json['createdAt'] as Timestamp).toDate() : null,
      );

  Map<String, dynamic> toJson() => {
        'vendorId': vendorId,
        'name': name,
        'description': description,
        'images': images,
        'price': price,
        'inventory': inventory,
        'category': category,
        'subcategory': subcategory,
        'shippingOptions': shippingOptions,
        'createdAt': createdAt,
      };
} 