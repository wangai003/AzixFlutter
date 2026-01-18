import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/polygon_mining_service.dart'; // Polygon mining service
import '../services/akofa_tag_service.dart';
import '../widgets/akofa_tag_prompt.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_layout.dart';

class MiningScreen extends StatefulWidget {
  const MiningScreen({super.key});

  @override
  State<MiningScreen> createState() => _MiningScreenState();
}

class _MiningScreenState extends State<MiningScreen> {
  final PolygonMiningService _polygonMiningService = PolygonMiningService();
  bool _isMining = false;
  int _remainingSeconds = 24 * 60 * 60; // 24 hours
  double _minedTokens = 0.0;
  Timer? _countdownTimer;
  String? _userWalletAddress;
  String? _currentSessionId;
  Set<String> _claimingSessionIds = {}; // Track which sessions are being claimed

  @override
  void initState() {
    super.initState();

    // Check if user has AKOFA tag before allowing mining
    _checkUserTagAndProceed();

    // Handle expired sessions on app reopen (and wait for it to complete)
    _handleExpiredSessionsAndLoad();

    // Polygon streaming for mining
    _polygonMiningService.minedTokenStream.listen((value) {
      setState(() => _minedTokens = value);
    });

    _loadUserWalletAddress();
    _restoreMiningSession();
  }

  /// Handle expired sessions and load wallet in proper sequence
  Future<void> _handleExpiredSessionsAndLoad() async {
    try {
      // First handle any expired sessions
      await _polygonMiningService.handleExpiredSessions();
      print('✅ Expired sessions handled');
      
      // Sessions will now be loaded via StreamBuilder in real-time
    } catch (e) {
      print('❌ Error handling expired sessions: $e');
    }
  }

  /// Check if user has AKOFA tag and prompt creation if needed
  Future<void> _checkUserTagAndProceed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final tagCheck = await AkofaTagService.checkUserHasTag(user.uid);

      if (!tagCheck['hasTag']) {
        // User doesn't have a tag - prompt creation
        if (mounted) {
          final tag = await showAkofaTagPrompt(
            context: context,
            userId: user.uid,
            firstName: user.displayName?.split(' ').first,
            publicKey: _userWalletAddress,
          );

          if (tag != null) {
            print('✅ AKOFA tag created for mining: $tag');
          } else {
            // User skipped tag creation - show warning
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('AKOFA tag is recommended for mining rewards'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else if (!tagCheck['isLinked'] && _userWalletAddress != null) {
        // Tag exists but not linked to current wallet - link it
        final linkResult = await AkofaTagService.linkTagToWallet(
          userId: user.uid,
          tag: tagCheck['tag'],
          publicKey: _userWalletAddress!,
          blockchain: 'polygon',
        );

        if (linkResult['success']) {
          print('✅ AKOFA tag linked to Polygon wallet for mining');
        }
      }
    } catch (e) {
      print('⚠️ Error checking AKOFA tag: $e');
    }
  }

  Future<void> _loadUserWalletAddress() async {
    // Load Polygon wallet address from the mining service
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final polygonAddress = await _polygonMiningService.getUserWalletAddress();
      
      setState(() {
        _userWalletAddress = polygonAddress;
      });
      
      if (polygonAddress == null) {
        print("⚠️ No Polygon wallet found for user. Please create a Polygon wallet first.");
      } else {
        print("✅ Loaded Polygon wallet: ${polygonAddress.substring(0, 10)}...");
      }
    } catch (e) {
      print("Error loading Polygon wallet address: $e");
    }
  }


  Future<void> _claimSession(String sessionId) async {
    // Prevent double-clicking
    if (_claimingSessionIds.contains(sessionId)) {
      return;
    }

    setState(() {
      _claimingSessionIds.add(sessionId);
    });

    try {
      // Show loading message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Processing claim... Please wait'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.blue,
        ),
      );

      final result = await _polygonMiningService.claimSpecificUnpaidSession(
        sessionId,
      );

      if (result['success']) {
        final txHash = result['txHash'] as String?;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✅ Successfully claimed mining rewards!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'AKOFA tokens have been sent to your wallet',
                  style: TextStyle(fontSize: 13),
                ),
                if (txHash != null && txHash.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Transaction: ${txHash.length > 8 ? txHash.substring(0, 8) + "..." : txHash}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
        
        // StreamBuilder automatically updates the unpaid sessions list in real-time
      } else {
        final errorMessage = result['message'] ?? 'Unknown error occurred';
        final isWalletError = errorMessage.toLowerCase().contains('wallet') ||
                               errorMessage.toLowerCase().contains('balance');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWalletError 
                    ? '⚠️ Wallet Issue' 
                    : '❌ Failed to claim rewards',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  errorMessage,
                  style: TextStyle(fontSize: isWalletError ? 13 : 12),
                ),
              ],
            ),
            backgroundColor: isWalletError ? Colors.orange : Colors.red,
            duration: Duration(seconds: isWalletError ? 8 : 5),
          ),
        );
      }
    } catch (e) {
      print("❌ Error claiming session: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '❌ Error claiming rewards',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(e.toString()),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _claimingSessionIds.remove(sessionId);
      });
    }
  }

  Future<void> _restoreMiningSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final activeSessions = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('active_mining_sessions')
        .where('sessionEnd', isGreaterThan: Timestamp.now())
        .where('completed', isEqualTo: false)
        .get();

    if (activeSessions.docs.isNotEmpty) {
      final doc = activeSessions.docs.first; // assume one active session
      final sessionData = doc.data();
      final sessionStart = (sessionData['sessionStart'] as Timestamp).toDate();
      final sessionEnd = (sessionData['sessionEnd'] as Timestamp).toDate();
      final now = DateTime.now();

      if (now.isBefore(sessionEnd)) {
        final elapsed = now.difference(sessionStart);
        final mined = elapsed.inSeconds * (1.5 / 3600);
        final remaining = sessionEnd.difference(now).inSeconds;

        setState(() {
          _minedTokens = mined;
          _remainingSeconds = remaining;
          _isMining = true;
          _currentSessionId = doc.id;
        });

        // Set the restored mined tokens in the service
        _polygonMiningService.setInitialMinedTokens(mined);
        _polygonMiningService.startMining();

        // Restart countdown timer
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (
          timer,
        ) async {
          if (_remainingSeconds > 0) {
            setState(() => _remainingSeconds--);
          } else {
            timer.cancel();
            _polygonMiningService.stopMining();

            // ⛏️ Send mined tokens via Polygon
            await _polygonMiningService.completeMiningSession(
              _currentSessionId!,
              _minedTokens,
            );

            setState(() {
              _isMining = false;
              _minedTokens = 0.0;
            });
          }
        });
      }
    }
  }

  void _startMining() async {
    await _startLegacyMining();
  }

  Future<void> _startLegacyMining() async {
    setState(() {
      _isMining = true;
      _remainingSeconds = 24 * 60 * 60;
    });

    final sessionRef = await _polygonMiningService.saveMiningSession();
    _currentSessionId = sessionRef.id;
    _polygonMiningService.startMining();

    // Countdown timer for 24 hours
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        _polygonMiningService.stopMining();

        // ⛏️ Send mined tokens via Polygon
        await _polygonMiningService.completeMiningSession(
          _currentSessionId!,
          _minedTokens,
        );

        setState(() {
          _isMining = false;
          _minedTokens = 0.0;
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _polygonMiningService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.black, Color(0xFF212121)],
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
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      children: [
                        Text(
                          'AKOFA Mining',
                          textAlign: TextAlign.center,
                          style:
                              (isDesktop
                                      ? AppTheme.headingMedium.copyWith(
                                          fontSize: 28,
                                        )
                                      : AppTheme.headingMedium)
                                  .copyWith(color: AppTheme.primaryGold),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(
                    duration: const Duration(milliseconds: 600),
                  ),

                  const SizedBox(height: 32),

                  // Main Content
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Mining Icon
                        Container(
                              width:
                                  ResponsiveLayout.getValueForScreenType<
                                    double
                                  >(
                                    context: context,
                                    mobile: 120,
                                    tablet: 150,
                                    desktop: 180,
                                  ),
                              height:
                                  ResponsiveLayout.getValueForScreenType<
                                    double
                                  >(
                                    context: context,
                                    mobile: 120,
                                    tablet: 150,
                                    desktop: 180,
                                  ),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: AppTheme.buttonShadow,
                                border: Border.all(
                                  color: AppTheme.primaryGold,
                                  width: 3,
                                ),
                              ),
                              child: ClipOval(
                                child: Image.network(
                                  'https://files.catbox.moe/lcg61a.jpg',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.goldGradient,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _isMining ? Icons.engineering : Icons.terrain,
                                        color: AppTheme.black,
                                        size: ResponsiveLayout.getValueForScreenType<double>(
                                          context: context,
                                          mobile: 30,
                                          tablet: 37.5,
                                          desktop: 45,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            )
                            .animate(target: _isMining ? 1 : 0)
                            .scale(
                              begin: const Offset(1, 1),
                              end: const Offset(1.1, 1.1),
                              duration: const Duration(milliseconds: 500),
                            )
                            .animate()
                            .fadeIn(
                              duration: const Duration(milliseconds: 800),
                            ),

                        SizedBox(height: isDesktop ? 48.0 : 32.0),

                        // Title
                        Text(
                              _isMining
                                  ? 'Mining in Progress'
                                  : 'Start Mining AKOFA',
                              textAlign: TextAlign.center,
                              style:
                                  (isDesktop
                                          ? AppTheme.headingLarge.copyWith(
                                              fontSize: 36,
                                            )
                                          : AppTheme.headingLarge)
                                      .copyWith(
                                        color: AppTheme.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                            )
                            .animate()
                            .fadeIn(
                              duration: const Duration(milliseconds: 800),
                              delay: const Duration(milliseconds: 200),
                            )
                            .slideY(
                              begin: 0.2,
                              end: 0,
                              curve: Curves.easeOut,
                              duration: const Duration(milliseconds: 800),
                            ),

                        SizedBox(height: isDesktop ? 32.0 : 24.0),

                        // Countdown Timer Card
                        Container(
                              constraints: BoxConstraints(
                                maxWidth: isDesktop
                                    ? 400
                                    : isTablet
                                    ? 350
                                    : double.infinity,
                              ),
                              child: Card(
                                color: AppTheme.darkGrey.withOpacity(0.8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 8,
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Time Remaining',
                                        style: AppTheme.labelLarge.copyWith(
                                          color: AppTheme.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _formatTime(_remainingSeconds),
                                        style: TextStyle(
                                          color: _isMining
                                              ? AppTheme.primaryGold
                                              : AppTheme.grey,
                                          fontSize: isDesktop ? 48 : 40,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: AppTheme.fontFamily,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .animate()
                            .fadeIn(
                              duration: const Duration(milliseconds: 800),
                              delay: const Duration(milliseconds: 400),
                            )
                            .scale(
                              begin: const Offset(0.9, 0.9),
                              end: const Offset(1, 1),
                              curve: Curves.easeOut,
                              duration: const Duration(milliseconds: 600),
                            ),

                        SizedBox(height: isDesktop ? 32.0 : 24.0),

                        // Mined Tokens Display
                        Container(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop
                                ? 350
                                : isTablet
                                ? 300
                                : double.infinity,
                          ),
                          child: Card(
                            color: AppTheme.darkGrey.withOpacity(0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Text(
                                    'Mined AKOFA',
                                    textAlign: TextAlign.center,
                                    style: AppTheme.labelMedium.copyWith(
                                      color: AppTheme.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _minedTokens.toStringAsFixed(6),
                                    style: TextStyle(
                                      color: AppTheme.primaryGold,
                                      fontSize: isDesktop ? 28 : 24,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: AppTheme.fontFamily,
                                    ),
                                  ),
                                  Text(
                                    '≈ ${(1.5 * (_remainingSeconds / 3600)).toStringAsFixed(6)} remaining',
                                    style: AppTheme.caption.copyWith(
                                      color: AppTheme.grey.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn(
                          duration: const Duration(milliseconds: 800),
                          delay: const Duration(milliseconds: 600),
                        ),

                        SizedBox(height: isDesktop ? 48.0 : 40.0),

                        // Mining Rate Info
                        Container(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop
                                ? 300
                                : isTablet
                                ? 250
                                : double.infinity,
                          ),
                          child: Card(
                            color: AppTheme.darkGrey.withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    color: AppTheme.secondaryGold,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '1.5 AKOFA/hour',
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: AppTheme.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn(
                          duration: const Duration(milliseconds: 800),
                          delay: const Duration(milliseconds: 800),
                        ),

                        SizedBox(height: isDesktop ? 32.0 : 24.0),

                        // Wallet Address Display
                        if (_userWalletAddress != null)
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: isDesktop
                                  ? 400
                                  : isTablet
                                  ? 350
                                  : double.infinity,
                            ),
                            child: Card(
                              color: AppTheme.darkGrey.withOpacity(0.6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.account_balance_wallet,
                                          color: AppTheme.primaryGold,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Your Wallet Address',
                                          style: AppTheme.labelMedium.copyWith(
                                            color: AppTheme.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SelectableText(
                                      _userWalletAddress!,
                                      style: TextStyle(
                                        color: AppTheme.white,
                                        fontSize: isDesktop ? 16 : 14,
                                        fontFamily: 'monospace',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ).animate().fadeIn(
                            duration: const Duration(milliseconds: 800),
                            delay: const Duration(milliseconds: 1000),
                          ),

                        SizedBox(height: isDesktop ? 48.0 : 40.0),

                        // Start Mining Button
                        Container(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop
                                ? 300
                                : isTablet
                                ? 250
                                : double.infinity,
                          ),
                          child: ElevatedButton(
                            onPressed: _isMining ? null : _startMining,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isMining
                                  ? AppTheme.grey.withOpacity(0.3)
                                  : AppTheme.primaryGold,
                              foregroundColor: _isMining
                                  ? AppTheme.grey
                                  : AppTheme.black,
                              disabledBackgroundColor: AppTheme.grey
                                  .withOpacity(0.3),
                              disabledForegroundColor: AppTheme.grey,
                              textStyle: AppTheme.buttonLarge,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              elevation: _isMining ? 0 : 8,
                              shadowColor: _isMining
                                  ? Colors.transparent
                                  : AppTheme.primaryGold.withOpacity(0.3),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isMining
                                      ? Icons.hourglass_top
                                      : Icons.play_arrow,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _isMining
                                      ? "Mining in progress..."
                                      : "Start Mining",
                                  style: AppTheme.buttonLarge.copyWith(
                                    color: _isMining
                                        ? AppTheme.grey
                                        : AppTheme.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(
                          duration: const Duration(milliseconds: 800),
                          delay: const Duration(milliseconds: 1000),
                        ),

                        // Conditional message
                        ...(_isMining
                            ? [
                                const SizedBox(height: 16),
                                Text(
                                  'Mining will complete automatically in 24 hours',
                                  textAlign: TextAlign.center,
                                  style: AppTheme.caption.copyWith(
                                    color: AppTheme.grey.withOpacity(0.8),
                                  ),
                                ),
                              ]
                            : []),

                        // Unpaid Sessions Section - Real-time Stream
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _polygonMiningService.streamUnpaidMiningSessions(),
                          builder: (context, snapshot) {
                            // Handle loading state
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Column(
                                children: [
                                  SizedBox(height: isDesktop ? 48.0 : 40.0),
                                  const Center(child: CircularProgressIndicator()),
                                ],
                              );
                            }

                            // Handle error state
                            if (snapshot.hasError) {
                              print('❌ Stream error: ${snapshot.error}');
                              return const SizedBox.shrink();
                            }

                            // Get unpaid sessions from stream
                            final unpaidSessions = snapshot.data ?? [];
                            
                            // Log session count for debugging
                            if (unpaidSessions.isNotEmpty) {
                              print('📊 Displaying ${unpaidSessions.length} unpaid sessions');
                            }

                            // Only show section if there are unpaid sessions
                            if (unpaidSessions.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Column(
                              children: [
                                SizedBox(height: isDesktop ? 48.0 : 40.0),

                                Text(
                                  'Unclaimed Mining Rewards',
                                  textAlign: TextAlign.center,
                                  style:
                                      (isDesktop
                                              ? AppTheme.headingMedium.copyWith(
                                                  fontSize: 24,
                                                )
                                              : AppTheme.headingMedium)
                                          .copyWith(color: AppTheme.primaryGold),
                                ).animate().fadeIn(
                                  duration: const Duration(milliseconds: 600),
                                  delay: const Duration(milliseconds: 200),
                                ),

                                const SizedBox(height: 8),
                                
                                // Info badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.orange.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        color: Colors.orange[300],
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${unpaidSessions.length} session${unpaidSessions.length > 1 ? 's' : ''} pending',
                                        style: TextStyle(
                                          color: Colors.orange[200],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: isDesktop ? 24.0 : 16.0),

                                // List of unpaid sessions
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: unpaidSessions.length,
                                  itemBuilder: (context, index) {
                                    final session = unpaidSessions[index];
                                    final sessionStart =
                                        (session['sessionStart'] as Timestamp)
                                            .toDate();
                                    final minedTokens =
                                        session['minedTokens'] as double;
                                    final blockchain = session['blockchain'] ?? 'polygon';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      constraints: BoxConstraints(
                                        maxWidth: isDesktop
                                            ? 500
                                            : isTablet
                                            ? 400
                                            : double.infinity,
                                      ),
                                      child: Card(
                                        color: AppTheme.darkGrey.withOpacity(0.8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 4,
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Session ${index + 1}',
                                                        style: AppTheme.labelLarge
                                                            .copyWith(
                                                              color:
                                                                  AppTheme.primaryGold,
                                                              fontWeight:
                                                                  FontWeight.w600,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 2,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: blockchain == 'polygon'
                                                              ? Colors.purple.withOpacity(0.2)
                                                              : Colors.blue.withOpacity(0.2),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text(
                                                          blockchain.toUpperCase(),
                                                          style: TextStyle(
                                                            color: blockchain == 'polygon'
                                                                ? Colors.purple[300]
                                                                : Colors.blue[300],
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    '${minedTokens.toStringAsFixed(6)} AKOFA',
                                                    style: AppTheme.bodyLarge
                                                        .copyWith(
                                                          color: AppTheme.white,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'Completed: ${sessionStart.toString().split(' ')[0]}',
                                                style: AppTheme.caption.copyWith(
                                                  color: AppTheme.grey.withOpacity(
                                                    0.8,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                  onPressed: _claimingSessionIds
                                                          .contains(session['id'])
                                                      ? null
                                                      : () => _claimSession(
                                                            session['id'],
                                                          ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        _claimingSessionIds.contains(
                                                                session['id'])
                                                            ? AppTheme.grey
                                                                .withOpacity(0.3)
                                                            : AppTheme.primaryGold,
                                                    foregroundColor:
                                                        _claimingSessionIds.contains(
                                                                session['id'])
                                                            ? AppTheme.grey
                                                            : AppTheme.black,
                                                    disabledBackgroundColor:
                                                        AppTheme.grey
                                                            .withOpacity(0.3),
                                                    disabledForegroundColor:
                                                        AppTheme.grey,
                                                    textStyle:
                                                        AppTheme.buttonMedium,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(8),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 24,
                                                          vertical: 12,
                                                        ),
                                                  ),
                                                  child: _claimingSessionIds
                                                          .contains(session['id'])
                                                      ? const Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            SizedBox(
                                                              width: 16,
                                                              height: 16,
                                                              child:
                                                                  CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                valueColor:
                                                                    AlwaysStoppedAnimation<
                                                                            Color>(
                                                                        Colors
                                                                            .white),
                                                              ),
                                                            ),
                                                            SizedBox(width: 8),
                                                            Text('Claiming...'),
                                                          ],
                                                        )
                                                      : const Text(
                                                          'Claim Rewards',
                                                        ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ).animate().fadeIn(
                                      duration: const Duration(milliseconds: 600),
                                      delay: Duration(
                                        milliseconds: 300 + (index * 100),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32), // Add bottom padding for scroll
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
