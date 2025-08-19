import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../theme/marketplace_theme.dart';
import '../../services/order_service.dart';
import 'order_detail_screen.dart';

/// Complete customer order tracking and history screen
class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({Key? key}) : super(key: key);

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen>
    with TickerProviderStateMixin {
  
  late TabController _tabController;
  final OrderService _orderService = OrderService();
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketplaceTheme.gray50,
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: MarketplaceTheme.primaryBlue,
          unselectedLabelColor: MarketplaceTheme.gray500,
          indicatorColor: MarketplaceTheme.primaryBlue,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Processing'),
            Tab(text: 'Shipped'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersList(null), // All orders
          _buildOrdersList('pending'),
          _buildOrdersList('processing'),
          _buildOrdersList('shipped'),
          _buildOrdersList('completed'),
        ],
      ),
    );
  }

  Widget _buildOrdersList(String? status) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getOrdersStream(status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(status);
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

  Stream<QuerySnapshot> _getOrdersStream(String? status) {
    Query query = FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);
    
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    
    return query.snapshots();
  }

  Widget _buildEmptyState(String? status) {
    String title = status != null 
        ? 'No ${status.toLowerCase()} orders'
        : 'No orders yet';
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: MarketplaceTheme.gray400,
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start shopping to see your orders here',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: MarketplaceTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Shopping'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> orderData, String orderId) {
    final status = orderData['status'] ?? 'pending';
    final totalAmount = orderData['totalAmount'] ?? 0.0;
    final createdAt = orderData['createdAt'] as Timestamp?;
    final orderType = orderData['orderType'] ?? 'product';
    final itemName = orderData['productName'] ?? orderData['serviceName'] ?? 'Unknown Item';
    final vendorId = orderData['vendorId'] ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Order Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${orderId.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt.toDate()),
                          style: TextStyle(
                            color: MarketplaceTheme.gray600,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
          ),
          
          // Order Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: MarketplaceTheme.gray200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        orderType == 'product' ? Icons.inventory_2 : Icons.design_services,
                        color: MarketplaceTheme.gray500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            itemName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            orderType == 'product' ? 'Product' : 'Service',
                            style: TextStyle(
                              color: MarketplaceTheme.gray600,
                              fontSize: 14,
                            ),
                          ),
                          if (orderType == 'product' && orderData['quantity'] != null)
                            Text(
                              'Qty: ${orderData['quantity']}',
                              style: TextStyle(
                                color: MarketplaceTheme.gray600,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₳${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: MarketplaceTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Vendor Info
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('vendor_profiles')
                      .doc(vendorId)
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    
                    final vendorData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                    final businessName = vendorData['businessName'] ?? 'Unknown Vendor';
                    
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MarketplaceTheme.gray50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.store,
                            color: MarketplaceTheme.primaryBlue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sold by $businessName',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: MarketplaceTheme.gray700,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Action Buttons
                _buildActionButtons(orderData, orderId, status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    final text = _getStatusText(status);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> orderData, String orderId, String status) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _viewOrderDetails(orderData, orderId),
            style: OutlinedButton.styleFrom(
              foregroundColor: MarketplaceTheme.primaryBlue,
              side: BorderSide(color: MarketplaceTheme.primaryBlue),
            ),
            child: const Text('View Details'),
          ),
        ),
        
        const SizedBox(width: 12),
        
        if (status == 'pending')
          Expanded(
            child: ElevatedButton(
              onPressed: () => _cancelOrder(orderId),
              style: ElevatedButton.styleFrom(
                backgroundColor: MarketplaceTheme.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancel'),
            ),
          )
        else if (status == 'completed' && !orderData.containsKey('hasReview'))
          Expanded(
            child: ElevatedButton(
              onPressed: () => _rateOrder(orderData, orderId),
              style: ElevatedButton.styleFrom(
                backgroundColor: MarketplaceTheme.primaryOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Rate & Review'),
            ),
          )
        else if (status == 'shipped')
          Expanded(
            child: ElevatedButton(
              onPressed: () => _trackOrder(orderId),
              style: ElevatedButton.styleFrom(
                backgroundColor: MarketplaceTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Track Order'),
            ),
          )
        else
          Expanded(
            child: ElevatedButton(
              onPressed: () => _contactVendor(orderData['vendorId']),
              style: ElevatedButton.styleFrom(
                backgroundColor: MarketplaceTheme.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Contact Vendor'),
            ),
          ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return MarketplaceTheme.success;
      case 'shipped':
        return MarketplaceTheme.info;
      case 'processing':
        return MarketplaceTheme.warning;
      case 'cancelled':
        return MarketplaceTheme.error;
      default:
        return MarketplaceTheme.gray500;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'processing':
        return 'Processing';
      case 'shipped':
        return 'Shipped';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.toUpperCase();
    }
  }

  void _viewOrderDetails(Map<String, dynamic> orderData, String orderId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          orderId: orderId,
          orderData: orderData,
        ),
      ),
    );
  }

  Future<void> _cancelOrder(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: MarketplaceTheme.error),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await _orderService.cancelOrder(orderId, 'Cancelled by customer');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled successfully'),
            backgroundColor: MarketplaceTheme.success,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling order: $e'),
            backgroundColor: MarketplaceTheme.error,
          ),
        );
      }
    }
  }

  void _rateOrder(Map<String, dynamic> orderData, String orderId) {
    // TODO: Implement rating and review screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rating feature coming soon!')),
    );
  }

  void _trackOrder(String orderId) {
    // TODO: Implement order tracking screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order tracking coming soon!')),
    );
  }

  void _contactVendor(String vendorId) {
    // TODO: Implement vendor messaging
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Messaging feature coming soon!')),
    );
  }
}
