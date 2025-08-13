import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/stellar_provider.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_layout.dart';
import '../widgets/stellar_wallet_prompt.dart';
import 'pi_home_screen.dart';
import 'explore_screen.dart';
import 'marketplace_home_screen.dart';
import 'community_screen.dart';
import 'settings_screen.dart';
import '../screens/user_notifications_screen.dart';
import '../providers/admin_provider.dart';
import 'wallet_screen.dart';
import 'all_transactions_screen.dart';
import '../widgets/app_logo.dart';
import 'wishlist_screen.dart';
import 'order_history_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'vendor/vendor_dashboard_screen.dart';
import 'transaction_test_screen.dart';
import 'referral_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  // Screens and navItems are now built dynamically in build()

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }



  void _onTabTapped(int index, List<Widget> screens, int vendorIndex, bool isVendor) async {
    setState(() {
      _currentIndex = index;
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(index);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWebPlatform = kIsWeb;
    final bool showAppBar = isWebPlatform && (ResponsiveLayout.isMobile(context) || 
                           (ResponsiveLayout.isTablet(context) && 
                            MediaQuery.of(context).orientation == Orientation.portrait));
    final String screenTitle = _getScreenTitle(_currentIndex);

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseAuth.instance.currentUser == null
          ? null
          : FirebaseFirestore.instance.collection('USER').doc(FirebaseAuth.instance.currentUser!.uid).get(),
      builder: (context, snapshot) {
        String? userRole;
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          userRole = (snapshot.data!.data() as Map<String, dynamic>?)?['role'] as String?;
        }
        final isVendor = userRole == 'vendor' || userRole == 'goods_vendor' || userRole == 'service_vendor';

        // --- Build screens and nav items dynamically, with vendor nav in a clean order ---
        final List<Widget> screens = [
          const PiHomeScreen(),
          const ExploreScreen(),
          const MarketplaceHomeScreen(),
          if (isVendor) const VendorDashboardScreen(),
          const WalletScreen(),
          const ReferralScreen(),
          const CommunityScreen(),
          const AllTransactionsScreen(),
          const SettingsScreen(),
        ];
        // Indexes: 0=Home, 1=Explore, 2=Market, 3=Vendor (if present), 4/3=Wallet, 5/4=Referral, ...
        final int vendorIndex = isVendor ? 3 : -1;
        final int walletIndex = isVendor ? 4 : 3;
        final int referralIndex = isVendor ? 5 : 4;
        final int communityIndex = isVendor ? 6 : 5;
        final int transactionsIndex = isVendor ? 7 : 6;
        final int settingsIndex = isVendor ? 8 : 7;
        final List<Widget> navItems = [
          _buildNavItem(Icons.home, 'Home', 0, screens, vendorIndex, isVendor),
          _buildNavItem(Icons.explore, 'Explore', 1, screens, vendorIndex, isVendor),
          _buildNavItem(Icons.shopping_cart, 'Market', 2, screens, vendorIndex, isVendor),
          if (isVendor) _buildNavItem(Icons.store, 'Vendor', vendorIndex, screens, vendorIndex, isVendor),
          _buildNavItem(Icons.account_balance_wallet, 'Wallet', walletIndex, screens, vendorIndex, isVendor),
          _buildNavItem(Icons.share, 'Referrals', referralIndex, screens, vendorIndex, isVendor),
          _buildNavItem(Icons.people, 'Community', communityIndex, screens, vendorIndex, isVendor),
          _buildNavItem(Icons.history, 'Transactions', transactionsIndex, screens, vendorIndex, isVendor),
          _buildNotificationNavItem(),
          _buildNavItem(Icons.settings, 'Settings', settingsIndex, screens, vendorIndex, isVendor),
        ];
        int effectiveIndex = _currentIndex;
        if (isVendor && _currentIndex > 2 && _currentIndex < screens.length) effectiveIndex = _currentIndex;
        return Scaffold(
          appBar: showAppBar ? AppBar(
            backgroundColor: AppTheme.black,
            title: Row(
              children: [
                const AppLogo(width: 32, height: 32),
                const SizedBox(width: 12),
                Text(
                  'AZIX',
                  style: AppTheme.headingSmall.copyWith(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            elevation: 0,
            actions: [],
          ) : null,
          body: ResponsiveLayoutBuilder(
            mobileBuilder: (context, constraints) => PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: screens,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
            tabletBuilder: (context, constraints) {
              final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
              if (isLandscape && !isWebPlatform) {
                return Row(
                  children: [
                    Container(
                      width: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.black,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(5, 0),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: const AppLogo(width: 32, height: 32),
                            ),
                            const SizedBox(height: 40),
                            Expanded(
                              child: ListView(
                                children: navItems,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: screens[effectiveIndex],
                    ),
                  ],
                );
              } else {
                return PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: screens,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                );
              }
            },
            desktopBuilder: (context, constraints) => Row(
              children: [
                Container(
                  width: 240,
                  decoration: BoxDecoration(
                    color: AppTheme.black,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(5, 0),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const AppLogo(width: 32, height: 32),
                              const SizedBox(width: 12),
                              Text(
                                'AZIX',
                                style: AppTheme.headingMedium.copyWith(
                                  color: AppTheme.primaryGold,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        Expanded(
                          child: ListView(
                            children: navItems,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: screens[effectiveIndex],
                ),
              ],
            ),
          ),
          bottomNavigationBar: !isWebPlatform ? ResponsiveLayout.builder(
            context: context,
            mobile: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: navItems,
            ),
            tablet: MediaQuery.of(context).orientation == Orientation.portrait 
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: navItems,
                  )
                : null,
            desktop: null,
          ) : null,
          drawer: isWebPlatform && (ResponsiveLayout.isMobile(context) || 
                 (ResponsiveLayout.isTablet(context) && 
                  MediaQuery.of(context).orientation == Orientation.portrait)) 
              ? Drawer(
                  child: Container(
                    color: AppTheme.black,
                    child: SafeArea(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet,
                                  color: AppTheme.primaryGold,
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'AZIX',
                                  style: AppTheme.headingMedium.copyWith(
                                    color: AppTheme.primaryGold,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                          Expanded(
                            child: ListView(
                              children: navItems,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
  
  // Helper method to get the title for the current screen
  String _getScreenTitle(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Explore';
      case 2:
        return 'Market';
      case 3:
        return 'Wallet';
      case 4:
        return 'Community';
      case 5:
        return 'Transactions';
      case 6:
        return 'Settings';
      default:
        return 'AZIX';
    }
  }

  // _buildTabletLayout, _buildDesktopLayout, and _buildBottomNavigationBar are not needed since navigation is now dynamic in build().

  Widget _buildNotificationNavItem() {
    final unreadCount = Provider.of<AdminProvider>(context).unreadNotificationCount;
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const UserNotificationsScreen(),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.notifications,
                color: AppTheme.grey,
                size: 24,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Alerts',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.grey,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, List<Widget> screens, int vendorIndex, bool isVendor) {
    final isActive = _currentIndex == index;
    return InkWell(
      onTap: () async {
        _onTabTapped(index, screens, vendorIndex, isVendor);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? AppTheme.primaryGold : AppTheme.grey,
            size: 24,
          )
              .animate(target: isActive ? 1 : 0)
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.2, 1.2),
                duration: const Duration(milliseconds: 200),
              ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: isActive ? AppTheme.primaryGold : AppTheme.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideNavItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    
    return InkWell(
      onTap: () async {
        _onTabTapped(index, [], -1, false); // Pass empty list for screens and -1 for vendorIndex
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isActive ? AppTheme.primaryGold : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppTheme.primaryGold : AppTheme.grey,
              size: 28,
            )
                .animate(target: isActive ? 1 : 0)
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.2, 1.2),
                  duration: const Duration(milliseconds: 200),
                ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: isActive ? AppTheme.primaryGold : AppTheme.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopNavItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    
    return InkWell(
      onTap: () async {
        _onTabTapped(index, [], -1, false); // Pass empty list for screens and -1 for vendorIndex
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isActive ? AppTheme.primaryGold : Colors.transparent,
              width: 3,
            ),
          ),
          color: isActive ? AppTheme.darkGrey.withOpacity(0.3) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? AppTheme.primaryGold : AppTheme.grey,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: isActive ? AppTheme.primaryGold : AppTheme.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Web-specific side drawer for mobile and tablet portrait views
  Widget _buildWebSideDrawer() {
    return Drawer(
      child: Container(
        color: AppTheme.black,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: AppTheme.primaryGold,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'AZIX',
                      style: AppTheme.headingMedium.copyWith(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: ListView(
                  children: [
                    _buildWebDrawerItem(Icons.home, 'Home', 0),
                    _buildWebDrawerItem(Icons.explore, 'Explore', 1),
                    _buildWebDrawerItem(Icons.shopping_cart, 'Market', 2),
                    _buildWebDrawerItem(Icons.account_balance_wallet, 'Wallet', 3),
                    _buildWebDrawerItem(Icons.people, 'Community', 4),
                    _buildWebDrawerItem(Icons.history, 'Transactions', 5),
                    _buildWebDrawerItem(Icons.settings, 'Settings', 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Web drawer item with navigation functionality
  Widget _buildWebDrawerItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? AppTheme.primaryGold : AppTheme.grey,
        size: 24,
      ),
      title: Text(
        label,
        style: AppTheme.bodyMedium.copyWith(
          color: isActive ? AppTheme.primaryGold : AppTheme.grey,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isActive,
      selectedTileColor: AppTheme.darkGrey.withOpacity(0.3),
      onTap: () async {
          // Close the drawer first to avoid UI issues
          Navigator.pop(context);
        // Navigate to the selected screen
          _onTabTapped(index, [], -1, false);
      },
    );
  }
}

