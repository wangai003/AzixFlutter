import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service_order.dart';
import 'service_order_detail_screen.dart';

class VendorServiceOrdersScreen extends StatelessWidget {
  const VendorServiceOrdersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('You must be logged in as a vendor.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Service Orders')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('service_orders')
            .where('vendorId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No service orders yet.'));
          }
          final orders = snapshot.data!.docs
              .map((doc) => ServiceOrder.fromJson(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          return ListView.separated(
            itemCount: orders.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final order = orders[i];
              return ListTile(
                title: Text(order.package['name'] ?? 'Package'),
                subtitle: Text('Buyer: ${order.buyerId}\nStatus: ${order.status}'),
                trailing: Text('₳${order.price.toStringAsFixed(2)}'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ServiceOrderDetailScreen(order: order),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
} 