import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/raffle_model.dart';
import '../models/user_model.dart';

/// Offline caching service for raffle data
class RaffleCacheService {
  static const String _rafflesCacheKey = 'cached_raffles';
  static const String _userEntriesCacheKey = 'cached_user_entries';
  static const String _winnersCacheKey = 'cached_winners';
  static const String _lastSyncKey = 'last_raffle_sync';
  static const Duration _cacheValidity = Duration(hours: 24);

  static Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  /// Cache raffle data
  static Future<void> cacheRaffles(List<RaffleModel> raffles) async {
    try {
      final prefs = await _prefs;
      final rafflesJson = raffles
          .map((r) => jsonEncode(r.toMap()..['id'] = r.id))
          .toList();
      await prefs.setStringList(_rafflesCacheKey, rafflesJson);
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('Error caching raffles: $e');
    }
  }

  /// Get cached raffles
  static Future<List<RaffleModel>?> getCachedRaffles() async {
    try {
      final prefs = await _prefs;
      final lastSyncStr = prefs.getString(_lastSyncKey);

      if (lastSyncStr == null) return null;

      final lastSync = DateTime.parse(lastSyncStr);
      if (DateTime.now().difference(lastSync) > _cacheValidity) {
        // Cache is stale
        await clearCache();
        return null;
      }

      final rafflesJson = prefs.getStringList(_rafflesCacheKey);
      if (rafflesJson == null) return null;

      return rafflesJson.map((jsonStr) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final id = data.remove('id') as String;
        return RaffleModel.fromMap(data, id);
      }).toList();
    } catch (e) {
      print('Error getting cached raffles: $e');
      return null;
    }
  }

  /// Cache user entries
  static Future<void> cacheUserEntries({
    required String userId,
    required List<Map<String, dynamic>> entries,
  }) async {
    try {
      final prefs = await _prefs;
      final cacheKey = '${_userEntriesCacheKey}_$userId';
      final entriesJson = entries.map((e) => jsonEncode(e)).toList();
      await prefs.setStringList(cacheKey, entriesJson);
    } catch (e) {
      print('Error caching user entries: $e');
    }
  }

  /// Get cached user entries
  static Future<List<Map<String, dynamic>>?> getCachedUserEntries(
    String userId,
  ) async {
    try {
      final prefs = await _prefs;
      final cacheKey = '${_userEntriesCacheKey}_$userId';
      final entriesJson = prefs.getStringList(cacheKey);
      if (entriesJson == null) return null;

      return entriesJson
          .map((jsonStr) => jsonDecode(jsonStr) as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error getting cached user entries: $e');
      return null;
    }
  }

  /// Cache winners data
  static Future<void> cacheWinners({
    required String raffleId,
    required List<Map<String, dynamic>> winners,
  }) async {
    try {
      final prefs = await _prefs;
      final cacheKey = '${_winnersCacheKey}_$raffleId';
      final winnersJson = winners.map((w) => jsonEncode(w)).toList();
      await prefs.setStringList(cacheKey, winnersJson);
    } catch (e) {
      print('Error caching winners: $e');
    }
  }

  /// Get cached winners
  static Future<List<Map<String, dynamic>>?> getCachedWinners(
    String raffleId,
  ) async {
    try {
      final prefs = await _prefs;
      final cacheKey = '${_winnersCacheKey}_$raffleId';
      final winnersJson = prefs.getStringList(cacheKey);
      if (winnersJson == null) return null;

      return winnersJson
          .map((jsonStr) => jsonDecode(jsonStr) as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error getting cached winners: $e');
      return null;
    }
  }

  /// Check if data is cached and valid
  static Future<bool> hasValidCache() async {
    try {
      final prefs = await _prefs;
      final lastSyncStr = prefs.getString(_lastSyncKey);

      if (lastSyncStr == null) return false;

      final lastSync = DateTime.parse(lastSyncStr);
      return DateTime.now().difference(lastSync) <= _cacheValidity;
    } catch (e) {
      return false;
    }
  }

  /// Get cache age in hours
  static Future<double?> getCacheAge() async {
    try {
      final prefs = await _prefs;
      final lastSyncStr = prefs.getString(_lastSyncKey);

      if (lastSyncStr == null) return null;

      final lastSync = DateTime.parse(lastSyncStr);
      return DateTime.now().difference(lastSync).inHours.toDouble();
    } catch (e) {
      return null;
    }
  }

  /// Clear all cached data
  static Future<void> clearCache() async {
    try {
      final prefs = await _prefs;
      final keys = prefs.getKeys();

      // Remove all raffle-related cache keys
      final raffleKeys = keys.where(
        (key) =>
            key.startsWith(_rafflesCacheKey) ||
            key.startsWith(_userEntriesCacheKey) ||
            key.startsWith(_winnersCacheKey) ||
            key == _lastSyncKey,
      );

      for (final key in raffleKeys) {
        await prefs.remove(key);
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  /// Clear cache for specific user
  static Future<void> clearUserCache(String userId) async {
    try {
      final prefs = await _prefs;
      final keys = prefs.getKeys();

      final userKeys = keys.where(
        (key) =>
            key.contains(userId) &&
            (key.startsWith(_userEntriesCacheKey) ||
                key.startsWith(_winnersCacheKey)),
      );

      for (final key in userKeys) {
        await prefs.remove(key);
      }
    } catch (e) {
      print('Error clearing user cache: $e');
    }
  }

  /// Get cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await _prefs;
      final keys = prefs.getKeys();

      final raffleKeys = keys
          .where((key) => key.startsWith(_rafflesCacheKey))
          .length;
      final entryKeys = keys
          .where((key) => key.startsWith(_userEntriesCacheKey))
          .length;
      final winnerKeys = keys
          .where((key) => key.startsWith(_winnersCacheKey))
          .length;

      final cacheAge = await getCacheAge();

      return {
        'totalCacheEntries': raffleKeys + entryKeys + winnerKeys,
        'raffleCacheEntries': raffleKeys,
        'entryCacheEntries': entryKeys,
        'winnerCacheEntries': winnerKeys,
        'cacheAgeHours': cacheAge,
        'isValid': cacheAge != null && cacheAge <= _cacheValidity.inHours,
      };
    } catch (e) {
      return {'error': e.toString(), 'totalCacheEntries': 0, 'isValid': false};
    }
  }

  /// Preload critical raffle data for offline use
  static Future<void> preloadCriticalData({
    required String userId,
    List<String>? raffleIds,
  }) async {
    try {
      // This would be called when user goes online to cache important data
      // Implementation would depend on how you want to integrate with RaffleService

      // For now, just update the sync timestamp
      final prefs = await _prefs;
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('Error preloading critical data: $e');
    }
  }

  /// Check if specific raffle data is cached
  static Future<bool> isRaffleCached(String raffleId) async {
    try {
      final cachedRaffles = await getCachedRaffles();
      return cachedRaffles?.any((raffle) => raffle.id == raffleId) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get storage usage estimate
  static Future<int> getEstimatedCacheSize() async {
    try {
      final prefs = await _prefs;
      int totalSize = 0;

      final keys = prefs.getKeys().where(
        (key) =>
            key.startsWith(_rafflesCacheKey) ||
            key.startsWith(_userEntriesCacheKey) ||
            key.startsWith(_winnersCacheKey),
      );

      for (final key in keys) {
        final value = prefs.get(key);
        if (value is String) {
          totalSize += value.length * 2; // Rough estimate for UTF-16 storage
        } else if (value is List<String>) {
          totalSize += value.join('').length * 2;
        }
      }

      return totalSize;
    } catch (e) {
      return 0;
    }
  }
}
