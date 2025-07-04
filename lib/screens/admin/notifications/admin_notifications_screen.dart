import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../providers/admin_provider.dart';
import '../../../models/notification.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/responsive_layout.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({Key? key}) : super(key: key);

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _userIdController = TextEditingController();
  String _selectedType = 'announcement';
  String? _selectedUserId;
  DateTime? _expiryDate;
  bool _isBroadcast = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      adminProvider.loadNotifications();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);

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
                const SizedBox(height: 24),
                Expanded(
                  child: isDesktop 
                      ? _buildDesktopLayout()
                      : _buildMobileLayout(),
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
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryGold),
        ),
        const SizedBox(width: 16),
        Icon(
          Icons.notifications,
          color: AppTheme.primaryGold,
          size: isDesktop ? 32 : 28,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage Notifications',
                style: (isDesktop 
                    ? AppTheme.headingLarge.copyWith(fontSize: 28)
                    : AppTheme.headingLarge).copyWith(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Send notifications to users',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.grey,
                  fontSize: isDesktop ? 16 : null,
                ),
              ),
            ],
          ),
        ),
        CustomButton(
          text: 'Send Notification',
          onPressed: _showCreateNotificationDialog,
          isOutlined: false,
        ),
      ],
    ).animate().fadeIn(duration: const Duration(milliseconds: 600));
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side - Notification list
        Expanded(
          flex: 2,
          child: _buildNotificationList(),
        ),
        const SizedBox(width: 24),
        // Right side - Create notification form
        Expanded(
          flex: 1,
          child: _buildCreateNotificationForm(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildNotificationList(),
        const SizedBox(height: 24),
        _buildCreateNotificationForm(),
      ],
    );
  }

  Widget _buildNotificationList() {
    final adminProvider = Provider.of<AdminProvider>(context);

    if (adminProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
        ),
      );
    }

    if (adminProvider.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: AppTheme.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: AppTheme.headingMedium.copyWith(
                color: AppTheme.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first notification to get started',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.grey.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: adminProvider.notifications.length,
      itemBuilder: (context, index) {
        final notification = adminProvider.notifications[index];
        return _buildNotificationCard(notification, index);
      },
    );
  }

  Widget _buildNotificationCard(NotificationModel notification, int index) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getNotificationColor(notification.type).withOpacity(0.1),
              _getNotificationColor(notification.type).withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getNotificationColor(notification.type).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    notification.type.toUpperCase(),
                    style: AppTheme.bodySmall.copyWith(
                      color: _getNotificationColor(notification.type),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(notification.createdAt),
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              notification.title,
              style: AppTheme.headingSmall.copyWith(
                color: AppTheme.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              notification.message,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.black.withOpacity(0.8),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (notification.actionText != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.link,
                    size: 16,
                    color: _getNotificationColor(notification.type),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    notification.actionText!,
                    style: AppTheme.bodySmall.copyWith(
                      color: _getNotificationColor(notification.type),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 16,
                  color: AppTheme.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  notification.userId ?? 'All Users',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.grey,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _deleteNotification(notification.id),
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  tooltip: 'Delete notification',
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
      duration: const Duration(milliseconds: 400),
      delay: Duration(milliseconds: 100 * index),
    );
  }

  Widget _buildCreateNotificationForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey.withOpacity(0.3)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Notification',
              style: AppTheme.headingMedium.copyWith(
                color: AppTheme.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            CustomTextField(
              controller: _titleController,
              label: 'Title',
              hint: 'Enter notification title',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _messageController,
              label: 'Message',
              hint: 'Enter notification message',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a message';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryGold),
                ),
              ),
              dropdownColor: AppTheme.darkGrey,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
              items: [
                DropdownMenuItem(value: 'announcement', child: Text('Announcement')),
                DropdownMenuItem(value: 'marketing', child: Text('Marketing')),
                DropdownMenuItem(value: 'system', child: Text('System')),
                DropdownMenuItem(value: 'transaction', child: Text('Transaction')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: Text(
                'Send to all users',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
              ),
              value: _isBroadcast,
              onChanged: (value) {
                setState(() {
                  _isBroadcast = value!;
                  if (_isBroadcast) {
                    _selectedUserId = null;
                  }
                });
              },
              activeColor: AppTheme.primaryGold,
            ),
            if (!_isBroadcast) ...[
              const SizedBox(height: 16),
              CustomTextField(
                controller: _userIdController,
                label: 'User ID (optional)',
                hint: 'Enter specific user ID',
                validator: (value) {
                  _selectedUserId = value == null || value.isEmpty ? null : value;
                  return null;
                },
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'Send Notification',
                onPressed: _createNotification,
                isOutlined: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateNotificationDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.darkGrey,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _buildCreateNotificationForm(),
        ),
      ),
    );
  }

  void _createNotification() async {
    if (!_formKey.currentState!.validate()) return;

    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    
    final notification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text,
      message: _messageController.text,
      type: _selectedType,
      createdAt: DateTime.now(),
      userId: _isBroadcast ? null : _selectedUserId,
    );

    await adminProvider.createNotification(notification);
    
    // Clear form
    _titleController.clear();
    _messageController.clear();
    setState(() {
      _selectedType = 'announcement';
      _isBroadcast = true;
      _selectedUserId = null;
    });

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification sent successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _deleteNotification(String notificationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text(
          'Delete Notification',
          style: AppTheme.headingSmall.copyWith(color: AppTheme.white),
        ),
        content: Text(
          'Are you sure you want to delete this notification?',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: AppTheme.bodyMedium.copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      await adminProvider.deleteNotification(notificationId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
} 