import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../theme/marketplace_theme.dart';
import '../services/notification_service.dart';

/// Comprehensive notifications screen with real-time updates
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  
  late TabController _tabController;
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          StreamBuilder<int>(
            stream: NotificationService.getUnreadCount(userId),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              if (unreadCount > 0) {
                return TextButton(
                  onPressed: _markAllAsRead,
                  child: Text('Mark all read ($unreadCount)'),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Text('Mark all as read'),
              ),
              const PopupMenuItem(
                value: 'delete_all',
                child: Text('Delete all'),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Text('Notification settings'),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: MarketplaceTheme.primaryBlue,
          unselectedLabelColor: MarketplaceTheme.gray500,
          indicatorColor: MarketplaceTheme.primaryBlue,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Orders'),
            Tab(text: 'Messages'),
            Tab(text: 'Payments'),
            Tab(text: 'Promotions'),
            Tab(text: 'System'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationsList(null), // All notifications
          _buildNotificationsList(NotificationType.order),
          _buildNotificationsList(NotificationType.message),
          _buildNotificationsList(NotificationType.payment),
          _buildNotificationsList(NotificationType.promotion),
          _buildNotificationsList(NotificationType.system),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(NotificationType? filterType) {
    return StreamBuilder<List<NotificationModel>>(
      stream: NotificationService.getUserNotifications(userId: userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(filterType);
        }
        
        final notifications = filterType != null
            ? snapshot.data!.where((n) => n.type == filterType).toList()
            : snapshot.data!;
        
        if (notifications.isEmpty) {
          return _buildEmptyState(filterType);
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return _buildNotificationCard(notification);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(NotificationType? filterType) {
    final typeText = filterType != null ? _getTypeDisplayName(filterType) : 'notifications';
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getTypeIcon(filterType),
            size: 80,
            color: MarketplaceTheme.gray400,
          ),
          const SizedBox(height: 24),
          Text(
            'No $typeText yet',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see $typeText here when they arrive',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.white : MarketplaceTheme.primaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notification.isRead ? MarketplaceTheme.gray200 : MarketplaceTheme.primaryBlue.withOpacity(0.2),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: _buildNotificationIcon(notification),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              notification.message,
              style: TextStyle(
                color: MarketplaceTheme.gray600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: MarketplaceTheme.gray500,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTime(notification.createdAt),
                  style: TextStyle(
                    color: MarketplaceTheme.gray500,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (!notification.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: MarketplaceTheme.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
        onTap: () => _handleNotificationTap(notification),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleNotificationAction(action, notification),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: notification.isRead ? 'mark_unread' : 'mark_read',
              child: Text(notification.isRead ? 'Mark as unread' : 'Mark as read'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(NotificationModel notification) {
    Color backgroundColor;
    IconData iconData;
    Color iconColor = Colors.white;
    
    switch (notification.type) {
      case NotificationType.order:
        backgroundColor = MarketplaceTheme.primaryBlue;
        iconData = Icons.shopping_bag;
        break;
      case NotificationType.message:
        backgroundColor = MarketplaceTheme.primaryGreen;
        iconData = Icons.message;
        break;
      case NotificationType.payment:
        backgroundColor = const Color(0xFFFFD700); // Gold
        iconData = Icons.payment;
        break;
      case NotificationType.verification:
        backgroundColor = MarketplaceTheme.success;
        iconData = Icons.verified;
        break;
      case NotificationType.promotion:
        backgroundColor = MarketplaceTheme.primaryOrange;
        iconData = Icons.local_offer;
        break;
      case NotificationType.system:
        backgroundColor = MarketplaceTheme.info;
        iconData = Icons.info;
        break;
      default:
        backgroundColor = MarketplaceTheme.gray500;
        iconData = Icons.notifications;
    }
    
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24,
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(dateTime);
    }
  }

  IconData _getTypeIcon(NotificationType? type) {
    switch (type) {
      case NotificationType.order:
        return Icons.shopping_bag;
      case NotificationType.message:
        return Icons.message;
      case NotificationType.payment:
        return Icons.payment;
      case NotificationType.promotion:
        return Icons.local_offer;
      case NotificationType.system:
        return Icons.settings;
      default:
        return Icons.notifications;
    }
  }

  String _getTypeDisplayName(NotificationType type) {
    switch (type) {
      case NotificationType.order:
        return 'order notifications';
      case NotificationType.message:
        return 'messages';
      case NotificationType.payment:
        return 'payment notifications';
      case NotificationType.promotion:
        return 'promotions';
      case NotificationType.system:
        return 'system notifications';
      default:
        return 'notifications';
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    // Mark as read
    if (!notification.isRead) {
      NotificationService.markAsRead(notification.id);
    }
    
    // Handle navigation based on notification type and data
    _navigateBasedOnNotification(notification);
  }

  void _navigateBasedOnNotification(NotificationModel notification) {
    switch (notification.type) {
      case NotificationType.order:
        final orderId = notification.data['orderId'];
        if (orderId != null) {
          // Navigate to order details
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Would navigate to order: $orderId')),
          );
        }
        break;
      case NotificationType.message:
        final conversationId = notification.data['conversationId'];
        if (conversationId != null) {
          // Navigate to conversation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Would navigate to conversation: $conversationId')),
          );
        }
        break;
      case NotificationType.payment:
        // Navigate to payment/wallet screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Would navigate to payments')),
        );
        break;
      default:
        // Default action or no navigation
        break;
    }
  }

  void _handleNotificationAction(String action, NotificationModel notification) {
    switch (action) {
      case 'mark_read':
        NotificationService.markAsRead(notification.id);
        break;
      case 'mark_unread':
        // This would require updating the notification service
        break;
      case 'delete':
        _deleteNotification(notification);
        break;
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'mark_all_read':
        _markAllAsRead();
        break;
      case 'delete_all':
        _deleteAllNotifications();
        break;
      case 'settings':
        _openNotificationSettings();
        break;
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await NotificationService.markAllAsRead(userId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: MarketplaceTheme.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: MarketplaceTheme.error,
        ),
      );
    }
  }

  Future<void> _deleteNotification(NotificationModel notification) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text('Are you sure you want to delete this notification?'),
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
        await NotificationService.deleteNotification(notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted'),
            backgroundColor: MarketplaceTheme.success,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting notification: $e'),
            backgroundColor: MarketplaceTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Notifications'),
        content: const Text('Are you sure you want to delete all notifications? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: MarketplaceTheme.error),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await NotificationService.deleteAllNotifications(userId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications deleted'),
            backgroundColor: MarketplaceTheme.success,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting notifications: $e'),
            backgroundColor: MarketplaceTheme.error,
          ),
        );
      }
    }
  }

  void _openNotificationSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildNotificationSettings(),
    );
  }

  Widget _buildNotificationSettings() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notification Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Notification type settings would go here
          _buildSettingTile(
            'Order Updates',
            'Get notified about order status changes',
            true,
            (value) {},
          ),
          
          _buildSettingTile(
            'New Messages',
            'Get notified when you receive messages',
            true,
            (value) {},
          ),
          
          _buildSettingTile(
            'Payment Notifications',
            'Get notified about payment updates',
            true,
            (value) {},
          ),
          
          _buildSettingTile(
            'Promotional Offers',
            'Get notified about deals and promotions',
            false,
            (value) {},
          ),
          
          const Spacer(),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: MarketplaceTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Settings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeColor: MarketplaceTheme.primaryBlue,
    );
  }
}
