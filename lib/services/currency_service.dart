import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Currency conversion and exchange rate service
class CurrencyService {
  static const String _exchangeRateApi =
      'https://api.exchangerate-api.com/v4/latest/USD';
  static const String _fallbackExchangeRateApi =
      'https://api.fixer.io/latest?access_key=YOUR_FIXER_API_KEY';

  // Static exchange rates as fallback (updated periodically)
  static const Map<String, double> _fallbackRates = {
    'USD': 1.0,
    'EUR': 0.85,
    'GBP': 0.73,
    'NGN': 1450.0,
    'KES': 129.0,
    'GHS': 12.0,
    'ZAR': 18.5,
    'UGX': 3700.0,
    'TZS': 2700.0,
    'RWF': 1300.0,
    'ZMW': 25.0,
    'BWP': 13.5,
    'MZN': 63.0,
    'AOA': 830.0,
    'XAF': 600.0, // Central African Franc
    'XOF': 600.0, // West African Franc
    'MAD': 10.0,
    'TND': 3.1,
    'EGP': 30.0,
    'ETB': 55.0,
    'CAD': 1.35,
    'MXN': 20.0,
    'BRL': 5.2,
    'ARS': 350.0,
    'CLP': 950.0,
    'COP': 4100.0,
    'PEN': 3.8,
    'VES': 35.0,
    'UYU': 42.0,
    'PYG': 7500.0,
    'BOB': 6.9,
    'INR': 83.0,
    'PKR': 278.0,
    'BDT': 110.0,
    'LKR': 320.0,
    'NPR': 133.0,
    'MMK': 2100.0,
    'THB': 36.0,
    'VND': 23000.0,
    'KHR': 4100.0,
    'MYR': 4.7,
    'SGD': 1.35,
    'IDR': 15000.0,
    'PHP': 56.0,
    'KRW': 1300.0,
    'JPY': 145.0,
    'CNY': 7.2,
    'HKD': 7.8,
    'TWD': 32.0,
    'AED': 3.67,
    'SAR': 3.75,
    'QAR': 3.64,
    'KWD': 0.31,
    'BHD': 0.38,
    'OMR': 0.38,
    'AUD': 1.5,
    'NZD': 1.6,
    'FJD': 2.2,
    'PGK': 3.5,
    'CHF': 0.92,
    'SEK': 10.5,
    'NOK': 10.8,
    'DKK': 6.8,
  };

  static Map<String, double> _currentRates = {};
  static DateTime? _lastUpdate;

  /// Get current exchange rates
  static Future<Map<String, double>> getExchangeRates() async {
    try {
      // Return cached rates if less than 1 hour old
      if (_currentRates.isNotEmpty &&
          _lastUpdate != null &&
          DateTime.now().difference(_lastUpdate!) < const Duration(hours: 1)) {
        return _currentRates;
      }

      // Try primary API first
      final response = await http.get(
        Uri.parse(_exchangeRateApi),
        headers: {'User-Agent': 'AzixWallet/1.0', 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = Map<String, double>.from(data['rates'] ?? {});

        // Validate rates are reasonable (not zero or negative)
        rates.removeWhere((key, value) => value <= 0);

        // Add USD base rate
        rates['USD'] = 1.0;

        _currentRates = rates;
        _lastUpdate = DateTime.now();

        if (kDebugMode) {
          print('Successfully fetched ${rates.length} exchange rates');
        }

        return rates;
      } else {
        if (kDebugMode) {
          print('Primary API failed with status: ${response.statusCode}');
        }
        // Try fallback API
        return await _getFallbackExchangeRates();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching exchange rates from primary API: $e');
      }
      // Try fallback API
      return await _getFallbackExchangeRates();
    }
  }

  /// Get fallback exchange rates from alternative API
  static Future<Map<String, double>> _getFallbackExchangeRates() async {
    try {
      final response = await http.get(
        Uri.parse(_fallbackExchangeRateApi),
        headers: {'User-Agent': 'AzixWallet/1.0', 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = Map<String, double>.from(data['rates'] ?? {});

        // Validate rates
        rates.removeWhere((key, value) => value <= 0);

        rates['USD'] = 1.0;

        _currentRates = rates;
        _lastUpdate = DateTime.now();

        if (kDebugMode) {
          print(
            'Successfully fetched ${rates.length} exchange rates from fallback API',
          );
        }

        return rates;
      } else {
        throw Exception('Fallback API also failed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching exchange rates from fallback API: $e');
      }
      // Use static fallback rates
      _currentRates = Map.from(_fallbackRates);
      _lastUpdate = DateTime.now();
      return _currentRates;
    }
  }

  /// Convert amount from one currency to another
  static Future<double> convertCurrency(
    double amount,
    String fromCurrency,
    String toCurrency,
  ) async {
    try {
      if (amount <= 0) {
        throw Exception('Amount must be positive');
      }

      if (fromCurrency == toCurrency) {
        return amount; // No conversion needed
      }

      final rates = await getExchangeRates();

      final fromRate = rates[fromCurrency] ?? _fallbackRates[fromCurrency];
      final toRate = rates[toCurrency] ?? _fallbackRates[toCurrency];

      if (fromRate == null || toRate == null) {
        throw Exception(
          'Exchange rate not available for $fromCurrency or $toCurrency',
        );
      }

      if (fromRate <= 0 || toRate <= 0) {
        throw Exception('Invalid exchange rate values');
      }

      // Convert to USD first, then to target currency
      final usdAmount = amount / fromRate;
      final convertedAmount = usdAmount * toRate;

      // Round to appropriate decimal places
      final roundedAmount = _roundToAppropriateDecimals(
        convertedAmount,
        toCurrency,
      );

      if (kDebugMode) {
        print('Converted $amount $fromCurrency to $roundedAmount $toCurrency');
      }

      return roundedAmount;
    } catch (e) {
      if (kDebugMode) {
        print('Error converting currency: $e');
      }
      // Fallback conversion
      final fromRate = _fallbackRates[fromCurrency] ?? 1.0;
      final toRate = _fallbackRates[toCurrency] ?? 1.0;

      final usdAmount = amount / fromRate;
      return _roundToAppropriateDecimals(usdAmount * toRate, toCurrency);
    }
  }

  /// Round amount to appropriate decimal places for currency
  static double _roundToAppropriateDecimals(double amount, String currency) {
    // Currencies that don't use decimals
    const noDecimalCurrencies = [
      'JPY',
      'KRW',
      'VND',
      'CLP',
      'ISK',
      'BIF',
      'DJF',
      'GNF',
      'JPY',
      'KMF',
      'KRW',
      'MGA',
      'PYG',
      'RWF',
      'UGX',
      'VND',
      'VUV',
      'XAF',
      'XOF',
      'XPF',
    ];

    if (noDecimalCurrencies.contains(currency)) {
      return amount.roundToDouble();
    }

    // Most currencies use 2 decimal places
    return double.parse(amount.toStringAsFixed(2));
  }

  /// Get currency symbol
  static String getCurrencySymbol(String currencyCode) {
    const symbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'NGN': '₦',
      'KES': 'KSh',
      'GHS': '₵',
      'ZAR': 'R',
      'UGX': 'UGX',
      'TZS': 'TSh',
      'RWF': 'FRw',
      'ZMW': 'ZK',
      'BWP': 'P',
      'MZN': 'MT',
      'AOA': 'Kz',
      'XAF': 'FCFA',
      'XOF': 'CFA',
      'MAD': 'MAD',
      'TND': 'DT',
      'EGP': 'E£',
      'ETB': 'Br',
      'CAD': 'C\$',
      'MXN': '\$',
      'BRL': 'R\$',
      'ARS': '\$',
      'CLP': '\$',
      'COP': '\$',
      'PEN': 'S/',
      'VES': 'Bs.',
      'UYU': '\$U',
      'PYG': '₲',
      'BOB': 'Bs.',
      'INR': '₹',
      'PKR': '₨',
      'BDT': '৳',
      'LKR': '₨',
      'NPR': '₨',
      'MMK': 'K',
      'THB': '฿',
      'VND': '₫',
      'KHR': '៛',
      'MYR': 'RM',
      'SGD': 'S\$',
      'IDR': 'Rp',
      'PHP': '₱',
      'KRW': '₩',
      'JPY': '¥',
      'CNY': '¥',
      'HKD': 'HK\$',
      'TWD': 'NT\$',
      'AED': 'AED',
      'SAR': 'SAR',
      'QAR': 'QAR',
      'KWD': 'KD',
      'BHD': 'BD',
      'OMR': 'OMR',
      'AUD': 'A\$',
      'NZD': 'NZ\$',
      'FJD': 'FJ\$',
      'PGK': 'K',
      'CHF': 'CHF',
      'SEK': 'kr',
      'NOK': 'kr',
      'DKK': 'kr',
    };

    return symbols[currencyCode] ?? currencyCode;
  }

  /// Format currency amount with symbol
  static String formatCurrency(double amount, String currencyCode) {
    final symbol = getCurrencySymbol(currencyCode);

    // Format based on currency
    if (currencyCode == 'JPY' || currencyCode == 'KRW') {
      // No decimal places for these currencies
      return '$symbol${amount.round()}';
    } else if ([
      'BIF',
      'CLP',
      'DJF',
      'GNF',
      'JPY',
      'KMF',
      'KRW',
      'MGA',
      'PYG',
      'RWF',
      'UGX',
      'VND',
      'VUV',
      'XAF',
      'XOF',
      'XPF',
    ].contains(currencyCode)) {
      // No decimal places
      return '$symbol${amount.round()}';
    } else {
      // Two decimal places
      return '$symbol${amount.toStringAsFixed(2)}';
    }
  }

  /// Get currency name
  static String getCurrencyName(String currencyCode) {
    const names = {
      'USD': 'US Dollar',
      'EUR': 'Euro',
      'GBP': 'British Pound',
      'NGN': 'Nigerian Naira',
      'KES': 'Kenyan Shilling',
      'GHS': 'Ghanaian Cedi',
      'ZAR': 'South African Rand',
      'UGX': 'Ugandan Shilling',
      'TZS': 'Tanzanian Shilling',
      'RWF': 'Rwandan Franc',
      'ZMW': 'Zambian Kwacha',
      'BWP': 'Botswana Pula',
      'MZN': 'Mozambican Metical',
      'AOA': 'Angolan Kwanza',
      'XAF': 'Central African Franc',
      'XOF': 'West African Franc',
      'MAD': 'Moroccan Dirham',
      'TND': 'Tunisian Dinar',
      'EGP': 'Egyptian Pound',
      'ETB': 'Ethiopian Birr',
      'CAD': 'Canadian Dollar',
      'MXN': 'Mexican Peso',
      'BRL': 'Brazilian Real',
      'ARS': 'Argentine Peso',
      'CLP': 'Chilean Peso',
      'COP': 'Colombian Peso',
      'PEN': 'Peruvian Sol',
      'VES': 'Venezuelan Bolivar',
      'UYU': 'Uruguayan Peso',
      'PYG': 'Paraguayan Guarani',
      'BOB': 'Bolivian Boliviano',
      'INR': 'Indian Rupee',
      'PKR': 'Pakistani Rupee',
      'BDT': 'Bangladeshi Taka',
      'LKR': 'Sri Lankan Rupee',
      'NPR': 'Nepalese Rupee',
      'MMK': 'Myanmar Kyat',
      'THB': 'Thai Baht',
      'VND': 'Vietnamese Dong',
      'KHR': 'Cambodian Riel',
      'MYR': 'Malaysian Ringgit',
      'SGD': 'Singapore Dollar',
      'IDR': 'Indonesian Rupiah',
      'PHP': 'Philippine Peso',
      'KRW': 'South Korean Won',
      'JPY': 'Japanese Yen',
      'CNY': 'Chinese Yuan',
      'HKD': 'Hong Kong Dollar',
      'TWD': 'Taiwan Dollar',
      'AED': 'UAE Dirham',
      'SAR': 'Saudi Riyal',
      'QAR': 'Qatari Riyal',
      'KWD': 'Kuwaiti Dinar',
      'BHD': 'Bahraini Dinar',
      'OMR': 'Omani Rial',
      'AUD': 'Australian Dollar',
      'NZD': 'New Zealand Dollar',
      'FJD': 'Fiji Dollar',
      'PGK': 'Papua New Guinea Kina',
      'CHF': 'Swiss Franc',
      'SEK': 'Swedish Krona',
      'NOK': 'Norwegian Krone',
      'DKK': 'Danish Krone',
    };

    return names[currencyCode] ?? currencyCode;
  }

  /// Calculate AKOFA price in different currencies
  static Future<Map<String, double>> getAkofaPricesInCurrencies(
    double baseUsdPrice,
    List<String> targetCurrencies,
  ) async {
    final rates = await getExchangeRates();
    final prices = <String, double>{};

    for (final currency in targetCurrencies) {
      final rate = rates[currency] ?? _fallbackRates[currency] ?? 1.0;
      prices[currency] = baseUsdPrice * rate;
    }

    return prices;
  }

  /// Get popular currencies for a region
  static List<String> getPopularCurrenciesForRegion(String region) {
    const regionCurrencies = {
      'africa': [
        'USD',
        'EUR',
        'NGN',
        'KES',
        'GHS',
        'ZAR',
        'UGX',
        'TZS',
        'RWF',
        'ZMW',
        'MAD',
        'EGP',
        'ETB',
      ],
      'europe': ['EUR', 'GBP', 'CHF', 'SEK', 'NOK', 'DKK', 'PLN'],
      'north_america': ['USD', 'CAD', 'MXN'],
      'south_america': ['USD', 'BRL', 'ARS', 'CLP', 'COP', 'PEN'],
      'asia': [
        'USD',
        'EUR',
        'INR',
        'PKR',
        'BDT',
        'THB',
        'VND',
        'MYR',
        'SGD',
        'IDR',
        'PHP',
        'KRW',
        'JPY',
        'CNY',
        'AED',
        'SAR',
      ],
      'oceania': ['AUD', 'NZD', 'USD'],
      'global': ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD'],
    };

    return regionCurrencies[region] ?? ['USD', 'EUR'];
  }
}
