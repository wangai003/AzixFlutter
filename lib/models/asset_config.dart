import 'package:flutter/material.dart';

/// Configuration for Stellar assets including stablecoins
class AssetConfig {
  final String code;
  final String issuer;
  final String name;
  final String symbol;
  final int decimals;
  final String? iconUrl;
  final bool isStablecoin;
  final String? peggedCurrency;
  final String? description;
  final bool isNative; // For XLM

  const AssetConfig({
    required this.code,
    required this.issuer,
    required this.name,
    required this.symbol,
    required this.decimals,
    this.iconUrl,
    this.isStablecoin = false,
    this.peggedCurrency,
    this.description,
    this.isNative = false,
  });

  /// Create asset from Stellar Asset object
  factory AssetConfig.fromStellarAsset(dynamic asset, {bool isNative = false}) {
    if (isNative) {
      return AssetConfig(
        code: 'XLM',
        issuer: 'native',
        name: 'Stellar Lumens',
        symbol: 'XLM',
        decimals: 7,
        isNative: true,
        description: 'Native Stellar cryptocurrency',
      );
    }

    return AssetConfig(
      code: asset.assetCode ?? 'UNKNOWN',
      issuer: asset.assetIssuer ?? 'UNKNOWN',
      name: asset.assetCode ?? 'Unknown Asset',
      symbol: asset.assetCode ?? 'UNKNOWN',
      decimals: 7, // Default for most Stellar assets
    );
  }

  /// Get asset identifier for storage/comparison
  String get assetId => isNative ? 'XLM' : '${code}_${issuer}';

  /// Check if this is a known trusted asset
  bool get isTrusted => _trustedAssets.contains(assetId);

  /// Get display color for UI
  Color get displayColor {
    if (isNative) return Colors.blue;
    if (isStablecoin) return Colors.green;
    return Colors.orange;
  }

  /// Static list of trusted assets
  static const Set<String> _trustedAssets = {
    'XLM',
    'AKOFA_GAXGCEV2XGCUORUWQ4B2NTRVLKUVDCOQT2EL5C3GY3X72LFR2G3QKSKW',
    'USDC_GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
    'EURC_GDHU6WRG4IEQXM5NZ4BMPKOXHW76MZM4Y2IEMFDVXBSDP6SJY4ITNPP2',
  };

  @override
  String toString() => '$symbol ($code)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetConfig &&
          runtimeType == other.runtimeType &&
          assetId == other.assetId;

  @override
  int get hashCode => assetId.hashCode;
}

/// Pre-configured asset configurations
class AssetConfigs {
  /// Native Stellar asset
  static const AssetConfig xlm = AssetConfig(
    code: 'XLM',
    issuer: 'native',
    name: 'Stellar Lumens',
    symbol: 'XLM',
    decimals: 7,
    isNative: true,
    description: 'The native cryptocurrency of the Stellar network',
  );

  /// AKOFA token
  static const AssetConfig akofa = AssetConfig(
    code: 'AKOFA',
    issuer: 'GAXGCEV2XGCUORUWQ4B2NTRVLKUVDCOQT2EL5C3GY3X72LFR2G3QKSKW',
    name: 'AKOFA Token',
    symbol: 'AKOFA',
    decimals: 7,
    description: 'AKOFA ecosystem token',
  );

  /// USD Coin (USDC) on Stellar
  static const AssetConfig usdc = AssetConfig(
    code: 'USDC',
    issuer: 'GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
    name: 'USD Coin',
    symbol: 'USDC',
    decimals: 7,
    isStablecoin: true,
    peggedCurrency: 'USD',
    description: 'USD-pegged stablecoin issued by Circle',
  );

  /// Euro Coin (EURC) on Stellar
  static const AssetConfig eurc = AssetConfig(
    code: 'EURC',
    issuer: 'GDHU6WRG4IEQXM5NZ4BMPKOXHW76MZM4Y2IEMFDVXBSDP6SJY4ITNPP2',
    name: 'Euro Coin',
    symbol: 'EURC',
    decimals: 7,
    isStablecoin: true,
    peggedCurrency: 'EUR',
    description: 'EUR-pegged stablecoin issued by Circle',
  );

  /// Tether USD (USDT) on Stellar
  static const AssetConfig usdt = AssetConfig(
    code: 'USDT',
    issuer: 'GCQTGZQQ5G4PTM2GLDDVLOTD5TB6GWDCLIT2HKIBTY5BXNPBJXSSY6S6',
    name: 'Tether USD',
    symbol: 'USDT',
    decimals: 7,
    isStablecoin: true,
    peggedCurrency: 'USD',
    description: 'USD-pegged stablecoin issued by Tether',
  );

  /// Get all pre-configured assets
  static List<AssetConfig> get allAssets => [xlm, akofa, usdc, eurc, usdt];

  /// Get stablecoins only
  static List<AssetConfig> get stablecoins =>
      allAssets.where((asset) => asset.isStablecoin).toList();

  /// Find asset by code and issuer
  static AssetConfig? findAsset(String code, String issuer) {
    return allAssets.firstWhere(
      (asset) => asset.code == code && asset.issuer == issuer,
      orElse: () => AssetConfig(
        code: code,
        issuer: issuer,
        name: code,
        symbol: code,
        decimals: 7,
      ),
    );
  }

  /// Find asset by asset ID
  static AssetConfig? findByAssetId(String assetId) {
    try {
      return allAssets.firstWhere((asset) => asset.assetId == assetId);
    } catch (e) {
      return null;
    }
  }
}
