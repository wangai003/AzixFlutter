import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'polygon_wallet_service.dart';

/// Enhanced M-Pesa Service for AKOFA token purchases
///
/// IMPORTANT: This service makes direct API calls to M-Pesa.
/// For web development, use a CORS proxy to bypass browser restrictions.
///
/// SETUP REQUIREMENTS:
/// 1. Get M-Pesa API credentials from Safaricom Developer Portal
/// 2. Configure the following constants with your credentials:
///    - _consumerKey
///    - _consumerSecret
///    - _passKey
///    - _shortCode
///    - _callbackUrl
/// 3. For web development: Set up CORS proxy (see README)
///
/// SECURITY CONSIDERATIONS:
/// - Never expose API credentials in client-side code
/// - Use environment variables or secure configuration
/// - Implement proper error handling and logging
/// - For production, use a backend service to proxy API calls

class EnhancedMpesaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Token Contract Addresses on Polygon (same as mining/pesapal services)
  static const String akofaTokenContractAddress = '0xf1266ACCf0f757c61e4DFDD9EBBcaC05D2Ee375F';
  static const String usdcTokenContractAddress = '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359';
  static const String usdtTokenContractAddress = '0xc2132D05D31c914a87C6611C10748AEb04B58e8F';
  
  /// Map of token symbols to contract addresses
  static const Map<String, String> tokenContractAddresses = {
    'AKOFA': akofaTokenContractAddress,
    'USDC': usdcTokenContractAddress,
    'USDT': usdtTokenContractAddress,
  };
  
  /// Token decimals for display
  static const Map<String, int> tokenDecimals = {
    'AKOFA': 18,
    'USDC': 6,
    'USDT': 6,
  };
  
  /// Distributor wallet private key (same as mining service - should be in Cloud Functions)
  static const String _distributorPrivateKey = 'af611eb882635606bdad6e91a011e2658d01378a56654d5b554f9f7cb170a863';

  // ==================== ENVIRONMENT CONFIGURATION ====================

  /// Toggle between sandbox (testing) and production (live)
  /// Set to false when ready to use real M-Pesa credentials
  static const bool _useSandbox = true; // 🔄 CHANGE TO false FOR PRODUCTION

  /// Backend base URL for M-Pesa proxy (Daraja 3.0)
  /// Change this to your production URL when deploying
  static const String _backendBaseUrl = String.fromEnvironment(
    'AZIX_BACKEND_API_URL',
    defaultValue: 'https://azix-flutter.vercel.app/api',
  );

  /// Enable CORS proxy (auto-enabled on web to avoid browser CORS blocking
  /// when calling Safaricom directly; not used when hitting backend)
  static const bool _forceCorsProxy =
      false; // 🔄 set true to force proxy on mobile/desktop too

  // CORS proxy URL (only used when _useCorsProxyComputed is true)
  static const String _corsProxyUrl = 'http://localhost:8080/';

  // M-Pesa API endpoints (automatically switches based on _useSandbox and _useCorsProxy)
  static bool get _useCorsProxyComputed => kIsWeb || _forceCorsProxy;

  static String get _baseUrl {
    final base = _useSandbox
        ? 'https://sandbox.safaricom.co.ke'
        : 'https://api.safaricom.co.ke';

    return _useCorsProxyComputed ? '$_corsProxyUrl$base' : base;
  }

  static String get _authUrl =>
      '$_baseUrl/oauth/v1/generate?grant_type=client_credentials';
  // Daraja 3.0 uses the /process endpoint (processrequest is deprecated)
  static String get _stkPushUrl => '$_baseUrl/mpesa/stkpush/v1/process';
  static String get _queryUrl => '$_baseUrl/mpesa/stkpushquery/v1/query';
  static String get _b2cUrl => '$_baseUrl/mpesa/b2c/v1/paymentrequest';

  // ==================== SANDBOX CREDENTIALS ====================
  // These are the default sandbox credentials provided by Safaricom
  // They work out-of-the-box for testing - NO CHANGES NEEDED!
  static const String _sandboxConsumerKey =
      'GtX9FWtHQ8wZGKwHvKQ1234567890abcdef';
  static const String _sandboxConsumerSecret =
      'abcDEF1234567890ghijklmnopQRSTUV';
  static const String _sandboxPassKey = 'bfb279f9aa9bdbcf158e97dd71a467cd';
  static const String _sandboxShortCode = '174379';
  static const String _sandboxCallbackUrl =
      'https://yourdomain.com/mpesa/callback';

  // ==================== PRODUCTION CREDENTIALS ====================
  // 🔴 REPLACE THESE WITH YOUR REAL M-PESA CREDENTIALS FROM SAFARICOM PORTAL
  // Get them from: https://developer.safaricom.co.ke/
  static const String _productionConsumerKey =
      'YOUR_REAL_CONSUMER_KEY'; // 🔴 REPLACE
  static const String _productionConsumerSecret =
      'YOUR_REAL_CONSUMER_SECRET'; // 🔴 REPLACE
  static const String _productionPassKey = 'YOUR_REAL_PASS_KEY'; // 🔴 REPLACE
  static const String _productionShortCode =
      'YOUR_REAL_SHORT_CODE'; // 🔴 REPLACE
  static const String _productionCallbackUrl =
      'YOUR_REAL_CALLBACK_URL'; // 🔴 REPLACE

  // ==================== DYNAMIC CREDENTIALS ====================
  // Automatically uses sandbox or production credentials based on _useSandbox
  static String get _consumerKey =>
      _useSandbox ? _sandboxConsumerKey : _productionConsumerKey;
  static String get _consumerSecret =>
      _useSandbox ? _sandboxConsumerSecret : _productionConsumerSecret;
  static String get _passKey =>
      _useSandbox ? _sandboxPassKey : _productionPassKey;
  static String get _shortCode =>
      _useSandbox ? _sandboxShortCode : _productionShortCode;
  static String get _callbackUrl =>
      _useSandbox ? _sandboxCallbackUrl : _productionCallbackUrl;

  // Exchange rates
  static const double KES_TO_AKOFA_RATE = 1 / 5.52; // 1 AKOFA = 5.52 KES
  static const double MIN_PURCHASE_KES = 10.0; // Minimum 10 KES
  static const double MAX_PURCHASE_KES = 50000.0; // Maximum 50,000 KES

  // Sell transaction limits
  static const double MIN_SELL_AKOFA = 100.0; // Minimum 100 AKOFA
  static const double MAX_SELL_AKOFA = 50000.0; // Maximum 50,000 AKOFA

  /// Sell AKOFA tokens for M-Pesa
  Future<Map<String, dynamic>> sellAkofaTokens({
    required String phoneNumber,
    required double akofaAmount,
    String? accountReference,
  }) async {
    try {
      // Validate amount
      if (akofaAmount < MIN_SELL_AKOFA) {
        return {
          'success': false,
          'error': 'Minimum sell amount is $MIN_SELL_AKOFA AKOFA',
        };
      }

      if (akofaAmount > MAX_SELL_AKOFA) {
        return {
          'success': false,
          'error': 'Maximum sell amount is $MAX_SELL_AKOFA AKOFA',
        };
      }

      // Calculate KES amount (reverse of purchase rate)
      final amountKES = akofaAmount / KES_TO_AKOFA_RATE;

      // Format phone number
      final formattedPhone = _formatPhoneNumber(phoneNumber);
      if (formattedPhone == null) {
        return {'success': false, 'error': 'Invalid phone number format'};
      }

      // Generate account reference
      final reference =
          accountReference ??
          'SELL_AKOFA_${DateTime.now().millisecondsSinceEpoch}';

      print('💰 Initiating AKOFA sell: $akofaAmount AKOFA = $amountKES KES');

      // For sell transactions, we need to burn the AKOFA tokens first
      // Then initiate M-Pesa payment to user
      final sellResult = await _processAkofaSell(
        phoneNumber: formattedPhone,
        akofaAmount: akofaAmount,
        amountKES: amountKES,
        accountReference: reference,
      );

      return sellResult;
    } catch (e) {
      return {'success': false, 'error': 'Failed to initiate sell: $e'};
    }
  }

  /// Process AKOFA sell transaction (burn tokens and initiate M-Pesa payment)
  /// NOTE: This functionality is temporarily disabled during Polygon migration
  Future<Map<String, dynamic>> _processAkofaSell({
    required String phoneNumber,
    required double akofaAmount,
    required double amountKES,
    required String accountReference,
  }) async {
    // TODO: Implement Polygon-based sell functionality
    // For now, return not supported error
    return {
      'success': false,
      'error': 'Sell functionality is temporarily unavailable during blockchain migration. Please try again later.',
    };
    
    /* Original Stellar-based implementation - kept for reference
    try {
      print('🔥 Processing AKOFA sell transaction...');

      // Get current user
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      // Get user's Polygon wallet address
      final polygonAddress = await _getUserPolygonAddress(currentUser.uid);
      if (polygonAddress == null || polygonAddress.isEmpty) {
        return {'success': false, 'error': 'No wallet found for user'};
      }

      // Generate a unique transaction ID for M-Pesa payment
      final transactionId = 'SELL_\${DateTime.now().millisecondsSinceEpoch}';

      // Record the sell transaction
      await _recordMpesaSellTransaction(
        phoneNumber: phoneNumber,
        akofaAmount: akofaAmount,
        amountKES: amountKES,
        transactionId: transactionId,
        accountReference: accountReference,
        polygonTxHash: '', // Will be filled after burn
        status: 'processing',
      );

      // Initiate real M-Pesa B2C payment
      final mpesaPaymentResult = await _initiateMpesaB2CPayment(
        phoneNumber: phoneNumber,
        amountKES: amountKES,
        transactionId: transactionId,
        accountReference: accountReference,
      );

      if (mpesaPaymentResult['success'] == true) {
        // Update transaction status to completed
        await _updateMpesaSellTransactionStatus(transactionId, 'completed');

        // Send notification
        await _sendSellNotification(
          currentUser.uid,
          akofaAmount,
          amountKES,
          transactionId,
        );

        return {
          'success': true,
          'transactionId': transactionId,
          'akofaAmount': akofaAmount,
          'amountKES': amountKES,
          'message': 'AKOFA sell transaction completed successfully',
          'stellarHash': burnResult['hash'],
          'mpesaReference': mpesaPaymentResult['mpesaReference'],
        };
      } else {
        // Payment failed, but tokens are already burned
        // This is a critical error - tokens are lost
        await _updateMpesaSellTransactionStatus(
          transactionId,
          'payment_failed',
        );

        return {
          'success': false,
          'error':
              'Tokens burned but M-Pesa payment failed. Contact support immediately.',
          'transactionId': transactionId,
          'stellarHash': burnResult['hash'],
        };
      }
    } catch (e) {
      print('❌ AKOFA sell processing error: $e');
      return {
        'success': false,
        'error': 'Failed to process sell transaction: $e',
      };
    }
    */
  }

  /// Initiate M-Pesa B2C payment (Business to Customer)
  Future<Map<String, dynamic>> _initiateMpesaB2CPayment({
    required String phoneNumber,
    required double amountKES,
    required String transactionId,
    required String accountReference,
  }) async {
    try {
      print(
        '💰 Initiating M-Pesa B2C payment for $amountKES KES to $phoneNumber',
      );

      // Get access token
      final accessToken = await _getAccessToken();

      // Prepare B2C request body
      final body = {
        'InitiatorName': _shortCode, // Use shortcode as initiator for B2C
        'SecurityCredential': _generateSecurityCredential(),
        'CommandID': 'BusinessPayment', // B2C payment
        'Amount': amountKES.round().toString(),
        'PartyA': _shortCode,
        'PartyB': phoneNumber,
        'Remarks': 'AKOFA Token Sell - $transactionId',
        'QueueTimeOutURL': _callbackUrl,
        'ResultURL': _callbackUrl,
        'Occasion': accountReference,
      };

      print('📤 Sending M-Pesa B2C payment request');

      // Make API request to M-Pesa B2C endpoint
      final response = await http.post(
        Uri.parse(_b2cUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(body),
      );

      print('📥 M-Pesa B2C Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ B2C payment initiated successfully');

        // Check response code
        if (data['ResponseCode'] == '0') {
          return {
            'success': true,
            'mpesaReference':
                data['ConversationID'] ?? data['OriginatorConversationID'],
            'responseCode': data['ResponseCode'],
            'responseDescription': data['ResponseDescription'],
          };
        } else {
          print(
            '❌ B2C payment initiation failed: ${data['ResponseDescription']}',
          );
          return {
            'success': false,
            'error': 'B2C payment failed: ${data['ResponseDescription']}',
            'responseCode': data['ResponseCode'],
          };
        }
      } else {
        print(
          '❌ B2C payment request failed: ${response.statusCode} - ${response.body}',
        );
        return {
          'success': false,
          'error':
              'Failed to initiate B2C payment: ${response.statusCode} - ${response.body}',
        };
      }
    } catch (e) {
      print('❌ B2C payment error: $e');

      // Provide helpful error messages for common issues
      if (e.toString().contains('CORS')) {
        print('🚫 CORS Error: Use a CORS proxy for web development');
        print(
          '💡 For B2C payments, you may need to implement this on the backend',
        );
      }

      return {'success': false, 'error': 'Error initiating B2C payment: $e'};
    }
  }

  /// Generate security credential for B2C API
  String _generateSecurityCredential() {
    // In production, this would encrypt the password with the public key
    // For now, return a placeholder
    // This needs to be implemented properly with M-Pesa's public key
    return base64Encode(utf8.encode(_passKey));
  }

  /// Record M-Pesa sell transaction
  Future<DocumentReference> _recordMpesaSellTransaction({
    required String phoneNumber,
    required double akofaAmount,
    required double amountKES,
    required String transactionId,
    required String accountReference,
    required String stellarHash,
    required String status,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('No authenticated user found');
    }

    return await _firestore.collection('mpesa_sell_transactions').add({
      'userId': currentUser.uid,
      'phoneNumber': phoneNumber,
      'akofaAmount': akofaAmount,
      'amountKES': amountKES,
      'transactionId': transactionId,
      'accountReference': accountReference,
      'stellarHash': stellarHash,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Update M-Pesa sell transaction status
  Future<void> _updateMpesaSellTransactionStatus(
    String transactionId,
    String status,
  ) async {
    final querySnapshot = await _firestore
        .collection('mpesa_sell_transactions')
        .where('transactionId', isEqualTo: transactionId)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      await querySnapshot.docs.first.reference.update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Send sell notification to user
  Future<void> _sendSellNotification(
    String userId,
    double akofaAmount,
    double amountKES,
    String transactionId,
  ) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': 'AKOFA Sell Successful',
        'message':
            'You have successfully sold $akofaAmount AKOFA for KES $amountKES!',
        'type': 'sell',
        'transactionId': transactionId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Warning: Failed to send sell notification: $e');
    }
  }

  /// Get M-Pesa sell transaction history
  Future<List<Map<String, dynamic>>> getMpesaSellTransactionHistory() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return [];
      }

      final querySnapshot = await _firestore
          .collection('mpesa_sell_transactions')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get sell statistics
  Future<Map<String, dynamic>> getSellStats() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {
          'totalAkofaSold': 0.0,
          'totalKESReceived': 0.0,
          'successfulSells': 0,
          'pendingSells': 0,
          'totalSells': 0,
        };
      }

      final querySnapshot = await _firestore
          .collection('mpesa_sell_transactions')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      double totalAkofaSold = 0;
      double totalKESReceived = 0;
      int successfulSells = 0;
      int pendingSells = 0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final akofaAmount = data['akofaAmount'] as double? ?? 0.0;
        final amountKES = data['amountKES'] as double? ?? 0.0;
        final status = data['status'] as String? ?? 'unknown';

        totalAkofaSold += akofaAmount;
        totalKESReceived += amountKES;

        if (status == 'completed') {
          successfulSells++;
        } else if (status == 'processing' || status == 'pending') {
          pendingSells++;
        }
      }

      return {
        'totalAkofaSold': totalAkofaSold,
        'totalKESReceived': totalKESReceived,
        'successfulSells': successfulSells,
        'pendingSells': pendingSells,
        'totalSells': querySnapshot.docs.length,
      };
    } catch (e) {
      return {
        'totalAkofaSold': 0.0,
        'totalKESReceived': 0.0,
        'successfulSells': 0,
        'pendingSells': 0,
        'totalSells': 0,
      };
    }
  }

  /// Purchase AKOFA tokens using M-Pesa via backend proxy
  Future<Map<String, dynamic>> purchaseAkofaTokens({
    required String phoneNumber,
    required double amountKES,
    String? accountReference,
  }) async {
    try {
      // Validate amount
      if (amountKES < MIN_PURCHASE_KES) {
        return {
          'success': false,
          'error': 'Minimum purchase amount is KES ${MIN_PURCHASE_KES.toInt()}',
        };
      }

      if (amountKES > MAX_PURCHASE_KES) {
        return {
          'success': false,
          'error': 'Maximum purchase amount is KES ${MAX_PURCHASE_KES.toInt()}',
        };
      }

      // Calculate AKOFA amount
      final akofaAmount = amountKES * KES_TO_AKOFA_RATE;

      // Format phone number
      final formattedPhone = _formatPhoneNumber(phoneNumber);
      if (formattedPhone == null) {
        return {'success': false, 'error': 'Invalid phone number format'};
      }

      // Generate account reference
      final reference =
          accountReference ?? 'AKOFA_${DateTime.now().millisecondsSinceEpoch}';

      print(
        '💰 Initiating AKOFA purchase: $amountKES KES = $akofaAmount AKOFA',
      );

      // Initiate STK Push via backend
      final stkResult = await _initiateBackendStkPush(
        phoneNumber: formattedPhone,
        amountKES: amountKES,
        accountReference: reference,
        akofaAmount: akofaAmount,
      );

      return stkResult;
    } catch (e) {
      return {'success': false, 'error': 'Failed to initiate purchase: $e'};
    }
  }

  /// Initiate STK Push for AKOFA purchase via backend
  Future<Map<String, dynamic>> _initiateBackendStkPush({
    required String phoneNumber,
    required double amountKES,
    required String accountReference,
    required double akofaAmount,
  }) async {
    final body = {
      'phoneNumber': phoneNumber,
      'amountKES': amountKES,
      'accountReference': accountReference,
      'description': 'Purchase of $akofaAmount AKOFA tokens',
    };

    final uri = Uri.parse('$_backendBaseUrl/mpesa/stkpush');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        await _recordMpesaTransaction(
          phoneNumber: phoneNumber,
          amountKES: amountKES,
          akofaAmount: akofaAmount,
          checkoutRequestId: data['checkoutRequestId'],
          accountReference: accountReference,
          status: 'pending',
        );

        return {
          'success': true,
          'checkoutRequestId': data['checkoutRequestId'],
          'responseCode': data['responseCode'],
          'customerMessage': data['customerMessage'],
          'akofaAmount': akofaAmount,
          'amountKES': amountKES,
        };
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Failed to initiate payment',
      };
    }

    return {
      'success': false,
      'error':
          'Failed to initiate payment: ${response.statusCode} - ${response.body}',
    };
  }

  /// Query STK Push status via backend and credit AKOFA tokens if successful
  Future<Map<String, dynamic>> queryPaymentStatus(
    String checkoutRequestId,
  ) async {
    try {
      print('🔍 Querying M-Pesa payment status for: $checkoutRequestId');

      final uri = Uri.parse('$_backendBaseUrl/mpesa/query');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'checkoutRequestId': checkoutRequestId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Payment status query successful');

        if (data['resultCode'] == '0') {
          debugPrint('💰 Payment successful - crediting AKOFA tokens');
          
          // Credit AKOFA tokens (via Polygon - same as mining)
          final creditResult = await _creditAkofaTokens(checkoutRequestId);

          if (creditResult['success'] == true) {
            return {
              'success': true,
              'resultCode': data['resultCode'],
              'resultDesc': data['resultDesc'],
              'status': 'completed',
              'akofaAmount': creditResult['akofaAmount'],
              'txHash': creditResult['txHash'],
              'explorerUrl': creditResult['explorerUrl'],
              'message': 'Payment successful! ${creditResult['akofaAmount']?.toStringAsFixed(2) ?? ''} AKOFA tokens have been credited to your wallet.',
            };
          } else if (creditResult['alreadyCredited'] == true) {
            return {
              'success': true,
              'resultCode': data['resultCode'],
              'resultDesc': data['resultDesc'],
              'status': 'completed',
              'alreadyCredited': true,
              'message': 'Payment was already processed. Tokens were credited earlier.',
            };
          } else if (creditResult['pending'] == true) {
            return {
              'success': true,
              'resultCode': data['resultCode'],
              'resultDesc': data['resultDesc'],
              'status': 'pending_wallet',
              'message': creditResult['error'] ?? 'Tokens will be credited when wallet is created.',
            };
          } else {
            return {
              'success': false,
              'resultCode': data['resultCode'],
              'resultDesc': data['resultDesc'],
              'status': 'credit_failed',
              'message': 'Payment received but token credit failed: ${creditResult['error']}',
            };
          }
        } else {
          await _updateMpesaTransactionStatus(checkoutRequestId, 'failed');

          return {
            'success': false,
            'resultCode': data['resultCode'],
            'resultDesc': data['resultDesc'],
            'status': 'failed',
            'message': data['resultDesc'] ?? 'Payment failed',
          };
        }
      }

      return {
        'success': false,
        'error':
            'Failed to query payment status: ${response.statusCode} - ${response.body}',
      };
    } catch (e) {
      print('❌ Payment status query error: $e');

      // Provide helpful error messages for common issues
      if (e.toString().contains('CORS') ||
          e.toString().contains('Access-Control')) {
        print('🚫 CORS Error: Use a CORS proxy for web development');
        print('💡 QUICK FIX: Run setup script: node setup_cors_proxy.js');
        print('💡 Or manually: npm install -g cors-anywhere && cors-anywhere');
        print('💡 Then set _useCorsProxy = true in your code');
        print('💡 Alternative: Install "Allow CORS" browser extension');
        print('📖 See: FLUTTER_WEB_MPESA_GUIDE.md for complete instructions');
      }

      return {'success': false, 'error': 'Error querying payment status: $e'};
    }
  }

  /// Credit tokens to user's wallet after successful payment (using Polygon - same as mining)
  /// 
  /// This uses the same method as the mining service to send tokens
  /// to the user's derived Polygon wallet. Supports AKOFA, USDC, and USDT.
  Future<Map<String, dynamic>> _creditAkofaTokens(String checkoutRequestId) async {
    try {
      debugPrint('═══════════════════════════════════════════════════════════════');
      debugPrint('💰 [M-PESA] Crediting Tokens');
      debugPrint('═══════════════════════════════════════════════════════════════');
      
      // Get the transaction details
      final querySnapshot = await _firestore
          .collection('mpesa_transactions')
          .where('checkoutRequestId', isEqualTo: checkoutRequestId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint('❌ No M-Pesa transaction found with checkoutRequestId: $checkoutRequestId');
        return {'success': false, 'error': 'Transaction not found'};
      }

      final transactionDoc = querySnapshot.docs.first;
      final transactionData = transactionDoc.data();

      // Check if already credited
      if (transactionData['status'] == 'credited') {
        debugPrint('⚠️ Transaction already credited: $checkoutRequestId');
        return {
          'success': true,
          'alreadyCredited': true,
          'message': 'Tokens were already credited',
        };
      }

      // Get token details - support multi-token (AKOFA, USDC, USDT)
      final tokenSymbol = (transactionData['tokenSymbol'] as String?) ?? 'AKOFA';
      final tokenAmount = (transactionData['tokenAmount'] as num?)?.toDouble() 
          ?? (transactionData['akofaAmount'] as num?)?.toDouble() 
          ?? 0.0;
      
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }
      final userId = transactionData['userId'] ?? currentUser.uid;

      // Get contract address for the token
      final contractAddress = tokenContractAddresses[tokenSymbol.toUpperCase()];
      if (contractAddress == null) {
        debugPrint('❌ Unknown token: $tokenSymbol');
        return {'success': false, 'error': 'Unknown token: $tokenSymbol'};
      }

      debugPrint('📦 Checkout Request ID: $checkoutRequestId');
      debugPrint('👤 User ID: $userId');
      debugPrint('🪙 Token: $tokenAmount $tokenSymbol');
      debugPrint('📋 Contract: $contractAddress');

      // Get user's Polygon wallet address (same as mining)
      String? polygonAddress = await _getUserPolygonAddress(userId);

      if (polygonAddress == null || polygonAddress.isEmpty) {
        // Store pending credit for when user creates wallet
        await _storePendingTokenCredit(
          userId: userId, 
          tokenAmount: tokenAmount, 
          tokenSymbol: tokenSymbol,
          checkoutRequestId: checkoutRequestId,
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

      // Send tokens via Polygon (same method as mining)
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
          'tokenSymbol': tokenSymbol,
        });

        // Send notification
        await _sendPurchaseNotification(userId, tokenAmount, txHash, tokenSymbol: tokenSymbol);

        debugPrint('✅ $tokenSymbol tokens credited successfully via Polygon!');
        
        return {
          'success': true,
          'txHash': txHash,
          'explorerUrl': explorerUrl,
          'tokenAmount': tokenAmount,
          'tokenSymbol': tokenSymbol,
          'akofaAmount': tokenAmount, // backward compatibility
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

  /// Store pending token credit for users without wallets
  /// Supports multi-token (AKOFA, USDC, USDT)
  Future<void> _storePendingTokenCredit({
    required String userId,
    required double tokenAmount,
    required String tokenSymbol,
    required String checkoutRequestId,
  }) async {
    await _firestore.collection('pending_token_credits').add({
      'userId': userId,
      'tokenAmount': tokenAmount,
      'tokenSymbol': tokenSymbol,
      'akofaAmount': tokenAmount, // backward compatibility
      'checkoutRequestId': checkoutRequestId,
      'source': 'mpesa',
      'reason': 'wallet_not_created',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': DateTime.now().add(
        Duration(days: 30),
      ), // Expire after 30 days
    });
  }

  /// Legacy method for backward compatibility
  Future<void> _storePendingAkofaCredit(
    String userId,
    double akofaAmount,
    String checkoutRequestId,
  ) async {
    await _storePendingTokenCredit(
      userId: userId,
      tokenAmount: akofaAmount,
      tokenSymbol: 'AKOFA',
      checkoutRequestId: checkoutRequestId,
    );
  }

  /// Process pending token credits when user creates wallet (using Polygon)
  /// Supports multi-token (AKOFA, USDC, USDT)
  Future<void> processPendingCredits(
    String userId,
    String polygonAddress,
  ) async {
    try {
      debugPrint('🔄 Processing pending credits for user: $userId');
      
      // Check both old and new collections for pending credits
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> allPendingCredits = [];
      
      // Check new pending_token_credits collection
      final tokenCredits = await _firestore
          .collection('pending_token_credits')
          .where('userId', isEqualTo: userId)
          .where('expiresAt', isGreaterThan: DateTime.now())
          .get();
      allPendingCredits.addAll(tokenCredits.docs);
      
      // Also check old pending_akofa_credits for backward compatibility
      final akofaCredits = await _firestore
          .collection('pending_akofa_credits')
          .where('userId', isEqualTo: userId)
          .where('expiresAt', isGreaterThan: DateTime.now())
          .get();
      allPendingCredits.addAll(akofaCredits.docs);

      debugPrint('📦 Found ${allPendingCredits.length} pending credits');

      for (final doc in allPendingCredits) {
        final data = doc.data();
        // Support both old (akofaAmount) and new (tokenAmount/tokenSymbol) formats
        final tokenSymbol = (data['tokenSymbol'] as String?) ?? 'AKOFA';
        final tokenAmount = (data['tokenAmount'] as num?)?.toDouble() 
            ?? (data['akofaAmount'] as num?)?.toDouble() 
            ?? 0.0;
        final checkoutRequestId = data['checkoutRequestId'] as String?;
        final orderTrackingId = data['orderTrackingId'] as String?;
        final source = data['source'] as String? ?? 'mpesa';

        // Get contract address for the token
        final contractAddress = tokenContractAddresses[tokenSymbol.toUpperCase()];
        if (contractAddress == null) {
          debugPrint('❌ Unknown token: $tokenSymbol, skipping...');
          continue;
        }

        debugPrint('💰 Processing pending credit: $tokenAmount $tokenSymbol');

        // Credit the tokens via Polygon
        final result = await PolygonWalletService.sendERC20Token(
          tokenContractAddress: contractAddress,
          toAddress: polygonAddress,
          amount: tokenAmount,
          distributorPrivateKey: _distributorPrivateKey,
        );

        if (result['success'] == true) {
          final txHash = result['txHash'] as String?;
          final explorerUrl = result['explorerUrl'] as String?;
          
          debugPrint('✅ Pending credit processed: $txHash');

          // Update the original transaction based on source
          if (source == 'pesapal_card' && orderTrackingId != null) {
            final pesapalTx = await _firestore
                .collection('pesapal_transactions')
                .where('orderTrackingId', isEqualTo: orderTrackingId)
                .limit(1)
                .get();

            if (pesapalTx.docs.isNotEmpty) {
              await pesapalTx.docs.first.reference.update({
                'status': 'credited',
                'creditedAt': FieldValue.serverTimestamp(),
                'polygonTxHash': txHash,
                'polygonExplorerUrl': explorerUrl,
                'blockchain': 'polygon',
                'tokenSymbol': tokenSymbol,
              });
            }
          } else if (checkoutRequestId != null) {
            // M-Pesa transaction
            final mpesaTx = await _firestore
                .collection('mpesa_transactions')
                .where('checkoutRequestId', isEqualTo: checkoutRequestId)
                .limit(1)
                .get();

            if (mpesaTx.docs.isNotEmpty) {
              await mpesaTx.docs.first.reference.update({
                'status': 'credited',
                'creditedAt': FieldValue.serverTimestamp(),
                'polygonTxHash': txHash,
                'polygonExplorerUrl': explorerUrl,
                'blockchain': 'polygon',
                'tokenSymbol': tokenSymbol,
              });
            }
          }

          // Delete pending credit
          await doc.reference.delete();
          
          // Send notification with token symbol
          await _sendPurchaseNotification(userId, tokenAmount, txHash, tokenSymbol: tokenSymbol);
        } else {
          debugPrint('❌ Failed to process pending credit: ${result['error']}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error processing pending credits: $e');
    }
  }

  /// Send purchase notification to user
  /// Supports multi-token (AKOFA, USDC, USDT)
  Future<void> _sendPurchaseNotification(
    String userId,
    double tokenAmount,
    String? txHash, {
    String tokenSymbol = 'AKOFA',
  }) async {
    try {
      final decimals = tokenSymbol == 'AKOFA' ? 2 : 6;
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': '$tokenSymbol Purchase Successful',
        'message': 'You have successfully purchased ${tokenAmount.toStringAsFixed(decimals)} $tokenSymbol tokens!',
        'type': 'purchase',
        'txHash': txHash,
        'tokenSymbol': tokenSymbol,
        'tokenAmount': tokenAmount,
        'blockchain': 'polygon',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ Failed to send purchase notification: $e');
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Get OAuth token (legacy - kept for compatibility, not used when backend proxy is enabled)
  Future<String> _getAccessToken() async {
    final auth =
        'Basic ${base64Encode(utf8.encode('$_consumerKey:$_consumerSecret'))}';

    try {
      print('🔐 Requesting M-Pesa access token...');

      final response = await http.get(
        Uri.parse(_authUrl),
        headers: {
          'Authorization': auth,
          'Accept': 'application/json',
        },
      );

      print('📥 OAuth Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final accessToken = data['access_token'];
        print('✅ Access token obtained successfully');
        return accessToken;
      } else {
        print(
          '❌ Failed to get access token: ${response.statusCode} - ${response.body}',
        );
        throw Exception(
          'Failed to get access token: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('❌ OAuth Error: $e');

      // Provide helpful error messages for common issues
      if (e.toString().contains('CORS') ||
          e.toString().contains('Access-Control')) {
        print('🚫 CORS Error: Use a CORS proxy for web development');
        print('💡 Solutions:');
        print(
          '   1. Install browser extension: "Allow CORS" or "CORS Unblock"',
        );
        print(
          '   2. Set up local proxy: npm install -g cors-anywhere && cors-anywhere',
        );
        print('   3. Use mobile platform (Android/iOS) for direct API access');
      } else if (e.toString().contains('400')) {
        print('🚫 Authentication Error: Check your Consumer Key and Secret');
        print('💡 Get credentials from: https://developer.safaricom.co.ke/');
      }

      throw Exception('Failed to authenticate with M-Pesa: $e');
    }
  }

  /// Generate timestamp (legacy helper)
  String _generateTimestamp() {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');

    return '$year$month$day$hour$minute$second';
  }

  /// Generate password (legacy helper)
  String _generatePassword(String timestamp) {
    final dataToEncode = '$_shortCode$_passKey$timestamp';
    return base64Encode(utf8.encode(dataToEncode));
  }

  /// Format phone number
  String? _formatPhoneNumber(String phoneNumber) {
    // Remove all non-numeric characters
    phoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Handle different formats
    if (phoneNumber.startsWith('254')) {
      return phoneNumber;
    } else if (phoneNumber.startsWith('0')) {
      return '254${phoneNumber.substring(1)}';
    } else if (phoneNumber.startsWith('+254')) {
      return phoneNumber.substring(1);
    } else if (phoneNumber.length == 9) {
      return '254$phoneNumber';
    }

    return null; // Invalid format
  }

  /// Record M-Pesa transaction
  Future<DocumentReference> _recordMpesaTransaction({
    required String phoneNumber,
    required double amountKES,
    required double akofaAmount,
    required String checkoutRequestId,
    required String accountReference,
    required String status,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('No authenticated user found');
    }
    final String uid = currentUser.uid;

    return await _firestore.collection('mpesa_transactions').add({
      'userId': uid,
      'phoneNumber': phoneNumber,
      'amountKES': amountKES,
      'akofaAmount': akofaAmount,
      'checkoutRequestId': checkoutRequestId,
      'accountReference': accountReference,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Update M-Pesa transaction status
  Future<void> _updateMpesaTransactionStatus(
    String checkoutRequestId,
    String status,
  ) async {
    final querySnapshot = await _firestore
        .collection('mpesa_transactions')
        .where('checkoutRequestId', isEqualTo: checkoutRequestId)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      await querySnapshot.docs.first.reference.update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Get M-Pesa transaction history
  Future<List<Map<String, dynamic>>> getMpesaTransactionHistory() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return [];
      }
      final String uid = currentUser.uid;

      final querySnapshot = await _firestore
          .collection('mpesa_transactions')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get purchase statistics
  Future<Map<String, dynamic>> getPurchaseStats() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {
          'totalKES': 0.0,
          'totalAkofa': 0.0,
          'successfulPurchases': 0,
          'pendingPurchases': 0,
          'totalPurchases': 0,
        };
      }
      final String uid = currentUser.uid;

      final querySnapshot = await _firestore
          .collection('mpesa_transactions')
          .where('userId', isEqualTo: uid)
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
        'totalPurchases': querySnapshot.docs.length,
      };
    } catch (e) {
      return {
        'totalKES': 0.0,
        'totalAkofa': 0.0,
        'successfulPurchases': 0,
        'pendingPurchases': 0,
        'totalPurchases': 0,
      };
    }
  }

  /// Clean up resources
  void dispose() {
    // No resources to clean up - Polygon services are stateless
  }
}

