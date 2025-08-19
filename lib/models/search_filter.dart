import 'package:flutter/material.dart';

/// Advanced search and filtering model for marketplace
class SearchFilter {
  final String query;
  final List<String> categories;
  final List<String> subcategories;
  final SearchType type; // products, services, or both
  final PriceRange? priceRange;
  final SortOption sortBy;
  final bool ascending;
  final List<String> vendorIds;
  final LocationFilter? location;
  final AvailabilityFilter availability;
  final RatingFilter? rating;
  final List<String> tags;

  const SearchFilter({
    this.query = '',
    this.categories = const [],
    this.subcategories = const [],
    this.type = SearchType.both,
    this.priceRange,
    this.sortBy = SortOption.relevance,
    this.ascending = false,
    this.vendorIds = const [],
    this.location,
    this.availability = AvailabilityFilter.all,
    this.rating,
    this.tags = const [],
  });

  /// Create a copy with updated values
  SearchFilter copyWith({
    String? query,
    List<String>? categories,
    List<String>? subcategories,
    SearchType? type,
    PriceRange? priceRange,
    SortOption? sortBy,
    bool? ascending,
    List<String>? vendorIds,
    LocationFilter? location,
    AvailabilityFilter? availability,
    RatingFilter? rating,
    List<String>? tags,
  }) {
    return SearchFilter(
      query: query ?? this.query,
      categories: categories ?? this.categories,
      subcategories: subcategories ?? this.subcategories,
      type: type ?? this.type,
      priceRange: priceRange ?? this.priceRange,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
      vendorIds: vendorIds ?? this.vendorIds,
      location: location ?? this.location,
      availability: availability ?? this.availability,
      rating: rating ?? this.rating,
      tags: tags ?? this.tags,
    );
  }

  /// Check if filter is empty (no criteria applied)
  bool get isEmpty {
    return query.isEmpty &&
           categories.isEmpty &&
           subcategories.isEmpty &&
           type == SearchType.both &&
           priceRange == null &&
           sortBy == SortOption.relevance &&
           vendorIds.isEmpty &&
           location == null &&
           availability == AvailabilityFilter.all &&
           rating == null &&
           tags.isEmpty;
  }

  /// Get number of active filters
  int get activeFilterCount {
    int count = 0;
    if (query.isNotEmpty) count++;
    if (categories.isNotEmpty) count++;
    if (subcategories.isNotEmpty) count++;
    if (type != SearchType.both) count++;
    if (priceRange != null) count++;
    if (sortBy != SortOption.relevance) count++;
    if (vendorIds.isNotEmpty) count++;
    if (location != null) count++;
    if (availability != AvailabilityFilter.all) count++;
    if (rating != null) count++;
    if (tags.isNotEmpty) count++;
    return count;
  }

  /// Convert to map for persistence or API calls
  Map<String, dynamic> toMap() {
    return {
      'query': query,
      'categories': categories,
      'subcategories': subcategories,
      'type': type.toString(),
      'priceRange': priceRange?.toMap(),
      'sortBy': sortBy.toString(),
      'ascending': ascending,
      'vendorIds': vendorIds,
      'location': location?.toMap(),
      'availability': availability.toString(),
      'rating': rating?.toMap(),
      'tags': tags,
    };
  }

  /// Create from map
  factory SearchFilter.fromMap(Map<String, dynamic> map) {
    return SearchFilter(
      query: map['query'] ?? '',
      categories: List<String>.from(map['categories'] ?? []),
      subcategories: List<String>.from(map['subcategories'] ?? []),
      type: SearchTypeExtension.fromString(map['type']),
      priceRange: map['priceRange'] != null 
          ? PriceRange.fromMap(map['priceRange'])
          : null,
      sortBy: SortOptionExtension.fromString(map['sortBy']),
      ascending: map['ascending'] ?? false,
      vendorIds: List<String>.from(map['vendorIds'] ?? []),
      location: map['location'] != null 
          ? LocationFilter.fromMap(map['location'])
          : null,
      availability: AvailabilityFilterExtension.fromString(map['availability']),
      rating: map['rating'] != null 
          ? RatingFilter.fromMap(map['rating'])
          : null,
      tags: List<String>.from(map['tags'] ?? []),
    );
  }
}

/// Search type enumeration
enum SearchType {
  products,
  services,
  both,
}

extension SearchTypeExtension on SearchType {
  static SearchType fromString(String? value) {
    switch (value) {
      case 'SearchType.products':
        return SearchType.products;
      case 'SearchType.services':
        return SearchType.services;
      case 'SearchType.both':
      default:
        return SearchType.both;
    }
  }

  String get displayName {
    switch (this) {
      case SearchType.products:
        return 'Products';
      case SearchType.services:
        return 'Services';
      case SearchType.both:
        return 'All';
    }
  }

  String get icon {
    switch (this) {
      case SearchType.products:
        return '📦';
      case SearchType.services:
        return '🛠️';
      case SearchType.both:
        return '🔍';
    }
  }
}

/// Price range filter
class PriceRange {
  final double? min;
  final double? max;

  const PriceRange({this.min, this.max});

  bool contains(double price) {
    if (min != null && price < min!) return false;
    if (max != null && price > max!) return false;
    return true;
  }

  Map<String, dynamic> toMap() {
    return {
      'min': min,
      'max': max,
    };
  }

  factory PriceRange.fromMap(Map<String, dynamic> map) {
    return PriceRange(
      min: map['min']?.toDouble(),
      max: map['max']?.toDouble(),
    );
  }

  @override
  String toString() {
    if (min != null && max != null) {
      return '₳${min!.toStringAsFixed(0)} - ₳${max!.toStringAsFixed(0)}';
    } else if (min != null) {
      return 'Above ₳${min!.toStringAsFixed(0)}';
    } else if (max != null) {
      return 'Below ₳${max!.toStringAsFixed(0)}';
    }
    return 'Any Price';
  }
}

/// Sort options
enum SortOption {
  relevance,
  priceAsc,
  priceDesc,
  nameAsc,
  nameDesc,
  newest,
  oldest,
  rating,
  popularity,
}

extension SortOptionExtension on SortOption {
  static SortOption fromString(String? value) {
    switch (value) {
      case 'SortOption.priceAsc':
        return SortOption.priceAsc;
      case 'SortOption.priceDesc':
        return SortOption.priceDesc;
      case 'SortOption.nameAsc':
        return SortOption.nameAsc;
      case 'SortOption.nameDesc':
        return SortOption.nameDesc;
      case 'SortOption.newest':
        return SortOption.newest;
      case 'SortOption.oldest':
        return SortOption.oldest;
      case 'SortOption.rating':
        return SortOption.rating;
      case 'SortOption.popularity':
        return SortOption.popularity;
      case 'SortOption.relevance':
      default:
        return SortOption.relevance;
    }
  }

  String get displayName {
    switch (this) {
      case SortOption.relevance:
        return 'Most Relevant';
      case SortOption.priceAsc:
        return 'Price: Low to High';
      case SortOption.priceDesc:
        return 'Price: High to Low';
      case SortOption.nameAsc:
        return 'Name: A to Z';
      case SortOption.nameDesc:
        return 'Name: Z to A';
      case SortOption.newest:
        return 'Newest First';
      case SortOption.oldest:
        return 'Oldest First';
      case SortOption.rating:
        return 'Highest Rated';
      case SortOption.popularity:
        return 'Most Popular';
    }
  }

  IconData get icon {
    switch (this) {
      case SortOption.relevance:
        return Icons.star;
      case SortOption.priceAsc:
        return Icons.arrow_upward;
      case SortOption.priceDesc:
        return Icons.arrow_downward;
      case SortOption.nameAsc:
        return Icons.sort_by_alpha;
      case SortOption.nameDesc:
        return Icons.sort_by_alpha;
      case SortOption.newest:
        return Icons.new_releases;
      case SortOption.oldest:
        return Icons.access_time;
      case SortOption.rating:
        return Icons.star_rate;
      case SortOption.popularity:
        return Icons.trending_up;
    }
  }
}

/// Location filter
class LocationFilter {
  final String? country;
  final String? state;
  final String? city;
  final double? radiusKm;

  const LocationFilter({
    this.country,
    this.state,
    this.city,
    this.radiusKm,
  });

  Map<String, dynamic> toMap() {
    return {
      'country': country,
      'state': state,
      'city': city,
      'radiusKm': radiusKm,
    };
  }

  factory LocationFilter.fromMap(Map<String, dynamic> map) {
    return LocationFilter(
      country: map['country'],
      state: map['state'],
      city: map['city'],
      radiusKm: map['radiusKm']?.toDouble(),
    );
  }
}

/// Availability filter
enum AvailabilityFilter {
  all,
  inStock,
  outOfStock,
  available,
  unavailable,
}

extension AvailabilityFilterExtension on AvailabilityFilter {
  static AvailabilityFilter fromString(String? value) {
    switch (value) {
      case 'AvailabilityFilter.inStock':
        return AvailabilityFilter.inStock;
      case 'AvailabilityFilter.outOfStock':
        return AvailabilityFilter.outOfStock;
      case 'AvailabilityFilter.available':
        return AvailabilityFilter.available;
      case 'AvailabilityFilter.unavailable':
        return AvailabilityFilter.unavailable;
      case 'AvailabilityFilter.all':
      default:
        return AvailabilityFilter.all;
    }
  }

  String get displayName {
    switch (this) {
      case AvailabilityFilter.all:
        return 'All Items';
      case AvailabilityFilter.inStock:
        return 'In Stock';
      case AvailabilityFilter.outOfStock:
        return 'Out of Stock';
      case AvailabilityFilter.available:
        return 'Available';
      case AvailabilityFilter.unavailable:
        return 'Unavailable';
    }
  }
}

/// Rating filter
class RatingFilter {
  final double minRating;
  final int? minReviews;

  const RatingFilter({
    required this.minRating,
    this.minReviews,
  });

  Map<String, dynamic> toMap() {
    return {
      'minRating': minRating,
      'minReviews': minReviews,
    };
  }

  factory RatingFilter.fromMap(Map<String, dynamic> map) {
    return RatingFilter(
      minRating: map['minRating']?.toDouble() ?? 0.0,
      minReviews: map['minReviews'],
    );
  }

  @override
  String toString() {
    if (minReviews != null) {
      return '${minRating.toStringAsFixed(1)}+ stars (${minReviews}+ reviews)';
    }
    return '${minRating.toStringAsFixed(1)}+ stars';
  }
}
