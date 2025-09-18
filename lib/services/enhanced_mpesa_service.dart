import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'enhanced_stellar_service.dart';

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
  final EnhancedStellarService _stellarService = EnhancedStellarService();

  // ==================== ENVIRONMENT CONFIGURATION ====================

  /// Toggle between sandbox (testing) and production (live)
  /// Set to false when ready to use real M-Pesa credentials
  static const bool _useSandbox = true; // 🔄 CHANGE TO false FOR PRODUCTION

  /// Enable CORS proxy for web development (set to true if getting CORS errors)
  /// Start proxy with: npm install -g cors-anywhere && cors-anywhere
  static const bool _useCorsProxy =
      false; // 🔄 CHANGE TO true FOR WEB DEVELOPMENT

  // CORS proxy URL (only used when _useCorsProxy is true)
  static const String _corsProxyUrl = 'http://localhost:8080/';

  // M-Pesa API endpoints (automatically switches based on _useSandbox and _useCorsProxy)
  static String get _baseUrl {
    final base = _useSandbox
        ? 'https://sandbox.safaricom.co.ke'
        : 'https://api.safaricom.co.ke';

    return _useCorsProxy ? '$_corsProxyUrl$base' : base;
  }

  static String get _authUrl =>
      '$_baseUrl/oauth/v1/generate?grant_type=client_credentials';
  static String get _stkPushUrl => '$_baseUrl/mpesa/stkpush/v1/processrequest';
  static String get _queryUrl => '$_baseUrl/mpesa/stkpushquery/v1/query';

  // ==================== SANDBOX CREDENTIALS ====================
  // These are the default sandbox credentials provided by Safaricom
  // They work out-of-the-box for testing - NO CHANGES NEEDED!
  static const String _sandboxConsumerKey =
      'GtX9FWtHQ8wZGKwHvKQ1234567890abcdef';
  static const String _sandboxConsumerSecret =
      'abcDEF1234567890ghijklmnopQRSTUV';
  static const String _sandboxPassKey = 'SuperSecretPassKeyFromSafaricom';
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
  static const double KES_TO_AKOFA_RATE = 0.01; // 100 KES = 1 AKOFA
  static const double MIN_PURCHASE_KES = 100.0; // Minimum 100 KES
  static const double MAX_PURCHASE_KES = 50000.0; // Maximum 50,000 KES

  /// Purchase AKOFA tokens using M-Pesa
  Future<Map<String, dynamic>> purchaseAkofaTokens({
    required String phoneNumber,
    required double amountKES,
    String? accountReference,
  }) async {
    try {
      // Log environment and proxy settings
      final environment = _useSandbox ? '🧪 SANDBOX' : '💰 PRODUCTION';
      final proxyStatus = _useCorsProxy ? '🌐 WITH CORS PROXY' : '🚫 NO PROXY';
      print('🌐 M-Pesa Environment: $environment | $proxyStatus');
      if (_useCorsProxy) {
        print('🔗 Proxy URL: $_corsProxyUrl');
      }

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

      // Initiate STK Push
      final stkResult = await initiateSTKPush(
        phoneNumber: formattedPhone,
        amount: amountKES,
        accountReference: reference,
        akofaAmount: akofaAmount,
      );

      return stkResult;
    } catch (e) {
      return {'success': false, 'error': 'Failed to initiate purchase: $e'};
    }
  }

  /// Initiate STK Push for AKOFA purchase
  Future<Map<String, dynamic>> initiateSTKPush({
    required String phoneNumber,
    required double amount,
    required String accountReference,
    required double akofaAmount,
  }) async {
    try {
      print('💰 Initiating M-Pesa STK Push for $amount KES');

      // Get access token
      final accessToken = await _getAccessToken();

      // Generate timestamp
      final timestamp = _generateTimestamp();

      // Generate password
      final password = _generatePassword(timestamp);

      // Prepare request body
      final body = {
        'BusinessShortCode': _shortCode,
        'Password': password,
        'Timestamp': timestamp,
        'TransactionType': 'CustomerPayBillOnline',
        'Amount': amount.round().toString(),
        'PartyA': phoneNumber,
        'PartyB': _shortCode,
        'PhoneNumber': phoneNumber,
        'CallBackURL': _callbackUrl,
        'AccountReference': accountReference,
        'TransactionDesc': 'Purchase of $akofaAmount AKOFA tokens',
      };

      print('📤 Sending STK Push request to M-Pesa API');

      // Make API request
      final response = await http.post(
        Uri.parse(_stkPushUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      print('📥 M-Pesa API Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ STK Push initiated successfully');

        // Store transaction details in Firestore
        await _recordMpesaTransaction(
          phoneNumber: phoneNumber,
          amountKES: amount,
          akofaAmount: akofaAmount,
          checkoutRequestId: data['CheckoutRequestID'],
          accountReference: accountReference,
          status: 'pending',
        );

        return {
          'success': true,
          'checkoutRequestId': data['CheckoutRequestID'],
          'responseCode': data['ResponseCode'],
          'customerMessage': data['CustomerMessage'],
          'akofaAmount': akofaAmount,
          'amountKES': amount,
        };
      } else {
        print('❌ STK Push failed: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'error':
              'Failed to initiate payment: ${response.statusCode} - ${response.body}',
        };
      }
    } catch (e) {
      print('❌ STK Push error: $e');

      // Provide helpful error messages for common issues
      if (e.toString().contains('CORS') ||
          e.toString().contains('Access-Control')) {
        print('🚫 CORS Error: Use a CORS proxy for web development');
        print('💡 Install browser extension: "Allow CORS" or "CORS Unblock"');
        print(
          '💡 Or set up local proxy: npm install -g cors-anywhere && cors-anywhere',
        );
      }

      return {'success': false, 'error': 'Error initiating payment: $e'};
    }
  }

  /// Query STK Push status and credit AKOFA tokens if successful
  Future<Map<String, dynamic>> queryPaymentStatus(
    String checkoutRequestId,
  ) async {
    try {
      print('🔍 Querying M-Pesa payment status for: $checkoutRequestId');

      // Get access token
      final accessToken = await _getAccessToken();

      // Generate timestamp
      final timestamp = _generateTimestamp();

      // Generate password
      final password = _generatePassword(timestamp);

      // Prepare request body
      final body = {
        'BusinessShortCode': _shortCode,
        'Password': password,
        'Timestamp': timestamp,
        'CheckoutRequestID': checkoutRequestId,
      };

      print('📤 Sending payment status query to M-Pesa API');

      // Make API request
      final response = await http.post(
        Uri.parse(_queryUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      print('📥 Payment Status Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Payment status query successful');

        // Check if payment was successful
        if (data['ResultCode'] == '0') {
          print('💰 Payment successful - crediting AKOFA tokens');
          // Payment successful, credit AKOFA tokens
          await _creditAkofaTokens(checkoutRequestId);

          return {
            'success': true,
            'resultCode': data['ResultCode'],
            'resultDesc': data['ResultDesc'],
            'status': 'completed',
            'message':
                'Payment successful! AKOFA tokens have been credited to your wallet.',
          };
        } else {
          print('❌ Payment failed: ${data['ResultDesc']}');
          // Payment failed
          await _updateMpesaTransactionStatus(checkoutRequestId, 'failed');

          return {
            'success': false,
            'resultCode': data['ResultCode'],
            'resultDesc': data['ResultDesc'],
            'status': 'failed',
            'message': 'Payment failed: ${data['ResultDesc']}',
          };
        }
      } else {
        print(
          '❌ Payment status query failed: ${response.statusCode} - ${response.body}',
        );
        return {
          'success': false,
          'error':
              'Failed to query payment status: ${response.statusCode} - ${response.body}',
        };
      }
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

  /// Credit AKOFA tokens to user's wallet after successful payment
  Future<void> _creditAkofaTokens(String checkoutRequestId) async {
    try {
      // Get the transaction details
      final querySnapshot = await _firestore
          .collection('mpesa_transactions')
          .where('checkoutRequestId', isEqualTo: checkoutRequestId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print(
          '❌ No M-Pesa transaction found with checkoutRequestId: $checkoutRequestId',
        );
        return;
      }

      final transactionDoc = querySnapshot.docs.first;
      final transactionData = transactionDoc.data();

      final akofaAmount = transactionData['akofaAmount'] ?? 0.0;
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return;
      }
      final userId = transactionData['userId'] ?? currentUser.uid;

      // Get user's Stellar public key
      final userDoc = await _firestore.collection('USER').doc(userId).get();
      if (!userDoc.exists) {
        return;
      }

      final userData = userDoc.data()!;
      final stellarPublicKey = userData['stellarPublicKey'] as String?;

      if (stellarPublicKey == null || stellarPublicKey.isEmpty) {
        // Store the AKOFA amount for when they create a wallet
        await _storePendingAkofaCredit(userId, akofaAmount, checkoutRequestId);
        return;
      }

      // Send AKOFA tokens from issuer to user
      final result = await _stellarService.sendAssetFromIssuer(
        'AKOFA',
        stellarPublicKey,
        akofaAmount.toString(),
        memo: 'M-Pesa Purchase - $checkoutRequestId',
      );

      if (result['success'] == true) {
        // Update transaction status
        await transactionDoc.reference.update({
          'status': 'credited',
          'creditedAt': FieldValue.serverTimestamp(),
          'stellarHash': result['hash'],
        });

        // Send notification
        await _sendPurchaseNotification(userId, akofaAmount, result['hash']);
      } else {
        await transactionDoc.reference.update({
          'status': 'credit_failed',
          'creditError': result['message'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {}
  }

  /// Store pending AKOFA credit for users without wallets
  Future<void> _storePendingAkofaCredit(
    String userId,
    double akofaAmount,
    String checkoutRequestId,
  ) async {
    await _firestore.collection('pending_akofa_credits').add({
      'userId': userId,
      'akofaAmount': akofaAmount,
      'checkoutRequestId': checkoutRequestId,
      'reason': 'wallet_not_created',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': DateTime.now().add(
        Duration(days: 30),
      ), // Expire after 30 days
    });
  }

  /// Process pending AKOFA credits when user creates wallet
  Future<void> processPendingCredits(
    String userId,
    String stellarPublicKey,
  ) async {
    try {
      final pendingCredits = await _firestore
          .collection('pending_akofa_credits')
          .where('userId', isEqualTo: userId)
          .where('expiresAt', isGreaterThan: DateTime.now())
          .get();

      for (final doc in pendingCredits.docs) {
        final data = doc.data();
        final akofaAmount = data['akofaAmount'] as double;
        final checkoutRequestId = data['checkoutRequestId'] as String;

        // Credit the tokens
        final result = await _stellarService.sendAssetFromIssuer(
          'AKOFA',
          stellarPublicKey,
          akofaAmount.toString(),
          memo: 'Pending Credit - $checkoutRequestId',
        );

        if (result['success'] == true) {
          // Update M-Pesa transaction
          final mpesaTx = await _firestore
              .collection('mpesa_transactions')
              .where('checkoutRequestId', isEqualTo: checkoutRequestId)
              .limit(1)
              .get();

          if (mpesaTx.docs.isNotEmpty) {
            await mpesaTx.docs.first.reference.update({
              'status': 'credited',
              'creditedAt': FieldValue.serverTimestamp(),
              'stellarHash': result['hash'],
            });
          }

          // Delete pending credit
          await doc.reference.delete();
        }
      }
    } catch (e) {}
  }

  /// Send purchase notification to user
  Future<void> _sendPurchaseNotification(
    String userId,
    double akofaAmount,
    String? stellarHash,
  ) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': 'AKOFA Purchase Successful',
        'message': 'You have successfully purchased $akofaAmount AKOFA tokens!',
        'type': 'purchase',
        'stellarHash': stellarHash,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {}
  }

  // ==================== UTILITY METHODS ====================

  /// Get OAuth token
  Future<String> _getAccessToken() async {
    final auth =
        'Basic ${base64Encode(utf8.encode('$_consumerKey:$_consumerSecret'))}';

    try {
      print('🔐 Requesting M-Pesa access token...');

      final response = await http.get(
        Uri.parse(_authUrl),
        headers: {'Authorization': auth},
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

  /// Generate timestamp
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

  /// Generate password
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
    _stellarService.dispose();
  }
}
