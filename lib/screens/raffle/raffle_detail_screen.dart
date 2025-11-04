import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/raffle_model.dart';
import '../../services/raffle_service.dart';
import '../../services/secure_wallet_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive_layout.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/enhanced_image_widget.dart';
import 'raffle_winner_announcement_screen.dart';

class RaffleDetailScreen extends StatefulWidget {
  final RaffleModel raffle;

  const RaffleDetailScreen({Key? key, required this.raffle}) : super(key: key);

  @override
  State<RaffleDetailScreen> createState() => _RaffleDetailScreenState();
}

class _RaffleDetailScreenState extends State<RaffleDetailScreen> {
  bool _isLoading = false;
  bool _isEntering = false;
  List<RaffleEntryModel> _userEntries = [];
  int _currentEntries = 0;
  Stream<int>? _entriesCountStream;
  Stream<List<RaffleEntryModel>>? _entriesStream;
  late RaffleModel _raffle;

  @override
  void initState() {
    super.initState();
    _raffle = widget.raffle;
    _initializeData();
  }

  Future<void> _initializeData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Load user's entries for this raffle
      _userEntries = await RaffleService.getUserEntries(
        raffleId: widget.raffle.id,
        userId: user.uid,
      );
    }

    // Set up real-time streams
    _setupStreams();

    setState(() {
      _currentEntries = widget.raffle.currentEntries;
    });
  }

  void _setupStreams() {
    // Listen to entries count updates
    _entriesCountStream = RaffleService.listenToEntriesCount(widget.raffle.id);
    _entriesCountStream?.listen((count) {
      if (mounted) {
        setState(() => _currentEntries = count);
      }
    });

    // Listen to raffle updates
    RaffleService.listenToRaffle(widget.raffle.id).listen((updatedRaffle) {
      if (mounted && updatedRaffle != null) {
        setState(() {
          _raffle = updatedRaffle;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: isDesktop ? null : _buildMobileAppBar(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Desktop header
            if (isDesktop) _buildDesktopHeader(),

            // Raffle image
            _buildRaffleImage(),

            // Raffle details
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and status
                  _buildTitleAndStatus(),

                  const SizedBox(height: 16),

                  // Progress and stats
                  _buildProgressAndStats(),

                  const SizedBox(height: 24),

                  // Description
                  _buildDescription(),

                  const SizedBox(height: 24),

                  // Entry requirements
                  _buildEntryRequirements(),

                  const SizedBox(height: 24),

                  // Prize details
                  _buildPrizeDetails(),

                  const SizedBox(height: 24),

                  // Action buttons
                  if (user != null) _buildActionButtons(user),

                  const SizedBox(height: 24),

                  // Recent entries (if raffle is active)
                  if (_raffle.isActive) _buildRecentEntries(),
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
        'Raffle Details',
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
            'Raffle Details',
            style: AppTheme.headingLarge.copyWith(color: AppTheme.primaryGold),
          ),
        ],
      ),
    );
  }

  Widget _buildRaffleImage() {
    final imageHeight = ResponsiveLayout.isMobile(context) ? 250.0 : 400.0;

    return Container(
      height: imageHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        image: _raffle.imageUrl != null
            ? DecorationImage(
                image: NetworkImage(_raffle.imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: _raffle.imageUrl == null
          ? const Icon(
              Icons.local_activity,
              color: AppTheme.primaryGold,
              size: 80,
            )
          : null,
    );
  }

  Widget _buildTitleAndStatus() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _raffle.title,
                style: AppTheme.headingLarge.copyWith(color: AppTheme.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Created by ${_raffle.creatorName}',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor(_raffle.status),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _getStatusText(_raffle.status),
            style: AppTheme.labelMedium.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressAndStats() {
    final progress = _raffle.maxEntries > 0
        ? _currentEntries / _raffle.maxEntries
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Progress bar
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: AppTheme.grey.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _raffle.isActive ? AppTheme.primaryGold : AppTheme.grey,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '$_currentEntries / ${_raffle.maxEntries}',
                style: AppTheme.bodyLarge.copyWith(color: AppTheme.white),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Stats grid
          Row(
            children: [
              _buildStatItem(
                'Entries',
                _currentEntries.toString(),
                Icons.people,
              ),
              _buildStatDivider(),
              _buildStatItem(
                'Remaining',
                _raffle.entriesRemaining.toString(),
                Icons.schedule,
              ),
              _buildStatDivider(),
              _buildStatItem(
                'Ends',
                _formatDate(_raffle.endDate),
                Icons.access_time,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
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
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 40,
      width: 1,
      color: AppTheme.grey.withOpacity(0.3),
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: AppTheme.headingMedium.copyWith(color: AppTheme.white),
        ),
        const SizedBox(height: 12),
        Text(
          _raffle.description,
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.white.withOpacity(0.9),
          ),
        ),
        if (_raffle.detailedDescription != null) ...[
          const SizedBox(height: 16),
          ExpansionTile(
            title: Text(
              'Read More',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryGold),
            ),
            children: [
              Text(
                _raffle.detailedDescription!,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildEntryRequirements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Entry Requirements',
          style: AppTheme.headingMedium.copyWith(color: AppTheme.white),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkGrey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: _raffle.entryRequirements.entries.map((entry) {
              return _buildRequirementItem(entry.key, entry.value);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementItem(String key, dynamic value) {
    String displayText;
    IconData icon;

    switch (key) {
      case 'type':
        displayText = 'Entry Type: ${value.toString().toUpperCase()}';
        icon = Icons.info;
        break;
      case 'cost':
        displayText = 'Cost: $value AKOFA';
        icon = Icons.attach_money;
        break;
      case 'minBalance':
        displayText = 'Minimum Balance: $value AKOFA';
        icon = Icons.account_balance_wallet;
        break;
      case 'referralRequired':
        displayText = value == true
            ? 'Referral Required'
            : 'No Referral Needed';
        icon = Icons.share;
        break;
      default:
        displayText = '$key: $value';
        icon = Icons.settings;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGold, size: 20),
          const SizedBox(width: 12),
          Text(
            displayText,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
          ),
        ],
      ),
    );
  }

  Widget _buildPrizeDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prize Details',
          style: AppTheme.headingMedium.copyWith(color: AppTheme.white),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkGrey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: _raffle.prizeDetails.entries.map((entry) {
              return _buildPrizeItem(entry.key, entry.value);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPrizeItem(String key, dynamic value) {
    String displayText;
    IconData icon;

    switch (key) {
      case 'type':
        displayText = 'Prize Type: ${value.toString().toUpperCase()}';
        icon = Icons.emoji_events;
        break;
      case 'value':
        displayText = 'Value: $value AKOFA';
        icon = Icons.attach_money;
        break;
      case 'description':
        displayText = 'Description: $value';
        icon = Icons.description;
        break;
      default:
        displayText = '$key: $value';
        icon = Icons.star;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              displayText,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(User user) {
    final hasEntered = _userEntries.isNotEmpty;
    final canEnter = _raffle.canEnter && !hasEntered;

    return Column(
      children: [
        if (canEnter)
          CustomButton(
            text: 'Enter Raffle',
            onPressed: _isEntering ? null : () => _enterRaffle(user),
            isLoading: _isEntering,
            icon: Icons.local_activity,
            width: double.infinity,
          )
        else if (hasEntered)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You have entered this raffle!',
                    style: AppTheme.bodyLarge.copyWith(color: AppTheme.green),
                  ),
                ),
              ],
            ),
          )
        else if (_raffle.status == RaffleStatus.completed)
          CustomButton(
            text: 'View Winners',
            onPressed: () => _viewWinners(),
            icon: Icons.emoji_events,
            width: double.infinity,
          ),

        if (_raffle.creatorId == user.uid) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _editRaffle(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primaryGold),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Edit',
                    style: AppTheme.buttonMedium.copyWith(
                      color: AppTheme.primaryGold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _raffle.status == RaffleStatus.draft
                      ? () => _activateRaffle()
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    _raffle.status == RaffleStatus.draft
                        ? 'Activate'
                        : 'Active',
                    style: AppTheme.buttonMedium.copyWith(
                      color: AppTheme.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildRecentEntries() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Entries',
          style: AppTheme.headingMedium.copyWith(color: AppTheme.white),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<RaffleEntryModel>>(
          stream: RaffleService.getRaffleEntries(_raffle.id),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGold),
              );
            }

            final entries = snapshot.data!.take(10).toList();

            if (entries.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.darkGrey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'No entries yet',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                  ),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: AppTheme.darkGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryGold.withOpacity(0.2),
                      child: Text(
                        entry.userName[0].toUpperCase(),
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.primaryGold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    title: Text(
                      entry.userName,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.white,
                      ),
                    ),
                    subtitle: Text(
                      _formatEntryDate(entry.entryDate),
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                    ),
                    trailing: Text(
                      '#${index + 1}',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _enterRaffle(User user) async {
    setState(() => _isEntering = true);

    try {
      // Check wallet authentication
      final authResult = await SecureWalletService.authenticateAndDecryptWallet(
        user.uid,
        '', // Password will be prompted by the service
      );

      if (!authResult['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Wallet authentication failed: ${authResult['error']}',
            ),
            backgroundColor: AppTheme.red,
          ),
        );
        return;
      }

      // Create entry verification data
      final verificationData = {
        'walletAuthenticated': true,
        'timestamp': DateTime.now().toIso8601String(),
        'entryMethod': 'wallet_auth',
      };

      // Enter the raffle
      final entryId = await RaffleService.enterRaffle(
        raffleId: _raffle.id,
        userId: user.uid,
        userName: user.displayName ?? 'Anonymous',
        userEmail: user.email,
        verificationData: verificationData,
      );

      // Update local state
      final newEntry = RaffleEntryModel(
        id: entryId,
        raffleId: _raffle.id,
        userId: user.uid,
        userName: user.displayName ?? 'Anonymous',
        userEmail: user.email,
        entryDate: DateTime.now(),
        verificationData: verificationData,
      );

      setState(() {
        _userEntries.add(newEntry);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully entered the raffle!'),
          backgroundColor: AppTheme.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to enter raffle: $e'),
          backgroundColor: AppTheme.red,
        ),
      );
    } finally {
      setState(() => _isEntering = false);
    }
  }

  void _viewWinners() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RaffleWinnerAnnouncementScreen(raffle: _raffle),
      ),
    );
  }

  void _editRaffle() {
    // TODO: Navigate to edit screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit functionality coming soon!')),
    );
  }

  Future<void> _activateRaffle() async {
    try {
      await RaffleService.updateRaffleStatus(
        raffleId: _raffle.id,
        newStatus: RaffleStatus.active,
        creatorId: _raffle.creatorId,
      );

      // Update local raffle object and trigger rebuild
      setState(() {
        _raffle = _raffle.copyWith(status: RaffleStatus.active);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Raffle activated successfully!'),
          backgroundColor: AppTheme.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to activate raffle: $e'),
          backgroundColor: AppTheme.red,
        ),
      );
    }
  }

  Color _getStatusColor(RaffleStatus status) {
    switch (status) {
      case RaffleStatus.active:
        return AppTheme.green;
      case RaffleStatus.draft:
        return AppTheme.blue;
      case RaffleStatus.upcoming:
        return AppTheme.amber;
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.isNegative) {
      return 'Ended';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inMinutes}m';
    }
  }

  String _formatEntryDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
