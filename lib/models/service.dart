import 'package:cloud_firestore/cloud_firestore.dart';

class ServicePackage {
  String name;
  double price;
  String description;
  int deliveryTime; // in days

  ServicePackage({
    required this.name,
    required this.price,
    required this.description,
    required this.deliveryTime,
  });

  factory ServicePackage.fromJson(Map<String, dynamic> json) => ServicePackage(
        name: json['name'] ?? '',
        price: (json['price'] ?? 0).toDouble(),
        description: json['description'] ?? '',
        deliveryTime: json['deliveryTime'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'description': description,
        'deliveryTime': deliveryTime,
      };
}

class Service {
  final String id;
  final String vendorId;
  final String title;
  final String description;
  final List<String> images;
  final List<ServicePackage> packages;
  final int deliveryTime;
  final String category;
  final String subcategory;
  final List<String> requirements;
  final DateTime? createdAt;

  Service({
    required this.id,
    required this.vendorId,
    required this.title,
    required this.description,
    required this.images,
    required this.packages,
    required this.deliveryTime,
    required this.category,
    required this.subcategory,
    required this.requirements,
    this.createdAt,
  });

  factory Service.fromJson(Map<String, dynamic> json, String id) => Service(
        id: id,
        vendorId: json['vendorId'] ?? '',
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        images: List<String>.from(json['images'] ?? []),
        packages: (json['packages'] as List<dynamic>? ?? []).map((e) => ServicePackage.fromJson(e)).toList(),
        deliveryTime: json['deliveryTime'] ?? 0,
        category: json['category'] ?? '',
        subcategory: json['subcategory'] ?? '',
        requirements: List<String>.from(json['requirements'] ?? []),
        createdAt: json['createdAt'] != null ? (json['createdAt'] as Timestamp).toDate() : null,
      );

  Map<String, dynamic> toJson() => {
        'vendorId': vendorId,
        'title': title,
        'description': description,
        'images': images,
        'packages': packages.map((e) => e.toJson()).toList(),
        'deliveryTime': deliveryTime,
        'category': category,
        'subcategory': subcategory,
        'requirements': requirements,
        'createdAt': createdAt,
      };
} 