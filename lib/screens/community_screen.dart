import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/auth_provider.dart' as local_auth;
import '../theme/app_theme.dart';
import '../services/chat_service.dart';
import '../widgets/reaction_bubble.dart';
import '../widgets/message_bubble.dart';
import '../providers/chat_provider.dart';
import '../utils/responsive_layout.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({Key? key}) : super(key: key);

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Loading state for message sending
  bool _isSendingMessage = false;
  
  // Chat service for direct API access if needed
  late ChatService _chatService;
  
  // Stream subscriptions
  Stream<List<Message>>? _messagesStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _chatService = ChatService();
    
    // Initialize the chat provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      
      // Load real data from Firestore
      chatProvider.loadCommunities();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                _buildAppBar(isMobile: isMobile),
                if (!isMobile) _buildSearchBar(),
                _buildTabBar(isMobile: isMobile),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildJoinedCommunitiesTab(),
                      _buildDiscoverCommunitiesTab(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar({required bool isMobile}) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12.0 : 20.0,
        vertical: isMobile ? 8.0 : 16.0,
      ),
      child: Row(
        children: [
          Text(
            'Community',
            style: AppTheme.headingLarge.copyWith(
              color: AppTheme.primaryGold,
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 20 : 24,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.add_circle_outline,
              color: AppTheme.primaryGold,
              size: isMobile ? 20 : 24,
            ),
            padding: EdgeInsets.all(isMobile ? 8 : 12),
            constraints: BoxConstraints(),
            onPressed: () {
              _showCreateCommunityDialog();
            },
          ),
          if (!isMobile)
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: AppTheme.primaryGold),
              onPressed: () {},
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.1, 1.1),
                  duration: const Duration(seconds: 2),
                ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 500))
        .slideY(begin: -0.2, end: 0, curve: Curves.easeOut);
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.darkGrey.withOpacity(0.5),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppTheme.grey.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppTheme.grey),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
                decoration: InputDecoration(
                  hintText: 'Search communities...',
                  hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 500),
          delay: const Duration(milliseconds: 200),
        )
        .slideY(begin: -0.2, end: 0, curve: Curves.easeOut);
  }

  Widget _buildTabBar({required bool isMobile}) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 12.0 : 20.0,
        vertical: isMobile ? 4.0 : 8.0,
      ),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(30),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: AppTheme.primaryGold,
        ),
        labelColor: AppTheme.black,
        unselectedLabelColor: AppTheme.grey,
        labelStyle: AppTheme.bodyMedium.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: isMobile ? 13 : 14,
        ),
        unselectedLabelStyle: AppTheme.bodyMedium.copyWith(
          fontSize: isMobile ? 13 : 14,
        ),
        tabs: const [
          Tab(text: 'Joined'),
          Tab(text: 'Discover'),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 500),
          delay: const Duration(milliseconds: 300),
        );
  }

  Widget _buildJoinedCommunitiesTab() {
    final chatProvider = Provider.of<ChatProvider>(context);
    if (chatProvider.communities.isEmpty) {
      return _buildEmptyCommunityState();
    }
    final selectedCommunity = chatProvider.selectedCommunity;
    if (selectedCommunity == null) {
      return _buildEmptyCommunityState();
    }
    final currentUserId = Provider.of<local_auth.AuthProvider>(context).user?.uid;
    final selectedChannel = chatProvider.selectedChannel;
    // Mark messages as read when entering chat
    if (selectedChannel != null && currentUserId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        chatProvider.markMessagesAsRead(selectedCommunity.id, selectedChannel.id, currentUserId);
      });
    }
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isCompact = constraints.maxWidth < 900;
              final bool isNarrow = constraints.maxWidth < 600;
              final isMobile = ResponsiveLayout.isMobile(context);
              if (isCompact) {
                return Column(
                  children: [
                    _buildCommunityStrip(chatProvider, currentUserId, isNarrow, isMobile: isMobile),
                    _buildChatHeader(
                      selectedCommunity,
                      chatProvider,
                      currentUserId,
                      isCompact: true,
                      isNarrow: isNarrow,
                      isMobile: isMobile,
                    ),
                    _buildMessagesSection(selectedCommunity, selectedChannel, currentUserId, isMobile: isMobile),
                    _buildComposer(chatProvider, isCompact: true, isMobile: isMobile),
                  ],
                );
              }
              return Row(
                children: [
                  _buildCommunityRail(chatProvider, currentUserId),
                  Expanded(
                    child: Column(
                      children: [
                        _buildChatHeader(
                          selectedCommunity,
                          chatProvider,
                          currentUserId,
                          isCompact: false,
                          isNarrow: false,
                          isMobile: false,
                        ),
                        _buildMessagesSection(selectedCommunity, selectedChannel, currentUserId, isMobile: false),
                        _buildComposer(chatProvider, isCompact: false, isMobile: false),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCommunityState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_outlined,
            color: AppTheme.grey,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'You haven\'t joined any communities yet',
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Discover and join communities to get started',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _tabController.animateTo(1);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: AppTheme.black,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              'Discover Communities',
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityStrip(ChatProvider chatProvider, String? currentUserId, bool isNarrow, {required bool isMobile}) {
    return Container(
      height: isMobile ? 50 : (isNarrow ? 64 : 72),
      decoration: BoxDecoration(
        color: AppTheme.black,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.grey.withOpacity(0.2),
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8.0 : 12.0,
          vertical: isMobile ? 6.0 : (isNarrow ? 10.0 : 12.0),
        ),
        itemCount: chatProvider.communities.length,
        itemBuilder: (context, index) {
          final community = chatProvider.communities[index];
          final isSelected = chatProvider.selectedCommunityIndex == index;
          return _buildCommunityTile(
            chatProvider: chatProvider,
            community: community,
            isSelected: isSelected,
            currentUserId: currentUserId,
            margin: EdgeInsets.only(right: isMobile ? 8.0 : 12.0),
            isMobile: isMobile,
            onTap: () => chatProvider.setSelectedCommunity(index),
          );
        },
      ),
    );
  }

  Widget _buildCommunityRail(ChatProvider chatProvider, String? currentUserId) {
    return Container(
      width: 96,
      decoration: BoxDecoration(
        color: AppTheme.black,
        border: Border(
          right: BorderSide(
            color: AppTheme.grey.withOpacity(0.2),
          ),
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        itemCount: chatProvider.communities.length,
        itemBuilder: (context, index) {
          final community = chatProvider.communities[index];
          final isSelected = chatProvider.selectedCommunityIndex == index;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: _buildCommunityTile(
              chatProvider: chatProvider,
              community: community,
              isSelected: isSelected,
              currentUserId: currentUserId,
              margin: EdgeInsets.zero,
              onTap: () => chatProvider.setSelectedCommunity(index),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCommunityTile({
    required ChatProvider chatProvider,
    required Community community,
    required bool isSelected,
    required String? currentUserId,
    required EdgeInsets margin,
    required VoidCallback onTap,
    bool isMobile = false,
  }) {
    return Tooltip(
      message: community.name,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              margin: margin,
              width: isMobile ? 40 : 52,
              height: isMobile ? 40 : 52,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryGold : AppTheme.darkGrey,
                borderRadius: BorderRadius.circular(isMobile ? 12.0 : 16.0),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryGold : Colors.transparent,
                  width: 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryGold.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  community.name.substring(0, 2).toUpperCase(),
                  style: AppTheme.bodyMedium.copyWith(
                    color: isSelected ? AppTheme.black : AppTheme.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 12 : 14,
                  ),
                ),
              ),
            ),
            if (currentUserId != null)
              Positioned(
                right: -2,
                top: -2,
                child: FutureBuilder<int>(
                  future: chatProvider.getUnreadCount(
                    community.id,
                    community.channels.isNotEmpty ? community.channels[0].id : 'general',
                    currentUserId,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data! > 0) {
                      return Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${snapshot.data}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatHeader(
    Community selectedCommunity,
    ChatProvider chatProvider,
    String? currentUserId, {
    required bool isCompact,
    required bool isNarrow,
    required bool isMobile,
  }) {
    final channelName = chatProvider.selectedChannel?.name ?? 'general';
    final messageCount = chatProvider.selectedChannel?.messages.length ?? 0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10.0 : 16.0,
        vertical: isMobile ? 6.0 : (isCompact ? 10.0 : 16.0),
      ),
      decoration: BoxDecoration(
        color: AppTheme.black,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.grey.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  selectedCommunity.name,
                  style: AppTheme.headingSmall.copyWith(
                    color: AppTheme.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 16 : 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isNarrow || isMobile)
                IconButton(
                  icon: Icon(Icons.menu, color: AppTheme.grey, size: isMobile ? 20 : 24),
                  padding: EdgeInsets.all(isMobile ? 4 : 8),
                  constraints: BoxConstraints(),
                  onPressed: () => _showChannelsBottomSheet(selectedCommunity),
                )
              else
                TextButton.icon(
                  onPressed: () => _showChannelsBottomSheet(selectedCommunity),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryGold,
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.tag, size: 18),
                  label: Text(
                    channelName,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (selectedCommunity.createdBy == currentUserId && !isMobile)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  padding: EdgeInsets.all(isMobile ? 4 : 8),
                  constraints: BoxConstraints(),
                  onPressed: () async {
                    await Provider.of<ChatProvider>(context, listen: false)
                        .deleteCommunity(selectedCommunity.id, imageUrl: selectedCommunity.imageUrl);
                  },
                ),
            ],
          ),
          if (!isMobile) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildHeaderPill(
                  icon: Icons.people,
                  label: '${selectedCommunity.members} members',
                ),
                _buildHeaderPill(
                  icon: Icons.tag,
                  label: '#$channelName',
                ),
                _buildHeaderPill(
                  icon: Icons.chat_bubble_outline,
                  label: '$messageCount messages',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.grey.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.grey),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesSection(
    Community selectedCommunity,
    Channel? selectedChannel,
    String? currentUserId, {
    required bool isMobile,
  }) {
    return Expanded(
      child: selectedChannel == null
          ? Center(
              child: Text(
                'No channel selected',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('communities')
                  .doc(selectedCommunity.id)
                  .collection('channels')
                  .doc(selectedChannel.id)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: AppTheme.grey,
                          size: isMobile ? 48 : 64,
                        ),
                        SizedBox(height: isMobile ? 12 : 16),
                        Text(
                          'No messages yet',
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.white,
                            fontSize: isMobile ? 16 : 18,
                          ),
                        ),
                        SizedBox(height: isMobile ? 6 : 8),
                        Text(
                          'Be the first to start a conversation!',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.grey,
                            fontSize: isMobile ? 13 : 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final messages = snapshot.data!.docs;
                
                // Auto-scroll to latest message when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients && messages.isNotEmpty) {
                    // Use a small delay to ensure ListView has rendered
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (_scrollController.hasClients) {
                        // Scroll to the bottom (latest message)
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    });
                  }
                });
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 10 : 16,
                    isMobile ? 8 : 12,
                    isMobile ? 10 : 16,
                    isMobile ? 8 : 12,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    DateTime timestamp;
                    if (data['timestamp'] is Timestamp) {
                      timestamp = (data['timestamp'] as Timestamp).toDate();
                    } else if (data['timestamp'] is DateTime) {
                      timestamp = data['timestamp'] as DateTime;
                    } else if (data['timestamp'] is String) {
                      timestamp = DateTime.tryParse(data['timestamp']) ?? DateTime.now();
                    } else {
                      timestamp = DateTime.now();
                    }
                    return _buildMessageItem(
                      Message(
                        id: messages[index].id,
                        senderId: data['senderId'] ?? '',
                        senderName: data['senderName'] ?? '',
                        content: data['content'] ?? '',
                        timestamp: timestamp,
                        reactions: Map<String, List<String>>.from(
                          (data['reactions'] as Map<String, dynamic>? ?? {}).map(
                            (key, value) => MapEntry(key, List<String>.from(value ?? [])),
                          ),
                        ),
                        replyToId: data['replyToId'],
                        replyToContent: data['replyToContent'],
                        replyToSenderName: data['replyToSenderName'],
                        imageUrl: data['imageUrl'],
                      ),
                      index,
                      isMobile: isMobile,
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildComposer(ChatProvider chatProvider, {required bool isCompact, required bool isMobile}) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (chatProvider.replyToMessage != null)
              Container(
                padding: EdgeInsets.all(isMobile ? 6.0 : 8.0),
                decoration: BoxDecoration(
                  color: AppTheme.darkGrey.withOpacity(0.5),
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.grey.withOpacity(0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reply to ${chatProvider.replyToMessage!.senderName}',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.primaryGold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            chatProvider.replyToMessage!.content,
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.grey, size: 20),
                      onPressed: () {
                        chatProvider.clearReplyToMessage();
                      },
                    ),
                  ],
                ),
              ),
            Container(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 8 : 12,
                isMobile ? 6 : 10,
                isMobile ? 8 : 12,
                isMobile ? 8 : 12,
              ),
              decoration: BoxDecoration(
                color: AppTheme.darkGrey.withOpacity(0.3),
                border: Border(
                  top: BorderSide(
                    color: AppTheme.grey.withOpacity(0.3),
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: AppTheme.grey,
                      size: isMobile ? 20 : 24,
                    ),
                    padding: EdgeInsets.all(isMobile ? 4 : 8),
                    constraints: BoxConstraints(),
                    onPressed: _showAttachmentOptions,
                  ),
                  SizedBox(width: isMobile ? 4 : 6),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.white,
                        fontSize: isMobile ? 14 : 16,
                      ),
                      minLines: 1,
                      maxLines: isMobile ? 3 : (isCompact ? 4 : 6),
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: chatProvider.replyToMessage != null
                            ? 'Reply to ${chatProvider.replyToMessage!.senderName}...'
                            : 'Type a message...',
                        hintStyle: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.grey,
                          fontSize: isMobile ? 14 : 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(isMobile ? 18 : 22),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppTheme.darkGrey,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12.0 : 14.0,
                          vertical: isMobile ? 10.0 : 12.0,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isMobile ? 4 : 6),
                  IconButton(
                    icon: Icon(
                      Icons.image,
                      color: AppTheme.primaryGold,
                      size: isMobile ? 20 : 24,
                    ),
                    padding: EdgeInsets.all(isMobile ? 4 : 8),
                    constraints: BoxConstraints(),
                    onPressed: () async {
                      final file = await Provider.of<ChatProvider>(context, listen: false).pickImageForMessage();
                      if (file != null) {
                        setState(() => _isSendingMessage = true);
                        await Provider.of<ChatProvider>(context, listen: false).sendMessage('', imageFile: file);
                        setState(() => _isSendingMessage = false);
                        
                        // Scroll to bottom after sending image
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scrollController.hasClients) {
                            Future.delayed(const Duration(milliseconds: 100), () {
                              if (_scrollController.hasClients) {
                                _scrollController.animateTo(
                                  _scrollController.position.maxScrollExtent,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              }
                            });
                          }
                        });
                      }
                    },
                  ),
                  SizedBox(width: isMobile ? 2 : 4),
                  _isSendingMessage
                      ? SizedBox(
                          width: isMobile ? 20 : 24,
                          height: isMobile ? 20 : 24,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
                          ),
                        )
                      : ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _messageController,
                          builder: (context, value, _) {
                            final hasText = value.text.trim().isNotEmpty;
                            return IconButton(
                              icon: Icon(
                                Icons.send,
                                size: isMobile ? 20 : 24,
                                color: hasText ? AppTheme.primaryGold : AppTheme.grey,
                              ),
                              padding: EdgeInsets.all(isMobile ? 4 : 8),
                              constraints: BoxConstraints(),
                              onPressed: hasText ? _sendMessage : null,
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(Message message, int index, {bool isMobile = false}) {
    final authProvider = Provider.of<local_auth.AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final currentUser = authProvider.user;
    final isCurrentUser = currentUser?.uid == message.senderId;
    final currentUserId = currentUser?.uid ?? 'current_user';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(bottom: isMobile ? 10.0 : 16.0),
          child: MessageBubble(
            message: message,
            isCurrentUser: isCurrentUser,
            currentUserId: currentUserId,
            onReply: (msg) {
              chatProvider.setReplyToMessage(msg);
              FocusScope.of(context).requestFocus(_messageFocusNode);
            },
            onShowOptions: (msg) {
              _showMessageOptions(msg);
            },
            onReactionTap: (msg, emoji) {
              _toggleReaction(msg, emoji);
            },
            onShowReactions: (msg) {
              _showReactionsDialog(msg);
            },
          ),
        )
            .animate()
            .fadeIn(
              duration: const Duration(milliseconds: 600),
              delay: Duration(milliseconds: 100 * index),
            )
            .slideY(
              begin: 0.1,
              end: 0,
              curve: Curves.easeOut,
              duration: const Duration(milliseconds: 600),
            ),
        
        // Divider between messages
        if (index < chatProvider.selectedChannel!.messages.length - 1)
          Divider(
            color: AppTheme.grey.withOpacity(0.1),
            height: isMobile ? 0.5 : 1,
          ),
      ],
    );
  }
  
  // Toggle a reaction on a message
  void _toggleReaction(Message message, String emoji) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.toggleReaction(message, emoji);
  }
  
  // Show message options
  void _showMessageOptions(Message message) {
    final authProvider = Provider.of<local_auth.AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;
    final isCurrentUser = currentUser?.uid == message.senderId;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: AppTheme.primaryGold),
              title: Text(
                'Reply',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
              ),
              onTap: () {
                Navigator.pop(context);
                final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                chatProvider.setReplyToMessage(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: AppTheme.primaryGold),
              title: Text(
                'Copy Text',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
              ),
              onTap: () {
                Navigator.pop(context);
                // Copy message text to clipboard
              },
            ),
            if (isCurrentUser)
              ListTile(
                leading: const Icon(Icons.edit, color: AppTheme.primaryGold),
                title: Text(
                  'Edit Message',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Show edit message dialog
                },
              ),
            if (isCurrentUser)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(
                  'Delete Message',
                  style: AppTheme.bodyMedium.copyWith(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Show delete confirmation dialog
                },
              ),
          ],
        ),
      ),
    );
  }

  // Message action methods are now handled by the MessageBubble widget

  Widget _buildDiscoverCommunitiesTab() {
    final chatProvider = Provider.of<ChatProvider>(context);
    
    return ListView.builder(
      padding: const EdgeInsets.all(20.0),
      itemCount: chatProvider.discoverCommunities.length,
      itemBuilder: (context, index) {
        final community = chatProvider.discoverCommunities[index];
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          decoration: BoxDecoration(
            color: AppTheme.darkGrey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: AppTheme.grey.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold,
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Center(
                        child: Text(
                          community.name.substring(0, 2).toUpperCase(),
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            community.name,
                            style: AppTheme.headingSmall.copyWith(
                              color: AppTheme.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            community.description,
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 6.0,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.darkGrey,
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.people,
                            color: AppTheme.grey,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${community.members} members',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 6.0,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.darkGrey,
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            community.isPrivate ? Icons.lock : Icons.public,
                            color: AppTheme.grey,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            community.isPrivate ? 'Private' : 'Public',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        // Join the community
                        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                        chatProvider.joinCommunity(community);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGold,
                        foregroundColor: AppTheme.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Join',
                        style: AppTheme.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        )
            .animate()
            .fadeIn(
              duration: const Duration(milliseconds: 600),
              delay: Duration(milliseconds: 100 * index),
            )
            .slideY(
              begin: 0.1,
              end: 0,
              curve: Curves.easeOut,
              duration: const Duration(milliseconds: 600),
            );
      },
    );
  }

  void _showReactionsDialog(Message message) {
    final authProvider = Provider.of<local_auth.AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;
    final currentUserId = currentUser?.uid ?? 'current_user';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Add Reaction',
          style: AppTheme.headingSmall.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: ReactionPicker(
          currentReactions: message.reactions,
          currentUserId: currentUserId,
          onEmojiSelected: (emoji) {
            Navigator.of(context).pop();
            _toggleReaction(message, emoji);
          },
        ),
      ),
    );
  }

  void _showChannelsBottomSheet(Community community) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final currentUserId = Provider.of<local_auth.AuthProvider>(context).user?.uid;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Channels',
              style: AppTheme.headingMedium.copyWith(
                color: AppTheme.primaryGold,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              itemCount: community.channels.length,
              itemBuilder: (context, index) {
                final channel = community.channels[index];
                return ListTile(
                  title: Text(channel.name, style: AppTheme.bodyMedium.copyWith(color: AppTheme.white)),
                  trailing: currentUserId != null
                    ? FutureBuilder<int>(
                        future: chatProvider.getUnreadCount(
                          community.id,
                          channel.id,
                          currentUserId,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data! > 0) {
                            return Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${snapshot.data}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      )
                    : null,
                  onTap: () {
                    chatProvider.setSelectedChannel(index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Members',
              style: AppTheme.headingMedium.copyWith(
                color: AppTheme.primaryGold,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.person,
                color: AppTheme.grey,
              ),
              title: Text(
                'Online: 42',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateCommunityDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: AppTheme.primaryGold,
            width: 2,
          ),
        ),
        title: Text(
          'Create Community',
          style: AppTheme.headingMedium.copyWith(
            color: AppTheme.primaryGold,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
              decoration: InputDecoration(
                labelText: 'Community Name',
                labelStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.grey.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.grey.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryGold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.grey.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.grey.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryGold,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'Cancel',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.grey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                
                try {
                  await chatProvider.createCommunity(
                    name: nameController.text,
                    description: descriptionController.text,
                    isPrivate: false,
                  );
                  
                  Navigator.of(context).pop();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Community created successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to create community: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: AppTheme.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              'Create',
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Send a message
  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    setState(() {
      _isSendingMessage = true;
    });

    try {
      final content = _messageController.text.trim();
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      
      await chatProvider.sendMessage(content);
      _messageController.clear();
      
      // Scroll to bottom after sending message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSendingMessage = false;
      });
    }
  }
  
  // Show attachment options
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Attach',
              style: AppTheme.headingMedium.copyWith(
                color: AppTheme.primaryGold,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.photo,
                  label: 'Photo',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Implement photo attachment
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Implement camera attachment
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.file_present,
                  label: 'File',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Implement file attachment
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.location_on,
                  label: 'Location',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Implement location attachment
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Build attachment option
  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryGold,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.white,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
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

class Community {
  final String id;
  final String name;
  final String description;
  final int members;
  final bool isPrivate;
  final List<Channel> channels;
  final String? createdBy;
  final String? imageUrl;

  Community({
    required this.id,
    required this.name,
    required this.description,
    required this.members,
    required this.isPrivate,
    required this.channels,
    this.createdBy,
    this.imageUrl,
  });
}

class Channel {
  final String id;
  final String name;
  final List<Message> messages;

  Channel({
    required this.id,
    required this.name,
    required this.messages,
  });
}

class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  Map<String, List<String>> reactions; // Changed to track who reacted
  final String? replyToId; // ID of the message this is replying to
  final String? replyToContent; // Content of the message this is replying to
  final String? replyToSenderName; // Name of the sender of the replied message
  final String? imageUrl;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.reactions,
    this.replyToId,
    this.replyToContent,
    this.replyToSenderName,
    this.imageUrl,
  });

  // Convert Firestore data to Message
  factory Message.fromFirestore(Map<String, dynamic> data, String id) {
    return Message(
      id: id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      reactions: Map<String, List<String>>.from(
        (data['reactions'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(key, List<String>.from(value ?? [])),
        ),
      ),
      replyToId: data['replyToId'],
      replyToContent: data['replyToContent'],
      replyToSenderName: data['replyToSenderName'],
      imageUrl: data['imageUrl'],
    );
  }

  // Convert Message to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'reactions': reactions,
      'replyToId': replyToId,
      'replyToContent': replyToContent,
      'replyToSenderName': replyToSenderName,
      'imageUrl': imageUrl,
    };
  }

  // Get the count of reactions for a specific emoji
  int getReactionCount(String emoji) {
    return reactions[emoji]?.length ?? 0;
  }

  // Check if a user has reacted with a specific emoji
  bool hasUserReacted(String emoji, String userId) {
    return reactions[emoji]?.contains(userId) ?? false;
  }
}
