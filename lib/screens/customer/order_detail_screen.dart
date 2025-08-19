import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../theme/marketplace_theme.dart';
import '../../services/order_service.dart';

/// Detailed order tracking and information screen
class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;
  
  const OrderDetailScreen({
    Key? key,
    required this.orderId,
    required this.orderData,
  }) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final OrderService _orderService = OrderService();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketplaceTheme.gray50,
      appBar: AppBar(
        title: Text('Order #${widget.orderId.substring(0, 8).toUpperCase()}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildOrderHeader(),
            const SizedBox(height: 16),
            _buildOrderTracking(),
            const SizedBox(height: 16),
            _buildOrderItems(),
            const SizedBox(height: 16),
            _buildShippingInfo(),
            const SizedBox(height: 16),
            _buildPaymentInfo(),
            const SizedBox(height: 16),
            _buildVendorInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHeader() {
    final status = widget.orderData['status'] ?? 'pending';
    final totalAmount = widget.orderData['totalAmount'] ?? 0.0;
    final createdAt = widget.orderData['createdAt'] as Timestamp?;
    final estimatedDelivery = widget.orderData['estimatedDelivery'] as Timestamp?;
    
    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Total',
                      style: TextStyle(
                        color: MarketplaceTheme.gray600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '₳${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: MarketplaceTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Order Date',
                  createdAt != null 
                      ? DateFormat('MMM dd, yyyy').format(createdAt.toDate())
                      : 'Unknown',
                  Icons.calendar_today,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem(
                  'Estimated Delivery',
                  estimatedDelivery != null 
                      ? DateFormat('MMM dd, yyyy').format(estimatedDelivery.toDate())
                      : 'TBD',
                  Icons.local_shipping,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: MarketplaceTheme.primaryBlue, size: 24),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            color: MarketplaceTheme.gray600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    final text = _getStatusText(status);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildOrderTracking() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Tracking',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          // Track order progress based on status
          _buildTrackingTimeline(),
        ],
      ),
    );
  }

  Widget _buildTrackingTimeline() {
    final status = widget.orderData['status'] ?? 'pending';
    final trackingEvents = widget.orderData['tracking']?['events'] as List? ?? [];
    
    final allSteps = [
      {'key': 'pending', 'title': 'Order Placed', 'description': 'Your order has been placed'},
      {'key': 'confirmed', 'title': 'Order Confirmed', 'description': 'Vendor has confirmed your order'},
      {'key': 'processing', 'title': 'Processing', 'description': 'Your order is being prepared'},
      {'key': 'shipped', 'title': 'Shipped', 'description': 'Your order is on the way'},
      {'key': 'completed', 'title': 'Delivered', 'description': 'Order has been delivered'},
    ];
    
    return Column(
      children: allSteps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isCompleted = _isStepCompleted(step['key']!, status);
        final isActive = step['key'] == status;
        
        return _buildTimelineStep(
          step['title']!,
          step['description']!,
          isCompleted,
          isActive,
          index == allSteps.length - 1, // isLast
          _getStepTimestamp(step['key']!, trackingEvents),
        );
      }).toList(),
    );
  }

  Widget _buildTimelineStep(
    String title,
    String description,
    bool isCompleted,
    bool isActive,
    bool isLast,
    DateTime? timestamp,
  ) {
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCompleted || isActive 
                    ? MarketplaceTheme.primaryBlue 
                    : MarketplaceTheme.gray300,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted ? Icons.check : Icons.circle,
                color: Colors.white,
                size: 16,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted 
                    ? MarketplaceTheme.primaryBlue 
                    : MarketplaceTheme.gray300,
              ),
          ],
        ),
        
        const SizedBox(width: 16),
        
        Expanded(
          child: Container(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isCompleted || isActive ? Colors.black : MarketplaceTheme.gray500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: MarketplaceTheme.gray600,
                  ),
                ),
                if (timestamp != null && (isCompleted || isActive))
                  Text(
                    DateFormat('MMM dd, hh:mm a').format(timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: MarketplaceTheme.gray500,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItems() {
    final orderType = widget.orderData['orderType'] ?? 'product';
    
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          if (orderType == 'product')
            _buildProductItem()
          else
            _buildServiceItem(),
        ],
      ),
    );
  }

  Widget _buildProductItem() {
    final productName = widget.orderData['productName'] ?? 'Unknown Product';
    final quantity = widget.orderData['quantity'] ?? 1;
    final unitPrice = widget.orderData['unitPrice'] ?? 0.0;
    
    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: MarketplaceTheme.gray200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.inventory_2,
            color: Colors.grey,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                productName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Quantity: $quantity',
                style: TextStyle(
                  color: MarketplaceTheme.gray600,
                ),
              ),
              Text(
                'Unit Price: ₳${unitPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  color: MarketplaceTheme.gray600,
                ),
              ),
            ],
          ),
        ),
        Text(
          '₳${(unitPrice * quantity).toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: MarketplaceTheme.primaryGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildServiceItem() {
    final serviceName = widget.orderData['serviceName'] ?? 'Unknown Service';
    final packageName = widget.orderData['packageName'] ?? '';
    final totalAmount = widget.orderData['totalAmount'] ?? 0.0;
    final deliveryTime = widget.orderData['deliveryTime'] ?? 0;
    
    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: MarketplaceTheme.gray200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.design_services,
            color: Colors.grey,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                serviceName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              if (packageName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Package: $packageName',
                  style: TextStyle(
                    color: MarketplaceTheme.primaryBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Delivery: $deliveryTime days',
                style: TextStyle(
                  color: MarketplaceTheme.gray600,
                ),
              ),
            ],
          ),
        ),
        Text(
          '₳${totalAmount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: MarketplaceTheme.primaryGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildShippingInfo() {
    final shippingAddress = widget.orderData['shippingAddress'] ?? '';
    final orderType = widget.orderData['orderType'] ?? 'product';
    
    if (orderType == 'service') return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shipping Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: MarketplaceTheme.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  shippingAddress.isNotEmpty ? shippingAddress : 'No address provided',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo() {
    final paymentMethod = widget.orderData['paymentMethod'] ?? 'Unknown';
    final paymentStatus = widget.orderData['paymentStatus'] ?? 'pending';
    final totalAmount = widget.orderData['totalAmount'] ?? 0.0;
    
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Payment Method:'),
              Text(
                paymentMethod,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Payment Status:'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: paymentStatus == 'completed' 
                      ? MarketplaceTheme.success.withOpacity(0.1)
                      : MarketplaceTheme.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  paymentStatus.toUpperCase(),
                  style: TextStyle(
                    color: paymentStatus == 'completed' 
                        ? MarketplaceTheme.success
                        : MarketplaceTheme.warning,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          
          const Divider(height: 32),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '₳${totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: MarketplaceTheme.primaryGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVendorInfo() {
    final vendorId = widget.orderData['vendorId'] ?? '';
    
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('vendor_profiles')
          .doc(vendorId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        
        final vendorData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final businessName = vendorData['businessName'] ?? 'Unknown Vendor';
        final contactInfo = vendorData['contactInfo'] as Map<String, dynamic>? ?? {};
        final phone = contactInfo['phone'] ?? '';
        
        return Container(
          padding: const EdgeInsets.all(20),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vendor Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: MarketplaceTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Icon(
                      Icons.store,
                      color: MarketplaceTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          businessName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        if (phone.isNotEmpty)
                          Text(
                            phone,
                            style: TextStyle(
                              color: MarketplaceTheme.gray600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => _contactVendor(vendorId),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MarketplaceTheme.primaryBlue,
                      side: BorderSide(color: MarketplaceTheme.primaryBlue),
                    ),
                    child: const Text('Contact'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper methods
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

  bool _isStepCompleted(String step, String currentStatus) {
    final steps = ['pending', 'confirmed', 'processing', 'shipped', 'completed'];
    final stepIndex = steps.indexOf(step);
    final currentIndex = steps.indexOf(currentStatus);
    
    if (stepIndex == -1 || currentIndex == -1) return false;
    return stepIndex <= currentIndex;
  }

  DateTime? _getStepTimestamp(String step, List trackingEvents) {
    for (final event in trackingEvents) {
      if (event['status'] == step && event['timestamp'] != null) {
        final timestamp = event['timestamp'] as Timestamp;
        return timestamp.toDate();
      }
    }
    return null;
  }

  void _contactVendor(String vendorId) {
    // TODO: Implement vendor messaging
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Messaging feature coming soon!')),
    );
  }
}
