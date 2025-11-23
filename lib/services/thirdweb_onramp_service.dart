import 'dart:convert';

/// ThirdWeb Onramp Service
/// Provides integration with ThirdWeb Pay for fiat-to-crypto onramping
class ThirdWebOnrampService {
  // ThirdWeb client configuration
  static const String _clientId = '33d89c360e1ec70249ee4f1e09f8ee2c'; // TODO: Replace with your actual client ID
  
  /// Get client ID (for external use)
  static String get clientId => _clientId;
  
  /// Supported networks for onramping
  static const Map<String, Map<String, String>> supportedNetworks = {
    'polygon': {
      'name': 'Polygon',
      'chainId': '137',
      'symbol': 'MATIC',
      'explorerUrl': 'https://polygonscan.com',
    },
    'polygon-amoy': {
      'name': 'Polygon Amoy Testnet',
      'chainId': '80002',
      'symbol': 'MATIC',
      'explorerUrl': 'https://amoy.polygonscan.com',
    },
    'ethereum': {
      'name': 'Ethereum',
      'chainId': '1',
      'symbol': 'ETH',
      'explorerUrl': 'https://etherscan.io',
    },
  };
  
  /// Generate ThirdWeb Pay widget URL
  /// [walletAddress] - The user's wallet address to receive funds
  /// [network] - The blockchain network (polygon, ethereum, etc.)
  /// [amount] - Default purchase amount (optional)
  /// [currency] - Fiat currency code (default: USD)
  /// [theme] - UI theme: 'light' or 'dark'
  static String generateOnrampUrl({
    required String walletAddress,
    String network = 'polygon',
    double? amount,
    String currency = 'USD',
    String theme = 'dark',
  }) {
    final networkConfig = supportedNetworks[network];
    if (networkConfig == null) {
      throw Exception('Unsupported network: $network');
    }
    
    // Build ThirdWeb Pay URL
    final baseUrl = 'https://embedded-wallet.thirdweb.com/sdk/2022-08-12/pay';
    
    final params = {
      'clientId': _clientId,
      'theme': theme,
      'mode': 'fund_wallet',
      'payOptions': jsonEncode({
        'mode': 'fund_wallet',
        'prefillWalletAddress': walletAddress,
        'metadata': {
          'name': 'Akofa Wallet',
        },
        'buyWithCrypto': {
          'testMode': network.contains('testnet') || network.contains('amoy'),
        },
        'buyWithFiat': {
          'testMode': network.contains('testnet') || network.contains('amoy'),
          'prefillBuy': {
            'chain': networkConfig['chainId'],
            'token': networkConfig['symbol'],
            if (amount != null) 'amount': amount.toString(),
          },
        },
      }),
    };
    
    final uri = Uri.parse(baseUrl).replace(queryParameters: params);
    return uri.toString();
  }
  
  /// Generate simplified onramp URL using ThirdWeb Connect Pay
  static String generateSimpleOnrampUrl({
    required String walletAddress,
    String network = 'polygon',
    double? amount,
  }) {
    // Use ThirdWeb Connect iframe embed
    // Format: https://thirdweb.com/pay/buy
    final baseUrl = 'https://thirdweb.com/pay/buy';
    
    final params = <String, String>{
      'clientId': _clientId,
      'theme': 'dark',
      'toAddress': walletAddress,
    };
    
    final networkConfig = supportedNetworks[network];
    if (networkConfig != null) {
      params['chainId'] = networkConfig['chainId']!;
    }
    
    if (amount != null) {
      params['tokenAmount'] = amount.toString();
    }
    
    final uri = Uri.parse(baseUrl).replace(queryParameters: params);
    return uri.toString();
  }
  
  /// Get network configuration
  static Map<String, String>? getNetworkConfig(String network) {
    return supportedNetworks[network];
  }
  
  /// Check if client ID is configured
  static bool get isConfigured {
    return _clientId.isNotEmpty && _clientId != 'YOUR_THIRDWEB_CLIENT_ID';
  }
  
  /// Get supported networks list
  static List<String> get availableNetworks => supportedNetworks.keys.toList();
  
  /// Validate wallet address format
  static bool isValidAddress(String address) {
    // Check if it's a valid Ethereum/Polygon address
    return address.startsWith('0x') && address.length == 42;
  }
}
