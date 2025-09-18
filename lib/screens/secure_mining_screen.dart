import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/secure_stellar_provider.dart';
import '../providers/auth_provider.dart' as local_auth;
import '../theme/app_theme.dart';
import '../models/secure_mining_session.dart';
import '../utils/responsive_layout.dart';

/// Enhanced mining screen with security features and real-time monitoring
class SecureMiningScreen extends StatefulWidget {
  const SecureMiningScreen({Key? key}) : super(key: key);

  @override
  State<SecureMiningScreen> createState() => _SecureMiningScreenState();
}

class _SecureMiningScreenState extends State<SecureMiningScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _uiUpdateTimer;
  bool _showSecurityPanel = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseController.repeat(reverse: true);

    // Start UI updates
    _startUIUpdates();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _uiUpdateTimer?.cancel();
    super.dispose();
  }

  void _startUIUpdates() {
    _uiUpdateTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
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
              '',
              style: AppTheme.headingMedium.copyWith(color: AppTheme.white),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
                onPressed: () => stellarProvider.refreshMiningSession(),
                tooltip: 'Refresh Mining Data',
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
                  // Security alerts banner
                  if (stellarProvider.securityAlerts.isNotEmpty)
                    _buildSecurityAlerts(stellarProvider.securityAlerts),

                  const SizedBox(height: 16),

                  // Mining status card
                  _buildMiningStatusCard(session, stellarProvider),

                  const SizedBox(height: 16),

                  // Security panel
                  if (_showSecurityPanel) _buildSecurityPanel(stellarProvider),

                  const SizedBox(height: 16),

                  // Mining controls
                  _buildMiningControls(session, stellarProvider),

                  const SizedBox(height: 16),

                  // Session details
                  if (session != null) _buildSessionDetails(session),

                  const SizedBox(height: 16),

                  // Security metrics
                  _buildSecurityMetrics(stellarProvider.securityMetrics),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSecurityAlerts(List<String> alerts) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Security Alerts',
                style: AppTheme.bodyMedium.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...alerts.map(
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
    );
  }

  Widget _buildMiningStatusCard(
    SecureMiningSession? session,
    SecureStellarProvider provider,
  ) {
    final isActive = session?.isActive ?? false;
    final isPaused = session?.isPaused ?? false;
    final earned = session?.earnedAkofa ?? 0.0;
    final miningRate = session?.miningRate ?? 0.25;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppTheme.primaryGold.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Status indicator with real-time animation
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? AppTheme.primaryGold : AppTheme.grey,
                width: 3,
              ),
              gradient: isActive
                  ? LinearGradient(
                      colors: [
                        AppTheme.primaryGold.withOpacity(0.2),
                        AppTheme.primaryGold.withOpacity(0.1),
                      ],
                    )
                  : null,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isActive
                        ? Icons.play_circle_filled
                        : Icons.pause_circle_filled,
                    size: 40,
                    color: isActive ? AppTheme.primaryGold : AppTheme.grey,
                  ).animate(
                    effects: isActive
                        ? [
                            const ScaleEffect(
                              duration: Duration(seconds: 2),
                              begin: Offset(1.0, 1.0),
                              end: Offset(1.1, 1.1),
                            ),
                          ]
                        : [],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isActive
                        ? 'MINING'
                        : isPaused
                        ? 'PAUSED'
                        : 'INACTIVE',
                    style: AppTheme.bodySmall.copyWith(
                      color: isActive ? AppTheme.primaryGold : AppTheme.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Real-time earnings display with animation
          Text(
            'Earned AKOFA',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              '${earned.toStringAsFixed(6)} ₳',
              key: ValueKey(earned),
              style: AppTheme.headingLarge.copyWith(
                color: AppTheme.primaryGold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Mining rate display
          Text(
            '${miningRate} AKOFA/hour',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.grey,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 8),

          // Wallet destination display (subtle and minimalistic)
          if (provider.publicKey != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryGold.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 14,
                    color: AppTheme.primaryGold.withOpacity(0.7),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Rewards to: ${provider.publicKey!.substring(0, 8)}...${provider.publicKey!.substring(provider.publicKey!.length - 4)}',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.primaryGold.withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Session progress with real-time updates
          if (session != null) _buildSessionProgress(session),

          // Real-time mining stats
          if (isActive && session != null) _buildRealTimeStats(session),
        ],
      ),
    );
  }

  Widget _buildSessionProgress(SecureMiningSession session) {
    final progress =
        session.accumulatedSeconds / (24 * 3600); // 24 hour session
    final remainingTime = session.sessionEnd.difference(DateTime.now());

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Session Progress',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
            ),
            Text(
              '${(progress * 100).toStringAsFixed(1)}%',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.white),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: AppTheme.grey.withOpacity(0.3),
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
        ),
        const SizedBox(height: 8),
        Text(
          'Time Remaining: ${_formatDuration(remainingTime)}',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
        ),
      ],
    );
  }

  Widget _buildRealTimeStats(SecureMiningSession session) {
    final now = DateTime.now();
    final elapsedTime = now.difference(session.sessionStart);
    final currentCycleElapsed = now.difference(session.lastResume);
    final hoursElapsed = elapsedTime.inSeconds / 3600.0;
    final currentRate = session.earnedAkofa / hoursElapsed;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryGold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Real-Time Stats',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.primaryGold,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Elapsed', _formatDuration(elapsedTime)),
              _buildStatItem(
                'Current Rate',
                '${currentRate.toStringAsFixed(4)} ₳/h',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Proofs', '${session.totalProofsSubmitted}'),
              _buildStatItem(
                'Cycle Time',
                _formatDuration(currentCycleElapsed),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.grey,
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityPanel(SecureStellarProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, color: AppTheme.primaryGold, size: 20),
              const SizedBox(width: 8),
              Text(
                'Security Panel',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Last security check
          Row(
            children: [
              Text(
                'Last Security Check: ',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
              ),
              Text(
                provider.lastSecurityCheck != null
                    ? _formatTime(provider.lastSecurityCheck!)
                    : 'Never',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.white),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Session validation status
          if (provider.currentMiningSession != null)
            Row(
              children: [
                Icon(
                  provider.currentMiningSession!.isValid
                      ? Icons.check_circle
                      : Icons.error,
                  color: provider.currentMiningSession!.isValid
                      ? Colors.green
                      : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Session Integrity: ${provider.currentMiningSession!.isValid ? "Valid" : "Compromised"}',
                  style: AppTheme.bodySmall.copyWith(
                    color: provider.currentMiningSession!.isValid
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMiningControls(
    SecureMiningSession? session,
    SecureStellarProvider provider,
  ) {
    final canStart = session == null || !session.isActive;
    final canPause = session?.isActive == true && session?.isPaused == false;
    final canResume = session?.isPaused == true;

    return Column(
      children: [
        // Main control button - changes based on session state
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
      ],
    );
  }

  Widget _buildSessionDetails(SecureMiningSession session) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Details',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          _buildDetailRow(
            'Session ID',
            session.sessionId.substring(0, 8) + '...',
          ),
          _buildDetailRow('Mining Rate', '${session.miningRate} AKOFA/hour'),
          _buildDetailRow('Started', _formatTime(session.sessionStart)),
          _buildDetailRow('Ends', _formatTime(session.sessionEnd)),
          _buildDetailRow(
            'Accumulated Time',
            _formatDuration(Duration(seconds: session.accumulatedSeconds)),
          ),
          _buildDetailRow(
            'Proofs Submitted',
            '${session.totalProofsSubmitted}',
          ),
          _buildDetailRow(
            'Valid Proofs',
            '${session.proofs.where((p) => session.validateProof(p)).length}',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
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

  Widget _buildSecurityMetrics(Map<String, dynamic> metrics) {
    if (metrics.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Security Metrics',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          _buildDetailRow('Total Sessions', '${metrics['totalSessions'] ?? 0}'),
          _buildDetailRow(
            'Flagged Sessions',
            '${metrics['flaggedSessions'] ?? 0}',
          ),
          _buildDetailRow(
            'Trust Level',
            '${metrics['trustLevel'] ?? 'Unknown'}',
          ),
          _buildDetailRow(
            'Integrity Score',
            '${((metrics['integrityScore'] ?? 0.0) * 100).toStringAsFixed(1)}%',
          ),
        ],
      ),
    );
  }

  Future<void> _startMining(SecureStellarProvider provider) async {
    try {
      final success = await provider.startSecureMining();

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Secure mining started successfully!'),
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
