import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/marketplace_theme.dart';
import '../../providers/marketplace/marketplace_provider.dart';
import '../../models/marketplace/vendor_profile.dart';
import '../../models/marketplace/order.dart';

/// Advanced vendor dashboard inspired by professional platforms
class AdvancedVendorDashboard extends StatefulWidget {
  const AdvancedVendorDashboard({Key? key}) : super(key: key);

  @override
  State<AdvancedVendorDashboard> createState() => _AdvancedVendorDashboardState();
}

class _AdvancedVendorDashboardState extends State<AdvancedVendorDashboard>
    with TickerProviderStateMixin {
  
  late TabController _tabController;
  final PageController _pageController = PageController();
  int _selectedIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketplaceTheme.gray50,
      body: SafeArea(
        child: Row(
          children: [
            _buildSidebar(),
            Expanded(child: _buildMainContent()),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSidebar() {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: MarketplaceTheme.white,
        boxShadow: [MarketplaceTheme.mediumShadow],
      ),
      child: Column(
        children: [
          _buildVendorHeader(),
          const SizedBox(height: MarketplaceTheme.space6),
          _buildNavigationMenu(),
          const Spacer(),
          _buildQuickActions(),
          const SizedBox(height: MarketplaceTheme.space4),
        ],
      ),
    );
  }
  
  Widget _buildVendorHeader() {
    return Container(
      padding: const EdgeInsets.all(MarketplaceTheme.space6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [MarketplaceTheme.primaryBlue, MarketplaceTheme.primaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(MarketplaceTheme.radiusXl),
          bottomRight: Radius.circular(MarketplaceTheme.radiusXl),
        ),
      ),
      child: Column(
        children: [
          // Vendor avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: MarketplaceTheme.white.withAlpha(51),
                child: const Icon(
                  Icons.store,
                  size: 40,
                  color: MarketplaceTheme.white,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: MarketplaceTheme.success,
                    shape: BoxShape.circle,
                    boxShadow: [MarketplaceTheme.smallShadow],
                  ),
                  child: const Icon(
                    Icons.verified,
                    size: 16,
                    color: MarketplaceTheme.white,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: MarketplaceTheme.space3),
          
          const Text(
            'Tech Solutions Pro',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: MarketplaceTheme.white,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: MarketplaceTheme.space2),
          
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MarketplaceTheme.space3,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: MarketplaceTheme.white.withAlpha(51),
              borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star,
                  size: 14,
                  color: MarketplaceTheme.primaryOrange,
                ),
                SizedBox(width: 4),
                Text(
                  '4.8 (156 reviews)',
                  style: TextStyle(
                    fontSize: 12,
                    color: MarketplaceTheme.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNavigationMenu() {
    final menuItems = [
      {'icon': Icons.dashboard, 'title': 'Dashboard', 'index': 0},
      {'icon': Icons.inventory, 'title': 'My Listings', 'index': 1},
      {'icon': Icons.shopping_cart, 'title': 'Orders', 'index': 2},
      {'icon': Icons.chat, 'title': 'Messages', 'index': 3},
      {'icon': Icons.analytics, 'title': 'Analytics', 'index': 4},
      {'icon': Icons.settings, 'title': 'Settings', 'index': 5},
    ];
    
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: MarketplaceTheme.space4),
        itemCount: menuItems.length,
        itemBuilder: (context, index) {
          final item = menuItems[index];
          final isSelected = _selectedIndex == item['index'];
          
          return Container(
            margin: const EdgeInsets.only(bottom: MarketplaceTheme.space2),
            child: ListTile(
              leading: Icon(
                item['icon'] as IconData,
                color: isSelected 
                    ? MarketplaceTheme.primaryBlue 
                    : MarketplaceTheme.gray500,
              ),
              title: Text(
                item['title'] as String,
                style: MarketplaceTheme.bodyMedium.copyWith(
                  color: isSelected 
                      ? MarketplaceTheme.primaryBlue 
                      : MarketplaceTheme.gray700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedTileColor: MarketplaceTheme.primaryBlue.withAlpha(25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
              ),
              onTap: () {
                setState(() {
                  _selectedIndex = item['index'] as int;
                });
                _pageController.animateToPage(
                  _selectedIndex,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: MarketplaceTheme.space4),
      child: Column(
        children: [
          _buildQuickActionButton(
            'Add Product',
            Icons.add_box,
            MarketplaceTheme.primaryBlue,
            () => _showAddProductDialog(),
          ),
          const SizedBox(height: MarketplaceTheme.space2),
          _buildQuickActionButton(
            'Add Service',
            Icons.work_outline,
            MarketplaceTheme.primaryGreen,
            () => _showAddServiceDialog(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(MarketplaceTheme.space3),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
          border: Border.all(color: color.withAlpha(51)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: MarketplaceTheme.space2),
            Text(
              label,
              style: MarketplaceTheme.bodyMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMainContent() {
    return PageView(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      children: [
        _buildDashboardTab(),
        _buildListingsTab(),
        _buildOrdersTab(),
        _buildMessagesTab(),
        _buildAnalyticsTab(),
        _buildSettingsTab(),
      ],
    );
  }
  
  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MarketplaceTheme.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader('Dashboard', 'Welcome back! Here\'s your business overview'),
          const SizedBox(height: MarketplaceTheme.space6),
          
          // Key metrics row
          _buildMetricsRow(),
          const SizedBox(height: MarketplaceTheme.space6),
          
          // Charts and recent activity
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildRevenueChart(),
              ),
              const SizedBox(width: MarketplaceTheme.space4),
              Expanded(
                child: _buildRecentActivity(),
              ),
            ],
          ),
          
          const SizedBox(height: MarketplaceTheme.space6),
          
          // Recent orders and quick stats
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildRecentOrders(),
              ),
              const SizedBox(width: MarketplaceTheme.space4),
              Expanded(
                child: _buildQuickStats(),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildPageHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: MarketplaceTheme.headingLarge,
            ),
            const Spacer(),
            _buildHeaderActions(),
          ],
        ),
        const SizedBox(height: MarketplaceTheme.space2),
        Text(
          subtitle,
          style: MarketplaceTheme.bodyLarge.copyWith(
            color: MarketplaceTheme.gray500,
          ),
        ),
      ],
    );
  }
  
  Widget _buildHeaderActions() {
    return Row(
      children: [
        _buildHeaderButton(
          'Export Data',
          Icons.download,
          () => _exportData(),
        ),
        const SizedBox(width: MarketplaceTheme.space2),
        _buildHeaderButton(
          'Notifications',
          Icons.notifications_outlined,
          () => _showNotifications(),
          badge: '3',
        ),
      ],
    );
  }
  
  Widget _buildHeaderButton(
    String label,
    IconData icon,
    VoidCallback onTap, {
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MarketplaceTheme.space3,
          vertical: MarketplaceTheme.space2,
        ),
        decoration: BoxDecoration(
          color: MarketplaceTheme.white,
          borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
          border: Border.all(color: MarketplaceTheme.gray200),
          boxShadow: const [MarketplaceTheme.smallShadow],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: MarketplaceTheme.gray600,
                ),
                if (badge != null)
                  Positioned(
                    top: -8,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: MarketplaceTheme.error,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: MarketplaceTheme.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: MarketplaceTheme.space2),
            Text(
              label,
              style: MarketplaceTheme.labelMedium.copyWith(
                color: MarketplaceTheme.gray600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetricsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Total Revenue',
            '₳12,450',
            '+23%',
            Icons.trending_up,
            MarketplaceTheme.primaryGreen,
            isPositive: true,
          ),
        ),
        const SizedBox(width: MarketplaceTheme.space4),
        Expanded(
          child: _buildMetricCard(
            'Orders',
            '156',
            '+12%',
            Icons.shopping_cart,
            MarketplaceTheme.primaryBlue,
            isPositive: true,
          ),
        ),
        const SizedBox(width: MarketplaceTheme.space4),
        Expanded(
          child: _buildMetricCard(
            'Conversion Rate',
            '4.2%',
            '-2%',
            Icons.analytics,
            MarketplaceTheme.primaryOrange,
            isPositive: false,
          ),
        ),
        const SizedBox(width: MarketplaceTheme.space4),
        Expanded(
          child: _buildMetricCard(
            'Response Time',
            '2.4 hrs',
            '+0.5hrs',
            Icons.schedule,
            MarketplaceTheme.warning,
            isPositive: false,
          ),
        ),
      ],
    );
  }
  
  Widget _buildMetricCard(
    String title,
    String value,
    String change,
    IconData icon,
    Color color, {
    required bool isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(MarketplaceTheme.space4),
      decoration: MarketplaceTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(MarketplaceTheme.space2),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MarketplaceTheme.space2,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isPositive 
                      ? MarketplaceTheme.success.withAlpha(25)
                      : MarketplaceTheme.error.withAlpha(25),
                  borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 12,
                      color: isPositive 
                          ? MarketplaceTheme.success 
                          : MarketplaceTheme.error,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      change,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isPositive 
                            ? MarketplaceTheme.success 
                            : MarketplaceTheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: MarketplaceTheme.space3),
          
          Text(
            value,
            style: MarketplaceTheme.headingMedium,
          ),
          
          const SizedBox(height: 4),
          
          Text(
            title,
            style: MarketplaceTheme.bodyMedium.copyWith(
              color: MarketplaceTheme.gray500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRevenueChart() {
    return Container(
      padding: const EdgeInsets.all(MarketplaceTheme.space4),
      decoration: MarketplaceTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Revenue Overview',
                style: MarketplaceTheme.titleLarge,
              ),
              const Spacer(),
              _buildChartPeriodSelector(),
            ],
          ),
          
          const SizedBox(height: MarketplaceTheme.space4),
          
          // Chart placeholder - would integrate with actual chart library
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: MarketplaceTheme.gray50,
              borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
            ),
            child: const Center(
              child: Text(
                'Revenue Chart\n(Chart library integration needed)',
                textAlign: TextAlign.center,
                style: MarketplaceTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildChartPeriodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: MarketplaceTheme.gray100,
        borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPeriodOption('7D', true),
          _buildPeriodOption('30D', false),
          _buildPeriodOption('90D', false),
        ],
      ),
    );
  }
  
  Widget _buildPeriodOption(String period, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MarketplaceTheme.space3,
        vertical: MarketplaceTheme.space2,
      ),
      decoration: BoxDecoration(
        color: isSelected ? MarketplaceTheme.primaryBlue : Colors.transparent,
        borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
      ),
      child: Text(
        period,
        style: MarketplaceTheme.labelMedium.copyWith(
          color: isSelected 
              ? MarketplaceTheme.white 
              : MarketplaceTheme.gray600,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
  
  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(MarketplaceTheme.space4),
      decoration: MarketplaceTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: MarketplaceTheme.titleLarge,
          ),
          
          const SizedBox(height: MarketplaceTheme.space4),
          
          ...List.generate(5, (index) {
            final activities = [
              {'title': 'New order received', 'time': '2 min ago', 'icon': Icons.shopping_cart, 'color': MarketplaceTheme.success},
              {'title': 'Product view increased', 'time': '5 min ago', 'icon': Icons.visibility, 'color': MarketplaceTheme.info},
              {'title': 'Review submitted', 'time': '1 hour ago', 'icon': Icons.star, 'color': MarketplaceTheme.primaryOrange},
              {'title': 'Message from buyer', 'time': '2 hours ago', 'icon': Icons.chat, 'color': MarketplaceTheme.primaryBlue},
              {'title': 'Payment received', 'time': '3 hours ago', 'icon': Icons.payment, 'color': MarketplaceTheme.primaryGreen},
            ];
            
            final activity = activities[index];
            
            return Container(
              margin: const EdgeInsets.only(bottom: MarketplaceTheme.space3),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(MarketplaceTheme.space2),
                    decoration: BoxDecoration(
                      color: (activity['color'] as Color).withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      activity['icon'] as IconData,
                      size: 16,
                      color: activity['color'] as Color,
                    ),
                  ),
                  
                  const SizedBox(width: MarketplaceTheme.space3),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity['title'] as String,
                          style: MarketplaceTheme.bodyMedium,
                        ),
                        Text(
                          activity['time'] as String,
                          style: MarketplaceTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
  
  // Placeholder widgets for other tabs
  Widget _buildListingsTab() {
    return const Center(
      child: Text(
        'Listings Management\n(To be implemented)',
        textAlign: TextAlign.center,
        style: MarketplaceTheme.headingMedium,
      ),
    );
  }
  
  Widget _buildOrdersTab() {
    return const Center(
      child: Text(
        'Orders Management\n(To be implemented)',
        textAlign: TextAlign.center,
        style: MarketplaceTheme.headingMedium,
      ),
    );
  }
  
  Widget _buildMessagesTab() {
    return const Center(
      child: Text(
        'Messages Center\n(To be implemented)',
        textAlign: TextAlign.center,
        style: MarketplaceTheme.headingMedium,
      ),
    );
  }
  
  Widget _buildAnalyticsTab() {
    return const Center(
      child: Text(
        'Advanced Analytics\n(To be implemented)',
        textAlign: TextAlign.center,
        style: MarketplaceTheme.headingMedium,
      ),
    );
  }
  
  Widget _buildSettingsTab() {
    return const Center(
      child: Text(
        'Vendor Settings\n(To be implemented)',
        textAlign: TextAlign.center,
        style: MarketplaceTheme.headingMedium,
      ),
    );
  }
  
  Widget _buildRecentOrders() {
    return Container(
      padding: const EdgeInsets.all(MarketplaceTheme.space4),
      decoration: MarketplaceTheme.cardDecoration,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Orders',
            style: MarketplaceTheme.titleLarge,
          ),
          SizedBox(height: MarketplaceTheme.space4),
          Center(
            child: Text(
              'Order list will be implemented here',
              style: MarketplaceTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(MarketplaceTheme.space4),
      decoration: MarketplaceTheme.cardDecoration,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Stats',
            style: MarketplaceTheme.titleLarge,
          ),
          SizedBox(height: MarketplaceTheme.space4),
          Center(
            child: Text(
              'Additional stats will be implemented here',
              style: MarketplaceTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
  
  // Action methods
  void _showAddProductDialog() {
    // TODO: Implement add product dialog
  }
  
  void _showAddServiceDialog() {
    // TODO: Implement add service dialog
  }
  
  void _exportData() {
    // TODO: Implement data export
  }
  
  void _showNotifications() {
    // TODO: Show notifications
  }
}
