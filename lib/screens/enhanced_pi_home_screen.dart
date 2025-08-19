import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart' as local_auth;
import '../providers/secure_stellar_provider.dart';
import '../theme/app_theme.dart';

import '../models/secure_mining_session.dart';

/// Enhanced PI Home Screen with integrated secure mining
class EnhancedPiHomeScreen extends StatefulWidget {
  const EnhancedPiHomeScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedPiHomeScreen> createState() => _EnhancedPiHomeScreenState();
}

class _EnhancedPiHomeScreenState extends State<EnhancedPiHomeScreen>
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
    
    // Initialize secure mining when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSecureMining();
    });
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

  Future<void> _initializeSecureMining() async {
    // Auto-load any existing mining session - will be done automatically by provider
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SecureStellarProvider, local_auth.AuthProvider>(
      builder: (context, stellarProvider, authProvider, _) {
        return Scaffold(
          backgroundColor: AppTheme.black,
          body: CustomScrollView(
            slivers: [
                // App Bar
                SliverAppBar(
                  backgroundColor: AppTheme.black,
                  elevation: 0,
                  expandedHeight: 120,
                  floating: false,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      'AZIX Mining',
                      style: AppTheme.headingLarge.copyWith(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    centerTitle: true,
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        _showSecurityPanel ? Icons.security : Icons.security_outlined,
                        color: AppTheme.primaryGold,
                      ),
                      onPressed: () => setState(() => _showSecurityPanel = !_showSecurityPanel),
                      tooltip: 'Security Status',
                    ),
                    IconButton(
                      icon: const Icon(Icons.account_balance_wallet, color: AppTheme.primaryGold),
                      onPressed: () => _showWalletInfo(stellarProvider),
                      tooltip: 'Wallet Info',
                    ),
                  ],
                ),
                
                // Main content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Security alerts banner
                        if (stellarProvider.securityAlerts.isNotEmpty)
                          _buildSecurityAlerts(stellarProvider.securityAlerts),
                        
                        const SizedBox(height: 16),
                        
                        // Security panel
                        if (_showSecurityPanel)
                          _buildSecurityPanel(stellarProvider),
                        
                        const SizedBox(height: 16),
                        
                        // Mining status card
                        _buildMiningStatusCard(stellarProvider),
                        
                        const SizedBox(height: 24),
                        
                        // Mining controls
                        _buildMiningControls(stellarProvider),
                        
                        const SizedBox(height: 24),
                        
                        // Session details
                        if (stellarProvider.currentMiningSession != null)
                          _buildSessionDetails(stellarProvider.currentMiningSession!),
                        
                        const SizedBox(height: 24),
                        
                        // Quick actions
                        _buildQuickActions(context, stellarProvider),
                        
                        const SizedBox(height: 24),
                        
                        // Security metrics
                        if (stellarProvider.securityMetrics.isNotEmpty)
                          _buildSecurityMetrics(stellarProvider.securityMetrics),
                      ],
                    ),
                  ),
                ),
              ],
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
          ...alerts.map((alert) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $alert',
              style: AppTheme.bodySmall.copyWith(color: Colors.orange.shade300),
            ),
          )),
        ],
      ),
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
                'Security Status',
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
                'Last Check: ',
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
                  provider.currentMiningSession!.isValid ? Icons.check_circle : Icons.error,
                  color: provider.currentMiningSession!.isValid ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Session: ${provider.currentMiningSession!.isValid ? "Secure" : "Compromised"}',
                  style: AppTheme.bodySmall.copyWith(
                    color: provider.currentMiningSession!.isValid ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMiningStatusCard(SecureStellarProvider provider) {
    final session = provider.currentMiningSession;
    final isActive = session?.isActive ?? false;
    final isPaused = session?.isPaused ?? false;
    final earned = session?.earnedAkofa ?? 0.0;
    
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
          color: isActive ? AppTheme.primaryGold.withOpacity(0.5) : AppTheme.grey.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Status indicator
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? AppTheme.primaryGold : AppTheme.grey,
                width: 3,
              ),
              gradient: isActive ? LinearGradient(
                colors: [AppTheme.primaryGold.withOpacity(0.2), Colors.transparent],
              ) : null,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isActive ? Icons.play_circle_filled : isPaused ? Icons.pause_circle_filled : Icons.stop_circle,
                    size: 40,
                    color: isActive ? AppTheme.primaryGold : AppTheme.grey,
                  ).animate(
                    effects: isActive ? [
                      const ScaleEffect(
                        duration: Duration(seconds: 2),
                        begin: Offset(1.0, 1.0),
                        end: Offset(1.1, 1.1),
                      ),
                    ] : [],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isActive ? 'MINING' : isPaused ? 'PAUSED' : 'INACTIVE',
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
          
          // Earnings display
          Text(
            'Earned AKOFA',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
          ),
          const SizedBox(height: 8),
          Text(
            '${earned.toStringAsFixed(6)} ₳',
            style: AppTheme.headingLarge.copyWith(
              color: AppTheme.primaryGold,
              fontWeight: FontWeight.bold,
              fontSize: 32,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Session progress
          if (session != null) _buildSessionProgress(session),
        ],
      ),
    );
  }

  Widget _buildSessionProgress(SecureMiningSession session) {
    final totalDuration = session.sessionEnd.difference(session.sessionStart).inSeconds;
    final progress = session.accumulatedSeconds / totalDuration;
    final remainingTime = session.sessionEnd.difference(DateTime.now());
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
            ),
            Text(
              '${(progress * 100).toStringAsFixed(1)}%',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.white),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: AppTheme.grey.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Time Remaining: ${_formatDuration(remainingTime)}',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
        ),
      ],
    );
  }

  Widget _buildMiningControls(SecureStellarProvider provider) {
    final session = provider.currentMiningSession;
    final canStart = session == null || !session.isActive;
    final canPause = session?.isActive == true && session?.isPaused == false;
    final canResume = session?.isPaused == true;
    
    return Column(
      children: [
        Row(
          children: [
            // Start/Stop button
            Expanded(
              child: ElevatedButton(
                onPressed: provider.isLoading ? null : () async {
                  if (canStart) {
                    await _startMining(provider);
                  } else {
                    await _showEndMiningDialog(provider);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: canStart ? AppTheme.primaryGold : Colors.red,
                  foregroundColor: AppTheme.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
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
                          Icon(canStart ? Icons.play_arrow : Icons.stop),
                          const SizedBox(width: 8),
                          Text(
                            canStart ? 'Start Mining' : 'End Session',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Pause/Resume button
            if (session != null && session.isActive)
              ElevatedButton(
                onPressed: provider.isLoading ? null : () async {
                  if (canPause) {
                    await provider.pauseMining();
                  } else if (canResume) {
                    await provider.resumeMining();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.darkGrey,
                  foregroundColor: AppTheme.white,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Icon(canPause ? Icons.pause : Icons.play_arrow),
              ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Status information
        if (session != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.darkGrey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('Rate', '${session.miningRate}/h'),
                _buildStatItem('Proofs', '${session.totalProofsSubmitted}'),
                _buildStatItem('Uptime', _formatDuration(Duration(seconds: session.accumulatedSeconds))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
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
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          _buildDetailRow('Session ID', session.sessionId.substring(0, 12) + '...'),
          _buildDetailRow('Started', _formatDateTime(session.sessionStart)),
          _buildDetailRow('Ends', _formatDateTime(session.sessionEnd)),
          _buildDetailRow('Valid Proofs', '${session.proofs.where((p) => session.validateProof(p)).length}/${session.proofs.length}'),
          _buildDetailRow('Integrity', session.isValid ? 'Secure ✅' : 'Compromised ❌'),
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
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
          ),
          Flexible(
            child: Text(
              value,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.white),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, SecureStellarProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/all-transactions'),
                  icon: const Icon(Icons.history),
                  label: const Text('History'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.darkGrey,
                    foregroundColor: AppTheme.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showWalletInfo(provider),
                  icon: const Icon(Icons.account_balance_wallet),
                  label: const Text('Wallet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.darkGrey,
                    foregroundColor: AppTheme.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityMetrics(Map<String, dynamic> metrics) {
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
            'Security Overview',
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          _buildDetailRow('Total Sessions', '${metrics['totalSessions'] ?? 0}'),
          _buildDetailRow('Trust Level', '${metrics['trustLevel'] ?? 'New'}'),
          _buildDetailRow('Integrity Score', '${((metrics['integrityScore'] ?? 0.0) * 100).toStringAsFixed(1)}%'),
          
          if ((metrics['flaggedSessions'] ?? 0) > 0)
            _buildDetailRow('Flagged Sessions', '${metrics['flaggedSessions']}'),
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
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Mining started successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(provider.error ?? 'Failed to start mining')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _showEndMiningDialog(SecureStellarProvider provider) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'End Mining Session',
          style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
        ),
        content: Text(
          'Are you sure you want to end your mining session? Your earned AKOFA will be credited to your wallet.',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: AppTheme.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Session will auto-end when it expires
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Session will end automatically when time expires'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: AppTheme.white,
            ),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showWalletInfo(SecureStellarProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wallet Information',
              style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Balance', '${provider.balance} AKOFA'),
            _buildDetailRow('Wallet Status', provider.hasWallet ? 'Active ✅' : 'Not Created ❌'),
            _buildDetailRow('Trustline', provider.hasAkofaTrustline ? 'Configured ✅' : 'Not Set ❌'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/all-transactions');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: AppTheme.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
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
}
