import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';

class VendorOrdersScreen extends StatelessWidget {
  const VendorOrdersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('You must be logged in as a vendor.')),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Orders'),
          backgroundColor: AppTheme.black,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Goods Orders'),
              Tab(text: 'Service Orders'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _VendorGoodsOrdersTab(vendorId: user.uid),
            _VendorServiceOrdersTab(vendorId: user.uid),
          ],
        ),
      ),
    );
  }
}

class _VendorGoodsOrdersTab extends StatelessWidget {
  final String vendorId;
  const _VendorGoodsOrdersTab({required this.vendorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('vendorId', isEqualTo: vendorId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data!.docs;
        if (orders.isEmpty) {
          return const Center(child: Text('No goods orders found.'));
        }
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, idx) {
            final data = orders[idx].data() as Map<String, dynamic>;
            final date = (data['timestamp'] as Timestamp?)?.toDate();
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                leading: const Icon(Icons.shopping_bag, color: Colors.amber),
                title: Text('Order: ₳${(data['total'] ?? 0).toStringAsFixed(2)}'),
                subtitle: Text(date != null ? DateFormat('yMMMd – HH:mm').format(date) : ''),
                trailing: Text(data['status'] ?? ''),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Order Details'),
                      content: SingleChildScrollView(
                        child: Text(data.toString()),
                      ),
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _VendorServiceOrdersTab extends StatelessWidget {
  final String vendorId;
  const _VendorServiceOrdersTab({required this.vendorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('service_orders')
          .where('vendorId', isEqualTo: vendorId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data!.docs;
        if (orders.isEmpty) {
          return const Center(child: Text('No service orders found.'));
        }
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, idx) {
            final data = orders[idx].data() as Map<String, dynamic>;
            final date = (data['createdAt'] as Timestamp?)?.toDate();
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                leading: const Icon(Icons.design_services, color: Colors.blueAccent),
                title: Text('Service: ${data['serviceId'] ?? ''}'),
                subtitle: Text(date != null ? DateFormat('yMMMd – HH:mm').format(date) : ''),
                trailing: Text(data['status'] ?? ''),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Service Order Details'),
                      content: SingleChildScrollView(
                        child: Text(data.toString()),
                      ),
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
} 