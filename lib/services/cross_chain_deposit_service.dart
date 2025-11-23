import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../bridge/bridge_config.dart';
import '../bridge/services/lifi_client.dart';
import '../bridge/models/route_models.dart' as bridge_models;
import 'allbridge_client.dart';

/// Service for managing cross-chain deposit addresses
/// Uses Allbridge API directly (primary) and LI.FI as fallback
class CrossChainDepositService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Use late initialization to avoid JavaScript interop issues
  late final AllbridgeClient _allbridgeClient = AllbridgeClient();
  late final LifiClient _lifiClient = LifiClient();
  
  // Lazy getters to ensure proper initialization
  AllbridgeClient get allbridgeClient {
    try {
      return _allbridgeClient;
    } catch (e) {
      return AllbridgeClient();
    }
  }
  
  LifiClient get lifiClient {
    try {
      return _lifiClient;
    } catch (e) {
      return LifiClient();
    }
  }

  /// Supported chains for cross-chain deposits
  static const List<Map<String, String>> supportedChains = [
    {'id': '1', 'name': 'Ethereum', 'symbol': 'ETH'},
    {'id': '137', 'name': 'Polygon', 'symbol': 'MATIC'},
    {'id': '56', 'name': 'BSC', 'symbol': 'BNB'},
    {'id': '43114', 'name': 'Avalanche', 'symbol': 'AVAX'},
  ];

  /// Common tokens per chain (for deposit address generation)
  static const Map<String, List<Map<String, String>>> commonTokens = {
    '1': [ // Ethereum
      {'address': 'native', 'symbol': 'ETH', 'name': 'Ethereum'},
      {'address': '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', 'symbol': 'USDC', 'name': 'USD Coin'},
      {'address': '0xdAC17F958D2ee523a2206206994597C13D831ec7', 'symbol': 'USDT', 'name': 'Tether'},
      {'address': '0x6B175474E89094C44Da98b954EedeAC495271d0F', 'symbol': 'DAI', 'name': 'Dai Stablecoin'},
    ],
    '137': [ // Polygon
      {'address': 'native', 'symbol': 'MATIC', 'name': 'Polygon'},
      {'address': '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174', 'symbol': 'USDC', 'name': 'USD Coin'},
      {'address': '0xc2132D05D31c914a87C6611C10748AEb04B58e8F', 'symbol': 'USDT', 'name': 'Tether'},
      {'address': '0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063', 'symbol': 'DAI', 'name': 'Dai Stablecoin'},
    ],
    '56': [ // BSC
      {'address': 'native', 'symbol': 'BNB', 'name': 'BNB'},
      {'address': '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d', 'symbol': 'USDC', 'name': 'USD Coin'},
      {'address': '0x55d398326f99059fF775485246999027B3197955', 'symbol': 'USDT', 'name': 'Tether'},
      {'address': '0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3', 'symbol': 'DAI', 'name': 'Dai Stablecoin'},
    ],
    '43114': [ // Avalanche
      {'address': 'native', 'symbol': 'AVAX', 'name': 'Avalanche'},
      {'address': '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E', 'symbol': 'USDC', 'name': 'USD Coin'},
      {'address': '0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7', 'symbol': 'USDT', 'name': 'Tether'},
    ],
  };

  /// Generate deposit address for a specific chain and token
  /// Returns deposit address and memo (if needed) for Stellar
  Future<Map<String, dynamic>> generateDepositAddress({
    required String stellarPublicKey,
    required String fromChainId,
    required String fromTokenAddress,
    String? fromTokenSymbol,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Generate unique memo for this deposit
      final memo = _generateDepositMemo(user.uid);

      // Try Allbridge first (supports Stellar directly)
      Map<String, dynamic>? allbridgeQuote;
      String? depositAddress;
      String? depositMemo = memo;
      
      try {
        // Use getter to ensure client is properly initialized
        final client = allbridgeClient;
        allbridgeQuote = await client.getQuote(
          fromChainId: fromChainId,
          toChainId: BridgeConfig.stellarChainId,
          fromTokenAddress: fromTokenAddress,
          toTokenAddress: 'native', // XLM on Stellar
          amount: '1000000000000000000', // 1 token (18 decimals for most ERC-20)
          recipientAddress: stellarPublicKey,
        );

        if (allbridgeQuote['success'] == true) {
          depositAddress = allbridgeQuote['depositAddress'] as String?;
          
          // Get Stellar memo from Allbridge if needed
          final stellarMemo = await allbridgeClient.getStellarMemo(
            recipientAddress: stellarPublicKey,
            fromChainId: fromChainId,
            fromTokenAddress: fromTokenAddress,
          );
          if (stellarMemo != null) {
            depositMemo = stellarMemo;
          }
        } else {
        }
      } catch (e, stackTrace) {
        // Fallback to LI.FI if Allbridge fails
        allbridgeQuote = null;
      }

      // Fallback to LI.FI if Allbridge didn't work
      if (depositAddress == null) {
        try {
          
          final quoteRequest = bridge_models.QuoteRequest(
            fromChain: fromChainId,
            toChain: BridgeConfig.stellarChainId,
            fromToken: fromTokenAddress,
            toToken: 'native',
            fromAmount: '1000000000000000000',
            fromAddress: '0x0000000000000000000000000000000000000000',
            toAddress: stellarPublicKey,
          );

          try {
            // Use getter to ensure client is properly initialized
            final client = lifiClient;
            final routes = await client.getQuote(quoteRequest);

            if (routes.isNotEmpty) {
              final route = routes.first;
              
              if (route.steps.isNotEmpty) {
                final firstStep = route.steps.first;
                
                if (firstStep.transactionRequest != null) {
                  depositAddress = firstStep.transactionRequest!['depositAddress'] as String?;
                }
                
                if (depositAddress == null) {
                  depositAddress = firstStep.action.to?.address;
                }
              }
            }
          } catch (lifiError, lifiStack) {
            // Re-throw with more context
            throw Exception('LI.FI getQuote failed: $lifiError');
          }
        } catch (e, stackTrace) {
          // Check for specific error types and provide helpful messages
          
          final errorString = e.toString();
          if (errorString.contains('404') || errorString.contains('Not Found')) {
          } else if (errorString.contains('429') || errorString.contains('Rate limit')) {
          } else if (errorString.contains('undefined') || errorString.contains('getQuote')) {
            try {
            } catch (e2) {
            }
          } else {
          }
          // Don't re-throw here, allow the function to continue and return a helpful error
        }
      }

      if (depositAddress == null || depositAddress.isEmpty) {
        // Provide more helpful error message
        final errorMessage = StringBuffer(
          'Unable to generate deposit address for ${fromTokenSymbol ?? fromTokenAddress} on chain $fromChainId.\n\n'
        );
        
        errorMessage.write('Possible reasons:\n');
        errorMessage.write('• The token may not be supported for cross-chain transfers to Stellar\n');
        errorMessage.write('• The bridge service (Allbridge/LI.FI) may be temporarily unavailable\n');
        errorMessage.write('• LI.FI API may not support Stellar network (404 error)\n');
        errorMessage.write('• Rate limits may have been exceeded (429 error)\n\n');
        errorMessage.write('Please try again later or contact support if the issue persists.');
        
        throw Exception(errorMessage.toString());
      }

      // Store deposit mapping in Firestore
      final routeId = allbridgeQuote != null 
          ? 'allbridge_${DateTime.now().millisecondsSinceEpoch}'
          : 'lifi_${DateTime.now().millisecondsSinceEpoch}';
      
      await _storeDepositMapping(
        userId: user.uid,
        stellarPublicKey: stellarPublicKey,
        fromChainId: fromChainId,
        fromTokenAddress: fromTokenAddress,
        fromTokenSymbol: fromTokenSymbol ?? 'UNKNOWN',
        depositAddress: depositAddress,
        memo: depositMemo ?? memo,
        routeId: routeId,
      );

      // Calculate estimated time and fees
      int estimatedTime = 15; // Default 15 minutes
      double? feeEstimate;
      
      if (allbridgeQuote != null) {
        // Use Allbridge quote data
        final fee = allbridgeQuote['fee'] as String?;
        if (fee != null) {
          feeEstimate = double.tryParse(fee);
        }
        estimatedTime = 10; // Allbridge typically faster
      }

      return {
        'success': true,
        'depositAddress': depositAddress,
        'memo': depositMemo ?? memo,
        'routeId': routeId,
        'estimatedTime': estimatedTime,
        'feeEstimate': feeEstimate,
        'provider': allbridgeQuote != null ? 'allbridge' : 'lifi',
        'toAmount': allbridgeQuote?['toAmount'],
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get all deposit addresses for a user's Stellar wallet
  Future<Map<String, dynamic>> getAllDepositAddresses(String stellarPublicKey) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final Map<String, Map<String, dynamic>> addresses = {};
      int successCount = 0;
      int failureCount = 0;

      // Generate addresses for common tokens on each chain
      for (final chain in supportedChains) {
        final chainId = chain['id']!;
        final chainName = chain['name']!;
        final tokens = commonTokens[chainId] ?? [];

        addresses[chainId] = {
          'chainName': chainName,
          'chainSymbol': chain['symbol'],
          'tokens': <Map<String, dynamic>>[],
        };

        for (final token in tokens) {
          try {
            final result = await generateDepositAddress(
              stellarPublicKey: stellarPublicKey,
              fromChainId: chainId,
              fromTokenAddress: token['address']!,
              fromTokenSymbol: token['symbol'],
            );

            if (result['success'] == true) {
              addresses[chainId]!['tokens'].add({
                'symbol': token['symbol'],
                'name': token['name'],
                'depositAddress': result['depositAddress'],
                'memo': result['memo'],
                'routeId': result['routeId'],
                'estimatedTime': result['estimatedTime'],
                'feeEstimate': result['feeEstimate'],
              });
              successCount++;
            } else {
              failureCount++;
            }
          } catch (e) {
            // Skip tokens that fail, continue with others
            failureCount++;
          }
        }
      }

      // If all failed, return a helpful error
      if (successCount == 0 && failureCount > 0) {
        return {
          'success': false,
          'error': 'Unable to generate deposit addresses. '
              'The bridge services (Allbridge/LI.FI) may not support Stellar network, '
              'the API endpoints may have changed, or rate limits may have been exceeded. '
              'Please try again later or contact support.',
          'addresses': addresses,
        };
      }

      return {
        'success': true,
        'addresses': addresses,
        'note': failureCount > 0 
            ? 'Some tokens could not be bridged. Only available routes are shown.'
            : null,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get deposit status for a specific deposit
  Future<Map<String, dynamic>> getDepositStatus(String routeId) async {
    try {
      // Determine which client to use based on routeId prefix
      if (routeId.startsWith('allbridge_')) {
        // Extract transaction hash from routeId if available
        final txHash = routeId.substring('allbridge_'.length);
        final status = await allbridgeClient.getTransactionStatus(txHash, '');
        return {
          'success': true,
          'status': status,
        };
      } else if (routeId.startsWith('lifi_')) {
        try {
          final status = await lifiClient.getStatus(routeId);
          return {
            'success': true,
            'status': status,
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'LI.FI status check failed: $e',
          };
        }
      } else {
        // Default to LI.FI for backward compatibility
        try {
          final status = await lifiClient.getStatus(routeId);
          return {
            'success': true,
            'status': status,
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'LI.FI status check failed: $e',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Store deposit mapping in Firestore
  Future<void> _storeDepositMapping({
    required String userId,
    required String stellarPublicKey,
    required String fromChainId,
    required String fromTokenAddress,
    required String fromTokenSymbol,
    required String depositAddress,
    required String memo,
    required String routeId,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('deposit_addresses')
          .doc('${fromChainId}_${fromTokenAddress}_${DateTime.now().millisecondsSinceEpoch}')
          .set({
        'stellarPublicKey': stellarPublicKey,
        'fromChainId': fromChainId,
        'fromTokenAddress': fromTokenAddress,
        'fromTokenSymbol': fromTokenSymbol,
        'depositAddress': depositAddress,
        'memo': memo,
        'routeId': routeId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
    }
  }

  /// Generate unique memo for deposit tracking
  String _generateDepositMemo(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    // Stellar memos are max 28 characters
    // Format: U{userIdHash}{timestamp}{random}
    final userIdHash = userId.substring(0, 8);
    return 'U$userIdHash${timestamp.toString().substring(8)}$random';
  }

  /// Get cached deposit addresses from Firestore
  Future<Map<String, dynamic>?> getCachedDepositAddresses(String stellarPublicKey) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('deposit_addresses')
          .where('stellarPublicKey', isEqualTo: stellarPublicKey)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final Map<String, Map<String, dynamic>> addresses = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final chainId = data['fromChainId'] as String;
        final tokenSymbol = data['fromTokenSymbol'] as String;

        if (!addresses.containsKey(chainId)) {
          addresses[chainId] = {
            'chainName': _getChainName(chainId),
            'tokens': <Map<String, dynamic>>[],
          };
        }

        addresses[chainId]!['tokens'].add({
          'symbol': tokenSymbol,
          'depositAddress': data['depositAddress'],
          'memo': data['memo'],
          'routeId': data['routeId'],
          'status': data['status'],
        });
      }

      return {'success': true, 'addresses': addresses};
    } catch (e) {
      return null;
    }
  }

  String _getChainName(String chainId) {
    final chain = supportedChains.firstWhere(
      (c) => c['id'] == chainId,
      orElse: () => {'name': 'Unknown', 'symbol': 'UNK'},
    );
    return chain['name']!;
  }
}

