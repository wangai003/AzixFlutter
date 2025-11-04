import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MoonPayService {
  static const String _baseUrl = 'https://api.moonpay.com';
  static const String _widgetUrl = 'https://buy.moonpay.com';

  // Environment-based API key management
  static String get _apiKey {
    final key = dotenv.env['MOONPAY_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('MOONPAY_API_KEY not found in environment variables');
    }
    return key;
  }

  static String get _secretKey {
    final key = dotenv.env['MOONPAY_SECRET_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('MOONPAY_SECRET_KEY not found in environment variables');
    }
    return key;
  }

  /// Generate MoonPay widget URL for XLM purchases
  static String generateWidgetUrl({
    required String walletAddress,
    required String currencyCode,
    required double baseCurrencyAmount,
    String baseCurrencyCode = 'USD',
    String colorCode = '#FFD700', // Gold color
    String language = 'en',
  }) {
    final params = {
      'apiKey': _apiKey,
      'currencyCode': currencyCode,
      'walletAddress': walletAddress,
      'baseCurrencyCode': baseCurrencyCode,
      'baseCurrencyAmount': baseCurrencyAmount.toString(),
      'colorCode': colorCode,
      'language': language,
      'showWalletAddressForm': 'false',
      'redirectURL': 'azix://wallet',
    };

    final queryString = params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    return '$_widgetUrl?$queryString';
  }

  /// Validate Stellar wallet address format
  static bool isValidStellarAddress(String address) {
    try {
      // Basic Stellar address validation
      if (address.isEmpty) return false;
      if (!address.startsWith('G')) return false;
      if (address.length != 56) return false;

      // Additional checksum validation could be added here
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get supported currencies from MoonPay
  static Future<List<Map<String, dynamic>>> getSupportedCurrencies() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/v3/currencies'),
        headers: {'Authorization': 'Bearer $_apiKey'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Failed to fetch currencies: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching MoonPay currencies: $e');
      return [];
    }
  }

  /// Get exchange rates for XLM
  static Future<Map<String, dynamic>?> getExchangeRate({
    String baseCurrency = 'USD',
    String quoteCurrency = 'XLM',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/v3/currencies/$quoteCurrency/buy_quote'),
        headers: {'Authorization': 'Bearer $_apiKey'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Failed to fetch exchange rate: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching MoonPay exchange rate: $e');
      return null;
    }
  }

  /// Monitor transaction status (webhook alternative)
  static Future<Map<String, dynamic>?> getTransactionStatus(
    String transactionId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/v1/transactions/$transactionId'),
        headers: {'Authorization': 'Bearer $_apiKey'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch transaction: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching transaction status: $e');
      return null;
    }
  }

  /// Get transaction status with enhanced error handling and retry logic
  static Future<Map<String, dynamic>?> getTransactionStatusWithRetry(
    String transactionId, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        final result = await getTransactionStatus(transactionId);
        if (result != null) {
          return result;
        }
        attempts++;
        if (attempts < maxRetries) {
          await Future.delayed(retryDelay * attempts);
        }
      } catch (e) {
        attempts++;
        debugPrint(
          'Attempt $attempts failed for transaction $transactionId: $e',
        );
        if (attempts < maxRetries) {
          await Future.delayed(retryDelay * attempts);
        }
      }
    }
    return null;
  }

  /// Poll transaction status until completion or timeout
  static Future<Map<String, dynamic>?> pollTransactionStatus(
    String transactionId, {
    Duration timeout = const Duration(minutes: 30),
    Duration pollInterval = const Duration(seconds: 10),
  }) async {
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < timeout) {
      try {
        final status = await getTransactionStatus(transactionId);
        if (status != null) {
          final transactionStatus = status['status'];
          if (transactionStatus == 'completed' ||
              transactionStatus == 'failed' ||
              transactionStatus == 'cancelled') {
            return status;
          }
        }
        await Future.delayed(pollInterval);
      } catch (e) {
        debugPrint('Error polling transaction $transactionId: $e');
        await Future.delayed(pollInterval);
      }
    }

    // Timeout reached
    debugPrint('Polling timeout reached for transaction $transactionId');
    return null;
  }

  /// Get multiple transaction statuses in batch
  static Future<List<Map<String, dynamic>>> getBatchTransactionStatuses(
    List<String> transactionIds,
  ) async {
    final results = <Map<String, dynamic>>[];

    // Process in batches to avoid rate limiting
    const batchSize = 5;
    for (int i = 0; i < transactionIds.length; i += batchSize) {
      final batch = transactionIds.skip(i).take(batchSize);
      final batchFutures = batch.map((id) => getTransactionStatus(id));

      try {
        final batchResults = await Future.wait(batchFutures);
        results.addAll(
          batchResults
              .where((result) => result != null)
              .cast<Map<String, dynamic>>(),
        );
      } catch (e) {
        debugPrint('Error in batch transaction status fetch: $e');
      }

      // Small delay between batches
      if (i + batchSize < transactionIds.length) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    return results;
  }

  /// Check if transaction is in a final state
  static bool isTransactionFinal(String status) {
    return status == 'completed' || status == 'failed' || status == 'cancelled';
  }

  /// Get transaction status display information
  static Map<String, dynamic> getTransactionStatusInfo(String status) {
    switch (status) {
      case 'waitingPayment':
        return {
          'label': 'Waiting for Payment',
          'color': 'orange',
          'description': 'Waiting for user to complete payment',
        };
      case 'pending':
        return {
          'label': 'Pending',
          'color': 'yellow',
          'description': 'Transaction is being processed',
        };
      case 'waitingAuthorization':
        return {
          'label': 'Waiting Authorization',
          'color': 'blue',
          'description': 'Waiting for authorization from payment provider',
        };
      case 'completed':
        return {
          'label': 'Completed',
          'color': 'green',
          'description': 'Transaction completed successfully',
        };
      case 'failed':
        return {
          'label': 'Failed',
          'color': 'red',
          'description': 'Transaction failed',
        };
      case 'cancelled':
        return {
          'label': 'Cancelled',
          'color': 'gray',
          'description': 'Transaction was cancelled',
        };
      default:
        return {
          'label': status,
          'color': 'gray',
          'description': 'Unknown status',
        };
    }
  }

  /// Validate transaction signature (for webhook verification)
  static bool verifyWebhookSignature(
    String payload,
    String signature,
    String secret,
  ) {
    // Implementation would depend on MoonPay's webhook signature verification
    // This is a placeholder for the actual implementation
    return true;
  }

  /// Get MoonPay limits for the user
  static Future<Map<String, dynamic>?> getLimits() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/v3/limits'),
        headers: {'Authorization': 'Bearer $_apiKey'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch limits: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching MoonPay limits: $e');
      return null;
    }
  }

  /// Check if MoonPay is available in user's country
  static Future<bool> isAvailableInCountry(String countryCode) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/v3/countries'),
        headers: {'Authorization': 'Bearer $_apiKey'},
      );

      if (response.statusCode == 200) {
        final countries = json.decode(response.body) as List;
        return countries.any(
          (country) =>
              country['alpha2'] == countryCode &&
              country['isBuyAllowed'] == true,
        );
      }
      return false;
    } catch (e) {
      debugPrint('Error checking country availability: $e');
      return false;
    }
  }

  /// Generate URL for MoonPay widget with enhanced parameters
  static String generateEnhancedWidgetUrl({
    required String walletAddress,
    required String currencyCode,
    double? baseCurrencyAmount,
    String baseCurrencyCode = 'USD',
    String? email,
    String? externalCustomerId,
    String? redirectURL,
    bool lockAmount = false,
    bool showOnlyCurrencies = false,
    String theme = 'dark',
    String language = 'en',
  }) {
    final params = <String, String>{
      'apiKey': _apiKey,
      'currencyCode': currencyCode,
      'walletAddress': walletAddress,
      'baseCurrencyCode': baseCurrencyCode,
      'theme': theme,
      'language': language,
      'showWalletAddressForm': 'false',
      'lockAmount': lockAmount.toString(),
      'showOnlyCurrencies': showOnlyCurrencies.toString(),
    };

    if (baseCurrencyAmount != null) {
      params['baseCurrencyAmount'] = baseCurrencyAmount.toString();
    }

    if (email != null && email.isNotEmpty) {
      params['email'] = email;
    }

    if (externalCustomerId != null && externalCustomerId.isNotEmpty) {
      params['externalCustomerId'] = externalCustomerId;
    }

    if (redirectURL != null && redirectURL.isNotEmpty) {
      params['redirectURL'] = redirectURL;
    }

    final queryString = params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    return '$_widgetUrl?$queryString';
  }
}
