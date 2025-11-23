import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service for integrating thirdweb on-ramp functionality
/// Allows users to buy crypto directly to their Polygon wallet addresses
class ThirdwebOnRampService {
  // Thirdweb client ID - replace with your actual client ID from thirdweb dashboard
  // Get it from: https://thirdweb.com/dashboard
  // Add THIRDWEB_CLIENT_ID to your .env file
  static const String _defaultClientId = 'YOUR_THIRDWEB_CLIENT_ID';
  
  // Thirdweb Pay widget base URL
  static const String _payWidgetBaseUrl = 'https://pay.thirdweb.com';

  /// Get thirdweb client ID from environment or use default
  static String get clientId {
    try {
      // Try to load from environment variables first
      // Check if dotenv is initialized before accessing
      if (dotenv.isInitialized) {
        final envClientId = dotenv.env['THIRDWEB_CLIENT_ID'];
        if (envClientId != null && envClientId.isNotEmpty) {
          return envClientId;
        }
      }
    } catch (e) {
      // If dotenv is not initialized or any error occurs, fall back to default
      // This prevents NotInitializedError
    }
    // Fallback to default (should be replaced with actual client ID)
    return _defaultClientId;
  }

  /// Generate thirdweb Pay widget URL for on-ramping
  /// 
  /// Parameters:
  /// - walletAddress: User's Polygon wallet address (0x...)
  /// - chainId: Polygon chain ID (137 for mainnet, 80002 for Amoy testnet)
  /// - tokenAddress: Optional token contract address (null for native MATIC)
  /// - amount: Optional pre-filled amount
  /// - currencyCode: Optional fiat currency code (default: 'USD')
  static String generateOnRampUrl({
    required String walletAddress,
    int chainId = 137, // Polygon mainnet
    String? tokenAddress,
    String? amount,
    String currencyCode = 'USD',
    String? email,
    String theme = 'dark',
  }) {
    // Validate wallet address
    if (!walletAddress.startsWith('0x') || walletAddress.length != 42) {
      throw Exception('Invalid Polygon wallet address');
    }

    // Build query parameters
    final queryParams = <String, String>{
      'clientId': clientId,
      'chainId': chainId.toString(),
      'walletAddress': walletAddress,
      'mode': 'fund_wallet',
      'theme': theme,
      'currencyCode': currencyCode,
    };

    // Add optional parameters
    if (tokenAddress != null && tokenAddress.isNotEmpty) {
      queryParams['tokenAddress'] = tokenAddress;
    }

    if (amount != null && amount.isNotEmpty) {
      queryParams['amount'] = amount;
    }

    if (email != null && email.isNotEmpty) {
      queryParams['email'] = email;
    }

    // Build URL
    final uri = Uri.parse(_payWidgetBaseUrl).replace(
      queryParameters: queryParams,
    );

    return uri.toString();
  }

  /// Generate on-ramp URL for specific token purchase
  /// 
  /// Common Polygon tokens:
  /// - USDC: 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174
  /// - USDT: 0xc2132D05D31c914a87C6611C10748AEb04B58e8F
  /// - DAI: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063
  /// - WETH: 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619
  static String generateTokenOnRampUrl({
    required String walletAddress,
    required String tokenAddress,
    int chainId = 137,
    String? amount,
    String currencyCode = 'USD',
    String? email,
    String theme = 'dark',
  }) {
    return generateOnRampUrl(
      walletAddress: walletAddress,
      chainId: chainId,
      tokenAddress: tokenAddress,
      amount: amount,
      currencyCode: currencyCode,
      email: email,
      theme: theme,
    );
  }

  /// Get supported tokens for Polygon
  static Map<String, Map<String, dynamic>> getSupportedTokens() {
    return {
      'MATIC': {
        'name': 'Polygon (MATIC)',
        'symbol': 'MATIC',
        'address': null, // Native token
        'decimals': 18,
        'icon': 'https://assets.coingecko.com/coins/images/4713/large/matic-token-icon.png',
      },
      'USDC': {
        'name': 'USD Coin',
        'symbol': 'USDC',
        'address': '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174',
        'decimals': 6,
        'icon': 'https://assets.coingecko.com/coins/images/6319/large/USD_Coin_icon.png',
      },
      'USDT': {
        'name': 'Tether USD',
        'symbol': 'USDT',
        'address': '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
        'decimals': 6,
        'icon': 'https://assets.coingecko.com/coins/images/325/large/Tether.png',
      },
      'DAI': {
        'name': 'Dai Stablecoin',
        'symbol': 'DAI',
        'address': '0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063',
        'decimals': 18,
        'icon': 'https://assets.coingecko.com/coins/images/9956/large/4943.png',
      },
      'WETH': {
        'name': 'Wrapped Ether',
        'symbol': 'WETH',
        'address': '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619',
        'decimals': 18,
        'icon': 'https://assets.coingecko.com/coins/images/2518/large/weth.png',
      },
    };
  }

  /// Validate Polygon wallet address format
  static bool isValidPolygonAddress(String address) {
    return address.startsWith('0x') &&
        address.length == 42 &&
        RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address);
  }

  /// Check if thirdweb client ID is configured
  static bool isConfigured() {
    return clientId != _defaultClientId && clientId.isNotEmpty;
  }
}

