import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/secure_stellar_provider.dart';
import '../providers/auth_provider.dart' as local_auth;
import '../theme/app_theme.dart';
import '../models/secure_mining_session.dart';
import '../utils/responsive_layout.dart';

/// Enhanced mining analytics screen with comprehensive performance monitoring
class EnhancedMiningAnalyticsScreen extends StatefulWidget {
  const EnhancedMiningAnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedMiningAnalyticsScreen> createState() =>
      _EnhancedMiningAnalyticsScreenState();
}

class _EnhancedMiningAnalyticsScreenState
    extends State<EnhancedMiningAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _analyticsUpdateTimer;
  bool _showAdvancedPanel = false;
  bool _showSecurityPanel = true;
  double _miningIntensity = 0.7; // 0.0 to 1.0

  // Simulated analytics data
  double _cpuUsage = 0.0;
  double _memoryUsage = 0.0;
  double _hashRate = 0.0;
  int _proofsPerMinute = 0;
  List<Map<String, dynamic>> _performanceHistory = [];
  List<Map<String, dynamic>> _proofHistory = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseController.repeat(reverse: true);

    _startAnalyticsUpdates();
    _initializeSimulatedData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _analyticsUpdateTimer?.cancel();
    super.dispose();
  }

  void _startAnalyticsUpdates() {
    _analyticsUpdateTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _updateAnalytics(),
    );
  }

  void _initializeSimulatedData() {
    // Initialize with some historical data
    final now = DateTime.now();
    for (int i = 0; i < 20; i++) {
      final time = now.subtract(Duration(minutes: 20 - i));
      _performanceHistory.add({
        'time': time,
        'cpu': 20 + Random().nextDouble() * 60,
        'hashRate': 100 + Random().nextDouble() * 200,
        'earnings': Random().nextDouble() * 0.1,
      });

      _proofHistory.add({
        'time': time,
        'proofs': Random().nextInt(10) + 1,
        'validated': Random().nextBool(),
      });
    }
  }

  void _updateAnalytics() {
    if (!mounted) return;

    final session = context.read<SecureStellarProvider>().currentMiningSession;
    if (session == null || !session.isActive || session.isPaused) {
      setState(() {
        _cpuUsage = 0.0;
        _memoryUsage = 0.0;
        _hashRate = 0.0;
        _proofsPerMinute = 0;
      });
      return;
    }

    // Simulate realistic mining analytics based on session state
    setState(() {
      _cpuUsage = 15 + (_miningIntensity * 70) + (Random().nextDouble() * 10);
      _memoryUsage = 25 + (_miningIntensity * 50) + (Random().nextDouble() * 5);
      _hashRate = (_miningIntensity * 500) + (Random().nextDouble() * 100);
      _proofsPerMinute = (_miningIntensity * 12).round() + Random().nextInt(3);

      // Add new data point to history
      final now = DateTime.now();
      _performanceHistory.add({
        'time': now,
        'cpu': _cpuUsage,
        'hashRate': _hashRate,
        'earnings': session.earnedAkofa,
      });

      _proofHistory.add({
        'time': now,
        'proofs': _proofsPerMinute,
        'validated': Random().nextDouble() > 0.05, // 95% success rate
      });

      // Keep only last 20 data points
      if (_performanceHistory.length > 20) {
        _performanceHistory.removeAt(0);
      }
      if (_proofHistory.length > 20) {
        _proofHistory.removeAt(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SecureStellarProvider, local_auth.AuthProvider>(
      builder: (context, stellarProvider, authProvider, _) {
        final session = stellarProvider.currentMiningSession;

        return Scaffold(
          backgroundColor: AppTheme.black,
          appBar: AppBar(
            backgroundColor: AppTheme.black,
            elevation: 0,
            title: Text(
              'Mining Analytics',
              style: AppTheme.headingMedium.copyWith(color: AppTheme.white),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
                onPressed: () => context
                    .read<SecureStellarProvider>()
                    .refreshMiningSession(),
                tooltip: 'Refresh Mining Data',
              ),
              IconButton(
                icon: Icon(
                  _showAdvancedPanel ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.primaryGold,
                ),
                onPressed: () =>
                    setState(() => _showAdvancedPanel = !_showAdvancedPanel),
                tooltip: 'Advanced Analytics',
              ),
              IconButton(
                icon: Icon(
                  _showSecurityPanel ? Icons.security : Icons.security_outlined,
                  color: AppTheme.primaryGold,
                ),
                onPressed: () =>
                    setState(() => _showSecurityPanel = !_showSecurityPanel),
                tooltip: 'Security Panel',
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              await stellarProvider.refreshMiningSession();
              await stellarProvider.refreshBalance();
            },
            color: AppTheme.primaryGold,
            backgroundColor: AppTheme.darkGrey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Real-time Performance Dashboard
                  _buildRealTimePerformanceDashboard(session),

                  const SizedBox(height: 16),

                  // Mining Control Center
                  _buildMiningControlCenter(session, stellarProvider),

                  const SizedBox(height: 16),

                  // Proof-of-Work Analytics
                  if (_showAdvancedPanel) _buildProofOfWorkAnalytics(session),

                  const SizedBox(height: 16),

                  // Security & Validation Panel
                  if (_showSecurityPanel)
                    _buildSecurityValidationPanel(stellarProvider),

                  const SizedBox(height: 16),

                  // Performance Charts
                  if (_showAdvancedPanel) _buildPerformanceCharts(),

                  const SizedBox(height: 16),

                  // Session Analytics
                  if (session != null) _buildSessionAnalytics(session),

                  const SizedBox(height: 16),

                  // Mining Network Status
                  _buildMiningNetworkStatus(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRealTimePerformanceDashboard(SecureMiningSession? session) {
    final isActive = session?.isActive ?? false;
    final isPaused = session?.isPaused ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.darkGrey.withOpacity(0.8),
            AppTheme.darkGrey.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? AppTheme.primaryGold.withOpacity(0.5)
              : AppTheme.grey.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // Status Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Real-Time Performance',
                style: AppTheme.headingMedium.copyWith(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isActive && !isPaused
                      ? AppTheme.primaryGold.withOpacity(0.2)
                      : AppTheme.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive && !isPaused
                        ? AppTheme.primaryGold
                        : AppTheme.grey,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isActive && !isPaused
                          ? Icons.play_circle_filled
                          : Icons.pause_circle_filled,
                      size: 16,
                      color: isActive && !isPaused
                          ? AppTheme.primaryGold
                          : AppTheme.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isActive && !isPaused ? 'MINING ACTIVE' : 'INACTIVE',
                      style: AppTheme.bodySmall.copyWith(
                        color: isActive && !isPaused
                            ? AppTheme.primaryGold
                            : AppTheme.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Performance Metrics Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildPerformanceMetric(
                'CPU Usage',
                '${_cpuUsage.toStringAsFixed(1)}%',
                _cpuUsage / 100,
                Icons.memory,
                _cpuUsage > 80
                    ? Colors.red
                    : _cpuUsage > 60
                    ? Colors.orange
                    : AppTheme.primaryGold,
              ),
              _buildPerformanceMetric(
                'Memory',
                '${_memoryUsage.toStringAsFixed(1)}%',
                _memoryUsage / 100,
                Icons.storage,
                _memoryUsage > 80
                    ? Colors.red
                    : _memoryUsage > 60
                    ? Colors.orange
                    : AppTheme.primaryGold,
              ),
              _buildPerformanceMetric(
                'Hash Rate',
                '${_hashRate.toStringAsFixed(0)} H/s',
                min(_hashRate / 600, 1.0),
                Icons.speed,
                AppTheme.primaryGold,
              ),
              _buildPerformanceMetric(
                'Proofs/Min',
                _proofsPerMinute.toString(),
                min(_proofsPerMinute / 15, 1.0),
                Icons.verified,
                AppTheme.primaryGold,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Earnings Display
          if (session != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryGold.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Current Session Earnings',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${session.earnedAkofa.toStringAsFixed(6)} ₳',
                    style: AppTheme.headingLarge.copyWith(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rate: ${(session.earnedAkofa / max(session.accumulatedSeconds / 3600, 0.0001)).toStringAsFixed(4)} ₳/hour',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetric(
    String label,
    String value,
    double progress,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppTheme.grey.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  Widget _buildMiningControlCenter(
    SecureMiningSession? session,
    SecureStellarProvider provider,
  ) {
    final canStart = session == null || !session.isActive;
    final canPause = session?.isActive == true && session?.isPaused == false;
    final canResume = session?.isPaused == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mining Control Center',
            style: AppTheme.headingMedium.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Mining Intensity Control
          Text(
            'Mining Intensity',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.speed, color: AppTheme.primaryGold, size: 20),
              Expanded(
                child: Slider(
                  value: _miningIntensity,
                  onChanged: (value) =>
                      setState(() => _miningIntensity = value),
                  activeColor: AppTheme.primaryGold,
                  inactiveColor: AppTheme.grey.withOpacity(0.3),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(_miningIntensity * 100).toStringAsFixed(0)}%',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Main Control Button - Single button that changes based on state
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      if (canStart) {
                        await _startMining(provider);
                      } else if (canPause) {
                        await provider.pauseMining();
                      } else if (canResume) {
                        await provider.resumeMining();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: canStart
                    ? AppTheme.primaryGold
                    : canPause
                    ? Colors.orange
                    : canResume
                    ? AppTheme.primaryGold
                    : AppTheme.darkGrey,
                foregroundColor: canStart || canResume
                    ? AppTheme.black
                    : AppTheme.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: provider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          canStart
                              ? Icons.play_arrow
                              : canPause
                              ? Icons.pause
                              : canResume
                              ? Icons.play_arrow
                              : Icons.stop,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          canStart
                              ? 'Start Secure Mining'
                              : canPause
                              ? 'Pause Mining'
                              : canResume
                              ? 'Resume Mining'
                              : 'Mining Active',
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // Session info text
          if (session != null && session.isActive)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                session.isPaused
                    ? 'Mining is paused. Resume to continue earning AKOFA.'
                    : 'Mining session will run for 24 hours. You can pause/resume at any time.',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.grey,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Session end time display
          if (session != null && session.isActive)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Session ends: ${_formatTime(session.sessionEnd)} (${_formatDuration(session.sessionEnd.difference(DateTime.now()))} remaining)',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Performance Mode Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Performance Mode',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
              ),
              Switch(
                value: _miningIntensity > 0.7,
                onChanged: (value) {
                  setState(() {
                    _miningIntensity = value ? 0.9 : 0.5;
                  });
                },
                activeColor: AppTheme.primaryGold,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProofOfWorkAnalytics(SecureMiningSession? session) {
    if (session == null) return const SizedBox.shrink();

    final validProofs = session.proofs
        .where((p) => session.validateProof(p))
        .length;
    final totalProofs = session.proofs.length;
    final validationRate = totalProofs > 0
        ? (validProofs / totalProofs) * 100
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user, color: AppTheme.primaryGold, size: 24),
              const SizedBox(width: 12),
              Text(
                'Proof-of-Work Analytics',
                style: AppTheme.headingMedium.copyWith(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Proof Statistics Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildProofStat(
                'Total Proofs',
                totalProofs.toString(),
                Icons.numbers,
                AppTheme.primaryGold,
              ),
              _buildProofStat(
                'Valid Proofs',
                validProofs.toString(),
                Icons.check_circle,
                validationRate > 90
                    ? Colors.green
                    : validationRate > 70
                    ? Colors.orange
                    : Colors.red,
              ),
              _buildProofStat(
                'Validation Rate',
                '${validationRate.toStringAsFixed(1)}%',
                Icons.analytics,
                validationRate > 90
                    ? Colors.green
                    : validationRate > 70
                    ? Colors.orange
                    : Colors.red,
              ),
              _buildProofStat(
                'Security Score',
                session.isValid ? '100%' : '0%',
                Icons.security,
                session.isValid ? Colors.green : Colors.red,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Recent Proof Activity
          Text(
            'Recent Proof Activity',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _proofHistory.isEmpty
                ? Center(
                    child: Text(
                      'No recent proof activity',
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: min(_proofHistory.length, 10),
                    itemBuilder: (context, index) {
                      final proof =
                          _proofHistory[_proofHistory.length - 1 - index];
                      return Container(
                        width: 60,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: proof['validated']
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: proof['validated']
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              proof['validated'] ? Icons.check : Icons.close,
                              color: proof['validated']
                                  ? Colors.green
                                  : Colors.red,
                              size: 16,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              proof['proofs'].toString(),
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProofStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityValidationPanel(SecureStellarProvider provider) {
    final session = provider.currentMiningSession;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: AppTheme.primaryGold, size: 24),
              const SizedBox(width: 12),
              Text(
                'Security & Validation',
                style: AppTheme.headingMedium.copyWith(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Security Status
          Row(
            children: [
              Icon(
                session?.isValid ?? false ? Icons.check_circle : Icons.error,
                color: session?.isValid ?? false ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Integrity',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.white,
                      ),
                    ),
                    Text(
                      session?.isValid ?? false ? 'Validated' : 'Compromised',
                      style: AppTheme.bodySmall.copyWith(
                        color: session?.isValid ?? false
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Security Metrics
          if (session != null) ...[
            _buildSecurityMetric(
              'Device ID',
              session.deviceId.substring(0, 8) + '...',
            ),
            _buildSecurityMetric(
              'Session Hash',
              session.sessionHash.substring(0, 8) + '...',
            ),
            _buildSecurityMetric(
              'Last Validation',
              _formatTime(DateTime.now()),
            ),
            _buildSecurityMetric(
              'Proof Frequency',
              '${session.proofs.length} proofs',
            ),
          ],

          const SizedBox(height: 16),

          // Security Alerts
          if (provider.securityAlerts.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Security Alerts',
                    style: AppTheme.bodyMedium.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...provider.securityAlerts.map(
                    (alert) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $alert',
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.orange.shade300,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSecurityMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
          Text(
            value,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.white),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCharts() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Analytics',
            style: AppTheme.headingMedium.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          // CPU Usage Chart
          _buildCustomLineChart(
            title: 'CPU Usage Over Time',
            data: _performanceHistory,
            valueKey: 'cpu',
            color: AppTheme.primaryGold,
            maxValue: 100,
            unit: '%',
          ),

          const SizedBox(height: 20),

          // Hash Rate Chart
          _buildCustomAreaChart(
            title: 'Hash Rate Trend',
            data: _performanceHistory,
            valueKey: 'hashRate',
            color: AppTheme.primaryGold,
            maxValue: 600,
            unit: ' H/s',
          ),

          const SizedBox(height: 20),

          // Earnings Chart
          _buildCustomLineChart(
            title: 'Earnings Growth',
            data: _performanceHistory,
            valueKey: 'earnings',
            color: Colors.green,
            maxValue: 0.2,
            unit: ' ₳',
          ),
        ],
      ),
    );
  }

  Widget _buildCustomLineChart({
    required String title,
    required List<Map<String, dynamic>> data,
    required String valueKey,
    required Color color,
    required double maxValue,
    required String unit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppTheme.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomPaint(
            painter: LineChartPainter(
              data: data,
              valueKey: valueKey,
              color: color,
              maxValue: maxValue,
            ),
            child: Container(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Latest: ${data.isNotEmpty ? (data.last[valueKey] as double).toStringAsFixed(1) : '0'}$unit',
              style: AppTheme.bodySmall.copyWith(color: color),
            ),
            Text(
              'Peak: ${data.isNotEmpty ? data.map((d) => d[valueKey] as double).reduce(max).toStringAsFixed(1) : '0'}$unit',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomAreaChart({
    required String title,
    required List<Map<String, dynamic>> data,
    required String valueKey,
    required Color color,
    required double maxValue,
    required String unit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppTheme.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomPaint(
            painter: AreaChartPainter(
              data: data,
              valueKey: valueKey,
              color: color,
              maxValue: maxValue,
            ),
            child: Container(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Current: ${data.isNotEmpty ? (data.last[valueKey] as double).toStringAsFixed(0) : '0'}$unit',
              style: AppTheme.bodySmall.copyWith(color: color),
            ),
            Text(
              'Average: ${data.isNotEmpty ? (data.map((d) => d[valueKey] as double).reduce((a, b) => a + b) / data.length).toStringAsFixed(0) : '0'}$unit',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSessionAnalytics(SecureMiningSession session) {
    final progress = session.accumulatedSeconds / (24 * 3600);
    final remainingTime = session.sessionEnd.difference(DateTime.now());
    final efficiency =
        session.earnedAkofa / max(session.accumulatedSeconds / 3600, 0.0001);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Analytics',
            style: AppTheme.headingMedium.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          // Session Progress
          Text(
            'Session Progress',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: AppTheme.grey.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toStringAsFixed(1)}% Complete • ${_formatDuration(remainingTime)} remaining',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.white),
          ),

          const SizedBox(height: 20),

          // Session Stats Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildSessionStat(
                'Mining Time',
                _formatDuration(Duration(seconds: session.accumulatedSeconds)),
                Icons.timer,
                AppTheme.primaryGold,
              ),
              _buildSessionStat(
                'Efficiency',
                '${efficiency.toStringAsFixed(4)} ₳/hr',
                Icons.trending_up,
                efficiency > 0.25 ? Colors.green : Colors.orange,
              ),
              _buildSessionStat(
                'Total Proofs',
                session.totalProofsSubmitted.toString(),
                Icons.verified,
                AppTheme.primaryGold,
              ),
              _buildSessionStat(
                'Session Status',
                session.isValid ? 'Valid' : 'Invalid',
                session.isValid ? Icons.check_circle : Icons.error,
                session.isValid ? Colors.green : Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMiningNetworkStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.network_check, color: AppTheme.primaryGold, size: 24),
              const SizedBox(width: 12),
              Text(
                'Mining Network Status',
                style: AppTheme.headingMedium.copyWith(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Network Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNetworkStat('Active Miners', '1,247', Colors.green),
              _buildNetworkStat(
                'Network Hash Rate',
                '2.4 TH/s',
                AppTheme.primaryGold,
              ),
              _buildNetworkStat(
                'Avg. Block Time',
                '3.2 min',
                AppTheme.primaryGold,
              ),
              _buildNetworkStat('Network Status', 'Healthy', Colors.green),
            ],
          ),

          const SizedBox(height: 20),

          // Regional Activity (simulated)
          Text(
            'Regional Mining Activity',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRegionActivity('North America', 0.8, Colors.blue),
              _buildRegionActivity('Europe', 0.6, Colors.green),
              _buildRegionActivity('Asia', 0.9, Colors.orange),
              _buildRegionActivity('Africa', 0.4, Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.bodyLarge.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRegionActivity(String region, double activity, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.2),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              '${(activity * 100).toInt()}%',
              style: AppTheme.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          region,
          style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _startMining(SecureStellarProvider provider) async {
    try {
      final success = await provider.startSecureMining();

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mining started successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to start mining'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}

/// Custom line chart painter for performance metrics
class LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final String valueKey;
  final Color color;
  final double maxValue;

  LineChartPainter({
    required this.data,
    required this.valueKey,
    required this.color,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final value = data[i][valueKey] as double;
      final x = (i / max(1, data.length - 1)) * size.width;
      final y = size.height - (value / maxValue) * size.height;
      points.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw points
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 3.0, pointPaint);
    }

    // Draw grid lines
    final gridPaint = Paint()
      ..color = AppTheme.grey.withOpacity(0.2)
      ..strokeWidth = 1.0;

    // Horizontal grid lines
    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Custom area chart painter for performance metrics
class AreaChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final String valueKey;
  final Color color;
  final double maxValue;

  AreaChartPainter({
    required this.data,
    required this.valueKey,
    required this.color,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    final borderPath = Path();
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final value = data[i][valueKey] as double;
      final x = (i / max(1, data.length - 1)) * size.width;
      final y = size.height - (value / maxValue) * size.height;
      points.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, size.height);
        path.lineTo(x, y);
        borderPath.moveTo(x, y);
      } else {
        path.lineTo(x, y);
        borderPath.lineTo(x, y);
      }
    }

    // Complete the area
    if (points.isNotEmpty) {
      path.lineTo(points.last.dx, size.height);
      path.close();
    }

    canvas.drawPath(path, paint);
    canvas.drawPath(borderPath, borderPaint);

    // Draw grid lines
    final gridPaint = Paint()
      ..color = AppTheme.grey.withOpacity(0.2)
      ..strokeWidth = 1.0;

    // Horizontal grid lines
    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
