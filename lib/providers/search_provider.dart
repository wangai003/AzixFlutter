import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';


import '../models/search_filter.dart';
import '../models/product.dart';
import '../models/service.dart';

/// Advanced search provider with filtering, sorting, and history
class SearchProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Current search state
  SearchFilter _currentFilter = const SearchFilter();
  List<Product> _productResults = [];
  List<Service> _serviceResults = [];
  bool _isLoading = false;
  String? _error;
  
  // Search history and suggestions
  List<String> _searchHistory = [];
  List<String> _popularSearches = [];
  List<String> _suggestions = [];
  
  // Categories and metadata
  Map<String, List<String>> _productCategories = {};
  Map<String, List<String>> _serviceCategories = {};
  List<String> _allTags = [];
  
  // Pagination
  static const int _pageSize = 20;
  DocumentSnapshot? _lastProductDoc;
  DocumentSnapshot? _lastServiceDoc;
  bool _hasMoreProducts = true;
  bool _hasMoreServices = true;

  // Getters
  SearchFilter get currentFilter => _currentFilter;
  List<Product> get productResults => _productResults;
  List<Service> get serviceResults => _serviceResults;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<String> get searchHistory => _searchHistory;
  List<String> get popularSearches => _popularSearches;
  List<String> get suggestions => _suggestions;
  Map<String, List<String>> get productCategories => _productCategories;
  Map<String, List<String>> get serviceCategories => _serviceCategories;
  List<String> get allTags => _allTags;
  bool get hasMoreProducts => _hasMoreProducts;
  bool get hasMoreServices => _hasMoreServices;
  
  int get totalResults => _productResults.length + _serviceResults.length;
  bool get hasResults => _productResults.isNotEmpty || _serviceResults.isNotEmpty;

  /// Initialize search provider
  Future<void> initialize() async {
    await _loadSearchHistory();
    await _loadCategories();
    await _loadPopularSearches();
  }

  /// Set error state
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ==================== SEARCH METHODS ====================

  /// Perform search with current filter
  Future<void> search({SearchFilter? filter, bool reset = true}) async {
    if (filter != null) {
      _currentFilter = filter;
    }

    if (reset) {
      _productResults.clear();
      _serviceResults.clear();
      _lastProductDoc = null;
      _lastServiceDoc = null;
      _hasMoreProducts = true;
      _hasMoreServices = true;
    }

    _isLoading = true;
    _setError(null);
    notifyListeners();

    try {
      // Save search query to history
      if (_currentFilter.query.isNotEmpty) {
        await _addToSearchHistory(_currentFilter.query);
      }

      // Perform search based on type
      switch (_currentFilter.type) {
        case SearchType.products:
          await _searchProducts();
          break;
        case SearchType.services:
          await _searchServices();
          break;
        case SearchType.both:
          await Future.wait([
            _searchProducts(),
            _searchServices(),
          ]);
          break;
      }

      // Generate suggestions based on results
      _generateSuggestions();

    } catch (e) {
      _setError('Search failed: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load more results (pagination)
  Future<void> loadMore() async {
    if (_isLoading || (!_hasMoreProducts && !_hasMoreServices)) return;

    _isLoading = true;
    notifyListeners();

    try {
      switch (_currentFilter.type) {
        case SearchType.products:
          if (_hasMoreProducts) await _searchProducts(loadMore: true);
          break;
        case SearchType.services:
          if (_hasMoreServices) await _searchServices(loadMore: true);
          break;
        case SearchType.both:
          final futures = <Future>[];
          if (_hasMoreProducts) futures.add(_searchProducts(loadMore: true));
          if (_hasMoreServices) futures.add(_searchServices(loadMore: true));
          if (futures.isNotEmpty) await Future.wait(futures);
          break;
      }
    } catch (e) {
      _setError('Failed to load more results: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Quick search with just query
  Future<void> quickSearch(String query) async {
    await search(
      filter: _currentFilter.copyWith(query: query),
      reset: true,
    );
  }

  /// Update filter and re-search
  Future<void> updateFilter(SearchFilter filter) async {
    await search(filter: filter, reset: true);
  }

  /// Clear current search
  void clearSearch() {
    _currentFilter = const SearchFilter();
    _productResults.clear();
    _serviceResults.clear();
    _lastProductDoc = null;
    _lastServiceDoc = null;
    _hasMoreProducts = true;
    _hasMoreServices = true;
    _setError(null);
    notifyListeners();
  }

  // ==================== PRIVATE SEARCH METHODS ====================

  /// Search products with current filter
  Future<void> _searchProducts({bool loadMore = false}) async {
    Query<Map<String, dynamic>> query = _firestore.collection('products');

    // Apply filters
    query = _applyProductFilters(query);

    // Apply sorting
    query = _applySorting(query, isProduct: true);

    // Apply pagination
    if (loadMore && _lastProductDoc != null) {
      query = query.startAfterDocument(_lastProductDoc!);
    }

    query = query.limit(_pageSize);

    final snapshot = await query.get();
    
    if (snapshot.docs.isNotEmpty) {
      final newProducts = snapshot.docs
          .map((doc) => Product.fromJson(doc.data(), doc.id))
          .toList();

      if (loadMore) {
        _productResults.addAll(newProducts);
      } else {
        _productResults = newProducts;
      }

      _lastProductDoc = snapshot.docs.last;
      _hasMoreProducts = snapshot.docs.length == _pageSize;
    } else {
      _hasMoreProducts = false;
      if (!loadMore) {
        _productResults.clear();
      }
    }
  }

  /// Search services with current filter
  Future<void> _searchServices({bool loadMore = false}) async {
    Query<Map<String, dynamic>> query = _firestore.collection('services');

    // Apply filters
    query = _applyServiceFilters(query);

    // Apply sorting
    query = _applySorting(query, isProduct: false);

    // Apply pagination
    if (loadMore && _lastServiceDoc != null) {
      query = query.startAfterDocument(_lastServiceDoc!);
    }

    query = query.limit(_pageSize);

    final snapshot = await query.get();
    
    if (snapshot.docs.isNotEmpty) {
      final newServices = snapshot.docs
          .map((doc) => Service.fromJson(doc.data(), doc.id))
          .toList();

      if (loadMore) {
        _serviceResults.addAll(newServices);
      } else {
        _serviceResults = newServices;
      }

      _lastServiceDoc = snapshot.docs.last;
      _hasMoreServices = snapshot.docs.length == _pageSize;
    } else {
      _hasMoreServices = false;
      if (!loadMore) {
        _serviceResults.clear();
      }
    }
  }

  /// Apply product-specific filters
  Query<Map<String, dynamic>> _applyProductFilters(Query<Map<String, dynamic>> query) {
    // Category filter
    if (_currentFilter.categories.isNotEmpty) {
      query = query.where('category', whereIn: _currentFilter.categories);
    }

    // Subcategory filter
    if (_currentFilter.subcategories.isNotEmpty) {
      query = query.where('subcategory', whereIn: _currentFilter.subcategories);
    }

    // Price range filter
    if (_currentFilter.priceRange != null) {
      if (_currentFilter.priceRange!.min != null) {
        query = query.where('price', isGreaterThanOrEqualTo: _currentFilter.priceRange!.min);
      }
      if (_currentFilter.priceRange!.max != null) {
        query = query.where('price', isLessThanOrEqualTo: _currentFilter.priceRange!.max);
      }
    }

    // Vendor filter
    if (_currentFilter.vendorIds.isNotEmpty) {
      query = query.where('vendorId', whereIn: _currentFilter.vendorIds);
    }

    // Availability filter
    switch (_currentFilter.availability) {
      case AvailabilityFilter.inStock:
        query = query.where('inventory', isGreaterThan: 0);
        break;
      case AvailabilityFilter.outOfStock:
        query = query.where('inventory', isLessThanOrEqualTo: 0);
        break;
      default:
        break;
    }

    // Text search (simplified - in production, use full-text search)
    if (_currentFilter.query.isNotEmpty) {
      // Note: Firestore doesn't support full-text search natively
      // This is a simplified approach - consider using Algolia or similar for production
      final queryLower = _currentFilter.query.toLowerCase();
      query = query.where('searchTokens', arrayContains: queryLower);
    }

    return query;
  }

  /// Apply service-specific filters
  Query<Map<String, dynamic>> _applyServiceFilters(Query<Map<String, dynamic>> query) {
    // Category filter
    if (_currentFilter.categories.isNotEmpty) {
      query = query.where('category', whereIn: _currentFilter.categories);
    }

    // Subcategory filter
    if (_currentFilter.subcategories.isNotEmpty) {
      query = query.where('subcategory', whereIn: _currentFilter.subcategories);
    }

    // Price range filter (based on minimum package price)
    if (_currentFilter.priceRange != null) {
      if (_currentFilter.priceRange!.min != null) {
        query = query.where('minPrice', isGreaterThanOrEqualTo: _currentFilter.priceRange!.min);
      }
      if (_currentFilter.priceRange!.max != null) {
        query = query.where('maxPrice', isLessThanOrEqualTo: _currentFilter.priceRange!.max);
      }
    }

    // Vendor filter
    if (_currentFilter.vendorIds.isNotEmpty) {
      query = query.where('vendorId', whereIn: _currentFilter.vendorIds);
    }

    // Text search
    if (_currentFilter.query.isNotEmpty) {
      final queryLower = _currentFilter.query.toLowerCase();
      query = query.where('searchTokens', arrayContains: queryLower);
    }

    return query;
  }

  /// Apply sorting to query
  Query<Map<String, dynamic>> _applySorting(Query<Map<String, dynamic>> query, {required bool isProduct}) {
    switch (_currentFilter.sortBy) {
      case SortOption.priceAsc:
        query = query.orderBy(isProduct ? 'price' : 'minPrice', descending: false);
        break;
      case SortOption.priceDesc:
        query = query.orderBy(isProduct ? 'price' : 'minPrice', descending: true);
        break;
      case SortOption.nameAsc:
        query = query.orderBy(isProduct ? 'name' : 'title', descending: false);
        break;
      case SortOption.nameDesc:
        query = query.orderBy(isProduct ? 'name' : 'title', descending: true);
        break;
      case SortOption.newest:
        query = query.orderBy('createdAt', descending: true);
        break;
      case SortOption.oldest:
        query = query.orderBy('createdAt', descending: false);
        break;
      case SortOption.rating:
        query = query.orderBy('averageRating', descending: true);
        break;
      case SortOption.popularity:
        query = query.orderBy('viewCount', descending: true);
        break;
      case SortOption.relevance:
        // For relevance, use a combination of factors or default ordering
        query = query.orderBy('createdAt', descending: true);
        break;
    }

    return query;
  }

  // ==================== SUGGESTIONS & HISTORY ====================

  /// Generate search suggestions based on current results
  void _generateSuggestions() {
    final suggestions = <String>{};

    // Add category names from results
    for (final product in _productResults) {
      suggestions.add(product.category);
      suggestions.add(product.subcategory);
    }

    for (final service in _serviceResults) {
      suggestions.add(service.category);
      suggestions.add(service.subcategory);
    }

    // Add popular searches
    suggestions.addAll(_popularSearches);

    _suggestions = suggestions.where((s) => s.isNotEmpty).take(10).toList();
  }

  /// Add search query to history
  Future<void> _addToSearchHistory(String query) async {
    if (query.isEmpty || _searchHistory.contains(query)) return;

    _searchHistory.insert(0, query);
    if (_searchHistory.length > 50) {
      _searchHistory = _searchHistory.take(50).toList();
    }

    await _saveSearchHistory();
    notifyListeners();
  }

  /// Clear search history
  Future<void> clearSearchHistory() async {
    _searchHistory.clear();
    await _saveSearchHistory();
    notifyListeners();
  }

  /// Save search history to local storage
  Future<void> _saveSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('search_history', _searchHistory);
    } catch (e) {
      print('Error saving search history: $e');
    }
  }

  /// Load search history from local storage
  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _searchHistory = prefs.getStringList('search_history') ?? [];
    } catch (e) {
      print('Error loading search history: $e');
    }
  }

  /// Load categories from Firestore
  Future<void> _loadCategories() async {
    try {
      // Load product categories
      final productSnapshot = await _firestore
          .collection('products')
          .get();

      final productCats = <String, Set<String>>{};
      for (final doc in productSnapshot.docs) {
        final data = doc.data();
        final category = data['category'] as String?;
        final subcategory = data['subcategory'] as String?;
        
        if (category != null) {
          productCats[category] ??= <String>{};
          if (subcategory != null) {
            productCats[category]!.add(subcategory);
          }
        }
      }

      _productCategories = productCats.map((key, value) => MapEntry(key, value.toList()));

      // Load service categories
      final serviceSnapshot = await _firestore
          .collection('services')
          .get();

      final serviceCats = <String, Set<String>>{};
      for (final doc in serviceSnapshot.docs) {
        final data = doc.data();
        final category = data['category'] as String?;
        final subcategory = data['subcategory'] as String?;
        
        if (category != null) {
          serviceCats[category] ??= <String>{};
          if (subcategory != null) {
            serviceCats[category]!.add(subcategory);
          }
        }
      }

      _serviceCategories = serviceCats.map((key, value) => MapEntry(key, value.toList()));

    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  /// Load popular searches (could be from analytics or predefined)
  Future<void> _loadPopularSearches() async {
    // For now, use predefined popular searches
    // In production, this could come from analytics
    _popularSearches = [
      'electronics',
      'clothing',
      'home decor',
      'web design',
      'consulting',
      'photography',
      'food',
      'handmade',
      'education',
      'health',
    ];
  }

  @override
  void dispose() {
    super.dispose();
  }
}
