import 'dart:convert';
import 'package:http/http.dart' as http;
import '../bridge_config.dart';
import '../models/route_models.dart' as bridge_models;

/// LI.FI API client for cross-chain routing
class LifiClient {
  final String baseUrl;
  final Map<String, String>? headers;

  LifiClient({
    String? baseUrl,
    this.headers,
  }) : baseUrl = baseUrl ?? BridgeConfig.lifiBaseUrl;

  /// Get quote for a cross-chain route
  /// Returns list of available routes sorted by best option
  Future<List<bridge_models.BridgeRoute>> getQuote(bridge_models.QuoteRequest request) async {
    try {
      final url = Uri.parse(BridgeConfig.lifiQuoteEndpoint);
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...?headers,
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        // LI.FI returns routes in different formats
        if (data.containsKey('routes')) {
          // Multiple routes returned
          final routes = data['routes'] as List<dynamic>;
          return routes
              .map((r) => bridge_models.BridgeRoute.fromJson(r as Map<String, dynamic>))
              .toList();
        } else if (data.containsKey('id')) {
          // Single route returned
          return [bridge_models.BridgeRoute.fromJson(data)];
        } else {
          throw Exception('Unexpected LI.FI response format: ${response.body}');
        }
      } else {
        final errorBody = response.body;
        throw Exception(
          'LI.FI API error (${response.statusCode}): $errorBody',
        );
      }
    } catch (e) {
      print('❌ Error getting quote from LI.FI: $e');
      rethrow;
    }
  }

  /// Get status of a route execution
  /// Used to poll for route completion
  Future<Map<String, dynamic>> getStatus(String routeId) async {
    try {
      final url = Uri.parse('${BridgeConfig.lifiStatusEndpoint}?routeId=$routeId');
      
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          ...?headers,
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'LI.FI status API error (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Error getting route status from LI.FI: $e');
      rethrow;
    }
  }

  /// Prepare step transaction request
  /// Extracts transaction data from a route step
  Future<bridge_models.TransactionRequest?> prepareStep(
    bridge_models.BridgeRoute route,
    int stepIndex,
  ) async {
    try {
      if (stepIndex >= route.steps.length) {
        throw Exception('Step index out of bounds');
      }

      final step = route.steps[stepIndex];
      
      // Check if step has transactionRequest
      if (step.transactionRequest != null) {
        return bridge_models.TransactionRequest.fromJson(step.transactionRequest!);
      }
      
      // Check if step has transactions array (for EVM)
      if (step.transactions != null && step.transactions!.isNotEmpty) {
        final tx = step.transactions!.first;
        return bridge_models.TransactionRequest(
          type: 'evm',
          to: tx['to'] as String?,
          data: tx['data'] as String?,
          value: tx['value'] as String?,
          chainId: tx['chainId'] as String?,
          gas: tx['gas'] as String?,
          gasPrice: tx['gasPrice'] as String?,
        );
      }
      
      // If no transaction request, check if we need to construct one
      // For Stellar deposits, we might need to construct Payment XDR
      if (step.requiresStellarSigning()) {
        final depositAddress = step.getDepositAddress();
        if (depositAddress != null) {
          // Return a marker that we need to construct XDR
          return bridge_models.TransactionRequest(
            type: 'stellar_construct',
            additionalData: {
              'depositAddress': depositAddress,
              'amount': step.action.amount ?? step.estimate.fromAmount,
              'asset': step.action.from.symbol,
            },
          );
        }
      }
      
      return null;
    } catch (e) {
      print('❌ Error preparing step: $e');
      rethrow;
    }
  }

  /// Execute a route (submit signed transactions)
  /// This is called after user signs transactions
  Future<Map<String, dynamic>> executeRoute(
    String routeId,
    Map<String, dynamic> executionData,
  ) async {
    try {
      final url = Uri.parse(BridgeConfig.lifiExecuteEndpoint);
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...?headers,
        },
        body: jsonEncode({
          'routeId': routeId,
          ...executionData,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'LI.FI execute API error (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Error executing route: $e');
      rethrow;
    }
  }

  /// Get supported tokens for a chain
  Future<List<bridge_models.Token>> getSupportedTokens(String chainId) async {
    try {
      // LI.FI doesn't have a direct tokens endpoint in v1
      // This would typically come from their token list API
      // For now, return common tokens
      final commonTokens = <bridge_models.Token>[];
      
      // Add native tokens
      if (chainId == BridgeConfig.stellarChainId) {
        commonTokens.addAll([
          bridge_models.Token(
            address: 'native',
            symbol: 'XLM',
            decimals: 7,
            chainId: chainId,
            name: 'Stellar Lumens',
          ),
          bridge_models.Token(
            address: 'GAXGCEV2XGCUORUWQ4B2NTRVLKUVDCOQT2EL5C3GY3X72LFR2G3QKSKW',
            symbol: 'AKOFA',
            decimals: 7,
            chainId: chainId,
            name: 'AKOFA Token',
          ),
        ]);
      } else {
        // EVM chains - common tokens
        commonTokens.addAll([
          bridge_models.Token(
            address: 'native',
            symbol: chainId == BridgeConfig.polygonChainId ? 'MATIC' : 'ETH',
            decimals: 18,
            chainId: chainId,
            name: chainId == BridgeConfig.polygonChainId
                ? 'Polygon'
                : 'Ethereum',
          ),
          bridge_models.Token(
            address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', // USDC
            symbol: 'USDC',
            decimals: 6,
            chainId: chainId,
            name: 'USD Coin',
          ),
          bridge_models.Token(
            address: '0xdAC17F958D2ee523a2206206994597C13D831ec7', // USDT
            symbol: 'USDT',
            decimals: 6,
            chainId: chainId,
            name: 'Tether USD',
          ),
        ]);
      }
      
      return commonTokens;
    } catch (e) {
      print('❌ Error getting supported tokens: $e');
      return [];
    }
  }
}

