import 'package:cloud_firestore/cloud_firestore.dart';

class GoodsVendorData {
  final String businessName;
  final String businessLicense;
  final List<String> productCategories;
  final List<String> shippingRegions;
  final String contactInfo;

  GoodsVendorData({
    required this.businessName,
    required this.businessLicense,
    required this.productCategories,
    required this.shippingRegions,
    required this.contactInfo,
  });

  factory GoodsVendorData.fromJson(Map<String, dynamic> json) => GoodsVendorData(
        businessName: json['businessName'] ?? '',
        businessLicense: json['businessLicense'] ?? '',
        productCategories: List<String>.from(json['productCategories'] ?? []),
        shippingRegions: List<String>.from(json['shippingRegions'] ?? []),
        contactInfo: json['contactInfo'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'businessName': businessName,
        'businessLicense': businessLicense,
        'productCategories': productCategories,
        'shippingRegions': shippingRegions,
        'contactInfo': contactInfo,
      };
}

class ServiceVendorData {
  final List<String> skills;
  final List<String> portfolioLinks;
  final List<String> serviceCategories;
  final String pricingModel;
  final String bio;

  ServiceVendorData({
    required this.skills,
    required this.portfolioLinks,
    required this.serviceCategories,
    required this.pricingModel,
    required this.bio,
  });

  factory ServiceVendorData.fromJson(Map<String, dynamic> json) => ServiceVendorData(
        skills: List<String>.from(json['skills'] ?? []),
        portfolioLinks: List<String>.from(json['portfolioLinks'] ?? []),
        serviceCategories: List<String>.from(json['serviceCategories'] ?? []),
        pricingModel: json['pricingModel'] ?? '',
        bio: json['bio'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'skills': skills,
        'portfolioLinks': portfolioLinks,
        'serviceCategories': serviceCategories,
        'pricingModel': pricingModel,
        'bio': bio,
      };
}

class VendorApplication {
  final String id;
  final String uid;
  final String type; // 'goods' or 'service'
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime? submittedAt;
  final GoodsVendorData? goodsVendorData;
  final ServiceVendorData? serviceVendorData;
  final DateTime? approvedAt;
  final String? rejectionReason;

  VendorApplication({
    required this.id,
    required this.uid,
    required this.type,
    required this.status,
    this.submittedAt,
    this.goodsVendorData,
    this.serviceVendorData,
    this.approvedAt,
    this.rejectionReason,
  });

  factory VendorApplication.fromJson(Map<String, dynamic> json, String id) => VendorApplication(
        id: id,
        uid: json['uid'] ?? '',
        type: json['type'] ?? '',
        status: json['status'] ?? '',
        submittedAt: json['submittedAt'] != null ? (json['submittedAt'] as Timestamp).toDate() : null,
        goodsVendorData: json['goodsVendorData'] != null ? GoodsVendorData.fromJson(json['goodsVendorData']) : null,
        serviceVendorData: json['serviceVendorData'] != null ? ServiceVendorData.fromJson(json['serviceVendorData']) : null,
        approvedAt: json['approvedAt'] != null ? (json['approvedAt'] as Timestamp).toDate() : null,
        rejectionReason: json['rejectionReason'],
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'type': type,
        'status': status,
        'submittedAt': submittedAt,
        'goodsVendorData': goodsVendorData?.toJson(),
        'serviceVendorData': serviceVendorData?.toJson(),
        'approvedAt': approvedAt,
        'rejectionReason': rejectionReason,
      };
} 