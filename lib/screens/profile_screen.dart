import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/stellar_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/stellar_wallet_prompt.dart';
import 'stellar_wallet_screen.dart';
import '../providers/admin_provider.dart';
import 'admin/admin_dashboard_screen.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  bool _isEditing = false;
  
  // Sample data
  final List<Achievement> _achievements = [
    Achievement(
      id: '1',
      title: 'Early Adopter',
      description: 'Joined during the beta phase',
      icon: Icons.star,
      color: Colors.blue,
      date: DateTime.now().subtract(const Duration(days: 180)),
    ),
    Achievement(
      id: '2',
      title: 'Mining Master',
      description: 'Mined for 30 consecutive days',
      icon: Icons.bolt,
      color: Colors.orange,
      date: DateTime.now().subtract(const Duration(days: 60)),
    ),
    Achievement(
      id: '3',
      title: 'Community Builder',
      description: 'Created a community with 100+ members',
      icon: Icons.people,
      color: Colors.green,
      date: DateTime.now().subtract(const Duration(days: 30)),
    ),
  ];
  
  final List<Activity> _activities = [
    Activity(
      id: '1',
      title: 'Received 0.25 Akofa',
      description: 'Stellar wallet transaction',
      icon: Icons.bolt,
      date: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    Activity(
      id: '2',
      title: 'Joined Akofa Pioneers community',
      description: 'You are now a member of Akofa Pioneers',
      icon: Icons.group_add,
      date: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Activity(
      id: '3',
      title: 'Completed profile',
      description: 'You added a profile picture and bio',
      icon: Icons.person,
      date: DateTime.now().subtract(const Duration(days: 5)),
    ),
    Activity(
      id: '4',
      title: 'Sent 2.5 Akofa to @johndoe',
      description: 'Stellar transaction completed successfully',
      icon: Icons.send,
      date: DateTime.now().subtract(const Duration(days: 7)),
    ),
  ];
  
  final List<SecuritySetting> _securitySettings = [
    SecuritySetting(
      id: '1',
      title: 'Two-Factor Authentication',
      description: 'Add an extra layer of security',
      icon: Icons.security,
      isEnabled: false,
    ),
    SecuritySetting(
      id: '2',
      title: 'Biometric Authentication',
      description: 'Use fingerprint or face ID',
      icon: Icons.fingerprint,
      isEnabled: true,
    ),
    SecuritySetting(
      id: '3',
      title: 'Transaction Notifications',
      description: 'Get notified for all transactions',
      icon: Icons.notifications,
      isEnabled: true,
    ),
  ];

  UserModel? _userModel;
  bool _isProfileLoading = true;
  String? _profileError;
  File? _newProfileImage;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      _isProfileLoading = true;
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
        _nameController.text = _userModel?.displayName ?? '';
        _bioController.text = _userModel?.profile?['bio'] ?? '';
        _isProfileLoading = false;
      });
    } catch (e) {
      setState(() {
        _profileError = e.toString();
        _isProfileLoading = false;
      });
    }
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _newProfileImage = File(picked.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isProfileLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final uid = authProvider.user?.uid;
      if (uid == null) throw Exception('User not logged in');
      String? photoUrl = _userModel?.photoUrl;
      if (_newProfileImage != null) {
        photoUrl = await _authService.uploadProfileImage(uid, _newProfileImage!);
      }
      await _authService.updateUserProfile(
        uid,
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        photoUrl: photoUrl,
      );
      // Optionally update Firebase Auth displayName/photoURL
      if (authProvider.user != null) {
        await authProvider.user!.updateDisplayName(_nameController.text.trim());
        if (photoUrl != null) {
          await authProvider.user!.updatePhotoURL(photoUrl);
        }
      }
      await _fetchUserProfile();
      setState(() {
        _isEditing = false;
        _newProfileImage = null;
      });
    } catch (e) {
      setState(() => _profileError = e.toString());
    } finally {
      setState(() => _isProfileLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final stellarProvider = Provider.of<StellarProvider>(context);
    final user = authProvider.user;
    
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
        child: _isProfileLoading
            ? const Center(child: CircularProgressIndicator())
            : _profileError != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_profileError!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.login),
                          label: const Text('Sign in with Google to create your profile'),
                          onPressed: () async {
                            try {
                              await _authService.signInWithGoogle();
                              await _fetchUserProfile();
                            } catch (e) {
                              setState(() { _profileError = 'Google sign-in failed: $e'; });
                            }
                          },
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      _buildAppBar(),
                      _buildProfileHeader(_userModel, stellarProvider),
                      _buildTabBar(),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildActivityTab(),
                            _buildAchievementsTab(),
                            _buildSettingsTab(),
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
            'Profile',
            style: AppTheme.headingLarge.copyWith(
              color: AppTheme.primaryGold,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _isEditing ? Icons.check : Icons.edit,
              color: AppTheme.primaryGold,
            ),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
                
                if (!_isEditing) {
                  // Save profile changes
                  // In a real app, this would update the user profile on the server
                }
              });
            },
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 500))
        .slideY(begin: -0.2, end: 0, curve: Curves.easeOut);
  }

  Widget _buildProfileHeader(UserModel? user, StellarProvider stellarProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryGold,
                    width: 3,
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
                  backgroundImage: _newProfileImage != null
                      ? FileImage(_newProfileImage!)
                      : (user?.photoUrl != null && user!.photoUrl!.isNotEmpty)
                          ? NetworkImage(user.photoUrl!) as ImageProvider
                          : null,
                  child: (user?.photoUrl == null || user!.photoUrl!.isEmpty) && _newProfileImage == null
                      ? Text(
                          user?.displayName?.isNotEmpty == true
                              ? user!.displayName![0].toUpperCase()
                              : 'A',
                          style: AppTheme.headingLarge.copyWith(
                            color: AppTheme.primaryGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 48,
                          ),
                        )
                      : null,
                ),
              ),
              if (_isEditing)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGold,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.black,
                      width: 2,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.camera_alt,
                      color: AppTheme.black,
                      size: 20,
                    ),
                    onPressed: _pickProfileImage,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
            ],
          )
              .animate()
              .fadeIn(duration: const Duration(milliseconds: 800))
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1, 1),
                curve: Curves.easeOut,
                duration: const Duration(milliseconds: 800),
              ),
          const SizedBox(height: 16),
          _isEditing
              ? TextField(
                  controller: _nameController,
                  style: AppTheme.headingMedium.copyWith(
                    color: AppTheme.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'Your Name',
                    hintStyle: AppTheme.headingMedium.copyWith(
                      color: AppTheme.grey,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.grey.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.grey.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryGold,
                      ),
                    ),
                  ),
                )
              : Text(
                  user?.displayName ?? 'Anonymous User',
                  style: AppTheme.headingMedium.copyWith(
                    color: AppTheme.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          const SizedBox(height: 8),
          _isEditing
              ? TextField(
                  controller: _bioController,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.grey,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Write a short bio about yourself',
                    hintStyle: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.grey.withOpacity(0.7),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.grey.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.grey.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryGold,
                      ),
                    ),
                  ),
                )
              : Text(
                  user?.profile?['bio'] ?? '',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              stellarProvider.hasWallet && stellarProvider.hasAkofaTrustline
                ? _buildStatItem(stellarProvider.akofaBalance, 'AKOFA Balance')
                : _buildStatItem('0', 'AKOFA Balance'),
              stellarProvider.hasWallet
                ? _buildStatItem(stellarProvider.balance, 'XLM Balance')
                : _buildStatItem('0', 'XLM Balance'),
              _buildStatItem((_userModel?.profile?['communitiesJoined'] ?? 0).toString(), 'Communities'),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.headingMedium.copyWith(
            color: AppTheme.primaryGold,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.grey,
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 800),
          delay: const Duration(milliseconds: 400),
        )
        .slideY(
          begin: 0.2,
          end: 0,
          curve: Curves.easeOut,
          duration: const Duration(milliseconds: 800),
        );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(30),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: AppTheme.primaryGold,
        ),
        labelColor: AppTheme.black,
        unselectedLabelColor: AppTheme.grey,
        labelStyle: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold),
        unselectedLabelStyle: AppTheme.bodyMedium,
        tabs: const [
          Tab(text: 'Activity'),
          Tab(text: 'Achievements'),
          Tab(text: 'Settings'),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 500),
          delay: const Duration(milliseconds: 600),
        );
  }

  Widget _buildActivityTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20.0),
      itemCount: _activities.length,
      itemBuilder: (context, index) {
        final activity = _activities[index];
        
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
                  activity.icon,
                  color: AppTheme.primaryGold,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activity.description,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatDate(activity.date),
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.grey,
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(
              duration: const Duration(milliseconds: 600),
              delay: Duration(milliseconds: 100 * index),
            )
            .slideY(
              begin: 0.1,
              end: 0,
              curve: Curves.easeOut,
              duration: const Duration(milliseconds: 600),
            );
      },
    );
  }

  Widget _buildAchievementsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20.0),
      itemCount: _achievements.length,
      itemBuilder: (context, index) {
        final achievement = _achievements[index];
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: AppTheme.darkGrey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: achievement.color.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: achievement.color.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: achievement.color,
                    width: 2,
                  ),
                ),
                child: Icon(
                  achievement.icon,
                  color: achievement.color,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      achievement.title,
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achievement.description,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Earned on ${_formatFullDate(achievement.date)}',
                      style: AppTheme.bodySmall.copyWith(
                        color: achievement.color,
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
              delay: Duration(milliseconds: 100 * index),
            )
            .slideY(
              begin: 0.1,
              end: 0,
              curve: Curves.easeOut,
              duration: const Duration(milliseconds: 600),
            );
      },
    );
  }

  Widget _buildSettingsTab() {
    final authProvider = Provider.of<AuthProvider>(context);
    final stellarProvider = Provider.of<StellarProvider>(context);
    final user = authProvider.user;
    final referralCode = _userModel?.referralCode ?? '';
    final referralCount = _userModel?.referralCount ?? 0;
    final miningRateBoosted = _userModel?.miningRateBoosted ?? false;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      children: [
        // Referral section
        Container(
          margin: const EdgeInsets.only(bottom: 24.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: AppTheme.darkGrey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.card_giftcard, color: AppTheme.primaryGold),
                  const SizedBox(width: 8),
                  Text('Referral Program', style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Your Referral Code: ', style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey)),
                  SelectableText(referralCode, style: AppTheme.bodyMedium.copyWith(color: AppTheme.white, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.copy, color: AppTheme.primaryGold, size: 18),
                    tooltip: 'Copy',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: referralCode));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral code copied!')));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Successful Referrals: $referralCount', style: AppTheme.bodyMedium.copyWith(color: AppTheme.white)),
              const SizedBox(height: 8),
              Text(
                miningRateBoosted
                  ? 'Mining Rate Boosted! 🎉'
                  : 'Refer 6+ users to boost your mining rate.',
                style: AppTheme.bodySmall.copyWith(color: miningRateBoosted ? Colors.green : AppTheme.grey),
              ),
            ],
          ),
        ),
        _buildSettingItem(
          icon: Icons.history,
          title: 'View All Transactions',
          subtitle: 'See your full transaction history',
          onTap: () {
            Navigator.of(context).pushNamed('/all-transactions');
          },
        ),
        const SizedBox(height: 24),
        // Security settings
        Text(
          'Security',
          style: AppTheme.headingSmall.copyWith(
            color: AppTheme.primaryGold,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ..._securitySettings.asMap().entries.map((entry) {
          final index = entry.key;
          final setting = entry.value;
          
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
                    color: setting.isEnabled
                        ? AppTheme.primaryGold.withOpacity(0.2)
                        : AppTheme.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Icon(
                    setting.icon,
                    color: setting.isEnabled ? AppTheme.primaryGold : AppTheme.grey,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        setting.title,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        setting.description,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: setting.isEnabled,
                  onChanged: (value) {
                    setState(() {
                      setting.isEnabled = value;
                    });
                  },
                  activeColor: AppTheme.primaryGold,
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(
                duration: const Duration(milliseconds: 600),
                delay: Duration(milliseconds: 100 * index),
              )
              .slideY(
                begin: 0.1,
                end: 0,
                curve: Curves.easeOut,
                duration: const Duration(milliseconds: 600),
              );
        }).toList(),
        
        const SizedBox(height: 24),
        
        // Account settings
        Text(
          'Account',
          style: AppTheme.headingSmall.copyWith(
            color: AppTheme.primaryGold,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildSettingItem(
          icon: Icons.email,
          title: 'Email',
          subtitle: user?.email ?? 'No email provided',
          onTap: () {},
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
        _buildSettingItem(
          icon: Icons.language,
          title: 'Language',
          subtitle: 'English (US)',
          onTap: () {},
        ),
        _buildSettingItem(
          icon: Icons.dark_mode,
          title: 'Theme',
          subtitle: 'Dark',
          onTap: () {},
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
              duration: const Duration(milliseconds: 800),
              delay: const Duration(milliseconds: 700),
            ),
        
        const SizedBox(height: 40),
      ],
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
    )
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 500),
        )
        .slideY(
          begin: 0.1,
          end: 0,
          curve: Curves.easeOut,
          duration: const Duration(milliseconds: 600),
        );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatFullDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final DateTime date;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.date,
  });
}

class Activity {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final DateTime date;

  Activity({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.date,
  });
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