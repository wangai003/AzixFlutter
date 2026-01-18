import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service to call Express.js backend for TRUE gasless transactions
/// Backend uses Biconomy SDK for actual sponsorship
/// Authentication: Wallet-based (no Firebase required!)
class BiconomyBackendService {
  // Backend server URL - UPDATE THIS to your deployed backend!
  static const String _backendUrl = 'http://localhost:3000';
  // For production: 'https://your-backend.herokuapp.com'
  // For mobile testing: 'http://YOUR_IP_ADDRESS:3000'
  
  /// Send gasless ERC-20 transaction via backend relay
  /// 
  /// User signs transaction with their wallet (their tokens)
  /// Backend relays it and pays the gas fee
  /// 
  /// Sustainable: Backend only needs MATIC, not every token type
  static Future<Map<String, dynamic>> sendGaslessTransaction({
    required String signedTransaction,
    required String userAddress,
  }) async {
    try {
      print('🚀 [BACKEND] Relaying signed transaction...');
      print('👤 User: ${userAddress.substring(0, 10)}...');
      print('💫 Mode: Backend Relay (user tokens, backend pays gas)');
      
      // Call backend API with signed transaction
      final response = await http.post(
        Uri.parse('$_backendUrl/api/gasless/send-token'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'signedTransaction': signedTransaction,
          'userAddress': userAddress,
        }),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Request timeout - backend took too long to respond');
        },
      );
      
      print('📥 [BACKEND] Response status: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        print('✅ [BACKEND] Sponsored gasless transaction successful!');
        print('💰 User paid: \$0.00 (fully sponsored by Biconomy)');
        
        return {
          'success': true,
          'txHash': data['txHash'],
          'transaction': data['transaction'],
          'isGasless': true,
          'sponsored': true,
          'gasPaymentMethod': 'Biconomy MEE Sponsorship',
          'userPaidUSD': '0.00',
          'message': data['message'],
        };
      } else {
        final error = json.decode(response.body);
        print('❌ [BACKEND] Transaction failed: ${error['error']}');
        
        return {
          'success': false,
          'error': error['error'] ?? 'Unknown error',
          'details': error['details'],
        };
      }
    } catch (e, stackTrace) {
      print('❌ [BACKEND] Error calling backend: $e');
      print('Stack trace: $stackTrace');
      
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to communicate with backend server',
      };
    }
  }
  
  /// Estimate gas cost (shows that user pays $0)
  static Future<Map<String, dynamic>> estimateGas({
    required String tokenAddress,
    required String toAddress,
    required double amount,
    required String userAddress,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/api/gasless/estimate-gas'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'tokenAddress': tokenAddress,
          'toAddress': toAddress,
          'amount': amount.toString(),
          'userAddress': userAddress,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'estimate': data['estimate'],
          'userPays': '0', // Gasless!
          'isGasless': true,
        };
      }
      
      return {
        'success': false,
        'error': 'Failed to estimate gas',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Get transaction status (no authentication required for lookup)
  static Future<Map<String, dynamic>> getTransactionStatus(String txHash) async {
    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/api/gasless/transaction-status/$txHash'),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      
      return {
        'success': false,
        'error': 'Failed to get transaction status',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Check if user is eligible for gasless transactions
  static Future<Map<String, dynamic>> checkEligibility({
    required String userAddress,
    required String tokenAddress,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/api/gasless/check-eligibility'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'userAddress': userAddress,
          'tokenAddress': tokenAddress,
        }),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      
      return {
        'success': false,
        'error': 'Failed to check eligibility',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Health check - verify backend is running
  static Future<bool> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/health'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ [BACKEND] Health check passed: ${data['message']}');
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ [BACKEND] Health check failed: $e');
      return false;
    }
  }

  /// Get smart account address (MEE Sponsorship)
  static Future<Map<String, dynamic>> getSmartAccountAddress() async {
    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/api/sponsorship/smart-account'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      
      return {'success': false, 'error': 'Failed to get smart account address'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Check sponsorship service health
  static Future<Map<String, dynamic>> checkSponsorshipHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/api/sponsorship/health'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      
      return {'success': false, 'error': 'Failed to check sponsorship health'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}

