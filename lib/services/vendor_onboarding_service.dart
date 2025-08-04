import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/vendor_application.dart';

class VendorOnboardingService {
  static Future<bool> submitGoodsVendorApplication({
    required String businessName,
    required String businessLicense,
    required List<String> productCategories,
    required List<String> shippingRegions,
    required String contactInfo,
    String? registrationDocUrl,
    String? idDocUrl,
    String? logoImageUrl,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final application = {
        'uid': user.uid,
        'type': 'goods',
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'goodsVendorData': {
          'businessName': businessName,
          'businessLicense': businessLicense,
          'productCategories': productCategories,
          'shippingRegions': shippingRegions,
          'contactInfo': contactInfo,
          'registrationDocUrl': registrationDocUrl,
          'idDocUrl': idDocUrl,
          'logoImageUrl': logoImageUrl,
        },
      };
      await FirebaseFirestore.instance.collection('vendor_applications').add(application);
      return true;
    } catch (e) {
      print('Error submitting goods vendor application: $e');
      return false;
    }
  }

  static Future<bool> submitServiceVendorApplication({
    required List<String> skills,
    required List<String> portfolioLinks,
    required List<String> serviceCategories,
    required String pricingModel,
    required String bio,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final application = {
        'uid': user.uid,
        'type': 'service',
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'serviceVendorData': {
          'skills': skills,
          'portfolioLinks': portfolioLinks,
          'serviceCategories': serviceCategories,
          'pricingModel': pricingModel,
          'bio': bio,
        },
      };
      await FirebaseFirestore.instance.collection('vendor_applications').add(application);
      return true;
    } catch (e) {
      print('Error submitting service vendor application: $e');
      return false;
    }
  }

  static Future<VendorApplication?> fetchLatestVendorApplication() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final query = await FirebaseFirestore.instance
        .collection('vendor_applications')
        .where('uid', isEqualTo: user.uid)
        .orderBy('submittedAt', descending: true)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    return VendorApplication.fromJson(doc.data(), doc.id);
  }
} 