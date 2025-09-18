import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/marketplace_theme.dart';
import '../../providers/marketplace/marketplace_provider.dart';

/// Advanced admin dashboard with comprehensive analytics and controls
class AdvancedAdminDashboard extends StatefulWidget {
  const AdvancedAdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdvancedAdminDashboard> createState() => _AdvancedAdminDashboardState();
}

class _AdvancedAdminDashboardState extends State<AdvancedAdminDashboard>
    with TickerProviderStateMixin {
  
  late TabController _tabController;
  int _selectedIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
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
      width: 300,
      decoration: const BoxDecoration(
        color: MarketplaceTheme.white,
        boxShadow: [MarketplaceTheme.mediumShadow],
      ),
      child: Column(
        children: [
          _buildAdminHeader(),
          const SizedBox(height: MarketplaceTheme.space6),
          _buildNavigationMenu(),
          const Spacer(),
          _buildSystemStatus(),
          const SizedBox(height: MarketplaceTheme.space4),
        ],
      ),
    );
  }
  
  Widget _buildAdminHeader() {
    return Container(
      padding: const EdgeInsets.all(MarketplaceTheme.space6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MarketplaceTheme.gray800,
            MarketplaceTheme.gray900,
          ],
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
          Container(
            padding: const EdgeInsets.all(MarketplaceTheme.space3),
            decoration: BoxDecoration(
              color: MarketplaceTheme.white.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              size: 40,
              color: MarketplaceTheme.white,
            ),
          ),
          
          const SizedBox(height: MarketplaceTheme.space3),
          
          const Text(
            'Admin Dashboard',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: MarketplaceTheme.white,
            ),
          ),
          
          const SizedBox(height: MarketplaceTheme.space2),
          
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MarketplaceTheme.space3,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: MarketplaceTheme.success.withAlpha(51),
              borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
            ),
            child: const Text(
              'System Operational',
              style: TextStyle(
                fontSize: 12,
                color: MarketplaceTheme.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNavigationMenu() {
    final menuItems = [
      {'icon': Icons.dashboard, 'title': 'Overview', 'index': 0, 'badge': null},
      {'icon': Icons.people, 'title': 'Users', 'index': 1, 'badge': '12'},
      {'icon': Icons.store, 'title': 'Vendors', 'index': 2, 'badge': '3'},
      {'icon': Icons.shopping_cart, 'title': 'Orders', 'index': 3, 'badge': '45'},
      {'icon': Icons.report_problem, 'title': 'Reports', 'index': 4, 'badge': '7'},
      {'icon': Icons.analytics, 'title': 'Analytics', 'index': 5, 'badge': null},
      {'icon': Icons.settings, 'title': 'System', 'index': 6, 'badge': null},
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
              trailing: item['badge'] != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: MarketplaceTheme.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item['badge'] as String,
                        style: const TextStyle(
                          color: MarketplaceTheme.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : null,
              selected: isSelected,
              selectedTileColor: MarketplaceTheme.primaryBlue.withAlpha(25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
              ),
              onTap: () {
                setState(() {
                  _selectedIndex = item['index'] as int;
                });
              },
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildSystemStatus() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: MarketplaceTheme.space4),
      padding: const EdgeInsets.all(MarketplaceTheme.space4),
      decoration: BoxDecoration(
        color: MarketplaceTheme.success.withAlpha(25),
        borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
        border: Border.all(color: MarketplaceTheme.success.withAlpha(51)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: MarketplaceTheme.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: MarketplaceTheme.space2),
              const Text(
                'All Systems Online',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MarketplaceTheme.success,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: MarketplaceTheme.space2),
          
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Uptime: 99.9%',
                style: TextStyle(
                  fontSize: 12,
                  color: MarketplaceTheme.gray600,
                ),
              ),
              Text(
                'Response: 45ms',
                style: TextStyle(
                  fontSize: 12,
                  color: MarketplaceTheme.gray600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildMainContent() {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        _buildOverviewTab(),
        _buildUsersTab(),
        _buildVendorsTab(),
        _buildOrdersTab(),
        _buildReportsTab(),
        _buildAnalyticsTab(),
        _buildSystemTab(),
      ],
    );
  }
  
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MarketplaceTheme.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            'System Overview',
            'Monitor your marketplace performance and health',
          ),
          
          const SizedBox(height: MarketplaceTheme.space6),
          
          // Key metrics
          _buildOverviewMetrics(),
          
          const SizedBox(height: MarketplaceTheme.space6),
          
          // Charts and activity
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildSystemHealthChart(),
              ),
              const SizedBox(width: MarketplaceTheme.space4),
              Expanded(
                child: _buildRecentAlerts(),
              ),
            ],
          ),
          
          const SizedBox(height: MarketplaceTheme.space6),
          
          // Platform stats
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildPlatformStats(),
              ),
              const SizedBox(width: MarketplaceTheme.space4),
              Expanded(
                child: _buildTopPerformers(),
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
        _buildActionButton(
          'Generate Report',
          Icons.assessment,
          () => _generateReport(),
        ),
        const SizedBox(width: MarketplaceTheme.space2),
        _buildActionButton(
          'System Logs',
          Icons.list_alt,
          () => _viewSystemLogs(),
        ),
        const SizedBox(width: MarketplaceTheme.space2),
        _buildActionButton(
          'Backup',
          Icons.backup,
          () => _initiateBackup(),
        ),
      ],
    );
  }
  
  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
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
            Icon(
              icon,
              size: 16,
              color: MarketplaceTheme.gray600,
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
  
  Widget _buildOverviewMetrics() {
    return Row(
      children: [
        Expanded(
          child: _buildAdminMetricCard(
            'Total Users',
            '12,453',
            '+8.2%',
            Icons.people,
            MarketplaceTheme.primaryBlue,
            true,
          ),
        ),
        const SizedBox(width: MarketplaceTheme.space4),
        Expanded(
          child: _buildAdminMetricCard(
            'Active Vendors',
            '1,234',
            '+12%',
            Icons.store,
            MarketplaceTheme.primaryGreen,
            true,
          ),
        ),
        const SizedBox(width: MarketplaceTheme.space4),
        Expanded(
          child: _buildAdminMetricCard(
            'Total GMV',
            '₳456K',
            '+23%',
            Icons.trending_up,
            MarketplaceTheme.success,
            true,
          ),
        ),
        const SizedBox(width: MarketplaceTheme.space4),
        Expanded(
          child: _buildAdminMetricCard(
            'System Load',
            '67%',
            '+5%',
            Icons.memory,
            MarketplaceTheme.warning,
            false,
          ),
        ),
      ],
    );
  }
  
  Widget _buildAdminMetricCard(
    String title,
    String value,
    String change,
    IconData icon,
    Color color,
    bool isPositive,
  ) {
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
  
  Widget _buildSystemHealthChart() {
    return Container(
      padding: const EdgeInsets.all(MarketplaceTheme.space4),
      decoration: MarketplaceTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Health',
            style: MarketplaceTheme.titleLarge,
          ),
          
          const SizedBox(height: MarketplaceTheme.space4),
          
          // Health indicators
          Row(
            children: [
              _buildHealthIndicator('API', 99.9, MarketplaceTheme.success),
              const SizedBox(width: MarketplaceTheme.space3),
              _buildHealthIndicator('Database', 98.5, MarketplaceTheme.success),
              const SizedBox(width: MarketplaceTheme.space3),
              _buildHealthIndicator('Storage', 95.2, MarketplaceTheme.warning),
              const SizedBox(width: MarketplaceTheme.space3),
              _buildHealthIndicator('Payment', 99.7, MarketplaceTheme.success),
            ],
          ),
          
          const SizedBox(height: MarketplaceTheme.space4),
          
          // Chart placeholder
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: MarketplaceTheme.gray50,
              borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
            ),
            child: const Center(
              child: Text(
                'System Health Chart\n(Real-time monitoring)',
                textAlign: TextAlign.center,
                style: MarketplaceTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHealthIndicator(String name, double percentage, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            name,
            style: MarketplaceTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: MarketplaceTheme.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: MarketplaceTheme.gray200,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecentAlerts() {
    return Container(
      padding: const EdgeInsets.all(MarketplaceTheme.space4),
      decoration: MarketplaceTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Recent Alerts',
                style: MarketplaceTheme.titleLarge,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: MarketplaceTheme.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '3',
                  style: TextStyle(
                    color: MarketplaceTheme.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: MarketplaceTheme.space4),
          
          ...List.generate(4, (index) {
            final alerts = [
              {'title': 'High CPU usage detected', 'time': '5 min ago', 'severity': 'high'},
              {'title': 'New vendor registration', 'time': '12 min ago', 'severity': 'info'},
              {'title': 'Payment gateway timeout', 'time': '1 hour ago', 'severity': 'medium'},
              {'title': 'Backup completed successfully', 'time': '3 hours ago', 'severity': 'low'},
            ];
            
            final alert = alerts[index];
            final color = _getAlertColor(alert['severity'] as String);
            
            return Container(
              margin: const EdgeInsets.only(bottom: MarketplaceTheme.space3),
              padding: const EdgeInsets.all(MarketplaceTheme.space3),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
                border: Border.all(color: color.withAlpha(51)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  
                  const SizedBox(width: MarketplaceTheme.space2),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert['title'] as String,
                          style: MarketplaceTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          alert['time'] as String,
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
  
  Color _getAlertColor(String severity) {
    switch (severity) {
      case 'high':
        return MarketplaceTheme.error;
      case 'medium':
        return MarketplaceTheme.warning;
      case 'low':
        return MarketplaceTheme.success;
      default:
        return MarketplaceTheme.info;
    }
  }
  
  // Placeholder widgets for other tabs
  Widget _buildUsersTab() {
    return _buildPlaceholderTab('User Management', 'Manage platform users, roles, and permissions');
  }
  
  Widget _buildVendorsTab() {
    return _buildPlaceholderTab('Vendor Management', 'Review vendor applications and manage vendor accounts');
  }
  
  Widget _buildOrdersTab() {
    return _buildPlaceholderTab('Order Management', 'Monitor and manage marketplace orders and disputes');
  }
  
  Widget _buildReportsTab() {
    return _buildPlaceholderTab('Reports & Moderation', 'Handle user reports and content moderation');
  }
  
  Widget _buildAnalyticsTab() {
    return _buildPlaceholderTab('Advanced Analytics', 'Deep dive into marketplace performance metrics');
  }
  
  Widget _buildSystemTab() {
    return _buildPlaceholderTab('System Settings', 'Configure platform settings and integrations');
  }
  
  Widget _buildPlaceholderTab(String title, String description) {
    return Padding(
      padding: const EdgeInsets.all(MarketplaceTheme.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: MarketplaceTheme.headingLarge,
          ),
          const SizedBox(height: MarketplaceTheme.space2),
          Text(
            description,
            style: MarketplaceTheme.bodyLarge.copyWith(
              color: MarketplaceTheme.gray500,
            ),
          ),
          const SizedBox(height: MarketplaceTheme.space6),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: MarketplaceTheme.white,
                borderRadius: BorderRadius.circular(MarketplaceTheme.radiusXl),
                border: Border.all(color: MarketplaceTheme.gray200),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.construction,
                      size: 64,
                      color: MarketplaceTheme.gray400,
                    ),
                    const SizedBox(height: MarketplaceTheme.space4),
                    Text(
                      'Coming Soon',
                      style: MarketplaceTheme.headingMedium.copyWith(
                        color: MarketplaceTheme.gray500,
                      ),
                    ),
                    const SizedBox(height: MarketplaceTheme.space2),
                    Text(
                      'This section will be implemented in the next phase',
                      style: MarketplaceTheme.bodyMedium.copyWith(
                        color: MarketplaceTheme.gray400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPlatformStats() {
    return Container(
      padding: const EdgeInsets.all(MarketplaceTheme.space4),
      decoration: MarketplaceTheme.cardDecoration,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Platform Statistics',
            style: MarketplaceTheme.titleLarge,
          ),
          SizedBox(height: MarketplaceTheme.space4),
          Center(
            child: Text(
              'Detailed platform stats will be implemented here',
              style: MarketplaceTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTopPerformers() {
    return Container(
      padding: const EdgeInsets.all(MarketplaceTheme.space4),
      decoration: MarketplaceTheme.cardDecoration,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Performers',
            style: MarketplaceTheme.titleLarge,
          ),
          SizedBox(height: MarketplaceTheme.space4),
          Center(
            child: Text(
              'Top vendor and product stats will be implemented here',
              style: MarketplaceTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
  
  // Action methods
  void _generateReport() {
  }
  
  void _viewSystemLogs() {
  }
  
  void _initiateBackup() {
  }
}
