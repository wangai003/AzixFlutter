import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/admin_provider.dart';
import '../models/explore_content.dart';
import 'article_detail_screen.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/auth_provider.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _selectedCategory = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).loadExploreContent(publishedOnly: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);
    final allContent = adminProvider.exploreContent;
    final featuredContent = allContent.where((c) => c.isFeatured).toList();
    final categories = ['all', ...{
      ...allContent.map((c) => c.category)
    }];
    final filteredContent = allContent.where((item) {
      final matchesCategory = _selectedCategory == 'all' || item.category == _selectedCategory;
      final matchesSearch = _searchController.text.isEmpty ||
        item.title.toLowerCase().contains(_searchController.text.toLowerCase()) ||
        (item.description.toLowerCase().contains(_searchController.text.toLowerCase()));
      return matchesCategory && matchesSearch;
    }).toList();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.black, Color(0xFF212121)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildSearchBar(),
            if (adminProvider.isLoading)
              _buildSkeletonCarousel()
            else if (featuredContent.isNotEmpty)
              _buildFeaturedCarousel(featuredContent),
            _buildCategoryTabs(categories),
            Expanded(
              child: adminProvider.isLoading
                  ? _buildSkeletonList()
                  : filteredContent.isEmpty
                      ? Center(child: Text('No content found.', style: AppTheme.bodyLarge.copyWith(color: AppTheme.grey)))
                      : ListView.builder(
                          itemCount: filteredContent.length,
                          itemBuilder: (context, index) {
                            final item = filteredContent[index];
                            return _buildContentCard(item);
                          },
                        ),
            ),
          ],
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
            'Explore',
            style: AppTheme.headingLarge.copyWith(
              color: AppTheme.primaryGold,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppTheme.primaryGold),
            onPressed: () {},
          ),
        ],
      ),
    );
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
                  hintText: 'Search for content...',
                  hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs(List<String> categories) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = category;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12.0),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryGold.withOpacity(0.2) : AppTheme.darkGrey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryGold : AppTheme.grey.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Text(
                category[0].toUpperCase() + category.substring(1),
                style: AppTheme.bodySmall.copyWith(
                  color: isSelected ? AppTheme.primaryGold : AppTheme.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContentCard(ExploreContentModel item) {
    final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid ?? '';
    final isLiked = item.isLikedBy(userId);
    final isBookmarked = item.isBookmarkedBy(userId);
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    final readTime = _estimateReadTime(item.content ?? item.description);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ArticleDetailScreen(article: item),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16.0),
                  topRight: Radius.circular(16.0),
                ),
                child: Image.network(
                  item.imageUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGold.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          item.category[0].toUpperCase() + item.category.substring(1),
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.primaryGold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (item.isFeatured)
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.title,
                    style: AppTheme.headingSmall.copyWith(
                      color: AppTheme.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.description,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('By Admin', style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
                      const SizedBox(width: 12),
                      if (item.createdAt != null)
                        Text(
                          '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}',
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                        ),
                      const SizedBox(width: 12),
                      Text(readTime, style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildActionButton(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        'Like${item.likeTotal > 0 ? ' (${item.likeTotal})' : ''}',
                        isLiked ? Colors.red : AppTheme.primaryGold,
                        () {
                          if (isLiked) {
                            adminProvider.unlikeArticle(item.id, userId);
                          } else {
                            adminProvider.likeArticle(item.id, userId);
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
                            adminProvider.unbookmarkArticle(item.id, userId);
                          } else {
                            adminProvider.bookmarkArticle(item.id, userId);
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      _buildActionButton(Icons.share, 'Share', AppTheme.primaryGold, () {
                        // Implement share logic
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _estimateReadTime(String content) {
    final words = content.split(RegExp(r'\s+')).length;
    final minutes = (words / 200).ceil();
    return '~${minutes} min read';
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

  Widget _buildFeaturedCarousel(List<ExploreContentModel> featured) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: featured.length,
        itemBuilder: (context, index) {
          final item = featured[index];
          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ArticleDetailScreen(article: item),
              ),
            ),
            child: Container(
              width: 320,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGold.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                      Image.network(
                        item.imageUrl!,
                        width: 320,
                        height: 220,
                        fit: BoxFit.cover,
                      ),
                    Container(
                      width: 320,
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 24,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: AppTheme.headingMedium.copyWith(
                              color: AppTheme.primaryGold,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.description,
                            style: AppTheme.bodySmall.copyWith(
                              color: Colors.white,
                              shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeletonCarousel() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: 2,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: AppTheme.darkGrey,
            highlightColor: AppTheme.grey.withOpacity(0.2),
            child: Container(
              width: 320,
              height: 220,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: AppTheme.darkGrey,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      itemCount: 4,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: AppTheme.darkGrey,
          highlightColor: AppTheme.grey.withOpacity(0.2),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: AppTheme.darkGrey,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }
}