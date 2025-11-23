import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'explore_screen.dart';
import 'marketplace/new_marketplace.dart';

import 'vendor/functional_vendor_dashboard.dart';
import 'community_screen.dart';
import 'settings_screen.dart';
import 'enhanced_wallet_screen.dart';
import 'referral_screen.dart';
import 'mining_screen.dart';
import 'raffle/raffle_hub_screen.dart';
import 'raffle/my_raffles_screen.dart';
import 'token_analytics_screen.dart';
import '../widgets/app_logo.dart';
import '../providers/admin_provider.dart';

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

            final userData =
                userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
            final userRole = userData['role'] ?? 'user';
            final isVendor =
                userRole == 'vendor' ||
                userRole == 'goods_vendor' ||
                userRole == 'service_vendor';
            final isAdmin = userRole == 'admin' || userRole == 'super_admin';

            // Build screens list - use builders to prevent premature initialization
            Widget _buildScreen(int index) {
              final List<Widget Function()> screenBuilders = [
                () => const MiningScreen(),
                () => const ExploreScreen(),
                () => const WebViewPage(),
                if (isVendor) () => const FunctionalVendorDashboard(),
                () => const EnhancedWalletScreen(), // Only built when navigated to
                () => const TokenAnalyticsScreen(), // Token analytics
                () => const ReferralScreen(),
                () => const RaffleHubScreen(),
                if (isAdmin) () => const MyRafflesScreen(),
                () => const CommunityScreen(),
                () => const SettingsScreen(),
              ];
              return screenBuilders[index]();
            }
            
            // For compatibility with existing code
            final int screensLength = [
              1, // MiningScreen
              1, // ExploreScreen
              1, // WebViewPage
              if (isVendor) 1, // FunctionalVendorDashboard
              1, // EnhancedWalletScreen
              1, // TokenAnalyticsScreen
              1, // ReferralScreen
              1, // RaffleHubScreen
              if (isAdmin) 1, // MyRafflesScreen
              1, // CommunityScreen
              1, // SettingsScreen
            ].length;

            // Calculate indices for all screens
            final int miningIndex = 0;
            final int exploreIndex = 1;
            final int marketIndex = 2;
            final int vendorIndex = isVendor ? 3 : -1;
            final int walletIndex = isVendor ? 4 : 3;
            final int analyticsIndex = isVendor ? 5 : 4;
            final int referralIndex = isVendor ? 6 : 5;
            final int raffleHubIndex = isVendor ? 7 : 6;
            final int myRafflesIndex = isAdmin ? (isVendor ? 8 : 7) : -1;
            final int communityIndex = isAdmin
                ? (isVendor ? 9 : 8)
                : (isVendor ? 8 : 7);
            final int settingsIndex = isAdmin
                ? (isVendor ? 10 : 9)
                : (isVendor ? 9 : 8);

            return LayoutBuilder(
              builder: (context, constraints) {
                final bool isMobile = constraints.maxWidth < 768;
                return _buildResponsiveLayout(
                  _buildScreen,
                  screensLength,
                  isVendor,
                  isAdmin,
                  miningIndex,
                  exploreIndex,
                  marketIndex,
                  vendorIndex,
                  walletIndex,
                  analyticsIndex,
                  referralIndex,
                  raffleHubIndex,
                  myRafflesIndex,
                  communityIndex,
                  settingsIndex,
                  isMobile,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildResponsiveLayout(
    Widget Function(int) buildScreen,
    int screensLength,
    bool isVendor,
    bool isAdmin,
    int miningIndex,
    int exploreIndex,
    int marketIndex,
    int vendorIndex,
    int walletIndex,
    int analyticsIndex,
    int referralIndex,
    int raffleHubIndex,
    int myRafflesIndex,
    int communityIndex,
    int settingsIndex,
    bool isMobile,
  ) {
    // Use collapsible side navigation for both mobile and desktop
    return Scaffold(
      body: Row(
        children: [
          _buildCollapsibleSideNavigation(
            isVendor,
            isAdmin,
            miningIndex,
            exploreIndex,
            marketIndex,
            vendorIndex,
            walletIndex,
            analyticsIndex,
            referralIndex,
            raffleHubIndex,
            myRafflesIndex,
            communityIndex,
            settingsIndex,
            isMobile,
          ),
          Expanded(
            child: Column(
              children: [
                isMobile ? _buildMobileAppBar() : _buildDesktopAppBar(),
                Expanded(
                  child: buildScreen(_selectedIndex), // Only build the selected screen
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Mobile app bar
  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 1,
      iconTheme: const IconThemeData(color: Colors.yellow),
      leading: IconButton(
        onPressed: () => setState(() => _isDrawerOpen = !_isDrawerOpen),
        icon: Icon(_isDrawerOpen ? Icons.close : Icons.menu),
        color: Colors.yellow,
      ),
      title: const AppLogo(width: 80, height: 40),
    );
  }

  // Desktop app bar
  Widget _buildDesktopAppBar() {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4),
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
  Widget _buildDrawer(
    bool isVendor,
    bool isAdmin,
    int miningIndex,
    int exploreIndex,
    int marketIndex,
    int vendorIndex,
    int walletIndex,
    int referralIndex,
    int raffleHubIndex,
    int myRafflesIndex,
    int communityIndex,
    int settingsIndex,
  ) {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.black),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: AppLogo()),
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
                  _buildDrawerItem(Icons.engineering, 'Mining', miningIndex),
                  _buildDrawerItem(Icons.explore, 'Explore', exploreIndex),
                  _buildDrawerItem(Icons.shopping_cart, 'Market', marketIndex),
                  if (isVendor)
                    _buildDrawerItem(Icons.store, 'Vendor', vendorIndex),
                  _buildDrawerItem(
                    Icons.account_balance_wallet,
                    'Wallet',
                    walletIndex,
                  ),
                  _buildDrawerItem(Icons.share, 'Referrals', referralIndex),
                  _buildDrawerItem(
                    Icons.local_activity,
                    'Raffles',
                    raffleHubIndex,
                  ),
                  if (isAdmin)
                    _buildDrawerItem(
                      Icons.emoji_events,
                      'My Raffles',
                      myRafflesIndex,
                    ),
                  _buildDrawerItem(Icons.people, 'Community', communityIndex),
                  _buildDrawerItem(Icons.settings, 'Settings', settingsIndex),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Collapsible side navigation for desktop and mobile
  Widget _buildCollapsibleSideNavigation(
    bool isVendor,
    bool isAdmin,
    int miningIndex,
    int exploreIndex,
    int marketIndex,
    int vendorIndex,
    int walletIndex,
    int analyticsIndex,
    int referralIndex,
    int raffleHubIndex,
    int myRafflesIndex,
    int communityIndex,
    int settingsIndex,
    bool isMobile,
  ) {
    final double width = _isDrawerOpen
        ? (isMobile ? 200 : 250)
        : (isMobile ? 0 : 70);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: width,
      decoration: const BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(color: Colors.black26, offset: Offset(2, 0), blurRadius: 4),
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
                _buildCollapsibleNavItem(
                  Icons.engineering,
                  'Mining',
                  miningIndex,
                ),
                _buildCollapsibleNavItem(
                  Icons.explore,
                  'Explore',
                  exploreIndex,
                ),
                _buildCollapsibleNavItem(
                  Icons.shopping_cart,
                  'Market',
                  marketIndex,
                ),
                if (isVendor)
                  _buildCollapsibleNavItem(Icons.store, 'Vendor', vendorIndex),
                _buildCollapsibleNavItem(
                  Icons.account_balance_wallet,
                  'Wallet',
                  walletIndex,
                ),
                _buildCollapsibleNavItem(
                  Icons.analytics,
                  'Analytics',
                  analyticsIndex,
                ),
                _buildCollapsibleNavItem(
                  Icons.share,
                  'Referrals',
                  referralIndex,
                ),
                _buildCollapsibleNavItem(
                  Icons.local_activity,
                  'Raffles',
                  raffleHubIndex,
                ),
                if (isAdmin)
                  _buildCollapsibleNavItem(
                    Icons.emoji_events,
                    'My Raffles',
                    myRafflesIndex,
                  ),
                _buildCollapsibleNavItem(
                  Icons.people,
                  'Community',
                  communityIndex,
                ),
                _buildCollapsibleNavItem(
                  Icons.settings,
                  'Settings',
                  settingsIndex,
                ),
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
        border: isSelected ? Border.all(color: Colors.yellow, width: 1) : null,
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
      return Tooltip(message: label, preferBelow: false, child: listTile);
    }

    return listTile;
  }
}
