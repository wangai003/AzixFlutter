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

import '../providers/auth_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initNotifications();
    _restoreMiningSession();
    _fetchMiningHistory();
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;
    final sessionData = _session!.toJsonForFirestore(user.uid);
    await FirebaseFirestore.instance.collection('mining_sessions').doc(user.uid).set(sessionData, SetOptions(merge: true));
  }

  Future<void> _restoreMiningSession() async {
    setState(() => _loadingSession = true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('mining_session');
    MiningSession? session;
    if (raw != null) {
      session = MiningSession.fromRawJson(raw);
      // If session expired, start a new one
      if (session.isExpired) {
        session = MiningSession.newSession(miningRate: session.miningRate);
        await prefs.setString('mining_session', session.toRawJson());
      }
    } else {
      // Try to restore from Firestore
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('mining_sessions').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          session = MiningSession.fromFirestore(data);
          if (session.isExpired) {
            session = MiningSession.newSession(miningRate: session.miningRate);
          }
          await prefs.setString('mining_session', session.toRawJson());
        }
      }
      session ??= MiningSession.newSession(miningRate: 0.25); // Default rate
      await prefs.setString('mining_session', session.toRawJson());
    }
    _session = session;
    setState(() => _loadingSession = false);
    _maybeStartMiningTimer();
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
    if (_session!.isPaused || _session!.isExpired) {
      _miningTimer?.cancel();
      setState(() {});
      // If session just expired, credit mining reward
      if (_session!.isExpired && !_session!.isPaused && !_session!.accumulatedSeconds.isNaN && _session!.accumulatedSeconds > 0) {
        final miningRate = _session?.miningRate ?? 0.0;
        final earned = miningRate * (_session?.accumulatedSeconds ?? 0 / 3600.0);
        if (earned > 0) {
          final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
          try {
            final success = await stellarProvider.recordMiningReward(earned);
            // Save mining session history
            await _saveMiningSessionHistory();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Mining reward of $earned ₳ credited to your wallet!')),
              );
            }
            await _fetchMiningHistory();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to credit mining reward: $e')),
              );
            }
          }
        }
      }
      return;
    }
    final elapsed = now.difference(_session!.lastResume).inSeconds;
    final total = _session!.accumulatedSeconds + elapsed;
    if (now.isAfter(_session!.sessionEnd)) {
      _session!.accumulatedSeconds += _session!.sessionEnd.difference(_session!.lastResume).inSeconds;
      _session!.lastResume = _session!.sessionEnd;
      _miningTimer?.cancel();
      // Session ended, credit mining reward
      final miningRate = _session?.miningRate ?? 0.0;
      final earned = miningRate * ((_session?.accumulatedSeconds ?? 0) / 3600.0);
      if (earned > 0) {
        final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
        try {
          final success = await stellarProvider.recordMiningReward(earned);
          // Save mining session history
          await _saveMiningSessionHistory();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Mining reward of $earned ₳ credited to your wallet!')),
            );
          }
          await _fetchMiningHistory();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to credit mining reward: $e')),
            );
          }
        }
      }
    } else {
      _session!.accumulatedSeconds = total;
      _session!.lastResume = now;
    }
    _saveMiningSession();
    setState(() {});
  }

  Future<void> _saveMiningSessionHistory({String? transactionId, String? stellarHash}) async {
    if (_session == null) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
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
      status: 'completed',
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
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
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
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
      return const SizedBox.shrink();
    }
    final totalMined = _miningHistory.fold<double>(0.0, (sum, s) => sum + s.earnedAkofa);
    final bestDay = _miningHistory.fold<double>(0.0, (max, s) => s.earnedAkofa > max ? s.earnedAkofa : max);
    // Calculate streak (consecutive days with mining)
    int streak = 0;
    DateTime? lastDay;
    for (final s in _miningHistory) {
      final day = DateTime(s.sessionEnd.year, s.sessionEnd.month, s.sessionEnd.day);
      if (lastDay == null || lastDay.difference(day).inDays == 1) {
        streak++;
        lastDay = day;
      } else {
        break;
      }
    }
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 24),
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
              value: '${totalMined.toStringAsFixed(4)} ₳',
              color: AppTheme.primaryGold,
            ),
            _buildAnalyticsItem(
              icon: Icons.local_fire_department,
              label: 'Streak',
              value: '$streak days',
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
                else if (session.isPaused)
                  ElevatedButton.icon(
                    onPressed: _tickMining,
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
                    onPressed: _tickMining,
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
                    AppTheme.darkGold.withOpacity(0.10),
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