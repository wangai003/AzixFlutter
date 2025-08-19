import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart' as local_auth;
import '../providers/secure_stellar_provider.dart';
import '../theme/ultra_modern_theme.dart';
import '../widgets/ultra_modern_widgets.dart';
import '../models/secure_mining_session.dart';

/// Ultra-modern mining interface inspired by world-class fintech apps
/// Following design principles from Revolut, Coinbase, Robinhood, and Apple
class UltraModernMiningScreen extends StatefulWidget {
  const UltraModernMiningScreen({Key? key}) : super(key: key);

  @override
  State<UltraModernMiningScreen> createState() => _UltraModernMiningScreenState();
}

class _UltraModernMiningScreenState extends State<UltraModernMiningScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _glowController;
  Timer? _uiUpdateTimer;
  bool _showAdvancedMetrics = false;
  String _selectedTimeframe = '24H';

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    // Start animations
    _pulseController.repeat(reverse: true);
    _rotationController.repeat();
    _glowController.repeat(reverse: true);
    
    // Start UI updates
    _startUIUpdates();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _glowController.dispose();
    _uiUpdateTimer?.cancel();
    super.dispose();
  }

  void _startUIUpdates() {
    _uiUpdateTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SecureStellarProvider, local_auth.AuthProvider>(
      builder: (context, stellarProvider, authProvider, _) {
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: UltraModernTheme.backgroundGradient,
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= UltraModernTheme.desktopBreakpoint;
                  
                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // App Bar
                      _buildModernAppBar(stellarProvider, isDesktop),
                      
                      // Main Content
                      SliverPadding(
                        padding: UltraModernTheme.responsivePadding(context),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // Hero Mining Section
                            _buildHeroMiningSection(stellarProvider, isDesktop),
                            
                            const SizedBox(height: UltraModernTheme.spacingXl),
                            
                            // Stats Grid
                            _buildStatsGrid(stellarProvider, isDesktop),
                            
                            const SizedBox(height: UltraModernTheme.spacingXl),
                            
                            // Mining Controls
                            _buildMiningControls(stellarProvider, isDesktop),
                            
                            const SizedBox(height: UltraModernTheme.spacingXl),
                            
                            // Advanced Metrics (Collapsible)
                            _buildAdvancedMetrics(stellarProvider),
                            
                            const SizedBox(height: UltraModernTheme.spacingXl),
                            
                            // Recent Activity
                            _buildRecentActivity(stellarProvider),
                            
                            const SizedBox(height: UltraModernTheme.spacing2xl),
                          ]),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernAppBar(SecureStellarProvider provider, bool isDesktop) {
    return SliverAppBar(
      expandedHeight: isDesktop ? 120 : 100,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(
          left: isDesktop ? UltraModernTheme.spacing2xl : UltraModernTheme.spacingLg,
          bottom: UltraModernTheme.spacingMd,
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: UltraModernTheme.neonCard(),
              child: Icon(
                Icons.diamond,
                color: UltraModernTheme.primaryGold,
                size: isDesktop ? 28 : 24,
              ),
                          ),
            const SizedBox(width: UltraModernTheme.spacingMd),
            Text(
              'AZIX Mining',
              style: UltraModernTheme.title1.copyWith(
                fontSize: UltraModernTheme.responsiveFontSize(context, 28),
                fontWeight: FontWeight.w700,
                foreground: Paint()
                  ..shader = UltraModernTheme.primaryGradient.createShader(
                    const Rect.fromLTWH(0, 0, 200, 50),
                  ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Security Status
        _buildSecurityIndicator(provider),
        const SizedBox(width: UltraModernTheme.spacingSm),
        
        // Wallet Balance
        _buildWalletIndicator(provider),
        const SizedBox(width: UltraModernTheme.spacingLg),
      ],
    );
  }

  Widget _buildSecurityIndicator(SecureStellarProvider provider) {
    final isSecure = provider.currentMiningSession?.isValid ?? true;
    
    return UltraModernWidgets.glassContainer(
      padding: const EdgeInsets.symmetric(
        horizontal: UltraModernTheme.spacingMd,
        vertical: UltraModernTheme.spacingSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isSecure ? UltraModernTheme.successGreen : UltraModernTheme.errorRed,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isSecure ? UltraModernTheme.successGreen : UltraModernTheme.errorRed,
                  blurRadius: 4,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
          ),
          const SizedBox(width: UltraModernTheme.spacingXs),
          Text(
            isSecure ? 'Secure' : 'Alert',
            style: UltraModernTheme.caption1.copyWith(
              color: isSecure ? UltraModernTheme.successGreen : UltraModernTheme.errorRed,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletIndicator(SecureStellarProvider provider) {
    return GestureDetector(
      onTap: () => _showWalletDetails(provider),
      child: UltraModernWidgets.glassContainer(
        padding: const EdgeInsets.symmetric(
          horizontal: UltraModernTheme.spacingMd,
          vertical: UltraModernTheme.spacingSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet,
              color: UltraModernTheme.primaryGold,
              size: 16,
            ),
            const SizedBox(width: UltraModernTheme.spacingXs),
            Text(
              '${double.tryParse(provider.balance)?.toStringAsFixed(2) ?? '0.00'} ₳',
              style: UltraModernTheme.monoBody.copyWith(
                color: UltraModernTheme.primaryGold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroMiningSection(SecureStellarProvider provider, bool isDesktop) {
    final session = provider.currentMiningSession;
    final isActive = session?.isActive ?? false;
    final isPaused = session?.isPaused ?? false;
    final earned = session?.earnedAkofa ?? 0.0;
    
    return UltraModernWidgets.neonCard(
      glowColor: isActive ? UltraModernTheme.primaryGold : UltraModernTheme.steel,
      animated: isActive,
      child: Column(
        children: [
          // Status Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mining Status',
                    style: UltraModernTheme.caption1.copyWith(
                      color: UltraModernTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: UltraModernTheme.spacing2xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: UltraModernTheme.spacingMd,
                      vertical: UltraModernTheme.spacingXs,
                    ),
                    decoration: BoxDecoration(
                      color: (isActive ? UltraModernTheme.successGreen : UltraModernTheme.steel).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(UltraModernTheme.radiusSm),
                      border: Border.all(
                        color: isActive ? UltraModernTheme.successGreen : UltraModernTheme.steel,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isActive ? 'ACTIVE' : isPaused ? 'PAUSED' : 'INACTIVE',
                      style: UltraModernTheme.caption1.copyWith(
                        color: isActive ? UltraModernTheme.successGreen : UltraModernTheme.steel,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              _buildMiningVisualization(isActive, earned),
            ],
          ),
          
          const SizedBox(height: UltraModernTheme.spacingXl),
          
          // Earnings Display
          Column(
            children: [
              Text(
                'Current Earnings',
                style: UltraModernTheme.footnote.copyWith(
                  color: UltraModernTheme.textSecondary,
                ),
              ),
              const SizedBox(height: UltraModernTheme.spacingSm),
              // Real-time earnings display using provider updates
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  UltraModernWidgets.animatedCounter(
                    value: session?.earnedAkofa ?? 0.0,
                    suffix: '₳',
                    textStyle: UltraModernTheme.largeTitle.copyWith(
                      fontSize: UltraModernTheme.responsiveFontSize(context, 42),
                      fontWeight: FontWeight.w800,
                      foreground: Paint()
                        ..shader = UltraModernTheme.primaryGradient.createShader(
                          const Rect.fromLTWH(0, 0, 300, 50),
                        ),
                    ),
                    decimalPlaces: 6,
                  ),
                  if (isActive && !isPaused) ...[
                    const SizedBox(width: UltraModernTheme.spacingSm),
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: UltraModernTheme.successGreen.withOpacity(0.7 + _pulseController.value * 0.3),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: UltraModernTheme.successGreen.withOpacity(0.5),
                                blurRadius: 4 + _pulseController.value * 4,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: UltraModernTheme.spacingSm),
              if (session != null) _buildEarningsRate(session),
            ],
          ),
          
          const SizedBox(height: UltraModernTheme.spacingXl),
          
          // Progress Section
          if (session != null) _buildProgressSection(session),
        ],
      ),
    );
  }

  Widget _buildMiningVisualization(bool isActive, double earned) {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Container(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring
              Transform.rotate(
                angle: _rotationController.value * 2 * math.pi,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: UltraModernTheme.primaryGold.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: CustomPaint(
                    painter: OrbitPainter(
                      animation: _rotationController,
                      isActive: isActive,
                    ),
                  ),
                ),
              ),
              
              // Inner core
              AnimatedBuilder(
                animation: _glowController,
                builder: (context, child) {
                  return Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isActive ? UltraModernTheme.primaryGradient : null,
                      color: isActive ? null : UltraModernTheme.steel,
                      boxShadow: isActive ? [
                        BoxShadow(
                          color: UltraModernTheme.primaryGold.withOpacity(0.4 + _glowController.value * 0.3),
                          blurRadius: 15 + _glowController.value * 10,
                          offset: const Offset(0, 0),
                        ),
                      ] : null,
                    ),
                    child: Icon(
                      Icons.bolt,
                      color: isActive ? UltraModernTheme.textInverse : UltraModernTheme.textTertiary,
                      size: 20,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEarningsRate(SecureMiningSession session) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: UltraModernTheme.spacingMd,
        vertical: UltraModernTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: UltraModernTheme.glassBlack,
        borderRadius: BorderRadius.circular(UltraModernTheme.radiusSm),
        border: Border.all(
          color: UltraModernTheme.primaryGold.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        '${session.miningRate} ₳/hour',
        style: UltraModernTheme.monoBody.copyWith(
          color: UltraModernTheme.primaryGold,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildProgressSection(SecureMiningSession session) {
    final totalDuration = session.sessionEnd.difference(session.sessionStart).inSeconds;
    final progress = session.accumulatedSeconds / totalDuration;
    final remainingTime = session.sessionEnd.difference(DateTime.now());
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Session Progress',
              style: UltraModernTheme.callout.copyWith(
                color: UltraModernTheme.textSecondary,
              ),
            ),
            Text(
              '${(progress * 100).toStringAsFixed(1)}%',
              style: UltraModernTheme.callout.copyWith(
                color: UltraModernTheme.primaryGold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: UltraModernTheme.spacingMd),
        
        // Progress Bar
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: UltraModernTheme.steel.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: UltraModernTheme.primaryGradient,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: UltraModernTheme.primaryGold.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
            ),
          ),
                    ),
        
        const SizedBox(height: UltraModernTheme.spacingMd),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Time Remaining',
              style: UltraModernTheme.footnote,
            ),
            Text(
              _formatDuration(remainingTime),
              style: UltraModernTheme.footnote.copyWith(
                color: UltraModernTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGrid(SecureStellarProvider provider, bool isDesktop) {
    final session = provider.currentMiningSession;
    final metrics = provider.securityMetrics;
    final balance = double.tryParse(provider.balance) ?? 0.0;
    
    final stats = [
      {
        'title': 'Total Earned',
        'value': '${(metrics['totalEarned'] ?? 0.0).toStringAsFixed(3)} ₳',
        'subtitle': 'Lifetime rewards',
        'icon': Icons.diamond,
        'color': UltraModernTheme.primaryGold,
        'trend': _calculateEarningsTrend(metrics),
        'progress': _calculateEarningsProgress(balance, metrics),
      },
      {
        'title': 'Active Sessions',
        'value': '${metrics['totalSessions'] ?? 0}',
        'subtitle': 'Mining cycles',
        'icon': Icons.rocket_launch,
        'color': UltraModernTheme.neonGreen,
        'trend': _calculateSessionsTrend(metrics),
        'progress': _calculateSessionsProgress(metrics),
      },
      {
        'title': 'Security Score',
        'value': '${((metrics['integrityScore'] ?? 1.0) * 100).toStringAsFixed(0)}%',
        'subtitle': 'Trust rating',
        'icon': Icons.verified_user,
        'color': UltraModernTheme.successGreen,
        'trend': _calculateSecurityTrend(metrics),
        'progress': (metrics['integrityScore'] ?? 1.0),
      },
      {
        'title': 'Network Power',
        'value': '${session?.totalProofsSubmitted ?? 0}',
        'subtitle': 'Proofs validated',
        'icon': Icons.bolt,
        'color': UltraModernTheme.electricBlue,
        'trend': _calculateNetworkTrend(session),
        'progress': _calculateNetworkProgress(session),
      },
      {
        'title': 'Mining Rate',
        'value': '${session?.miningRate ?? 0.25}/hr',
        'subtitle': 'Current rate',
        'icon': Icons.speed,
        'color': UltraModernTheme.warningAmber,
        'trend': _calculateMiningRateTrend(session),
        'progress': _calculateMiningRateProgress(session),
      },
      {
        'title': 'Efficiency',
        'value': '${_calculateEfficiency(session)}%',
        'subtitle': 'Performance',
        'icon': Icons.trending_up,
        'color': UltraModernTheme.cyberpunkPurple,
        'trend': _calculateEfficiencyTrend(session),
        'progress': _calculateEfficiency(session) / 100,
      },
      {
        'title': 'Current Balance',
        'value': '${balance.toStringAsFixed(3)} ₳',
        'subtitle': 'Wallet balance',
        'icon': Icons.account_balance_wallet,
        'color': UltraModernTheme.electricBlue,
        'trend': _calculateBalanceTrend(balance, metrics),
        'progress': _calculateBalanceProgress(balance, metrics),
      },
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: UltraModernTheme.primaryGradient,
                borderRadius: BorderRadius.circular(UltraModernTheme.radiusSm),
              ),
              child: const Icon(
                Icons.analytics,
                color: UltraModernTheme.textInverse,
                size: 20,
              ),
            ),
            const SizedBox(width: UltraModernTheme.spacingMd),
            Text(
              'Performance Analytics',
              style: UltraModernTheme.title2.copyWith(
                color: UltraModernTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: UltraModernTheme.spacingMd,
                vertical: UltraModernTheme.spacingXs,
              ),
              decoration: BoxDecoration(
                color: UltraModernTheme.successGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(UltraModernTheme.radiusSm),
                border: Border.all(
                  color: UltraModernTheme.successGreen,
                  width: 1,
                ),
              ),
              child: Text(
                session?.isActive == true ? 'LIVE' : 'OFFLINE',
                style: UltraModernTheme.caption1.copyWith(
                  color: session?.isActive == true ? UltraModernTheme.successGreen : UltraModernTheme.errorRed,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: UltraModernTheme.spacingLg),
        
        // Enhanced Stats Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isDesktop ? 3 : 2,
            crossAxisSpacing: UltraModernTheme.spacingMd,
            mainAxisSpacing: UltraModernTheme.spacingMd,
            childAspectRatio: isDesktop ? 1.6 : 1.5,
          ),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final stat = stats[index];
            return _buildEnhancedDataCard(
              title: stat['title'] as String,
              value: stat['value'] as String,
              subtitle: stat['subtitle'] as String,
              icon: stat['icon'] as IconData,
              color: stat['color'] as Color,
              trend: stat['trend'] as String,
              progress: stat['progress'] as double,
              index: index,
            );
          },
        ),
      ],
    );
  }

  Widget _buildEnhancedDataCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String trend,
    required double progress,
    required int index,
  }) {
    return UltraModernWidgets.glassContainer(
      padding: const EdgeInsets.all(UltraModernTheme.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with icon and trend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(UltraModernTheme.radiusSm),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UltraModernTheme.spacingXs,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    trend,
                    style: UltraModernTheme.caption2.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 9,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 4),
          
          // Title
          Text(
            title,
            style: UltraModernTheme.caption1.copyWith(
              color: UltraModernTheme.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 2),
          
          // Value
          Text(
            value,
            style: UltraModernTheme.callout.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 1),
          
          // Subtitle
          Text(
            subtitle,
            style: UltraModernTheme.footnote.copyWith(
              color: UltraModernTheme.textTertiary,
              fontSize: 9,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 6),
          
          // Progress bar
          Container(
            height: 2,
            width: double.infinity,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(1),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 2,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateEfficiency(SecureMiningSession? session) {
    if (session == null) return 0.0;
    
    // Calculate efficiency based on uptime vs session duration
    final totalDuration = session.sessionEnd.difference(session.sessionStart).inSeconds;
    final efficiency = (session.accumulatedSeconds / totalDuration) * 100;
    return efficiency.clamp(0.0, 100.0);
  }

  Widget _buildMiningControls(SecureStellarProvider provider, bool isDesktop) {
    final session = provider.currentMiningSession;
    final canStart = session == null || !session.isActive;
    final canPause = session?.isActive == true && session?.isPaused == false;
    final canResume = session?.isPaused == true;
    
    return UltraModernWidgets.glassContainer(
      child: Column(
        children: [
          // Main Control Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: provider.isLoading ? null : () async {
                if (canStart) {
                  await _startMining(provider);
                } else {
                  await _showEndMiningDialog(provider);
                }
              },
              style: UltraModernTheme.primaryButton.copyWith(
                backgroundColor: WidgetStateProperty.all(
                  canStart ? UltraModernTheme.primaryGold : UltraModernTheme.errorRed,
                ),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UltraModernTheme.radiusMd),
                  ),
                ),
              ),
              child: provider.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: UltraModernTheme.textInverse,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          canStart ? Icons.play_arrow : Icons.stop,
                          size: 24,
                        ),
                        const SizedBox(width: UltraModernTheme.spacingSm),
                        Text(
                          canStart ? 'Start Mining' : 'End Session',
                          style: UltraModernTheme.headline.copyWith(
                            color: UltraModernTheme.textInverse,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          
          // Secondary Controls
          if (session != null && session.isActive) ...[
            const SizedBox(height: UltraModernTheme.spacingMd),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: provider.isLoading ? null : () async {
                      if (canPause) {
                        await provider.pauseMining();
                      } else if (canResume) {
                        await provider.resumeMining();
                      }
                    },
                    style: UltraModernTheme.secondaryButton,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(canPause ? Icons.pause : Icons.play_arrow),
                        const SizedBox(width: UltraModernTheme.spacingSm),
                        Text(canPause ? 'Pause' : 'Resume'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: UltraModernTheme.spacingMd),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _showAdvancedMetrics = !_showAdvancedMetrics),
                    style: UltraModernTheme.secondaryButton,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_showAdvancedMetrics ? Icons.expand_less : Icons.expand_more),
                        const SizedBox(width: UltraModernTheme.spacingSm),
                        const Text('Metrics'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdvancedMetrics(SecureStellarProvider provider) {
    if (!_showAdvancedMetrics) return const SizedBox.shrink();
    
    final session = provider.currentMiningSession;
    if (session == null) return const SizedBox.shrink();
    
    return UltraModernWidgets.glassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics,
                color: UltraModernTheme.primaryGold,
                size: 20,
              ),
              const SizedBox(width: UltraModernTheme.spacingSm),
              Text(
                'Advanced Metrics',
                style: UltraModernTheme.headline.copyWith(
                  color: UltraModernTheme.primaryGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: UltraModernTheme.spacingLg),
          
          // Metrics Grid
          _buildMetricRow('Session ID', session.sessionId.substring(0, 12) + '...'),
          _buildMetricRow('Started', _formatDateTime(session.sessionStart)),
          _buildMetricRow('Valid Proofs', '${session.proofs.where((p) => session.validateProof(p)).length}/${session.proofs.length}'),
          _buildMetricRow('Uptime', _formatDuration(Duration(seconds: session.accumulatedSeconds))),
          _buildMetricRow('Device ID', session.deviceId.substring(0, 12) + '...'),
          
          const SizedBox(height: UltraModernTheme.spacingLg),
          
          // Security Status
          Container(
            padding: const EdgeInsets.all(UltraModernTheme.spacingMd),
            decoration: BoxDecoration(
              color: session.isValid ? UltraModernTheme.successGreen.withOpacity(0.1) : UltraModernTheme.errorRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(UltraModernTheme.radiusSm),
              border: Border.all(
                color: session.isValid ? UltraModernTheme.successGreen : UltraModernTheme.errorRed,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  session.isValid ? Icons.verified_user : Icons.error,
                  color: session.isValid ? UltraModernTheme.successGreen : UltraModernTheme.errorRed,
                  size: 20,
                ),
                const SizedBox(width: UltraModernTheme.spacingSm),
                Text(
                  'Session ${session.isValid ? 'Verified' : 'Compromised'}',
                  style: UltraModernTheme.callout.copyWith(
                    color: session.isValid ? UltraModernTheme.successGreen : UltraModernTheme.errorRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: UltraModernTheme.spacingMd),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: UltraModernTheme.subheadline.copyWith(
              color: UltraModernTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: UltraModernTheme.subheadline.copyWith(
              color: UltraModernTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(SecureStellarProvider provider) {
    return UltraModernWidgets.glassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: UltraModernTheme.headline.copyWith(
                  color: UltraModernTheme.textPrimary,
                ),
              ),
              SizedBox(
                width: 150,
                child: UltraModernWidgets.segmentedControl<String>(
                  segments: const ['1H', '24H', '7D'],
                  selected: _selectedTimeframe,
                  onChanged: (value) => setState(() => _selectedTimeframe = value),
                  labelBuilder: (value) => value,
                ),
              ),
            ],
          ),
          const SizedBox(height: UltraModernTheme.spacingLg),
          
                    // Activity List
          _buildRealActivityList(provider),
        ],
      ),
    );
  }

  Future<void> _startMining(SecureStellarProvider provider) async {
    try {
      final success = await provider.startSecureMining();
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: UltraModernTheme.successGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: UltraModernTheme.spacingMd),
                const Text(
                  'Mining started successfully!',
                  style: UltraModernTheme.callout,
                ),
              ],
            ),
            backgroundColor: UltraModernTheme.charcoal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(UltraModernTheme.radiusMd),
            ),
            margin: const EdgeInsets.all(UltraModernTheme.spacingLg),
          ),
        );
      } else if (mounted) {
        _showErrorSnackBar(provider.error ?? 'Failed to start mining');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: UltraModernTheme.errorRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: UltraModernTheme.spacingMd),
            Expanded(
              child: Text(
                message,
                style: UltraModernTheme.callout,
              ),
            ),
          ],
        ),
        backgroundColor: UltraModernTheme.charcoal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UltraModernTheme.radiusMd),
        ),
        margin: const EdgeInsets.all(UltraModernTheme.spacingLg),
      ),
    );
  }

  Future<void> _showEndMiningDialog(SecureStellarProvider provider) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: UltraModernTheme.charcoal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UltraModernTheme.radiusLg),
        ),
        title: Text(
          'End Mining Session',
          style: UltraModernTheme.title2.copyWith(
            color: UltraModernTheme.primaryGold,
          ),
        ),
        content: Text(
          'Your mining session will end automatically after 24 hours. Rewards are credited automatically upon completion.',
          style: UltraModernTheme.body.copyWith(
            color: UltraModernTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: UltraModernTheme.callout.copyWith(
                color: UltraModernTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: UltraModernTheme.primaryButton,
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showWalletDetails(SecureStellarProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: UltraModernTheme.charcoal,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(UltraModernTheme.radiusXl),
          ),
        ),
        padding: const EdgeInsets.all(UltraModernTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: UltraModernTheme.steel,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: UltraModernTheme.spacingXl),
            
            Text(
              'Wallet Details',
              style: UltraModernTheme.title2.copyWith(
                color: UltraModernTheme.primaryGold,
              ),
            ),
            const SizedBox(height: UltraModernTheme.spacingXl),
            
            _buildMetricRow('Current Balance', '${provider.balance} AKOFA'),
            _buildMetricRow('Total Earned', '${(provider.securityMetrics['totalEarned'] ?? 0.0).toStringAsFixed(3)} AKOFA'),
            _buildMetricRow('Mining Sessions', '${provider.securityMetrics['totalSessions'] ?? 0}'),
            _buildMetricRow('Wallet Status', provider.hasWallet ? 'Active' : 'Inactive'),
            _buildMetricRow('Trustline', provider.hasAkofaTrustline ? 'Configured' : 'Not Set'),
            _buildMetricRow('Security Score', '${((provider.securityMetrics['integrityScore'] ?? 1.0) * 100).toStringAsFixed(0)}%'),
            
            const SizedBox(height: UltraModernTheme.spacingXl),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/all-transactions');
                },
                style: UltraModernTheme.primaryButton,
                child: const Text('View Transactions'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime time) {
    return '${time.day}/${time.month} ${_formatTime(time)}';
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return '0m';
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  // Real-time calculation methods for dynamic analytics
  
  String _calculateEarningsTrend(Map<String, dynamic> metrics) {
    final totalEarned = metrics['totalEarned'] ?? 0.0;
    final totalSessions = metrics['totalSessions'] ?? 0;
    
    if (totalSessions == 0) return 'New';
    
    final avgPerSession = totalEarned / totalSessions;
    if (avgPerSession > 0.5) return '+${(avgPerSession * 100).toStringAsFixed(1)}%';
    if (avgPerSession > 0.2) return '+${(avgPerSession * 50).toStringAsFixed(1)}%';
    return '+${(avgPerSession * 20).toStringAsFixed(1)}%';
  }
  
  double _calculateEarningsProgress(double balance, Map<String, dynamic> metrics) {
    final totalEarned = metrics['totalEarned'] ?? 0.0;
    if (totalEarned == 0) return 0.0;
    
    // Calculate progress based on earning milestones
    final milestone = (totalEarned / 10).floor() * 10; // Every 10 AKOFA milestone
    return (balance / (milestone + 10)).clamp(0.0, 1.0);
  }
  
  String _calculateSessionsTrend(Map<String, dynamic> metrics) {
    final totalSessions = metrics['totalSessions'] ?? 0;
    final flaggedSessions = metrics['flaggedSessions'] ?? 0;
    
    if (totalSessions == 0) return 'New';
    
    final successRate = (totalSessions - flaggedSessions) / totalSessions;
    if (successRate > 0.95) return '+${(successRate * 100).toStringAsFixed(0)}%';
    if (successRate > 0.8) return '+${(successRate * 50).toStringAsFixed(0)}%';
    return '+${(successRate * 20).toStringAsFixed(0)}%';
  }
  
  double _calculateSessionsProgress(Map<String, dynamic> metrics) {
    final totalSessions = metrics['totalSessions'] ?? 0;
    final flaggedSessions = metrics['flaggedSessions'] ?? 0;
    
    if (totalSessions == 0) return 0.0;
    
    final successRate = (totalSessions - flaggedSessions) / totalSessions;
    return successRate;
  }
  
  String _calculateSecurityTrend(Map<String, dynamic> metrics) {
    final integrityScore = metrics['integrityScore'] ?? 1.0;
    final trustLevel = metrics['trustLevel'] ?? 'new';
    
    if (integrityScore > 0.95 && trustLevel == 'high') return 'Excellent';
    if (integrityScore > 0.8 && trustLevel == 'medium') return 'Good';
    if (integrityScore > 0.6) return 'Fair';
    return 'Needs Attention';
  }
  
  String _calculateNetworkTrend(SecureMiningSession? session) {
    if (session == null) return 'Inactive';
    
    final proofs = session.totalProofsSubmitted;
    if (proofs > 100) return '+${proofs}';
    if (proofs > 50) return '+${proofs}';
    if (proofs > 10) return '+${proofs}';
    return '+${proofs}';
  }
  
  double _calculateNetworkProgress(SecureMiningSession? session) {
    if (session == null) return 0.0;
    
    final proofs = session.totalProofsSubmitted;
    // Progress based on proof milestones
    if (proofs >= 100) return 1.0;
    if (proofs >= 50) return 0.8;
    if (proofs >= 25) return 0.6;
    if (proofs >= 10) return 0.4;
    if (proofs >= 5) return 0.2;
    return proofs / 5.0;
  }
  
  String _calculateMiningRateTrend(SecureMiningSession? session) {
    if (session == null) return 'Inactive';
    
    final rate = session.miningRate;
    if (rate >= 0.5) return 'Boosted';
    if (rate >= 0.35) return 'Enhanced';
    if (rate >= 0.25) return 'Standard';
    return 'Basic';
  }
  
  double _calculateMiningRateProgress(SecureMiningSession? session) {
    if (session == null) return 0.0;
    
    final rate = session.miningRate;
    // Progress based on mining rate tiers
    return (rate / 0.5).clamp(0.0, 1.0);
  }
  
  String _calculateEfficiencyTrend(SecureMiningSession? session) {
    if (session == null) return 'Inactive';
    
    final efficiency = _calculateEfficiency(session);
    if (efficiency > 90) return 'Optimal';
    if (efficiency > 75) return 'Good';
    if (efficiency > 60) return 'Fair';
    return 'Poor';
  }

  // Balance trend calculation
  String _calculateBalanceTrend(double balance, Map<String, dynamic> metrics) {
    final totalEarned = metrics['totalEarned'] ?? 0.0;
    
    if (totalEarned == 0) return 'New';
    
    // Calculate what percentage of total earnings is currently in wallet
    if (totalEarned > 0) {
      final percentageInWallet = (balance / totalEarned) * 100;
      if (percentageInWallet > 80) return 'High';
      if (percentageInWallet > 50) return 'Medium';
      if (percentageInWallet > 20) return 'Low';
      return 'Very Low';
    }
    
    return 'New';
  }
  
  // Balance progress calculation
  double _calculateBalanceProgress(double balance, Map<String, dynamic> metrics) {
    final totalEarned = metrics['totalEarned'] ?? 0.0;
    
    if (totalEarned == 0) return 0.0;
    
    // Progress based on how much of total earnings is currently in wallet
    return (balance / totalEarned).clamp(0.0, 1.0);
  }

  // Build real activity list from actual mining data
  Widget _buildRealActivityList(SecureStellarProvider provider) {
    final session = provider.currentMiningSession;
    final metrics = provider.securityMetrics;
    
    if (session == null) {
      return Container(
        padding: const EdgeInsets.all(UltraModernTheme.spacingLg),
        child: Center(
          child: Text(
            'No mining activity yet',
            style: UltraModernTheme.callout.copyWith(
              color: UltraModernTheme.textTertiary,
            ),
          ),
        ),
      );
    }

    final activities = <Map<String, dynamic>>[];
    
    // Add current session activity
    if (session.isActive) {
      activities.add({
        'action': 'Mining Active',
        'time': _formatDuration(DateTime.now().difference(session.sessionStart)),
        'icon': Icons.play_arrow,
        'color': UltraModernTheme.successGreen,
        'status': 'active',
      });
    }
    
    // Add proof submission activity
    if (session.totalProofsSubmitted > 0) {
      activities.add({
        'action': 'Proofs Submitted',
        'time': '${session.totalProofsSubmitted} proofs',
        'icon': Icons.verified,
        'color': UltraModernTheme.primaryGold,
        'status': 'completed',
      });
    }
    
    // Add session validation status
    activities.add({
      'action': 'Session Status',
      'time': session.isValid ? 'Verified' : 'Pending',
      'icon': session.isValid ? Icons.check_circle : Icons.pending,
      'color': session.isValid ? UltraModernTheme.successGreen : UltraModernTheme.warningAmber,
      'status': session.isValid ? 'verified' : 'pending',
    });
    
    // Add security metrics
    if (metrics.isNotEmpty) {
      final integrityScore = metrics['integrityScore'] ?? 1.0;
      activities.add({
        'action': 'Security Score',
        'time': '${(integrityScore * 100).toStringAsFixed(0)}%',
        'icon': Icons.security,
        'color': integrityScore > 0.8 ? UltraModernTheme.successGreen : UltraModernTheme.warningAmber,
        'status': integrityScore > 0.8 ? 'secure' : 'warning',
      });
    }
    
    if (activities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(UltraModernTheme.spacingLg),
        child: Center(
          child: Text(
            'Start mining to see activity',
            style: UltraModernTheme.callout.copyWith(
              color: UltraModernTheme.textTertiary,
            ),
          ),
        ),
      );
    }

    return Column(
      children: activities.take(4).map((activity) {
        return Container(
          margin: const EdgeInsets.only(bottom: UltraModernTheme.spacingMd),
          padding: const EdgeInsets.all(UltraModernTheme.spacingMd),
          decoration: BoxDecoration(
            color: UltraModernTheme.glassBlack,
            borderRadius: BorderRadius.circular(UltraModernTheme.radiusSm),
            border: Border.all(
              color: UltraModernTheme.steel.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (activity['color'] as Color).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(UltraModernTheme.radiusSm),
                ),
                child: Icon(
                  activity['icon'] as IconData,
                  color: activity['color'] as Color,
                  size: 16,
                ),
              ),
              const SizedBox(width: UltraModernTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity['action'] as String,
                      style: UltraModernTheme.callout.copyWith(
                        color: UltraModernTheme.textPrimary,
                      ),
                    ),
                    Text(
                      activity['time'] as String,
                      style: UltraModernTheme.footnote.copyWith(
                        color: activity['color'] as Color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }


}

/// Custom painter for orbital animation around mining core
class OrbitPainter extends CustomPainter {
  final Animation<double> animation;
  final bool isActive;

  OrbitPainter({required this.animation, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;
    
    final paint = Paint()
      ..color = UltraModernTheme.primaryGold.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    
    // Draw orbiting particles
    for (int i = 0; i < 3; i++) {
      final angle = (animation.value * 2 * math.pi) + (i * 2 * math.pi / 3);
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      
      canvas.drawCircle(
        Offset(x, y),
        2 + math.sin(animation.value * 4 * math.pi + i) * 1,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
