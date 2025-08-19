import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/marketplace_theme.dart';
import '../../models/product.dart';
import '../../models/service.dart';
import 'add_product_screen.dart';
import 'add_service_screen.dart';
import 'vendor_orders_screen.dart';
import 'vendor_analytics_screen.dart';

/// Fully functional vendor dashboard with real product/service management
class FunctionalVendorDashboard extends StatefulWidget {
  const FunctionalVendorDashboard({Key? key}) : super(key: key);

  @override
  State<FunctionalVendorDashboard> createState() => _FunctionalVendorDashboardState();
}

class _FunctionalVendorDashboardState extends State<FunctionalVendorDashboard>
    with TickerProviderStateMixin {
  
  late TabController _tabController;
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildProductsTab(),
                  _buildOrdersTab(),
                  _buildAnalyticsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [MarketplaceTheme.primaryBlue, MarketplaceTheme.primaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vendor_profiles')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(height: 80);
          }
          
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final businessName = data['businessName'] ?? 'My Store';
          final analytics = data['analytics'] as Map<String, dynamic>? ?? {};
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.store,
                      color: Colors.white,
                      size: 24,
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
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Vendor Dashboard',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildQuickStat('Sales', '₳${analytics['totalSales'] ?? 0}'),
                  _buildQuickStat('Orders', '${analytics['totalOrders'] ?? 0}'),
                  _buildQuickStat('Rating', '${(analytics['rating'] ?? 0.0).toStringAsFixed(1)}⭐'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildQuickStat(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: MarketplaceTheme.primaryBlue,
        unselectedLabelColor: MarketplaceTheme.gray500,
        indicatorColor: MarketplaceTheme.primaryBlue,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Products'),
          Tab(text: 'Orders'),
          Tab(text: 'Analytics'),
        ],
      ),
    );
  }
  
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildRecentOrdersCard(),
          const SizedBox(height: 16),
          _buildQuickActionsCard(),
          const SizedBox(height: 16),
          _buildInventoryAlertsCard(),
        ],
      ),
    );
  }
  
  Widget _buildRecentOrdersCard() {
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
          Row(
            children: [
              const Text(
                'Recent Orders',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _tabController.animateTo(2),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('vendorId', isEqualTo: userId)
                .orderBy('createdAt', descending: true)
                .limit(3)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text('No recent orders'),
                );
              }
              
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildOrderItem(data);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildOrderItem(Map<String, dynamic> orderData) {
    final status = orderData['status'] ?? 'pending';
    final total = orderData['totalAmount'] ?? 0.0;
    final customerName = orderData['customerName'] ?? 'Unknown Customer';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MarketplaceTheme.gray50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _getStatusColor(status),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customerName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '₳${total.toStringAsFixed(2)} • ${_formatStatus(status)}',
                  style: TextStyle(
                    color: MarketplaceTheme.gray600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: MarketplaceTheme.gray400,
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickActionsCard() {
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
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Add Product',
                  Icons.add_box,
                  MarketplaceTheme.primaryBlue,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddProductScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Add Service',
                  Icons.work_outline,
                  MarketplaceTheme.primaryGreen,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddServiceScreen()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInventoryAlertsCard() {
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
            'Inventory Alerts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .where('vendorId', isEqualTo: userId)
                .where('inventory', isLessThan: 10)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MarketplaceTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: MarketplaceTheme.success),
                      const SizedBox(width: 12),
                      const Text('All products have sufficient stock'),
                    ],
                  ),
                );
              }
              
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Unknown Product';
                  final inventory = data['inventory'] ?? 0;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MarketplaceTheme.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: MarketplaceTheme.warning),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('$name - Only $inventory left in stock'),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildProductsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              const Text(
                'My Products & Services',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddProductServiceDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MarketplaceTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .where('vendorId', isEqualTo: userId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }
              
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final product = Product.fromJson(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  );
                  return _buildProductCard(product, doc.id);
                },
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: MarketplaceTheme.gray400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No products yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Start by adding your first product or service'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showAddProductServiceDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: MarketplaceTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Your First Item'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProductCard(Product product, String productId) {
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: product.images.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(product.images.first),
                    fit: BoxFit.cover,
                  )
                : null,
            color: product.images.isEmpty ? MarketplaceTheme.gray200 : null,
          ),
          child: product.images.isEmpty
              ? const Icon(Icons.inventory_2, color: Colors.grey)
              : null,
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('₳${product.price.toStringAsFixed(2)}'),
            Text(
              'Stock: ${product.inventory}',
              style: TextStyle(
                color: product.inventory < 10 
                    ? MarketplaceTheme.warning 
                    : MarketplaceTheme.success,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _editProduct(product, productId);
            } else if (value == 'delete') {
              _deleteProduct(productId);
            }
          },
        ),
      ),
    );
  }
  
  Widget _buildOrdersTab() {
    return VendorOrdersScreen(vendorId: userId);
  }
  
  Widget _buildAnalyticsTab() {
    return VendorAnalyticsScreen(vendorId: userId);
  }
  
  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () => _showAddProductServiceDialog(),
      backgroundColor: MarketplaceTheme.primaryBlue,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'Add Item',
        style: TextStyle(color: Colors.white),
      ),
    );
  }
  
  void _showAddProductServiceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'What would you like to add?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildAddOptionCard(
                    'Product',
                    'Physical or digital goods',
                    Icons.inventory_2,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddProductScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAddOptionCard(
                    'Service',
                    'Skills or professional services',
                    Icons.work_outline,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddServiceScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAddOptionCard(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MarketplaceTheme.gray50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MarketplaceTheme.gray200),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: MarketplaceTheme.primaryBlue),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: MarketplaceTheme.gray600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  void _editProduct(Product product, String productId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          product: product,
          productId: productId,
        ),
      ),
    );
  }
  
  Future<void> _deleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: MarketplaceTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .delete();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting product: $e')),
        );
      }
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
}
