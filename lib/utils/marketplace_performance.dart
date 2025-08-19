import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

/// Performance optimization utilities for the marketplace
class MarketplacePerformance {
  
  static final Map<String, Timer> _debounceTimers = {};
  static final Map<String, dynamic> _memoryCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  
  /// Debounce function calls to prevent excessive API requests
  static void debounce(
    String key,
    Function() callback, {
    Duration delay = const Duration(milliseconds: 500),
  }) {
    if (_debounceTimers[key]?.isActive ?? false) {
      _debounceTimers[key]!.cancel();
    }
    
    _debounceTimers[key] = Timer(delay, callback);
  }
  
  /// Memory cache with expiration
  static void cacheData(
    String key,
    dynamic data, {
    Duration expiration = const Duration(minutes: 5),
  }) {
    _memoryCache[key] = data;
    _cacheTimestamps[key] = DateTime.now().add(expiration);
  }
  
  /// Get cached data if not expired
  static T? getCachedData<T>(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp != null && DateTime.now().isBefore(timestamp)) {
      return _memoryCache[key] as T?;
    } else {
      // Remove expired cache
      _memoryCache.remove(key);
      _cacheTimestamps.remove(key);
      return null;
    }
  }
  
  /// Clear all cache
  static void clearCache() {
    _memoryCache.clear();
    _cacheTimestamps.clear();
  }
  
  /// Clear expired cache entries
  static void cleanExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    _cacheTimestamps.forEach((key, timestamp) {
      if (now.isAfter(timestamp)) {
        expiredKeys.add(key);
      }
    });
    
    for (final key in expiredKeys) {
      _memoryCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }
  
  /// Persistent cache using SharedPreferences
  static Future<void> setCachedData(
    String key,
    dynamic data, {
    Duration expiration = const Duration(hours: 1),
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'expiration': expiration.inMilliseconds,
      };
      
      await prefs.setString('cache_$key', jsonEncode(cacheData));
    } catch (e) {
      debugPrint('Failed to cache data: $e');
    }
  }
  
  /// Get persistent cached data
  static Future<T?> getCachedDataPersistent<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cache_$key');
      
      if (cachedJson == null) return null;
      
      final cacheData = jsonDecode(cachedJson);
      final timestamp = cacheData['timestamp'] as int;
      final expiration = cacheData['expiration'] as int;
      
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - timestamp > expiration) {
        // Expired, remove from cache
        await prefs.remove('cache_$key');
        return null;
      }
      
      return cacheData['data'] as T?;
    } catch (e) {
      debugPrint('Failed to get cached data: $e');
      return null;
    }
  }
  
  /// Lazy loading helper for images
  static Widget lazyImage({
    required String imageUrl,
    required Widget placeholder,
    Widget? errorWidget,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
  }) {
    return Image.network(
      imageUrl,
      fit: fit,
      width: width,
      height: height,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder;
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? placeholder;
      },
    );
  }
  
  /// Pagination helper
  static Widget buildPaginatedList<T>({
    required List<T> items,
    required Widget Function(T item, int index) itemBuilder,
    required Future<void> Function() onLoadMore,
    required bool hasMore,
    required bool isLoading,
    Widget? loadingWidget,
    Widget? emptyWidget,
    ScrollController? scrollController,
  }) {
    if (items.isEmpty && !isLoading) {
      return emptyWidget ?? const Center(child: Text('No items found'));
    }
    
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!isLoading && 
            hasMore && 
            scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.builder(
        controller: scrollController,
        itemCount: items.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return loadingWidget ?? 
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
          }
          
          return itemBuilder(items[index], index);
        },
      ),
    );
  }
  
  /// Batch processing helper
  static Future<List<R>> batchProcess<T, R>(
    List<T> items,
    Future<R> Function(T item) processor, {
    int batchSize = 10,
    Duration batchDelay = const Duration(milliseconds: 100),
  }) async {
    final results = <R>[];
    
    for (int i = 0; i < items.length; i += batchSize) {
      final batch = items.skip(i).take(batchSize).toList();
      final batchResults = await Future.wait(
        batch.map(processor),
      );
      results.addAll(batchResults);
      
      // Small delay between batches to prevent overwhelming the system
      if (i + batchSize < items.length) {
        await Future.delayed(batchDelay);
      }
    }
    
    return results;
  }
  
  /// Performance monitoring
  static Future<T> measurePerformance<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await operation();
      stopwatch.stop();
      
      debugPrint('Performance: $operationName took ${stopwatch.elapsedMilliseconds}ms');
      
      return result;
    } catch (e) {
      stopwatch.stop();
      debugPrint('Performance: $operationName failed after ${stopwatch.elapsedMilliseconds}ms - $e');
      rethrow;
    }
  }
  
  /// Memory usage optimization for large lists
  static Widget buildOptimizedList<T>({
    required List<T> items,
    required Widget Function(T item, int index) itemBuilder,
    required double itemHeight,
    int? visibleItemsBuffer,
  }) {
    return ListView.builder(
      itemCount: items.length,
      itemExtent: itemHeight,
      cacheExtent: (visibleItemsBuffer ?? 10) * itemHeight,
      itemBuilder: (context, index) {
        return itemBuilder(items[index], index);
      },
    );
  }
  
  /// Preload critical data
  static Future<void> preloadCriticalData() async {
    try {
      // Preload frequently accessed data
      await Future.wait([
        _preloadCategories(),
        _preloadFeaturedItems(),
        _preloadUserPreferences(),
      ]);
    } catch (e) {
      debugPrint('Failed to preload critical data: $e');
    }
  }
  
  static Future<void> _preloadCategories() async {
    // TODO: Implement category preloading
    debugPrint('Preloading categories...');
  }
  
  static Future<void> _preloadFeaturedItems() async {
    // TODO: Implement featured items preloading
    debugPrint('Preloading featured items...');
  }
  
  static Future<void> _preloadUserPreferences() async {
    // TODO: Implement user preferences preloading
    debugPrint('Preloading user preferences...');
  }
  
  /// Image optimization
  static String optimizeImageUrl(
    String originalUrl, {
    int? width,
    int? height,
    String quality = 'medium',
  }) {
    // This would integrate with a CDN service like Cloudinary or ImageKit
    // For now, return the original URL
    return originalUrl;
  }
  
  /// Network request optimization
  static Future<T> optimizedNetworkRequest<T>(
    String cacheKey,
    Future<T> Function() request, {
    Duration cacheExpiration = const Duration(minutes: 5),
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      // Try memory cache first
      final cachedData = getCachedData<T>(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }
      
      // Try persistent cache
      final persistentData = await getCachedDataPersistent<T>(cacheKey);
      if (persistentData != null) {
        // Also cache in memory for faster access
        cacheData(cacheKey, persistentData, expiration: cacheExpiration);
        return persistentData;
      }
    }
    
    // Make fresh request
    final result = await request();
    
    // Cache the result
    cacheData(cacheKey, result, expiration: cacheExpiration);
    await setCachedData(cacheKey, result, expiration: cacheExpiration);
    
    return result;
  }
  
  /// Dispose of performance utilities
  static void dispose() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    clearCache();
  }
}

/// Performance-optimized image widget
class OptimizedImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  
  const OptimizedImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);
  
  @override
  State<OptimizedImage> createState() => _OptimizedImageState();
}

class _OptimizedImageState extends State<OptimizedImage> {
  late String _optimizedUrl;
  
  @override
  void initState() {
    super.initState();
    _optimizedUrl = MarketplacePerformance.optimizeImageUrl(
      widget.imageUrl,
      width: widget.width?.toInt(),
      height: widget.height?.toInt(),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return MarketplacePerformance.lazyImage(
      imageUrl: _optimizedUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: widget.placeholder ?? 
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey[200],
            child: const Icon(Icons.image, color: Colors.grey),
          ),
      errorWidget: widget.errorWidget,
    );
  }
}

/// Performance monitoring widget
class PerformanceMonitor extends StatefulWidget {
  final Widget child;
  final String? name;
  
  const PerformanceMonitor({
    Key? key,
    required this.child,
    this.name,
  }) : super(key: key);
  
  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor> {
  late Stopwatch _stopwatch;
  
  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
  }
  
  @override
  void dispose() {
    _stopwatch.stop();
    final renderTime = _stopwatch.elapsedMilliseconds;
    debugPrint('Render time for ${widget.name ?? 'Widget'}: ${renderTime}ms');
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
