import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/raffle_model.dart';
import '../../services/raffle_service.dart';
import '../../providers/admin_provider.dart';
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
      // Check if user has entered this raffle
      final hasEntered = await RaffleService.hasUserEnteredRaffle(
        user.uid,
        widget.raffle.id,
      );
      
      if (hasEntered) {
        final entry = await RaffleService.getUserRaffleEntry(
          user.uid,
          widget.raffle.id,
        );
        if (entry != null) {
          _userEntries = [entry];
        }
      }
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
          'How to Enter',
          style: AppTheme.headingMedium.copyWith(color: AppTheme.white),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.green.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.green, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Free Entry - Just Click "Enter Raffle" Button!',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
        displayText = 'Type: $value';
        icon = Icons.card_giftcard;
        break;
      case 'value':
        displayText = 'Value: $value';
        icon = Icons.attach_money;
        break;
      case 'description':
        displayText = value.toString();
        icon = Icons.description;
        break;
      case 'totalValue':
        displayText = 'Total Value: $value';
        icon = Icons.paid;
        break;
      default:
        displayText = '$key: $value';
        icon = Icons.star;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGold, size: 22),
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

        // Admin/Creator actions
        Builder(
          builder: (context) {
            final adminProvider = Provider.of<AdminProvider>(context);
            final isAdmin = adminProvider.isAdmin;
            final isCreator = _raffle.creatorId == user.uid;
            
            if (!isAdmin && !isCreator) {
              return const SizedBox.shrink();
            }

            return Column(
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (isCreator) ...[
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
                  ],
                ),
                const SizedBox(height: 12),
                // Delete button (Admin or Creator)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteRaffle(context, isAdmin),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: const Text('Delete Raffle'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: AppTheme.red,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
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
      // Simple entry - just click to join!
      final entryId = await RaffleService.enterRaffle(
        raffleId: _raffle.id,
        userId: user.uid,
        userName: user.displayName ?? 'Anonymous',
        userEmail: user.email ?? 'no-email@example.com',
      );

      // Update local state
      final newEntry = RaffleEntryModel(
        id: entryId,
        raffleId: _raffle.id,
        userId: user.uid,
        userName: user.displayName ?? 'Anonymous',
        userEmail: user.email,
        entryDate: DateTime.now(),
        verificationData: {
          'timestamp': DateTime.now().toIso8601String(),
          'entryMethod': 'simple_click',
        },
      );

      setState(() {
        _userEntries.add(newEntry);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 You\'re in! Good luck!'),
          backgroundColor: AppTheme.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.red,
          duration: const Duration(seconds: 4),
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

  Future<void> _deleteRaffle(BuildContext context, bool isAdmin) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text(
          'Delete Raffle?',
          style: AppTheme.headingMedium.copyWith(color: AppTheme.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${_raffle.title}"?',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
            ),
            const SizedBox(height: 12),
            if (_raffle.currentEntries > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: AppTheme.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This raffle has ${_raffle.currentEntries} entries. All entries and winners will be permanently deleted.',
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.red),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTheme.buttonMedium.copyWith(color: AppTheme.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.red,
            ),
            child: Text(
              'Delete',
              style: AppTheme.buttonMedium.copyWith(color: AppTheme.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGold),
      ),
    );

    try {
      await RaffleService.deleteRaffle(
        raffleId: _raffle.id,
        userId: user.uid,
        isAdmin: isAdmin,
      );

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Raffle deleted successfully'),
            backgroundColor: AppTheme.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Navigate back
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete raffle: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppTheme.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
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
