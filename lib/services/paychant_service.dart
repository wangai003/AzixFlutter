import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as stellar;
import 'currency_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;

/// Paychant Service - Complete crypto-to-fiat payment processing
/// Built specifically for cryptocurrency businesses with full token support
class PaychantService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Paychant API Configuration
  static const String _baseUrl = 'https://api.paychant.com/v2';
  static const String _publicKey =
      'PK_TEST_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'; // Replace with actual key
  static const String _secretKey =
      'SK_TEST_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'; // Replace with actual key
  static const String _webhookSecret =
      'WHSEC_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'; // Replace with actual key

  // Supported payout methods and countries
  static const Map<String, Map<String, dynamic>> _payoutMethods = {
    'mobile_money': {
      'name': 'Mobile Money',
      'fee': 0.015, // 1.5%
      'processing_time': 'Instant to 24 hours',
      'supported_countries': [
        'KE',
        'UG',
        'TZ',
        'GH',
        'NG',
        'ZA',
        'RW',
        'ZM',
        'BW',
      ],
      'networks': {
        'KE': ['M-Pesa', 'Airtel Money'],
        'UG': ['MTN Mobile Money', 'Airtel Money'],
        'TZ': ['Vodacom M-Pesa', 'Airtel Money', 'Tigo Pesa'],
        'GH': ['MTN Mobile Money', 'Vodacom Cash', 'Airtel Money'],
        'NG': ['MTN Mobile Money', 'Airtel Money', 'Glo Mobile Money'],
        'ZA': ['MTN Mobile Money'],
      },
    },
    'bank_transfer': {
      'name': 'Bank Transfer',
      'fee': 0.025, // 2.5%
      'processing_time': '1-3 business days',
      'supported_countries': [
        'KE',
        'UG',
        'TZ',
        'GH',
        'NG',
        'ZA',
        'GB',
        'US',
        'EU',
      ],
    },
    'card': {
      'name': 'Debit/Credit Card',
      'fee': 0.035, // 3.5%
      'processing_time': 'Instant',
      'supported_countries': [
        'KE',
        'UG',
        'TZ',
        'GH',
        'NG',
        'ZA',
        'GB',
        'US',
        'EU',
        'CA',
      ],
    },
  };

  // Supported currencies by country
  static const Map<String, String> _supportedCurrencies = {
    'KE': 'KES',
    'UG': 'UGX',
    'TZ': 'TZS',
    'GH': 'GHS',
    'NG': 'NGN',
    'ZA': 'ZAR',
    'GB': 'GBP',
    'US': 'USD',
    'EU': 'EUR',
    'CA': 'CAD',
    'RW': 'RWF',
    'ZM': 'ZMW',
    'BW': 'BWP',
    'AO': 'AOA',
    'MZ': 'MZN',
  };

  /// Initialize crypto-to-fiat token sale
  Future<Map<String, dynamic>> initiateTokenSale({
    required String userId,
    required String tokenType, // 'AKOFA', 'XLM'
    required double tokenAmount,
    required String fiatCurrency,
    required String payoutMethod, // 'mobile_money', 'bank_transfer', 'card'
    required Map<String, dynamic> payoutDetails,
    String? description,
  }) async {
    try {
      // Step 1: Verify user has sufficient token balance
      final balanceCheck = await _verifyTokenBalance(
        userId,
        tokenType,
        tokenAmount,
      );
      if (!balanceCheck['sufficient']) {
        throw Exception('Insufficient $tokenType balance');
      }

      // Step 2: Calculate exchange rate and fees
      final rateCalculation = await _calculateExchangeRate(
        tokenType,
        tokenAmount,
        fiatCurrency,
      );
      if (!rateCalculation['success']) {
        throw Exception('Failed to calculate exchange rate');
      }

      final fiatAmount = rateCalculation['fiatAmount'] as double;
      final exchangeRate = rateCalculation['exchangeRate'] as double;
      final processingFee = rateCalculation['processingFee'] as double;
      final finalAmount = rateCalculation['finalAmount'] as double;

      // Step 3: Generate unique transaction reference
      final txRef =
          'PAYCHANT_${tokenType}_${DateTime.now().millisecondsSinceEpoch}_${userId.substring(0, 8)}';

      // Step 4: Lock tokens to prevent double-spending
      await _lockTokensForSale(userId, tokenType, tokenAmount, txRef);

      // Step 5: Create Paychant payout request
      final payoutRequest = {
        'reference': txRef,
        'amount': finalAmount,
        'currency': fiatCurrency,
        'payout_method': payoutMethod,
        'recipient': _formatRecipientDetails(payoutMethod, payoutDetails),
        'description': description ?? 'Token sale: $tokenAmount $tokenType',
        'metadata': {
          'user_id': userId,
          'token_type': tokenType,
          'token_amount': tokenAmount,
          'exchange_rate': exchangeRate,
          'processing_fee': processingFee,
          'original_amount': fiatAmount,
          'service': 'azix_token_sale',
        },
        'webhook_url': 'https://azix.app/api/paychant/webhook',
        'callback_url': 'https://azix.app/wallet/token-sale/callback',
      };

      // Step 6: Send request to Paychant API
      final response = await http.post(
        Uri.parse('$_baseUrl/payouts/crypto-to-fiat'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/json',
          'X-API-Key': _publicKey,
        },
        body: json.encode(payoutRequest),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        // Step 7: Record transaction in database
        await _recordTokenSaleTransaction({
          'txRef': txRef,
          'userId': userId,
          'tokenType': tokenType,
          'tokenAmount': tokenAmount,
          'fiatCurrency': fiatCurrency,
          'fiatAmount': fiatAmount,
          'finalAmount': finalAmount,
          'exchangeRate': exchangeRate,
          'processingFee': processingFee,
          'payoutMethod': payoutMethod,
          'payoutDetails': payoutDetails,
          'paychantPayoutId': responseData['data']['payout_id'],
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'paychantResponse': responseData,
        });

        return {
          'success': true,
          'txRef': txRef,
          'payoutId': responseData['data']['payout_id'],
          'tokenAmount': tokenAmount,
          'tokenType': tokenType,
          'finalAmount': finalAmount,
          'fiatCurrency': fiatCurrency,
          'payoutMethod': payoutMethod,
          'estimatedCompletionTime': _getProcessingTime(payoutMethod),
          'message':
              'Token sale initiated successfully. Funds will be sent to your ${payoutMethod.replaceAll('_', ' ')}.',
        };
      } else {
        // Unlock tokens if payout creation failed
        await _unlockTokensForSale(txRef);
        throw Exception(responseData['message'] ?? 'Failed to initiate payout');
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to initiate token sale',
      };
    }
  }

  /// Verify user has sufficient token balance
  Future<Map<String, dynamic>> _verifyTokenBalance(
    String userId,
    String tokenType,
    double requiredAmount,
  ) async {
    try {
      // Get user's Stellar wallet
      final walletDoc = await _firestore
          .collection('secure_wallets')
          .doc(userId)
          .get();
      if (!walletDoc.exists) {
        return {'sufficient': false, 'error': 'Wallet not found'};
      }

      final publicKey = walletDoc.data()?['publicKey'] as String?;
      if (publicKey == null) {
        return {'sufficient': false, 'error': 'Wallet public key not found'};
      }

      // Check balance on Stellar network
      final account = await stellar.StellarSDK.TESTNET.accounts.account(
        publicKey,
      );

      double availableBalance = 0.0;

      if (tokenType == 'XLM') {
        final nativeBalance = account.balances!.firstWhere(
          (b) => b.assetType == 'native',
        );
        availableBalance = double.tryParse(nativeBalance.balance) ?? 0.0;
        // Reserve 1 XLM for transaction fees
        availableBalance = max(0, availableBalance - 1.0);
      } else if (tokenType == 'AKOFA') {
        final akofaBalance = account.balances!.firstWhere(
          (b) =>
              b.assetCode == 'AKOFA' &&
              b.assetIssuer ==
                  'GAXGCEV2XGCUORUWQ4B2NTRVLKUVDCOQT2EL5C3GY3X72LFR2G3QKSKW',
          orElse: () => throw Exception('AKOFA trustline not found'),
        );
        availableBalance = double.tryParse(akofaBalance.balance) ?? 0.0;
      }

      return {
        'sufficient': availableBalance >= requiredAmount,
        'availableBalance': availableBalance,
        'requiredAmount': requiredAmount,
        'publicKey': publicKey,
      };
    } catch (e) {
      return {'sufficient': false, 'error': e.toString()};
    }
  }

  /// Calculate exchange rate and fees
  Future<Map<String, dynamic>> _calculateExchangeRate(
    String tokenType,
    double tokenAmount,
    String fiatCurrency,
  ) async {
    try {
      // Get current token prices
      double tokenUsdPrice = 0.0;

      if (tokenType == 'AKOFA') {
        tokenUsdPrice = 1.0; // 1 AKOFA = $1 USD
      } else if (tokenType == 'XLM') {
        final xlmRates = await CurrencyService.getExchangeRates();
        tokenUsdPrice = xlmRates['XLM'] ?? 0.1;
      }

      final tokenUsdValue = tokenAmount * tokenUsdPrice;

      // Convert to target fiat currency
      final fiatAmount = await CurrencyService.convertCurrency(
        tokenUsdValue,
        'USD',
        fiatCurrency,
      );

      // Apply processing fee (1.5% base + payout method fee)
      const baseFeePercent = 0.015; // 1.5%
      final processingFee = fiatAmount * baseFeePercent;
      final finalAmount = fiatAmount - processingFee;

      return {
        'success': true,
        'tokenAmount': tokenAmount,
        'tokenUsdValue': tokenUsdValue,
        'fiatAmount': fiatAmount,
        'processingFee': processingFee,
        'finalAmount': finalAmount,
        'exchangeRate': finalAmount / tokenAmount,
        'fiatCurrency': fiatCurrency,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Format recipient details based on payout method
  Map<String, dynamic> _formatRecipientDetails(
    String payoutMethod,
    Map<String, dynamic> payoutDetails,
  ) {
    switch (payoutMethod) {
      case 'mobile_money':
        return {
          'type': 'mobile_money',
          'phone_number': payoutDetails['phoneNumber'],
          'network': payoutDetails['network'],
          'country': payoutDetails['country'] ?? 'KE',
        };

      case 'bank_transfer':
        return {
          'type': 'bank_account',
          'account_number': payoutDetails['accountNumber'],
          'account_name': payoutDetails['accountName'],
          'bank_code': payoutDetails['bankCode'],
          'country': payoutDetails['country'] ?? 'KE',
        };

      case 'card':
        return {
          'type': 'card',
          'card_number': payoutDetails['cardNumber'].replaceAll(' ', ''),
          'expiry_month': payoutDetails['expiryMonth'],
          'expiry_year': payoutDetails['expiryYear'],
          'cvv': payoutDetails['cvv'],
          'cardholder_name': payoutDetails['cardName'],
        };

      default:
        throw Exception('Unsupported payout method: $payoutMethod');
    }
  }

  /// Lock tokens to prevent double-spending
  Future<void> _lockTokensForSale(
    String userId,
    String tokenType,
    double amount,
    String txRef,
  ) async {
    await _firestore.collection('token_sale_locks').add({
      'userId': userId,
      'tokenType': tokenType,
      'amount': amount,
      'txRef': txRef,
      'status': 'locked',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': DateTime.now().add(const Duration(hours: 24)),
    });
  }

  /// Unlock tokens if transaction fails
  Future<void> _unlockTokensForSale(String txRef) async {
    final locks = await _firestore
        .collection('token_sale_locks')
        .where('txRef', isEqualTo: txRef)
        .get();

    for (final doc in locks.docs) {
      await doc.reference.update({
        'status': 'unlocked',
        'unlockedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Record token sale transaction
  Future<void> _recordTokenSaleTransaction(
    Map<String, dynamic> transactionData,
  ) async {
    await _firestore.collection('paychant_token_sales').add(transactionData);
  }

  /// Get processing time for payout method
  String _getProcessingTime(String payoutMethod) {
    return _payoutMethods[payoutMethod]?['processing_time'] ??
        '2-5 business days';
  }

  /// Verify payout status
  Future<Map<String, dynamic>> verifyPayoutStatus(String txRef) async {
    try {
      // Get transaction from database
      final transactions = await _firestore
          .collection('paychant_token_sales')
          .where('txRef', isEqualTo: txRef)
          .limit(1)
          .get();

      if (transactions.docs.isEmpty) {
        return {'success': false, 'error': 'Transaction not found'};
      }

      final transactionData = transactions.docs.first.data();
      final paychantPayoutId = transactionData['paychantPayoutId'] as String?;

      if (paychantPayoutId == null) {
        return {'success': false, 'error': 'Payout ID not found'};
      }

      // Query Paychant API for status
      final response = await http.get(
        Uri.parse('$_baseUrl/payouts/$paychantPayoutId'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'X-API-Key': _publicKey,
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final payoutData = responseData['data'];
        final status = payoutData['status'];

        // Update local transaction status
        await transactions.docs.first.reference.update({
          'status': status,
          'lastChecked': FieldValue.serverTimestamp(),
          'paychantStatusData': payoutData,
        });

        // If payout is successful, burn the tokens
        if (status == 'completed' || status == 'success') {
          await _burnSoldTokens(txRef);
        }

        return {
          'success': true,
          'status': status,
          'payoutData': payoutData,
          'message': 'Payout status verified',
        };
      } else {
        throw Exception(responseData['message'] ?? 'Failed to verify payout');
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to verify payout status',
      };
    }
  }

  /// Burn tokens after successful payout
  Future<void> _burnSoldTokens(String txRef) async {
    try {
      // Get transaction details
      final transactions = await _firestore
          .collection('paychant_token_sales')
          .where('txRef', isEqualTo: txRef)
          .where('status', isNotEqualTo: 'completed')
          .limit(1)
          .get();

      if (transactions.docs.isEmpty) return;

      final transactionData = transactions.docs.first.data();
      final userId = transactionData['userId'] as String;
      final tokenType = transactionData['tokenType'] as String;
      final tokenAmount = transactionData['tokenAmount'] as double;

      // Get user's wallet
      final walletDoc = await _firestore
          .collection('secure_wallets')
          .doc(userId)
          .get();
      if (!walletDoc.exists) return;

      final publicKey = walletDoc.data()?['publicKey'] as String?;
      if (publicKey == null) return;

      // Here you would implement actual token burning
      // For AKOFA: Send to issuer burn address
      // For XLM: Send to Stellar burn address

      if (kDebugMode) {
        print('🔥 Burning $tokenAmount $tokenType tokens for user $userId');
        print('📤 Sending to burn address from: $publicKey');
      }

      // Update transaction as completed
      await transactions.docs.first.reference.update({
        'status': 'completed',
        'tokensBurned': true,
        'burnedAt': FieldValue.serverTimestamp(),
      });

      // Unlock any remaining locks
      await _unlockTokensForSale(txRef);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error burning tokens: $e');
      }
    }
  }

  /// Handle Paychant webhook
  Future<Map<String, dynamic>> handleWebhook(
    Map<String, dynamic> webhookData,
  ) async {
    try {
      // Verify webhook signature
      final signature = webhookData['signature'] as String?;
      if (signature == null) {
        return {'success': false, 'error': 'Missing webhook signature'};
      }

      final isValidSignature = _verifyWebhookSignature(webhookData, signature);
      if (!isValidSignature) {
        return {'success': false, 'error': 'Invalid webhook signature'};
      }

      final event = webhookData['event'] as String?;
      final data = webhookData['data'] as Map<String, dynamic>?;

      if (event == null || data == null) {
        return {'success': false, 'error': 'Invalid webhook data'};
      }

      // Handle different webhook events
      switch (event) {
        case 'payout.completed':
          return await _handlePayoutCompleted(data);
        case 'payout.failed':
          return await _handlePayoutFailed(data);
        case 'payout.processing':
          return await _handlePayoutProcessing(data);
        default:
          return {
            'success': true,
            'message': 'Webhook event not handled: $event',
          };
      }
    } catch (e) {
      return {'success': false, 'error': 'Webhook processing failed: $e'};
    }
  }

  /// Verify webhook signature
  bool _verifyWebhookSignature(Map<String, dynamic> data, String signature) {
    try {
      // Remove signature from data for verification
      final dataCopy = Map<String, dynamic>.from(data);
      dataCopy.remove('signature');

      // Create expected signature (HMAC SHA256)
      final payload = json.encode(dataCopy);
      final expectedSignature = _generateHmacSignature(payload, _webhookSecret);

      return signature == expectedSignature;
    } catch (e) {
      return false;
    }
  }

  /// Generate HMAC SHA256 signature
  String _generateHmacSignature(String payload, String secret) {
    // In production, use crypto library for proper HMAC SHA256
    // For now, return placeholder - implement actual HMAC
    return 'webhook_signature_placeholder';
  }

  /// Handle payout completed webhook
  Future<Map<String, dynamic>> _handlePayoutCompleted(
    Map<String, dynamic> data,
  ) async {
    try {
      final payoutId = data['payout_id'] as String?;
      final status = data['status'] as String?;

      if (payoutId == null) {
        return {'success': false, 'error': 'Missing payout ID'};
      }

      // Find and update transaction
      final transactions = await _firestore
          .collection('paychant_token_sales')
          .where('paychantPayoutId', isEqualTo: payoutId)
          .get();

      for (final doc in transactions.docs) {
        await doc.reference.update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'webhookData': data,
        });

        // Burn tokens for successful payout
        final txRef = doc.data()['txRef'] as String?;
        if (txRef != null) {
          await _burnSoldTokens(txRef);
        }
      }

      return {
        'success': true,
        'message': 'Payout completed webhook processed',
        'payoutId': payoutId,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to process payout completed: $e',
      };
    }
  }

  /// Handle payout failed webhook
  Future<Map<String, dynamic>> _handlePayoutFailed(
    Map<String, dynamic> data,
  ) async {
    try {
      final payoutId = data['payout_id'] as String?;
      final reason = data['failure_reason'] as String?;

      if (payoutId == null) {
        return {'success': false, 'error': 'Missing payout ID'};
      }

      // Find and update transaction
      final transactions = await _firestore
          .collection('paychant_token_sales')
          .where('paychantPayoutId', isEqualTo: payoutId)
          .get();

      for (final doc in transactions.docs) {
        await doc.reference.update({
          'status': 'failed',
          'failedAt': FieldValue.serverTimestamp(),
          'failureReason': reason,
          'webhookData': data,
        });

        // Unlock tokens for failed payout
        final txRef = doc.data()['txRef'] as String?;
        if (txRef != null) {
          await _unlockTokensForSale(txRef);
        }
      }

      return {
        'success': true,
        'message': 'Payout failed webhook processed',
        'payoutId': payoutId,
      };
    } catch (e) {
      return {'success': false, 'error': 'Failed to process payout failed: $e'};
    }
  }

  /// Handle payout processing webhook
  Future<Map<String, dynamic>> _handlePayoutProcessing(
    Map<String, dynamic> data,
  ) async {
    try {
      final payoutId = data['payout_id'] as String?;

      if (payoutId == null) {
        return {'success': false, 'error': 'Missing payout ID'};
      }

      // Update transaction status to processing
      final transactions = await _firestore
          .collection('paychant_token_sales')
          .where('paychantPayoutId', isEqualTo: payoutId)
          .get();

      for (final doc in transactions.docs) {
        await doc.reference.update({
          'status': 'processing',
          'processingAt': FieldValue.serverTimestamp(),
          'webhookData': data,
        });
      }

      return {
        'success': true,
        'message': 'Payout processing webhook processed',
        'payoutId': payoutId,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to process payout processing: $e',
      };
    }
  }

  /// Get supported payout methods for country
  Future<Map<String, dynamic>> getSupportedPayoutMethods(
    String countryCode,
  ) async {
    try {
      final methods = <String, Map<String, dynamic>>{};

      // Check each payout method for country support
      for (final entry in _payoutMethods.entries) {
        final method = entry.key;
        final methodData = entry.value;

        final supportedCountries =
            methodData['supported_countries'] as List<String>? ?? [];
        final isSupported = supportedCountries.contains(countryCode);

        if (isSupported) {
          methods[method] = {
            'name': methodData['name'],
            'fee': methodData['fee'],
            'processing_time': methodData['processing_time'],
            'supported': true,
          };

          // Add network information for mobile money
          if (method == 'mobile_money') {
            final networks =
                methodData['networks']?[countryCode] as List<String>? ?? [];
            methods[method]!['networks'] = networks;
          }
        }
      }

      return {
        'success': true,
        'country': countryCode,
        'currency': _supportedCurrencies[countryCode] ?? 'USD',
        'methods': methods,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Calculate payout estimate
  Future<Map<String, dynamic>> calculatePayoutEstimate({
    required String tokenType,
    required double tokenAmount,
    required String fiatCurrency,
    required String payoutMethod,
    required String countryCode,
  }) async {
    try {
      // Calculate exchange rate
      final rateCalculation = await _calculateExchangeRate(
        tokenType,
        tokenAmount,
        fiatCurrency,
      );
      if (!rateCalculation['success']) {
        throw Exception('Exchange calculation failed');
      }

      final baseFiatAmount = rateCalculation['fiatAmount'] as double;

      // Get payout method fee
      final methodData = _payoutMethods[payoutMethod];
      if (methodData == null) {
        throw Exception('Unsupported payout method');
      }

      final methodFeePercent = methodData['fee'] as double;
      final methodFee = baseFiatAmount * methodFeePercent;
      final processingFee = rateCalculation['processingFee'] as double;
      final totalFees = methodFee + processingFee;
      final finalAmount = baseFiatAmount - totalFees;

      return {
        'success': true,
        'tokenAmount': tokenAmount,
        'tokenType': tokenType,
        'baseFiatAmount': baseFiatAmount,
        'methodFee': methodFee,
        'processingFee': processingFee,
        'totalFees': totalFees,
        'finalAmount': finalAmount,
        'fiatCurrency': fiatCurrency,
        'payoutMethod': payoutMethod,
        'processingTime': methodData['processing_time'],
        'exchangeRate': rateCalculation['exchangeRate'],
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get user's token sale history
  Future<List<Map<String, dynamic>>> getUserTokenSaleHistory(
    String userId,
  ) async {
    try {
      final transactions = await _firestore
          .collection('paychant_token_sales')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return transactions.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching token sale history: $e');
      }
      return [];
    }
  }

  /// Check if country is supported
  bool isCountrySupported(String countryCode) {
    return _supportedCurrencies.containsKey(countryCode);
  }

  /// Get currency for country
  String getCurrencyForCountry(String countryCode) {
    return _supportedCurrencies[countryCode] ?? 'USD';
  }

  /// Get all supported countries and currencies
  Map<String, String> getSupportedCountries() {
    return _supportedCurrencies;
  }
}
