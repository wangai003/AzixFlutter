import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/marketplace_theme.dart';
import '../../services/marketplace/search_service.dart';
import '../../models/product.dart';
import '../../utils/marketplace_categories.dart';

import 'product_detail_screen.dart';

/// Functional search screen with advanced filtering and suggestions
class FunctionalSearchScreen extends StatefulWidget {
  final String? initialQuery;
  
  const FunctionalSearchScreen({Key? key, this.initialQuery}) : super(key: key);

  @override
  State<FunctionalSearchScreen> createState() => _FunctionalSearchScreenState();
}

class _FunctionalSearchScreenState extends State<FunctionalSearchScreen>
    with TickerProviderStateMixin {
  
  final TextEditingController _searchController = TextEditingController();
  final AdvancedSearchService _searchService = AdvancedSearchService();
  
  late TabController _tabController;
  SearchResults? _searchResults;
  List<SearchSuggestion> _suggestions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;
  
  // Filters
  SearchType _selectedSearchType = SearchType.all;
  List<String> _selectedCategories = [];
  PriceRange? _priceRange;
  double _minRating = 0.0;
  SortBy _sortBy = SortBy.relevance;
  
  List<String> _categories = ['All', ...MarketplaceCategories.getAllCategories()];
  List<String> _subcategories = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _performSearch();
    }
    
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query.isNotEmpty) {
      _getSuggestions(query);
      setState(() => _showSuggestions = true);
    } else {
      setState(() => _showSuggestions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketplaceTheme.gray50,
      appBar: AppBar(
        title: const Text('Search'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        bottom: _searchResults != null ? TabBar(
          controller: _tabController,
          labelColor: MarketplaceTheme.primaryBlue,
          unselectedLabelColor: MarketplaceTheme.gray500,
          indicatorColor: MarketplaceTheme.primaryBlue,
          tabs: [
            Tab(text: 'All (${_searchResults!.totalCount})'),
            Tab(text: 'Products (${_searchResults!.products.length})'),
            Tab(text: 'Services (${_searchResults!.services.length})'),
            Tab(text: 'Vendors (${_searchResults!.vendors.length})'),
          ],
        ) : null,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_showSuggestions && _suggestions.isNotEmpty)
            _buildSuggestions()
          else if (_searchResults != null)
            Expanded(child: _buildSearchResults()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products, services, or vendors...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchResults = null;
                                _showSuggestions = false;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: MarketplaceTheme.gray300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: MarketplaceTheme.primaryBlue),
                    ),
                  ),
                  onSubmitted: (_) => _performSearch(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _showFilters,
                icon: Icon(
                  Icons.tune,
                  color: MarketplaceTheme.primaryBlue,
                ),
              ),
            ],
          ),
          
          if (_searchResults != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', _selectedSearchType == SearchType.all, () {
                          setState(() => _selectedSearchType = SearchType.all);
                          _performSearch();
                        }),
                        _buildFilterChip('Products', _selectedSearchType == SearchType.products, () {
                          setState(() => _selectedSearchType = SearchType.products);
                          _performSearch();
                        }),
                        _buildFilterChip('Services', _selectedSearchType == SearchType.services, () {
                          setState(() => _selectedSearchType = SearchType.services);
                          _performSearch();
                        }),
                        _buildFilterChip('Vendors', _selectedSearchType == SearchType.vendors, () {
                          setState(() => _selectedSearchType = SearchType.vendors);
                          _performSearch();
                        }),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<SortBy>(
                  icon: Icon(Icons.sort, color: MarketplaceTheme.primaryBlue),
                  onSelected: (sortBy) {
                    setState(() => _sortBy = sortBy);
                    _performSearch();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: SortBy.relevance, child: Text('Relevance')),
                    const PopupMenuItem(value: SortBy.priceAsc, child: Text('Price: Low to High')),
                    const PopupMenuItem(value: SortBy.priceDesc, child: Text('Price: High to Low')),
                    const PopupMenuItem(value: SortBy.rating, child: Text('Rating')),
                    const PopupMenuItem(value: SortBy.newest, child: Text('Newest')),
                    const PopupMenuItem(value: SortBy.popular, child: Text('Popular')),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? MarketplaceTheme.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? MarketplaceTheme.primaryBlue : MarketplaceTheme.gray300,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : MarketplaceTheme.gray700,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      color: Colors.white,
      child: Column(
        children: _suggestions.map((suggestion) {
          return ListTile(
            leading: Icon(
              _getSuggestionIcon(suggestion.type),
              color: MarketplaceTheme.gray500,
            ),
            title: Text(suggestion.text),
            subtitle: Text(_getSuggestionTypeText(suggestion.type)),
            trailing: const Icon(Icons.north_west, size: 16),
            onTap: () {
              _searchController.text = suggestion.text;
              setState(() => _showSuggestions = false);
              _performSearch();
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults == null || _searchResults!.totalCount == 0) {
      return _buildEmptyResults();
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildAllResults(),
        _buildProductResults(),
        _buildServiceResults(),
        _buildVendorResults(),
      ],
    );
  }

  Widget _buildEmptyResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: MarketplaceTheme.gray400,
          ),
          const SizedBox(height: 24),
          const Text(
            'No results found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search or filters',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAllResults() {
    final allResults = [
      ..._searchResults!.products,
      ..._searchResults!.services,
      ..._searchResults!.vendors,
    ];
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allResults.length,
      itemBuilder: (context, index) {
        final result = allResults[index];
        return _buildResultCard(result);
      },
    );
  }

  Widget _buildProductResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults!.products.length,
      itemBuilder: (context, index) {
        final result = _searchResults!.products[index];
        return _buildResultCard(result);
      },
    );
  }

  Widget _buildServiceResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults!.services.length,
      itemBuilder: (context, index) {
        final result = _searchResults!.services[index];
        return _buildResultCard(result);
      },
    );
  }

  Widget _buildVendorResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults!.vendors.length,
      itemBuilder: (context, index) {
        final result = _searchResults!.vendors[index];
        return _buildVendorCard(result);
      },
    );
  }

  Widget _buildResultCard(SearchResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: MarketplaceTheme.gray200,
            image: result.imageUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(result.imageUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: result.imageUrl.isEmpty
              ? Icon(
                  result.type == SearchResultType.product 
                      ? Icons.inventory_2 
                      : Icons.design_services,
                  color: MarketplaceTheme.gray500,
                )
              : null,
        ),
        title: Text(
          result.title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              result.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: MarketplaceTheme.gray600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (result.rating > 0) ...[
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.orange, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${result.rating.toStringAsFixed(1)} (${result.reviewCount})',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: MarketplaceTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    result.category,
                    style: TextStyle(
                      color: MarketplaceTheme.primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: result.price > 0
            ? Text(
                '₳${result.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: MarketplaceTheme.primaryGreen,
                ),
              )
            : null,
        onTap: () => _openResultDetail(result),
      ),
    );
  }

  Widget _buildVendorCard(SearchResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: MarketplaceTheme.primaryBlue.withOpacity(0.1),
          ),
          child: const Icon(
            Icons.store,
            color: MarketplaceTheme.primaryBlue,
            size: 30,
          ),
        ),
        title: Text(
          result.title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              result.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: MarketplaceTheme.gray600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.star, color: Colors.orange, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${result.rating.toStringAsFixed(1)} (${result.reviewCount} reviews)',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _openVendorProfile(result),
      ),
    );
  }

  Future<void> _performSearch() async {
    if (_searchController.text.trim().isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _showSuggestions = false;
    });

    try {
      final query = SearchQuery(
        query: _searchController.text.trim(),
        searchType: _selectedSearchType,
        categories: _selectedCategories,
        priceRange: _priceRange,
        minRating: _minRating,
        sortBy: _sortBy,
      );

      final results = await _searchService.search(query);
      
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search error: $e')),
      );
    }
  }

  Future<void> _getSuggestions(String query) async {
    try {
      final suggestions = await _searchService.getSuggestions(query);
      setState(() => _suggestions = suggestions);
    } catch (e) {
    }
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildFiltersSheet(),
    );
  }

  Widget _buildFiltersSheet() {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              // Categories
              const Text('Categories', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((category) {
                  final isSelected = _selectedCategories.contains(category);
                  return GestureDetector(
                    onTap: () {
                      setSheetState(() {
                        if (isSelected) {
                          _selectedCategories.remove(category);
                        } else {
                          _selectedCategories.add(category);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? MarketplaceTheme.primaryBlue : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? MarketplaceTheme.primaryBlue : MarketplaceTheme.gray300,
                        ),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 24),
              
              // Rating filter
              Text('Minimum Rating: ${_minRating.toStringAsFixed(1)}⭐'),
              Slider(
                value: _minRating,
                min: 0,
                max: 5,
                divisions: 10,
                onChanged: (value) {
                  setSheetState(() => _minRating = value);
                },
              ),
              
              const Spacer(),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setSheetState(() {
                          _selectedCategories.clear();
                          _minRating = 0.0;
                          _priceRange = null;
                        });
                      },
                      child: const Text('Clear Filters'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {}); // Update main state
                        Navigator.pop(context);
                        _performSearch();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MarketplaceTheme.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getSuggestionIcon(SuggestionType type) {
    switch (type) {
      case SuggestionType.product:
        return Icons.inventory_2;
      case SuggestionType.service:
        return Icons.design_services;
      case SuggestionType.vendor:
        return Icons.store;
      case SuggestionType.category:
        return Icons.category;
      default:
        return Icons.search;
    }
  }

  String _getSuggestionTypeText(SuggestionType type) {
    switch (type) {
      case SuggestionType.product:
        return 'Product';
      case SuggestionType.service:
        return 'Service';
      case SuggestionType.vendor:
        return 'Vendor';
      case SuggestionType.category:
        return 'Category';
      case SuggestionType.popular:
        return 'Popular search';
      case SuggestionType.recent:
        return 'Recent search';
    }
  }

  void _openResultDetail(SearchResult result) {
    if (result.type == SearchResultType.product) {
      // Load full product and navigate
      FirebaseFirestore.instance
          .collection('products')
          .doc(result.id)
          .get()
          .then((doc) {
        if (doc.exists) {
          final product = Product.fromJson(doc.data()!, doc.id);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product),
            ),
          );
        }
      });
    } else if (result.type == SearchResultType.service) {
      // TODO: Navigate to service detail screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service details coming soon!')),
      );
    }
  }

  void _openVendorProfile(SearchResult result) {
    // TODO: Navigate to vendor profile screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vendor profiles coming soon!')),
    );
  }
}
