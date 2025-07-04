import 'package:flutter/material.dart';
import '../screens/community_screen.dart';
import '../theme/app_theme.dart';
import 'reaction_bubble.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isCurrentUser;
  final String currentUserId;
  final Function(Message) onReply;
  final Function(Message) onShowOptions;
  final Function(Message, String) onReactionTap;
  final Function(Message) onShowReactions;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isCurrentUser,
    required this.currentUserId,
    required this.onReply,
    required this.onShowOptions,
    required this.onReactionTap,
    required this.onShowReactions,
  }) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              backgroundColor: isCurrentUser ? Colors.blue : AppTheme.primaryGold,
              radius: 22,
              child: Text(
                message.senderName[0].toUpperCase(),
                style: AppTheme.headingMedium.copyWith(
                  color: AppTheme.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Message content
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sender name and timestamp
                    Row(
                      children: [
                        Text(
                          isCurrentUser ? 'You' : message.senderName,
                          style: AppTheme.bodyLarge.copyWith(
                            color: isCurrentUser ? Colors.blue : AppTheme.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatTimestamp(message.timestamp),
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    // Reply reference
                    if (message.replyToId != null && message.replyToContent != null)
                      _buildReplyReference(),
                    const SizedBox(height: 8),
                    // Message content
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                      decoration: BoxDecoration(
                        color: isCurrentUser 
                            ? Colors.blue.withOpacity(0.18) 
                            : AppTheme.darkGrey.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isCurrentUser 
                              ? Colors.blue.withOpacity(0.3) 
                              : AppTheme.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        message.content,
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Reactions
                    ReactionBar(
                      reactions: message.reactions,
                      currentUserId: currentUserId,
                      onReactionTap: (emoji) => onReactionTap(message, emoji),
                    ),
                    const SizedBox(height: 10),
                    // Message actions
                    Row(
                      children: [
                        _buildMessageAction(
                          icon: Icons.emoji_emotions_outlined,
                          label: 'React',
                          onTap: () => onShowReactions(message),
                        ),
                        const SizedBox(width: 20),
                        _buildMessageAction(
                          icon: Icons.reply,
                          label: 'Reply',
                          onTap: () => onReply(message),
                        ),
                        const SizedBox(width: 20),
                        _buildMessageAction(
                          icon: Icons.more_horiz,
                          label: 'More',
                          onTap: () => onShowOptions(message),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildReplyReference() {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: AppTheme.primaryGold.withOpacity(0.5),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.reply,
                color: AppTheme.grey,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                'Reply to ${message.replyToSenderName}',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message.replyToContent!,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.grey,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: AppTheme.grey,
            size: 16,
          ),
          const SizedBox(width: 4),
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
}