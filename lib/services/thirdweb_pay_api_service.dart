import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// ThirdWeb Pay API Service
/// Direct API integration without using pre-built widgets
/// Build your own UI and use ThirdWeb's onramp infrastructure
class ThirdWebPayApiService {
  static const String _clientId = '33d89c360e1ec70249ee4f1e09f8ee2c';
  static const String _baseUrl = 'https://embedded-wallet.thirdweb.com';
  
  /// Supported onramp providers
  static const List<String> supportedProviders = [
    'stripe',
    'coinbase',
    'transak',
    'moonpay',
  ];
  
  /// Supported networks
  static const Map<String, int> supportedNetworks = {
    'polygon': 137,
    'polygon-amoy': 80002,
    'ethereum': 1,
  };
  
  /// Prepare an onramp transaction
  /// Returns a payment link and quote
  static Future<OnrampQuote> prepareOnramp({
    required String walletAddress,
    required String network,
    required double amountUSD,
    String provider = 'stripe', // or 'coinbase', 'transak', 'moonpay'
    String token = 'MATIC',
  }) async {
    try {
      final chainId = supportedNetworks[network];
      if (chainId == null) {
        throw Exception('Unsupported network: $network');
      }
      
      debugPrint('🔄 Preparing ThirdWeb onramp...');
      debugPrint('   Provider: $provider');
      debugPrint('   Network: $network (${chainId})');
      debugPrint('   Amount: \$$amountUSD');
      debugPrint('   Token: $token');
      debugPrint('   Wallet: $walletAddress');
      
      // ThirdWeb Pay API endpoint
      final url = Uri.parse('$_baseUrl/api/v1/onramp/quote');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-client-id': _clientId,
        },
        body: jsonEncode({
          'provider': provider,
          'chainId': chainId,
          'tokenAddress': token == 'MATIC' || token == 'ETH' 
              ? '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee' // Native token
              : token, // ERC-20 address
          'receiver': walletAddress,
          'amount': amountUSD.toString(),
          'currency': 'USD',
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Onramp prepared successfully');
        
        return OnrampQuote(
          paymentLink: data['link'] ?? _buildFallbackLink(
            provider: provider,
            walletAddress: walletAddress,
            chainId: chainId,
            amount: amountUSD,
          ),
          fiatAmount: data['currencyAmount'] ?? amountUSD,
          cryptoAmount: data['tokenAmount']?.toString() ?? 'N/A',
          provider: provider,
          network: network,
          token: token,
        );
      } else {
        debugPrint('⚠️ API returned ${response.statusCode}, using fallback');
        // If API fails, generate direct provider link
        return OnrampQuote(
          paymentLink: _buildFallbackLink(
            provider: provider,
            walletAddress: walletAddress,
            chainId: chainId,
            amount: amountUSD,
          ),
          fiatAmount: amountUSD,
          cryptoAmount: 'N/A',
          provider: provider,
          network: network,
          token: token,
        );
      }
    } catch (e) {
      debugPrint('❌ Error preparing onramp: $e');
      // Return fallback link on error
      return OnrampQuote(
        paymentLink: _buildFallbackLink(
          provider: provider,
          walletAddress: walletAddress,
          chainId: supportedNetworks[network]!,
          amount: amountUSD,
        ),
        fiatAmount: amountUSD,
        cryptoAmount: 'N/A',
        provider: provider,
        network: network,
        token: token,
      );
    }
  }
  
  /// Build fallback payment link directly to provider
  /// Used when API is unavailable or for simpler integration
  static String _buildFallbackLink({
    required String provider,
    required String walletAddress,
    required int chainId,
    required double amount,
  }) {
    switch (provider.toLowerCase()) {
      case 'stripe':
        // Stripe onramp (via ThirdWeb)
        return 'https://crypto.link.com/buy?'
            'clientReferenceId=$_clientId&'
            'destinationWallets=[{"address":"$walletAddress","assets":["MATIC"]}]&'
            'defaultNetwork=polygon';
        
      case 'coinbase':
        // Coinbase Pay
        return 'https://pay.coinbase.com/buy/select-asset?'
            'appId=$_clientId&'
            'addresses={"$walletAddress":["polygon"]}&'
            'assets=["MATIC"]';
        
      case 'transak':
        // Transak (most reliable fallback)
        return 'https://global.transak.com/?'
            'apiKey=$_clientId&'
            'walletAddress=$walletAddress&'
            'defaultCryptoCurrency=MATIC&'
            'defaultNetwork=polygon&'
            'defaultFiatAmount=${amount.toStringAsFixed(2)}&'
            'themeColor=D4AF37&'
            'hideMenu=true';
        
      case 'moonpay':
        // MoonPay
        return 'https://buy.moonpay.com?'
            'apiKey=$_clientId&'
            'walletAddress=$walletAddress&'
            'defaultCurrencyCode=matic_polygon&'
            'baseCurrencyAmount=${amount.toStringAsFixed(2)}&'
            'colorCode=%23D4AF37';
        
      default:
        // Default to Transak (most reliable)
        return _buildFallbackLink(
          provider: 'transak',
          walletAddress: walletAddress,
          chainId: chainId,
          amount: amount,
        );
    }
  }
  
  /// Get available payment methods for a provider
  static Future<List<PaymentMethod>> getPaymentMethods(String provider) async {
    // Simplified - in production, fetch from API
    final methods = <PaymentMethod>[];
    
    switch (provider.toLowerCase()) {
      case 'stripe':
        methods.addAll([
          PaymentMethod('card', 'Credit/Debit Card', '2.9% + \$0.30'),
          PaymentMethod('ach', 'Bank Transfer (ACH)', '0.8%'),
        ]);
        break;
      case 'coinbase':
        methods.addAll([
          PaymentMethod('card', 'Credit/Debit Card', '3.99%'),
          PaymentMethod('bank', 'Bank Account', '1.49%'),
        ]);
        break;
      case 'transak':
        methods.addAll([
          PaymentMethod('card', 'Credit/Debit Card', '3.5%'),
          PaymentMethod('bank', 'Bank Transfer', '0.99%'),
          PaymentMethod('apple_pay', 'Apple Pay', '3.5%'),
          PaymentMethod('google_pay', 'Google Pay', '3.5%'),
        ]);
        break;
      case 'moonpay':
        methods.addAll([
          PaymentMethod('card', 'Credit/Debit Card', '4.5%'),
          PaymentMethod('bank', 'Bank Transfer', '1%'),
        ]);
        break;
    }
    
    return methods;
  }
}

/// Onramp quote response
class OnrampQuote {
  final String paymentLink;
  final double fiatAmount;
  final String cryptoAmount;
  final String provider;
  final String network;
  final String token;
  
  OnrampQuote({
    required this.paymentLink,
    required this.fiatAmount,
    required this.cryptoAmount,
    required this.provider,
    required this.network,
    required this.token,
  });
  
  @override
  String toString() {
    return 'OnrampQuote(provider: $provider, fiat: \$$fiatAmount, crypto: $cryptoAmount $token)';
  }
}

/// Payment method option
class PaymentMethod {
  final String id;
  final String name;
  final String fee;
  
  PaymentMethod(this.id, this.name, this.fee);
}

