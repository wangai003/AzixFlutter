import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/custom_button.dart';
import '../utils/responsive_layout.dart';
// Auth flow is handled by the root Wrapper; we navigate back to it after landing.

class LandingScreen extends StatefulWidget {
  const LandingScreen({Key? key}) : super(key: key);

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 500 && !_showBackToTop) {
        setState(() => _showBackToTop = true);
      } else if (_scrollController.offset <= 500 && _showBackToTop) {
        setState(() => _showBackToTop = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _markLandingAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_landing', true);
  }

  Future<void> _navigateToAuth() async {
    await _markLandingAsSeen();
    if (!mounted) return;

    // Return to the root route (Wrapper) so it can orchestrate auth/navigation
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    return Scaffold(
      body: Stack(
        children: [
          // Main scrollable content
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                // Hero Section
                _buildHeroSection(isDesktop, isTablet, isMobile),
                
                // Features Section
                _buildFeaturesSection(isDesktop, isTablet, isMobile),
                
                // How It Works Section
                _buildHowItWorksSection(isDesktop, isTablet, isMobile),
                
                // Ecosystem Section
                _buildEcosystemSection(isDesktop, isTablet, isMobile),
                
                // CTA Section
                _buildCTASection(isDesktop, isTablet, isMobile),
                
                // Footer
                _buildFooter(isDesktop, isTablet, isMobile),
              ],
            ),
          ),
          
          // Back to top button
          if (_showBackToTop)
            Positioned(
              bottom: 32,
              right: 32,
              child: FloatingActionButton(
                onPressed: _scrollToTop,
                backgroundColor: AppTheme.primaryGold,
                child: const Icon(Icons.arrow_upward, color: AppTheme.black),
              ).animate().fadeIn().scale(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(bool isDesktop, bool isTablet, bool isMobile) {
    return Container(
      height: isMobile ? 700 : (isTablet ? 800 : 900),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.black,
            const Color(0xFF1a1a1a),
            const Color(0xFF0d0d0d),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Animated background particles
          ...List.generate(
            20,
            (index) => Positioned(
              left: (index * 100) % MediaQuery.of(context).size.width,
              top: (index * 50) % 600,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .fadeIn(duration: 1000.ms)
                  .fadeOut(duration: 1000.ms, delay: 2000.ms),
            ),
          ),
          
          // Content
          SafeArea(
            child: ResponsiveContainer(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 24.0 : (isTablet ? 48.0 : 80.0),
                vertical: 40.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo and tagline
                  AppLogo(
                    width: isMobile ? 100 : (isTablet ? 130 : 160),
                    height: isMobile ? 100 : (isTablet ? 130 : 160),
                  ).animate().fadeIn(duration: 800.ms).scale(),
                  
                  const SizedBox(height: 40),
                  
                  // Main heading
                  Text(
                    'Welcome to AZIX',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isMobile ? 40 : (isTablet ? 56 : 72),
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryGold,
                      height: 1.1,
                      letterSpacing: -1,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 1000.ms, delay: 200.ms)
                      .slideY(begin: 0.3, end: 0),
                  
                  const SizedBox(height: 24),
                  
                  // Subtitle
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 700 : (isTablet ? 600 : double.infinity),
                    ),
                    child: Text(
                      'The Hub for Seamless, Super-Fast Transactions',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isMobile ? 20 : (isTablet ? 24 : 28),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.white,
                        height: 1.4,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 1000.ms, delay: 400.ms)
                        .slideY(begin: 0.3, end: 0),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Description
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 800 : (isTablet ? 650 : double.infinity),
                    ),
                    child: Text(
                      'Your gateway to cross-border trade and tokenized assets. Experience lightning-fast transactions, gasless transfers, and seamless global commerce—all in one powerful platform.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isMobile ? 16 : (isTablet ? 18 : 20),
                        color: AppTheme.white.withOpacity(0.8),
                        height: 1.6,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 1000.ms, delay: 600.ms)
                        .slideY(begin: 0.3, end: 0),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // CTA Buttons
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      SizedBox(
                        width: isMobile ? double.infinity : 200,
                        child: CustomButton(
                          text: 'Get Started',
                          onPressed: _navigateToAuth,
                        )
                            .animate()
                            .fadeIn(duration: 1000.ms, delay: 800.ms)
                            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
                      ),
                      SizedBox(
                        width: isMobile ? double.infinity : 200,
                        child: CustomButton(
                          text: 'Learn More',
                          isOutlined: true,
                          onPressed: () {
                            _scrollController.animateTo(
                              800,
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.easeInOut,
                            );
                          },
                        )
                            .animate()
                            .fadeIn(duration: 1000.ms, delay: 1000.ms)
                            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Stats Row
                  if (!isMobile)
                    _buildStatsRow(isDesktop, isTablet)
                        .animate()
                        .fadeIn(duration: 1000.ms, delay: 1200.ms)
                        .slideY(begin: 0.3, end: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isDesktop, bool isTablet) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('Super-Fast', 'Lightning Speed', Icons.flash_on),
        _buildStatItem('Cross-Border', 'Global Trade', Icons.public),
        _buildStatItem('Tokenized', 'Digital Assets', Icons.account_balance),
      ],
    );
  }

  Widget _buildStatItem(String title, String subtitle, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryGold, size: 32),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryGold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesSection(bool isDesktop, bool isTablet, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.0 : (isTablet ? 48.0 : 80.0),
        vertical: isMobile ? 60.0 : 100.0,
      ),
      color: const Color(0xFF1a1a1a),
      child: Column(
        children: [
          // Section title
          Text(
            'Powerful Features',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 32 : (isTablet ? 40 : 48),
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryGold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Built for seamless transactions and global commerce',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 16 : (isTablet ? 18 : 20),
              color: AppTheme.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 60),
          
          // Features grid
          if (isDesktop || isTablet)
            _buildFeaturesGrid(isDesktop, isTablet)
          else
            _buildFeaturesList(),
        ],
      ),
    );
  }

  Widget _buildFeaturesGrid(bool isDesktop, bool isTablet) {
    return Wrap(
      spacing: 32,
      runSpacing: 32,
      alignment: WrapAlignment.center,
      children: [
        _buildFeatureCard(
          'Super-Fast Transactions',
          'Experience lightning-speed transactions with instant confirmations across multiple blockchains',
          Icons.speed,
          const Color(0xFFFFD700),
        ),
        _buildFeatureCard(
          'Cross-Border Trade',
          'Trade globally without borders, barriers, or excessive fees. Connect with buyers and sellers worldwide',
          Icons.language,
          const Color(0xFF2196F3),
        ),
        _buildFeatureCard(
          'Tokenized Assets',
          'Access a complete ecosystem of tokenized digital assets including AKOFA tokens and more',
          Icons.stars,
          const Color(0xFF4CAF50),
        ),
        _buildFeatureCard(
          'Seamless Payments',
          'Gasless transactions powered by Biconomy—send tokens without paying gas fees',
          Icons.payment,
          const Color(0xFFFF9800),
        ),
        _buildFeatureCard(
          'Global Marketplace',
          'Buy and sell goods and services worldwide using crypto with secure escrow protection',
          Icons.storefront,
          const Color(0xFF9C27B0),
        ),
        _buildFeatureCard(
          'Multi-Chain Wallet',
          'Secure wallet supporting Stellar and Polygon with encrypted key management',
          Icons.account_balance_wallet,
          const Color(0xFFE91E63),
        ),
      ],
    );
  }

  Widget _buildFeaturesList() {
    return Column(
      children: [
        _buildFeatureCard(
          'Super-Fast Transactions',
          'Experience lightning-speed transactions with instant confirmations across multiple blockchains',
          Icons.speed,
          const Color(0xFFFFD700),
        ),
        const SizedBox(height: 24),
        _buildFeatureCard(
          'Cross-Border Trade',
          'Trade globally without borders, barriers, or excessive fees. Connect with buyers and sellers worldwide',
          Icons.language,
          const Color(0xFF2196F3),
        ),
        const SizedBox(height: 24),
        _buildFeatureCard(
          'Tokenized Assets',
          'Access a complete ecosystem of tokenized digital assets including AKOFA tokens and more',
          Icons.stars,
          const Color(0xFF4CAF50),
        ),
        const SizedBox(height: 24),
        _buildFeatureCard(
          'Seamless Payments',
          'Gasless transactions powered by Biconomy—send tokens without paying gas fees',
          Icons.payment,
          const Color(0xFFFF9800),
        ),
        const SizedBox(height: 24),
        _buildFeatureCard(
          'Global Marketplace',
          'Buy and sell goods and services worldwide using crypto with secure escrow protection',
          Icons.storefront,
          const Color(0xFF9C27B0),
        ),
        const SizedBox(height: 24),
        _buildFeatureCard(
          'Multi-Chain Wallet',
          'Secure wallet supporting Stellar and Polygon with encrypted key management',
          Icons.account_balance_wallet,
          const Color(0xFFE91E63),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(String title, String description, IconData icon, Color color) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    
    return Container(
      width: isDesktop ? 350 : (isTablet ? 300 : double.infinity),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.white.withOpacity(0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildHowItWorksSection(bool isDesktop, bool isTablet, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.0 : (isTablet ? 48.0 : 80.0),
        vertical: isMobile ? 60.0 : 100.0,
      ),
      color: AppTheme.black,
      child: Column(
        children: [
          Text(
            'How It Works',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 32 : (isTablet ? 40 : 48),
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryGold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Get started in minutes',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 16 : (isTablet ? 18 : 20),
              color: AppTheme.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 60),
          
          // Steps
          if (isDesktop || isTablet)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: _buildStep(
                    '1',
                    'Create Account',
                    'Sign up with email or Google. Quick and secure.',
                    Icons.person_add,
                  ),
                ),
                if (isDesktop) const SizedBox(width: 32),
                if (isTablet) const SizedBox(width: 24),
                Expanded(
                  child: _buildStep(
                    '2',
                    'Setup Wallet',
                    'Create or import your crypto wallet in seconds.',
                    Icons.wallet,
                  ),
                ),
                if (isDesktop) const SizedBox(width: 32),
                if (isTablet) const SizedBox(width: 24),
                Expanded(
                  child: _buildStep(
                    '3',
                    'Start Earning',
                    'Mine tokens, trade, and participate in the ecosystem.',
                    Icons.rocket_launch,
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildStep(
                  '1',
                  'Create Account',
                  'Sign up with email or Google. Quick and secure.',
                  Icons.person_add,
                ),
                const SizedBox(height: 32),
                _buildStep(
                  '2',
                  'Setup Wallet',
                  'Create or import your crypto wallet in seconds.',
                  Icons.wallet,
                ),
                const SizedBox(height: 32),
                _buildStep(
                  '3',
                  'Start Earning',
                  'Mine tokens, trade, and participate in the ecosystem.',
                  Icons.rocket_launch,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String title, String description, IconData icon) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryGold, Color(0xFFFFE57F)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGold.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(icon, color: AppTheme.black, size: 36),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF212121),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryGold, width: 2),
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.white.withOpacity(0.7),
            height: 1.5,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms).scale();
  }

  Widget _buildEcosystemSection(bool isDesktop, bool isTablet, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.0 : (isTablet ? 48.0 : 80.0),
        vertical: isMobile ? 60.0 : 100.0,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1a1a1a),
            AppTheme.black,
          ],
        ),
      ),
      child: Column(
        children: [
          Text(
            'The AZIX Ecosystem',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 32 : (isTablet ? 40 : 48),
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryGold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 800 : (isTablet ? 650 : double.infinity),
            ),
            child: Text(
              'The premier hub for seamless, super-fast transactions and cross-border trade. AZIX is your home for tokenized assets and the future of global digital commerce.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isMobile ? 16 : (isTablet ? 18 : 20),
                color: AppTheme.white.withOpacity(0.8),
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 60),
          
          // Ecosystem features
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              _buildEcosystemItem(
                'Instant Settlement',
                'Super-fast transaction finality in seconds',
                Icons.timer,
              ),
              _buildEcosystemItem(
                'Global Reach',
                'Trade across borders with anyone, anywhere',
                Icons.public,
              ),
              _buildEcosystemItem(
                'Tokenized Economy',
                'Complete ecosystem of digital tokenized assets',
                Icons.token,
              ),
              _buildEcosystemItem(
                'Zero Gas Fees',
                'Seamless transactions without gas costs',
                Icons.money_off,
              ),
              _buildEcosystemItem(
                'Vendor Network',
                'Join our global marketplace of vendors',
                Icons.store,
              ),
              _buildEcosystemItem(
                'Secure & Fast',
                'Military-grade security with lightning speed',
                Icons.shield_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEcosystemItem(String title, String description, IconData icon) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    
    return Container(
      width: isDesktop ? 320 : (isTablet ? 280 : double.infinity),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF212121).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryGold.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryGold, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1, end: 0);
  }

  Widget _buildCTASection(bool isDesktop, bool isTablet, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.0 : (isTablet ? 48.0 : 80.0),
        vertical: isMobile ? 80.0 : 120.0,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryGold.withOpacity(0.1),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Ready to Get Started?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 32 : (isTablet ? 40 : 48),
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryGold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 700 : (isTablet ? 600 : double.infinity),
            ),
            child: Text(
              'Join the future of seamless, super-fast transactions. Experience cross-border trade and manage your tokenized assets—all in one powerful hub.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isMobile ? 16 : (isTablet ? 18 : 20),
                color: AppTheme.white.withOpacity(0.8),
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: isMobile ? double.infinity : 250,
            child: CustomButton(
              text: 'Create Your Account',
              onPressed: _navigateToAuth,
            ).animate().fadeIn(duration: 600.ms).scale(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDesktop, bool isTablet, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.0 : (isTablet ? 48.0 : 80.0),
        vertical: 40.0,
      ),
      color: AppTheme.black,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppLogo(width: 40, height: 40),
              const SizedBox(width: 12),
              const Text(
                'AZIX',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '© 2024 AZIX. All rights reserved.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The Hub for Seamless, Super-Fast Transactions & Cross-Border Trade',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your Home for Tokenized Assets',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.white.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}














