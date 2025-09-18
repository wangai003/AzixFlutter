import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/auth_provider.dart' as local_auth;
import '../theme/app_theme.dart';
import '../utils/responsive_layout.dart';
import '../models/mining_session.dart';
import '../models/secure_mining_session.dart';
import '../providers/stellar_provider.dart';
import '../providers/secure_stellar_provider.dart';

class PiHomeScreen extends StatefulWidget {
  const PiHomeScreen({Key? key}) : super(key: key);

  @override
  State<PiHomeScreen> createState() => _PiHomeScreenState();
}

class _PiHomeScreenState extends State<PiHomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  bool _loadingSession = true;
  
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  List<MiningSessionHistory> _miningHistory = [];
  bool _loadingHistory = false;
  
  // Mining streaks and achievements
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalMiningDays = 0;
  double _totalMined = 0.0;
  List<String> _achievements = [];
  
  // Real-time update timer
  Timer? _uiUpdateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseController.repeat(reverse: true);
    
    // Load mining session and history
    _restoreMiningSession();
    _fetchMiningHistory();
    _loadMiningStats();
    
    // Start real-time UI updates
    _startUIUpdates();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _uiUpdateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startUIUpdates() {
    // Update UI every second for real-time mining updates
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // This will trigger a rebuild and show updated mining data
        });
      } else {
        timer.cancel();
      }
    });
  }

  // Ensure mining timer is running when screen is focused
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureMiningTimerIsRunning();
  }

  void _ensureMiningTimerIsRunning() {
    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
    final session = stellarProvider.currentMiningSession;
    
    // Don't automatically start mining timer - user must manually start mining
    // if (session != null && session.isActive && !session.isPaused) {
    //   stellarProvider.startMiningTimer();
    // }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground, restore mining state
      _restoreMiningSession();
      _ensureMiningTimerIsRunning();
    } else if (state == AppLifecycleState.paused) {
      // App going to background, save current mining state
      final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
      final session = stellarProvider.currentMiningSession;
      if (session != null) {
        // Save the current state before app goes to background
        stellarProvider.saveMiningSession(session);
      }
    }
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _notifications.initialize(initSettings);
    tz.initializeTimeZones();
  }

  Future<void> _scheduleMiningEndNotification(DateTime endTime) async {
    await _notifications.zonedSchedule(
      0,
      'Mining Session Complete',
      'Your 24-hour mining session has ended. Start a new session to continue earning Akofa.',
      tz.TZDateTime.from(endTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails('mining_channel', 'Mining', channelDescription: 'Mining session alerts'),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _cancelMiningEndNotification() async {
    await _notifications.cancel(0);
  }

  Future<void> _scheduleMiningReminder(DateTime nextSession) async {
    await _notifications.zonedSchedule(
      1,
      'Start Mining',
      'Your mining session is ready. Tap to start mining Akofa again!',
      tz.TZDateTime.from(nextSession, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails('mining_channel', 'Mining', channelDescription: 'Mining session alerts'),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _cancelMiningReminder() async {
    await _notifications.cancel(1);
  }

  Future<void> _updateMiningNotifications() async {
    // This method is no longer needed as session management is handled by StellarProvider
  }

  Future<void> _saveMiningSession() async {
    // This method is no longer needed as session management is handled by StellarProvider
  }

  Future<void> _saveMiningSessionToFirestore() async {
    // This method is no longer needed as session management is handled by StellarProvider
  }

  Future<void> _restoreMiningSession() async {
    setState(() {
      _loadingSession = true;
    });

    try {
      // Let StellarProvider handle the mining session restoration
      final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
      await stellarProvider.loadMiningSessions();
      
      setState(() {
        _loadingSession = false;
      });
    } catch (e) {
      setState(() {
        _loadingSession = false;
      });
    }
  }

  Future<void> _createNewMiningSession() async {
    // This method is no longer needed as StellarProvider handles session creation
    // Just ensure the provider is loaded
    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
    if (stellarProvider.currentMiningSession == null) {
      await stellarProvider.loadMiningSessions();
    }
  }

  Future<void> _startMining() async {
    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
    
    // Check if mining can be started
    if (!stellarProvider.canStartMining) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot start mining while another session is active'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Start mining using the provider
    final success = await stellarProvider.startMining();
    
    if (success) {
      setState(() {});
      
      // Get the new session for notification scheduling
      final session = stellarProvider.currentMiningSession;
      if (session != null) {
        // Schedule notification for session end
        await _scheduleMiningEndNotification(session.sessionEnd);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mining started successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start mining'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pauseMining() async {
    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
    final session = stellarProvider.currentMiningSession;
    
    if (session != null) {
      session.pauseMining();
      setState(() {});
      
      // Cancel notifications
      await _cancelMiningEndNotification();
      await _cancelMiningReminder();
    }
  }

  Future<void> _resumeMining() async {
    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
    final session = stellarProvider.currentMiningSession;
    
    if (session != null) {
      session.resumeMining();
      // _maybeStartMiningTimer(); // This line is no longer needed
      setState(() {});
      
      // Reschedule notification for session end
      await _scheduleMiningEndNotification(session.sessionEnd);
    }
  }

  // void _maybeStartMiningTimer() { // This method is no longer needed
  //   _miningTimer?.cancel();
  //   if (_session != null && _session!.isActive && !_session!.isPaused) {
  //     _miningTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickMining());
  //   }
  // }

  // void _tickMining() async { // This method is no longer needed
  //   if (_session == null) return;
  //   final now = DateTime.now();
    
  //   // Check if session is paused or expired
  //   if (_session!.isPaused || _session!.isExpired) {
  //     _miningTimer?.cancel();
  //     setState(() {});
  //     return;
  //   }
    
  //   final elapsed = now.difference(_session!.lastResume).inSeconds;
  //   final total = _session!.accumulatedSeconds + elapsed;
    
  //   // Check if session has ended
  //   if (now.isAfter(_session!.sessionEnd)) {
  //     _session!.accumulatedSeconds += _session!.sessionEnd.difference(_session!.lastResume).inSeconds;
  //     _session!.lastResume = _session!.sessionEnd;
  //     _miningTimer?.cancel();
      
  //     print('Mining session ended, triggering reward...');
  //     // Credit mining reward only once when session ends
  //     await _creditMiningReward();
  //   } else {
  //     _session!.accumulatedSeconds = total;
  //     _session!.lastResume = now;
  //   }
    
  //   _saveMiningSession();
  //   setState(() {});
  // }

  // Separate method to credit mining reward
  Future<void> _creditMiningReward() async {
    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
    final session = stellarProvider.currentMiningSession;
    
    if (session == null) return;
    
    final miningRate = session.miningRate ?? 0.0;
    final accumulatedSeconds = session.accumulatedSeconds;
    final earned = miningRate * (accumulatedSeconds / 3600.0);
    
    // Ensure minimum reward for very short sessions
    final finalEarned = earned < 0.001 ? 0.001 : earned;
    
    if (finalEarned <= 0) {
      return;
    }
    
    try {
      // Check if reward was already credited (prevent double crediting)
      final authProvider = Provider.of<local_auth.AuthProvider>(context, listen: false);
      final user = authProvider.user;
      if (user != null) {
        final existingHistory = await FirebaseFirestore.instance
          .collection('mining_history')
          .doc(user.uid)
          .collection('sessions')
          .where('sessionStart', isEqualTo: session.sessionStart.toIso8601String())
          .where('sessionEnd', isEqualTo: session.sessionEnd.toIso8601String())
          .get();
        
        if (existingHistory.docs.isNotEmpty) {
          return;
        }
      }
      
      // Show processing dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.black,
            title: Text(
              'Processing Mining Reward',
              style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Crediting ${finalEarned.toStringAsFixed(6)} ₳ to your wallet...',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }
      
      final success = await stellarProvider.recordMiningReward(finalEarned);
      
      // Close processing dialog
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (success) {
        // Save mining session history
        await _saveMiningSessionHistory(status: 'completed');
        
        if (mounted) {
          // Show success dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.black,
              title: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 32),
                  const SizedBox(width: 12),
                  Text(
                    'Mining Complete!',
                    style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Congratulations! You have successfully mined:',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.monetization_on, color: AppTheme.primaryGold, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          '${finalEarned.toStringAsFixed(6)} ₳',
                          style: AppTheme.headingMedium.copyWith(
                            color: AppTheme.primaryGold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your mining reward has been credited to your wallet. You can view it in your transaction history.',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close', style: TextStyle(color: AppTheme.primaryGold)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Navigate to transaction history
                    Navigator.of(context).pushNamed('/transactions');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    foregroundColor: AppTheme.black,
                  ),
                  child: const Text('View Transactions'),
                ),
              ],
            ),
          );
        }
        
        await _fetchMiningHistory();
        
        // After a mining session completes, call reconcileUncreditedMiningSessions for the current user
        final authProvider = Provider.of<local_auth.AuthProvider>(context, listen: false);
        final user = authProvider.user;
        if (user != null) {
          await stellarProvider.reconcileUncreditedMiningSessions(user.uid);
        }
      } else {
        // Save as failed
        await _saveMiningSessionHistory(status: 'failed');
        throw Exception('Failed to record mining reward');
      }
    } catch (e) {
      // Close processing dialog if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (mounted) {
        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.black,
            title: Row(
              children: [
                const Icon(Icons.error, color: Colors.red, size: 32),
                const SizedBox(width: 12),
                Text(
                  'Mining Error',
                  style: AppTheme.headingMedium.copyWith(color: Colors.red),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Failed to credit mining reward:',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                ),
                const SizedBox(height: 12),
                Text(
                  'Don\'t worry! Your mining session has been recorded and will be processed later.',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK', style: TextStyle(color: AppTheme.primaryGold)),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _saveMiningSessionHistory({String? transactionId, String? stellarHash, String? status}) async {
    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
    final session = stellarProvider.currentMiningSession;
    
    if (session == null) return;
    
    final authProvider = Provider.of<local_auth.AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;
    
    final miningRate = session.miningRate ?? 0.0;
    final earned = miningRate * ((session.accumulatedSeconds) / 3600.0);
    
    final history = MiningSessionHistory(
      id: '',
      userId: user.uid,
      sessionStart: session.sessionStart,
      sessionEnd: session.sessionEnd,
      earnedAkofa: earned,
      status: status ?? 'completed',
      transactionId: transactionId,
      stellarHash: stellarHash,
    );
    await FirebaseFirestore.instance
      .collection('mining_history')
      .doc(user.uid)
      .collection('sessions')
      .add(history.toFirestore());
  }

  Future<void> _fetchMiningHistory() async {
    setState(() => _loadingHistory = true);
    final authProvider = Provider.of<local_auth.AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;
    final query = await FirebaseFirestore.instance
      .collection('mining_history')
      .doc(user.uid)
      .collection('sessions')
      .orderBy('sessionEnd', descending: true)
      .limit(50)
      .get();
    _miningHistory = query.docs.map((doc) => MiningSessionHistory.fromFirestore(doc.id, doc.data())).toList();
    setState(() => _loadingHistory = false);
    
    // Calculate mining stats after fetching history
    _calculateMiningStats();
  }

  // Load mining statistics from local storage
  Future<void> _loadMiningStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentStreak = prefs.getInt('mining_current_streak') ?? 0;
      _longestStreak = prefs.getInt('mining_longest_streak') ?? 0;
      _totalMiningDays = prefs.getInt('mining_total_days') ?? 0;
      _totalMined = prefs.getDouble('mining_total_mined') ?? 0.0;
      _achievements = prefs.getStringList('mining_achievements') ?? [];
      setState(() {});
    } catch (e) {
    }
  }

  // Save mining statistics to local storage
  Future<void> _saveMiningStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('mining_current_streak', _currentStreak);
      await prefs.setInt('mining_longest_streak', _longestStreak);
      await prefs.setInt('mining_total_days', _totalMiningDays);
      await prefs.setDouble('mining_total_mined', _totalMined);
      await prefs.setStringList('mining_achievements', _achievements);
    } catch (e) {
    }
  }

  // Calculate mining statistics from history
  void _calculateMiningStats() {
    if (_miningHistory.isEmpty) return;
    
    // Calculate total mined
    _totalMined = _miningHistory.fold<double>(0.0, (sum, session) => sum + session.earnedAkofa);
    
    // Calculate streaks
    _calculateStreaks();
    
    // Calculate achievements
    _calculateAchievements();
    
    // Save stats
    _saveMiningStats();
    setState(() {});
  }

  // Calculate mining streaks
  void _calculateStreaks() {
    if (_miningHistory.isEmpty) return;
    
    // Sort by session end date (most recent first)
    final sortedHistory = List<MiningSessionHistory>.from(_miningHistory)
      ..sort((a, b) => b.sessionEnd.compareTo(a.sessionEnd));
    
    int currentStreak = 0;
    int longestStreak = 0;
    int totalDays = 0;
    
    DateTime? lastMiningDay;
    
    for (final session in sortedHistory) {
      final sessionDay = DateTime(session.sessionEnd.year, session.sessionEnd.month, session.sessionEnd.day);
      
      if (lastMiningDay == null) {
        // First mining day
        currentStreak = 1;
        totalDays = 1;
        lastMiningDay = sessionDay;
      } else {
        final daysDifference = lastMiningDay.difference(sessionDay).inDays;
        
        if (daysDifference == 1) {
          // Consecutive day
          currentStreak++;
          totalDays++;
          lastMiningDay = sessionDay;
        } else if (daysDifference == 0) {
          // Same day, don't count again
          continue;
        } else {
          // Break in streak
          if (currentStreak > longestStreak) {
            longestStreak = currentStreak;
          }
          currentStreak = 1;
          totalDays++;
          lastMiningDay = sessionDay;
        }
      }
    }
    
    // Check if current streak is the longest
    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
    }
    
    _currentStreak = currentStreak;
    _longestStreak = longestStreak;
    _totalMiningDays = totalDays;
  }

  // Calculate achievements
  void _calculateAchievements() {
    final newAchievements = <String>[];
    
    // First mining session
    if (_totalMiningDays >= 1 && !_achievements.contains('first_miner')) {
      newAchievements.add('first_miner');
    }
    
    // 7-day streak
    if (_currentStreak >= 7 && !_achievements.contains('week_warrior')) {
      newAchievements.add('week_warrior');
    }
    
    // 30-day streak
    if (_currentStreak >= 30 && !_achievements.contains('month_master')) {
      newAchievements.add('month_master');
    }
    
    // 100-day streak
    if (_currentStreak >= 100 && !_achievements.contains('century_club')) {
      newAchievements.add('century_club');
    }
    
    // Total mined milestones
    if (_totalMined >= 1.0 && !_achievements.contains('first_akofa')) {
      newAchievements.add('first_akofa');
    }
    
    if (_totalMined >= 10.0 && !_achievements.contains('akofa_collector')) {
      newAchievements.add('akofa_collector');
    }
    
    if (_totalMined >= 100.0 && !_achievements.contains('akofa_master')) {
      newAchievements.add('akofa_master');
    }
    
    // Add new achievements
    if (newAchievements.isNotEmpty) {
      _achievements.addAll(newAchievements);
      _showAchievementNotification(newAchievements);
    }
  }

  // Show achievement notification
  void _showAchievementNotification(List<String> achievements) {
    if (achievements.isEmpty) return;
    
    final achievementNames = {
      'first_miner': 'First Miner',
      'week_warrior': 'Week Warrior',
      'month_master': 'Month Master',
      'century_club': 'Century Club',
      'first_akofa': 'First AKOFA',
      'akofa_collector': 'AKOFA Collector',
      'akofa_master': 'AKOFA Master',
    };
    
    final achievementDescriptions = {
      'first_miner': 'Completed your first mining session!',
      'week_warrior': 'Mined for 7 consecutive days!',
      'month_master': 'Mined for 30 consecutive days!',
      'century_club': 'Mined for 100 consecutive days!',
      'first_akofa': 'Earned your first AKOFA coin!',
      'akofa_collector': 'Earned 10 AKOFA coins!',
      'akofa_master': 'Earned 100 AKOFA coins!',
    };
    
    for (final achievement in achievements) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.emoji_events, color: AppTheme.primaryGold),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Achievement Unlocked!',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.primaryGold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${achievementNames[achievement]}: ${achievementDescriptions[achievement]}',
                        style: AppTheme.bodySmall.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.black,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // Show mining session summary
  void _showMiningSessionSummary() {
    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
    final session = stellarProvider.currentMiningSession;
    
    if (session == null) return;
    
    final miningRate = session.miningRate ?? 0.0;
    final earned = miningRate * ((session.accumulatedSeconds) / 3600.0);
    final sessionDuration = session.sessionEnd.difference(session.sessionStart);
    final minedDuration = Duration(seconds: session.accumulatedSeconds);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.black,
        title: Row(
          children: [
            const Icon(Icons.analytics, color: AppTheme.primaryGold, size: 28),
            const SizedBox(width: 12),
            Text(
              'Session Summary',
              style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryItem('Session Duration', _formatDuration(sessionDuration)),
            _buildSummaryItem('Time Mined', _formatDuration(minedDuration)),
            _buildSummaryItem('Mining Rate', '${miningRate.toStringAsFixed(2)} ₳/hour'),
            _buildSummaryItem('Earnings', '${earned.toStringAsFixed(6)} ₳'),
            _buildSummaryItem('Session Status', session.isExpired ? 'Completed' : session.isPaused ? 'Paused' : 'Active'),
            if (session.isExpired)
              _buildSummaryItem('Next Session', 'Ready to start'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close', style: TextStyle(color: AppTheme.primaryGold)),
          ),
          if (session.isExpired)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _restoreMiningSession();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.black,
              ),
              child: const Text('Start New Session'),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
          ),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<local_auth.AuthProvider>(context);
    final stellarProvider = Provider.of<StellarProvider>(context);
    
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
              children: [
                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ResponsiveContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: ResponsiveLayoutBuilder(
                        // Mobile layout (stacked)
                        mobileBuilder: (context, constraints) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            _buildMiningAnalytics(),
                            const SizedBox(height: 24),
                            _buildMiningSection(),
                            const SizedBox(height: 24),
                            _buildMiningHistorySection(),
                            const SizedBox(height: 40),
                          ],
                        ),
                        // Tablet layout (2 columns)
                        tabletBuilder: (context, constraints) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            _buildMiningAnalytics(),
                            const SizedBox(height: 24),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildMiningSection(),
                                      const SizedBox(height: 24),
                                      _buildMiningHistorySection(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                        // Desktop layout (3 columns)
                        desktopBuilder: (context, constraints) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            _buildMiningAnalytics(),
                            const SizedBox(height: 24),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildMiningSection(),
                                      const SizedBox(height: 24),
                                      _buildMiningHistorySection(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiningAnalytics() {
    if (_miningHistory.isEmpty) {
      return Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: AppTheme.darkGrey.withOpacity(0.7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            children: [
              Icon(
                Icons.auto_graph,
                color: AppTheme.grey,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'No Mining History Yet',
                style: AppTheme.headingSmall.copyWith(color: AppTheme.grey),
              ),
              const SizedBox(height: 8),
              Text(
                'Start mining to see your statistics and achievements!',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    final bestDay = _miningHistory.fold<double>(0.0, (max, s) => s.earnedAkofa > max ? s.earnedAkofa : max);
    
    return Column(
      children: [
        // Main analytics card
        Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          color: AppTheme.darkGrey.withOpacity(0.7),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAnalyticsItem(
                  icon: Icons.auto_graph,
                  label: 'Total Mined',
                  value: '${_totalMined.toStringAsFixed(4)} ₳',
                  color: AppTheme.primaryGold,
                ),
                _buildAnalyticsItem(
                  icon: Icons.local_fire_department,
                  label: 'Current Streak',
                  value: '$_currentStreak days',
                  color: Colors.orangeAccent,
                ),
                _buildAnalyticsItem(
                  icon: Icons.star,
                  label: 'Best Day',
                  value: '${bestDay.toStringAsFixed(4)} ₳',
                  color: Colors.amber,
                ),
              ],
            ),
          ),
        ),
        
        // Additional stats card
        Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          color: AppTheme.darkGrey.withOpacity(0.7),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAnalyticsItem(
                  icon: Icons.calendar_today,
                  label: 'Total Days',
                  value: '$_totalMiningDays',
                  color: Colors.blue,
                ),
                _buildAnalyticsItem(
                  icon: Icons.emoji_events,
                  label: 'Longest Streak',
                  value: '$_longestStreak days',
                  color: Colors.purple,
                ),
                _buildAnalyticsItem(
                  icon: Icons.workspace_premium,
                  label: 'Achievements',
                  value: '${_achievements.length}',
                  color: Colors.green,
                ),
              ],
            ),
          ),
        ),
        
        // Achievements card
        if (_achievements.isNotEmpty)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            color: AppTheme.darkGrey.withOpacity(0.7),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.emoji_events, color: AppTheme.primaryGold, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Achievements',
                        style: AppTheme.headingSmall.copyWith(
                          color: AppTheme.primaryGold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _achievements.map((achievement) {
                      final achievementNames = {
                        'first_miner': 'First Miner',
                        'week_warrior': 'Week Warrior',
                        'month_master': 'Month Master',
                        'century_club': 'Century Club',
                        'first_akofa': 'First AKOFA',
                        'akofa_collector': 'AKOFA Collector',
                        'akofa_master': 'AKOFA Master',
                      };
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGold.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
                        ),
                        child: Text(
                          achievementNames[achievement] ?? achievement,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.primaryGold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAnalyticsItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
        ),
        Text(
          value,
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMiningSection() {
    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
    final session = stellarProvider.currentMiningSession;
    
    if (stellarProvider.isLoadingMiningSessions) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // If no session exists, show the start mining UI
    if (session == null) {
      return Card(
        color: AppTheme.darkGrey.withOpacity(0.7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Mining', style: AppTheme.headingSmall.copyWith(color: AppTheme.white, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Ready to Start',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Start Mining Prompt
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryGold.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.play_circle_outline,
                      size: 64,
                      color: AppTheme.primaryGold,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ready to Start Mining?',
                      style: AppTheme.headingMedium.copyWith(
                        color: AppTheme.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Click the button below to begin your 24-hour mining session and start earning Akofa tokens!',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _startMining,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGold,
                        foregroundColor: AppTheme.black,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      child: const Text(
                        'Start Mining',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Session exists - show normal mining UI
    final progress = stellarProvider.miningProgress;
    final earnedValue = stellarProvider.currentMiningEarnings;
    final timeRemaining = stellarProvider.formattedTimeRemaining;
    final sessionExpired = session.isExpired;

    return Card(
      color: AppTheme.darkGrey.withOpacity(0.7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mining', style: AppTheme.headingSmall.copyWith(color: AppTheme.white, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: session.isActive ? AppTheme.primaryGold : AppTheme.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    sessionExpired ? 'Session Ended' : session.isPaused ? 'Paused' : 'Active',
                    style: AppTheme.bodySmall.copyWith(
                      color: session.isActive ? AppTheme.black : AppTheme.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Countdown Timer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryGold.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Time Remaining',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (session.isActive && !session.isPaused) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: AppTheme.bodySmall.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeRemaining,
                    style: AppTheme.headingLarge.copyWith(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Monospace',
                      fontSize: 32,
                    ),
                  ),
                  Text(
                    '24-Hour Session',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.grey,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}%',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress.clamp(0, 1),
                  minHeight: 12,
                  backgroundColor: AppTheme.grey.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Earnings Display
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.darkGrey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryGold.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Current Earnings',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (session.isActive && !session.isPaused) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'UPDATING',
                          style: AppTheme.bodySmall.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${earnedValue.toStringAsFixed(6)} ₳',
                    style: AppTheme.headingLarge.copyWith(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Rate: ${session.miningRate.toStringAsFixed(2)} ₳/hour',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Show different buttons based on session state
                if (session != null && session.isActive && !session.isExpired) ...[
                  // Active session - show pause/resume
                  ElevatedButton(
                    onPressed: session.isPaused ? _resumeMining : _pauseMining,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: session.isPaused ? AppTheme.primaryGold : Colors.orange,
                      foregroundColor: session.isPaused ? AppTheme.black : AppTheme.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(session.isPaused ? 'Resume' : 'Pause'),
                  ),
                ] else if (stellarProvider.canStartMining) ...[
                  // No active session - show start mining
                  ElevatedButton(
                    onPressed: _startMining,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: AppTheme.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Start Mining'),
                  ),
                ] else ...[
                  // Session exists but can't start new one - show disabled button
                  ElevatedButton(
                    onPressed: null, // Disabled
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.grey.withOpacity(0.3),
                      foregroundColor: AppTheme.grey,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Session Active'),
                  ),
                ],
                ElevatedButton(
                  onPressed: _showMiningSessionSummary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: AppTheme.primaryGold,
                    side: const BorderSide(color: AppTheme.primaryGold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Summary'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Check for uncredited sessions button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
                  await stellarProvider.checkAndProcessUncreditedSessions();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Checking for uncredited mining sessions...'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Check for Uncredited Sessions'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryGold,
                  side: BorderSide(color: AppTheme.primaryGold),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Force complete mining session button (for testing)
            if (session != null && session.isActive && !session.isExpired)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
                    await stellarProvider.forceCompleteMiningSession();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Forcing completion of mining session...'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                  icon: const Icon(Icons.timer_off),
                  label: const Text('Force Complete Session (Test)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            
            const SizedBox(height: 8),
            
            // Debug mining sessions button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
                  final debugInfo = stellarProvider.getMiningSessionsDebugInfo();
                  
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppTheme.black,
                      title: Text(
                        'Mining Sessions Debug Info',
                        style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
                      ),
                      content: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: debugInfo.entries.map((entry) {
                            if (entry.key.startsWith('session_')) {
                              final sessionData = entry.value as Map<String, dynamic>;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Session ${entry.key.split('_')[1]}',
                                    style: AppTheme.bodyLarge.copyWith(
                                      color: AppTheme.primaryGold,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  ...sessionData.entries.map((sessionEntry) => Text(
                                    '  ${sessionEntry.key}: ${sessionEntry.value}',
                                    style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                                  )),
                                  const SizedBox(height: 8),
                                ],
                              );
                            } else {
                              return Text(
                                '${entry.key}: ${entry.value}',
                                style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
                              );
                            }
                          }).toList(),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Close', style: TextStyle(color: AppTheme.primaryGold)),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.bug_report),
                label: const Text('Debug Mining Sessions'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple,
                  side: BorderSide(color: Colors.purple),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Check account funding status button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
                  final fundingInfo = await stellarProvider.getAccountFundingInfo();
                  
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppTheme.black,
                      title: Text(
                        'Account Funding Status',
                        style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
                      ),
                      content: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: fundingInfo['status'] == 'active' 
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: fundingInfo['status'] == 'active' 
                                    ? Colors.green 
                                    : Colors.orange,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    fundingInfo['status'] == 'active' 
                                      ? Icons.check_circle 
                                      : Icons.warning,
                                    color: fundingInfo['status'] == 'active' 
                                      ? Colors.green 
                                      : Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      fundingInfo['message'] ?? 'Unknown status',
                                      style: AppTheme.bodyMedium.copyWith(
                                        color: AppTheme.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            if (fundingInfo['publicKey'] != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Public Key:',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.primaryGold,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkGrey.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: SelectableText(
                                  fundingInfo['publicKey'],
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.grey,
                                    fontFamily: 'Monospace',
                                  ),
                                ),
                              ),
                            ],
                            
                            if (fundingInfo['fundingInstructions'] != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Funding Instructions:',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.primaryGold,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...(fundingInfo['fundingInstructions'] as List<String>).map((instruction) => 
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('• ', style: TextStyle(color: AppTheme.primaryGold)),
                                      Expanded(
                                        child: Text(
                                          instruction,
                                          style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            
                            if (fundingInfo['testnetFaucet'] != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Testnet Faucet:',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.primaryGold,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () {
                                  // You can implement URL launching here
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Copy this URL: ${fundingInfo['testnetFaucet']}'),
                                      action: SnackBarAction(
                                        label: 'Copy',
                                        onPressed: () {
                                          // Copy to clipboard
                                        },
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  fundingInfo['testnetFaucet'],
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.primaryGold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Close', style: TextStyle(color: AppTheme.primaryGold)),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.account_balance_wallet),
                label: const Text('Check Account Funding'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: BorderSide(color: Colors.blue),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}' ;
  }

  Widget _buildMiningHistorySection() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_miningHistory.isEmpty) {
      return Center(
        child: Text(
          'No mining history yet. Start mining to earn Akofa! ✨',
          style: AppTheme.bodyLarge.copyWith(color: AppTheme.grey),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mining History',
          style: AppTheme.headingMedium.copyWith(
            color: AppTheme.primaryGold,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _miningHistory.length,
          itemBuilder: (context, index) {
            final session = _miningHistory[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryGold.withOpacity(0.15),
                    AppTheme.secondaryGold.withOpacity(0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGold.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: AppTheme.primaryGold.withOpacity(0.18),
                  width: 1.2,
                ),
                // Glassmorphism effect
                backgroundBlendMode: BlendMode.overlay,
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryGold.withOpacity(0.15),
                  child: const Icon(Icons.flash_on, color: AppTheme.primaryGold),
                ),
                title: Row(
                  children: [
                    Text(
                      '+${session.earnedAkofa.toStringAsFixed(6)} ₳',
                      style: AppTheme.headingSmall.copyWith(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: session.status == 'completed'
                            ? Colors.green.withOpacity(0.15)
                            : Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        session.status.capitalize(),
                        style: AppTheme.bodySmall.copyWith(
                          color: session.status == 'completed' ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      'Start: ${session.sessionStart.toLocal().toString().substring(0, 19)}',
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                    ),
                    Text(
                      'End:   ${session.sessionEnd.toLocal().toString().substring(0, 19)}',
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                    ),
                    if (session.stellarHash != null && session.stellarHash!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: GestureDetector(
                          onTap: () {
                            final url = 'https://stellar.expert/explorer/testnet/tx/${session.stellarHash}';
                            // Use url_launcher to open
                            // launchUrl(Uri.parse(url));
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.open_in_new, size: 16, color: AppTheme.primaryGold),
                              const SizedBox(width: 4),
                              Text(
                                'View on Stellar',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.primaryGold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified, color: AppTheme.primaryGold, size: 20),
                    Text(
                      session.id.substring(0, 6),
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 600.ms, delay: (index * 80).ms).slideX(begin: 0.1, end: 0);
          },
        ),
      ],
    );
  }
}

extension StringCasingExtension on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}