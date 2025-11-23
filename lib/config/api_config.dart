/// ═══════════════════════════════════════════════════════════════════════════
/// API Configuration for AzixFlutter
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// ⚠️ WARNING: Do NOT commit this file with your actual API keys!
/// ⚠️ Keep your API keys private and secure!
/// 
/// This file contains API keys and configuration for external services.
/// See POLYGONSCAN_SETUP.md for detailed setup instructions.
/// ═══════════════════════════════════════════════════════════════════════════

class ApiConfig {
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // PolygonScan API Key Configuration
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  /// Get a free API key from: https://polygonscan.com/apis
  /// 
  /// The same API key works for both mainnet and testnet (Amoy)
  /// 
  /// 🚨 IMPORTANT: Replace 'YourApiKeyToken' with your actual API key
  /// 
  /// Without an API key:
  /// ❌ API has severe rate limits (1 call per 5 seconds)
  /// ❌ On Amoy testnet, transactions may not be visible
  /// ❌ You may receive "No transactions found" even when transactions exist
  /// 
  /// With an API key (free tier):
  /// ✅ 5 calls per second
  /// ✅ Transactions load instantly
  /// ✅ Full access to all endpoints
  static const String polygonScanApiKey = '5EA7PQ82E3WV35C4NQ91FBTJEDPYACXIT7';
  
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Alchemy API Key Configuration (Better alternative for transaction history)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  /// Get a free API key from: https://www.alchemy.com/
  /// 
  /// Alchemy provides full transaction history indexing for both testnet and mainnet
  /// 
  /// 🚨 IMPORTANT: Replace 'YourAlchemyApiKey' with your actual API key
  /// 
  /// Benefits:
  /// ✅ Full transaction history (not just recent blocks)
  /// ✅ Works perfectly on Amoy testnet
  /// ✅ Free tier: 300M compute units/month
  /// ✅ Much faster than direct RPC scanning
  /// ✅ Reliable and well-maintained
  static const String alchemyApiKey = 'z1iMUJVWzX5GjRelx58V_';
  
  /// Check if Alchemy API key is configured
  static bool get hasAlchemyApiKey =>
      alchemyApiKey != 'YourAlchemyApiKey' &&
      alchemyApiKey.isNotEmpty;
  
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Helper Methods
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  /// Check if API key is configured
  static bool get hasPolygonScanApiKey => 
      polygonScanApiKey != 'YourApiKeyToken' && 
      polygonScanApiKey.isNotEmpty;
  
  /// Get helpful error message when API key is not configured
  static String get apiKeySetupInstructions => '''
═══════════════════════════════════════════════════════════════════════════
⚠️  PolygonScan API Key Not Configured
═══════════════════════════════════════════════════════════════════════════

Your transactions may not be visible without an API key.

Quick Setup (5 minutes):
1. Visit: https://polygonscan.com/apis
2. Register for a free account
3. Generate an API key
4. Add it to: lib/config/api_config.dart
5. Restart the app

For detailed instructions, see: POLYGONSCAN_SETUP.md

═══════════════════════════════════════════════════════════════════════════
''';
}

