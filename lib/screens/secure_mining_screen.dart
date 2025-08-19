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
              'Secure Mining',
              style: AppTheme.headingMedium.copyWith(color: AppTheme.white),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _showSecurityPanel ? Icons.security : Icons.security_outlined,
                  color: AppTheme.primaryGold,
                ),
                onPressed: () => setState(() => _showSecurityPanel = !_showSecurityPanel),
                tooltip: 'Security Panel',
              ),
            ],
          ),
          body: SingleChildScrollView(
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
                  if (_showSecurityPanel)
                    _buildSecurityPanel(stellarProvider),
                  
                  const SizedBox(height: 16),
                  
                  // Mining controls
                  _buildMiningControls(session, stellarProvider),
                  
                  const SizedBox(height: 16),
                  
                  // Session details
                  if (session != null)
                    _buildSessionDetails(session),
                  
                  const SizedBox(height: 16),
                  
                  // Security metrics
                  _buildSecurityMetrics(stellarProvider.securityMetrics),
                ],
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

  Widget _buildMiningStatusCard(SecureMiningSession? session, SecureStellarProvider provider) {
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
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isActive ? Icons.play_circle_filled : Icons.pause_circle_filled,
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
    final progress = session.accumulatedSeconds / (24 * 3600); // 24 hour session
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
                  provider.currentMiningSession!.isValid ? Icons.check_circle : Icons.error,
                  color: provider.currentMiningSession!.isValid ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Session Integrity: ${provider.currentMiningSession!.isValid ? "Valid" : "Compromised"}',
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

  Widget _buildMiningControls(SecureMiningSession? session, SecureStellarProvider provider) {
    final canStart = session == null || !session.isActive;
    final canPause = session?.isActive == true && session?.isPaused == false;
    final canResume = session?.isPaused == true;
    
    return Row(
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
            ),
            child: provider.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    canStart ? 'Start Secure Mining' : 'End Mining',
                    style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold),
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
          
          _buildDetailRow('Session ID', session.sessionId.substring(0, 8) + '...'),
          _buildDetailRow('Mining Rate', '${session.miningRate} AKOFA/hour'),
          _buildDetailRow('Started', _formatTime(session.sessionStart)),
          _buildDetailRow('Ends', _formatTime(session.sessionEnd)),
          _buildDetailRow('Accumulated Time', _formatDuration(Duration(seconds: session.accumulatedSeconds))),
          _buildDetailRow('Proofs Submitted', '${session.totalProofsSubmitted}'),
          _buildDetailRow('Valid Proofs', '${session.proofs.where((p) => session.validateProof(p)).length}'),
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
          _buildDetailRow('Flagged Sessions', '${metrics['flaggedSessions'] ?? 0}'),
          _buildDetailRow('Trust Level', '${metrics['trustLevel'] ?? 'Unknown'}'),
          _buildDetailRow('Integrity Score', '${((metrics['integrityScore'] ?? 0.0) * 100).toStringAsFixed(1)}%'),
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
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
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
            onPressed: () async {
              Navigator.of(context).pop();
              // Session ending is handled automatically
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: AppTheme.white,
            ),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
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
