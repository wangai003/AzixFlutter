import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/service_order.dart';

class ServiceOrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new service order in Firestore
  Future<String> createServiceOrder(ServiceOrder order) async {
    try {
      final docRef = await _firestore.collection('service_orders').add(order.toJson());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create service order: $e');
    }
  }

  // Optionally: Add more methods for fetching, updating, etc.
} 