import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'polygon_wallet_service.dart';

/// PesaPal Payment Service for Card Payments
///
/// Enables users to purchase AKOFA tokens using credit/debit cards
/// via the PesaPal payment gateway.
///
/// SETUP REQUIREMENTS:
/// 1. Get PesaPal API credentials from https://developer.pesapal.com
/// 2. Configure PESAPAL_CONSUMER_KEY and PESAPAL_CONSUMER_SECRET
/// 3. Register IPN endpoint in PesaPal dashboard
/// 4. Set BACKEND_BASE_URL to your backend server
class PesapalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Backend base URL for PesaPal proxy
  // Change this to your production URL when deploying
  static const String _backendBaseUrl = String.fromEnvironment(
    'AZIX_BACKEND_API_URL',
    defaultValue: 'https://azix-flutter.vercel.app/api',
  );

  // Minimum and maximum purchase amounts in KES
  static const double MIN_PURCHASE_KES = 100.0; // Minimum 100 KES
  static const double MAX_PURCHASE_KES = 500000.0; // Maximum 500,000 KES (higher for cards)

  /// Token Contract Addresses on Polygon
  static const Map<String, String> tokenContractAddresses = {
    'AKOFA': '0xf1266ACCf0f757c61e4DFDD9EBBcaC05D2Ee375F',
    'USDC': '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359',  // Native USDC on Polygon
    'USDT': '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',  // USDT on Polygon
  };
  
  /// Token decimals (USDC and USDT use 6 decimals, AKOFA uses 18)
  static const Map<String, int> tokenDecimals = {
    'AKOFA': 18,
    'USDC': 6,
    'USDT': 6,
  };
  
  /// Distributor wallet private key (same as mining service - should be in Cloud Functions)
  static const String _distributorPrivateKey = 'af611eb882635606bdad6e91a011e2658d01378a56654d5b554f9f7cb170a863';
  
  /// Get contract address for a token
  static String getContractAddress(String symbol) {
    final address = tokenContractAddresses[symbol.toUpperCase()];
    if (address == null) {
      throw Exception('Unsupported token: $symbol');
    }
    return address;
  }
  
  /// Get decimals for a token
  static int getDecimals(String symbol) {
    return tokenDecimals[symbol.toUpperCase()] ?? 18;
  }

  /// Check if PesaPal service is available
  Future<Map<String, dynamic>> healthCheck() async {
    if (_backendBaseUrl.isEmpty) {
      return {
        'available': false,
        'error': 'Backend URL not configured',
      };
    }

    try {
      final response = await http.get(
        Uri.parse('$_backendBaseUrl/pesapal/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'available': data['status'] == 'ok',
          'environment': data['environment'],
          'hasCredentials': data['hasCredentials'],
          'hasIpnId': data['hasIpnId'],
        };
      }
      return {'available': false, 'error': 'Health check failed'};
    } catch (e) {
      return {'available': false, 'error': e.toString()};
    }
  }

  /// Initiate card payment for token purchase (AKOFA, USDC, or USDT)
  ///
  /// Returns a redirect URL for the user to complete payment on PesaPal's
  /// secure payment page.
  /// 
  /// Parameters:
  /// - [amountKES]: Amount to charge in KES
  /// - [tokenAmount]: Amount of tokens to receive (calculated from locked price)
  /// - [tokenSymbol]: Token to purchase (AKOFA, USDC, USDT)
  /// - [priceLockId]: Optional price lock ID for guaranteed pricing
  /// - [pricePerTokenKES]: Locked price per token in KES
  Future<Map<String, dynamic>> initiateCardPayment({
    required double amountKES,
    required double tokenAmount,
    required String tokenSymbol,
    required String email,
    String? phone,
    String? firstName,
    String? lastName,
    String countryCode = 'KE',
    String currency = 'KES',
    String? description,
    String? priceLockId,
    double? pricePerTokenKES,
  }) async {
    debugPrint('═══════════════════════════════════════════════════════════════');
    debugPrint('💳 [PESAPAL] Initiating Card Payment for $tokenSymbol');
    debugPrint('═══════════════════════════════════════════════════════════════');
    debugPrint('📍 Backend URL: $_backendBaseUrl');
    
    // Validate token symbol
    final upperSymbol = tokenSymbol.toUpperCase();
    if (!tokenContractAddresses.containsKey(upperSymbol)) {
      return {
        'success': false,
        'error': 'Unsupported token: $tokenSymbol. Supported: AKOFA, USDC, USDT',
      };
    }
    
    if (_backendBaseUrl.isEmpty) {
      debugPrint('❌ [PESAPAL] Backend URL is empty!');
      return {
        'success': false,
        'error':
            'PesaPal backend URL not configured. Set BACKEND_BASE_URL.',
      };
    }

    try {
      // Validate amount
      if (amountKES < MIN_PURCHASE_KES) {
        debugPrint('❌ [PESAPAL] Amount too low: $amountKES < $MIN_PURCHASE_KES');
        return {
          'success': false,
          'error': 'Minimum purchase amount is KES ${MIN_PURCHASE_KES.toInt()}',
        };
      }

      if (amountKES > MAX_PURCHASE_KES) {
        debugPrint('❌ [PESAPAL] Amount too high: $amountKES > $MAX_PURCHASE_KES');
        return {
          'success': false,
          'error': 'Maximum purchase amount is KES ${MAX_PURCHASE_KES.toInt()}',
        };
      }

      // Validate email
      if (email.isEmpty || !email.contains('@')) {
        debugPrint('❌ [PESAPAL] Invalid email: $email');
        return {
          'success': false,
          'error': 'Valid email is required for card payments',
        };
      }

      // Get current user
      final currentUser = _auth.currentUser;

      debugPrint('💰 Amount: $amountKES $currency');
      debugPrint('🪙 Token: $tokenAmount $upperSymbol');
      debugPrint('💱 Price/Token: ${pricePerTokenKES?.toStringAsFixed(2) ?? "N/A"} KES');
      debugPrint('🔒 Price Lock: ${priceLockId ?? "None"}');
      debugPrint('📧 Email: $email');
      debugPrint('👤 User ID: ${currentUser?.uid}');

      final body = {
        'amount': amountKES,
        'currency': currency,
        'email': email,
        'phone': phone,
        'firstName': firstName,
        'lastName': lastName,
        'countryCode': countryCode,
        'userId': currentUser?.uid,
        'tokenSymbol': upperSymbol,
        'tokenAmount': tokenAmount,
        'pricePerTokenKES': pricePerTokenKES,
        'priceLockId': priceLockId,
        'description': description ?? 'Purchase $tokenAmount $upperSymbol tokens',
      };

      final apiUrl = '$_backendBaseUrl/pesapal/initiate';
      debugPrint('📤 [PESAPAL] POST $apiUrl');
      debugPrint('📦 [PESAPAL] Request body: ${json.encode(body)}');

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(body),
      );
      
      debugPrint('📥 [PESAPAL] Response status: ${response.statusCode}');
      debugPrint('📥 [PESAPAL] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          debugPrint('✅ [PESAPAL] Payment initiated successfully!');
          debugPrint('🔗 Redirect URL: ${data['redirectUrl']}');
          debugPrint('🆔 Order Tracking ID: ${data['orderTrackingId']}');
          
          // Store transaction in Firestore with token info
          await _recordPesapalTransaction(
            orderTrackingId: data['orderTrackingId'],
            merchantReference: data['merchantReference'],
            amountKES: amountKES,
            tokenAmount: tokenAmount,
            tokenSymbol: upperSymbol,
            pricePerTokenKES: pricePerTokenKES,
            priceLockId: priceLockId,
            currency: currency,
            email: email,
            status: 'pending',
          );

          debugPrint('═══════════════════════════════════════════════════════════════');
          return {
            'success': true,
            'orderTrackingId': data['orderTrackingId'],
            'merchantReference': data['merchantReference'],
            'redirectUrl': data['redirectUrl'],
            'tokenAmount': tokenAmount,
            'tokenSymbol': upperSymbol,
            'amountKES': amountKES,
            'currency': currency,
            'pricePerTokenKES': pricePerTokenKES,
            'message': 'Payment initiated. Complete payment on PesaPal.',
          };
        }

        debugPrint('❌ [PESAPAL] API returned error: ${data['error']}');
        debugPrint('═══════════════════════════════════════════════════════════════');
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to initiate payment',
        };
      }

      debugPrint('❌ [PESAPAL] HTTP error: ${response.statusCode}');
      debugPrint('═══════════════════════════════════════════════════════════════');
      return {
        'success': false,
        'error': 'Payment initiation failed: ${response.statusCode} - ${response.body}',
      };
    } catch (e, stackTrace) {
      debugPrint('❌ [PESAPAL] Exception: $e');
      debugPrint('📋 Stack trace: $stackTrace');
      debugPrint('═══════════════════════════════════════════════════════════════');
      
      // Provide helpful error messages
      String errorMessage = 'Failed to initiate card payment';
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Connection refused')) {
        errorMessage = 'Cannot connect to payment server. Make sure the backend is running on $_backendBaseUrl';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Payment server is not responding. Please try again.';
      }
      
      return {
        'success': false,
        'error': errorMessage,
        'details': e.toString(),
      };
    }
  }

  /// Query payment status
  Future<Map<String, dynamic>> queryPaymentStatus({required String orderTrackingId}) async {
    if (_backendBaseUrl.isEmpty) {
      return {
        'success': false,
        'error': 'Backend URL not configured',
      };
    }

    try {
      debugPrint('🔍 Querying PesaPal payment status: $orderTrackingId');

      final response = await http.post(
        Uri.parse('$_backendBaseUrl/pesapal/query'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'orderTrackingId': orderTrackingId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          // Check if payment is completed
          if (data['isCompleted'] == true) {
            debugPrint('✅ Payment completed: $orderTrackingId');

            // Credit AKOFA tokens to user (via Polygon - same as mining)
            final creditResult = await _creditAkofaTokens(orderTrackingId);
            
            if (creditResult['success'] == true) {
              return {
                'success': true,
                'status': 'completed',
                'confirmationCode': data['confirmationCode'],
                'paymentMethod': data['paymentMethod'],
                'amount': data['amount'],
                'akofaAmount': creditResult['akofaAmount'] ?? data['akofaAmount'],
                'txHash': creditResult['txHash'],
                'explorerUrl': creditResult['explorerUrl'],
                'message': 'Payment successful! ${creditResult['akofaAmount']?.toStringAsFixed(2) ?? ''} AKOFA tokens have been credited to your wallet.',
              };
            } else if (creditResult['alreadyCredited'] == true) {
              return {
                'success': true,
                'status': 'completed',
                'alreadyCredited': true,
                'message': 'Payment was already processed. Tokens were credited earlier.',
              };
            } else if (creditResult['pending'] == true) {
              return {
                'success': true,
                'status': 'pending_wallet',
                'message': creditResult['error'] ?? 'Tokens will be credited when wallet is created.',
              };
            } else {
              return {
                'success': false,
                'status': 'credit_failed',
                'message': 'Payment received but token credit failed: ${creditResult['error']}',
              };
            }
          } else if (data['isFailed'] == true) {
            // Update transaction status to failed
            await _updateTransactionStatus(orderTrackingId, 'failed');

            return {
              'success': false,
              'status': 'failed',
              'message': data['message'] ?? 'Payment failed',
            };
          }

          return {
            'success': true,
            'status': 'pending',
            'message': data['paymentStatusDescription'] ?? 'Payment is being processed',
          };
        }

        return {
          'success': false,
          'error': data['error'] ?? 'Failed to query status',
        };
      }

      return {
        'success': false,
        'error': 'Status query failed: ${response.statusCode}',
      };
    } catch (e) {
      debugPrint('❌ PesaPal status query error: $e');
      return {
        'success': false,
        'error': 'Failed to query payment status: $e',
      };
    }
  }

  /// Credit tokens after successful payment (using Polygon)
  /// 
  /// Supports multiple tokens: AKOFA, USDC, USDT
  /// Uses the same distribution method as the mining service.
  Future<Map<String, dynamic>> _creditTokens(String orderTrackingId) async {
    try {
      debugPrint('═══════════════════════════════════════════════════════════════');
      debugPrint('💰 [PESAPAL] Crediting Tokens');
      debugPrint('═══════════════════════════════════════════════════════════════');
      
      // Get transaction details
      final querySnapshot = await _firestore
          .collection('pesapal_transactions')
          .where('orderTrackingId', isEqualTo: orderTrackingId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint('❌ No PesaPal transaction found: $orderTrackingId');
        return {'success': false, 'error': 'Transaction not found'};
      }

      final transactionDoc = querySnapshot.docs.first;
      final transactionData = transactionDoc.data();

      // Check if already credited
      if (transactionData['status'] == 'credited') {
        debugPrint('⚠️ Transaction already credited: $orderTrackingId');
        return {
          'success': true,
          'alreadyCredited': true,
          'message': 'Tokens were already credited',
        };
      }

      // Get token details (supports multiple tokens)
      final tokenSymbol = (transactionData['tokenSymbol'] as String?) ?? 'AKOFA';
      final tokenAmount = (transactionData['tokenAmount'] as num?)?.toDouble() ?? 
                          (transactionData['akofaAmount'] as num?)?.toDouble() ?? 0.0;
      final userId = transactionData['userId'] as String?;

      if (userId == null || userId.isEmpty) {
        debugPrint('❌ No user ID for transaction: $orderTrackingId');
        return {'success': false, 'error': 'User ID not found'};
      }

      // Get contract address for the token
      final contractAddress = tokenContractAddresses[tokenSymbol.toUpperCase()];
      if (contractAddress == null) {
        debugPrint('❌ Unknown token: $tokenSymbol');
        return {'success': false, 'error': 'Unknown token: $tokenSymbol'};
      }

      debugPrint('📦 Order Tracking ID: $orderTrackingId');
      debugPrint('👤 User ID: $userId');
      debugPrint('🪙 Token: $tokenAmount $tokenSymbol');
      debugPrint('📋 Contract: $contractAddress');

      // Get user's Polygon wallet address
      String? polygonAddress = await _getUserPolygonAddress(userId);

      if (polygonAddress == null || polygonAddress.isEmpty) {
        // Store pending credit for when user creates wallet
        await _storePendingCredit(
          userId: userId,
          tokenAmount: tokenAmount,
          tokenSymbol: tokenSymbol,
          orderTrackingId: orderTrackingId,
        );
        return {
          'success': false,
          'pending': true,
          'error': 'Polygon wallet not found. Tokens will be credited when wallet is created.',
        };
      }

      debugPrint('📍 Polygon Address: $polygonAddress');
      debugPrint('🔄 Sending $tokenAmount $tokenSymbol via Polygon network...');

      // Update status to processing
      await transactionDoc.reference.update({
        'status': 'processing',
        'processingAt': FieldValue.serverTimestamp(),
      });

      // Send tokens via Polygon
      final result = await PolygonWalletService.sendERC20Token(
        tokenContractAddress: contractAddress,
        toAddress: polygonAddress,
        amount: tokenAmount,
        distributorPrivateKey: _distributorPrivateKey,
      );

      if (result['success'] == true) {
        final txHash = result['txHash'] as String?;
        final explorerUrl = result['explorerUrl'] as String?;
        
        debugPrint('✅ Transaction successful!');
        debugPrint('📋 TX Hash: $txHash');
        debugPrint('🔗 Explorer: $explorerUrl');
        
        // Update transaction status with Polygon details
        await transactionDoc.reference.update({
          'status': 'credited',
          'creditedAt': FieldValue.serverTimestamp(),
          'polygonTxHash': txHash,
          'polygonExplorerUrl': explorerUrl,
          'blockchain': 'polygon',
          'tokenContract': contractAddress,
        });

        // Send notification
        await _sendPurchaseNotification(
          userId, 
          tokenAmount, 
          txHash,
          tokenSymbol: tokenSymbol,
        );

        debugPrint('✅ $tokenSymbol tokens credited successfully via Polygon!');
        
        return {
          'success': true,
          'txHash': txHash,
          'explorerUrl': explorerUrl,
          'tokenAmount': tokenAmount,
          'tokenSymbol': tokenSymbol,
          // Legacy field for backward compatibility
          'akofaAmount': tokenSymbol == 'AKOFA' ? tokenAmount : 0.0,
          'message': 'Tokens credited successfully!',
        };
      } else {
        final errorMessage = result['message'] ?? result['error'] ?? 'Unknown error';
        debugPrint('❌ Failed to credit tokens: $errorMessage');
        
        await transactionDoc.reference.update({
          'status': 'credit_failed',
          'creditError': errorMessage,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        return {
          'success': false,
          'error': errorMessage,
        };
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error crediting tokens: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Backward compatibility alias
  Future<Map<String, dynamic>> _creditAkofaTokens(String orderTrackingId) async {
    return _creditTokens(orderTrackingId);
  }
  
  /// Get user's Polygon wallet address (same logic as mining service)
  Future<String?> _getUserPolygonAddress(String userId) async {
    try {
      // First check polygon_wallets collection
      final polygonWalletDoc = await _firestore
          .collection('polygon_wallets')
          .doc(userId)
          .get();

      if (polygonWalletDoc.exists) {
        final data = polygonWalletDoc.data() ?? {};
        final address = data['address'] as String?;
        if (address != null && address.isNotEmpty) {
          debugPrint('📍 Found Polygon address in polygon_wallets: $address');
          return address;
        }
      }

      // Fallback to users collection
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final address = userDoc.data()?['polygonAddress'] as String?;
        if (address != null && address.isNotEmpty) {
          debugPrint('📍 Found Polygon address in users: $address');
          return address;
        }
      }

      // Also check USER collection (case sensitive)
      final userDocUpper = await _firestore.collection('USER').doc(userId).get();
      if (userDocUpper.exists) {
        final address = userDocUpper.data()?['polygonAddress'] as String?;
        if (address != null && address.isNotEmpty) {
          debugPrint('📍 Found Polygon address in USER: $address');
          return address;
        }
      }

      debugPrint('❌ No Polygon address found for user: $userId');
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching Polygon address: $e');
      return null;
    }
  }

  /// Store pending credit for users without wallets (supports multiple tokens)
  Future<void> _storePendingCredit({
    required String userId,
    required double tokenAmount,
    required String tokenSymbol,
    required String orderTrackingId,
  }) async {
    await _firestore.collection('pending_token_credits').add({
      'userId': userId,
      'tokenAmount': tokenAmount,
      'tokenSymbol': tokenSymbol.toUpperCase(),
      'tokenContract': tokenContractAddresses[tokenSymbol.toUpperCase()],
      // Legacy field for backward compatibility
      'akofaAmount': tokenSymbol.toUpperCase() == 'AKOFA' ? tokenAmount : 0.0,
      'orderTrackingId': orderTrackingId,
      'source': 'pesapal_card',
      'reason': 'wallet_not_created',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': DateTime.now().add(const Duration(days: 30)),
    });
    debugPrint('📦 Stored pending credit for user: $userId ($tokenAmount $tokenSymbol)');
  }

  /// Record PesaPal transaction in Firestore (supports multiple tokens)
  Future<DocumentReference> _recordPesapalTransaction({
    required String orderTrackingId,
    required String merchantReference,
    required double amountKES,
    required double tokenAmount,
    required String tokenSymbol,
    double? pricePerTokenKES,
    String? priceLockId,
    required String currency,
    required String email,
    required String status,
  }) async {
    final currentUser = _auth.currentUser;
    final upperSymbol = tokenSymbol.toUpperCase();

    return await _firestore.collection('pesapal_transactions').add({
      'userId': currentUser?.uid,
      'orderTrackingId': orderTrackingId,
      'merchantReference': merchantReference,
      'amountKES': amountKES,
      'tokenAmount': tokenAmount,
      'tokenSymbol': upperSymbol,
      'pricePerTokenKES': pricePerTokenKES,
      'priceLockId': priceLockId,
      // Legacy field for backward compatibility
      'akofaAmount': upperSymbol == 'AKOFA' ? tokenAmount : 0.0,
      'currency': currency,
      'email': email,
      'status': status,
      'paymentMethod': 'card',
      'tokenContract': tokenContractAddresses[upperSymbol],
      'tokenDecimals': tokenDecimals[upperSymbol],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update transaction status
  Future<void> _updateTransactionStatus(
    String orderTrackingId,
    String status,
  ) async {
    final querySnapshot = await _firestore
        .collection('pesapal_transactions')
        .where('orderTrackingId', isEqualTo: orderTrackingId)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      await querySnapshot.docs.first.reference.update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Send purchase notification (supports multiple tokens)
  Future<void> _sendPurchaseNotification(
    String userId,
    double tokenAmount,
    String? txHash, {
    String tokenSymbol = 'AKOFA',
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': 'Card Purchase Successful',
        'message':
            'You have successfully purchased $tokenAmount $tokenSymbol tokens via card!',
        'type': 'purchase',
        'source': 'pesapal_card',
        'tokenSymbol': tokenSymbol,
        'tokenAmount': tokenAmount,
        'polygonTxHash': txHash,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Warning: Failed to send notification: $e');
    }
  }

  /// Get PesaPal transaction history for current user
  Future<List<Map<String, dynamic>>> getTransactionHistory() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      final querySnapshot = await _firestore
          .collection('pesapal_transactions')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting PesaPal history: $e');
      return [];
    }
  }

  /// Get purchase statistics
  Future<Map<String, dynamic>> getPurchaseStats() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return _emptyStats();
      }

      final querySnapshot = await _firestore
          .collection('pesapal_transactions')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      double totalKES = 0;
      double totalAkofa = 0;
      int successfulPurchases = 0;
      int pendingPurchases = 0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final amountKES = data['amountKES'] as double? ?? 0.0;
        final akofaAmount = data['akofaAmount'] as double? ?? 0.0;
        final status = data['status'] as String? ?? 'unknown';

        totalKES += amountKES;
        totalAkofa += akofaAmount;

        if (status == 'credited') {
          successfulPurchases++;
        } else if (status == 'pending') {
          pendingPurchases++;
        }
      }

      return {
        'totalKES': totalKES,
        'totalAkofa': totalAkofa,
        'successfulPurchases': successfulPurchases,
        'pendingPurchases': pendingPurchases,
        'totalTransactions': querySnapshot.docs.length,
      };
    } catch (e) {
      return _emptyStats();
    }
  }

  Map<String, dynamic> _emptyStats() {
    return {
      'totalKES': 0.0,
      'totalAkofa': 0.0,
      'successfulPurchases': 0,
      'pendingPurchases': 0,
      'totalTransactions': 0,
    };
  }

  /// Convert USD to KES (approximate rate)
  static double usdToKes(double usdAmount) {
    const usdToKesRate = 155.0; // Approximate rate
    return usdAmount * usdToKesRate;
  }

  /// Convert KES to AKOFA (100 KES = 1 AKOFA)
  static double kesToAkofa(double kesAmount) {
    const kesToAkofaRate = 0.01;
    return kesAmount * kesToAkofaRate;
  }

  /// Get AKOFA amount for USD
  static double usdToAkofa(double usdAmount) {
    return kesToAkofa(usdToKes(usdAmount));
  }

  /// Clean up resources
  void dispose() {
    // No resources to clean up
  }
}

