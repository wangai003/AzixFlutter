import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Crypto Price Service
/// 
/// Provides real-time cryptocurrency prices with price locking mechanism
/// similar to Coinbase and other exchanges.
/// 
/// Supported tokens: AKOFA, USDC, USDT
/// Price sources: CoinGecko (primary), with fallback to Binance
class CryptoPriceService {
  static final CryptoPriceService _instance = CryptoPriceService._internal();
  factory CryptoPriceService() => _instance;
  CryptoPriceService._internal();

  // Cache for prices
  final Map<String, CryptoPrice> _priceCache = {};
  final Map<String, DateTime> _lastFetchTime = {};
  
  // Price validity duration (how long cached prices are valid)
  static const Duration _cacheValidityDuration = Duration(seconds: 30);
  
  // Price lock duration (how long a locked price is valid for purchase)
  static const Duration _priceLockDuration = Duration(minutes: 5);
  
  // Locked prices for active purchases
  final Map<String, LockedPrice> _lockedPrices = {};

  // Token configurations
  static final Map<String, TokenConfig> supportedTokens = {
    'AKOFA': TokenConfig(
      symbol: 'AKOFA',
      name: 'AKOFA Token',
      contractAddress: '0xf1266ACCf0f757c61e4DFDD9EBBcaC05D2Ee375F',
      decimals: 18,
      isStablecoin: false,
      fixedPriceKES: 5.52, // 1 AKOFA = 5.52 KES (fixed rate)
      coingeckoId: null, // Not listed on CoinGecko
      iconPath: 'assets/icons/akofa.png',
    ),
    'USDC': TokenConfig(
      symbol: 'USDC',
      name: 'USD Coin',
      contractAddress: '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359', // USDC on Polygon
      decimals: 6,
      isStablecoin: true,
      fixedPriceKES: null, // Dynamic pricing
      coingeckoId: 'usd-coin',
      iconPath: 'assets/icons/usdc.png',
    ),
    'USDT': TokenConfig(
      symbol: 'USDT',
      name: 'Tether USD',
      contractAddress: '0xc2132D05D31c914a87C6611C10748AEb04B58e8F', // USDT on Polygon
      decimals: 6,
      isStablecoin: true,
      fixedPriceKES: null, // Dynamic pricing
      coingeckoId: 'tether',
      iconPath: 'assets/icons/usdt.png',
    ),
  };

  /// Get current KES to USD exchange rate
  Future<double> getKESToUSDRate() async {
    try {
      // Try CoinGecko first (free API)
      final response = await http.get(
        Uri.parse('https://api.coingecko.com/api/v3/simple/price?ids=usd&vs_currencies=kes'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // CoinGecko returns USD price in KES
        return data['usd']?['kes']?.toDouble() ?? 155.0;
      }
    } catch (e) {
      debugPrint('❌ Error fetching KES/USD rate: $e');
    }

    // Fallback to approximate rate
    return 155.0; // Default KES/USD rate
  }

  /// Get real-time price for a token in KES
  Future<CryptoPrice> getTokenPriceKES(String symbol) async {
    final tokenConfig = supportedTokens[symbol.toUpperCase()];
    if (tokenConfig == null) {
      throw Exception('Unsupported token: $symbol');
    }

    // Check cache first
    if (_isCacheValid(symbol)) {
      debugPrint('📦 Using cached price for $symbol');
      return _priceCache[symbol]!;
    }

    // For AKOFA, use fixed price
    if (symbol.toUpperCase() == 'AKOFA') {
      final price = CryptoPrice(
        symbol: 'AKOFA',
        priceKES: tokenConfig.fixedPriceKES!,
        priceUSD: tokenConfig.fixedPriceKES! / 155.0,
        timestamp: DateTime.now(),
        source: 'fixed',
      );
      _updateCache(symbol, price);
      return price;
    }

    // For stablecoins (USDC, USDT), fetch real-time price
    try {
      debugPrint('🔄 Fetching real-time price for $symbol...');
      
      // Get USD price from CoinGecko
      final priceUSD = await _fetchUSDPrice(tokenConfig.coingeckoId!);
      
      // Get KES/USD exchange rate
      final kesRate = await getKESToUSDRate();
      
      // Calculate KES price
      final priceKES = priceUSD * kesRate;
      
      final price = CryptoPrice(
        symbol: symbol.toUpperCase(),
        priceKES: priceKES,
        priceUSD: priceUSD,
        kesUsdRate: kesRate,
        timestamp: DateTime.now(),
        source: 'coingecko',
      );
      
      _updateCache(symbol, price);
      debugPrint('✅ $symbol price: \$$priceUSD = KES $priceKES');
      
      return price;
    } catch (e) {
      debugPrint('❌ Error fetching price for $symbol: $e');
      
      // Fallback for stablecoins (should be ~$1)
      final kesRate = await getKESToUSDRate();
      final fallbackPrice = CryptoPrice(
        symbol: symbol.toUpperCase(),
        priceKES: kesRate, // 1 USD = kesRate KES
        priceUSD: 1.0,
        kesUsdRate: kesRate,
        timestamp: DateTime.now(),
        source: 'fallback',
      );
      _updateCache(symbol, fallbackPrice);
      return fallbackPrice;
    }
  }

  /// Fetch USD price from CoinGecko
  Future<double> _fetchUSDPrice(String coingeckoId) async {
    final response = await http.get(
      Uri.parse('https://api.coingecko.com/api/v3/simple/price?ids=$coingeckoId&vs_currencies=usd'),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data[coingeckoId]?['usd']?.toDouble() ?? 1.0;
    }
    
    throw Exception('Failed to fetch price from CoinGecko');
  }

  /// Lock in a price for a purchase (Coinbase-style)
  /// Returns a lock ID that must be used when completing the purchase
  Future<LockedPrice> lockPrice({
    required String symbol,
    required double tokenAmount,
  }) async {
    debugPrint('🔒 Locking price for $tokenAmount $symbol...');
    
    // Get current price
    final currentPrice = await getTokenPriceKES(symbol);
    
    // Generate unique lock ID
    final lockId = '${symbol}_${DateTime.now().millisecondsSinceEpoch}_${tokenAmount.hashCode}';
    
    // Calculate total in KES
    final totalKES = tokenAmount * currentPrice.priceKES;
    
    // Create locked price
    final lockedPrice = LockedPrice(
      lockId: lockId,
      symbol: symbol.toUpperCase(),
      tokenAmount: tokenAmount,
      pricePerTokenKES: currentPrice.priceKES,
      pricePerTokenUSD: currentPrice.priceUSD,
      totalKES: totalKES,
      totalUSD: tokenAmount * currentPrice.priceUSD,
      lockedAt: DateTime.now(),
      expiresAt: DateTime.now().add(_priceLockDuration),
      kesUsdRate: currentPrice.kesUsdRate,
    );
    
    // Store locked price
    _lockedPrices[lockId] = lockedPrice;
    
    debugPrint('✅ Price locked: $lockId');
    debugPrint('   $tokenAmount $symbol @ KES ${currentPrice.priceKES.toStringAsFixed(2)} = KES ${totalKES.toStringAsFixed(2)}');
    debugPrint('   Lock expires at: ${lockedPrice.expiresAt}');
    
    return lockedPrice;
  }

  /// Get a locked price by ID
  LockedPrice? getLockedPrice(String lockId) {
    final locked = _lockedPrices[lockId];
    if (locked == null) return null;
    
    // Check if expired
    if (DateTime.now().isAfter(locked.expiresAt)) {
      debugPrint('⚠️ Locked price expired: $lockId');
      _lockedPrices.remove(lockId);
      return null;
    }
    
    return locked;
  }

  /// Validate and consume a locked price (for completing purchase)
  LockedPrice? consumeLockedPrice(String lockId) {
    final locked = getLockedPrice(lockId);
    if (locked != null) {
      _lockedPrices.remove(lockId);
      debugPrint('✅ Consumed locked price: $lockId');
    }
    return locked;
  }

  /// Clear expired locked prices
  void clearExpiredLocks() {
    final now = DateTime.now();
    _lockedPrices.removeWhere((_, locked) => now.isAfter(locked.expiresAt));
  }

  /// Calculate how much KES is needed for a given token amount
  Future<PurchaseQuote> getQuote({
    required String symbol,
    required double tokenAmount,
  }) async {
    final price = await getTokenPriceKES(symbol);
    final totalKES = tokenAmount * price.priceKES;
    final totalUSD = tokenAmount * price.priceUSD;
    
    return PurchaseQuote(
      symbol: symbol.toUpperCase(),
      tokenAmount: tokenAmount,
      pricePerTokenKES: price.priceKES,
      pricePerTokenUSD: price.priceUSD,
      totalKES: totalKES,
      totalUSD: totalUSD,
      validUntil: DateTime.now().add(const Duration(seconds: 30)),
      source: price.source,
    );
  }

  /// Calculate how many tokens can be purchased with a given KES amount
  Future<PurchaseQuote> getQuoteFromKES({
    required String symbol,
    required double amountKES,
  }) async {
    final price = await getTokenPriceKES(symbol);
    final tokenAmount = amountKES / price.priceKES;
    
    return PurchaseQuote(
      symbol: symbol.toUpperCase(),
      tokenAmount: tokenAmount,
      pricePerTokenKES: price.priceKES,
      pricePerTokenUSD: price.priceUSD,
      totalKES: amountKES,
      totalUSD: amountKES / (price.kesUsdRate ?? 155.0),
      validUntil: DateTime.now().add(const Duration(seconds: 30)),
      source: price.source,
    );
  }

  /// Get all supported tokens with current prices
  Future<List<TokenWithPrice>> getAllTokenPrices() async {
    final List<TokenWithPrice> result = [];
    
    for (final entry in supportedTokens.entries) {
      try {
        final price = await getTokenPriceKES(entry.key);
        result.add(TokenWithPrice(
          config: entry.value,
          currentPrice: price,
        ));
      } catch (e) {
        debugPrint('Error getting price for ${entry.key}: $e');
      }
    }
    
    return result;
  }

  /// Stream of price updates for a token
  Stream<CryptoPrice> priceStream(String symbol) async* {
    while (true) {
      yield await getTokenPriceKES(symbol);
      await Future.delayed(const Duration(seconds: 10));
    }
  }

  // Cache management
  bool _isCacheValid(String symbol) {
    final lastFetch = _lastFetchTime[symbol];
    if (lastFetch == null) return false;
    return DateTime.now().difference(lastFetch) < _cacheValidityDuration;
  }

  void _updateCache(String symbol, CryptoPrice price) {
    _priceCache[symbol] = price;
    _lastFetchTime[symbol] = DateTime.now();
  }

  /// Clear all cached prices
  void clearCache() {
    _priceCache.clear();
    _lastFetchTime.clear();
  }
}

/// Token configuration
class TokenConfig {
  final String symbol;
  final String name;
  final String contractAddress;
  final int decimals;
  final bool isStablecoin;
  final double? fixedPriceKES; // For tokens with fixed KES price (like AKOFA)
  final String? coingeckoId;
  final String iconPath;

  const TokenConfig({
    required this.symbol,
    required this.name,
    required this.contractAddress,
    required this.decimals,
    required this.isStablecoin,
    this.fixedPriceKES,
    this.coingeckoId,
    required this.iconPath,
  });
}

/// Real-time crypto price
class CryptoPrice {
  final String symbol;
  final double priceKES;
  final double priceUSD;
  final double? kesUsdRate;
  final DateTime timestamp;
  final String source;

  CryptoPrice({
    required this.symbol,
    required this.priceKES,
    required this.priceUSD,
    this.kesUsdRate,
    required this.timestamp,
    required this.source,
  });

  bool get isStale => DateTime.now().difference(timestamp) > const Duration(minutes: 1);

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'priceKES': priceKES,
    'priceUSD': priceUSD,
    'kesUsdRate': kesUsdRate,
    'timestamp': timestamp.toIso8601String(),
    'source': source,
  };
}

/// Locked price for a purchase (Coinbase-style price lock)
class LockedPrice {
  final String lockId;
  final String symbol;
  final double tokenAmount;
  final double pricePerTokenKES;
  final double pricePerTokenUSD;
  final double totalKES;
  final double totalUSD;
  final DateTime lockedAt;
  final DateTime expiresAt;
  final double? kesUsdRate;

  LockedPrice({
    required this.lockId,
    required this.symbol,
    required this.tokenAmount,
    required this.pricePerTokenKES,
    required this.pricePerTokenUSD,
    required this.totalKES,
    required this.totalUSD,
    required this.lockedAt,
    required this.expiresAt,
    this.kesUsdRate,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  Duration get remainingTime => expiresAt.difference(DateTime.now());

  Map<String, dynamic> toJson() => {
    'lockId': lockId,
    'symbol': symbol,
    'tokenAmount': tokenAmount,
    'pricePerTokenKES': pricePerTokenKES,
    'pricePerTokenUSD': pricePerTokenUSD,
    'totalKES': totalKES,
    'totalUSD': totalUSD,
    'lockedAt': lockedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
  };
}

/// Purchase quote (not yet locked)
class PurchaseQuote {
  final String symbol;
  final double tokenAmount;
  final double pricePerTokenKES;
  final double pricePerTokenUSD;
  final double totalKES;
  final double totalUSD;
  final DateTime validUntil;
  final String source;

  PurchaseQuote({
    required this.symbol,
    required this.tokenAmount,
    required this.pricePerTokenKES,
    required this.pricePerTokenUSD,
    required this.totalKES,
    required this.totalUSD,
    required this.validUntil,
    required this.source,
  });

  bool get isExpired => DateTime.now().isAfter(validUntil);
}

/// Token with current price
class TokenWithPrice {
  final TokenConfig config;
  final CryptoPrice currentPrice;

  TokenWithPrice({
    required this.config,
    required this.currentPrice,
  });
}

