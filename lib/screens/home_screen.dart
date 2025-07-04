import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../providers/auth_provider.dart';
import '../providers/stellar_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_logo.dart';
import '../widgets/app_logo.dart';
import '../widgets/custom_button.dart';
import '../widgets/stellar_wallet_card.dart';
import '../utils/responsive_layout.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh the wallet balance and check Akofa trustline when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
      if (stellarProvider.hasWallet) {
        stellarProvider.refreshBalance();
        stellarProvider.checkAkofaTrustline();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final stellarProvider = Provider.of<StellarProvider>(context);
    final user = authProvider.user;
    final isWebPlatform = kIsWeb;
    
    // Determine layout based on screen size
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    
    // Debug print
    print('HomeScreen build - hasWallet: ${stellarProvider.hasWallet}, publicKey: ${stellarProvider.publicKey}');
    
    return Scaffold(
      body: Container(
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
          child: ResponsiveContainer(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveLayout.getValueForScreenType<double>(
                context: context,
                mobile: 24.0,
                tablet: 48.0,
                desktop: 64.0,
                largeDesktop: 80.0,
              ),
              vertical: 24.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                // Logo size based on screen size
                AppLogo(
                  width: ResponsiveLayout.getValueForScreenType<double>(
                    context: context,
                    mobile: 120,
                    tablet: 150,
                    desktop: 180,
                  ),
                  height: ResponsiveLayout.getValueForScreenType<double>(
                    context: context,
                    mobile: 120,
                    tablet: 150,
                    desktop: 180,
                  ),
                ),
                SizedBox(height: isDesktop ? 60 : 40),
                Text(
                  'Welcome${user?.displayName != null ? ', ${user!.displayName}' : ''}!',
                  textAlign: TextAlign.center,
                  style: (isDesktop 
                    ? AppTheme.headingLarge.copyWith(fontSize: 36)
                    : AppTheme.headingLarge).copyWith(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.w800,
                  ),
                )
                    .animate()
                    .fadeIn(
                      duration: const Duration(milliseconds: 800),
                      delay: const Duration(milliseconds: 300),
                    )
                    .slideY(
                      begin: 0.2,
                      end: 0,
                      curve: Curves.easeOut,
                      duration: const Duration(milliseconds: 800),
                    ),
                SizedBox(height: isDesktop ? 24 : 16),
                Text(
                  'You have successfully signed in to your account.',
                  textAlign: TextAlign.center,
                  style: (isDesktop 
                    ? AppTheme.bodyLarge.copyWith(fontSize: 20)
                    : AppTheme.bodyLarge).copyWith(
                    color: AppTheme.white,
                  ),
                )
                    .animate()
                    .fadeIn(
                      duration: const Duration(milliseconds: 800),
                      delay: const Duration(milliseconds: 500),
                    )
                    .slideY(
                      begin: 0.2,
                      end: 0,
                      curve: Curves.easeOut,
                      duration: const Duration(milliseconds: 800),
                    ),
                
                // Stellar Wallet Card - Constrained width for larger screens
                Container(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop 
                      ? 600 
                      : isTablet 
                        ? 500 
                        : double.infinity,
                  ),
                  child: StellarWalletCard(
                    publicKey: stellarProvider.publicKey,
                    balance: stellarProvider.balance,
                    hasWallet: stellarProvider.hasWallet,
                    isLoading: stellarProvider.isLoading,
                    hasAkofaTrustline: stellarProvider.hasAkofaTrustline,
                    akofaBalance: stellarProvider.akofaBalance,
                  ),
                ),
                
                const Spacer(flex: 1),
                
                // Refresh balance button (only shown if wallet exists)
                if (stellarProvider.hasWallet)
                  TextButton.icon(
                    onPressed: () {
                      stellarProvider.refreshBalance();
                    },
                    icon: const Icon(Icons.refresh, color: AppTheme.primaryGold, size: 18),
                    label: Text(
                      'Refresh Balance',
                      style: (isDesktop 
                        ? AppTheme.bodySmall.copyWith(fontSize: 16)
                        : AppTheme.bodySmall).copyWith(
                        color: AppTheme.primaryGold,
                      ),
                    ),
                  ).animate().fadeIn(
                        duration: const Duration(milliseconds: 800),
                        delay: const Duration(milliseconds: 650),
                      ),
                
                SizedBox(height: isDesktop ? 24 : 16),
                // Button with constrained width for larger screens
                Container(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 300 : isTablet ? 250 : double.infinity,
                  ),
                  child: CustomButton(
                    text: 'Sign Out',
                    onPressed: () async {
                      await authProvider.signOut();
                    },
                    isOutlined: true,
                  ).animate().fadeIn(
                        duration: const Duration(milliseconds: 800),
                        delay: const Duration(milliseconds: 700),
                      ),
                ),
                SizedBox(height: isDesktop ? 60 : 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}