import 'dart:async';
import 'dart:math' as math;
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
import '../widgets/animated_logo.dart';
import '../widgets/app_logo.dart';
import '../widgets/custom_button.dart';
import '../models/mining_session.dart';
import '../providers/stellar_provider.dart';

class PiHomeScreen extends StatefulWidget {
  const PiHomeScreen({Key? key}) : super(key: key);

  @override
  State<PiHomeScreen> createState() => _PiHomeScreenState();
}

class _PiHomeScreenState extends State<PiHomeScreen> with SingleTickerProviderStateMixin {
  Timer? _miningTimer;
  late AnimationController _pulseController;
  MiningSession? _session;
  bool _loadingSession = true;
  final List<Transaction> _recentTransactions = [
    Transaction(
      id: '1',
      title: 'Received from John',
      amount: 5.0,
      date: DateTime.now().subtract(const Duration(days: 1)),
      isIncoming: true,
    ),
    Transaction(
      id: '2',
      title: 'Sent to Market',
      amount: 2.5,
      date: DateTime.now().subtract(const Duration(days: 3)),
      isIncoming: false,
    ),
    Transaction(
      id: '3',
      title: 'Received from Mining',
      amount: 1.2,
      date: DateTime.now().subtract(const Duration(days: 5)),
      isIncoming: true,
    ),
  ];
  
  final List<String> _announcements = [
    'Welcome to the new AZIX Network interface!',
    'Mining rate has been updated to 0.25 ₳/hour',
    'New marketplace features coming soon',
    'Invite friends to earn bonus ₳',
  ];

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  List<MiningSessionHistory> _miningHistory = [];
  bool _loadingHistory = false;
  
  // Mining streaks and achievements
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalMiningDays = 0;
  double _totalMined = 0.0;
  List<String> _achievements = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseController.repeat(reverse: true);
    
    // Load mining session and history
    _restoreMiningSession();
    _fetchMiningHistory();
    _loadMiningStats();
  }

  @override
  void dispose() {
    _miningTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
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
    if (_session == null) return;
    await _cancelMiningEndNotification();
    await _cancelMiningReminder();
    if (_session!.isActive && !_session!.isPaused) {
      await _scheduleMiningEndNotification(_session!.sessionEnd);
    } else if (_session!.isExpired) {
      await _scheduleMiningReminder(DateTime.now().add(const Duration(seconds: 2)));
    }
  }

  Future<void> _saveMiningSession() async {
    if (_session == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mining_session', _session!.toRawJson());
    await _saveMiningSessionToFirestore();
  }

  Future<void> _saveMiningSessionToFirestore() async {
    if (_session == null) return;
    final authProvider = Provider.of<local_auth.AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;
    final sessionData = _session!.toJsonForFirestore(user.uid);
    await FirebaseFirestore.instance.collection('mining_sessions').doc(user.uid).set(sessionData, SetOptions(merge: true));
  }

  Future<void> _restoreMiningSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('mining_session');
      MiningSession? session;
      
      if (raw != null) {
        try {
          session = MiningSession.fromRawJson(raw);
          // Check if session is still valid
          if (session.sessionEnd.isAfter(DateTime.now())) {
            // Session is still valid, but don't start automatically
            _session = session;
            setState(() {
              _loadingSession = false;
            });
            return;
          } else {
            // Session expired, create new one but don't start
            session = MiningSession.newSession(miningRate: session.miningRate);
            await prefs.setString('mining_session', session.toRawJson());
          }
        } catch (e) {
          print('Error parsing mining session: $e');
        }
      }
      
      // Try to restore from Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final doc = await FirebaseFirestore.instance.collection('mining_sessions').doc(user.uid).get();
          if (doc.exists) {
            final data = doc.data()!;
            session = MiningSession.fromFirestore(data);
            if (session.sessionEnd.isAfter(DateTime.now())) {
              // Session is still valid, but don't start automatically
              _session = session;
              await prefs.setString('mining_session', session.toRawJson());
              setState(() {
                _loadingSession = false;
              });
              return;
            } else {
              // Session expired, create new one but don't start
              session = MiningSession.newSession(miningRate: session.miningRate);
              await prefs.setString('mining_session', session.toRawJson());
            }
          }
        } catch (e) {
          print('Error restoring from Firestore: $e');
        }
      }
      
      // Create new session if none exists
      session ??= MiningSession.newSession(miningRate: 0.25); // Default rate
      await prefs.setString('mining_session', session.toRawJson());
      _session = session;
      setState(() {
        _loadingSession = false;
      });
      
      // Don't start mining automatically - user must click start
    } catch (e) {
      print('Error restoring mining session: $e');
      setState(() {
        _loadingSession = false;
      });
    }
  }

  // Start mining manually
  Future<void> _startMining() async {
    if (_session == null) return;
    
    try {
      _session!.startMining();
      await _saveMiningSession();
      _maybeStartMiningTimer();
      setState(() {});
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mining started! 🚀'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error starting mining: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start mining: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Pause mining
  Future<void> _pauseMining() async {
    if (_session == null) return;
    
    try {
      _session!.pauseMining();
      await _saveMiningSession();
      setState(() {});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mining paused'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error pausing mining: $e');
    }
  }

  // Resume mining
  Future<void> _resumeMining() async {
    if (_session == null) return;
    
    try {
      _session!.resumeMining();
      await _saveMiningSession();
      _maybeStartMiningTimer();
      setState(() {});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mining resumed! 🚀'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error resuming mining: $e');
    }
  }

  void _maybeStartMiningTimer() {
    _miningTimer?.cancel();
    if (_session != null && _session!.isActive && !_session!.isPaused) {
      _miningTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickMining());
    }
  }

  void _tickMining() async {
    if (_session == null) return;
    final now = DateTime.now();
    
    // Check if session is paused or expired
    if (_session!.isPaused || _session!.isExpired) {
      _miningTimer?.cancel();
      setState(() {});
      return;
    }
    
    final elapsed = now.difference(_session!.lastResume).inSeconds;
    final total = _session!.accumulatedSeconds + elapsed;
    
    // Check if session has ended
    if (now.isAfter(_session!.sessionEnd)) {
      _session!.accumulatedSeconds += _session!.sessionEnd.difference(_session!.lastResume).inSeconds;
      _session!.lastResume = _session!.sessionEnd;
      _miningTimer?.cancel();
      
      print('Mining session ended, triggering reward...');
      // Credit mining reward only once when session ends
      await _creditMiningReward();
    } else {
      _session!.accumulatedSeconds = total;
      _session!.lastResume = now;
    }
    
    _saveMiningSession();
    setState(() {});
  }

  // Separate method to credit mining reward
  Future<void> _creditMiningReward() async {
    if (_session == null) return;
    
    final miningRate = _session?.miningRate ?? 0.0;
    final accumulatedSeconds = _session?.accumulatedSeconds ?? 0;
    final earned = miningRate * (accumulatedSeconds / 3600.0);
    
    // Ensure minimum reward for very short sessions
    final finalEarned = earned < 0.001 ? 0.001 : earned;
    
    if (finalEarned <= 0) {
      print('Warning: Final earned amount is 0 or negative, skipping reward');
      return;
    }
    
    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
    
    try {
      // Check if reward was already credited (prevent double crediting)
      final authProvider = Provider.of<local_auth.AuthProvider>(context, listen: false);
      final user = authProvider.user;
      if (user != null) {
        final existingHistory = await FirebaseFirestore.instance
          .collection('mining_history')
          .doc(user.uid)
          .collection('sessions')
          .where('sessionStart', isEqualTo: _session!.sessionStart.toIso8601String())
          .where('sessionEnd', isEqualTo: _session!.sessionEnd.toIso8601String())
          .get();
        
        if (existingHistory.docs.isNotEmpty) {
          print('Mining reward already credited for this session');
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
      
      print('Error crediting mining reward: $e');
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
    if (_session == null) return;
    final authProvider = Provider.of<local_auth.AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;
    final miningRate = _session?.miningRate ?? 0.0;
    final earned = miningRate * ((_session?.accumulatedSeconds ?? 0) / 3600.0);
    final history = MiningSessionHistory(
      id: '',
      userId: user.uid,
      sessionStart: _session!.sessionStart,
      sessionEnd: _session!.sessionEnd,
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
      print('Error loading mining stats: $e');
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
      print('Error saving mining stats: $e');
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
    if (_session == null) return;
    
    final miningRate = _session?.miningRate ?? 0.0;
    final earned = miningRate * ((_session?.accumulatedSeconds ?? 0) / 3600.0);
    final sessionDuration = _session!.sessionEnd.difference(_session!.sessionStart);
    final minedDuration = Duration(seconds: _session!.accumulatedSeconds);
    
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
            _buildSummaryItem('Session Status', _session!.isExpired ? 'Completed' : _session!.isPaused ? 'Paused' : 'Active'),
            if (_session!.isExpired)
              _buildSummaryItem('Next Session', 'Ready to start'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close', style: TextStyle(color: AppTheme.primaryGold)),
          ),
          if (_session!.isExpired)
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
    final user = authProvider.user;
    final screenSize = MediaQuery.of(context).size;
    
    return Container(
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

  Widget _buildAnalyticsItem({required IconData icon, required String label, required String value, required Color color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.13),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: AppTheme.headingSmall.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
        ),
      ],
    );
  }

  Widget _buildMiningSection() {
    if (_loadingSession || _session == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final now = DateTime.now();
    final session = _session!;
    final totalSessionSeconds = session.sessionEnd.difference(session.sessionStart).inSeconds;
    int minedSeconds = session.accumulatedSeconds;
    if (!session.isPaused && now.isBefore(session.sessionEnd)) {
      minedSeconds += now.difference(session.lastResume).inSeconds;
    } else if (now.isAfter(session.sessionEnd)) {
      minedSeconds = totalSessionSeconds;
    }
    final progress = minedSeconds / totalSessionSeconds;
    final miningRate = session.miningRate ?? 0.0;
    final earnedValue = miningRate * ((minedSeconds.toDouble()) / 3600.0);
    final timeLeft = session.sessionEnd.difference(now);
    final sessionExpired = now.isAfter(session.sessionEnd);

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
            LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 10,
              backgroundColor: AppTheme.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
            ),
            const SizedBox(height: 16),
            Text(
              'Earnings: ${earnedValue.toStringAsFixed(6)} ₳',
              style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              sessionExpired
                  ? 'Session complete. Start a new session to continue mining.'
                  : session.isPaused
                      ? 'Mining paused. Resume to continue.'
                      : 'Mining rate: ${session.miningRate} ₳/hour',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
            ),
            const SizedBox(height: 8),
            if (!sessionExpired)
              Text(
                session.isPaused
                    ? 'Time left: ${_formatDuration(session.sessionEnd.difference(session.pausedAt ?? now))}'
                    : 'Time left: ${_formatDuration(timeLeft)}',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
              ),
            const SizedBox(height: 24),
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: session.isActive ? AppTheme.darkGrey : Colors.transparent,
                  border: Border.all(
                    color: session.isActive ? AppTheme.primaryGold : AppTheme.grey,
                    width: 3,
                  ),
                  boxShadow: session.isActive
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryGold.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: session.isActive && !session.isPaused
                            ? 1.0 + (_pulseController.value * 0.1)
                            : 1.0,
                        child: Icon(
                          session.isActive && !session.isPaused ? Icons.flash_on : Icons.flash_on_outlined,
                          color: session.isActive ? AppTheme.primaryGold : AppTheme.grey,
                          size: 60,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (sessionExpired)
                      ElevatedButton.icon(
                        onPressed: _restoreMiningSession,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Start New Session'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold,
                          foregroundColor: AppTheme.black,
                          minimumSize: const Size(140, 48),
                          textStyle: AppTheme.headingSmall,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      )
                    else if (!session.isActive && !session.isPaused)
                      ElevatedButton.icon(
                        onPressed: _startMining,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Mining'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold,
                          foregroundColor: AppTheme.black,
                          minimumSize: const Size(140, 48),
                          textStyle: AppTheme.headingSmall,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      )
                    else if (session.isPaused)
                      ElevatedButton.icon(
                        onPressed: _resumeMining,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Resume'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold,
                          foregroundColor: AppTheme.black,
                          minimumSize: const Size(140, 48),
                          textStyle: AppTheme.headingSmall,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _pauseMining,
                        icon: const Icon(Icons.pause),
                        label: const Text('Pause'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold,
                          foregroundColor: AppTheme.black,
                          minimumSize: const Size(140, 48),
                          textStyle: AppTheme.headingSmall,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Session summary button
                ElevatedButton.icon(
                  onPressed: _showMiningSessionSummary,
                  icon: const Icon(Icons.analytics),
                  label: const Text('Session Summary'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(140, 40),
                    textStyle: AppTheme.bodyMedium,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
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

class Transaction {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final bool isIncoming;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.isIncoming,
  });
}

extension StringCasingExtension on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}