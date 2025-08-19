import 'package:flutter/material.dart';
import '../../theme/marketplace_theme.dart';
import '../../models/marketplace/listing.dart';
import '../../models/marketplace/vendor_profile.dart';

/// Modern marketplace widgets inspired by world-class platforms
class ModernMarketplaceWidgets {
  
  /// Modern product card (Jiji/Amazon inspired)
  static Widget productCard({
    required Product product,
    required VoidCallback onTap,
    VoidCallback? onFavorite,
    bool isFavorite = false,
    bool showVendor = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: MarketplaceTheme.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(MarketplaceTheme.radiusXl),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: product.images.isNotEmpty
                        ? Image.network(
                            product.images.first,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: MarketplaceTheme.gray100,
                              child: const Icon(
                                Icons.image_not_supported,
                                color: MarketplaceTheme.gray400,
                              ),
                            ),
                          )
                        : Container(
                            color: MarketplaceTheme.gray100,
                            child: const Icon(
                              Icons.image,
                              color: MarketplaceTheme.gray400,
                            ),
                          ),
                  ),
                ),
                
                // Favorite button
                if (onFavorite != null)
                  Positioned(
                    top: MarketplaceTheme.space2,
                    right: MarketplaceTheme.space2,
                    child: GestureDetector(
                      onTap: onFavorite,
                      child: Container(
                        padding: const EdgeInsets.all(MarketplaceTheme.space2),
                        decoration: BoxDecoration(
                          color: MarketplaceTheme.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: const [MarketplaceTheme.smallShadow],
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: isFavorite 
                              ? MarketplaceTheme.error 
                              : MarketplaceTheme.gray500,
                        ),
                      ),
                    ),
                  ),
                
                // Status badge
                if (product.metadata['featured'] == true)
                  Positioned(
                    top: MarketplaceTheme.space2,
                    left: MarketplaceTheme.space2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MarketplaceTheme.space2,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: MarketplaceTheme.primaryOrange,
                        borderRadius: BorderRadius.circular(MarketplaceTheme.radiusSm),
                      ),
                      child: const Text(
                        'Featured',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: MarketplaceTheme.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            // Product details
            Padding(
              padding: const EdgeInsets.all(MarketplaceTheme.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    product.title,
                    style: MarketplaceTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: MarketplaceTheme.space2),
                  
                  // Price and rating row
                  Row(
                    children: [
                      Text(
                        '₳${product.price.toStringAsFixed(2)}',
                        style: MarketplaceTheme.headingMedium.copyWith(
                          color: MarketplaceTheme.primaryGreen,
                        ),
                      ),
                      const Spacer(),
                      _buildRatingChip(product.rating, product.reviewCount),
                    ],
                  ),
                  
                  const SizedBox(height: MarketplaceTheme.space2),
                  
                  // Category
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MarketplaceTheme.space2,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: MarketplaceTheme.getCategoryColor(product.category)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(MarketplaceTheme.radiusSm),
                    ),
                    child: Text(
                      product.category,
                      style: MarketplaceTheme.labelMedium.copyWith(
                        color: MarketplaceTheme.getCategoryColor(product.category),
                      ),
                    ),
                  ),
                  
                  // Vendor info
                  if (showVendor) ...[
                    const SizedBox(height: MarketplaceTheme.space2),
                    Row(
                      children: [
                        const Icon(
                          Icons.store,
                          size: 14,
                          color: MarketplaceTheme.gray400,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Vendor',
                            style: MarketplaceTheme.labelMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildTrustBadge(),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Modern service card (Upwork/Fiverr inspired)
  static Widget serviceCard({
    required Service service,
    required VoidCallback onTap,
    VoidCallback? onFavorite,
    bool isFavorite = false,
  }) {
    final minPrice = service.packages.isNotEmpty 
        ? service.packages.map((p) => p.price).reduce((a, b) => a < b ? a : b)
        : 0.0;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: MarketplaceTheme.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(MarketplaceTheme.radiusXl),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: service.images.isNotEmpty
                        ? Image.network(
                            service.images.first,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: MarketplaceTheme.gray100,
                              child: const Icon(
                                Icons.work,
                                color: MarketplaceTheme.gray400,
                              ),
                            ),
                          )
                        : Container(
                            color: MarketplaceTheme.gray100,
                            child: const Icon(
                              Icons.work,
                              color: MarketplaceTheme.gray400,
                            ),
                          ),
                  ),
                ),
                
                // Favorite button
                if (onFavorite != null)
                  Positioned(
                    top: MarketplaceTheme.space2,
                    right: MarketplaceTheme.space2,
                    child: GestureDetector(
                      onTap: onFavorite,
                      child: Container(
                        padding: const EdgeInsets.all(MarketplaceTheme.space2),
                        decoration: BoxDecoration(
                          color: MarketplaceTheme.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: const [MarketplaceTheme.smallShadow],
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: isFavorite 
                              ? MarketplaceTheme.error 
                              : MarketplaceTheme.gray500,
                        ),
                      ),
                    ),
                  ),
                
                // Service level badge
                Positioned(
                  top: MarketplaceTheme.space2,
                  left: MarketplaceTheme.space2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MarketplaceTheme.space2,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: MarketplaceTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(MarketplaceTheme.radiusSm),
                    ),
                    child: const Text(
                      'Pro',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: MarketplaceTheme.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Service details
            Padding(
              padding: const EdgeInsets.all(MarketplaceTheme.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    service.title,
                    style: MarketplaceTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: MarketplaceTheme.space2),
                  
                  // Description
                  Text(
                    service.description,
                    style: MarketplaceTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: MarketplaceTheme.space3),
                  
                  // Price and rating row
                  Row(
                    children: [
                      Text(
                        'From ₳${minPrice.toStringAsFixed(0)}',
                        style: MarketplaceTheme.headingMedium.copyWith(
                          color: MarketplaceTheme.primaryGreen,
                        ),
                      ),
                      const Spacer(),
                      _buildRatingChip(service.rating, service.reviewCount),
                    ],
                  ),
                  
                  const SizedBox(height: MarketplaceTheme.space2),
                  
                  // Delivery time and category
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: MarketplaceTheme.gray400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '7 days delivery',
                        style: MarketplaceTheme.labelMedium,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MarketplaceTheme.space2,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: MarketplaceTheme.getCategoryColor(service.category)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(MarketplaceTheme.radiusSm),
                        ),
                        child: Text(
                          service.category,
                          style: MarketplaceTheme.labelMedium.copyWith(
                            color: MarketplaceTheme.getCategoryColor(service.category),
                          ),
                        ),
                      ),
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
  
  /// Modern vendor card
  static Widget vendorCard({
    required VendorProfile vendor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: MarketplaceTheme.cardDecoration,
        padding: const EdgeInsets.all(MarketplaceTheme.space4),
        child: Column(
          children: [
            // Vendor avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: vendor.logoUrl != null
                      ? NetworkImage(vendor.logoUrl!)
                      : null,
                  child: vendor.logoUrl == null
                      ? Text(
                          vendor.displayName.substring(0, 1).toUpperCase(),
                          style: MarketplaceTheme.headingMedium.copyWith(
                            color: MarketplaceTheme.white,
                          ),
                        )
                      : null,
                ),
                
                // Online indicator
                if (vendor.isOnline)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: MarketplaceTheme.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: MarketplaceTheme.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: MarketplaceTheme.space3),
            
            // Vendor name
            Text(
              vendor.displayName,
              style: MarketplaceTheme.titleLarge,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: MarketplaceTheme.space2),
            
            // Primary category
            if (vendor.categories.isNotEmpty)
              Text(
                vendor.categories.first.name,
                style: MarketplaceTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            
            const SizedBox(height: MarketplaceTheme.space3),
            
            // Rating and reviews
            _buildRatingChip(
              vendor.analytics.rating,
              vendor.analytics.reviewCount,
            ),
            
            const SizedBox(height: MarketplaceTheme.space2),
            
            // Verification badges
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (vendor.isVerified) _buildTrustBadge(),
                if (vendor.trustScore != null) ...[
                  const SizedBox(width: MarketplaceTheme.space2),
                  _buildTrustLevelBadge(vendor.trustScore!.level),
                ],
              ],
            ),
            
            const SizedBox(height: MarketplaceTheme.space3),
            
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  'Orders',
                  vendor.analytics.completedOrders.toString(),
                ),
                _buildStatItem(
                  'Response',
                  '${vendor.analytics.responseRate.toStringAsFixed(0)}%',
                ),
                _buildStatItem(
                  'Member',
                  vendor.membershipDuration?.inDays.toString() ?? '0',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  /// Modern category card
  static Widget categoryCard({
    required String name,
    required String iconName,
    required Color color,
    required int itemCount,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withAlpha(25), color.withAlpha(13)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(MarketplaceTheme.radiusXl),
          border: Border.all(color: color.withAlpha(51)),
        ),
        padding: const EdgeInsets.all(MarketplaceTheme.space4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Icon(
                _getIconForCategory(iconName),
                size: 28,
                color: color,
              ),
            ),
            
            const SizedBox(height: 4),
            
            Flexible(
              child: Text(
                name,
                style: MarketplaceTheme.titleLarge.copyWith(fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            const SizedBox(height: 2),
            
            Flexible(
              child: Text(
                '$itemCount items',
                style: MarketplaceTheme.labelMedium.copyWith(fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Helper widgets
  
  static Widget _buildRatingChip(double rating, int reviewCount) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MarketplaceTheme.space2,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: MarketplaceTheme.primaryOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(MarketplaceTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star,
            size: 12,
            color: MarketplaceTheme.primaryOrange,
          ),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: MarketplaceTheme.labelMedium.copyWith(
              color: MarketplaceTheme.primaryOrange,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (reviewCount > 0) ...[
            const SizedBox(width: 2),
            Text(
              '($reviewCount)',
              style: MarketplaceTheme.labelMedium.copyWith(
                color: MarketplaceTheme.gray500,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  static Widget _buildTrustBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: MarketplaceTheme.success,
        borderRadius: BorderRadius.circular(MarketplaceTheme.radiusSm),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified,
            size: 12,
            color: MarketplaceTheme.white,
          ),
          SizedBox(width: 2),
          Text(
            'Verified',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: MarketplaceTheme.white,
            ),
          ),
        ],
      ),
    );
  }
  
  static Widget _buildTrustLevelBadge(dynamic level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: MarketplaceTheme.primaryBlue,
        borderRadius: BorderRadius.circular(MarketplaceTheme.radiusSm),
      ),
      child: Text(
        level.toString().split('.').last.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: MarketplaceTheme.white,
        ),
      ),
    );
  }
  
  static Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            value,
            style: MarketplaceTheme.titleLarge.copyWith(
              color: MarketplaceTheme.primaryBlue,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        Flexible(
          child: Text(
            label,
            style: MarketplaceTheme.labelMedium,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
  
  static IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'electronics':
        return Icons.devices;
      case 'fashion':
        return Icons.checkroom;
      case 'home':
        return Icons.home;
      case 'automotive':
        return Icons.directions_car;
      case 'services':
        return Icons.work;
      case 'sports':
        return Icons.sports;
      case 'books':
        return Icons.book;
      case 'beauty':
        return Icons.face;
      case 'food':
        return Icons.restaurant;
      default:
        return Icons.category;
    }
  }
}
