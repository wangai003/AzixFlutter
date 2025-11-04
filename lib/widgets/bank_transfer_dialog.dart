import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/currency_service.dart';
import '../theme/app_theme.dart';
import '../providers/enhanced_wallet_provider.dart';

class BankTransferDialog extends StatefulWidget {
  final double akofaAmount;
  final String userId;
  final String email;
  final String phoneNumber;
  final String countryCode;

  const BankTransferDialog({
    super.key,
    required this.akofaAmount,
    required this.userId,
    required this.email,
    required this.phoneNumber,
    required this.countryCode,
  });

  @override
  State<BankTransferDialog> createState() => _BankTransferDialogState();
}

class _BankTransferDialogState extends State<BankTransferDialog> {
  final _formKey = GlobalKey<FormState>();
  // Bank service removed - Flutterwave integration no longer available

  String? _selectedBank;
  String? _accountNumber;
  String? _accountName;
  String? _selectedCurrency;
  double _convertedAmount = 0.0;
  Map<String, double> _currencyPrices = {};
  List<Map<String, dynamic>> _supportedBanks = [];
  bool _isLoading = false;
  bool _isLoadingBanks = true;

  // AKOFA price in USD (example: $0.10 per AKOFA)
  static const double _akofaUsdPrice = 0.10;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = CurrencyService.getCurrencyName(widget.countryCode);
    _loadCurrencyPrices();
    _loadSupportedBanks();
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

  Future<void> _loadSupportedBanks() async {
    // Bank loading removed - Flutterwave integration no longer available
    // Use fallback banks only
    setState(() {
      _supportedBanks = _getFallbackBanks(widget.countryCode);
      _isLoadingBanks = false;
    });
  }

  List<Map<String, dynamic>> _getFallbackBanks(String countryCode) {
    // Common banks by country
    const fallbackBanks = {
      'NG': [
        {'name': 'Access Bank', 'code': '044'},
        {'name': 'First Bank', 'code': '011'},
        {'name': 'GTBank', 'code': '058'},
        {'name': 'UBA', 'code': '033'},
        {'name': 'Zenith Bank', 'code': '057'},
      ],
      'KE': [
        {'name': 'KCB Bank', 'code': '001'},
        {'name': 'Equity Bank', 'code': '068'},
        {'name': 'Co-operative Bank', 'code': '011'},
        {'name': 'Absa Bank', 'code': '003'},
      ],
      'GH': [
        {'name': 'GCB Bank', 'code': '030100'},
        {'name': 'Ecobank', 'code': '130100'},
        {'name': 'CalBank', 'code': '280100'},
      ],
      'ZA': [
        {'name': 'Absa Bank', 'code': '632005'},
        {'name': 'FNB', 'code': '250655'},
        {'name': 'Standard Bank', 'code': '051001'},
        {'name': 'Nedbank', 'code': '198765'},
      ],
      'UG': [
        {'name': 'Centenary Bank', 'code': '022'},
        {'name': 'Stanbic Bank', 'code': '023'},
        {'name': 'DFCU Bank', 'code': '025'},
      ],
      'TZ': [
        {'name': 'CRDB Bank', 'code': '118'},
        {'name': 'NMB Bank', 'code': '119'},
        {'name': 'NBC Bank', 'code': '120'},
      ],
    };

    return List<Map<String, dynamic>>.from(fallbackBanks[countryCode] ?? []);
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
                      Icons.account_balance,
                      color: AppTheme.primaryGold,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Bank Transfer',
                      style: AppTheme.headingMedium.copyWith(
                        color: AppTheme.primaryGold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Purchase ${widget.akofaAmount} AKOFA tokens via bank transfer',
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

                // Bank Selection
                if (_isLoadingBanks)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryGold,
                      ),
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: _selectedBank,
                    dropdownColor: AppTheme.darkGrey,
                    style: TextStyle(color: AppTheme.white),
                    decoration: InputDecoration(
                      labelText: 'Select Bank',
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
                    items: _supportedBanks.map((bank) {
                      return DropdownMenuItem(
                        value: bank['code'] as String,
                        child: Text(
                          bank['name'] as String,
                          style: TextStyle(color: AppTheme.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedBank = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a bank';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 16),

                // Account Details
                TextFormField(
                  style: TextStyle(color: AppTheme.white),
                  decoration: InputDecoration(
                    labelText: 'Account Number',
                    labelStyle: TextStyle(color: AppTheme.primaryGold),
                    hintText: 'Enter your account number',
                    hintStyle: TextStyle(color: AppTheme.grey),
                    prefixIcon: Icon(
                      Icons.account_balance_wallet,
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
                  onChanged: (value) => _accountNumber = value,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter account number';
                    }
                    if (value.length < 8 || value.length > 20) {
                      return 'Invalid account number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  style: TextStyle(color: AppTheme.white),
                  decoration: InputDecoration(
                    labelText: 'Account Name',
                    labelStyle: TextStyle(color: AppTheme.primaryGold),
                    hintText: 'Enter account holder name',
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
                  onChanged: (value) => _accountName = value,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter account name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Info Text
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You will be redirected to complete the bank transfer. Funds will be credited once payment is confirmed.',
                          style: AppTheme.bodySmall.copyWith(
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                        onPressed: _isLoading ? null : _processBankTransfer,
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
                            : const Text('Continue'),
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

  Future<void> _processBankTransfer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Bank transfer processing removed - Flutterwave integration no longer available
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bank transfer processing is currently unavailable - Flutterwave integration removed',
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

  void _showBankTransferInstructions(
    String paymentLink,
    Map<String, dynamic> bankData,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text(
          'Bank Transfer Instructions',
          style: TextStyle(color: AppTheme.primaryGold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Complete your bank transfer using the following details:',
                style: TextStyle(color: AppTheme.white),
              ),
              const SizedBox(height: 16),
              _buildInstructionItem('Bank', bankData['name']),
              _buildInstructionItem('Account Number', _accountNumber),
              _buildInstructionItem('Account Name', _accountName),
              _buildInstructionItem(
                'Amount',
                CurrencyService.formatCurrency(
                  _convertedAmount,
                  _selectedCurrency!,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Text(
                  '⚠️ Important: Include your transaction reference in the payment description.',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close', style: TextStyle(color: AppTheme.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Open payment link in browser/webview
              _openPaymentLink(paymentLink);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: AppTheme.black,
            ),
            child: const Text('Continue to Payment'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: AppTheme.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: TextStyle(color: AppTheme.white),
            ),
          ),
        ],
      ),
    );
  }

  void _openPaymentLink(String url) {
    // Open payment URL in external browser or webview
    if (kIsWeb) {
      // For web, open in new tab
      // html.window.open(url, '_blank');
      if (kDebugMode) {
        print('Opening bank transfer URL: $url');
      }
    } else {
      // For mobile, use url_launcher
      // launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (kDebugMode) {
        print('Launching bank transfer URL: $url');
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Bank transfer initiated! Complete transfer in browser.',
        ),
        backgroundColor: Colors.blue,
        action: SnackBarAction(
          label: 'Open',
          textColor: Colors.white,
          onPressed: () {
            // Actually open the URL
            if (kDebugMode) {
              print('Opening bank transfer URL: $url');
            }
          },
        ),
      ),
    );
  }
}
