import 'package:flutter/material.dart';
import '../utils/marketplace_categories.dart';
import '../theme/marketplace_theme.dart';
import '../utils/responsive_layout.dart';

/// Comprehensive category selector with main categories and subcategories
class CategorySelector extends StatefulWidget {
  final String selectedCategory;
  final String? selectedSubcategory;
  final bool isForGoods; // true for goods, false for services
  final Function(String category, String? subcategory) onSelectionChanged;
  final String? title;

  const CategorySelector({
    Key? key,
    required this.selectedCategory,
    this.selectedSubcategory,
    required this.isForGoods,
    required this.onSelectionChanged,
    this.title,
  }) : super(key: key);

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  late String _selectedCategory;
  String? _selectedSubcategory;
  bool _showSubcategories = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.selectedCategory;
    _selectedSubcategory = widget.selectedSubcategory;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: EdgeInsets.all(ResponsiveLayout.getResponsivePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          if (widget.title != null) ...[
            Text(
              widget.title!,
              style: MarketplaceTheme.titleLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: ResponsiveLayout.getResponsiveSpacing(context, 12)),
          ],

          // Category type indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: widget.isForGoods 
                  ? MarketplaceTheme.primaryBlue.withOpacity(0.1)
                  : MarketplaceTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(MarketplaceTheme.radiusSm),
            ),
            child: Text(
              widget.isForGoods ? 'Product Category' : 'Service Category',
              style: MarketplaceTheme.bodyMedium.copyWith(
                color: widget.isForGoods 
                    ? MarketplaceTheme.primaryBlue
                    : MarketplaceTheme.primaryGreen,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          SizedBox(height: ResponsiveLayout.getResponsiveSpacing(context, 16)),

          // Main category selection
          _buildMainCategorySelector(),

          SizedBox(height: ResponsiveLayout.getResponsiveSpacing(context, 16)),

          // Subcategory selection
          if (_showSubcategories) _buildSubcategorySelector(),
        ],
      ),
    );
  }

  Widget _buildMainCategorySelector() {
    final categories = widget.isForGoods 
        ? MarketplaceCategories.getGoodsCategories()
        : MarketplaceCategories.getServiceCategories();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Main Category',
          style: MarketplaceTheme.titleLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        
        SizedBox(height: ResponsiveLayout.getResponsiveSpacing(context, 8)),

        // Category grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: ResponsiveLayout.isMobile(context) ? 1 : 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: ResponsiveLayout.isMobile(context) ? 5 : 4,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final isSelected = _selectedCategory == category;
            
            return GestureDetector(
              onTap: () => _selectMainCategory(category),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected 
                      ? (widget.isForGoods 
                          ? MarketplaceTheme.primaryBlue.withOpacity(0.1)
                          : MarketplaceTheme.primaryGreen.withOpacity(0.1))
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(MarketplaceTheme.radiusMd),
                  border: Border.all(
                    color: isSelected 
                        ? (widget.isForGoods 
                            ? MarketplaceTheme.primaryBlue
                            : MarketplaceTheme.primaryGreen)
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                padding: EdgeInsets.all(ResponsiveLayout.getResponsivePadding(context)),
                child: Row(
                  children: [
                    // Category icon
                    Text(
                      MarketplaceCategories.getCategoryIcon(category),
                      style: TextStyle(
                        fontSize: ResponsiveLayout.getResponsiveFontSize(context, 20),
                      ),
                    ),
                    
                    SizedBox(width: ResponsiveLayout.getResponsiveSpacing(context, 8)),
                    
                    // Category name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            category,
                            style: MarketplaceTheme.titleLarge.copyWith(
                              color: isSelected 
                                  ? (widget.isForGoods 
                                      ? MarketplaceTheme.primaryBlue
                                      : MarketplaceTheme.primaryGreen)
                                  : MarketplaceTheme.gray900,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          // Show subcategory count
                          Text(
                            '${MarketplaceCategories.getSubcategories(category).length} subcategories',
                            style: MarketplaceTheme.bodyMedium.copyWith(
                              color: Colors.grey.shade600,
                              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Selection indicator
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: widget.isForGoods 
                            ? MarketplaceTheme.primaryBlue
                            : MarketplaceTheme.primaryGreen,
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubcategorySelector() {
    final subcategories = MarketplaceCategories.getSubcategories(_selectedCategory);
    
    if (subcategories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subcategory (Optional)',
          style: MarketplaceTheme.titleLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        
        SizedBox(height: ResponsiveLayout.getResponsiveSpacing(context, 8)),

        // Subcategory chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Clear selection chip
            FilterChip(
              label: const Text('None'),
              selected: _selectedSubcategory == null,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedSubcategory = null;
                  });
                  widget.onSelectionChanged(_selectedCategory, null);
                }
              },
              selectedColor: Colors.grey.shade200,
              checkmarkColor: Colors.grey.shade700,
            ),
            
            // Subcategory chips
            ...subcategories.map((subcategory) => FilterChip(
              label: Text(subcategory),
              selected: _selectedSubcategory == subcategory,
              onSelected: (selected) {
                setState(() {
                  _selectedSubcategory = selected ? subcategory : null;
                });
                widget.onSelectionChanged(_selectedCategory, _selectedSubcategory);
              },
              selectedColor: widget.isForGoods 
                  ? MarketplaceTheme.primaryBlue.withOpacity(0.2)
                  : MarketplaceTheme.primaryGreen.withOpacity(0.2),
              checkmarkColor: widget.isForGoods 
                  ? MarketplaceTheme.primaryBlue
                  : MarketplaceTheme.primaryGreen,
              labelStyle: TextStyle(
                fontSize: ResponsiveLayout.getResponsiveFontSize(context, 12),
              ),
            )),
          ],
        ),
      ],
    );
  }

  void _selectMainCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _selectedSubcategory = null; // Reset subcategory when main category changes
      _showSubcategories = true;
    });
    widget.onSelectionChanged(_selectedCategory, null);
  }
}

/// Simple dropdown category selector for compact forms
class CompactCategorySelector extends StatelessWidget {
  final String selectedCategory;
  final bool isForGoods;
  final Function(String) onChanged;
  final String label;

  const CompactCategorySelector({
    Key? key,
    required this.selectedCategory,
    required this.isForGoods,
    required this.onChanged,
    this.label = 'Category',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final categories = isForGoods 
        ? MarketplaceCategories.getGoodsCategories()
        : MarketplaceCategories.getServiceCategories();

    return DropdownButtonFormField<String>(
      value: selectedCategory,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          isForGoods ? Icons.inventory : Icons.work,
          color: isForGoods 
              ? MarketplaceTheme.primaryBlue
              : MarketplaceTheme.primaryGreen,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MarketplaceTheme.radiusMd),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: categories.map((category) => DropdownMenuItem(
        value: category,
        child: Row(
          children: [
            Text(MarketplaceCategories.getCategoryIcon(category)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      )).toList(),
      onChanged: (value) => onChanged(value!),
      validator: (value) => value == null ? 'Please select a category' : null,
    );
  }
}
