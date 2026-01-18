import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/raffle_model.dart';
import '../../services/raffle_service.dart';
import '../../services/raffle_cache_service.dart';
import '../../providers/admin_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive_layout.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/enhanced_image_widget.dart';
import 'raffle_detail_screen.dart';
import 'raffle_creation_screen.dart';

class RaffleHubScreen extends StatefulWidget {
  const RaffleHubScreen({Key? key}) : super(key: key);

  @override
  State<RaffleHubScreen> createState() => _RaffleHubScreenState();
}

class _RaffleHubScreenState extends State<RaffleHubScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  RaffleStatus? _statusFilter;
  String _sortBy = 'createdAt'; // createdAt, endDate, currentEntries
  bool _sortAscending = false;
  bool _isLoading = true;
  List<RaffleModel> _raffles = [];
  Stream<List<RaffleModel>>? _rafflesStream;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    // Try to load cached data first
    final cachedRaffles = await RaffleCacheService.getCachedRaffles();
    if (cachedRaffles != null) {
      setState(() {
        _raffles = cachedRaffles;
        _isLoading = false;
      });
    }

    // Set up real-time stream
    _setupRafflesStream();
  }

  void _setupRafflesStream() {
    // Automatically exclude completed raffles from the main list
    _rafflesStream = RaffleService.getRaffles(
      status: _statusFilter,
      isPublic: true,
      limit: 50,
      includeCompleted: false, // Hide completed raffles
    );

    // Cache the data when it updates
    _rafflesStream?.listen(
      (raffles) {
        print('📊 Received ${raffles.length} raffles from stream');
        RaffleCacheService.cacheRaffles(raffles);
        if (mounted) {
          setState(() {
            _raffles = _filterAndSortRaffles(raffles);
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        print('❌ Error in raffles stream: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  List<RaffleModel> _filterAndSortRaffles(List<RaffleModel> raffles) {
    // Apply search filter
    var filtered = raffles.where((raffle) {
      if (_searchQuery.isEmpty) return true;
      return raffle.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          raffle.description.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          raffle.creatorName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // Apply sorting
    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'endDate':
          comparison = a.endDate.compareTo(b.endDate);
          break;
        case 'currentEntries':
          comparison = a.currentEntries.compareTo(b.currentEntries);
          break;
        case 'createdAt':
        default:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  void _updateFilters() {
    if (_rafflesStream != null) {
      setState(() {
        _raffles = _filterAndSortRaffles(_raffles);
      });
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

          // Search and filters
          _buildSearchAndFilters(),

          // Recent Winners Section
          _buildRecentWinnersSection(),

          // Raffles list
          Expanded(child: _buildRafflesList()),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: AppTheme.black,
      title: Text(
        'Raffles',
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
          Text(
            'Raffle Hub',
            style: AppTheme.headingLarge.copyWith(color: AppTheme.primaryGold),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.darkGrey,
        border: Border(bottom: BorderSide(color: AppTheme.grey, width: 0.5)),
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
            decoration: InputDecoration(
              hintText: 'Search raffles...',
              hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
              prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGold),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppTheme.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _updateFilters();
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.black.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _updateFilters();
            },
          ),

          const SizedBox(height: 12),

          // Filters row
          Row(
            children: [
              // Status filter
              Expanded(
                child: _buildFilterDropdown(
                  label: 'Status',
                  value: _statusFilter,
                  items: {
                    null: 'All',
                    RaffleStatus.active: 'Active',
                    RaffleStatus.draft: 'Draft',
                    RaffleStatus.upcoming: 'Upcoming',
                    RaffleStatus.completed: 'Completed',
                  },
                  onChanged: (value) {
                    setState(() => _statusFilter = value);
                    _setupRafflesStream();
                  },
                ),
              ),

              const SizedBox(width: 12),

              // Sort by
              Expanded(
                child: _buildFilterDropdown(
                  label: 'Sort by',
                  value: _sortBy,
                  items: const {
                    'createdAt': 'Date Created',
                    'endDate': 'End Date',
                    'currentEntries': 'Entries',
                  },
                  onChanged: (value) {
                    setState(() => _sortBy = value!);
                    _updateFilters();
                  },
                ),
              ),

              const SizedBox(width: 12),

              // Sort direction
              IconButton(
                onPressed: () {
                  setState(() => _sortAscending = !_sortAscending);
                  _updateFilters();
                },
                icon: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  color: AppTheme.primaryGold,
                ),
                tooltip: _sortAscending ? 'Sort Ascending' : 'Sort Descending',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required String label,
    required T? value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.grey.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            label,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
          ),
          dropdownColor: AppTheme.darkGrey,
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryGold),
          isExpanded: true,
          items: items.entries.map((entry) {
            return DropdownMenuItem<T>(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildRafflesList() {
    if (_isLoading && _raffles.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGold),
      );
    }

    if (_raffles.isEmpty) {
      return _buildEmptyState();
    }

    return StreamBuilder<List<RaffleModel>>(
      stream: _rafflesStream,
      builder: (context, snapshot) {
        // Show loading only if we have no data at all
        if (snapshot.connectionState == ConnectionState.waiting && _raffles.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGold),
          );
        }

        if (snapshot.hasError) {
          print('❌ Stream error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading raffles',
                  style: AppTheme.bodyLarge.copyWith(color: AppTheme.red),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _setupRafflesStream();
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Use stream data if available, otherwise use cached data
        final raffles = _filterAndSortRaffles(snapshot.data ?? _raffles);

        if (raffles.isEmpty && !_isLoading) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: raffles.length,
          itemBuilder: (context, index) {
            return _buildRaffleCard(raffles[index]);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_activity_outlined, color: AppTheme.grey, size: 64),
          const SizedBox(height: 16),
          Text(
            'No raffles found',
            style: AppTheme.headingMedium.copyWith(color: AppTheme.grey),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search or filters'
                : 'Be the first to create a raffle!',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRaffleCard(RaffleModel raffle) {
    final isActive = raffle.isActive;
    final isExpired = raffle.isExpired;
    final progress = raffle.maxEntries > 0
        ? raffle.currentEntries / raffle.maxEntries
        : 0.0;
    final adminProvider = Provider.of<AdminProvider>(context);
    final isAdmin = adminProvider.isAdmin;
    final user = FirebaseAuth.instance.currentUser;
    final isCreator = user != null && raffle.creatorId == user.uid;

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
              // Image and basic info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Raffle image
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppTheme.grey.withOpacity(0.3),
                    ),
                    child: raffle.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: EnhancedImageWidget(
                              imageUrl: raffle.imageUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(
                            Icons.local_activity,
                            color: AppTheme.primaryGold,
                            size: 40,
                          ),
                  ),

                  const SizedBox(width: 16),

                  // Title and creator
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
                        Text(
                          'by ${raffle.creatorName}',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status badge and delete button
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(raffle.status),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStatusText(raffle.status),
                          style: AppTheme.bodyTiny.copyWith(
                            color: AppTheme.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Delete button (Admin/Creator only)
                      if (isAdmin || isCreator) ...[
                        const SizedBox(height: 4),
                        IconButton(
                          onPressed: () => _showDeleteDialog(raffle, isAdmin),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: AppTheme.red.withOpacity(0.7),
                          tooltip: 'Delete Raffle',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                raffle.description,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.white.withOpacity(0.8),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Progress and dates
              Column(
                children: [
                  // Entries progress
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
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.white,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Dates
                  Row(
                    children: [
                      Icon(Icons.schedule, color: AppTheme.grey, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Ends: ${_formatDate(raffle.endDate)}',
                        style: AppTheme.bodyTiny.copyWith(color: AppTheme.grey),
                      ),
                      const Spacer(),
                      if (raffle.canEnter)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    // Only show FAB for admins
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        // Ensure admin status is checked
        if (!adminProvider.isAdmin) {
          return const SizedBox.shrink(); // Hide button completely
        }
        
        return FloatingActionButton(
          onPressed: () => _navigateToCreateRaffle(),
          backgroundColor: AppTheme.primaryGold,
          foregroundColor: AppTheme.black,
          child: const Icon(Icons.add),
        );
      },
    );
  }

  void _navigateToRaffleDetail(RaffleModel raffle) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RaffleDetailScreen(raffle: raffle)),
    );
  }

  void _navigateToCreateRaffle() async {
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    
    // Double-check admin status before navigation
    await adminProvider.refreshAdminStatus();
    
    if (!adminProvider.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Denied: Only administrators can create raffles'),
          backgroundColor: AppTheme.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Additional check: verify admin status one more time after refresh
    if (!adminProvider.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Denied: Admin verification failed'),
          backgroundColor: AppTheme.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

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
        return AppTheme.blue;
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
      return '${difference.inDays}d left';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h left';
    } else {
      return '${difference.inMinutes}m left';
    }
  }

  Future<void> _showDeleteDialog(RaffleModel raffle, bool isAdmin) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
              'Are you sure you want to delete "${raffle.title}"?',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
            ),
            const SizedBox(height: 12),
            if (raffle.currentEntries > 0)
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
                        'This raffle has ${raffle.currentEntries} entries. All entries and winners will be permanently deleted.',
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
        raffleId: raffle.id,
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

  Widget _buildRecentWinnersSection() {
    return StreamBuilder<List<RaffleWinnerModel>>(
      stream: RaffleService.getAllRecentWinners(limit: 3),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final winners = snapshot.data!;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryGold.withOpacity(0.2),
                AppTheme.primaryGold.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: AppTheme.primaryGold, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      '🎉 Recent Winners',
                      style: AppTheme.headingSmall.copyWith(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ...winners.map((winner) => _buildWinnerItem(winner)).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWinnerItem(RaffleWinnerModel winner) {
    final metadata = winner.metadata ?? {};
    final raffleTitle = metadata['raffleTitle'] ?? 'Raffle';
    final raffleImage = metadata['raffleImage'];

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Winner avatar or raffle image
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: AppTheme.primaryGold.withOpacity(0.2),
            ),
            child: raffleImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: EnhancedImageWidget(
                      imageUrl: raffleImage,
                      fit: BoxFit.cover,
                    ),
                  )
                : Center(
                    child: Text(
                      winner.winnerName[0].toUpperCase(),
                      style: AppTheme.headingMedium.copyWith(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  winner.winnerName,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Won: $raffleTitle',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.star, color: AppTheme.primaryGold, size: 20),
        ],
      ),
    );
  }
}
