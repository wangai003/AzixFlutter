import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/auth_provider.dart';
import '../providers/stellar_provider.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_layout.dart';
import '../widgets/transaction_list.dart';
import '../models/transaction.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({Key? key}) : super(key: key);

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  Map<String, dynamic>? _userData;
  List<Transaction> _referralTransactions = [];
  List<Map<String, dynamic>> _referralLeaderboard = [];
  List<Map<String, dynamic>> _recentReferrals = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadReferralData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReferralData() async {
    setState(() => _isLoading = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
      final user = authProvider.user;
      
      if (user != null) {
        // Load user data
        _userData = await authProvider.authService.getUserDetails(user.uid);
        
        // Load referral transactions
        _referralTransactions = stellarProvider.transactions.where((tx) =>
          tx.typeLabel == 'Mining Reward' && (tx.memo?.toLowerCase().contains('referral') ?? false)
        ).toList();
        
        // Load real leaderboard data
        _referralLeaderboard = await authProvider.authService.getReferralLeaderboard();
        
        // Add ranks to leaderboard data
        for (int i = 0; i < _referralLeaderboard.length; i++) {
          _referralLeaderboard[i]['rank'] = i + 1;
        }
        
        // Load real recent referrals
        _recentReferrals = await authProvider.authService.getRecentReferrals(user.uid);
      }
    } catch (e) {
      print('Error loading referral data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }



  void _copyReferralCode() {
    final referralCode = _userData?['referralCode'] ?? '';
    if (referralCode.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: referralCode));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Referral code copied to clipboard!'),
          backgroundColor: AppTheme.primaryGold,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _shareReferralCode() {
    final referralCode = _userData?['referralCode'] ?? '';
    if (referralCode.isNotEmpty) {
      Share.share(
        'Join me on AZIX Network and earn AKOFA tokens! Use my referral code: $referralCode\n\nDownload the app and start earning today! 🚀',
        subject: 'Join AZIX Network - Earn AKOFA Tokens',
      );
    }
  }

  void _showQRCode() {
    final referralCode = _userData?['referralCode'] ?? '';
    if (referralCode.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Your Referral QR Code',
            style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: referralCode,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                referralCode,
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: AppTheme.primaryGold)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : RefreshIndicator(
              onRefresh: _loadReferralData,
              color: AppTheme.primaryGold,
              backgroundColor: AppTheme.black,
              child: CustomScrollView(
              slivers: [
                // Custom App Bar
                SliverAppBar(
                  expandedHeight: isDesktop ? 200 : 150,
                  floating: false,
                  pinned: true,
                  backgroundColor: AppTheme.black,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      'Referral Program',
                      style: AppTheme.headingMedium.copyWith(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryGold.withOpacity(0.1),
                            AppTheme.black,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.share,
                          size: isDesktop ? 80 : 60,
                          color: AppTheme.primaryGold.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 48 : 24,
                      vertical: 24,
                    ),
                    child: Column(
                      children: [
                        // Referral Code Card
                        _buildReferralCodeCard(),
                        const SizedBox(height: 24),
                        
                        // Stats Cards
                        _buildStatsCards(),
                        const SizedBox(height: 24),
                        
                        // Tab Bar
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.darkGrey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: AppTheme.primaryGold,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            labelColor: AppTheme.black,
                            unselectedLabelColor: AppTheme.grey,
                            tabs: const [
                              Tab(icon: Icon(Icons.analytics), text: 'Overview'),
                              Tab(icon: Icon(Icons.leaderboard), text: 'Leaderboard'),
                              Tab(icon: Icon(Icons.people), text: 'Referrals'),
                              Tab(icon: Icon(Icons.history), text: 'History'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Tab Content
                        SizedBox(
                          height: 600,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildOverviewTab(),
                              _buildLeaderboardTab(),
                              _buildReferralsTab(),
                              _buildHistoryTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildReferralCodeCard() {
    final referralCode = _userData?['referralCode'] ?? '';
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGold.withOpacity(0.2),
            AppTheme.primaryGold.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.primaryGold.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGold.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.qr_code,
                  color: AppTheme.primaryGold,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Referral Code',
                      style: AppTheme.headingMedium.copyWith(
                        color: AppTheme.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Share this code to earn rewards',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryGold.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    referralCode,
                    style: AppTheme.headingLarge.copyWith(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontFamily: 'Monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    IconButton(
                      onPressed: _copyReferralCode,
                      icon: const Icon(Icons.copy, color: AppTheme.primaryGold),
                      tooltip: 'Copy Code',
                    ),
                    IconButton(
                      onPressed: _showQRCode,
                      icon: const Icon(Icons.qr_code, color: AppTheme.primaryGold),
                      tooltip: 'Show QR Code',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _shareReferralCode,
                  icon: const Icon(Icons.share),
                  label: const Text('Share Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    foregroundColor: AppTheme.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0);
  }

    Widget _buildStatsCards() {
    final totalReferrals = (_userData?['referrals'] as List<dynamic>?)?.length ?? 0;
    final referralCount = _userData?['referralCount'] ?? 0;
    final totalEarnings = _referralTransactions.fold<double>(0, (sum, tx) => sum + (tx.amount ?? 0));
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Referrals',
            '$totalReferrals',
            Icons.people,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Active Referrals',
            '$referralCount',
            Icons.trending_up,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Total Earnings',
            '${totalEarnings.toStringAsFixed(2)} ₳',
            Icons.monetization_on,
            AppTheme.primaryGold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTheme.headingMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideY(begin: 0.3, end: 0);
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Program Overview',
            style: AppTheme.headingMedium.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // How it works
          _buildInfoCard(
            'How It Works',
            'Share your referral code with friends and earn 5 AKOFA tokens for each successful referral!',
            Icons.how_to_reg,
            AppTheme.primaryGold,
          ),
          const SizedBox(height: 16),
          
          // Rewards
          _buildInfoCard(
            'Rewards',
            '• 5 AKOFA tokens per referral\n• Bonus rewards for milestone achievements\n• Exclusive access to premium features',
            Icons.card_giftcard,
            Colors.green,
          ),
          const SizedBox(height: 16),
          
          // Tips
          _buildInfoCard(
            'Tips for Success',
            '• Share on social media\n• Create engaging content\n• Help new users get started\n• Build a community',
            Icons.lightbulb,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    final currentUserId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    final currentUserRank = _referralLeaderboard.indexWhere((user) => user['userId'] == currentUserId) + 1;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Referrers',
            style: AppTheme.headingMedium.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          if (currentUserRank > 0 && currentUserRank <= 10)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryGold.withOpacity(0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.star, color: AppTheme.primaryGold, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Your Rank: #$currentUserRank',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          
          ..._referralLeaderboard.map((user) => _buildLeaderboardItem(user)).toList(),
        ],
      ),
    );
  }

  Widget _buildReferralsTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Referrals',
            style: AppTheme.headingMedium.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          if (_recentReferrals.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: AppTheme.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No referrals yet',
                    style: AppTheme.bodyLarge.copyWith(color: AppTheme.grey),
                  ),
                  Text(
                    'Start sharing your referral code!',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                  ),
                ],
              ),
            )
          else
            ..._recentReferrals.map((referral) => _buildReferralItem(referral)).toList(),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Referral Rewards History',
            style: AppTheme.headingMedium.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          if (_referralTransactions.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: AppTheme.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No referral rewards yet',
                    style: AppTheme.bodyLarge.copyWith(color: AppTheme.grey),
                  ),
                  Text(
                    'Your referral rewards will appear here',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                  ),
                ],
              ),
            )
          else
            Container(
              height: 400,
              decoration: BoxDecoration(
                color: AppTheme.darkGrey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: TransactionList(transactions: _referralTransactions),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String content, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardItem(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: user['rank'] <= 3 ? AppTheme.primaryGold.withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: user['rank'] <= 3 ? AppTheme.primaryGold : AppTheme.grey,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                '${user['rank']}',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            user['avatar'],
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['username'],
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${user['referrals']} referrals',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${user['earnings']} ₳',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'earned',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReferralItem(Map<String, dynamic> referral) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: referral['status'] == 'active' ? Colors.green : Colors.orange,
            child: Icon(
              referral['status'] == 'active' ? Icons.check : Icons.pending,
              color: AppTheme.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  referral['username'],
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Joined ${_formatDate(referral['joined'])}',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: referral['status'] == 'active' ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              referral['status'].toUpperCase(),
              style: AppTheme.bodySmall.copyWith(
                color: referral['status'] == 'active' ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
} 