import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/currency_service.dart';
import '../theme/app_theme.dart';
import '../providers/enhanced_wallet_provider.dart';

class CardPaymentDialog extends StatefulWidget {
  final double akofaAmount;
  final String userId;
  final String email;
  final String phoneNumber;
  final String countryCode;

  const CardPaymentDialog({
    super.key,
    required this.akofaAmount,
    required this.userId,
    required this.email,
    required this.phoneNumber,
    required this.countryCode,
  });

  @override
  State<CardPaymentDialog> createState() => _CardPaymentDialogState();
}

class _CardPaymentDialogState extends State<CardPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  // Card service removed - Flutterwave integration no longer available

  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cardNameController = TextEditingController();

  bool _isLoading = false;
  bool _useSavedCard = false;
  String? _selectedCurrency;
  double _convertedAmount = 0.0;
  Map<String, double> _currencyPrices = {};

  // AKOFA price in USD (example: $0.10 per AKOFA)
  static const double _akofaUsdPrice = 0.10;

  @override
  void initState() {
    super.initState();
    _loadCurrencyPrices();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardNameController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrencyPrices() async {
    try {
      final popularCurrencies = CurrencyService.getPopularCurrenciesForRegion(
        'global',
      );
      _currencyPrices = await CurrencyService.getAkofaPricesInCurrencies(
        _akofaUsdPrice * widget.akofaAmount,
        popularCurrencies,
      );

      // Set default currency based on country code if available
      if (_selectedCurrency == null && popularCurrencies.isNotEmpty) {
        _selectedCurrency = CurrencyService.getCurrencyName(widget.countryCode);
        if (!_currencyPrices.containsKey(_selectedCurrency)) {
          _selectedCurrency = popularCurrencies.first;
        }
      }

      if (_selectedCurrency != null &&
          _currencyPrices.containsKey(_selectedCurrency!)) {
        _convertedAmount = _currencyPrices[_selectedCurrency!]!;
      }

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading currency prices: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.darkGrey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.credit_card,
                      color: AppTheme.primaryGold,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Card Payment',
                      style: AppTheme.headingMedium.copyWith(
                        color: AppTheme.primaryGold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Purchase ${widget.akofaAmount} AKOFA tokens',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                ),
                const SizedBox(height: 24),

                // Amount Display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryGold.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Amount:',
                            style: AppTheme.bodyLarge.copyWith(
                              color: AppTheme.white,
                            ),
                          ),
                          Text(
                            '${widget.akofaAmount} AKOFA',
                            style: AppTheme.bodyLarge.copyWith(
                              color: AppTheme.primaryGold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Price:',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.grey,
                            ),
                          ),
                          Text(
                            _selectedCurrency != null &&
                                    _currencyPrices.containsKey(
                                      _selectedCurrency!,
                                    )
                                ? CurrencyService.formatCurrency(
                                    _currencyPrices[_selectedCurrency!]!,
                                    _selectedCurrency!,
                                  )
                                : '\$${_akofaUsdPrice * widget.akofaAmount}',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Currency Selector
                if (_currencyPrices.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    dropdownColor: AppTheme.darkGrey,
                    style: TextStyle(color: AppTheme.white),
                    decoration: InputDecoration(
                      labelText: 'Payment Currency',
                      labelStyle: TextStyle(color: AppTheme.primaryGold),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.primaryGold),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppTheme.primaryGold.withOpacity(0.5),
                        ),
                      ),
                    ),
                    items: _currencyPrices.keys.map((currency) {
                      return DropdownMenuItem(
                        value: currency,
                        child: Text(
                          '${CurrencyService.getCurrencyName(currency)} (${CurrencyService.getCurrencySymbol(currency)}${CurrencyService.formatCurrency(_currencyPrices[currency]!, currency).replaceFirst(CurrencyService.getCurrencySymbol(currency), '')})',
                          style: TextStyle(color: AppTheme.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCurrency = value;
                        _convertedAmount = _currencyPrices[value!] ?? 0.0;
                      });
                    },
                  ),
                const SizedBox(height: 24),

                // Card Details Form
                TextFormField(
                  controller: _cardNumberController,
                  style: TextStyle(color: AppTheme.white),
                  decoration: InputDecoration(
                    labelText: 'Card Number',
                    labelStyle: TextStyle(color: AppTheme.primaryGold),
                    hintText: '1234 5678 9012 3456',
                    hintStyle: TextStyle(color: AppTheme.grey),
                    prefixIcon: Icon(
                      Icons.credit_card,
                      color: AppTheme.primaryGold,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppTheme.primaryGold.withOpacity(0.5),
                      ),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(19),
                    _CardNumberFormatter(),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter card number';
                    }
                    final cleanNumber = value.replaceAll(' ', '');
                    if (cleanNumber.length < 13 || cleanNumber.length > 19) {
                      return 'Invalid card number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _expiryController,
                        style: TextStyle(color: AppTheme.white),
                        decoration: InputDecoration(
                          labelText: 'Expiry Date',
                          labelStyle: TextStyle(color: AppTheme.primaryGold),
                          hintText: 'MM/YY',
                          hintStyle: TextStyle(color: AppTheme.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: AppTheme.primaryGold.withOpacity(0.5),
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                          _ExpiryDateFormatter(),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          if (value.length != 5) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _cvvController,
                        style: TextStyle(color: AppTheme.white),
                        decoration: InputDecoration(
                          labelText: 'CVV',
                          labelStyle: TextStyle(color: AppTheme.primaryGold),
                          hintText: '123',
                          hintStyle: TextStyle(color: AppTheme.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: AppTheme.primaryGold.withOpacity(0.5),
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          if (value.length < 3 || value.length > 4) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _cardNameController,
                  style: TextStyle(color: AppTheme.white),
                  decoration: InputDecoration(
                    labelText: 'Cardholder Name',
                    labelStyle: TextStyle(color: AppTheme.primaryGold),
                    hintText: 'John Doe',
                    hintStyle: TextStyle(color: AppTheme.grey),
                    prefixIcon: Icon(Icons.person, color: AppTheme.primaryGold),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppTheme.primaryGold.withOpacity(0.5),
                      ),
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter cardholder name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: AppTheme.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _processPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold,
                          foregroundColor: AppTheme.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text('Pay Now'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Card payment processing removed - Flutterwave integration no longer available
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Card payment processing is currently unavailable - Flutterwave integration removed',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showPaymentWebView(String url) {
    // Open payment URL in external browser or webview
    // This would integrate with url_launcher or webview_flutter
    if (kIsWeb) {
      // For web, open in new tab
      // html.window.open(url, '_blank');
      if (kDebugMode) {
        print('Opening payment URL: $url');
      }
    } else {
      // For mobile, use url_launcher
      // launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (kDebugMode) {
        print('Launching payment URL: $url');
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Payment initiated! Complete payment in browser.'),
        backgroundColor: Colors.blue,
        action: SnackBarAction(
          label: 'Open',
          textColor: Colors.white,
          onPressed: () {
            // Actually open the URL
            if (kDebugMode) {
              print('Opening payment URL: $url');
            }
          },
        ),
      ),
    );
  }
}

/// Card number formatter
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i + 1 != text.length) {
        buffer.write(' ');
      }
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

/// Expiry date formatter
class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 && i + 1 != text.length) {
        buffer.write('/');
      }
    }

    return TextEditingValue(
      text: buffer.length <= 5
          ? buffer.toString()
          : buffer.toString().substring(0, 5),
      selection: TextSelection.collapsed(
        offset: buffer.length <= 5 ? buffer.length : 5,
      ),
    );
  }
}
