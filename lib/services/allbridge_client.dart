import 'dart:convert';
import 'package:http/http.dart' as http;
import '../bridge/bridge_config.dart';

/// Allbridge API client for cross-chain transfers to/from Stellar
/// Allbridge supports Stellar network directly
class AllbridgeClient {
  final String baseUrl;
  final bool useTestnet;

  AllbridgeClient({
    String? baseUrl,
    bool? useTestnet,
  })  : baseUrl = baseUrl ?? BridgeConfig.allbridgeApiUrl,
        useTestnet = useTestnet ?? BridgeConfig.useTestnet;

  /// Get supported chains
  Future<List<Map<String, dynamic>>> getSupportedChains() async {
    try {
      // Try the info endpoint
      final url = Uri.parse('$baseUrl/info');
      
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Allbridge API might return chains directly or in a nested structure
        List<dynamic> chains;
        if (responseData is Map<String, dynamic>) {
          final data = responseData;
          if (data.containsKey('chains')) {
            chains = data['chains'] as List<dynamic>? ?? [];
          } else {
            // Try to find chains in the response
            chains = [];
            data.forEach((key, value) {
              if (value is List) {
                chains = value;
              }
            });
          }
        } else if (responseData is List) {
          chains = responseData;
        } else {
          // Return empty list if we can't parse the response
          chains = [];
        }
        
        return chains.map((chain) {
          if (chain is Map<String, dynamic>) {
            return chain;
          } else {
            return {'chain': chain.toString()};
          }
        }).toList();
      } else {
        throw Exception('Allbridge API error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      // Return empty list instead of throwing to allow graceful degradation
      return [];
    }
  }

  /// Get tokens available for a specific chain
  Future<List<Map<String, dynamic>>> getChainTokens(String chainId) async {
    try {
      final url = Uri.parse('$baseUrl/info');
      
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final chains = data['chains'] as List<dynamic>? ?? [];
        
        // Find the chain
        final chain = chains.firstWhere(
          (c) => c['chainId'] == chainId || c['name'] == chainId,
          orElse: () => null,
        );
        
        if (chain == null) {
          return [];
        }
        
        final tokens = chain['tokens'] as List<dynamic>? ?? [];
        return tokens.map((token) => token as Map<String, dynamic>).toList();
      } else {
        throw Exception('Allbridge API error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get quote for cross-chain transfer
  /// Returns deposit address and transaction details
  Future<Map<String, dynamic>> getQuote({
    required String fromChainId,
    required String toChainId,
    required String fromTokenAddress,
    required String toTokenAddress,
    required String amount,
    required String recipientAddress,
  }) async {
    try {
      // Allbridge uses a different endpoint structure
      // We need to get the pool info first, then calculate the quote
      final url = Uri.parse('$baseUrl/info');
      
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
        },
      );

      // Log the actual response for debugging
      if (response.statusCode != 200) {
        throw Exception('Allbridge API error (${response.statusCode}): ${response.body}');
      }

      // Log response structure for debugging (first 500 chars)
      final responsePreview = response.body.length > 500 
          ? '${response.body.substring(0, 500)}...' 
          : response.body;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Handle different response structures
        List<dynamic> chains;
        if (responseData is Map<String, dynamic>) {
          final data = responseData;
          if (data.containsKey('chains')) {
            chains = data['chains'] as List<dynamic>? ?? [];
          } else {
            // Try to extract chains from the response
            chains = [];
            data.forEach((key, value) {
              if (value is List && value.isNotEmpty) {
                final firstItem = value.first;
                if (firstItem is Map && (firstItem as Map).containsKey('chainId')) {
                  chains = value;
                }
              }
            });
          }
        } else if (responseData is List) {
          chains = responseData;
        } else {
          throw Exception('Unexpected Allbridge API response format: ${response.body}');
        }
        
        if (chains.isEmpty) {
          throw Exception('No chains available from Allbridge API. Response: ${response.body}');
        }
        
        // Find source and destination chains
        Map<String, dynamic>? fromChain;
        Map<String, dynamic>? toChain;
        
        for (final chain in chains) {
          final chainMap = chain as Map<String, dynamic>;
          if (_matchesChainId(chainMap, fromChainId)) {
            fromChain = chainMap;
          }
          if (_matchesChainId(chainMap, toChainId)) {
            toChain = chainMap;
          }
        }
        
        if (fromChain == null) {
          // Log available chains for debugging
          final availableChains = chains.map((c) {
            final chainMap = c as Map<String, dynamic>;
            return '${chainMap['chainId'] ?? 'unknown'} (${chainMap['name'] ?? 'unknown'})';
          }).join(', ');
          throw Exception('Source chain $fromChainId not supported by Allbridge. Available: $availableChains');
        }
        
        if (toChain == null) {
          // Log available chains for debugging
          final availableChains = chains.map((c) {
            final chainMap = c as Map<String, dynamic>;
            return '${chainMap['chainId'] ?? 'unknown'} (${chainMap['name'] ?? 'unknown'})';
          }).join(', ');
          throw Exception('Destination chain $toChainId not supported by Allbridge. Available: $availableChains');
        }
        
        // Find tokens
        final fromTokens = fromChain['tokens'] as List<dynamic>? ?? [];
        final toTokens = toChain['tokens'] as List<dynamic>? ?? [];
        
        Map<String, dynamic>? fromToken;
        Map<String, dynamic>? toToken;
        
        for (final token in fromTokens) {
          final tokenMap = token as Map<String, dynamic>;
          if (_matchesTokenAddress(tokenMap, fromTokenAddress)) {
            fromToken = tokenMap;
            break;
          }
        }
        
        for (final token in toTokens) {
          final tokenMap = token as Map<String, dynamic>;
          if (_matchesTokenAddress(tokenMap, toTokenAddress)) {
            toToken = tokenMap;
            break;
          }
        }
        
        if (fromToken == null) {
          // Log available tokens for debugging
          final availableTokens = fromTokens.map((t) {
            final tokenMap = t as Map<String, dynamic>;
            return '${tokenMap['symbol'] ?? 'unknown'} (${tokenMap['address'] ?? 'unknown'})';
          }).join(', ');
          throw Exception('Source token $fromTokenAddress not supported on ${fromChain['name']}. Available: $availableTokens');
        }
        
        if (toToken == null) {
          // Log available tokens for debugging
          final availableTokens = toTokens.map((t) {
            final tokenMap = t as Map<String, dynamic>;
            return '${tokenMap['symbol'] ?? 'unknown'} (${tokenMap['address'] ?? 'unknown'})';
          }).join(', ');
          throw Exception('Destination token $toTokenAddress not supported on ${toChain['name']}. Available: $availableTokens');
        }
        
        // Get pool information for the token pair
        final poolInfo = await _getPoolInfo(
          fromChain['chainId'] as String,
          toChain['chainId'] as String,
          fromToken['poolAddress'] as String? ?? fromToken['address'] as String,
        );
        
        // Calculate estimated output amount
        final inputAmount = BigInt.parse(amount);
        final estimatedOutput = _calculateOutputAmount(
          inputAmount,
          poolInfo,
        );
        
        // Get deposit address
        final depositAddress = await _getDepositAddress(
          fromChain: fromChain,
          toChain: toChain,
          fromToken: fromToken,
          recipientAddress: recipientAddress,
        );
        
        return {
          'success': true,
          'depositAddress': depositAddress,
          'fromAmount': amount,
          'toAmount': estimatedOutput.toString(),
          'fromToken': fromToken,
          'toToken': toToken,
          'fromChain': fromChain,
          'toChain': toChain,
          'fee': poolInfo['fee'] ?? '0',
          'minAmount': poolInfo['minAmount'] ?? '0',
          'maxAmount': poolInfo['maxAmount'] ?? '0',
        };
      } else {
        throw Exception('Allbridge API error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get deposit address for a transfer
  Future<String> _getDepositAddress({
    required Map<String, dynamic> fromChain,
    required Map<String, dynamic> toChain,
    required Map<String, dynamic> fromToken,
    required String recipientAddress,
  }) async {
    try {
      // Allbridge deposit address is typically the bridge contract address
      // Check multiple possible fields where the bridge address might be stored
      
      // Priority 1: Token's bridge address or pool address
      String? depositAddress = fromToken['bridgeAddress'] as String? ??
                              fromToken['poolAddress'] as String? ??
                              fromToken['contractAddress'] as String?;
      
      // Priority 2: Chain's bridge address
      if (depositAddress == null || depositAddress.isEmpty) {
        depositAddress = fromChain['bridgeAddress'] as String? ??
                        fromChain['routerAddress'] as String? ??
                        fromChain['contractAddress'] as String?;
      }
      
      // Priority 3: For Stellar destination, might need special handling
      final isStellarDest = toChain['chainId']?.toString().toLowerCase() == 'stellar' ||
                           toChain['name']?.toString().toLowerCase() == 'stellar';
      
      if (isStellarDest && (depositAddress == null || depositAddress.isEmpty)) {
        // For Stellar, the deposit address might be in a different format
        // Try to get from token metadata
        depositAddress = fromToken['stellarBridgeAddress'] as String? ??
                        fromToken['depositAddress'] as String?;
      }
      
      // If still no address, try to construct from known patterns
      if (depositAddress == null || depositAddress.isEmpty) {
        // Log what we found for debugging
        
        // Try one more fallback: use the token address itself if it's a contract
        // (This is a last resort and might not work, but better than failing completely)
        final tokenAddr = fromToken['address'] as String?;
        if (tokenAddr != null && 
            tokenAddr.isNotEmpty && 
            tokenAddr != 'native' && 
            tokenAddr.startsWith('0x')) {
          depositAddress = tokenAddr;
        } else {
          // Final fallback: throw with detailed error
          throw Exception(
            'Could not determine deposit address. '
            'Allbridge bridge contract address not found in API response. '
            'From chain: ${fromChain['name']} (${fromChain['chainId']}), '
            'From token: ${fromToken['symbol']} (${fromToken['address']}). '
            'Please check Allbridge documentation for bridge addresses.',
          );
        }
      }
      
      return depositAddress;
    } catch (e) {
      rethrow;
    }
  }

  /// Get pool information for a token pair
  Future<Map<String, dynamic>> _getPoolInfo(
    String fromChainId,
    String toChainId,
    String tokenAddress,
  ) async {
    try {
      // Try Allbridge pool info endpoint (if available)
      final url = Uri.parse('$baseUrl/poolInfo?chainFrom=$fromChainId&chainTo=$toChainId&tokenAddress=$tokenAddress');
      
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'fee': data['fee']?.toString() ?? '0.001',
          'minAmount': data['minAmount']?.toString() ?? '1000000',
          'maxAmount': data['maxAmount']?.toString() ?? '1000000000000000000000000',
          'liquidity': data['liquidity'],
          'apy': data['apy'],
        };
      }
    } catch (e) {
    }
    
    // Return default pool info if endpoint doesn't exist or fails
    return {
      'fee': '0.001', // 0.1% default fee
      'minAmount': '1000000', // Minimum amount (1 token with 6 decimals)
      'maxAmount': '1000000000000000000000000', // Maximum amount
    };
  }

  /// Calculate estimated output amount
  String _calculateOutputAmount(
    BigInt inputAmount,
    Map<String, dynamic> poolInfo,
  ) {
    try {
      // Simple calculation: input - fee
      final feePercent = double.tryParse(poolInfo['fee']?.toString() ?? '0.001') ?? 0.001;
      final feeAmount = (inputAmount * BigInt.from((feePercent * 1000).toInt())) ~/ BigInt.from(1000);
      final outputAmount = inputAmount - feeAmount;
      
      return outputAmount.toString();
    } catch (e) {
      // Return input amount if calculation fails
      return inputAmount.toString();
    }
  }

  /// Check if chain matches the given chain ID
  bool _matchesChainId(Map<String, dynamic> chain, String chainId) {
    final chainIdStr = chain['chainId']?.toString() ?? '';
    final nameStr = chain['name']?.toString().toLowerCase() ?? '';
    final chainIdLower = chainId.toLowerCase();
    
    // Try multiple matching strategies
    // 1. Exact match on chainId
    if (chainIdStr == chainId || chainIdStr == chainIdLower) {
      return true;
    }
    
    // 2. Match on name
    if (nameStr == chainIdLower) {
      return true;
    }
    
    // 3. Try converted chain ID
    final convertedId = _convertToAllbridgeChainId(chainId);
    if (chainIdStr == convertedId) {
      return true;
    }
    
    // 4. Special handling for Stellar
    if (chainIdLower == 'stellar' || chainIdLower == 'xlm') {
      return nameStr.contains('stellar') || 
             nameStr.contains('xlm') ||
             chainIdStr.toLowerCase().contains('stellar') ||
             chainIdStr.toLowerCase().contains('xlm');
    }
    
    // 5. Check alternative fields
    final altChainId = chain['id']?.toString() ?? '';
    if (altChainId == chainId || altChainId == chainIdLower) {
      return true;
    }
    
    return false;
  }

  /// Check if token matches the given address
  bool _matchesTokenAddress(Map<String, dynamic> token, String address) {
    final tokenAddress = token['address']?.toString().toLowerCase() ?? '';
    final tokenSymbol = token['symbol']?.toString().toLowerCase() ?? '';
    final addressLower = address.toLowerCase();
    
    // Check if address matches or if it's native token
    if (addressLower == 'native' || addressLower == '0x0000000000000000000000000000000000000000') {
      return token['isNative'] == true || tokenSymbol == 'native';
    }
    
    return tokenAddress == addressLower;
  }

  /// Convert standard chain ID to Allbridge chain ID format
  String _convertToAllbridgeChainId(String chainId) {
    // Allbridge uses different chain ID formats
    switch (chainId) {
      case '1':
      case 'ethereum':
        return '1';
      case '137':
      case 'polygon':
        return '137';
      case '56':
      case 'bsc':
        return '56';
      case '43114':
      case 'avalanche':
        return '43114';
      case 'stellar':
        return 'stellar';
      default:
        return chainId;
    }
  }

  /// Get transaction status
  Future<Map<String, dynamic>> getTransactionStatus(String txHash, String chainId) async {
    try {
      // Allbridge status endpoint (if available)
      final url = Uri.parse('$baseUrl/transactionStatus?txHash=$txHash&chainId=$chainId');
      
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        // Return pending status if endpoint doesn't exist
        return {
          'status': 'pending',
          'txHash': txHash,
        };
      }
    } catch (e) {
      return {
        'status': 'unknown',
        'txHash': txHash,
        'error': e.toString(),
      };
    }
  }

  /// Get Stellar memo for deposit (Allbridge specific)
  Future<String?> getStellarMemo({
    required String recipientAddress,
    required String fromChainId,
    required String fromTokenAddress,
  }) async {
    try {
      // Allbridge may require a memo for Stellar deposits
      // Generate a unique memo based on recipient and token
      final memoData = {
        'recipient': recipientAddress,
        'fromChain': fromChainId,
        'token': fromTokenAddress,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      // Create a hash-based memo (first 28 chars for Stellar memo limit)
      final memoString = jsonEncode(memoData);
      final memoHash = memoString.hashCode.toRadixString(36);
      
      // Stellar memos are max 28 characters
      return memoHash.length > 28 ? memoHash.substring(0, 28) : memoHash;
    } catch (e) {
      return null;
    }
  }
}

