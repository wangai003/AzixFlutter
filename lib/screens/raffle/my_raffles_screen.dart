import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../models/raffle_model.dart';
import '../../services/raffle_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive_layout.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/enhanced_image_widget.dart';
import 'raffle_detail_screen.dart';
import 'raffle_creation_screen.dart';

class MyRafflesScreen extends StatefulWidget {
  const MyRafflesScreen({Key? key}) : super(key: key);

  @override
  State<MyRafflesScreen> createState() => _MyRafflesScreenState();
}

class _MyRafflesScreenState extends State<MyRafflesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Created', 'Entered', 'Won'];
  bool _isLoading = true;
  List<RaffleModel> _createdRaffles = [];
  List<RaffleModel> _enteredRaffles = [];
  List<RaffleModel> _wonRaffles = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Load created raffles
      final createdStream = RaffleService.getRaffles(creatorId: user.uid);
      _createdRaffles = await createdStream.first;

      // Load entered raffles (this would need to be implemented in the service)
      // For now, we'll show a placeholder
      _enteredRaffles = [];

      // Load won raffles (this would need to be implemented in the service)
      // For now, we'll show a placeholder
      _wonRaffles = [];
    } catch (e) {
      print('Error loading raffles: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);

    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: isDesktop ? null : _buildMobileAppBar(),
      body: Column(
        children: [
          // Desktop header
          if (isDesktop) _buildDesktopHeader(),

          // Tab bar
          _buildTabBar(),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRafflesList(_createdRaffles, 'created'),
                _buildRafflesList(_enteredRaffles, 'entered'),
                _buildRafflesList(_wonRaffles, 'won'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: AppTheme.black,
      title: Text(
        'My Raffles',
        style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
      ),
      elevation: 0,
      bottom: TabBar(
        controller: _tabController,
        tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        indicatorColor: AppTheme.primaryGold,
        labelColor: AppTheme.primaryGold,
        unselectedLabelColor: AppTheme.grey,
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppTheme.black,
        border: Border(
          bottom: BorderSide(color: AppTheme.primaryGold, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            'My Raffles',
            style: AppTheme.headingLarge.copyWith(color: AppTheme.primaryGold),
          ),
          const Spacer(),
          CustomButton(
            text: 'Create Raffle',
            onPressed: () => _navigateToCreateRaffle(),
            icon: Icons.add,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    if (!ResponsiveLayout.isMobile(context)) {
      return Container(
        color: AppTheme.darkGrey,
        child: TabBar(
          controller: _tabController,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
          indicatorColor: AppTheme.primaryGold,
          labelColor: AppTheme.primaryGold,
          unselectedLabelColor: AppTheme.grey,
          labelStyle: AppTheme.buttonMedium,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildRafflesList(List<RaffleModel> raffles, String type) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGold),
      );
    }

    if (raffles.isEmpty) {
      return _buildEmptyState(type);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: raffles.length,
      itemBuilder: (context, index) {
        return _buildRaffleCard(raffles[index], type);
      },
    );
  }

  Widget _buildEmptyState(String type) {
    String title;
    String message;
    IconData icon;

    switch (type) {
      case 'created':
        title = 'No raffles created';
        message = 'Create your first raffle to get started!';
        icon = Icons.add_circle_outline;
        break;
      case 'entered':
        title = 'No raffles entered';
        message = 'Browse raffles and enter to see them here!';
        icon = Icons.local_activity_outlined;
        break;
      case 'won':
        title = 'No raffles won';
        message = 'Keep entering raffles to win prizes!';
        icon = Icons.emoji_events_outlined;
        break;
      default:
        title = 'No raffles found';
        message = 'Check back later for updates!';
        icon = Icons.inbox;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.grey, size: 64),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTheme.headingMedium.copyWith(color: AppTheme.grey),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (type == 'created')
            CustomButton(
              text: 'Create Raffle',
              onPressed: () => _navigateToCreateRaffle(),
              icon: Icons.add,
            ),
        ],
      ),
    );
  }

  Widget _buildRaffleCard(RaffleModel raffle, String type) {
    final isActive = raffle.isActive;
    final isExpired = raffle.isExpired;
    final progress = raffle.maxEntries > 0
        ? raffle.currentEntries / raffle.maxEntries
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppTheme.darkGrey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _navigateToRaffleDetail(raffle),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with image and basic info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Raffle image
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppTheme.grey.withOpacity(0.3),
                    ),
                    child: raffle.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: EnhancedImageWidget(
                              imageUrl: raffle.imageUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(
                            Icons.local_activity,
                            color: AppTheme.primaryGold,
                            size: 30,
                          ),
                  ),

                  const SizedBox(width: 12),

                  // Title and status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          raffle.title,
                          style: AppTheme.headingSmall.copyWith(
                            color: AppTheme.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(raffle.status),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getStatusText(raffle.status),
                            style: AppTheme.bodyTiny.copyWith(
                              color: AppTheme.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Type indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getTypeColor(type),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getTypeText(type),
                      style: AppTheme.bodyTiny.copyWith(
                        color: AppTheme.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Progress and stats
              if (type == 'created') ...[
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: AppTheme.grey.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isActive ? AppTheme.primaryGold : AppTheme.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${raffle.currentEntries}/${raffle.maxEntries}',
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.white),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Icon(Icons.schedule, color: AppTheme.grey, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Ends: ${_formatDate(raffle.endDate)}',
                      style: AppTheme.bodyTiny.copyWith(color: AppTheme.grey),
                    ),
                    const Spacer(),
                    if (raffle.canEnter)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Active',
                          style: AppTheme.bodyTiny.copyWith(
                            color: AppTheme.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ] else if (type == 'entered') ...[
                Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.green, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Entered',
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.green),
                    ),
                    const Spacer(),
                    Text(
                      'Ends: ${_formatDate(raffle.endDate)}',
                      style: AppTheme.bodyTiny.copyWith(color: AppTheme.grey),
                    ),
                  ],
                ),
              ] else if (type == 'won') ...[
                Row(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: AppTheme.primaryGold,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Winner!',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Completed',
                      style: AppTheme.bodyTiny.copyWith(color: AppTheme.grey),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () => _navigateToCreateRaffle(),
      backgroundColor: AppTheme.primaryGold,
      foregroundColor: AppTheme.black,
      child: const Icon(Icons.add),
    );
  }

  void _navigateToRaffleDetail(RaffleModel raffle) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RaffleDetailScreen(raffle: raffle)),
    );
  }

  void _navigateToCreateRaffle() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RaffleCreationScreen()),
    );
  }

  Color _getStatusColor(RaffleStatus status) {
    switch (status) {
      case RaffleStatus.active:
        return AppTheme.green;
      case RaffleStatus.draft:
        return AppTheme.blue;
      case RaffleStatus.upcoming:
        return AppTheme.primaryGold.withOpacity(0.7);
      case RaffleStatus.paused:
        return AppTheme.orange;
      case RaffleStatus.completed:
        return AppTheme.primaryGold;
      case RaffleStatus.cancelled:
        return AppTheme.red;
    }
  }

  String _getStatusText(RaffleStatus status) {
    switch (status) {
      case RaffleStatus.active:
        return 'Active';
      case RaffleStatus.draft:
        return 'Draft';
      case RaffleStatus.upcoming:
        return 'Upcoming';
      case RaffleStatus.paused:
        return 'Paused';
      case RaffleStatus.completed:
        return 'Completed';
      case RaffleStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'created':
        return AppTheme.primaryGold;
      case 'entered':
        return AppTheme.blue;
      case 'won':
        return AppTheme.green;
      default:
        return AppTheme.grey;
    }
  }

  String _getTypeText(String type) {
    switch (type) {
      case 'created':
        return 'Created';
      case 'entered':
        return 'Entered';
      case 'won':
        return 'Won';
      default:
        return 'Unknown';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.isNegative) {
      return 'Ended';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d left';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h left';
    } else {
      return '${difference.inMinutes}m left';
    }
  }
}
