import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/admin_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive_layout.dart';
import 'notifications/admin_notifications_screen.dart';
import 'announcements/admin_announcements_screen.dart';
import 'content/admin_content_screen.dart';
import 'users/admin_users_screen.dart';
import 'analytics/admin_analytics_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      adminProvider.initializeAdminStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);

    if (!adminProvider.isAdmin) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.black, Color(0xFF212121)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  size: 80,
                  color: AppTheme.primaryGold,
                ),
                const SizedBox(height: 24),
                Text(
                  'Access Denied',
                  style: AppTheme.headingLarge.copyWith(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'You do not have admin privileges.',
                  style: AppTheme.bodyLarge.copyWith(color: AppTheme.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.black, Color(0xFF212121)],
          ),
        ),
        child: SafeArea(
          child: ResponsiveContainer(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveLayout.getValueForScreenType<double>(
                context: context,
                mobile: 16.0,
                tablet: 24.0,
                desktop: 32.0,
                largeDesktop: 40.0,
              ),
              vertical: 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDesktop),
                const SizedBox(height: 32),
                Expanded(
                  child: isDesktop 
                      ? _buildDesktopLayout()
                      : _buildMobileTabletLayout(isTablet),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Row(
      children: [
        Icon(
          Icons.admin_panel_settings,
          color: AppTheme.primaryGold,
          size: isDesktop ? 40 : 32,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Dashboard',
                style: (isDesktop 
                    ? AppTheme.headingLarge.copyWith(fontSize: 32)
                    : AppTheme.headingLarge).copyWith(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Manage your application',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.grey,
                  fontSize: isDesktop ? 18 : null,
                ),
              ),
            ],
          ),
        ),
        if (isDesktop)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
            ),
            child: Text(
              'Admin',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.primaryGold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    ).animate().fadeIn(duration: const Duration(milliseconds: 600));
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left sidebar with navigation
        Container(
          width: 280,
          margin: const EdgeInsets.only(right: 32),
          child: _buildNavigationCards(),
        ),
        // Right content area
        Expanded(
          child: _buildQuickStats(),
        ),
      ],
    );
  }

  Widget _buildMobileTabletLayout(bool isTablet) {
    return Column(
      children: [
        _buildQuickStats(),
        const SizedBox(height: 24),
        Expanded(child: _buildNavigationCards()),
      ],
    );
  }

  Widget _buildNavigationCards() {
    final adminProvider = Provider.of<AdminProvider>(context);
    
    return GridView.count(
      crossAxisCount: ResponsiveLayout.isDesktop(context) ? 1 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: ResponsiveLayout.isDesktop(context) ? 4 : 1.2,
      children: [
        _buildNavigationCard(
          icon: Icons.notifications,
          title: 'Notifications',
          subtitle: 'Send notifications to users',
          color: Colors.blue,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminNotificationsScreen(),
            ),
          ),
        ),
        _buildNavigationCard(
          icon: Icons.announcement,
          title: 'Announcements',
          subtitle: 'Manage homepage announcements',
          color: Colors.orange,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminAnnouncementsScreen(),
            ),
          ),
        ),
        _buildNavigationCard(
          icon: Icons.article,
          title: 'Content',
          subtitle: 'Manage explore screen content',
          color: Colors.green,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminContentScreen(),
            ),
          ),
        ),
        _buildNavigationCard(
          icon: Icons.people,
          title: 'Users',
          subtitle: 'Manage user accounts',
          color: Colors.purple,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminUsersScreen(),
            ),
          ),
        ),
        _buildNavigationCard(
          icon: Icons.analytics,
          title: 'Analytics',
          subtitle: 'View app statistics',
          color: Colors.red,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminAnalyticsScreen(),
            ),
          ),
        ),
        if (adminProvider.isSuperAdmin())
          _buildNavigationCard(
            icon: Icons.settings,
            title: 'Settings',
            subtitle: 'System configuration',
            color: Colors.teal,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings coming soon!')),
              );
            },
          ),
      ],
    );
  }

  Widget _buildNavigationCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 8,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: ResponsiveLayout.isDesktop(context)
              ? Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTheme.headingSmall.copyWith(
                              color: AppTheme.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.black.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: color,
                      size: 16,
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.black,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
        ),
      ),
    ).animate().fadeIn(
      duration: const Duration(milliseconds: 600),
      delay: const Duration(milliseconds: 200),
    );
  }

  Widget _buildQuickStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Stats',
          style: AppTheme.headingMedium.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.darkGrey.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.grey.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.people,
                  label: 'Total Users',
                  value: '1,234',
                  color: Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.notifications,
                  label: 'Notifications',
                  value: '56',
                  color: Colors.orange,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.article,
                  label: 'Content Items',
                  value: '89',
                  color: Colors.green,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.trending_up,
                  label: 'Active Users',
                  value: '789',
                  color: Colors.purple,
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(
      duration: const Duration(milliseconds: 600),
      delay: const Duration(milliseconds: 400),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: AppTheme.headingMedium.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
} 