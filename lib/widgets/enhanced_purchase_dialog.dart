import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/enhanced_wallet_provider.dart';
import '../theme/app_theme.dart';
import 'package:cloud_functions/cloud_functions.dart';

class EnhancedPurchaseDialog extends StatefulWidget {
  final EnhancedWalletProvider walletProvider;

  const EnhancedPurchaseDialog({super.key, required this.walletProvider});

  @override
  State<EnhancedPurchaseDialog> createState() => _EnhancedPurchaseDialogState();
}

class _EnhancedPurchaseDialogState extends State<EnhancedPurchaseDialog> {
  String _selectedCountry = 'KE'; // Default to Kenya for M-Pesa
  String _selectedProvider = 'M-Pesa'; // Default provider
  double _selectedAmount = 100.0;
  final _phoneController = TextEditingController();
  bool _isProcessing = false;
  String? _error;
  String? _userEmail;
  String? _userName;

  // Available providers by country
  final Map<String, List<String>> _countryProviders = {
    'KE': ['M-Pesa'],
    'NG': ['MTN'],
    'GH': ['MTN'],
    'UG': ['MTN'],
    'RW': ['MTN'],
    'ZM': ['MTN'],
    'CI': ['MTN'],
    'CM': ['MTN'],
  };

  // Preset amounts by country
  final Map<String, List<double>> _countryPresetAmounts = {
    'KE': [100, 500, 1000, 5000], // KES
    'NG': [500, 1000, 2000, 5000], // NGN
    'GH': [10, 50, 100, 200], // GHS
    'UG': [2500, 5000, 10000, 25000], // UGX
    'RW': [1000, 2000, 5000, 10000], // RWF
    'ZM': [50, 100, 200, 500], // ZMW
    'CI': [1000, 2500, 5000, 10000], // XOF
    'CM': [1000, 2500, 5000, 10000], // XAF
  };

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _detectUserCountry();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userEmail = user.email;
        _userName = user.displayName;
      });
    }
  }

  void _detectUserCountry() {
    // TODO: Implement IP-based country detection
    // For now, keep default as Kenya
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.darkGrey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Buy AKOFA Tokens',
                    style: AppTheme.headingMedium.copyWith(
                      color: AppTheme.primaryGold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Text(
                'Purchase AKOFA tokens using mobile money across Africa',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
              ),

              const SizedBox(height: 24),

              // Country Selection
              Text(
                'Select Country',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _buildCountrySelector(),

              const SizedBox(height: 16),

              // Provider Selection
              Text(
                'Mobile Money Provider',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _buildProviderSelector(),

              const SizedBox(height: 16),

              // Amount Selection
              Text(
                'Select Amount (${_getCurrencySymbol()})',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _buildAmountSelector(),

              const SizedBox(height: 16),

              // Conversion Display
              _buildConversionDisplay(),

              const SizedBox(height: 16),

              // Phone Number
              TextFormField(
                controller: _phoneController,
                style: TextStyle(color: AppTheme.white),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: '${_selectedProvider} Phone Number',
                  labelStyle: TextStyle(color: AppTheme.grey),
                  hintText: _getPhoneHint(),
                  hintStyle: TextStyle(color: AppTheme.grey.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.phone, color: AppTheme.primaryGold),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.primaryGold.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.primaryGold),
                  ),
                ),
                validator: (value) => _validatePhoneNumber(value),
              ),

              const SizedBox(height: 16),

              // Information
              _buildProviderInfo(),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppTheme.bodySmall.copyWith(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isProcessing
                          ? null
                          : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: AppTheme.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _initiatePurchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGold,
                        foregroundColor: AppTheme.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'Buy Now',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountrySelector() {
    // Country selection removed - Flutterwave integration no longer available
    final countries = [];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: DropdownButton<String>(
        value: _selectedCountry,
        isExpanded: true,
        dropdownColor: AppTheme.darkGrey,
        style: TextStyle(color: AppTheme.white),
        underline: const SizedBox(),
        items: countries.map((country) {
          return DropdownMenuItem<String>(
            value: country['code'],
            child: Row(
              children: [
                Text(country['flag'], style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${country['name']} (${country['code']})',
                    style: TextStyle(color: AppTheme.white),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedCountry = value;
              // Reset provider selection when country changes
              final availableProviders = _countryProviders[value] ?? [];
              if (!availableProviders.contains(_selectedProvider)) {
                _selectedProvider = availableProviders.isNotEmpty
                    ? availableProviders[0]
                    : 'MTN';
              }
              // Reset amount to first preset
              final presets = _countryPresetAmounts[value] ?? [100];
              _selectedAmount = presets[0];
            });
          }
        },
      ),
    );
  }

  Widget _buildProviderSelector() {
    final availableProviders = _countryProviders[_selectedCountry] ?? ['MTN'];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: availableProviders.map((provider) {
        final isSelected = _selectedProvider == provider;
        return GestureDetector(
          onTap: () => setState(() => _selectedProvider = provider),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryGold
                  : AppTheme.darkGrey.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryGold
                    : AppTheme.primaryGold.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              provider,
              style: AppTheme.bodyMedium.copyWith(
                color: isSelected ? AppTheme.black : AppTheme.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAmountSelector() {
    final presets =
        _countryPresetAmounts[_selectedCountry] ?? [100, 500, 1000, 5000];

    return Column(
      children: [
        // Preset Amounts
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((amount) {
            final isSelected = _selectedAmount == amount;
            return GestureDetector(
              onTap: () => setState(() => _selectedAmount = amount),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryGold
                      : AppTheme.darkGrey.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryGold
                        : AppTheme.primaryGold.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${_getCurrencySymbol()} ${amount.toInt()}',
                  style: AppTheme.bodyMedium.copyWith(
                    color: isSelected ? AppTheme.black : AppTheme.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 12),

        // Custom Amount
        TextFormField(
          initialValue: _selectedAmount.toStringAsFixed(0),
          style: TextStyle(color: AppTheme.white),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Custom Amount (${_getCurrencySymbol()})',
            labelStyle: TextStyle(color: AppTheme.grey),
            hintText: 'Enter amount',
            hintStyle: TextStyle(color: AppTheme.grey.withOpacity(0.5)),
            prefixIcon: Icon(Icons.attach_money, color: AppTheme.primaryGold),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.primaryGold.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryGold),
            ),
          ),
          onChanged: (value) {
            final amount = double.tryParse(value);
            // Amount validation removed - Flutterwave integration no longer available
            if (amount != null && amount > 0) {
              setState(() => _selectedAmount = amount);
            }
          },
        ),
      ],
    );
  }

  Widget _buildConversionDisplay() {
    // Conversion calculation removed - Flutterwave integration no longer available
    final akofaAmount = _selectedAmount / 100; // Simple conversion for display
    final currencySymbol = _getCurrencySymbol();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryGold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'You Pay',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
              ),
              Text(
                '$currencySymbol ${_selectedAmount.toInt()}',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'You Receive',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
              ),
              Text(
                '${akofaAmount.toStringAsFixed(2)} AKOFA',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Rate: ${_getExchangeRateText()}',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.grey.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderInfo() {
    String infoText = '';
    Color infoColor = Colors.blue;

    switch (_selectedProvider) {
      case 'M-Pesa':
        infoText =
            'You will receive an M-Pesa STK push prompt on your phone to complete the payment.';
        infoColor = Colors.green;
        break;
      case 'MTN':
        infoText =
            'You will receive an MTN Mobile Money prompt on your phone to complete the payment.';
        infoColor = Colors.orange;
        break;
      default:
        infoText =
            'You will receive a payment prompt on your phone to complete the transaction.';
        infoColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: infoColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: infoColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: infoColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              infoText,
              style: AppTheme.bodySmall.copyWith(color: infoColor),
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrencySymbol() {
    // Currency symbol lookup removed - Flutterwave integration no longer available
    return '\$';
  }

  String _getPhoneHint() {
    switch (_selectedCountry) {
      case 'KE':
        return '0712345678';
      case 'NG':
        return '08012345678';
      case 'GH':
        return '0201234567';
      case 'UG':
        return '0712345678';
      case 'RW':
        return '0721234567';
      case 'ZM':
        return '0951234567';
      case 'CI':
        return '0101234567';
      case 'CM':
        return '0691234567';
      default:
        return '0712345678';
    }
  }

  String _getExchangeRateText() {
    // Exchange rate calculation removed - Flutterwave integration no longer available
    return 'Rate unavailable';
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter phone number';
    }

    // Phone number validation removed - Flutterwave integration no longer available
    return null;
  }

  Future<void> _initiatePurchase() async {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) {
      setState(() => _error = 'Please enter phone number');
      return;
    }

    final validationError = _validatePhoneNumber(phoneNumber);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    // Amount validation removed - Flutterwave integration no longer available

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      if (_selectedProvider == 'M-Pesa') {
        // Use existing M-Pesa service
        final result = await widget.walletProvider.purchaseAkofaWithMpesa(
          phoneNumber: phoneNumber,
          amountKES: _selectedAmount,
        );

        if (result['success'] == true) {
          Navigator.pop(context);
          _showPaymentPendingDialog(result, 'M-Pesa');
        } else {
          setState(() {
            _error = result['error'] ?? 'Failed to initiate M-Pesa purchase';
          });
        }
      } else if (_selectedProvider == 'MTN') {
        // MTN payment processing removed - Flutterwave integration no longer available
        setState(() {
          _error =
              'MTN payment processing is currently unavailable - Flutterwave integration removed';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showPaymentPendingDialog(Map<String, dynamic> result, String provider) {
    final akofaAmount = result['akofaAmount'] ?? 0.0;
    final localAmount = result['localAmount'] ?? _selectedAmount;
    final currencySymbol = _getCurrencySymbol();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text(
          'Payment Initiated',
          style: TextStyle(color: AppTheme.primaryGold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_android, color: AppTheme.primaryGold, size: 48),
            const SizedBox(height: 16),
            Text(
              'Check your phone for the $provider payment prompt.',
              style: TextStyle(color: AppTheme.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Amount: $currencySymbol ${localAmount.toInt()}',
              style: TextStyle(color: AppTheme.grey),
            ),
            Text(
              'Tokens: ${akofaAmount.toStringAsFixed(2)} AKOFA',
              style: TextStyle(color: AppTheme.primaryGold),
            ),
            const SizedBox(height: 16),
            Text(
              'Payment should complete within 5-10 minutes.',
              style: TextStyle(color: AppTheme.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppTheme.primaryGold)),
          ),
        ],
      ),
    );
  }
}
