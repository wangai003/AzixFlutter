import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/stellar_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/security_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/stellar_wallet_prompt.dart';
import 'stellar_wallet_screen.dart';
import '../providers/admin_provider.dart';
import 'admin/admin_dashboard_screen.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  
  // Display settings
  final List<String> _languages = ['English', 'Spanish', 'French', 'German', 'Chinese'];
  final List<String> _currencies = ['USD', 'EUR', 'GBP', 'JPY', 'AUD'];
  String _selectedLanguage = 'English';
  String _selectedCurrency = 'USD';
  bool _isDarkMode = true;
  bool _autoBackupEnabled = false;
  
  // Security settings for UI display
  late List<SecuritySetting> _securitySettings;
  
  UserModel? _userModel;
  String? _profileError;
  final AuthService _authService = AuthService();
  
  @override
  void initState() {
    super.initState();
    _initializeSecuritySettings();
    _fetchUserProfile();
  }
  
  void _initializeSecuritySettings() {
    final securityProvider = Provider.of<SecurityProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    
    _securitySettings = [
      SecuritySetting(
        id: '1',
        title: 'Two-Factor Authentication',
        description: 'Add an extra layer of security',
        icon: Icons.security,
        isEnabled: securityProvider.twoFactorEnabled,
      ),
      SecuritySetting(
        id: '2',
        title: 'Biometric Authentication',
        description: 'Use fingerprint or face ID',
        icon: Icons.fingerprint,
        isEnabled: securityProvider.biometricsEnabled,
      ),
      SecuritySetting(
        id: '3',
        title: 'Transaction Notifications',
        description: 'Get notified for all transactions',
        icon: Icons.notifications,
        isEnabled: notificationProvider.transactionNotificationsEnabled,
      ),
    ];
  }
  
  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoading = true;
      _profileError = null;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final uid = authProvider.user?.uid;
      if (uid == null) throw Exception('User not logged in');
      final data = await _authService.getUserDetails(uid);
      if (data == null) throw Exception('User data not found');
      setState(() {
        _userModel = UserModel.fromMap({...data, 'id': uid});
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _profileError = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final securityProvider = Provider.of<SecurityProvider>(context, listen: false);
      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = _userModel;
      // Save security settings
      await securityProvider.setTwoFactorEnabled(_securitySettings[0].isEnabled);
      await securityProvider.setBiometricsEnabled(_securitySettings[1].isEnabled);
      await notificationProvider.setTransactionNotificationsEnabled(_securitySettings[2].isEnabled);
      // Save preferences to Firestore
      if (user != null) {
        final preferences = {
          'language': _selectedLanguage,
          'currency': _selectedCurrency,
          'darkMode': _isDarkMode,
          'autoBackup': _autoBackupEnabled,
        };
        final authService = AuthService();
        await authService.updateUserProfile(user.id, preferences: preferences);
        await _fetchUserProfile();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
    } catch (e) {
      // Handle error
      debugPrint('Error saving settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final stellarProvider = Provider.of<StellarProvider>(context);
    final user = _userModel;
    
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.black,
            Color(0xFF212121),
          ],
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
            : Column(
                children: [
                  _buildAppBar(),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20.0),
                      children: [
                        // Account section
                        _buildSectionHeader('Account'),
                        _buildAccountInfo(user),
                        const SizedBox(height: 8),
                        _buildSettingItem(
                          icon: Icons.edit,
                          title: 'Edit Profile',
                          subtitle: 'Change your name, email, or photo',
                          onTap: _showEditProfileDialog,
                        ),
                        _buildSettingItem(
                          icon: Icons.lock,
                          title: 'Change Password',
                          subtitle: 'Update your account password',
                          onTap: _showChangePasswordDialog,
                        ),
                        _buildSettingItem(
                          icon: Icons.delete_forever,
                          title: 'Delete Account',
                          subtitle: 'Permanently delete your account',
                          onTap: _showDeleteAccountDialog,
                        ),
                        _buildSettingItem(
                          icon: Icons.account_balance_wallet,
                          title: 'Stellar Wallet',
                          subtitle: stellarProvider.hasWallet 
                              ? 'Manage your Stellar wallet'
                              : 'Create a Stellar wallet',
                          onTap: () {
                            if (stellarProvider.hasWallet) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const StellarWalletScreen(),
                                ),
                              );
                            } else {
                              // Show wallet creation dialog
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                                  child: SizedBox(
                                    width: MediaQuery.of(context).size.width > 600 
                                        ? 400 
                                        : MediaQuery.of(context).size.width * 0.85,
                                    child: const StellarWalletPrompt(),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Appearance section
                        _buildSectionHeader('Appearance'),
                        _buildSwitchItem(
                          icon: Icons.dark_mode,
                          title: 'Dark Mode',
                          subtitle: 'Use dark theme throughout the app',
                          value: _isDarkMode,
                          onChanged: (value) {
                            setState(() {
                              _isDarkMode = value;
                            });
                          },
                        ),
                        _buildDropdownItem(
                          icon: Icons.language,
                          title: 'Language',
                          value: _selectedLanguage,
                          items: _languages,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedLanguage = value;
                              });
                            }
                          },
                        ),
                        _buildDropdownItem(
                          icon: Icons.attach_money,
                          title: 'Currency',
                          value: _selectedCurrency,
                          items: _currencies,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedCurrency = value;
                              });
                            }
                          },
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Security section
                        _buildSectionHeader('Security'),
                        ..._securitySettings.map((setting) {
                          return _buildSwitchItem(
                            icon: setting.icon,
                            title: setting.title,
                            subtitle: setting.description,
                            value: setting.isEnabled,
                            onChanged: (value) {
                              setState(() {
                                setting.isEnabled = value;
                              });
                            },
                          );
                        }).toList(),
                        
                        const SizedBox(height: 24),
                        
                        // Data & Storage section
                        _buildSectionHeader('Data & Storage'),
                        _buildSwitchItem(
                          icon: Icons.backup,
                          title: 'Auto Backup',
                          subtitle: 'Automatically backup your data',
                          value: _autoBackupEnabled,
                          onChanged: (value) {
                            setState(() {
                              _autoBackupEnabled = value;
                            });
                          },
                        ),
                        _buildSettingItem(
                          icon: Icons.delete,
                          title: 'Clear Cache',
                          subtitle: 'Free up storage space',
                          onTap: () {
                            _showClearCacheDialog();
                          },
                        ),
                        _buildSettingItem(
                          icon: Icons.download,
                          title: 'Export Data',
                          subtitle: 'Download your personal data',
                          onTap: () {
                            _showExportDataDialog();
                          },
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // About section
                        _buildSectionHeader('About'),
                        _buildSettingItem(
                          icon: Icons.info,
                          title: 'App Version',
                          subtitle: '1.0.0',
                          onTap: () {},
                        ),
                        _buildSettingItem(
                          icon: Icons.privacy_tip,
                          title: 'Privacy Policy',
                          subtitle: 'Read our privacy policy',
                          onTap: () {
                            // Navigate to privacy policy
                          },
                        ),
                        _buildSettingItem(
                          icon: Icons.description,
                          title: 'Terms of Service',
                          subtitle: 'Read our terms of service',
                          onTap: () {
                            // Navigate to terms of service
                          },
                        ),
                        
                        // Admin Dashboard button (only for admins)
                        Builder(
                          builder: (context) {
                            final isAdmin = Provider.of<AdminProvider>(context, listen: false).isAdmin;
                            if (!isAdmin) return const SizedBox.shrink();
                            return _buildSettingItem(
                              icon: Icons.admin_panel_settings,
                              title: 'Admin Dashboard',
                              subtitle: 'Manage the app',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const AdminDashboardScreen(),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Save button
                        CustomButton(
                          text: 'Save Settings',
                          onPressed: _saveSettings,
                          width: double.infinity,
                        )
                            .animate()
                            .fadeIn(
                              duration: const Duration(milliseconds: 600),
                              delay: const Duration(milliseconds: 400),
                            ),
                        
                        const SizedBox(height: 16),
                        
                        // Sign out button
                        CustomButton(
                          text: 'Sign Out',
                          onPressed: () async {
                            await authProvider.signOut();
                          },
                          isOutlined: true,
                          width: double.infinity,
                        )
                            .animate()
                            .fadeIn(
                              duration: const Duration(milliseconds: 600),
                              delay: const Duration(milliseconds: 500),
                            ),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Row(
        children: [
          Text(
            'Settings',
            style: AppTheme.headingLarge.copyWith(
              color: AppTheme.primaryGold,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 500))
        .slideY(begin: -0.2, end: 0, curve: Curves.easeOut);
  }

  Widget _buildAccountInfo(UserModel? user) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: AppTheme.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryGold,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGold.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              backgroundColor: AppTheme.darkGrey,
              backgroundImage: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                  ? NetworkImage(user.photoUrl!) as ImageProvider
                  : null,
              child: (user?.photoUrl == null || user!.photoUrl!.isEmpty)
                  ? Text(
                      user?.displayName?.isNotEmpty == true
                          ? user!.displayName![0].toUpperCase()
                          : 'A',
                      style: AppTheme.headingLarge.copyWith(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'Anonymous User',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? 'No email provided',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 200),
        )
        .slideY(
          begin: 0.1,
          end: 0,
          curve: Curves.easeOut,
          duration: const Duration(milliseconds: 600),
        );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: AppTheme.headingSmall.copyWith(
          color: AppTheme.primaryGold,
          fontWeight: FontWeight.bold,
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 300),
        );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: AppTheme.grey.withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Icon(
                    icon,
                    color: AppTheme.primaryGold,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: AppTheme.grey,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 300),
        )
        .slideY(
          begin: 0.1,
          end: 0,
          curve: Curves.easeOut,
          duration: const Duration(milliseconds: 600),
        );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: AppTheme.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: value
                  ? AppTheme.primaryGold.withOpacity(0.2)
                  : AppTheme.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Icon(
              icon,
              color: value ? AppTheme.primaryGold : AppTheme.grey,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.grey,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryGold,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 300),
        )
        .slideY(
          begin: 0.1,
          end: 0,
          curve: Curves.easeOut,
          duration: const Duration(milliseconds: 600),
        );
  }

  Widget _buildDropdownItem<T>({
    required IconData icon,
    required String title,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: AppTheme.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryGold.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryGold,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  decoration: BoxDecoration(
                    color: AppTheme.darkGrey.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: AppTheme.grey.withOpacity(0.3),
                    ),
                  ),
                  child: DropdownButton<T>(
                    value: value,
                    onChanged: onChanged,
                    items: items.map((item) {
                      return DropdownMenuItem<T>(
                        value: item,
                        child: Text(
                          item.toString(),
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.white,
                          ),
                        ),
                      );
                    }).toList(),
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.white,
                    ),
                    dropdownColor: AppTheme.darkGrey,
                    isExpanded: true,
                    underline: const SizedBox(),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: AppTheme.primaryGold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 300),
        )
        .slideY(
          begin: 0.1,
          end: 0,
          curve: Curves.easeOut,
          duration: const Duration(milliseconds: 600),
        );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text(
          'Clear Cache',
          style: AppTheme.headingSmall.copyWith(
            color: AppTheme.white,
          ),
        ),
        content: Text(
          'This will clear all cached data. This action cannot be undone.',
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'Cancel',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.grey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement cache clearing logic
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared successfully')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: AppTheme.black,
            ),
            child: Text(
              'Clear',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text(
          'Export Data',
          style: AppTheme.headingSmall.copyWith(
            color: AppTheme.white,
          ),
        ),
        content: Text(
          'This will export all your personal data. Where would you like to save it?',
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'Cancel',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.grey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement data export logic
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data exported successfully')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: AppTheme.black,
            ),
            child: Text(
              'Export',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final user = _userModel;
    final TextEditingController nameController = TextEditingController(text: user?.displayName ?? '');
    final TextEditingController emailController = TextEditingController(text: user?.email ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text('Edit Profile', style: AppTheme.headingSmall.copyWith(color: AppTheme.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              enabled: false, // Email change not supported here
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty && user != null) {
                setState(() => _isLoading = true);
                try {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  final firebaseUser = authProvider.user;
                  final authService = AuthService();
                  await authService.updateUserProfile(user.id, name: newName);
                  if (firebaseUser != null) {
                    await firebaseUser.updateDisplayName(newName);
                  }
                  await _fetchUserProfile();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                } finally {
                  setState(() => _isLoading = false);
                  Navigator.of(context).pop();
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold),
            child: Text('Save', style: AppTheme.bodyMedium.copyWith(color: AppTheme.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final TextEditingController passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text('Change Password', style: AppTheme.headingSmall.copyWith(color: AppTheme.white)),
        content: TextField(
          controller: passwordController,
          decoration: const InputDecoration(labelText: 'New Password'),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPassword = passwordController.text.trim();
              if (newPassword.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters')));
                return;
              }
              setState(() => _isLoading = true);
              try {
                // Use FirebaseAuth directly for password change
                final user = Provider.of<AuthProvider>(context, listen: false).user;
                if (user != null) {
                  await user.updatePassword(newPassword);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully')));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              } finally {
                setState(() => _isLoading = false);
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold),
            child: Text('Change', style: AppTheme.bodyMedium.copyWith(color: AppTheme.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text('Delete Account', style: AppTheme.headingSmall.copyWith(color: AppTheme.white)),
        content: Text('Are you sure you want to permanently delete your account? This action cannot be undone.', style: AppTheme.bodyMedium.copyWith(color: AppTheme.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() => _isLoading = true);
              try {
                final user = Provider.of<AuthProvider>(context, listen: false).user;
                if (user != null) {
                  await user.delete();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deleted successfully')));
                  Navigator.of(context).pop();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              } finally {
                setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: AppTheme.bodyMedium.copyWith(color: AppTheme.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class SecuritySetting {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  bool isEnabled;

  SecuritySetting({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isEnabled,
  });
}