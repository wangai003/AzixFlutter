import 'package:flutter/material.dart';
import '../theme/ultra_modern_theme.dart';
import '../theme/marketplace_theme.dart';
import '../models/product.dart';
import '../models/service.dart';

/// Collection of reusable marketplace widgets with ultra-modern styling
class MarketplaceWidgets {
  
  // ==================== PRODUCT CARDS ====================
  
  /// Ultra-modern product card for grid view
  static Widget productGridCard({
    required Product product,
    required VoidCallback onTap,
    VoidCallback? onAddToCart,
    VoidCallback? onFavorite,
    bool isInCart = false,
    bool isFavorite = false,
    bool showAnimation = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: MarketplaceTheme.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      image: product.images.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(product.images.first),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: product.images.isEmpty ? Colors.grey[300] : null,
                    ),
                    child: product.images.isEmpty
                        ? const Icon(Icons.inventory_2, size: 48, color: Colors.grey)
                        : null,
                  ),
                  
                  // Status Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: product.inventory > 0 ? MarketplaceTheme.success : MarketplaceTheme.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        product.inventory > 0 ? 'In Stock' : 'Out of Stock',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                  
                  // Favorite Button
                  if (onFavorite != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: onFavorite,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Product Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      product.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Category
                    Text(
                      product.category,
                      style: TextStyle(
                        fontSize: 12,
                        color: MarketplaceTheme.getCategoryColor(product.category),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Price and Action Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '₳${product.price.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: MarketplaceTheme.primaryGreen),
                          ),
                        ),
                        
                        if (onAddToCart != null)
                          GestureDetector(
                            onTap: onAddToCart,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isInCart 
                                    ? Colors.red.withOpacity(0.2)
                                    : Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isInCart ? Colors.red : Colors.green,
                                ),
                              ),
                              child: Icon(
                                isInCart ? Icons.remove_shopping_cart : Icons.add_shopping_cart,
                                color: isInCart ? Colors.red : Colors.green,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Ultra-modern product card for list view
  static Widget productListCard({
    required Product product,
    required VoidCallback onTap,
    VoidCallback? onAddToCart,
    VoidCallback? onFavorite,
    bool isInCart = false,
    bool isFavorite = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: MarketplaceTheme.cardDecoration,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: product.images.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(product.images.first),
                    fit: BoxFit.cover,
                  )
                : null,
            color: product.images.isEmpty ? Colors.grey[300] : null,
          ),
          child: product.images.isEmpty
              ? const Icon(Icons.inventory_2, color: Colors.grey)
              : null,
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              product.description,
              style: const TextStyle(color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '₳${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: MarketplaceTheme.primaryGreen),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: product.inventory > 0 ? MarketplaceTheme.success : MarketplaceTheme.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    product.inventory > 0 ? 'In Stock' : 'Out of Stock',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (onFavorite != null)
              IconButton(
                onPressed: onFavorite,
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.grey,
                ),
              ),
            if (onAddToCart != null)
              IconButton(
                onPressed: onAddToCart,
                icon: Icon(
                  isInCart ? Icons.remove_shopping_cart : Icons.add_shopping_cart,
                  color: isInCart ? Colors.red : Colors.green,
                ),
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
  
  // ==================== SERVICE CARDS ====================
  
  /// Ultra-modern service card for grid view
  static Widget serviceGridCard({
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
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      image: service.images.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(service.images.first),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: service.images.isEmpty ? Colors.grey[300] : null,
                    ),
                    child: service.images.isEmpty
                        ? const Icon(Icons.design_services, size: 48, color: Colors.grey)
                        : null,
                  ),
                  
                  // Service Type Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: MarketplaceTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '🛠️ Service',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                  
                  // Favorite Button
                  if (onFavorite != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: onFavorite,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Service Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Service Title
                    Text(
                      service.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Category
                    Text(
                      service.category,
                      style: TextStyle(
                        fontSize: 12,
                        color: MarketplaceTheme.getCategoryColor(service.category),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Price
                    Text(
                      'From ₳${minPrice.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: MarketplaceTheme.primaryGreen),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Ultra-modern service card for list view
  static Widget serviceListCard({
    required Service service,
    required VoidCallback onTap,
    VoidCallback? onFavorite,
    bool isFavorite = false,
  }) {
    final minPrice = service.packages.isNotEmpty 
        ? service.packages.map((p) => p.price).reduce((a, b) => a < b ? a : b)
        : 0.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: MarketplaceTheme.cardDecoration,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: service.images.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(service.images.first),
                    fit: BoxFit.cover,
                  )
                : null,
            color: service.images.isEmpty ? Colors.grey[300] : null,
          ),
          child: service.images.isEmpty
              ? const Icon(Icons.design_services, color: Colors.grey)
              : null,
        ),
        title: Text(
          service.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              service.description,
              style: const TextStyle(color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'From ₳${minPrice.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: MarketplaceTheme.primaryGreen),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: MarketplaceTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '🛠️ Service',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: onFavorite != null
            ? IconButton(
                onPressed: onFavorite,
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.grey,
                ),
              )
            : const Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey,
                size: 16,
              ),
        onTap: onTap,
      ),
    );
  }
  
  // ==================== CATEGORY CARDS ====================
  
  /// Ultra-modern category card
  static Widget categoryCard({
    required String name,
    required String subcategory,
    required VoidCallback onTap,
    int? itemCount,
    IconData? icon,
  }) {
    final categoryColor = MarketplaceTheme.getCategoryColor(name);
    final categoryIcon = icon ?? _getCategoryIcon(name);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: categoryColor.withOpacity(0.3)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Category Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: categoryColor.withOpacity(0.4), width: 2),
              ),
              child: Icon(categoryIcon, color: categoryColor, size: 32),
            ),
            
            const SizedBox(height: 16),
            
            // Category Name
            Text(
              name,
              style: TextStyle(
                color: categoryColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            // Subcategory
            if (subcategory.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subcategory,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            
            // Item Count
            if (itemCount != null) ...[
              const SizedBox(height: 4),
              Text(
                '$itemCount items',
                style: TextStyle(
                  color: categoryColor.withOpacity(0.8),
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // ==================== UTILITY WIDGETS ====================
  
  /// Ultra-modern section header
  static Widget sectionHeader({
    required String title,
    String? subtitle,
    VoidCallback? onSeeAll,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: UltraModernTheme.primaryGold, size: 24),
            const SizedBox(width: 16),
          ],
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: const Text(
                'See All',
                style: TextStyle(
                  color: UltraModernTheme.primaryGold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  /// Loading grid placeholder
  static Widget loadingGrid({int itemCount = 6, double aspectRatio = 0.8}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: aspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }
  
  /// Empty state widget
  static Widget emptyState({
    required String title,
    required String subtitle,
    IconData? icon,
    VoidCallback? onAction,
    String? actionText,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.inventory_2,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            if (onAction != null && actionText != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MarketplaceTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                child: Text(actionText),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // Helper method for category icons
  static IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'electronics':
        return Icons.devices;
      case 'fashion':
        return Icons.checkroom;
      case 'food':
        return Icons.restaurant;
      case 'health':
        return Icons.medical_services;
      case 'services':
        return Icons.design_services;
      case 'education':
        return Icons.school;
      default:
        return Icons.category;
    }
  }
}