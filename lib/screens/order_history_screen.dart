import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.black,
          title: Text('Order History', style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold)),
        ),
        body: const Center(child: Text('You must be logged in to view your orders.')),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: Text('Order History', style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('buyerId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!.docs;
          if (orders.isEmpty) {
            return const Center(child: Text('No orders found.'));
          }
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final data = orders[index].data() as Map<String, dynamic>;
              final items = (data['items'] as List<dynamic>? ?? []);
              final date = (data['timestamp'] as Timestamp?)?.toDate();
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: ListTile(
                  title: Text('Order #${orders[index].id}', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (date != null)
                        Text('Date: ${date.toLocal()}', style: AppTheme.bodySmall),
                      Text('Status: ${data['status']}', style: AppTheme.bodySmall),
                      Text('Total: Ksh ${data['total']}', style: AppTheme.bodySmall.copyWith(color: AppTheme.primaryGold)),
                      Text('Items: ${items.map((e) => e['product']['name']).join(", ")}', style: AppTheme.bodySmall),
                    ],
                  ),
                  isThreeLine: true,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: AppTheme.white,
                        title: Row(
                          children: [
                            Icon(Icons.receipt_long, color: AppTheme.primaryGold, size: 28),
                            const SizedBox(width: 8),
                            Text('Order #${orders[index].id}'),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (date != null)
                              Text('Date: ${date.toLocal()}', style: AppTheme.bodySmall),
                            Text('Status: ${data['status']}', style: AppTheme.bodySmall),
                            Text('Total: Ksh ${data['total']}', style: AppTheme.bodySmall.copyWith(color: AppTheme.primaryGold)),
                            const SizedBox(height: 8),
                            const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                            ...items.map((e) => Text('${e['product']['name']} x${e['quantity']}')).toList(),
                            const SizedBox(height: 8),
                            if (data['shippingInfo'] != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Shipping Info:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text('Name: ${data['shippingInfo']['name']}'),
                                  Text('Address: ${data['shippingInfo']['address']}'),
                                  Text('Phone: ${data['shippingInfo']['phone']}'),
                                ],
                              ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
} 