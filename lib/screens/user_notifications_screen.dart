import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../models/notification.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_layout.dart';
import '../providers/auth_provider.dart';

class UserNotificationsScreen extends StatefulWidget {
  const UserNotificationsScreen({Key? key}) : super(key: key);

  @override
  State<UserNotificationsScreen> createState() => _UserNotificationsScreenState();
}

class _UserNotificationsScreenState extends State<UserNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      adminProvider.loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: const Text('Notifications', style: TextStyle(color: AppTheme.primaryGold)),
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
        child: adminProvider.isLoading
            ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold)))
            : adminProvider.notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none, size: 64, color: AppTheme.grey),
                        const SizedBox(height: 16),
                        Text('No notifications yet', style: AppTheme.headingMedium.copyWith(color: AppTheme.grey)),
                        const SizedBox(height: 8),
                        Text('You have no notifications at this time.', style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey.withOpacity(0.7))),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: adminProvider.notifications.length,
                    itemBuilder: (context, index) {
                      final notification = adminProvider.notifications[index];
                      return _buildNotificationCard(notification);
                    },
                  ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(_getNotificationIcon(notification.type), color: _getNotificationColor(notification.type)),
        title: Text(notification.title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(notification.message, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: notification.isRead
            ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
            : IconButton(
                icon: const Icon(Icons.mark_email_read, color: AppTheme.primaryGold),
                tooltip: 'Mark as read',
                onPressed: () => _markAsRead(notification),
              ),
        onTap: () => _showNotificationDetail(notification),
      ),
    );
  }

  void _markAsRead(NotificationModel notification) async {
    final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (userId == null) return;
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    await adminProvider.markNotificationAsRead(notification, userId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked as read: ${notification.title}'), backgroundColor: Colors.green),
      );
    }
  }

  void _showNotificationDetail(NotificationModel notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text(notification.title, style: TextStyle(color: AppTheme.primaryGold)),
        content: Text(notification.message, style: TextStyle(color: AppTheme.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppTheme.primaryGold)),
          ),
        ],
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'announcement':
        return Icons.campaign;
      case 'marketing':
        return Icons.campaign_outlined;
      case 'system':
        return Icons.settings;
      case 'transaction':
        return Icons.swap_horiz;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'announcement':
        return Colors.blue;
      case 'marketing':
        return Colors.orange;
      case 'system':
        return Colors.green;
      case 'transaction':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
} 