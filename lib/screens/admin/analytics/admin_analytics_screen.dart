import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/admin_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/responsive_layout.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).loadAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final analytics = Provider.of<AdminProvider>(context).analytics;
    final isLoading = Provider.of<AdminProvider>(context).isLoading;
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: const Text('Analytics', style: TextStyle(color: AppTheme.primaryGold)),
        iconTheme: const IconThemeData(color: AppTheme.primaryGold),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.black, Color(0xFF212121)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveLayout.getValueForScreenType<double>(
                context: context,
                mobile: 8.0,
                tablet: 24.0,
                desktop: 32.0,
                largeDesktop: 40.0,
              ),
              vertical: 16.0,
            ),
            child: isLoading
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold)))
                : analytics.isEmpty
                    ? Center(child: Text('No analytics data.', style: TextStyle(color: AppTheme.grey)))
                    : _buildAnalyticsGrid(analytics, isDesktop),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsGrid(Map<String, dynamic> analytics, bool isDesktop) {
    final items = [
      _buildStatCard('Total Users', analytics['totalUsers']?.toString() ?? '-', Icons.people, Colors.blue),
      _buildStatCard('Active Users', analytics['activeUsers']?.toString() ?? '-', Icons.person, Colors.green),
      _buildStatCard('Users with Wallets', analytics['usersWithWallets']?.toString() ?? '-', Icons.account_balance_wallet, Colors.purple),
      _buildStatCard('Admin Users', analytics['adminUsers']?.toString() ?? '-', Icons.admin_panel_settings, Colors.orange),
      _buildStatCard('Notifications', analytics['totalNotifications']?.toString() ?? '-', Icons.notifications, Colors.teal),
      _buildStatCard('Announcements', analytics['totalAnnouncements']?.toString() ?? '-', Icons.announcement, Colors.red),
      _buildStatCard('Content Items', analytics['totalContent']?.toString() ?? '-', Icons.article, Colors.amber),
      _buildStatCard('Published Content', analytics['publishedContent']?.toString() ?? '-', Icons.publish, Colors.cyan),
    ];
    return GridView.count(
      crossAxisCount: isDesktop ? 4 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: items,
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 16),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryGold)),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: AppTheme.white)),
          ],
        ),
      ),
    );
  }
} 