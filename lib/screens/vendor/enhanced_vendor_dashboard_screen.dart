import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../../providers/marketplace_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/order.dart';
import 'product_management_screen.dart';
import 'service_management_screen.dart';
import 'vendor_orders_screen.dart';
import 'package:intl/intl.dart';

/// Enhanced vendor dashboard with real-time order management
class EnhancedVendorDashboardScreen extends StatefulWidget {
  const EnhancedVendorDashboardScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedVendorDashboardScreen> createState() => _EnhancedVendorDashboardScreenState();
}

class _EnhancedVendorDashboardScreenState extends State<EnhancedVendorDashboardScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final marketplace = Provider.of<MarketplaceProvider>(context, listen: false);
    await marketplace.refreshOrders();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('You must be logged in as a vendor.')),
      );
    }

    return Consumer<MarketplaceProvider>(
      builder: (context, marketplace, _) {
        return Scaffold(
          backgroundColor: AppTheme.black,
          appBar: AppBar(
            backgroundColor: AppTheme.black,
            elevation: 0,
            title: Row(
              children: [
                Icon(Icons.store, color: AppTheme.primaryGold, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Vendor Dashboard',
                  style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () => _loadDashboardData(),
                icon: Icon(
                  Icons.refresh,
                  color: AppTheme.primaryGold,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryGold),
                )
              : FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('USER').doc(user.uid).get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryGold),
                      );
                    }
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Center(
                        child: Text(
                          'User data not found.',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    final userData = snapshot.data!.data() as Map<String, dynamic>;
                    final stats = marketplace.getVendorOrderStats();
                    final recentActivity = marketplace.getRecentOrderActivity(limit: 8);

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 700;
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Enhanced Balance Cards
                              _buildBalanceSection(userData, stats),
                              
                              const SizedBox(height: 24),
                              
                              // Order Analytics
                              _buildOrderAnalytics(stats, isMobile),
                              
                              const SizedBox(height: 24),
                              
                              // Quick Actions
                              _buildQuickActions(context, isMobile),
                              
                              const SizedBox(height: 24),
                              
                              // Recent Order Activity
                              _buildRecentActivity(recentActivity),
                              
                              const SizedBox(height: 24),
                              
                              // Pending Orders Section
                              _buildPendingOrdersSection(marketplace),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildBalanceSection(Map<String, dynamic> userData, Map<String, dynamic> stats) {
    final available = (userData['akofaBalance'] ?? 0.0).toDouble();
    final pending = (userData['pendingBalance'] ?? 0.0).toDouble();
    final totalRevenue = (stats['totalRevenue'] ?? 0.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Financial Overview',
          style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildBalanceCard(
              'Available',
              '₳${available.toStringAsFixed(2)}',
              Icons.account_balance_wallet,
              AppTheme.primaryGold,
            ),
            _buildBalanceCard(
              'Pending',
              '₳${pending.toStringAsFixed(2)}',
              Icons.pending_actions,
              Colors.orange,
            ),
            _buildBalanceCard(
              'Total Revenue',
              '₳${totalRevenue.toStringAsFixed(2)}',
              Icons.trending_up,
              AppTheme.successGreen,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceCard(String title, String amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: AppTheme.headingSmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderAnalytics(Map<String, dynamic> stats, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Analytics',
          style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isMobile ? 2 : 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isMobile ? 1.8 : 1.5,
          children: [
            _buildStatCard(
              'Total Orders',
              stats['totalOrders'].toString(),
              Icons.shopping_bag,
              Colors.blue,
            ),
            _buildStatCard(
              'Pending',
              stats['pendingOrders'].toString(),
              Icons.schedule,
              Colors.orange,
            ),
            _buildStatCard(
              'Processing',
              stats['processingOrders'].toString(),
              Icons.settings,
              Colors.purple,
            ),
            _buildStatCard(
              'Completed',
              stats['completedOrders'].toString(),
              Icons.check_circle,
              AppTheme.successGreen,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.headingMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isMobile ? 2 : 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isMobile ? 2.5 : 2.0,
          children: [
            _buildActionCard(
              'Manage Products',
              Icons.inventory,
              AppTheme.primaryGold,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductManagementScreen()),
              ),
            ),
            _buildActionCard(
              'Manage Services',
              Icons.design_services,
              Colors.purple,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ServiceManagementScreen()),
              ),
            ),
            _buildActionCard(
              'View Orders',
              Icons.list_alt,
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => VendorOrdersScreen(vendorId: FirebaseAuth.instance.currentUser!.uid)),
              ),
            ),
            _buildActionCard(
              'Analytics',
              Icons.analytics,
              AppTheme.successGreen,
              () => _showAnalyticsDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkGrey,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTheme.bodyMedium.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(List<Map<String, dynamic>> activities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => VendorOrdersScreen(vendorId: FirebaseAuth.instance.currentUser!.uid)),
              ),
              child: Text(
                'View All',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryGold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.darkGrey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: activities.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No recent activity',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                    ),
                  ),
                )
              : Column(
                  children: activities.take(5).map((activity) {
                    final timestamp = activity['timestamp'] as DateTime;
                    final event = activity['event'];
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryGold.withOpacity(0.2),
                        child: Icon(
                          _getActivityIcon(activity['type']),
                          color: AppTheme.primaryGold,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        event['details'] ?? 'Order activity',
                        style: AppTheme.bodyMedium.copyWith(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _formatTimestamp(timestamp),
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        color: AppTheme.grey,
                        size: 16,
                      ),
                      onTap: () {
                        // Navigate to order details
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => VendorOrdersScreen(vendorId: FirebaseAuth.instance.currentUser!.uid)),
                        );
                      },
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildPendingOrdersSection(MarketplaceProvider marketplace) {
    final pendingOrders = marketplace.vendorOrders
        .where((order) => order.status == OrderStatus.pending)
        .take(3)
        .toList();

    if (pendingOrders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pending Orders - Immediate Action Required',
          style: AppTheme.headingMedium.copyWith(color: Colors.orange),
        ),
        const SizedBox(height: 16),
        ...pendingOrders.map((order) => _buildPendingOrderCard(order, marketplace)),
      ],
    );
  }

  Widget _buildPendingOrderCard(Order order, MarketplaceProvider marketplace) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #${order.id.substring(0, 8)}',
                style: AppTheme.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₳${order.totalAmount.toStringAsFixed(2)}',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${order.items.length} item(s) - ${_formatTimestamp(order.createdAt)}',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await marketplace.updateOrderStatus(
                      orderId: order.id,
                      newStatus: OrderStatus.confirmed,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Accept'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await marketplace.updateOrderStatus(
                      orderId: order.id,
                      newStatus: OrderStatus.cancelled,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text('Decline'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'product_order':
        return Icons.shopping_bag;
      case 'service_order':
        return Icons.design_services;
      default:
        return Icons.receipt;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d, y').format(timestamp);
    }
  }

  void _showAnalyticsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text(
          'Analytics',
          style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
        ),
        content: Text(
          'Detailed analytics feature coming soon!',
          style: AppTheme.bodyMedium.copyWith(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryGold),
            ),
          ),
        ],
      ),
    );
  }
}
