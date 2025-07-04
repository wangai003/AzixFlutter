import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ReactionBubble extends StatelessWidget {
  final String emoji;
  final int count;
  final bool hasReacted;
  final VoidCallback onTap;
  final bool showCount;
  final double size;

  const ReactionBubble({
    Key? key,
    required this.emoji,
    required this.count,
    required this.hasReacted,
    required this.onTap,
    this.showCount = true,
    this.size = 1.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 8.0 * size,
          vertical: 4.0 * size,
        ),
        decoration: BoxDecoration(
          color: hasReacted 
              ? AppTheme.primaryGold.withOpacity(0.2) 
              : AppTheme.darkGrey,
          borderRadius: BorderRadius.circular(12.0 * size),
          border: hasReacted
              ? Border.all(color: AppTheme.primaryGold, width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: TextStyle(fontSize: 16.0 * size),
            ),
            if (showCount && count > 0) ...[
              SizedBox(width: 4.0 * size),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12.0 * size,
                  color: hasReacted 
                      ? AppTheme.primaryGold 
                      : AppTheme.white,
                  fontWeight: hasReacted 
                      ? FontWeight.bold 
                      : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ReactionPicker extends StatelessWidget {
  final Function(String) onEmojiSelected;
  final Map<String, List<String>> currentReactions;
  final String currentUserId;

  const ReactionPicker({
    Key? key,
    required this.onEmojiSelected,
    required this.currentReactions,
    required this.currentUserId,
  }) : super(key: key);

  bool _hasUserReacted(String emoji) {
    return currentReactions[emoji]?.contains(currentUserId) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    const emojis = [
      '👍', '❤️', '😂', '😮', '😢', '😡', '🎉', '👀', '🔥', '💯', '🙏', '👏', '🤔', '🤩', '🥳'
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12.0,
        runSpacing: 12.0,
        children: emojis.map((emoji) {
          final hasReacted = _hasUserReacted(emoji);
          
          return GestureDetector(
            onTap: () => onEmojiSelected(emoji),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: hasReacted ? AppTheme.primaryGold.withOpacity(0.2) : AppTheme.black,
                borderRadius: BorderRadius.circular(12),
                border: hasReacted
                    ? Border.all(color: AppTheme.primaryGold, width: 2)
                    : null,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  if (hasReacted)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryGold,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: AppTheme.black,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ReactionBar extends StatelessWidget {
  final Map<String, List<String>> reactions;
  final String currentUserId;
  final Function(String) onReactionTap;

  const ReactionBar({
    Key? key,
    required this.reactions,
    required this.currentUserId,
    required this.onReactionTap,
  }) : super(key: key);

  bool _hasUserReacted(String emoji) {
    return reactions[emoji]?.contains(currentUserId) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: reactions.entries.map((entry) {
        final emoji = entry.key;
        final users = entry.value;
        final hasReacted = _hasUserReacted(emoji);
        
        return ReactionBubble(
          emoji: emoji,
          count: users.length,
          hasReacted: hasReacted,
          onTap: () => onReactionTap(emoji),
        );
      }).toList(),
    );
  }
}