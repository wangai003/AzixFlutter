import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/marketplace_theme.dart';
import '../../widgets/marketplace/modern_widgets.dart';
import '../../providers/marketplace/marketplace_provider.dart';
import '../../providers/auth_provider.dart' as local_auth;
import '../../services/marketplace/search_service.dart';
import '../vendor/vendor_registration_screen.dart';
import 'functional_search_screen.dart';
import 'functional_cart_screen.dart';
import '../../screens/customer/customer_orders_screen.dart';
import '../product_detail_screen.dart';
import '../service_detail_screen.dart';
import '../notifications_screen.dart';
import '../../providers/unified_cart_provider.dart';
import '../../utils/marketplace_categories.dart';
import '../../utils/responsive_layout.dart';
import '../../models/product.dart';
import '../../models/service.dart';
import '../../widgets/enhanced_image_widget.dart';

/// Ultra-modern responsive marketplace with real functionality
class ModernMarketplaceHome extends StatefulWidget {
  const ModernMarketplaceHome({Key? key}) : super(key: key);

  @override
  State<ModernMarketplaceHome> createState() => _ModernMarketplaceHomeState();
}

class _ModernMarketplaceHomeState extends State<ModernMarketplaceHome>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<SearchSuggestion> _suggestions = [];
  bool _showSuggestions = false;

  // Category filtering
  String _selectedCategory = 'All';
  String? _selectedSubcategory;
  bool _showCategoryFilters = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() async {
    final query = _searchController.text.trim();
    if (query.length >= 2) {
      final marketplace = context.read<EnhancedMarketplaceProvider>();
      final suggestions = await marketplace.getSearchSuggestions(query);
      setState(() {
        _suggestions = suggestions;
        _showSuggestions = true;
      });
    } else {
      setState(() {
        _showSuggestions = false;
      });
    }
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) return;

    final marketplace = context.read<EnhancedMarketplaceProvider>();
    marketplace.search(SearchQuery(query: query, searchType: SearchType.all));

    setState(() {
      _showSuggestions = false;
    });

    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketplaceTheme.gray50,
      body: SafeArea(
        child: Consumer<EnhancedMarketplaceProvider>(
          builder: (context, marketplace, child) {
            // Show error state if there's an error
            if (marketplace.errorMessage != null) {
              return _buildErrorState(marketplace.errorMessage!);
            }

            // Show loading state
            if (marketplace.isLoading) {
              return _buildLoadingState();
            }

            // Show main content
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildHeader(),
                  _buildSearchSection(),
                  // Show empty state if no data
                  if (marketplace.products.isEmpty &&
                      marketplace.services.isEmpty &&
                      !marketplace.isLoading)
                    _buildEmptyState('No products or services available yet'),
                  if (_showSuggestions) _buildSuggestions(),
                  _buildCategoryFilters(),
                  _buildQuickStats(),
                  _buildTabSection(),
                  _buildTabContent(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(ResponsiveLayout.getResponsivePadding(context)),
      decoration: const BoxDecoration(
        color: MarketplaceTheme.white,
        boxShadow: [MarketplaceTheme.smallShadow],
      ),
      child: ResponsiveLayout.isTabletOrDesktop(context)
          ? _buildDesktopHeader()
          : _buildMobileHeader(),
    );
  }

  Widget _buildMobileHeader() {
    return Column(
      children: [
        Row(
          children: [
            // Logo/Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marketplace',
                    style: MarketplaceTheme.headingLarge.copyWith(
                      color: MarketplaceTheme.primaryBlue,
                      fontSize: ResponsiveLayout.getResponsiveFontSize(
                        context,
                        24,
                      ),
                    ),
                  ),
                  Text(
                    'Buy & sell with confidence',
                    style: MarketplaceTheme.bodyMedium.copyWith(
                      fontSize: ResponsiveLayout.getResponsiveFontSize(
                        context,
                        14,
                      ),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            _buildActionButtons(),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopHeader() {
    return Row(
      children: [
        // Logo/Title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Marketplace',
                style: MarketplaceTheme.headingLarge.copyWith(
                  color: MarketplaceTheme.primaryBlue,
                  fontSize: ResponsiveLayout.getResponsiveFontSize(context, 32),
                ),
              ),
              Text(
                'Discover amazing products & services from verified vendors',
                style: MarketplaceTheme.bodyMedium.copyWith(
                  fontSize: ResponsiveLayout.getResponsiveFontSize(context, 16),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildActionButtons() {
    final iconSize = ResponsiveLayout.isMobile(context) ? 20.0 : 24.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search button
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FunctionalSearchScreen()),
          ),
          icon: Icon(Icons.search, size: iconSize),
          color: MarketplaceTheme.primaryBlue,
        ),
        // Cart button
        Consumer<UnifiedCartProvider>(
          builder: (context, cart, _) {
            return Stack(
              children: [
                IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FunctionalCartScreen(),
                    ),
                  ),
                  icon: Icon(Icons.shopping_cart_outlined, size: iconSize),
                  color: MarketplaceTheme.primaryBlue,
                ),
                if (cart.itemCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        cart.itemCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        // Orders button
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomerOrdersScreen()),
          ),
          icon: Icon(Icons.receipt_long, size: iconSize),
          color: MarketplaceTheme.primaryBlue,
        ),
        // Become a Vendor button
        Consumer<local_auth.AuthProvider>(
          builder: (context, auth, _) {
            final user = auth.user;
            if (user == null) return const SizedBox.shrink();

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();

                final userData =
                    snapshot.data!.data() as Map<String, dynamic>? ?? {};
                final userRole = userData['role'] ?? 'user';
                final isVendor =
                    userRole == 'vendor' ||
                    userRole == 'goods_vendor' ||
                    userRole == 'service_vendor';

                if (!isVendor) {
                  return Container(
                    margin: EdgeInsets.only(
                      left: ResponsiveLayout.getResponsiveSpacing(context, 8),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VendorRegistrationScreen(),
                        ),
                      ),
                      icon: Icon(
                        Icons.store,
                        size: ResponsiveLayout.isMobile(context) ? 14 : 16,
                      ),
                      label: const Text('Sell'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MarketplaceTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveLayout.getResponsivePadding(
                            context,
                          ),
                          vertical: ResponsiveLayout.isMobile(context) ? 6 : 8,
                        ),
                        textStyle: TextStyle(
                          fontSize: ResponsiveLayout.getResponsiveFontSize(
                            context,
                            12,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildIconButton(
    IconData icon, {
    String? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(MarketplaceTheme.space2),
        decoration: BoxDecoration(
          color: MarketplaceTheme.gray100,
          borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: MarketplaceTheme.gray600, size: 20),
            if (badge != null)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: MarketplaceTheme.error,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: MarketplaceTheme.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(MarketplaceTheme.space3),
      color: MarketplaceTheme.white,
      child: Container(
        decoration: BoxDecoration(
          color: MarketplaceTheme.gray50,
          borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
          border: Border.all(color: MarketplaceTheme.gray200),
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search products, services, or vendors...',
            hintStyle: MarketplaceTheme.bodyMedium.copyWith(
              color: MarketplaceTheme.gray400,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: MarketplaceTheme.gray400,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _showSuggestions = false;
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: MarketplaceTheme.space3,
              vertical: MarketplaceTheme.space2,
            ),
          ),
          onSubmitted: _performSearch,
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return Container(
      padding: EdgeInsets.all(
        ResponsiveLayout.getResponsivePadding(context) * 0.75,
      ),
      color: MarketplaceTheme.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Category filter header
          Row(
            children: [
              Icon(
                Icons.filter_list,
                color: MarketplaceTheme.primaryBlue,
                size: 20,
              ),
              SizedBox(
                width: ResponsiveLayout.getResponsiveSpacing(context, 8),
              ),
              Text(
                'Filter by Category',
                style: MarketplaceTheme.titleLarge.copyWith(
                  fontSize: ResponsiveLayout.getResponsiveFontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(
                  () => _showCategoryFilters = !_showCategoryFilters,
                ),
                icon: Icon(
                  _showCategoryFilters ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(
                  _showCategoryFilters ? 'Hide' : 'Show',
                  style: TextStyle(
                    fontSize: ResponsiveLayout.getResponsiveFontSize(
                      context,
                      12,
                    ),
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: MarketplaceTheme.primaryBlue,
                ),
              ),
            ],
          ),

          if (_showCategoryFilters) ...[
            SizedBox(
              height: ResponsiveLayout.getResponsiveSpacing(context, 10),
            ),

            // Scrollable category content
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MarketplaceTheme.radiusMd),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: ResponsiveLayout.isMobile(context) ? 300 : 400,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.all(
                    ResponsiveLayout.getResponsivePadding(context) * 0.5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Main categories
                      _buildMainCategoryChips(),

                      // Subcategories (if main category selected)
                      if (_selectedCategory != 'All') ...[
                        SizedBox(
                          height: ResponsiveLayout.getResponsiveSpacing(
                            context,
                            6,
                          ),
                        ),
                        _buildSubcategoryChips(),
                      ],

                      // Active filters display
                      if (_selectedCategory != 'All' ||
                          _selectedSubcategory != null) ...[
                        SizedBox(
                          height: ResponsiveLayout.getResponsiveSpacing(
                            context,
                            6,
                          ),
                        ),
                        _buildActiveFilters(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainCategoryChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Goods Categories
        Text(
          'Goods Categories',
          style: MarketplaceTheme.bodyMedium.copyWith(
            fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: ResponsiveLayout.getResponsiveSpacing(context, 4)),
        Wrap(
          spacing: ResponsiveLayout.getResponsiveSpacing(context, 4),
          runSpacing: ResponsiveLayout.getResponsiveSpacing(context, 4),
          children: ['All', ...MarketplaceCategories.getGoodsCategories()].map((
            category,
          ) {
            final isSelected = _selectedCategory == category;
            return FilterChip(
              label: Text(
                category,
                style: TextStyle(
                  fontSize: ResponsiveLayout.getResponsiveFontSize(context, 11),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = selected ? category : 'All';
                  _selectedSubcategory = null;
                });
              },
              selectedColor: MarketplaceTheme.primaryBlue.withOpacity(0.2),
              checkmarkColor: MarketplaceTheme.primaryBlue,
              backgroundColor: isSelected
                  ? MarketplaceTheme.primaryBlue
                  : Colors.white,
              side: BorderSide(
                color: isSelected
                    ? MarketplaceTheme.primaryBlue
                    : Colors.grey.shade400,
                width: isSelected ? 2 : 1,
              ),
              padding: EdgeInsets.symmetric(
                horizontal:
                    ResponsiveLayout.getResponsivePadding(context) * 0.5,
                vertical: 4,
              ),
            );
          }).toList(),
        ),

        SizedBox(height: ResponsiveLayout.getResponsiveSpacing(context, 8)),

        // Services Categories
        Text(
          'Services Categories',
          style: MarketplaceTheme.bodyMedium.copyWith(
            fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: ResponsiveLayout.getResponsiveSpacing(context, 4)),
        Wrap(
          spacing: ResponsiveLayout.getResponsiveSpacing(context, 4),
          runSpacing: ResponsiveLayout.getResponsiveSpacing(context, 4),
          children: MarketplaceCategories.getServiceCategories().map((
            category,
          ) {
            final isSelected = _selectedCategory == category;
            return FilterChip(
              label: Text(
                category,
                style: TextStyle(
                  fontSize: ResponsiveLayout.getResponsiveFontSize(context, 11),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = selected ? category : 'All';
                  _selectedSubcategory = null;
                });
              },
              selectedColor: MarketplaceTheme.primaryGreen.withOpacity(0.2),
              checkmarkColor: MarketplaceTheme.primaryGreen,
              backgroundColor: isSelected
                  ? MarketplaceTheme.primaryGreen
                  : Colors.white,
              side: BorderSide(
                color: isSelected
                    ? MarketplaceTheme.primaryGreen
                    : Colors.grey.shade400,
                width: isSelected ? 2 : 1,
              ),
              padding: EdgeInsets.symmetric(
                horizontal:
                    ResponsiveLayout.getResponsivePadding(context) * 0.5,
                vertical: 4,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSubcategoryChips() {
    final subcategories = MarketplaceCategories.getSubcategories(
      _selectedCategory,
    );

    if (subcategories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Subcategories',
          style: MarketplaceTheme.bodyMedium.copyWith(
            fontSize: ResponsiveLayout.getResponsiveFontSize(context, 12),
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: ResponsiveLayout.getResponsiveSpacing(context, 4)),
        Wrap(
          spacing: ResponsiveLayout.getResponsiveSpacing(context, 4),
          runSpacing: ResponsiveLayout.getResponsiveSpacing(context, 4),
          children: subcategories.map((subcategory) {
            final isSelected = _selectedSubcategory == subcategory;
            return FilterChip(
              label: Text(
                subcategory,
                style: TextStyle(
                  fontSize: ResponsiveLayout.getResponsiveFontSize(context, 10),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedSubcategory = selected ? subcategory : null;
                });
              },
              selectedColor: MarketplaceTheme.primaryGreen.withOpacity(0.2),
              checkmarkColor: MarketplaceTheme.primaryGreen,
              backgroundColor: isSelected
                  ? MarketplaceTheme.primaryGreen
                  : Colors.white,
              side: BorderSide(
                color: isSelected
                    ? MarketplaceTheme.primaryGreen
                    : Colors.grey.shade400,
                width: isSelected ? 2 : 1,
              ),
              padding: EdgeInsets.symmetric(
                horizontal:
                    ResponsiveLayout.getResponsivePadding(context) * 0.4,
                vertical: 3,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActiveFilters() {
    return Container(
      padding: EdgeInsets.all(
        ResponsiveLayout.getResponsivePadding(context) * 0.75,
      ),
      decoration: BoxDecoration(
        color: MarketplaceTheme.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(MarketplaceTheme.radiusMd),
        border: Border.all(
          color: MarketplaceTheme.primaryBlue.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_alt, color: MarketplaceTheme.primaryBlue, size: 16),
          SizedBox(width: ResponsiveLayout.getResponsiveSpacing(context, 6)),
          Expanded(
            child: Text(
              'Active Filters: ${_selectedCategory != 'All' ? _selectedCategory : ''}${_selectedSubcategory != null ? ' > $_selectedSubcategory' : ''}',
              style: TextStyle(
                color: MarketplaceTheme.primaryBlue,
                fontSize: ResponsiveLayout.getResponsiveFontSize(context, 11),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedCategory = 'All';
                _selectedSubcategory = null;
              });
            },
            child: Text(
              'Clear All',
              style: TextStyle(
                color: MarketplaceTheme.primaryBlue,
                fontSize: ResponsiveLayout.getResponsiveFontSize(context, 11),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal:
                    ResponsiveLayout.getResponsivePadding(context) * 0.5,
                vertical: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Filtered stream methods
  Stream<QuerySnapshot> _getFilteredProductsStream() {
    Query query = FirebaseFirestore.instance.collection('products');

    // Apply category filter
    if (_selectedCategory != 'All') {
      query = query.where('category', isEqualTo: _selectedCategory);

      // Apply subcategory filter if selected
      if (_selectedSubcategory != null) {
        query = query.where('subcategory', isEqualTo: _selectedSubcategory);
      }
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot> _getFilteredServicesStream() {
    Query query = FirebaseFirestore.instance.collection('services');

    // Apply category filter
    if (_selectedCategory != 'All') {
      query = query.where('category', isEqualTo: _selectedCategory);

      // Apply subcategory filter if selected
      if (_selectedSubcategory != null) {
        query = query.where('subcategory', isEqualTo: _selectedSubcategory);
      }
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  Widget _buildSuggestions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: MarketplaceTheme.space4),
      decoration: MarketplaceTheme.cardDecoration,
      child: Column(
        children: _suggestions.take(5).map((suggestion) {
          return ListTile(
            leading: Icon(
              _getSuggestionIcon(suggestion.type),
              color: MarketplaceTheme.gray400,
              size: 20,
            ),
            title: Text(suggestion.text, style: MarketplaceTheme.bodyMedium),
            trailing: Text(
              _getSuggestionTypeLabel(suggestion.type),
              style: MarketplaceTheme.labelMedium,
            ),
            onTap: () {
              _searchController.text = suggestion.text;
              _performSearch(suggestion.text);
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Consumer<EnhancedMarketplaceProvider>(
      builder: (context, marketplace, child) {
        return Container(
          padding: EdgeInsets.all(
            ResponsiveLayout.getResponsivePadding(context) * 0.75,
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Products',
                  marketplace.products.length.toString(),
                  Icons.inventory,
                  MarketplaceTheme.primaryBlue,
                ),
              ),
              SizedBox(
                width: ResponsiveLayout.getResponsiveSpacing(context, 8),
              ),
              Expanded(
                child: _buildStatCard(
                  'Services',
                  marketplace.services.length.toString(),
                  Icons.work,
                  MarketplaceTheme.primaryGreen,
                ),
              ),
              SizedBox(
                width: ResponsiveLayout.getResponsiveSpacing(context, 8),
              ),
              Expanded(
                child: _buildStatCard(
                  'Vendors',
                  marketplace.vendors.length.toString(),
                  Icons.store,
                  MarketplaceTheme.primaryOrange,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(
        ResponsiveLayout.getResponsivePadding(context) * 0.5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: ResponsiveLayout.getResponsiveSpacing(context, 4)),
          Text(
            value,
            style: MarketplaceTheme.headingMedium.copyWith(
              color: color,
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 16),
            ),
          ),
          Text(
            label,
            style: MarketplaceTheme.labelMedium.copyWith(
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: MarketplaceTheme.error),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: MarketplaceTheme.headingLarge.copyWith(
                color: MarketplaceTheme.gray900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: MarketplaceTheme.bodyMedium.copyWith(
                color: MarketplaceTheme.gray600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final marketplace = context.read<EnhancedMarketplaceProvider>();
                marketplace.retryInitialization();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: MarketplaceTheme.primaryBlue,
                foregroundColor: MarketplaceTheme.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              MarketplaceTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading marketplace...',
            style: MarketplaceTheme.bodyMedium.copyWith(
              color: MarketplaceTheme.gray600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSection() {
    return Container(
      color: MarketplaceTheme.white,
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Featured'),
          Tab(text: 'Products'),
          Tab(text: 'Services'),
        ],
        labelColor: MarketplaceTheme.primaryBlue,
        unselectedLabelColor: MarketplaceTheme.gray500,
        indicatorColor: MarketplaceTheme.primaryBlue,
        indicatorWeight: 3,
        labelStyle: MarketplaceTheme.titleLarge,
        unselectedLabelStyle: MarketplaceTheme.bodyMedium,
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [_buildFeaturedTab(), _buildProductsTab(), _buildServicesTab()],
    );
  }

  Widget _buildFeaturedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getFilteredProductsStream(),
      builder: (context, productSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: _getFilteredServicesStream(),
          builder: (context, serviceSnapshot) {
            if (productSnapshot.connectionState == ConnectionState.waiting ||
                serviceSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingGrid();
            }

            final featuredProducts = (productSnapshot.data?.docs ?? [])
                .take(6)
                .map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Product(
                    id: doc.id,
                    vendorId: data['vendorId'] ?? data['vendor_id'] ?? '',
                    name: data['name'] ?? data['title'] ?? 'Untitled Product',
                    description:
                        data['description'] ??
                        data['desc'] ??
                        'No description available',
                    images: List<String>.from(
                      data['images'] ?? data['imageUrls'] ?? [],
                    ),
                    price: (data['price'] ?? 0.0).toDouble(),
                    inventory: data['inventory'] ?? data['stock'] ?? 0,
                    category: data['category'] ?? '',
                    subcategory: data['subcategory'] ?? '',
                    shippingOptions: List<String>.from(
                      data['shippingOptions'] ?? data['shipping_options'] ?? [],
                    ),
                  );
                })
                .toList();

            final featuredServices = (serviceSnapshot.data?.docs ?? [])
                .take(4)
                .map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Service(
                    id: doc.id,
                    vendorId: data['vendorId'] ?? data['vendor_id'] ?? '',
                    title: data['title'] ?? data['name'] ?? 'Untitled Service',
                    description:
                        data['description'] ??
                        data['desc'] ??
                        'No description available',
                    images: List<String>.from(
                      data['images'] ?? data['imageUrls'] ?? [],
                    ),
                    packages: (data['packages'] as List? ?? [])
                        .map(
                          (p) => ServicePackage(
                            name: p['name'] ?? p['title'] ?? '',
                            description: p['description'] ?? p['desc'] ?? '',
                            price: (p['price'] ?? 0.0).toDouble(),
                            deliveryTime:
                                p['deliveryTime'] ?? p['delivery_time'] ?? '',
                          ),
                        )
                        .toList(),
                    deliveryTime:
                        data['deliveryTime'] ?? data['delivery_time'] ?? 0,
                    category: data['category'] ?? '',
                    subcategory: data['subcategory'] ?? '',
                    requirements: List<String>.from(data['requirements'] ?? []),
                  );
                })
                .toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(MarketplaceTheme.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categories section
                  _buildSectionHeader(
                    'Browse Categories',
                    onViewAll: _viewAllCategories,
                  ),
                  const SizedBox(height: MarketplaceTheme.space3),
                  _buildCategoriesGrid(),

                  const SizedBox(height: MarketplaceTheme.space6),

                  // Featured products
                  if (featuredProducts.isNotEmpty) ...[
                    _buildSectionHeader(
                      'Featured Products',
                      onViewAll: () => _tabController.index = 1,
                    ),
                    const SizedBox(height: MarketplaceTheme.space3),
                    _buildProductsGrid(featuredProducts),

                    const SizedBox(height: MarketplaceTheme.space6),
                  ],

                  // Featured services
                  if (featuredServices.isNotEmpty) ...[
                    _buildSectionHeader(
                      'Popular Services',
                      onViewAll: () => _tabController.index = 2,
                    ),
                    const SizedBox(height: MarketplaceTheme.space3),
                    _buildServicesGrid(featuredServices),

                    const SizedBox(height: MarketplaceTheme.space6),
                  ],

                  // Top vendors
                  _buildSectionHeader(
                    'Top Vendors',
                    onViewAll: _viewAllVendors,
                  ),
                  const SizedBox(height: MarketplaceTheme.space3),
                  _buildVendorsRow(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProductsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getFilteredProductsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingGrid();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('No products available yet');
        }

        final products = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Product(
            id: doc.id,
            vendorId: data['vendorId'] ?? data['vendor_id'] ?? '',
            name: data['name'] ?? data['title'] ?? 'Untitled Product',
            description:
                data['description'] ??
                data['desc'] ??
                'No description available',
            images: List<String>.from(
              data['images'] ?? data['imageUrls'] ?? [],
            ),
            price: (data['price'] ?? 0.0).toDouble(),
            inventory: data['inventory'] ?? data['stock'] ?? 0,
            category: data['category'] ?? '',
            subcategory: data['subcategory'] ?? '',
            shippingOptions: List<String>.from(
              data['shippingOptions'] ?? data['shipping_options'] ?? [],
            ),
          );
        }).toList();

        return RefreshIndicator(
          onRefresh: () async {
            // Refresh is handled automatically by StreamBuilder
          },
          child: GridView.builder(
            padding: EdgeInsets.all(
              ResponsiveLayout.getResponsivePadding(context),
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveLayout.getGridCrossAxisCount(context),
              crossAxisSpacing: ResponsiveLayout.getResponsiveSpacing(
                context,
                12,
              ),
              mainAxisSpacing: ResponsiveLayout.getResponsiveSpacing(
                context,
                12,
              ),
              childAspectRatio: ResponsiveLayout.isMobile(context) ? 0.75 : 0.8,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildResponsiveProductCard(product);
            },
          ),
        );
      },
    );
  }

  Widget _buildServicesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getFilteredServicesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingGrid();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('No services available yet');
        }

        final services = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Service(
            id: doc.id,
            vendorId: data['vendorId'] ?? data['vendor_id'] ?? '',
            title: data['title'] ?? data['name'] ?? 'Untitled Service',
            description:
                data['description'] ??
                data['desc'] ??
                'No description available',
            images: List<String>.from(
              data['images'] ?? data['imageUrls'] ?? [],
            ),
            packages: (data['packages'] as List? ?? [])
                .map(
                  (p) => ServicePackage(
                    name: p['name'] ?? p['title'] ?? '',
                    description: p['description'] ?? p['desc'] ?? '',
                    price: (p['price'] ?? 0.0).toDouble(),
                    deliveryTime: p['deliveryTime'] ?? p['delivery_time'] ?? '',
                  ),
                )
                .toList(),
            deliveryTime: data['deliveryTime'] ?? data['delivery_time'] ?? 0,
            category: data['category'] ?? '',
            subcategory: data['subcategory'] ?? '',
            requirements: List<String>.from(data['requirements'] ?? []),
          );
        }).toList();

        return RefreshIndicator(
          onRefresh: () async {
            // Refresh is handled automatically by StreamBuilder
          },
          child: ListView.builder(
            padding: EdgeInsets.all(
              ResponsiveLayout.getResponsivePadding(context),
            ),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              return Container(
                margin: EdgeInsets.only(
                  bottom: ResponsiveLayout.getResponsiveSpacing(context, 12),
                ),
                child: _buildResponsiveServiceCard(service),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onViewAll}) {
    return Row(
      children: [
        Text(title, style: MarketplaceTheme.headingMedium),
        const Spacer(),
        if (onViewAll != null)
          GestureDetector(
            onTap: onViewAll,
            child: Text(
              'View All',
              style: MarketplaceTheme.bodyMedium.copyWith(
                color: MarketplaceTheme.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoriesGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, productSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('services').snapshots(),
          builder: (context, serviceSnapshot) {
            if (!productSnapshot.hasData && !serviceSnapshot.hasData) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            // Extract category counts from real data
            final Map<String, int> categoryCounts = {};

            // Count products by main category
            if (productSnapshot.hasData) {
              for (var doc in productSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final category = data['category']?.toString();
                if (category != null && category.isNotEmpty) {
                  categoryCounts[category] =
                      (categoryCounts[category] ?? 0) + 1;
                }
              }
            }

            // Count services by main category
            if (serviceSnapshot.hasData) {
              for (var doc in serviceSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final category = data['category']?.toString();
                if (category != null && category.isNotEmpty) {
                  categoryCounts[category] =
                      (categoryCounts[category] ?? 0) + 1;
                }
              }
            }

            // Use predefined categories, showing count if available
            final allCategories = MarketplaceCategories.getAllCategories();
            final displayCategories = allCategories
                .take(8)
                .map(
                  (category) => {
                    'name': category,
                    'icon': MarketplaceCategories.getCategoryIcon(category),
                    'count': categoryCounts[category] ?? 0,
                    'type': MarketplaceCategories.getCategoryType(category),
                  },
                )
                .toList();

            if (displayCategories.isEmpty) {
              return Container(
                height: 200,
                child: const Center(child: Text('No categories available')),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ResponsiveLayout.isMobile(context) ? 2 : 4,
                crossAxisSpacing: ResponsiveLayout.getResponsiveSpacing(
                  context,
                  12,
                ),
                mainAxisSpacing: ResponsiveLayout.getResponsiveSpacing(
                  context,
                  12,
                ),
                childAspectRatio: ResponsiveLayout.isMobile(context)
                    ? 1.2
                    : 1.0,
              ),
              itemCount: displayCategories.length,
              itemBuilder: (context, index) {
                final category = displayCategories[index];
                return _buildCategoryCard(
                  name: category['name'] as String,
                  icon: category['icon'] as String,
                  count: category['count'] as int,
                  type: category['type'] as String,
                  onTap: () => _searchCategory(category['name'] as String),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildProductsGrid(List products) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: MarketplaceTheme.space3,
        mainAxisSpacing: MarketplaceTheme.space3,
        childAspectRatio: 0.75,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ModernMarketplaceWidgets.productCard(
          product: product,
          onTap: () => _openProductDetail(product),
          onFavorite: () => _toggleFavorite(product.id),
          isFavorite: false,
        );
      },
    );
  }

  Widget _buildServicesGrid(List services) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return Container(
          margin: const EdgeInsets.only(bottom: MarketplaceTheme.space3),
          child: ModernMarketplaceWidgets.serviceCard(
            service: service,
            onTap: () => _openServiceDetail(service),
            onFavorite: () => _toggleFavorite(service.id),
            isFavorite: false,
          ),
        );
      },
    );
  }

  Widget _buildVendorsRow() {
    return Consumer<EnhancedMarketplaceProvider>(
      builder: (context, marketplace, child) {
        if (marketplace.vendors.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: marketplace.vendors.length,
            itemBuilder: (context, index) {
              final vendor = marketplace.vendors[index];
              return Container(
                width: 160,
                margin: EdgeInsets.only(
                  right: index < marketplace.vendors.length - 1
                      ? MarketplaceTheme.space3
                      : 0,
                ),
                child: ModernMarketplaceWidgets.vendorCard(
                  vendor: vendor,
                  onTap: () => _openVendorProfile(vendor),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(MarketplaceTheme.space4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: MarketplaceTheme.space3,
        mainAxisSpacing: MarketplaceTheme.space3,
        childAspectRatio: 0.75,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => _buildShimmerCard(),
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      decoration: MarketplaceTheme.cardDecoration,
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: const BoxDecoration(
                color: MarketplaceTheme.gray200,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(MarketplaceTheme.radiusXl),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(MarketplaceTheme.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: MarketplaceTheme.gray200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 100,
                    decoration: BoxDecoration(
                      color: MarketplaceTheme.gray200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: MarketplaceTheme.gray100,
          borderRadius: BorderRadius.circular(MarketplaceTheme.radiusXl),
          border: Border.all(color: MarketplaceTheme.gray200),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 32, color: MarketplaceTheme.gray400),
            SizedBox(height: MarketplaceTheme.space2),
            Text('Load More', style: MarketplaceTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  // Helper methods

  IconData _getSuggestionIcon(SuggestionType type) {
    switch (type) {
      case SuggestionType.recent:
        return Icons.history;
      case SuggestionType.popular:
        return Icons.trending_up;
      case SuggestionType.category:
        return Icons.category;
      case SuggestionType.product:
        return Icons.inventory;
      case SuggestionType.service:
        return Icons.work;
      case SuggestionType.vendor:
        return Icons.store;
    }
  }

  String _getSuggestionTypeLabel(SuggestionType type) {
    switch (type) {
      case SuggestionType.recent:
        return 'Recent';
      case SuggestionType.popular:
        return 'Popular';
      case SuggestionType.category:
        return 'Category';
      case SuggestionType.product:
        return 'Product';
      case SuggestionType.service:
        return 'Service';
      case SuggestionType.vendor:
        return 'Vendor';
    }
  }

  // Responsive card builders

  Widget _buildResponsiveProductCard(Product product) {
    return GestureDetector(
      onTap: () => _openProductDetail(product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
          boxShadow: const [MarketplaceTheme.smallShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(MarketplaceTheme.radiusLg),
                ),
                child: ProductImageWidget(
                  imageUrl: product.images.isNotEmpty
                      ? product.images.first
                      : null,
                  isGrid: true,
                ),
              ),
            ),
            // Product details
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(
                  ResponsiveLayout.getResponsivePadding(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        product.name,
                        style: MarketplaceTheme.titleLarge.copyWith(
                          fontSize: ResponsiveLayout.getResponsiveFontSize(
                            context,
                            14,
                          ),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: MarketplaceTheme.titleLarge.copyWith(
                          color: MarketplaceTheme.primaryBlue,
                          fontSize: ResponsiveLayout.getResponsiveFontSize(
                            context,
                            16,
                          ),
                        ),
                      ),
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

  Widget _buildResponsiveServiceCard(Service service) {
    return GestureDetector(
      onTap: () => _openServiceDetail(service),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
          boxShadow: const [MarketplaceTheme.smallShadow],
        ),
        child: Padding(
          padding: EdgeInsets.all(
            ResponsiveLayout.getResponsivePadding(context),
          ),
          child: Row(
            children: [
              // Service image
              ClipRRect(
                borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
                child: SizedBox(
                  width: ResponsiveLayout.isMobile(context) ? 80 : 120,
                  height: ResponsiveLayout.isMobile(context) ? 80 : 120,
                  child: ServiceImageWidget(
                    imageUrl: service.images.isNotEmpty
                        ? service.images.first
                        : null,
                    size: ResponsiveLayout.isMobile(context) ? 80 : 120,
                  ),
                ),
              ),

              SizedBox(
                width: ResponsiveLayout.getResponsiveSpacing(context, 12),
              ),

              // Service details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title,
                      style: MarketplaceTheme.titleLarge.copyWith(
                        fontSize: ResponsiveLayout.getResponsiveFontSize(
                          context,
                          16,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      service.description,
                      style: MarketplaceTheme.bodyMedium.copyWith(
                        fontSize: ResponsiveLayout.getResponsiveFontSize(
                          context,
                          14,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Starting at \$${service.packages.isNotEmpty ? service.packages.first.price.toStringAsFixed(2) : "0.00"}',
                      style: MarketplaceTheme.titleLarge.copyWith(
                        color: MarketplaceTheme.primaryBlue,
                        fontSize: ResponsiveLayout.getResponsiveFontSize(
                          context,
                          16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      color: Colors.grey.shade200,
      child: Icon(
        Icons.image,
        size: ResponsiveLayout.isMobile(context) ? 40 : 60,
        color: Colors.grey.shade400,
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: MarketplaceTheme.bodyLarge.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required String name,
    required String icon,
    required int count,
    required String type,
    required VoidCallback onTap,
  }) {
    final isGoods = type == 'goods';
    final cardColor = isGoods
        ? MarketplaceTheme.primaryBlue.withOpacity(0.1)
        : MarketplaceTheme.primaryGreen.withOpacity(0.1);
    final borderColor = isGoods
        ? MarketplaceTheme.primaryBlue
        : MarketplaceTheme.primaryGreen;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
          border: Border.all(color: borderColor.withOpacity(0.2)),
          boxShadow: const [MarketplaceTheme.smallShadow],
        ),
        child: Padding(
          padding: EdgeInsets.all(
            ResponsiveLayout.getResponsivePadding(context),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with background
              Container(
                width: ResponsiveLayout.isMobile(context) ? 40 : 50,
                height: ResponsiveLayout.isMobile(context) ? 40 : 50,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(
                    MarketplaceTheme.radiusMd,
                  ),
                ),
                child: Center(
                  child: Text(
                    icon,
                    style: TextStyle(
                      fontSize: ResponsiveLayout.getResponsiveFontSize(
                        context,
                        20,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(
                height: ResponsiveLayout.getResponsiveSpacing(context, 8),
              ),

              // Category name
              Flexible(
                child: Text(
                  name,
                  style: MarketplaceTheme.titleLarge.copyWith(
                    fontSize: ResponsiveLayout.getResponsiveFontSize(
                      context,
                      12,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              SizedBox(
                height: ResponsiveLayout.getResponsiveSpacing(context, 4),
              ),

              // Count and type badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          ResponsiveLayout.getResponsivePadding(context) / 2,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: borderColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(
                        MarketplaceTheme.radiusSm,
                      ),
                    ),
                    child: Text(
                      '$count items',
                      style: MarketplaceTheme.bodyMedium.copyWith(
                        color: borderColor,
                        fontSize: ResponsiveLayout.getResponsiveFontSize(
                          context,
                          10,
                        ),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Navigation methods

  void _openProductDetail(dynamic product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
    );
  }

  void _openServiceDetail(dynamic service) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ServiceDetailScreen(service: service)),
    );
  }

  void _openVendorProfile(dynamic vendor) {
    // Navigate to vendor profile when implemented
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Vendor profile: ${vendor.displayName}')),
    );
  }

  void _searchCategory(String category) {
    _performSearch(category);
  }

  void _toggleFavorite(String itemId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Favorites feature coming soon!')),
    );
  }

  void _viewAllCategories() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FunctionalSearchScreen()),
    );
  }

  void _viewAllVendors() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vendor directory coming soon!')),
    );
  }

  void _showFilters() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FunctionalSearchScreen()),
    );
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FunctionalCartScreen()),
    );
  }
}
