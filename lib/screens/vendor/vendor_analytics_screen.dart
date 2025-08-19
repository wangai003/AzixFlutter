import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/marketplace_theme.dart';

/// Vendor analytics and insights screen
class VendorAnalyticsScreen extends StatelessWidget {
  final String vendorId;
  
  const VendorAnalyticsScreen({Key? key, required this.vendorId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildOverviewCards(),
          const SizedBox(height: 16),
          _buildSalesChart(),
          const SizedBox(height: 16),
          _buildTopProducts(),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('vendor_profiles')
          .doc(vendorId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 100);
        }
        
        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final analytics = data['analytics'] as Map<String, dynamic>? ?? {};
        
        return Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Sales',
                '₳${analytics['totalSales'] ?? 0}',
                Icons.attach_money,
                MarketplaceTheme.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Orders',
                '${analytics['totalOrders'] ?? 0}',
                Icons.shopping_cart,
                MarketplaceTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Rating',
                '${(analytics['rating'] ?? 0.0).toStringAsFixed(1)}⭐',
                Icons.star,
                MarketplaceTheme.primaryOrange,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: MarketplaceTheme.gray600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesChart() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: MarketplaceTheme.gray50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                '📊 Sales Chart\n(Chart library integration needed)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProducts() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Products',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .where('vendorId', isEqualTo: vendorId)
                .orderBy('viewCount', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text('No products yet'),
                );
              }
              
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Unknown Product';
                  final views = data['viewCount'] ?? 0;
                  final price = data['price'] ?? 0.0;
                  
                  return ListTile(
                    title: Text(name),
                    subtitle: Text('₳${price.toStringAsFixed(2)}'),
                    trailing: Text('$views views'),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
