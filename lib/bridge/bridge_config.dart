/// Bridge configuration for cross-chain operations
/// Contains LI.FI endpoints, chain IDs, and testnet/mainnet settings
class BridgeConfig {
  // LI.FI API endpoints
  static const String lifiBaseUrl = 'https://li.quest/v1';
  static const String lifiQuoteEndpoint = '$lifiBaseUrl/quote';
  static const String lifiStatusEndpoint = '$lifiBaseUrl/status';
  static const String lifiExecuteEndpoint = '$lifiBaseUrl/execute';
  
  // Chain IDs (LI.FI format)
  static const String stellarChainId = 'stellar';
  static const String ethereumChainId = '1'; // Mainnet: 1, Goerli: 5
  static const String polygonChainId = '137'; // Mainnet: 137, Mumbai: 80001
  static const String bscChainId = '56'; // Mainnet: 56, Testnet: 97
  static const String avalancheChainId = '43114'; // Mainnet: 43114, Fuji: 43113
  
  // Testnet Chain IDs
  static const String ethereumGoerliChainId = '5';
  static const String polygonMumbaiChainId = '80001';
  static const String bscTestnetChainId = '97';
  static const String avalancheFujiChainId = '43113';
  
  // Stellar network configuration
  static const String stellarTestnetHorizonUrl = 'https://horizon-testnet.stellar.org';
  static const String stellarMainnetHorizonUrl = 'https://horizon.stellar.org';
  static const String stellarTestnetNetworkPassphrase = 'Test SDF Network ; September 2015';
  static const String stellarMainnetNetworkPassphrase = 'Public Global Stellar Network ; September 2015';
  
  // EVM RPC endpoints (for read-only queries)
  static const String ethereumRpcUrl = 'https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY';
  static const String polygonRpcUrl = 'https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY';
  static const String ethereumGoerliRpcUrl = 'https://eth-goerli.g.alchemy.com/v2/YOUR_KEY';
  static const String polygonMumbaiRpcUrl = 'https://polygon-mumbai.g.alchemy.com/v2/YOUR_KEY';
  
  // WalletConnect configuration
  // Note: Full WalletConnect integration requires additional setup
  // Get project ID from https://cloud.walletconnect.com/
  static const String walletConnectProjectId = 'YOUR_WALLETCONNECT_PROJECT_ID';
  static const String walletConnectRelayUrl = 'wss://relay.walletconnect.com';
  
  // Bridge settings
  static const bool useTestnet = true; // Set to false for mainnet
  static const Duration routePollingInterval = Duration(seconds: 5);
  static const Duration routeTimeout = Duration(minutes: 30);
  static const int maxRetries = 3;
  
  // Preferred providers
  static const List<String> preferredProviders = [
    'allbridge', // Prefer Allbridge for Stellar
    'circle', // Prefer Circle CCTP for USDC
    'stargate',
  ];
  
  // Get current network settings
  static bool get isTestnet => useTestnet;
  static String get stellarHorizonUrl => 
      isTestnet ? stellarTestnetHorizonUrl : stellarMainnetHorizonUrl;
  static String get stellarNetworkPassphrase => 
      isTestnet ? stellarTestnetNetworkPassphrase : stellarMainnetNetworkPassphrase;
  
  // Get chain ID based on network
  static String getChainId(String chainName) {
    if (isTestnet) {
      switch (chainName.toLowerCase()) {
        case 'ethereum':
        case 'eth':
          return ethereumGoerliChainId;
        case 'polygon':
        case 'matic':
          return polygonMumbaiChainId;
        case 'bsc':
        case 'binance':
          return bscTestnetChainId;
        case 'avalanche':
        case 'avax':
          return avalancheFujiChainId;
        default:
          return chainName;
      }
    } else {
      switch (chainName.toLowerCase()) {
        case 'ethereum':
        case 'eth':
          return ethereumChainId;
        case 'polygon':
        case 'matic':
          return polygonChainId;
        case 'bsc':
        case 'binance':
          return bscChainId;
        case 'avalanche':
        case 'avax':
          return avalancheChainId;
        default:
          return chainName;
      }
    }
  }
  
  // Get RPC URL for EVM chain
  static String? getRpcUrl(String chainId) {
    if (isTestnet) {
      switch (chainId) {
        case ethereumGoerliChainId:
          return ethereumGoerliRpcUrl;
        case polygonMumbaiChainId:
          return polygonMumbaiRpcUrl;
        default:
          return null;
      }
    } else {
      switch (chainId) {
        case ethereumChainId:
          return ethereumRpcUrl;
        case polygonChainId:
          return polygonRpcUrl;
        default:
          return null;
      }
    }
  }
}

