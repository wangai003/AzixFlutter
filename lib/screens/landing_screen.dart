import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/custom_button.dart';
import '../utils/responsive_layout.dart';
import '../providers/auth_provider.dart' as local_auth;
import 'main_navigation.dart';
import 'auth/modern_auth_screen.dart';
import 'auth/email_verification_screen.dart';
import 'user_registration_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({Key? key}) : super(key: key);

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;
  final GlobalKey _howItWorksKey = GlobalKey();
  final GlobalKey _finalCtaKey = GlobalKey();

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

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
      alignment: 0.05,
    );
  }

  Future<void> _navigateToApp() async {
    if (!mounted) return;

    // Check authentication state and navigate accordingly
    final authProvider = Provider.of<local_auth.AuthProvider>(context, listen: false);
    
    // Wait for auth state to be initialized
    if (authProvider.authState == local_auth.AuthState.initial) {
      // Wait a bit for auth to initialize
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (!mounted) return;

    // If user is not authenticated, navigate to auth screen
    if (!authProvider.isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ModernAuthScreen()),
      );
      return;
    }

    // User is authenticated - check if they need email verification
    final needsEmailVerification = await authProvider.needsEmailVerification();
    if (!mounted) return;

    if (needsEmailVerification) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const EmailVerificationScreen()),
      );
      return;
    }

    // Check if profile completion is needed
    final needsProfileCompletion = await authProvider.needsProfileCompletion();
    if (!mounted) return;

    if (needsProfileCompletion) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const UserRegistrationScreen()),
      );
      return;
    }

    // User is fully authenticated and profile is complete - navigate to main app
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainNavigation()),
    );
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

                // Why Azix Exists
                _buildWhyAzixSection(isDesktop, isTablet, isMobile),

                // What You Can Do
                _buildWhatYouCanDoSection(isDesktop, isTablet, isMobile),

                // How Azix Works
                _buildHowItWorksSection(isDesktop, isTablet, isMobile),

                // Security & Transparency
                _buildSecuritySection(isDesktop, isTablet, isMobile),

                // Who Azix Is For
                _buildWhoAzixIsForSection(isDesktop, isTablet, isMobile),

                // Phased Ecosystem
                _buildPhasedEcosystemSection(isDesktop, isTablet, isMobile),

                // Who's Behind Azix
                _buildWhoBehindAzixSection(isDesktop, isTablet, isMobile),

                // Principles
                _buildPrinciplesSection(isDesktop, isTablet, isMobile),

                // Final CTA
                _buildFinalCTASection(isDesktop, isTablet, isMobile),
                
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
      height: isMobile ? 700 : (isTablet ? 760 : 780),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo and tagline
                  AppLogo(
                    width: isMobile ? 100 : (isTablet ? 130 : 160),
                    height: isMobile ? 100 : (isTablet ? 130 : 160),
                  ).animate().fadeIn(duration: 800.ms).scale(),
                  
                  const SizedBox(height: 40),
                  
                  // Main heading
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 1000 : (isTablet ? 900 : double.infinity),
                    ),
                    child: Text(
                      'Azix - The Digital Infrastructure for African Commerce & Global Trade',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isMobile ? 34 : (isTablet ? 46 : 56),
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryGold,
                        height: 1.15,
                        letterSpacing: -1,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 1000.ms, delay: 200.ms)
                      .slideY(begin: 0.3, end: 0),
                  
                  const SizedBox(height: 24),
                  
                  // Subtitle
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 720 : (isTablet ? 640 : double.infinity),
                    ),
                    child: Text(
                      'Trade. Pay. Invest. Settle.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isMobile ? 22 : (isTablet ? 26 : 30),
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
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 900 : (isTablet ? 700 : double.infinity),
                    ),
                    child: Text(
                      'All in one secure platform designed for Africa and the global diaspora.',
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

                  const SizedBox(height: 16),

                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 960 : (isTablet ? 740 : double.infinity),
                    ),
                    child: Text(
                      'Azix connects African businesses, creators, exporters, and investors to global markets, payments, and opportunities - without relying on fragmented banks, middlemen, or expensive intermediaries.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isMobile ? 15 : (isTablet ? 17 : 19),
                        color: AppTheme.white.withOpacity(0.75),
                        height: 1.6,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 1000.ms, delay: 700.ms)
                        .slideY(begin: 0.3, end: 0),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // CTA Buttons
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      SizedBox(
                        width: isMobile ? double.infinity : 200,
                        child: CustomButton(
                          text: 'Explore Azix',
                          onPressed: _navigateToApp,
                        )
                            .animate()
                            .fadeIn(duration: 1000.ms, delay: 800.ms)
                            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
                      ),
                      SizedBox(
                        width: isMobile ? double.infinity : 200,
                        child: CustomButton(
                          text: 'Learn How It Works',
                          isOutlined: true,
                          onPressed: () {
                            _scrollToSection(_howItWorksKey);
                          },
                        )
                            .animate()
                            .fadeIn(duration: 1000.ms, delay: 1000.ms)
                            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhyAzixSection(bool isDesktop, bool isTablet, bool isMobile) {
    return _buildTextSection(
      backgroundColor: const Color(0xFF1a1a1a),
      isDesktop: isDesktop,
      isTablet: isTablet,
      isMobile: isMobile,
      title: 'Why we built Azix',
      subtitle: 'Across Africa and emerging markets:',
      paragraphs: [
        'Azix was created to solve these problems at the infrastructure level, not with temporary fixes.',
        'We are building a neutral digital marketplace and financial layer where:',
      ],
      bullets: [
        'Businesses struggle to receive international payments',
        'Traders rely on costly middlemen',
        'Investors face limited access to global markets',
        'Young people lack credible digital economic pathways',
        'Value moves efficiently',
        'Trade is transparent',
        'Payments are programmable',
        'Opportunity is accessible',
      ],
    );
  }

  Widget _buildWhatYouCanDoSection(bool isDesktop, bool isTablet, bool isMobile) {
    return _buildTextSection(
      backgroundColor: AppTheme.black,
      isDesktop: isDesktop,
      isTablet: isTablet,
      isMobile: isMobile,
      title: 'What you can do on Azix',
      subtitle: 'One platform. Multiple economic functions.',
      paragraphs: [
        'With Azix, you can:',
      ],
      bullets: [
        'Buy & sell goods or services across borders',
        'Send & receive digital payments securely',
        'Access tokenized markets & financial tools (coming phases)',
        'Participate in live marketplaces & bidding hubs',
        'Connect directly with verified buyers & sellers',
        'Prepare for global trade without traditional barriers',
        'No switching between apps. No fragmented systems.',
      ],
      bulletIcon: Icons.check_circle,
    );
  }

  Widget _buildHowItWorksSection(bool isDesktop, bool isTablet, bool isMobile) {
    return ResponsiveContainer(
      key: _howItWorksKey,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.0 : (isTablet ? 48.0 : 80.0),
        vertical: isMobile ? 60.0 : 100.0,
      ),
      color: const Color(0xFF1a1a1a),
      child: Column(
        children: [
          Text(
            'How Azix Works',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 32 : (isTablet ? 40 : 48),
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryGold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Simple & transparent',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 16 : (isTablet ? 18 : 20),
              color: AppTheme.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 60),
          
          // Steps
          if (isDesktop || isTablet)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 1100 : 900,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: _buildStep(
                      '1',
                      'Create an Account',
                      'Sign up with email or wallet-based access. No unnecessary data harvesting.',
                      Icons.person_add,
                    ),
                  ),
                  if (isDesktop) const SizedBox(width: 32),
                  if (isTablet) const SizedBox(width: 24),
                  Expanded(
                    child: _buildStep(
                      '2',
                      'Access the Ecosystem',
                      'Explore marketplaces, wallets, trade tools, and opportunities.',
                      Icons.public,
                    ),
                  ),
                  if (isDesktop) const SizedBox(width: 32),
                  if (isTablet) const SizedBox(width: 24),
                  Expanded(
                    child: _buildStep(
                      '3',
                      'Transact & Grow',
                      'Trade, earn, settle payments, and build digital economic history. Azix grows with you.',
                      Icons.trending_up,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                _buildStep(
                  '1',
                  'Create an Account',
                  'Sign up with email or wallet-based access. No unnecessary data harvesting.',
                  Icons.person_add,
                ),
                const SizedBox(height: 32),
                _buildStep(
                  '2',
                  'Access the Ecosystem',
                  'Explore marketplaces, wallets, trade tools, and opportunities.',
                  Icons.public,
                ),
                const SizedBox(height: 32),
                _buildStep(
                  '3',
                  'Transact & Grow',
                  'Trade, earn, settle payments, and build digital economic history. Azix grows with you.',
                  Icons.trending_up,
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

  Widget _buildSecuritySection(bool isDesktop, bool isTablet, bool isMobile) {
    return _buildTextSection(
      backgroundColor: AppTheme.black,
      isDesktop: isDesktop,
      isTablet: isTablet,
      isMobile: isMobile,
      title: 'Security & Transparency',
      subtitle: 'Built with modern financial standards',
      paragraphs: [
        'Users control value. Azix provides infrastructure - not custodial exploitation.',
      ],
      bullets: [
        'Self-custody compatible architecture',
        'Blockchain-backed transaction records',
        'Transparent settlement layers',
        'No hidden rehypothecation of user assets',
      ],
      bulletIcon: Icons.lock,
    );
  }

  Widget _buildWhoAzixIsForSection(bool isDesktop, bool isTablet, bool isMobile) {
    return _buildTextSection(
      backgroundColor: const Color(0xFF1a1a1a),
      isDesktop: isDesktop,
      isTablet: isTablet,
      isMobile: isMobile,
      title: 'Who Azix is for',
      subtitle: 'Designed for real economic participants',
      paragraphs: [
        'If you participate in the real economy, Azix is built for you.',
      ],
      bullets: [
        'African SMEs & exporters',
        'Global buyers seeking verified African suppliers',
        'Creators, developers & service providers',
        'Diaspora investors & traders',
        'Students & young professionals building digital income',
      ],
      bulletIcon: Icons.group,
    );
  }

  Widget _buildPhasedEcosystemSection(bool isDesktop, bool isTablet, bool isMobile) {
    return ResponsiveContainer(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.0 : (isTablet ? 48.0 : 80.0),
        vertical: isMobile ? 60.0 : 100.0,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.black,
            const Color(0xFF1a1a1a),
          ],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Phased Ecosystem',
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
              'Azix is not a single product - it is an evolving system.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isMobile ? 16 : (isTablet ? 18 : 20),
                color: AppTheme.white.withOpacity(0.8),
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              _buildPhaseCard(
                title: 'Phase 1 (Live / Rolling Out)',
                items: [
                  'Wallet & payments',
                  'Marketplace & trade listings',
                  'Live bidding hubs',
                  'Escrow-style transaction flows',
                ],
              ),
              _buildPhaseCard(
                title: 'Phase 2 (Expansion)',
                items: [
                  'Tokenized assets & trade finance',
                  'Cross-border settlement rails',
                  'Advanced merchant tools',
                ],
              ),
              _buildPhaseCard(
                title: 'Phase 3 (Long-Term Vision)',
                items: [
                  'African capital markets access',
                  'Global liquidity bridges',
                  'Digital economic identity layers',
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWhoBehindAzixSection(bool isDesktop, bool isTablet, bool isMobile) {
    return ResponsiveContainer(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.0 : (isTablet ? 48.0 : 80.0),
        vertical: isMobile ? 60.0 : 100.0,
      ),
      color: const Color(0xFF1a1a1a),
      child: Column(
        children: [
          Text(
            "Who's behind Azix",
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
              maxWidth: isDesktop ? 900 : (isTablet ? 700 : double.infinity),
            ),
            child: Column(
              children: [
                Text(
                  'Azix is developed by Daada Inc., a cross-border technology company focused on:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isMobile ? 16 : (isTablet ? 18 : 20),
                    color: AppTheme.white.withOpacity(0.8),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                _buildBulletList(
                  items: const [
                    'Digital commerce',
                    'Financial infrastructure',
                    'Trade enablement',
                  ],
                  icon: Icons.business,
                ),
                const SizedBox(height: 24),
                Text(
                  'Founded by operators with experience in:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isMobile ? 16 : (isTablet ? 18 : 20),
                    color: AppTheme.white.withOpacity(0.8),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                _buildBulletList(
                  items: const [
                    'Education',
                    'Blockchain systems',
                    'Trade & sourcing',
                    'African market development',
                  ],
                  icon: Icons.school,
                ),
                const SizedBox(height: 24),
                Text(
                  'This is infrastructure, not a quick crypto experiment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isMobile ? 15 : (isTablet ? 17 : 19),
                    color: AppTheme.white.withOpacity(0.8),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrinciplesSection(bool isDesktop, bool isTablet, bool isMobile) {
    return _buildTextSection(
      backgroundColor: AppTheme.black,
      isDesktop: isDesktop,
      isTablet: isTablet,
      isMobile: isMobile,
      title: 'Our principles',
      subtitle: 'Azix is being built to last decades, not cycles.',
      bullets: [
        'Access over exclusion',
        'Infrastructure over hype',
        'Transparency over opacity',
        'Long-term value over speculation',
      ],
      bulletIcon: Icons.check_circle_outline,
    );
  }

  Widget _buildFinalCTASection(bool isDesktop, bool isTablet, bool isMobile) {
    return ResponsiveContainer(
      key: _finalCtaKey,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.0 : (isTablet ? 48.0 : 80.0),
        vertical: isMobile ? 80.0 : 120.0,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryGold.withOpacity(0.12),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Explore before you commit',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 30 : (isTablet ? 38 : 46),
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryGold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 800 : (isTablet ? 650 : double.infinity),
            ),
            child: Column(
              children: [
                Text(
                  'You do not need to deposit funds to explore Azix. You do not need to trade immediately.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isMobile ? 16 : (isTablet ? 18 : 20),
                    color: AppTheme.white.withOpacity(0.85),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Create a free account and explore the platform. See how trade, payments, and opportunity come together.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isMobile ? 16 : (isTablet ? 18 : 20),
                    color: AppTheme.white.withOpacity(0.8),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: isMobile ? double.infinity : 240,
            child: CustomButton(
              text: 'Explore Azix',
              onPressed: _navigateToApp,
            ).animate().fadeIn(duration: 600.ms).scale(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextSection({
    required String title,
    String? subtitle,
    List<String> paragraphs = const [],
    List<String> bullets = const [],
    IconData bulletIcon = Icons.circle,
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
    Color backgroundColor = AppTheme.black,
  }) {
    final double maxWidth =
        isDesktop ? 900 : (isTablet ? 720 : double.infinity);
    return ResponsiveContainer(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.0 : (isTablet ? 48.0 : 80.0),
        vertical: isMobile ? 60.0 : 100.0,
      ),
      color: backgroundColor,
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 30 : (isTablet ? 38 : 46),
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryGold,
            ),
          ),
          Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              children: [
                if (subtitle != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isMobile ? 16 : (isTablet ? 18 : 20),
                      color: AppTheme.white.withOpacity(0.85),
                    ),
                  ),
                ],
                if (paragraphs.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  ...paragraphs.map(
                    (paragraph) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        paragraph,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isMobile ? 15 : (isTablet ? 17 : 19),
                          color: AppTheme.white.withOpacity(0.75),
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ],
                if (bullets.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildBulletList(items: bullets, icon: bulletIcon),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletList({
    required List<String> items,
    required IconData icon,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 900;
        if (!isWide || items.length < 4) {
          return _buildBulletColumn(items, icon);
        }

        final int midPoint = (items.length / 2).ceil();
        final List<String> leftItems = items.sublist(0, midPoint);
        final List<String> rightItems = items.sublist(midPoint);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildBulletColumn(leftItems, icon)),
            const SizedBox(width: 32),
            Expanded(child: _buildBulletColumn(rightItems, icon)),
          ],
        );
      },
    );
  }

  Widget _buildBulletColumn(List<String> items, IconData icon) {
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: AppTheme.primaryGold),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppTheme.white.withOpacity(0.85),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildPhaseCard({
    required String title,
    required List<String> items,
  }) {
    return Container(
      width: ResponsiveLayout.isDesktop(context) ? 360 : double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryGold.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryGold,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.circle, size: 8, color: AppTheme.primaryGold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.white.withOpacity(0.8),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDesktop, bool isTablet, bool isMobile) {
    return ResponsiveContainer(
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
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              Text(
                'Terms & Privacy',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.white.withOpacity(0.7),
                ),
              ),
              Text(
                'Roadmap',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.white.withOpacity(0.7),
                ),
              ),
              Text(
                'Contact: support@azix.world',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Azix does not provide financial advice. Platform features vary by region.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.white.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '© 2024 AZIX. All rights reserved.',
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

















