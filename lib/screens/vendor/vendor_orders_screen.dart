import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/marketplace_theme.dart';

/// Vendor orders management screen
class VendorOrdersScreen extends StatefulWidget {
  final String vendorId;
  
  const VendorOrdersScreen({Key? key, required this.vendorId}) : super(key: key);

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen>
    with TickerProviderStateMixin {
  
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: MarketplaceTheme.primaryBlue,
            unselectedLabelColor: MarketplaceTheme.gray500,
            indicatorColor: MarketplaceTheme.primaryBlue,
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Processing'),
              Tab(text: 'Completed'),
              Tab(text: 'All'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOrdersList('pending'),
              _buildOrdersList('processing'),
              _buildOrdersList('completed'),
              _buildOrdersList(null), // All orders
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersList(String? status) {
    Query query = FirebaseFirestore.instance
        .collection('orders')
        .where('vendorId', isEqualTo: widget.vendorId)
        .orderBy('createdAt', descending: true);
    
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 64,
                  color: MarketplaceTheme.gray400,
                ),
                const SizedBox(height: 16),
                Text(
                  status != null ? 'No $status orders' : 'No orders yet',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text('Orders will appear here once customers place them'),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final orderData = doc.data() as Map<String, dynamic>;
            return _buildOrderCard(orderData, doc.id);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> orderData, String orderId) {
    final status = orderData['status'] ?? 'pending';
    final total = orderData['totalAmount'] ?? 0.0;
    final customerName = orderData['customerName'] ?? 'Unknown Customer';
    final createdAt = orderData['createdAt'] as Timestamp?;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: _getStatusColor(status),
            shape: BoxShape.circle,
          ),
        ),
        title: Text(
          'Order #${orderId.substring(0, 8)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: $customerName'),
            Text('Total: ₳${total.toStringAsFixed(2)}'),
            if (createdAt != null)
              Text(
                'Date: ${_formatDate(createdAt.toDate())}',
                style: TextStyle(color: MarketplaceTheme.gray500),
              ),
          ],
        ),
        trailing: _buildStatusBadge(status),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildOrderActions(orderId, status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _formatStatus(status),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildOrderActions(String orderId, String status) {
    return Row(
      children: [
        if (status == 'pending')
          Expanded(
            child: ElevatedButton(
              onPressed: () => _updateOrderStatus(orderId, 'processing'),
              child: const Text('Accept Order'),
            ),
          ),
        if (status == 'processing') ...[
          Expanded(
            child: ElevatedButton(
              onPressed: () => _updateOrderStatus(orderId, 'completed'),
              child: const Text('Mark Complete'),
            ),
          ),
        ],
        if (status == 'pending' || status == 'processing') ...[
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _updateOrderStatus(orderId, 'cancelled'),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to ${_formatStatus(newStatus)}'),
          backgroundColor: MarketplaceTheme.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating order: $e'),
          backgroundColor: MarketplaceTheme.error,
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return MarketplaceTheme.success;
      case 'processing':
        return MarketplaceTheme.warning;
      case 'cancelled':
        return MarketplaceTheme.error;
      default:
        return MarketplaceTheme.info;
    }
  }

  String _formatStatus(String status) {
    return status[0].toUpperCase() + status.substring(1);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}