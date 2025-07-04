import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/admin_provider.dart';
import '../../../models/user_model.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/responsive_layout.dart';
import '../../../widgets/custom_button.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({Key? key}) : super(key: key);

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    final users = adminProvider.users.where((user) {
      if (_searchQuery.isEmpty) return true;
      return user.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             (user.displayName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: const Text('User Management', style: TextStyle(color: AppTheme.primaryGold)),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchBar(),
                const SizedBox(height: 16),
                Expanded(
                  child: adminProvider.isLoading
                      ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold)))
                      : users.isEmpty
                          ? Center(
                              child: Text('No users found.', style: AppTheme.bodyLarge.copyWith(color: AppTheme.grey)),
                            )
                          : ListView.builder(
                              itemCount: users.length,
                              itemBuilder: (context, index) {
                                final user = users[index];
                                return _buildUserCard(user);
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
      decoration: InputDecoration(
        hintText: 'Search users by email or name...',
        hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
        prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGold),
        filled: true,
        fillColor: AppTheme.darkGrey.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryGold),
        ),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  Widget _buildUserCard(UserModel user) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryGold.withOpacity(0.2),
          child: Text(
            user.displayName?.isNotEmpty == true ? user.displayName![0].toUpperCase() : 'U',
            style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(user.displayName ?? 'No Name', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email, style: AppTheme.bodySmall),
            Text('Role: ${user.role}', style: AppTheme.bodySmall),
            Text('Status: ${user.isActive ? 'Active' : 'Deactivated'}', style: AppTheme.bodySmall.copyWith(color: user.isActive ? Colors.green : Colors.red)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppTheme.primaryGold),
          onSelected: (value) => _handleUserAction(value, user),
          itemBuilder: (context) => [
            if (user.isActive)
              const PopupMenuItem(value: 'deactivate', child: Text('Deactivate')),
            if (!user.isActive)
              const PopupMenuItem(value: 'activate', child: Text('Activate')),
            if (user.role == 'user')
              const PopupMenuItem(value: 'promote', child: Text('Promote to Admin')),
            if (user.role == 'admin')
              const PopupMenuItem(value: 'demote', child: Text('Demote to User')),
          ],
        ),
        onTap: () => _showUserDetails(user),
      ),
    );
  }

  void _handleUserAction(String action, UserModel user) async {
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    switch (action) {
      case 'deactivate':
        await adminProvider.deactivateUser(user.id);
        break;
      case 'activate':
        await adminProvider.activateUser(user.id);
        break;
      case 'promote':
        await adminProvider.updateUserRole(user.id, 'admin');
        break;
      case 'demote':
        await adminProvider.updateUserRole(user.id, 'user');
        break;
    }
  }

  void _showUserDetails(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text(user.displayName ?? 'User Details', style: const TextStyle(color: AppTheme.primaryGold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${user.email}', style: const TextStyle(color: AppTheme.white)),
            Text('Role: ${user.role}', style: const TextStyle(color: AppTheme.white)),
            Text('Status: ${user.isActive ? 'Active' : 'Deactivated'}', style: TextStyle(color: user.isActive ? Colors.green : Colors.red)),
            if (user.stellarPublicKey != null) ...[
              const SizedBox(height: 8),
              Text('Stellar Wallet: ${user.stellarPublicKey}', style: const TextStyle(color: AppTheme.primaryGold)),
            ],
            if (user.totalMiningSessions != null)
              Text('Mining Sessions: ${user.totalMiningSessions}', style: const TextStyle(color: AppTheme.white)),
            if (user.totalEarnings != null)
              Text('Total Earnings: ${user.totalEarnings}', style: const TextStyle(color: AppTheme.white)),
          ],
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
} 