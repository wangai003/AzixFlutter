import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/raffle_model.dart';
import '../../services/raffle_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive_layout.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/enhanced_image_widget.dart';

class RaffleWinnerAnnouncementScreen extends StatefulWidget {
  final RaffleModel raffle;

  const RaffleWinnerAnnouncementScreen({Key? key, required this.raffle})
    : super(key: key);

  @override
  State<RaffleWinnerAnnouncementScreen> createState() =>
      _RaffleWinnerAnnouncementScreenState();
}

class _RaffleWinnerAnnouncementScreenState
    extends State<RaffleWinnerAnnouncementScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<RaffleWinnerModel> _winners = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _loadWinners();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadWinners() async {
    try {
      final winnersStream = RaffleService.getRaffleWinners(widget.raffle.id);
      _winners = await winnersStream.first;

      // Sort winners by position
      _winners.sort((a, b) => a.winnerPosition.compareTo(b.winnerPosition));

      setState(() => _isLoading = false);

      // Start animation after data is loaded
      _animationController.forward();
    } catch (e) {
      print('Error loading winners: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: isDesktop ? null : _buildMobileAppBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGold),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Desktop header
                  if (isDesktop) _buildDesktopHeader(),

                  // Winners announcement
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Raffle info
                        _buildRaffleInfo(),

                        const SizedBox(height: 32),

                        // Winners list
                        if (_winners.isEmpty)
                          _buildNoWinners()
                        else
                          _buildWinnersList(),

                        const SizedBox(height: 32),

                        // Action buttons
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: AppTheme.black,
      title: Text(
        'Winners Announcement',
        style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
      ),
      elevation: 0,
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
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: AppTheme.primaryGold),
          ),
          const SizedBox(width: 16),
          Text(
            'Winners Announcement',
            style: AppTheme.headingLarge.copyWith(color: AppTheme.primaryGold),
          ),
        ],
      ),
    );
  }

  Widget _buildRaffleInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Raffle image
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppTheme.grey.withOpacity(0.3),
            ),
            child: widget.raffle.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: EnhancedImageWidget(
                      imageUrl: widget.raffle.imageUrl!,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(
                    Icons.emoji_events,
                    color: AppTheme.primaryGold,
                    size: 60,
                  ),
          ),

          const SizedBox(height: 16),

          // Raffle title
          Text(
            widget.raffle.title,
            style: AppTheme.headingLarge.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Completion message
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppTheme.primaryGold,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Raffle Completed',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatItem(
                '${widget.raffle.currentEntries}',
                'Total Entries',
                Icons.people,
              ),
              _buildStatDivider(),
              _buildStatItem(
                '${_winners.length}',
                'Winners',
                Icons.emoji_events,
              ),
              _buildStatDivider(),
              _buildStatItem(
                _formatDate(widget.raffle.drawDate ?? widget.raffle.endDate),
                'Draw Date',
                Icons.calendar_today,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryGold, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTheme.headingSmall.copyWith(color: AppTheme.white),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTheme.bodyTiny.copyWith(color: AppTheme.grey)),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 40,
      width: 1,
      color: AppTheme.grey.withOpacity(0.3),
      margin: const EdgeInsets.symmetric(horizontal: 24),
    );
  }

  Widget _buildNoWinners() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.sentiment_dissatisfied, color: AppTheme.grey, size: 64),
          const SizedBox(height: 16),
          Text(
            'No Winners Selected',
            style: AppTheme.headingMedium.copyWith(color: AppTheme.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'The raffle has ended but no winners have been selected yet.',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWinnersList() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🏆 Winners',
              style: AppTheme.headingLarge.copyWith(color: AppTheme.white),
            ),
            const SizedBox(height: 16),
            ..._winners.map((winner) => _buildWinnerCard(winner)),
          ],
        ),
      ),
    );
  }

  Widget _buildWinnerCard(RaffleWinnerModel winner) {
    final isFirstPlace = winner.winnerPosition == 1;
    final isSecondPlace = winner.winnerPosition == 2;
    final isThirdPlace = winner.winnerPosition == 3;

    Color cardColor;
    IconData trophyIcon;
    String positionText;

    if (isFirstPlace) {
      cardColor = AppTheme.primaryGold.withOpacity(0.1);
      trophyIcon = Icons.emoji_events;
      positionText = '🥇 1st Place';
    } else if (isSecondPlace) {
      cardColor = AppTheme.grey.withOpacity(0.3);
      trophyIcon = Icons.emoji_events;
      positionText = '🥈 2nd Place';
    } else if (isThirdPlace) {
      cardColor = const Color(0xFFCD7F32).withOpacity(0.3); // Bronze color
      trophyIcon = Icons.emoji_events;
      positionText = '🥉 3rd Place';
    } else {
      cardColor = AppTheme.darkGrey;
      trophyIcon = Icons.star;
      positionText = '${winner.winnerPosition}th Place';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFirstPlace
              ? AppTheme.primaryGold
              : AppTheme.grey.withOpacity(0.3),
          width: isFirstPlace ? 2 : 1,
        ),
        boxShadow: isFirstPlace
            ? [
                BoxShadow(
                  color: AppTheme.primaryGold.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Position and trophy
          Row(
            children: [
              Icon(
                trophyIcon,
                color: isFirstPlace
                    ? AppTheme.primaryGold
                    : isSecondPlace
                    ? AppTheme.grey
                    : const Color(0xFFCD7F32),
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                positionText,
                style: AppTheme.headingMedium.copyWith(
                  color: AppTheme.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: winner.canClaim
                      ? AppTheme.green.withOpacity(0.2)
                      : winner.isClaimed
                      ? AppTheme.blue.withOpacity(0.2)
                      : AppTheme.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  winner.isClaimed
                      ? 'Claimed'
                      : winner.canClaim
                      ? 'Ready to Claim'
                      : 'Expired',
                  style: AppTheme.bodySmall.copyWith(
                    color: winner.isClaimed
                        ? AppTheme.blue
                        : winner.canClaim
                        ? AppTheme.green
                        : AppTheme.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Winner info
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primaryGold.withOpacity(0.2),
                child: Text(
                  winner.winnerName[0].toUpperCase(),
                  style: AppTheme.headingMedium.copyWith(
                    color: AppTheme.primaryGold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      winner.winnerName,
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Winner selected on ${_formatDate(winner.drawDate)}',
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Prize details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prize Details',
                  style: AppTheme.labelLarge.copyWith(
                    color: AppTheme.primaryGold,
                  ),
                ),
                const SizedBox(height: 8),
                ...winner.prizeDetails.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text(
                          '${entry.key}: ',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.grey,
                          ),
                        ),
                        Text(
                          entry.value.toString(),
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

          // Claim button (if applicable)
          if (winner.canClaim) ...[
            const SizedBox(height: 16),
            CustomButton(
              text: 'Claim Prize',
              onPressed: () => _claimPrize(winner),
              width: double.infinity,
              backgroundColor: AppTheme.green,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        CustomButton(
          text: 'Back to Raffles',
          onPressed: () => Navigator.pop(context),
          width: double.infinity,
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => _shareResults(),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.primaryGold),
            padding: const EdgeInsets.symmetric(vertical: 12),
            minimumSize: const Size(double.infinity, 48),
          ),
          child: Text(
            'Share Results',
            style: AppTheme.buttonMedium.copyWith(color: AppTheme.primaryGold),
          ),
        ),
      ],
    );
  }

  Future<void> _claimPrize(RaffleWinnerModel winner) async {
    // TODO: Implement prize claiming logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Prize claiming coming soon!'),
        backgroundColor: AppTheme.primaryGold,
      ),
    );
  }

  void _shareResults() {
    // TODO: Implement sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sharing functionality coming soon!'),
        backgroundColor: AppTheme.primaryGold,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
