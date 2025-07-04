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

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({Key? key}) : super(key: key);

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                _buildAppBar(),
                _buildSearchBar(),
                _buildTabBar(),
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

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Row(
        children: [
          Text(
            'Community',
            style: AppTheme.headingLarge.copyWith(
              color: AppTheme.primaryGold,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryGold),
            onPressed: () {
              _showCreateCommunityDialog();
            },
          ),
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

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
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
        labelStyle: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold),
        unselectedLabelStyle: AppTheme.bodyMedium,
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
    return Column(
      children: [
        // Header section (scrollable if needed)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Communities row at the top
              Container(
                height: 80,
                color: AppTheme.black,
                child: ListView.builder(
                  shrinkWrap: true,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  itemCount: chatProvider.communities.length,
                  itemBuilder: (context, index) {
                    final community = chatProvider.communities[index];
                    final isSelected = chatProvider.selectedCommunityIndex == index;
                    return GestureDetector(
                      onTap: () {
                        chatProvider.setSelectedCommunity(index);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 16.0),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryGold : AppTheme.darkGrey,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryGold : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            community.name.substring(0, 2).toUpperCase(),
                            style: AppTheme.bodyMedium.copyWith(
                              color: isSelected ? AppTheme.black : AppTheme.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Community header and channel info
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: AppTheme.black,
                      border: Border(
                        bottom: BorderSide(
                          color: AppTheme.grey.withOpacity(0.3),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          selectedCommunity.name,
                          style: AppTheme.headingSmall.copyWith(
                            color: AppTheme.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.darkGrey,
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Text(
                            '${selectedCommunity.members} members',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.grey,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.menu, color: AppTheme.grey),
                          onPressed: () {
                            _showChannelsBottomSheet(selectedCommunity);
                          },
                        ),
                        if (selectedCommunity.createdBy == currentUserId)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await Provider.of<ChatProvider>(context, listen: false).deleteCommunity(selectedCommunity.id, imageUrl: selectedCommunity.imageUrl);
                            },
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: AppTheme.black,
                      border: Border(
                        bottom: BorderSide(
                          color: AppTheme.grey.withOpacity(0.3),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tag, color: AppTheme.grey, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          chatProvider.selectedChannel?.name ?? 'general',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${chatProvider.selectedChannel?.messages.length ?? 0} messages',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Messages (real-time)
        Expanded(
          child: selectedChannel == null
              ? Center(child: Text('No channel selected'))
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
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: AppTheme.bodyLarge.copyWith(color: AppTheme.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to start a conversation!',
                              style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                            ),
                          ],
                        ),
                      );
                    }
                    final messages = snapshot.data!.docs;
                    return ListView.builder(
                      padding: const EdgeInsets.all(16.0),
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
                        );
                      },
                    );
                  },
                ),
        ),
        
        // Message input
        Column(
          children: [
            // Reply UI
            if (chatProvider.replyToMessage != null)
              Container(
                padding: const EdgeInsets.all(8.0),
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
                          Row(
                            children: [
                              Text(
                                'Reply to ${chatProvider.replyToMessage!.senderName}',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.primaryGold,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
            
            // Message input
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppTheme.darkGrey.withOpacity(0.3),
                border: Border(
                  top: BorderSide(
                    color: AppTheme.grey.withOpacity(0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppTheme.grey),
                    onPressed: _showAttachmentOptions,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: chatProvider.replyToMessage != null 
                            ? 'Reply to ${chatProvider.replyToMessage!.senderName}...' 
                            : 'Type a message...',
                        hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppTheme.darkGrey,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.image, color: AppTheme.primaryGold),
                    onPressed: () async {
                      final file = await Provider.of<ChatProvider>(context, listen: false).pickImageForMessage();
                      if (file != null) {
                        setState(() => _isSendingMessage = true);
                        await Provider.of<ChatProvider>(context, listen: false).sendMessage('', imageFile: file);
                        setState(() => _isSendingMessage = false);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _isSendingMessage
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send, color: AppTheme.primaryGold),
                        onPressed: _sendMessage,
                      ),
                ],
              ),
            ),
          ],
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

  Widget _buildMessageItem(Message message, int index) {
    final authProvider = Provider.of<local_auth.AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final currentUser = authProvider.user;
    final isCurrentUser = currentUser?.uid == message.senderId;
    final currentUserId = currentUser?.uid ?? 'current_user';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          child: MessageBubble(
            message: message,
            isCurrentUser: isCurrentUser,
            currentUserId: currentUserId,
            onReply: (msg) {
              chatProvider.setReplyToMessage(msg);
              // Focus the text field
              FocusScope.of(context).requestFocus(FocusNode());
              Future.delayed(const Duration(milliseconds: 100), () {
                FocusScope.of(context).requestFocus(FocusNode());
              });
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
            height: 1,
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
            ...community.channels.asMap().entries.map((entry) {
              final index = entry.key;
              final channel = entry.value;
              final chatProvider = Provider.of<ChatProvider>(context, listen: false);
              final isSelected = chatProvider.selectedChannelIndex == index;
              
              return ListTile(
                leading: Icon(
                  Icons.tag,
                  color: isSelected ? AppTheme.primaryGold : AppTheme.grey,
                ),
                title: Text(
                  channel.name,
                  style: AppTheme.bodyMedium.copyWith(
                    color: isSelected ? AppTheme.primaryGold : AppTheme.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected 
                    ? const Icon(Icons.check, color: AppTheme.primaryGold)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  chatProvider.setSelectedChannel(index);
                },
              );
            }).toList(),
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
    } catch (e) {
      print('Error sending message: $e');
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