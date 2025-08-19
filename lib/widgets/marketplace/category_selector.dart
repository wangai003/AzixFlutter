import 'package:flutter/material.dart';
import '../../theme/marketplace_theme.dart';
import '../../utils/marketplace_categories.dart';
import '../../utils/responsive_layout.dart';

/// A responsive widget for selecting categories and subcategories
class CategorySelector extends StatefulWidget {
  final String selectedCategory;
  final String? selectedSubcategory;
  final bool showGoodsCategories;
  final bool showServiceCategories;
  final Function(String category) onCategorySelected;
  final Function(String? subcategory)? onSubcategorySelected;

  const CategorySelector({
    Key? key,
    required this.selectedCategory,
    this.selectedSubcategory,
    this.showGoodsCategories = true,
    this.showServiceCategories = true,
    required this.onCategorySelected,
    this.onSubcategorySelected,
  }) : super(key: key);

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main categories
        _buildMainCategories(),
        
        // Subcategories (if main category selected)
        if (widget.selectedCategory != 'All' && _hasSubcategories())
          _buildSubcategories(),
      ],
    );
  }
  
  Widget _buildMainCategories() {
    final List<String> displayCategories = ['All'];
    
    if (widget.showGoodsCategories) {
      displayCategories.addAll(MarketplaceCategories.getGoodsCategories());
    }
    if (widget.showServiceCategories) {
      displayCategories.addAll(MarketplaceCategories.getServiceCategories());
    }
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: displayCategories.map((category) {
          final isSelected = widget.selectedCategory == category;
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => widget.onCategorySelected(category),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveLayout.getResponsivePadding(context) * 0.75,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? MarketplaceTheme.primaryBlue 
                      : MarketplaceTheme.white,
                  borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
                  border: Border.all(
                    color: isSelected 
                        ? MarketplaceTheme.primaryBlue 
                        : MarketplaceTheme.gray200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (category != 'All') ...[
                      Icon(
                        _getCategoryIconData(MarketplaceCategories.getCategoryIcon(category)),
                        size: 16,
                        color: isSelected ? Colors.white : MarketplaceTheme.gray600,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        category,
                        style: MarketplaceTheme.labelMedium.copyWith(
                          color: isSelected ? Colors.white : MarketplaceTheme.gray600,
                          fontSize: ResponsiveLayout.getResponsiveFontSize(context, 12),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildSubcategories() {
    final subcategories = MarketplaceCategories.getSubcategories(widget.selectedCategory);
    
    if (subcategories.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subcategories',
            style: MarketplaceTheme.labelMedium.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 12),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: subcategories.map((subcategory) {
                final isSelected = widget.selectedSubcategory == subcategory;
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => widget.onSubcategorySelected?.call(
                      isSelected ? null : subcategory
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveLayout.getResponsivePadding(context) * 0.6,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? MarketplaceTheme.primaryGreen 
                            : MarketplaceTheme.gray50,
                        borderRadius: BorderRadius.circular(MarketplaceTheme.radiusMd),
                        border: Border.all(
                          color: isSelected 
                              ? MarketplaceTheme.primaryGreen 
                              : MarketplaceTheme.gray300,
                        ),
                      ),
                      child: Text(
                        subcategory,
                        style: MarketplaceTheme.labelMedium.copyWith(
                          color: isSelected ? Colors.white : MarketplaceTheme.gray700,
                          fontSize: ResponsiveLayout.getResponsiveFontSize(context, 11),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
  
  bool _hasSubcategories() {
    return MarketplaceCategories.getSubcategories(widget.selectedCategory).isNotEmpty;
  }
  
  IconData _getCategoryIconData(String iconName) {
    switch (iconName) {
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'agriculture':
        return Icons.agriculture;
      case 'handmade':
        return Icons.handyman;
      case 'restaurant':
        return Icons.restaurant;
      case 'construction':
        return Icons.construction;
      case 'school':
        return Icons.school;
      case 'directions_car':
        return Icons.directions_car;
      case 'computer':
        return Icons.computer;
      case 'home_repair_service':
        return Icons.home_repair_service;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'design_services':
        return Icons.design_services;
      case 'event':
        return Icons.event;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'engineering':
        return Icons.engineering;
      case 'menu_book':
        return Icons.menu_book;
      case 'build':
        return Icons.build;
      case 'account_balance':
        return Icons.account_balance;
      case 'hotel':
        return Icons.hotel;
      default:
        return Icons.category;
    }
  }
}
