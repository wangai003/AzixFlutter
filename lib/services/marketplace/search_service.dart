import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

/// Advanced search service with ML-powered recommendations
class AdvancedSearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Perform intelligent search with ranking algorithm
  Future<SearchResults> search(SearchQuery query) async {
    final results = SearchResults();
    
    // Multi-collection search
    if (query.searchType == SearchType.all || query.searchType == SearchType.products) {
      final productResults = await _searchProducts(query);
      results.products.addAll(productResults);
    }
    
    if (query.searchType == SearchType.all || query.searchType == SearchType.services) {
      final serviceResults = await _searchServices(query);
      results.services.addAll(serviceResults);
    }
    
    if (query.searchType == SearchType.all || query.searchType == SearchType.vendors) {
      final vendorResults = await _searchVendors(query);
      results.vendors.addAll(vendorResults);
    }
    
    // Apply relevance scoring and ranking
    _applyRelevanceScoring(results, query);
    
    // Apply filters
    _applyFilters(results, query);
    
    // Sort results
    _sortResults(results, query.sortBy);
    
    // Apply pagination
    _applyPagination(results, query.page, query.pageSize);
    
    // Record search analytics
    await _recordSearch(query, results);
    
    return results;
  }
  
  /// Search products with advanced text matching
  Future<List<SearchResult>> _searchProducts(SearchQuery query) async {
    final collection = _firestore.collection('marketplace_products');
    Query firebaseQuery = collection;
    
    // Apply status filter
    firebaseQuery = firebaseQuery.where('status', isEqualTo: 'active');
    
    // Apply location filter if specified
    if (query.location != null) {
      firebaseQuery = firebaseQuery.where('serviceAreas', arrayContains: query.location);
    }
    
    // Apply category filter
    if (query.categories.isNotEmpty) {
      firebaseQuery = firebaseQuery.where('category', whereIn: query.categories);
    }
    
    // Apply price range filter
    if (query.priceRange != null) {
      if (query.priceRange!.min > 0) {
        firebaseQuery = firebaseQuery.where('price', isGreaterThanOrEqualTo: query.priceRange!.min);
      }
      if (query.priceRange!.max < double.infinity) {
        firebaseQuery = firebaseQuery.where('price', isLessThanOrEqualTo: query.priceRange!.max);
      }
    }
    
    // Apply rating filter
    if (query.minRating > 0) {
      firebaseQuery = firebaseQuery.where('rating', isGreaterThanOrEqualTo: query.minRating);
    }
    
    // Execute query
    final snapshot = await firebaseQuery.get();
    final results = <SearchResult>[];
    
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final searchResult = SearchResult(
        id: doc.id,
        type: SearchResultType.product,
        title: data['title'] ?? '',
        description: data['description'] ?? '',
        imageUrl: (data['images'] as List?)?.first ?? '',
        price: (data['price'] ?? 0.0).toDouble(),
        rating: (data['rating'] ?? 0.0).toDouble(),
        reviewCount: data['reviewCount'] ?? 0,
        vendorId: data['vendorId'] ?? '',
        category: data['category'] ?? '',
        data: data,
        relevanceScore: 0.0, // Will be calculated later
      );
      
      // Calculate text relevance if query text is provided
      if (query.query.isNotEmpty) {
        searchResult.relevanceScore = _calculateTextRelevance(query.query, searchResult);
      } else {
        searchResult.relevanceScore = 1.0; // Default score for filter-only searches
      }
      
      results.add(searchResult);
    }
    
    return results;
  }
  
  /// Search services with advanced matching
  Future<List<SearchResult>> _searchServices(SearchQuery query) async {
    final collection = _firestore.collection('marketplace_services');
    Query firebaseQuery = collection;
    
    // Apply similar filters as products
    firebaseQuery = firebaseQuery.where('status', isEqualTo: 'active');
    
    if (query.location != null) {
      firebaseQuery = firebaseQuery.where('serviceAreas', arrayContains: query.location);
    }
    
    if (query.categories.isNotEmpty) {
      firebaseQuery = firebaseQuery.where('category', whereIn: query.categories);
    }
    
    if (query.priceRange != null) {
      // For services, check package prices
      if (query.priceRange!.min > 0) {
        firebaseQuery = firebaseQuery.where('minPrice', isGreaterThanOrEqualTo: query.priceRange!.min);
      }
      if (query.priceRange!.max < double.infinity) {
        firebaseQuery = firebaseQuery.where('maxPrice', isLessThanOrEqualTo: query.priceRange!.max);
      }
    }
    
    if (query.minRating > 0) {
      firebaseQuery = firebaseQuery.where('rating', isGreaterThanOrEqualTo: query.minRating);
    }
    
    final snapshot = await firebaseQuery.get();
    final results = <SearchResult>[];
    
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final packages = data['packages'] as List? ?? [];
      final minPrice = packages.isNotEmpty 
          ? packages.map((p) => (p['price'] ?? 0.0) as double).reduce((a, b) => a < b ? a : b)
          : 0.0;
      
      final searchResult = SearchResult(
        id: doc.id,
        type: SearchResultType.service,
        title: data['title'] ?? '',
        description: data['description'] ?? '',
        imageUrl: (data['images'] as List?)?.first ?? '',
        price: minPrice,
        rating: (data['rating'] ?? 0.0).toDouble(),
        reviewCount: data['reviewCount'] ?? 0,
        vendorId: data['vendorId'] ?? '',
        category: data['category'] ?? '',
        data: data,
        relevanceScore: 0.0,
      );
      
      if (query.query.isNotEmpty) {
        searchResult.relevanceScore = _calculateTextRelevance(query.query, searchResult);
      } else {
        searchResult.relevanceScore = 1.0;
      }
      
      results.add(searchResult);
    }
    
    return results;
  }
  
  /// Search vendors with profile matching
  Future<List<SearchResult>> _searchVendors(SearchQuery query) async {
    final collection = _firestore.collection('vendor_profiles');
    Query firebaseQuery = collection;
    
    firebaseQuery = firebaseQuery.where('status', isEqualTo: 'active');
    
    if (query.categories.isNotEmpty) {
      firebaseQuery = firebaseQuery.where('categories', arrayContainsAny: query.categories);
    }
    
    if (query.location != null) {
      firebaseQuery = firebaseQuery.where('serviceAreas', arrayContains: query.location);
    }
    
    if (query.minRating > 0) {
      firebaseQuery = firebaseQuery.where('analytics.rating', isGreaterThanOrEqualTo: query.minRating);
    }
    
    final snapshot = await firebaseQuery.get();
    final results = <SearchResult>[];
    
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final analytics = data['analytics'] as Map<String, dynamic>? ?? {};
      
      final searchResult = SearchResult(
        id: doc.id,
        type: SearchResultType.vendor,
        title: data['businessInfo']?['businessName'] ?? data['contactInfo']?['fullName'] ?? '',
        description: data['description'] ?? '',
        imageUrl: data['logoUrl'] ?? (data['images'] as List?)?.first ?? '',
        price: 0.0, // Vendors don't have a single price
        rating: (analytics['rating'] ?? 0.0).toDouble(),
        reviewCount: analytics['reviewCount'] ?? 0,
        vendorId: doc.id,
        category: (data['categories'] as List?)?.first?['name'] ?? '',
        data: data,
        relevanceScore: 0.0,
      );
      
      if (query.query.isNotEmpty) {
        searchResult.relevanceScore = _calculateVendorRelevance(query.query, searchResult);
      } else {
        searchResult.relevanceScore = 1.0;
      }
      
      results.add(searchResult);
    }
    
    return results;
  }
  
  /// Calculate text relevance score using TF-IDF-like algorithm
  double _calculateTextRelevance(String queryText, SearchResult result) {
    final query = queryText.toLowerCase();
    final title = result.title.toLowerCase();
    final description = result.description.toLowerCase();
    final category = result.category.toLowerCase();
    
    double score = 0.0;
    
    // Exact title match gets highest score
    if (title.contains(query)) {
      score += 1.0;
    }
    
    // Partial title matches
    final queryWords = query.split(' ');
    for (final word in queryWords) {
      if (word.length > 2) { // Ignore short words
        if (title.contains(word)) score += 0.8;
        if (description.contains(word)) score += 0.4;
        if (category.contains(word)) score += 0.6;
      }
    }
    
    // Boost for exact word matches
    for (final word in queryWords) {
      if (word.length > 2) {
        final titleWords = title.split(' ');
        final descWords = description.split(' ');
        
        if (titleWords.any((w) => w == word)) score += 0.5;
        if (descWords.any((w) => w == word)) score += 0.2;
      }
    }
    
    return math.min(score, 5.0); // Cap the score
  }
  
  /// Calculate vendor-specific relevance
  double _calculateVendorRelevance(String queryText, SearchResult result) {
    final baseScore = _calculateTextRelevance(queryText, result);
    
    // Boost for vendor-specific factors
    double vendorBoost = 0.0;
    
    // Rating boost
    vendorBoost += result.rating * 0.2;
    
    // Review count boost (logarithmic)
    if (result.reviewCount > 0) {
      vendorBoost += math.log(result.reviewCount) * 0.1;
    }
    
    // Verification boost
    final data = result.data;
    final verifications = data['verifications'] as List? ?? [];
    vendorBoost += verifications.length * 0.1;
    
    // Trust score boost
    final trustScore = data['trustScore'];
    if (trustScore != null && trustScore['score'] != null) {
      vendorBoost += (trustScore['score'] as double) * 0.01;
    }
    
    return baseScore + vendorBoost;
  }
  
  /// Apply ML-powered relevance scoring
  void _applyRelevanceScoring(SearchResults results, SearchQuery query) {
    // Combine user behavior, popularity, and recency
    final allResults = <SearchResult>[];
    allResults.addAll(results.products);
    allResults.addAll(results.services);
    allResults.addAll(results.vendors);
    
    for (final result in allResults) {
      // Apply popularity boost
      double popularityBoost = 0.0;
      if (result.type == SearchResultType.product || result.type == SearchResultType.service) {
        popularityBoost = _calculatePopularityScore(result);
      }
      
      // Apply recency boost
      double recencyBoost = _calculateRecencyScore(result);
      
      // Apply personalization boost (if user data available)
      double personalizationBoost = 0.0;
      if (query.userId != null) {
        personalizationBoost = _calculatePersonalizationScore(result, query.userId!);
      }
      
      // Combine all scores
      result.relevanceScore = result.relevanceScore + 
                             popularityBoost + 
                             recencyBoost + 
                             personalizationBoost;
    }
  }
  
  /// Calculate popularity score based on engagement metrics
  double _calculatePopularityScore(SearchResult result) {
    final data = result.data;
    double score = 0.0;
    
    // Views boost
    final views = data['viewCount'] ?? 0;
    score += math.log(views + 1) * 0.05;
    
    // Favorites boost
    final favorites = data['favoriteCount'] ?? 0;
    score += math.log(favorites + 1) * 0.1;
    
    // Recent orders boost
    final recentOrders = data['recentOrderCount'] ?? 0;
    score += math.log(recentOrders + 1) * 0.15;
    
    // Rating boost
    score += result.rating * 0.1;
    
    return math.min(score, 1.0);
  }
  
  /// Calculate recency score
  double _calculateRecencyScore(SearchResult result) {
    final data = result.data;
    final createdAt = data['createdAt'] as Timestamp?;
    final updatedAt = data['updatedAt'] as Timestamp?;
    
    if (createdAt == null) return 0.0;
    
    final now = DateTime.now();
    final itemDate = updatedAt?.toDate() ?? createdAt.toDate();
    final daysSince = now.difference(itemDate).inDays;
    
    // Newer items get higher scores, exponential decay
    if (daysSince <= 7) return 0.5;
    if (daysSince <= 30) return 0.3;
    if (daysSince <= 90) return 0.1;
    return 0.0;
  }
  
  /// Calculate personalization score based on user behavior
  double _calculatePersonalizationScore(SearchResult result, String userId) {
    // This would typically involve user behavior analysis
    // For now, return a basic score based on category preferences
    
    // TODO: Implement user behavior tracking and ML recommendations
    return 0.0;
  }
  
  /// Apply advanced filters
  void _applyFilters(SearchResults results, SearchQuery query) {
    // Filter products
    results.products.retainWhere((product) => _passesFilters(product, query));
    
    // Filter services
    results.services.retainWhere((service) => _passesFilters(service, query));
    
    // Filter vendors
    results.vendors.retainWhere((vendor) => _passesVendorFilters(vendor, query));
  }
  
  /// Check if a result passes all filters
  bool _passesFilters(SearchResult result, SearchQuery query) {
    // Availability filter
    if (query.availableOnly) {
      final availability = result.data['availability'] as Map<String, dynamic>?;
      if (availability?['inStock'] == false) return false;
    }
    
    // Shipping filter
    if (query.shippingOptions.isNotEmpty) {
      final shipping = result.data['shippingOptions'] as List?;
      if (shipping == null || !query.shippingOptions.any(shipping.contains)) {
        return false;
      }
    }
    
    // Vendor verification filter
    if (query.verifiedVendorsOnly) {
      // Would need to join with vendor data
      // For now, assume verification is in the data
      final isVerified = result.data['vendorVerified'] ?? false;
      if (!isVerified) return false;
    }
    
    // Custom attributes filter
    for (final attr in query.customAttributes.entries) {
      final value = result.data[attr.key];
      if (value != attr.value) return false;
    }
    
    return true;
  }
  
  /// Check if a vendor passes filters
  bool _passesVendorFilters(SearchResult vendor, SearchQuery query) {
    final data = vendor.data;
    
    // Business type filter
    if (query.businessTypes.isNotEmpty) {
      final businessType = data['businessInfo']?['type'] ?? '';
      if (!query.businessTypes.contains(businessType)) return false;
    }
    
    // Experience filter
    if (query.minExperienceYears > 0) {
      final categories = data['categories'] as List? ?? [];
      final maxExperience = categories.isNotEmpty 
          ? categories.map((c) => (c['experienceYears'] ?? 0) as int).reduce(math.max)
          : 0;
      if (maxExperience < query.minExperienceYears) return false;
    }
    
    return true;
  }
  
  /// Sort results by specified criteria
  void _sortResults(SearchResults results, SortBy sortBy) {
    switch (sortBy) {
      case SortBy.relevance:
        _sortByRelevance(results);
        break;
      case SortBy.priceAsc:
        _sortByPrice(results, ascending: true);
        break;
      case SortBy.priceDesc:
        _sortByPrice(results, ascending: false);
        break;
      case SortBy.rating:
        _sortByRating(results);
        break;
      case SortBy.newest:
        _sortByDate(results, newest: true);
        break;
      case SortBy.oldest:
        _sortByDate(results, newest: false);
        break;
      case SortBy.popular:
        _sortByPopularity(results);
        break;
      case SortBy.distance:
        _sortByDistance(results);
        break;
    }
  }
  
  void _sortByRelevance(SearchResults results) {
    results.products.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    results.services.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    results.vendors.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
  }
  
  void _sortByPrice(SearchResults results, {required bool ascending}) {
    final multiplier = ascending ? 1 : -1;
    results.products.sort((a, b) => (a.price.compareTo(b.price)) * multiplier);
    results.services.sort((a, b) => (a.price.compareTo(b.price)) * multiplier);
  }
  
  void _sortByRating(SearchResults results) {
    results.products.sort((a, b) => b.rating.compareTo(a.rating));
    results.services.sort((a, b) => b.rating.compareTo(a.rating));
    results.vendors.sort((a, b) => b.rating.compareTo(a.rating));
  }
  
  void _sortByDate(SearchResults results, {required bool newest}) {
    final multiplier = newest ? -1 : 1;
    
    results.products.sort((a, b) {
      final aDate = a.data['createdAt'] as Timestamp?;
      final bDate = b.data['createdAt'] as Timestamp?;
      if (aDate == null || bDate == null) return 0;
      return aDate.compareTo(bDate) * multiplier;
    });
    
    results.services.sort((a, b) {
      final aDate = a.data['createdAt'] as Timestamp?;
      final bDate = b.data['createdAt'] as Timestamp?;
      if (aDate == null || bDate == null) return 0;
      return aDate.compareTo(bDate) * multiplier;
    });
    
    results.vendors.sort((a, b) {
      final aDate = a.data['createdAt'] as Timestamp?;
      final bDate = b.data['createdAt'] as Timestamp?;
      if (aDate == null || bDate == null) return 0;
      return aDate.compareTo(bDate) * multiplier;
    });
  }
  
  void _sortByPopularity(SearchResults results) {
    results.products.sort((a, b) {
      final aViews = a.data['viewCount'] ?? 0;
      final bViews = b.data['viewCount'] ?? 0;
      return bViews.compareTo(aViews);
    });
    
    results.services.sort((a, b) {
      final aViews = a.data['viewCount'] ?? 0;
      final bViews = b.data['viewCount'] ?? 0;
      return bViews.compareTo(aViews);
    });
    
    results.vendors.sort((a, b) {
      final aFollowers = a.data['analytics']?['followers'] ?? 0;
      final bFollowers = b.data['analytics']?['followers'] ?? 0;
      return bFollowers.compareTo(aFollowers);
    });
  }
  
  void _sortByDistance(SearchResults results) {
    // TODO: Implement distance sorting based on user location
    // This would require geolocation data
  }
  
  /// Apply pagination
  void _applyPagination(SearchResults results, int page, int pageSize) {
    final start = page * pageSize;
    
    results.products = results.products.skip(start).take(pageSize).toList();
    results.services = results.services.skip(start).take(pageSize).toList();
    results.vendors = results.vendors.skip(start).take(pageSize).toList();
  }
  
  /// Record search analytics
  Future<void> _recordSearch(SearchQuery query, SearchResults results) async {
    try {
      await _firestore.collection('search_analytics').add({
        'query': query.toJson(),
        'resultCounts': {
          'products': results.products.length,
          'services': results.services.length,
          'vendors': results.vendors.length,
          'total': results.totalCount,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'userId': query.userId,
      });
    } catch (e) {
      // Don't let analytics failure affect search results
    }
  }
  
  /// Get search suggestions
  Future<List<SearchSuggestion>> getSuggestions(String query) async {
    final suggestions = <SearchSuggestion>[];
    
    if (query.length < 2) return suggestions;
    
    // Get recent searches
    final recentSearches = await _getRecentSearches(query);
    suggestions.addAll(recentSearches);
    
    // Get popular searches
    final popularSearches = await _getPopularSearches(query);
    suggestions.addAll(popularSearches);
    
    // Get category suggestions
    final categorySuggestions = await _getCategorySuggestions(query);
    suggestions.addAll(categorySuggestions);
    
    // Get product/service title suggestions
    final titleSuggestions = await _getTitleSuggestions(query);
    suggestions.addAll(titleSuggestions);
    
    // Remove duplicates and limit results
    final uniqueSuggestions = suggestions.toSet().toList();
    uniqueSuggestions.sort((a, b) => b.popularity.compareTo(a.popularity));
    
    return uniqueSuggestions.take(10).toList();
  }
  
  Future<List<SearchSuggestion>> _getRecentSearches(String query) async {
    // TODO: Implement recent searches from user history
    return [];
  }
  
  Future<List<SearchSuggestion>> _getPopularSearches(String query) async {
    try {
      final snapshot = await _firestore
          .collection('popular_searches')
          .where('query', isGreaterThanOrEqualTo: query)
          .where('query', isLessThan: query + 'z')
          .orderBy('count', descending: true)
          .limit(5)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return SearchSuggestion(
          text: data['query'] ?? '',
          type: SuggestionType.popular,
          popularity: data['count'] ?? 0,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }
  
  Future<List<SearchSuggestion>> _getCategorySuggestions(String query) async {
    try {
      final snapshot = await _firestore
          .collection('categories')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: query + 'z')
          .limit(3)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return SearchSuggestion(
          text: data['name'] ?? '',
          type: SuggestionType.category,
          popularity: data['itemCount'] ?? 0,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }
  
  Future<List<SearchSuggestion>> _getTitleSuggestions(String query) async {
    try {
      final productSnapshot = await _firestore
          .collection('marketplace_products')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThan: query + 'z')
          .where('status', isEqualTo: 'active')
          .limit(3)
          .get();
      
      final serviceSnapshot = await _firestore
          .collection('marketplace_services')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThan: query + 'z')
          .where('status', isEqualTo: 'active')
          .limit(3)
          .get();
      
      final suggestions = <SearchSuggestion>[];
      
      for (final doc in productSnapshot.docs) {
        final data = doc.data();
        suggestions.add(SearchSuggestion(
          text: data['title'] ?? '',
          type: SuggestionType.product,
          popularity: data['viewCount'] ?? 0,
        ));
      }
      
      for (final doc in serviceSnapshot.docs) {
        final data = doc.data();
        suggestions.add(SearchSuggestion(
          text: data['title'] ?? '',
          type: SuggestionType.service,
          popularity: data['viewCount'] ?? 0,
        ));
      }
      
      return suggestions;
    } catch (e) {
      return [];
    }
  }
}

/// Search query model
class SearchQuery {
  final String query;
  final SearchType searchType;
  final List<String> categories;
  final List<String> subcategories;
  final PriceRange? priceRange;
  final double minRating;
  final String? location;
  final bool availableOnly;
  final bool verifiedVendorsOnly;
  final List<String> shippingOptions;
  final List<String> businessTypes;
  final int minExperienceYears;
  final Map<String, dynamic> customAttributes;
  final SortBy sortBy;
  final int page;
  final int pageSize;
  final String? userId;
  
  SearchQuery({
    required this.query,
    this.searchType = SearchType.all,
    this.categories = const [],
    this.subcategories = const [],
    this.priceRange,
    this.minRating = 0.0,
    this.location,
    this.availableOnly = false,
    this.verifiedVendorsOnly = false,
    this.shippingOptions = const [],
    this.businessTypes = const [],
    this.minExperienceYears = 0,
    this.customAttributes = const {},
    this.sortBy = SortBy.relevance,
    this.page = 0,
    this.pageSize = 20,
    this.userId,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'searchType': searchType.toString(),
      'categories': categories,
      'subcategories': subcategories,
      'priceRange': priceRange?.toJson(),
      'minRating': minRating,
      'location': location,
      'availableOnly': availableOnly,
      'verifiedVendorsOnly': verifiedVendorsOnly,
      'shippingOptions': shippingOptions,
      'businessTypes': businessTypes,
      'minExperienceYears': minExperienceYears,
      'customAttributes': customAttributes,
      'sortBy': sortBy.toString(),
      'page': page,
      'pageSize': pageSize,
      'userId': userId,
    };
  }
}

enum SearchType { all, products, services, vendors }
enum SortBy { relevance, priceAsc, priceDesc, rating, newest, oldest, popular, distance }

class PriceRange {
  final double min;
  final double max;
  
  PriceRange({required this.min, required this.max});
  
  Map<String, dynamic> toJson() {
    return {'min': min, 'max': max};
  }
}

/// Search results model
class SearchResults {
  List<SearchResult> products = [];
  List<SearchResult> services = [];
  List<SearchResult> vendors = [];
  
  int get totalCount => products.length + services.length + vendors.length;
  
  List<SearchResult> get allResults => [...products, ...services, ...vendors];
}

/// Individual search result
class SearchResult {
  final String id;
  final SearchResultType type;
  final String title;
  final String description;
  final String imageUrl;
  final double price;
  final double rating;
  final int reviewCount;
  final String vendorId;
  final String category;
  final Map<String, dynamic> data;
  double relevanceScore;
  
  SearchResult({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.rating,
    required this.reviewCount,
    required this.vendorId,
    required this.category,
    required this.data,
    required this.relevanceScore,
  });
}

enum SearchResultType { product, service, vendor }

/// Search suggestion model
class SearchSuggestion {
  final String text;
  final SuggestionType type;
  final int popularity;
  
  SearchSuggestion({
    required this.text,
    required this.type,
    required this.popularity,
  });
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchSuggestion &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          type == other.type;
  
  @override
  int get hashCode => text.hashCode ^ type.hashCode;
}

enum SuggestionType { recent, popular, category, product, service, vendor }
