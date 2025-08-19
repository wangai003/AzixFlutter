import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../providers/unified_cart_provider.dart';
import '../models/search_filter.dart';
import '../models/product.dart';
import '../models/service.dart';
import '../theme/app_theme.dart';
import 'product_detail_screen.dart';
import 'service_detail_screen.dart';

/// Advanced search screen with filtering, sorting, and modern UI
class AdvancedSearchScreen extends StatefulWidget {
  final String? initialQuery;

  const AdvancedSearchScreen({Key? key, this.initialQuery}) : super(key: key);

  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen>
    with TickerProviderStateMixin {
  
  late TextEditingController _searchController;
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  
  bool _showFilters = false;
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _tabController = TabController(length: 3, vsync: this);
    
    // Initialize search provider and perform initial search if query provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final searchProvider = Provider.of<SearchProvider>(context, listen: false);
      searchProvider.initialize();
      
      if (widget.initialQuery?.isNotEmpty == true) {
        searchProvider.quickSearch(widget.initialQuery!);
      }
    });

    // Setup infinite scroll
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      Provider.of<SearchProvider>(context, listen: false).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SearchProvider>(
      builder: (context, searchProvider, _) {
        return Scaffold(
          backgroundColor: AppTheme.black,
          body: SafeArea(
            child: Column(
              children: [
                // Search Header
                _buildSearchHeader(searchProvider),
                
                // Filter Bar
                if (_showFilters) _buildFilterBar(searchProvider),
                
                // Results Header
                _buildResultsHeader(searchProvider),
                
                // Content
                Expanded(
                  child: _buildContent(searchProvider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchHeader(SearchProvider searchProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: AppTheme.primaryGold),
              ),
              
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: AppTheme.bodyMedium.copyWith(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search products and services...',
                      hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                      prefixIcon: Icon(Icons.search, color: AppTheme.primaryGold),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                searchProvider.clearSearch();
                              },
                              icon: Icon(Icons.clear, color: AppTheme.grey),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (query) => searchProvider.quickSearch(query),
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Filter Toggle
              IconButton(
                onPressed: () => setState(() => _showFilters = !_showFilters),
                icon: Stack(
                  children: [
                    Icon(
                      Icons.tune,
                      color: _showFilters ? AppTheme.primaryGold : AppTheme.grey,
                    ),
                    if (searchProvider.currentFilter.activeFilterCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGold,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          
          // Search Suggestions
          if (_searchController.text.isEmpty && searchProvider.searchHistory.isNotEmpty)
            _buildSearchSuggestions(searchProvider),
        ],
      ),
    );
  }

  Widget _buildSearchSuggestions(SearchProvider searchProvider) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: searchProvider.searchHistory.take(5).length,
        itemBuilder: (context, index) {
          final query = searchProvider.searchHistory[index];
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(
                query,
                style: AppTheme.bodySmall.copyWith(color: AppTheme.primaryGold),
              ),
              backgroundColor: AppTheme.primaryGold.withOpacity(0.1),
              side: BorderSide(color: AppTheme.primaryGold.withOpacity(0.3)),
              onPressed: () {
                _searchController.text = query;
                searchProvider.quickSearch(query);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(SearchProvider searchProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.darkGrey.withOpacity(0.5),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Type Filter
            _buildFilterChip(
              'Type: ${searchProvider.currentFilter.type.displayName}',
              Icons.category,
              () => _showTypeFilter(searchProvider),
            ),
            
            const SizedBox(width: 8),
            
            // Category Filter
            if (searchProvider.currentFilter.categories.isNotEmpty)
              _buildFilterChip(
                'Categories (${searchProvider.currentFilter.categories.length})',
                Icons.label,
                () => _showCategoryFilter(searchProvider),
              ),
            
            const SizedBox(width: 8),
            
            // Price Filter
            if (searchProvider.currentFilter.priceRange != null)
              _buildFilterChip(
                searchProvider.currentFilter.priceRange.toString(),
                Icons.attach_money,
                () => _showPriceFilter(searchProvider),
              ),
            
            const SizedBox(width: 8),
            
            // Sort Filter
            _buildFilterChip(
              searchProvider.currentFilter.sortBy.displayName,
              searchProvider.currentFilter.sortBy.icon,
              () => _showSortFilter(searchProvider),
            ),
            
            const SizedBox(width: 8),
            
            // Clear Filters
            if (searchProvider.currentFilter.activeFilterCount > 0)
              TextButton.icon(
                onPressed: () => searchProvider.updateFilter(const SearchFilter()),
                icon: Icon(Icons.clear_all, color: Colors.red, size: 16),
                label: Text(
                  'Clear All',
                  style: AppTheme.bodySmall.copyWith(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryGold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.primaryGold, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.primaryGold,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsHeader(SearchProvider searchProvider) {
    if (!searchProvider.hasResults && !searchProvider.isLoading) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.darkGrey.withOpacity(0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${searchProvider.totalResults} results',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
          ),
          
          Row(
            children: [
              // View Toggle
              IconButton(
                onPressed: () => setState(() => _isGridView = !_isGridView),
                icon: Icon(
                  _isGridView ? Icons.list : Icons.grid_view,
                  color: AppTheme.primaryGold,
                ),
              ),
              
              // Tab Controller for Products/Services
              if (searchProvider.currentFilter.type == SearchType.both) ...[
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: 'All (${searchProvider.totalResults})'),
                      Tab(text: '📦 Products (${searchProvider.productResults.length})'),
                      Tab(text: '🛠️ Services (${searchProvider.serviceResults.length})'),
                    ],
                    labelColor: AppTheme.primaryGold,
                    unselectedLabelColor: AppTheme.grey,
                    indicatorColor: AppTheme.primaryGold,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelStyle: AppTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(SearchProvider searchProvider) {
    if (searchProvider.isLoading && !searchProvider.hasResults) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGold),
      );
    }

    if (!searchProvider.hasResults && searchProvider.currentFilter.query.isNotEmpty) {
      return _buildNoResults(searchProvider);
    }

    if (searchProvider.currentFilter.query.isEmpty) {
      return _buildEmptyState(searchProvider);
    }

    // Show results based on tab selection
    if (searchProvider.currentFilter.type == SearchType.both) {
      return TabBarView(
        controller: _tabController,
        children: [
          _buildAllResults(searchProvider),
          _buildProductResults(searchProvider),
          _buildServiceResults(searchProvider),
        ],
      );
    } else if (searchProvider.currentFilter.type == SearchType.products) {
      return _buildProductResults(searchProvider);
    } else {
      return _buildServiceResults(searchProvider);
    }
  }

  Widget _buildEmptyState(SearchProvider searchProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Popular Searches
          if (searchProvider.popularSearches.isNotEmpty) ...[
            Text(
              'Popular Searches',
              style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: searchProvider.popularSearches.map((search) {
                return ActionChip(
                  label: Text(search),
                  backgroundColor: AppTheme.darkGrey,
                  labelStyle: AppTheme.bodySmall.copyWith(color: Colors.white),
                  onPressed: () {
                    _searchController.text = search;
                    searchProvider.quickSearch(search);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          
          // Categories
          Text(
            'Browse Categories',
            style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold),
          ),
          const SizedBox(height: 12),
          
          // Product Categories
          if (searchProvider.productCategories.isNotEmpty) ...[
            Text(
              'Products',
              style: AppTheme.bodyLarge.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            ...searchProvider.productCategories.keys.take(5).map((category) {
              return ListTile(
                leading: const Icon(Icons.inventory, color: AppTheme.primaryGold),
                title: Text(
                  category,
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white),
                ),
                trailing: Icon(Icons.arrow_forward_ios, color: AppTheme.grey, size: 16),
                onTap: () {
                  searchProvider.updateFilter(
                    searchProvider.currentFilter.copyWith(
                      type: SearchType.products,
                      categories: [category],
                    ),
                  );
                },
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildNoResults(SearchProvider searchProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: AppTheme.grey),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: AppTheme.headingMedium.copyWith(color: AppTheme.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.lightGrey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => searchProvider.updateFilter(const SearchFilter()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: AppTheme.black,
            ),
            child: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildAllResults(SearchProvider searchProvider) {
    final allItems = <dynamic>[];
    allItems.addAll(searchProvider.productResults);
    allItems.addAll(searchProvider.serviceResults);
    
    // Sort combined results (simplified)
    allItems.shuffle(); // In production, implement proper mixed sorting
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: allItems.length + (searchProvider.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= allItems.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppTheme.primaryGold),
            ),
          );
        }
        
        final item = allItems[index];
        if (item is Product) {
          return _buildProductCard(item);
        } else if (item is Service) {
          return _buildServiceCard(item);
        }
        
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildProductResults(SearchProvider searchProvider) {
    if (_isGridView) {
      return GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: searchProvider.productResults.length + (searchProvider.isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= searchProvider.productResults.length) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGold),
            );
          }
          return _buildProductGridCard(searchProvider.productResults[index]);
        },
      );
    }
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: searchProvider.productResults.length + (searchProvider.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= searchProvider.productResults.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppTheme.primaryGold),
            ),
          );
        }
        return _buildProductCard(searchProvider.productResults[index]);
      },
    );
  }

  Widget _buildServiceResults(SearchProvider searchProvider) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: searchProvider.serviceResults.length + (searchProvider.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= searchProvider.serviceResults.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppTheme.primaryGold),
            ),
          );
        }
        return _buildServiceCard(searchProvider.serviceResults[index]);
      },
    );
  }

  Widget _buildProductCard(Product product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppTheme.lightGrey,
            borderRadius: BorderRadius.circular(8),
            image: product.images.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(product.images.first),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: product.images.isEmpty
              ? Icon(Icons.inventory, color: AppTheme.grey)
              : null,
        ),
        title: Text(
          '📦 ${product.name}',
          style: AppTheme.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.description,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '₳${product.price.toStringAsFixed(2)}',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.primaryGold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: _buildAddToCartButton(product),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        ),
      ),
    );
  }

  Widget _buildProductGridCard(Product product) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.lightGrey,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                image: product.images.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(product.images.first),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: product.images.isEmpty
                  ? Icon(Icons.inventory, color: AppTheme.grey, size: 40)
                  : null,
            ),
          ),
          
          // Product Info
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppTheme.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text(
                    '₳${product.price.toStringAsFixed(2)}',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
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

  Widget _buildServiceCard(Service service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppTheme.lightGrey,
            borderRadius: BorderRadius.circular(8),
            image: service.images.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(service.images.first),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: service.images.isEmpty
              ? Icon(Icons.design_services, color: AppTheme.grey)
              : null,
        ),
        title: Text(
          '🛠️ ${service.title}',
          style: AppTheme.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              service.description,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'From ₳${service.packages.isNotEmpty ? service.packages.first.price : 0}',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.primaryGold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: AppTheme.grey, size: 16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceDetailScreen(service: service),
          ),
        ),
      ),
    );
  }

  Widget _buildAddToCartButton(Product product) {
    return Consumer<UnifiedCartProvider>(
      builder: (context, cart, _) {
        final isInCart = cart.isProductInCart(product.id);
        
        return IconButton(
          onPressed: () {
            if (isInCart) {
              cart.removeProduct(product.id);
            } else {
              cart.addProduct(product);
            }
          },
          icon: Icon(
            isInCart ? Icons.remove_shopping_cart : Icons.add_shopping_cart,
            color: isInCart ? Colors.red : AppTheme.primaryGold,
          ),
        );
      },
    );
  }

  // Filter Dialog Methods
  void _showTypeFilter(SearchProvider searchProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkGrey,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: SearchType.values.map((type) {
          return ListTile(
            leading: Text(type.icon, style: const TextStyle(fontSize: 24)),
            title: Text(
              type.displayName,
              style: AppTheme.bodyMedium.copyWith(color: Colors.white),
            ),
            trailing: searchProvider.currentFilter.type == type
                ? Icon(Icons.check, color: AppTheme.primaryGold)
                : null,
            onTap: () {
              searchProvider.updateFilter(
                searchProvider.currentFilter.copyWith(type: type),
              );
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showCategoryFilter(SearchProvider searchProvider) {
    // Implementation for category filter dialog
    // Similar pattern to type filter
  }

  void _showPriceFilter(SearchProvider searchProvider) {
    // Implementation for price range filter dialog
    // Could use a RangeSlider widget
  }

  void _showSortFilter(SearchProvider searchProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkGrey,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: SortOption.values.map((sort) {
          return ListTile(
            leading: Icon(sort.icon, color: AppTheme.primaryGold),
            title: Text(
              sort.displayName,
              style: AppTheme.bodyMedium.copyWith(color: Colors.white),
            ),
            trailing: searchProvider.currentFilter.sortBy == sort
                ? Icon(Icons.check, color: AppTheme.primaryGold)
                : null,
            onTap: () {
              searchProvider.updateFilter(
                searchProvider.currentFilter.copyWith(sortBy: sort),
              );
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }
}
