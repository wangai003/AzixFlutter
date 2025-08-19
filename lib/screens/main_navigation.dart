import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'ultra_modern_mining_screen.dart';
import 'explore_screen.dart';
import 'marketplace/modern_marketplace_home.dart';

import 'vendor/functional_vendor_dashboard.dart';
import 'notifications_screen.dart';
import '../services/notification_service.dart';
import 'community_screen.dart';
import 'settings_screen.dart';
import 'wallet_screen.dart';
import 'all_transactions_screen.dart';
import 'referral_screen.dart';
import '../widgets/app_logo.dart';

/// Main navigation with responsive design and real-time updates
class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  bool _isDrawerOpen = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (!authSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data!;
        
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
            final userRole = userData['role'] ?? 'user';
        final isVendor = userRole == 'vendor' || userRole == 'goods_vendor' || userRole == 'service_vendor';

                        // Build screens list
        final List<Widget> screens = [
              const UltraModernMiningScreen(),
          const ExploreScreen(),
              const ModernMarketplaceHome(),
              if (isVendor) const FunctionalVendorDashboard(),
          const WalletScreen(),
          const ReferralScreen(),
          const CommunityScreen(),
          const AllTransactionsScreen(),
          const SettingsScreen(),
        ];

            // Calculate indices for all screens
        final int vendorIndex = isVendor ? 3 : -1;
        final int walletIndex = isVendor ? 4 : 3;
        final int referralIndex = isVendor ? 5 : 4;
        final int communityIndex = isVendor ? 6 : 5;
        final int transactionsIndex = isVendor ? 7 : 6;
        final int settingsIndex = isVendor ? 8 : 7;

            return LayoutBuilder(
              builder: (context, constraints) {
                final bool isMobile = constraints.maxWidth < 768;
                return _buildResponsiveLayout(screens, isVendor, vendorIndex, walletIndex, referralIndex, communityIndex, transactionsIndex, settingsIndex, isMobile);
              },
            );
          },
        );
                  },
                );
              }

    Widget _buildResponsiveLayout(List<Widget> screens, bool isVendor, int vendorIndex, int walletIndex, int referralIndex, int communityIndex, int transactionsIndex, int settingsIndex, bool isMobile) {
    if (isMobile) {
      // Mobile: Drawer navigation
      return Scaffold(
        key: _scaffoldKey,
        appBar: _buildMobileAppBar(),
        drawer: _buildDrawer(isVendor, vendorIndex, walletIndex, referralIndex, communityIndex, transactionsIndex, settingsIndex),
        body: IndexedStack(
          index: _selectedIndex,
          children: screens,
        ),
      );
    } else {
      // Desktop: Collapsible side navigation
      return Scaffold(
        body: Row(
              children: [
            _buildCollapsibleSideNavigation(isVendor, vendorIndex, walletIndex, referralIndex, communityIndex, transactionsIndex, settingsIndex),
            Expanded(
                    child: Column(
                      children: [
                  _buildDesktopAppBar(),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: screens,
                                ),
                              ),
                            ],
                          ),
                        ),
          ],
        ),
      );
    }
  }

  // Mobile app bar
  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 1,
      iconTheme: const IconThemeData(color: Colors.yellow),
      title: const AppLogo(),
      centerTitle: true,
    );
  }

  // Desktop app bar
  Widget _buildDesktopAppBar() {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(0, 2),
            blurRadius: 4,
                ),
              ],
            ),
                            child: Row(
                              children: [
          // Toggle button
          IconButton(
            onPressed: () => setState(() => _isDrawerOpen = !_isDrawerOpen),
            icon: Icon(_isDrawerOpen ? Icons.close : Icons.menu),
            color: Colors.yellow,
          ),
          const Expanded(child: SizedBox()),
          // User profile or actions can go here
        ],
      ),
    );
  }

  // Mobile drawer
  Widget _buildDrawer(bool isVendor, int vendorIndex, int walletIndex, int referralIndex, int communityIndex, int transactionsIndex, int settingsIndex) {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.black,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
            children: [
                Flexible(
                  child: AppLogo(),
                ),
                SizedBox(height: 8),
                Flexible(
                    child: Text(
                    'AZIX App',
                    style: TextStyle(
                      color: Colors.yellow,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(Icons.home, 'Home', 0),
                  _buildDrawerItem(Icons.explore, 'Explore', 1),
                  _buildDrawerItem(Icons.shopping_cart, 'Market', 2),
                  if (isVendor) _buildDrawerItem(Icons.store, 'Vendor', vendorIndex),
                  _buildDrawerItem(Icons.account_balance_wallet, 'Wallet', walletIndex),
                  _buildDrawerItem(Icons.share, 'Referrals', referralIndex),
                  _buildDrawerItem(Icons.people, 'Community', communityIndex),
                  _buildDrawerItem(Icons.history, 'Transactions', transactionsIndex),
                  _buildNotificationDrawerItem(),
                  _buildDrawerItem(Icons.settings, 'Settings', settingsIndex),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Collapsible side navigation for desktop
  Widget _buildCollapsibleSideNavigation(bool isVendor, int vendorIndex, int walletIndex, int referralIndex, int communityIndex, int transactionsIndex, int settingsIndex) {
    final double width = _isDrawerOpen ? 250 : 70;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: width,
      decoration: const BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(2, 0),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo section
          Container(
            height: 60,
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.yellow, width: 1),
              ),
            ),
            child: _isDrawerOpen 
              ? const AppLogo()
              : const Icon(Icons.apps, color: Colors.yellow, size: 30),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildCollapsibleNavItem(Icons.home, 'Home', 0),
                _buildCollapsibleNavItem(Icons.explore, 'Explore', 1),
                _buildCollapsibleNavItem(Icons.shopping_cart, 'Market', 2),
                if (isVendor) _buildCollapsibleNavItem(Icons.store, 'Vendor', vendorIndex),
                _buildCollapsibleNavItem(Icons.account_balance_wallet, 'Wallet', walletIndex),
                _buildCollapsibleNavItem(Icons.share, 'Referrals', referralIndex),
                _buildCollapsibleNavItem(Icons.people, 'Community', communityIndex),
                _buildCollapsibleNavItem(Icons.history, 'Transactions', transactionsIndex),
                _buildCollapsibleNotificationItem(),
                _buildCollapsibleNavItem(Icons.settings, 'Settings', settingsIndex),
              ],
            ),
          ),
        ],
      ),
    );
  }



    // Drawer item for mobile
  Widget _buildDrawerItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
        color: isSelected ? Colors.yellow.withOpacity(0.2) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.black : Colors.grey.shade600,
        ),
        title: Text(
              label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onTap: () {
          setState(() => _selectedIndex = index);
          Navigator.pop(context); // Close drawer
        },
      ),
    );
  }

  // Collapsible nav item for desktop
  Widget _buildCollapsibleNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    
    Widget listTile = Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
        color: isSelected ? Colors.yellow.withOpacity(0.2) : null,
        borderRadius: BorderRadius.circular(8),
        border: isSelected 
          ? Border.all(color: Colors.yellow, width: 1)
          : null,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: _isDrawerOpen ? 16 : 8,
          vertical: 0,
        ),
        leading: Icon(
              icon,
          color: isSelected ? Colors.yellow : Colors.white70,
              size: 24,
            ),
        title: _isDrawerOpen 
          ? Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.yellow : Colors.white70,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            )
          : null,
        onTap: () => setState(() => _selectedIndex = index),
      ),
    );

    // Add tooltip when collapsed
    if (!_isDrawerOpen) {
      return Tooltip(
        message: label,
        preferBelow: false,
        child: listTile,
      );
    }

    return listTile;
  }
  // Notification item for mobile drawer
  Widget _buildNotificationDrawerItem() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: ListTile(
          leading: Icon(Icons.notifications, color: Colors.grey.shade600),
          title: Text(
            'Notifications',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          onTap: () {
            Navigator.pop(context); // Close drawer
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
        ),
      );
    }

    return StreamBuilder<int>(
      stream: NotificationService.getUnreadCount(user.uid),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        
        return IntrinsicHeight(
      child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: unreadCount > 0 ? Colors.yellow.withOpacity(0.2) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              dense: true,
              leading: Stack(
                clipBehavior: Clip.none,
                  children: [
                    Icon(
                    Icons.notifications, 
                    color: unreadCount > 0 ? Colors.black : Colors.grey.shade600,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                        fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              title: Text(
                unreadCount > 0 ? 'Notifications ($unreadCount)' : 'Notifications',
                style: TextStyle(
                  color: unreadCount > 0 ? Colors.black : Colors.grey.shade700,
                  fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // Notification item for collapsible desktop navigation
  Widget _buildCollapsibleNotificationItem() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: _isDrawerOpen ? 16 : 8,
            vertical: 0,
          ),
          leading: const Icon(Icons.notifications, color: Colors.white70, size: 24),
          title: _isDrawerOpen 
            ? const Text(
                'Notifications',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              )
            : null,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        ),
      ),
    );
  }
  
    return StreamBuilder<int>(
      stream: NotificationService.getUnreadCount(user.uid),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        
        Widget notificationItem = IntrinsicHeight(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: unreadCount > 0 ? Colors.yellow.withOpacity(0.2) : null,
              borderRadius: BorderRadius.circular(8),
              border: unreadCount > 0 
                ? Border.all(color: Colors.yellow, width: 1)
                : null,
            ),
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: _isDrawerOpen ? 16 : 8,
                vertical: 0,
              ),
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.notifications,
                    color: unreadCount > 0 ? Colors.yellow : Colors.white70,
        size: 24,
      ),
                  if (unreadCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              title: _isDrawerOpen 
                ? Text(
                    unreadCount > 0 ? 'Notifications ($unreadCount)' : 'Notifications',
                    style: TextStyle(
                      color: unreadCount > 0 ? Colors.yellow : Colors.white70,
                      fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            ),
          ),
        );

        // Add tooltip when collapsed
        if (!_isDrawerOpen) {
          return Tooltip(
            message: unreadCount > 0 ? 'Notifications ($unreadCount)' : 'Notifications',
            preferBelow: false,
            child: notificationItem,
          );
        }

        return notificationItem;
      },
    );
  }
}
