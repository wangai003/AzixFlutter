import 'package:flutter/material.dart';
import '../models/explore_content.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/admin_provider.dart';

class ArticleDetailScreen extends StatelessWidget {
  final ExploreContentModel article;
  const ArticleDetailScreen({Key? key, required this.article}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid ?? '';
    final isLiked = article.isLikedBy(userId);
    final isBookmarked = article.isBookmarkedBy(userId);
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    final readTime = _estimateReadTime(article.content ?? article.description);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        iconTheme: const IconThemeData(color: AppTheme.primaryGold),
        title: Text(
          article.title,
          style: const TextStyle(color: AppTheme.primaryGold),
        ),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.black, Color(0xFF212121)],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      article.imageUrl!,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        article.category[0].toUpperCase() + article.category.substring(1),
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.primaryGold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (article.isFeatured)
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  article.title,
                  style: AppTheme.headingLarge.copyWith(
                    color: AppTheme.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  article.content ?? article.description,
                  style: AppTheme.bodyLarge.copyWith(color: AppTheme.white),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _buildActionButton(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      'Like${article.likeTotal > 0 ? ' (${article.likeTotal})' : ''}',
                      isLiked ? Colors.red : AppTheme.primaryGold,
                      () {
                        if (isLiked) {
                          adminProvider.unlikeArticle(article.id, userId);
                        } else {
                          adminProvider.likeArticle(article.id, userId);
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    _buildActionButton(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      'Save',
                      isBookmarked ? Colors.amber : AppTheme.primaryGold,
                      () {
                        if (isBookmarked) {
                          adminProvider.unbookmarkArticle(article.id, userId);
                        } else {
                          adminProvider.bookmarkArticle(article.id, userId);
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    _buildActionButton(Icons.share, 'Share', AppTheme.primaryGold, () {
                      // Implement share logic
                    }),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text('By Admin', style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
                    const SizedBox(width: 12),
                    if (article.createdAt != null)
                      Text(
                        'Published: ${article.createdAt.day}/${article.createdAt.month}/${article.createdAt.year}',
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                      ),
                    const SizedBox(width: 12),
                    Text(readTime, style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _estimateReadTime(String content) {
    final words = content.split(RegExp(r'\s+')).length;
    final minutes = (words / 200).ceil();
    return '~${minutes} min read';
  }
} 