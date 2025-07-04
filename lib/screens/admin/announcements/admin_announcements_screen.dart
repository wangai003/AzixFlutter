import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/admin_provider.dart';
import '../../../models/announcement.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/responsive_layout.dart';
import '../../../widgets/custom_button.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({Key? key}) : super(key: key);

  @override
  State<AdminAnnouncementsScreen> createState() => _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).loadAnnouncements(activeOnly: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: const Text('Announcements', style: TextStyle(color: AppTheme.primaryGold)),
        iconTheme: const IconThemeData(color: AppTheme.primaryGold),
        elevation: 0,
        actions: [
          CustomButton(
            text: 'New Announcement',
            onPressed: _showCreateAnnouncementDialog,
            isOutlined: false,
          ),
        ],
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
            child: adminProvider.isLoading
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold)))
                : adminProvider.announcements.isEmpty
                    ? Center(child: Text('No announcements found.', style: AppTheme.bodyLarge.copyWith(color: AppTheme.grey)))
                    : ListView.builder(
                        itemCount: adminProvider.announcements.length,
                        itemBuilder: (context, index) {
                          final announcement = adminProvider.announcements[index];
                          return _buildAnnouncementCard(announcement);
                        },
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(AnnouncementModel announcement) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          Icons.announcement,
          color: announcement.isActive ? AppTheme.primaryGold : Colors.grey,
        ),
        title: Text(announcement.title, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(announcement.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.bodySmall),
            Text('Status: ${announcement.isActive ? 'Active' : 'Inactive'}', style: AppTheme.bodySmall.copyWith(color: announcement.isActive ? Colors.green : Colors.red)),
            if (announcement.expiresAt != null)
              Text('Expires: ${_formatDate(announcement.expiresAt!)}', style: AppTheme.bodySmall),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppTheme.primaryGold),
          onSelected: (value) => _handleAnnouncementAction(value, announcement),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => _showAnnouncementDetails(announcement),
      ),
    );
  }

  void _handleAnnouncementAction(String action, AnnouncementModel announcement) async {
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    switch (action) {
      case 'edit':
        _showEditAnnouncementDialog(announcement);
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.darkGrey,
            title: const Text('Delete Announcement', style: TextStyle(color: AppTheme.primaryGold)),
            content: const Text('Are you sure you want to delete this announcement?', style: TextStyle(color: AppTheme.white)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await adminProvider.deleteAnnouncement(announcement.id);
        }
        break;
    }
  }

  void _showAnnouncementDetails(AnnouncementModel announcement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text(announcement.title, style: const TextStyle(color: AppTheme.primaryGold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(announcement.content, style: const TextStyle(color: AppTheme.white)),
              if (announcement.imageUrl != null) ...[
                const SizedBox(height: 12),
                Image.network(announcement.imageUrl!, height: 120, fit: BoxFit.cover),
              ],
              if (announcement.expiresAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('Expires: ${_formatDate(announcement.expiresAt!)}', style: const TextStyle(color: AppTheme.grey)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppTheme.primaryGold)),
          ),
        ],
      ),
    );
  }

  void _showCreateAnnouncementDialog() {
    _showAnnouncementFormDialog();
  }

  void _showEditAnnouncementDialog(AnnouncementModel announcement) {
    _showAnnouncementFormDialog(editAnnouncement: announcement);
  }

  void _showAnnouncementFormDialog({AnnouncementModel? editAnnouncement}) {
    final titleController = TextEditingController(text: editAnnouncement?.title ?? '');
    final contentController = TextEditingController(text: editAnnouncement?.content ?? '');
    final imageUrlController = TextEditingController(text: editAnnouncement?.imageUrl ?? '');
    DateTime? expiresAt = editAnnouncement?.expiresAt;
    bool isActive = editAnnouncement?.isActive ?? true;
    int priority = editAnnouncement?.priority ?? 1;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text(editAnnouncement == null ? 'New Announcement' : 'Edit Announcement', style: const TextStyle(color: AppTheme.primaryGold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: AppTheme.white),
                decoration: const InputDecoration(labelText: 'Title', labelStyle: TextStyle(color: AppTheme.primaryGold)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                style: const TextStyle(color: AppTheme.white),
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Content', labelStyle: TextStyle(color: AppTheme.primaryGold)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: imageUrlController,
                style: const TextStyle(color: AppTheme.white),
                decoration: const InputDecoration(labelText: 'Image URL (optional)', labelStyle: TextStyle(color: AppTheme.primaryGold)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Expires:', style: TextStyle(color: AppTheme.primaryGold)),
                  const SizedBox(width: 8),
                  Text(
                    expiresAt != null ? _formatDate(expiresAt!) : 'Never',
                    style: const TextStyle(color: AppTheme.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today, color: AppTheme.primaryGold),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: expiresAt ?? DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (context, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppTheme.primaryGold,
                              onPrimary: AppTheme.black,
                              surface: AppTheme.darkGrey,
                              onSurface: AppTheme.white,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          expiresAt = picked;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Active:', style: TextStyle(color: AppTheme.primaryGold)),
                  Switch(
                    value: isActive,
                    onChanged: (value) {
                      setState(() {
                        isActive = value;
                      });
                    },
                    activeColor: AppTheme.primaryGold,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Priority:', style: TextStyle(color: AppTheme.primaryGold)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: priority,
                    dropdownColor: AppTheme.darkGrey,
                    style: const TextStyle(color: AppTheme.white),
                    items: List.generate(5, (i) => i + 1).map((p) => DropdownMenuItem(value: p, child: Text('$p'))).toList(),
                    onChanged: (value) {
                      setState(() {
                        priority = value ?? 1;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.grey)),
          ),
          TextButton(
            onPressed: () async {
              final adminProvider = Provider.of<AdminProvider>(context, listen: false);
              final announcement = AnnouncementModel(
                id: editAnnouncement?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                title: titleController.text,
                content: contentController.text,
                imageUrl: imageUrlController.text.isNotEmpty ? imageUrlController.text : null,
                createdAt: editAnnouncement?.createdAt ?? DateTime.now(),
                expiresAt: expiresAt,
                isActive: isActive,
                priority: priority,
                actionUrl: null,
                actionText: null,
                createdBy: 'admin', // Replace with actual admin ID
                targetAudience: null,
              );
              if (editAnnouncement == null) {
                await adminProvider.createAnnouncement(announcement);
              } else {
                await adminProvider.updateAnnouncement(announcement.id, announcement.toMap());
              }
              if (mounted) Navigator.pop(context);
            },
            child: Text(editAnnouncement == null ? 'Create' : 'Update', style: const TextStyle(color: AppTheme.primaryGold)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
} 