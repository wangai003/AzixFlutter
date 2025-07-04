import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/admin_provider.dart';
import '../../../models/explore_content.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/responsive_layout.dart';
import '../../../widgets/custom_button.dart';

class AdminContentScreen extends StatefulWidget {
  const AdminContentScreen({Key? key}) : super(key: key);

  @override
  State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).loadExploreContent(publishedOnly: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: const Text('Explore Content', style: TextStyle(color: AppTheme.primaryGold)),
        iconTheme: const IconThemeData(color: AppTheme.primaryGold),
        elevation: 0,
        actions: [
          CustomButton(
            text: 'New Article',
            onPressed: _showCreateContentDialog,
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
                : adminProvider.exploreContent.isEmpty
                    ? Center(child: Text('No content found.', style: AppTheme.bodyLarge.copyWith(color: AppTheme.grey)))
                    : ListView.builder(
                        itemCount: adminProvider.exploreContent.length,
                        itemBuilder: (context, index) {
                          final content = adminProvider.exploreContent[index];
                          return _buildContentCard(content);
                        },
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentCard(ExploreContentModel content) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: content.imageUrl != null && content.imageUrl!.isNotEmpty
            ? Image.network(content.imageUrl!, width: 48, height: 48, fit: BoxFit.cover)
            : const Icon(Icons.article, color: AppTheme.primaryGold),
        title: Text(content.title, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.bodySmall),
            Text('Category: ${content.category}', style: AppTheme.bodySmall),
            Text('Status: ${content.isPublished ? 'Published' : 'Draft'}', style: AppTheme.bodySmall.copyWith(color: content.isPublished ? Colors.green : Colors.red)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppTheme.primaryGold),
          onSelected: (value) => _handleContentAction(value, content),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => _showContentDetails(content),
      ),
    );
  }

  void _handleContentAction(String action, ExploreContentModel content) async {
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    switch (action) {
      case 'edit':
        _showEditContentDialog(content);
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.darkGrey,
            title: const Text('Delete Article', style: TextStyle(color: AppTheme.primaryGold)),
            content: const Text('Are you sure you want to delete this article?', style: TextStyle(color: AppTheme.white)),
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
          await adminProvider.deleteExploreContent(content.id);
        }
        break;
    }
  }

  void _showContentDetails(ExploreContentModel content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text(content.title, style: const TextStyle(color: AppTheme.primaryGold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(content.description, style: const TextStyle(color: AppTheme.white)),
              if (content.imageUrl != null && content.imageUrl!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Image.network(content.imageUrl!, height: 120, fit: BoxFit.cover),
              ],
              if (content.content != null && content.content!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(content.content!, style: const TextStyle(color: AppTheme.white)),
              ],
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

  void _showCreateContentDialog() {
    _showContentFormDialog();
  }

  void _showEditContentDialog(ExploreContentModel content) {
    _showContentFormDialog(editContent: content);
  }

  void _showContentFormDialog({ExploreContentModel? editContent}) {
    final titleController = TextEditingController(text: editContent?.title ?? '');
    final descriptionController = TextEditingController(text: editContent?.description ?? '');
    final imageUrlController = TextEditingController(text: editContent?.imageUrl ?? '');
    final contentController = TextEditingController(text: editContent?.content ?? '');
    String category = editContent?.category ?? 'news';
    bool isPublished = editContent?.isPublished ?? false;
    bool isFeatured = editContent?.isFeatured ?? false;
    int priority = editContent?.priority ?? 1;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text(editContent == null ? 'New Article' : 'Edit Article', style: const TextStyle(color: AppTheme.primaryGold)),
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
                controller: descriptionController,
                style: const TextStyle(color: AppTheme.white),
                decoration: const InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: AppTheme.primaryGold)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: imageUrlController,
                style: const TextStyle(color: AppTheme.white),
                decoration: const InputDecoration(labelText: 'Image URL (optional)', labelStyle: TextStyle(color: AppTheme.primaryGold)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                style: const TextStyle(color: AppTheme.white),
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Full Content', labelStyle: TextStyle(color: AppTheme.primaryGold)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Category:', style: TextStyle(color: AppTheme.primaryGold)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: category,
                    dropdownColor: AppTheme.darkGrey,
                    style: const TextStyle(color: AppTheme.white),
                    items: ['news', 'tutorials', 'events', 'projects']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        category = value ?? 'news';
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Published:', style: TextStyle(color: AppTheme.primaryGold)),
                  Switch(
                    value: isPublished,
                    onChanged: (value) {
                      setState(() {
                        isPublished = value;
                      });
                    },
                    activeColor: AppTheme.primaryGold,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Featured:', style: TextStyle(color: AppTheme.primaryGold)),
                  Switch(
                    value: isFeatured,
                    onChanged: (value) {
                      setState(() {
                        isFeatured = value;
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
              final content = ExploreContentModel(
                id: editContent?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                title: titleController.text,
                description: descriptionController.text,
                category: category,
                imageUrl: imageUrlController.text.isNotEmpty ? imageUrlController.text : null,
                content: contentController.text,
                createdAt: editContent?.createdAt ?? DateTime.now(),
                publishDate: isPublished ? DateTime.now() : null,
                expiryDate: null,
                isPublished: isPublished,
                isFeatured: isFeatured,
                priority: priority,
                createdBy: 'admin', // Replace with actual admin ID
                metadata: null,
                tags: null,
                externalUrl: null,
                readCount: 0,
                likeCount: 0,
              );
              if (editContent == null) {
                await adminProvider.createExploreContent(content);
              } else {
                await adminProvider.updateExploreContent(content.id, content.toMap());
              }
              if (mounted) Navigator.pop(context);
            },
            child: Text(editContent == null ? 'Create' : 'Update', style: const TextStyle(color: AppTheme.primaryGold)),
          ),
        ],
      ),
    );
  }
} 