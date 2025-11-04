import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/paychant_service.dart';
import '../services/currency_service.dart';
import '../theme/app_theme.dart';
import '../providers/enhanced_wallet_provider.dart';

class TokenSellDialog extends StatefulWidget {
  const TokenSellDialog({super.key});

  @override
  State<TokenSellDialog> createState() => _TokenSellDialogState();
}

class _TokenSellDialogState extends State<TokenSellDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tokenAmountController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryMonthController = TextEditingController();
  final _expiryYearController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cardNameController = TextEditingController();
  final _bankCodeController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();

  String _selectedTokenType = 'AKOFA';
  String _selectedFiatCurrency = 'USD';
  String _selectedPayoutMethod = 'card';
  String _selectedNetwork = 'MTN';
  String _selectedCountry = 'KE';

  bool _isLoading = false;
  bool _isCalculating = false;
  Map<String, dynamic>? _payoutEstimate;
  Map<String, dynamic>? _supportedMethods;

  @override
  void initState() {
    super.initState();
    _loadSupportedMethods();
  }

  @override
  void dispose() {
    _tokenAmountController.dispose();
    _cardNumberController.dispose();
    _expiryMonthController.dispose();
    _expiryYearController.dispose();
    _cvvController.dispose();
    _cardNameController.dispose();
    _bankCodeController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadSupportedMethods() async {
    setState(() => _isLoading = true);
    try {
      final paychantService = PaychantService();
      final result = await paychantService.getSupportedPayoutMethods(
        _selectedCountry,
      );
      if (result['success']) {
        setState(() => _supportedMethods = result['methods']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load payout methods: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _calculateEstimate() async {
    final tokenAmount = double.tryParse(_tokenAmountController.text);
    if (tokenAmount == null || tokenAmount <= 0) return;

    setState(() => _isCalculating = true);
    try {
      final paychantService = PaychantService();
      final result = await paychantService.calculatePayoutEstimate(
        tokenType: _selectedTokenType,
        tokenAmount: tokenAmount,
        fiatCurrency: _selectedFiatCurrency,
        payoutMethod: _selectedPayoutMethod,
        countryCode: _selectedCountry,
      );

      if (result['success']) {
        setState(() => _payoutEstimate = result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to calculate estimate: $e')),
        );
      }
    } finally {
      setState(() => _isCalculating = false);
    }
  }

  Future<void> _initiateSell() async {
    if (!_formKey.currentState!.validate()) return;

    final tokenAmount = double.parse(_tokenAmountController.text);
    final walletProvider = Provider.of<EnhancedWalletProvider>(
      context,
      listen: false,
    );

    setState(() => _isLoading = true);

    try {
      final paychantService = PaychantService();

      // Build payout details based on selected method
      final payoutDetails = _buildPayoutDetails();

      final user = FirebaseAuth.instance.currentUser;
      final result = await paychantService.initiateTokenSale(
        userId: user?.uid ?? '',
        tokenType: _selectedTokenType,
        tokenAmount: tokenAmount,
        fiatCurrency: _selectedFiatCurrency,
        payoutMethod: _selectedPayoutMethod,
        payoutDetails: payoutDetails,
      );

      if (result['success']) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(result['error']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initiate sell: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _buildPayoutDetails() {
    switch (_selectedPayoutMethod) {
      case 'card':
        return {
          'cardNumber': _cardNumberController.text.replaceAll(' ', ''),
          'expiryMonth': _expiryMonthController.text,
          'expiryYear': _expiryYearController.text,
          'cvv': _cvvController.text,
          'cardName': _cardNameController.text,
        };
      case 'bank':
        return {
          'bankCode': _bankCodeController.text,
          'accountNumber': _accountNumberController.text,
          'accountName': _accountNameController.text,
        };
      case 'mobile_money':
        return {
          'phoneNumber': _phoneNumberController.text,
          'network': _selectedNetwork,
        };
      default:
        return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.darkGrey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
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
                    Icon(Icons.sell, color: AppTheme.primaryGold, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Sell Tokens for Cash',
                      style: AppTheme.headingMedium.copyWith(
                        color: AppTheme.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Convert your tokens to fiat currency and receive cash instantly',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                ),
                const SizedBox(height: 24),

                // Token Selection
                _buildTokenSelection(),
                const SizedBox(height: 16),

                // Amount Input
                _buildAmountInput(),
                const SizedBox(height: 16),

                // Currency Selection
                _buildCurrencySelection(),
                const SizedBox(height: 16),

                // Country Selection
                _buildCountrySelection(),
                const SizedBox(height: 16),

                // Payout Method Selection
                _buildPayoutMethodSelection(),
                const SizedBox(height: 16),

                // Payout Details Form
                _buildPayoutDetailsForm(),

                // Estimate Display
                if (_payoutEstimate != null) _buildEstimateDisplay(),

                const SizedBox(height: 24),

                // Action Buttons
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTokenSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Token',
          style: AppTheme.bodyLarge.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
          ),
          child: DropdownButton<String>(
            value: _selectedTokenType,
            dropdownColor: AppTheme.darkGrey,
            style: TextStyle(color: AppTheme.white),
            underline: const SizedBox(),
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'AKOFA', child: Text('AKOFA Tokens')),
              DropdownMenuItem(
                value: 'XLM',
                child: Text('Stellar Lumens (XLM)'),
              ),
            ],
            onChanged: (value) {
              setState(() => _selectedTokenType = value!);
              _calculateEstimate();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount to Sell',
          style: AppTheme.bodyLarge.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _tokenAmountController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: AppTheme.white),
          decoration: InputDecoration(
            hintText: 'Enter amount',
            hintStyle: TextStyle(color: AppTheme.grey),
            suffixText: _selectedTokenType,
            suffixStyle: TextStyle(color: AppTheme.primaryGold),
            filled: true,
            fillColor: AppTheme.black.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AppTheme.primaryGold.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AppTheme.primaryGold.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.primaryGold),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter an amount';
            }
            final amount = double.tryParse(value);
            if (amount == null || amount <= 0) {
              return 'Please enter a valid amount';
            }
            return null;
          },
          onChanged: (_) => _calculateEstimate(),
        ),
      ],
    );
  }

  Widget _buildCurrencySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Receive Currency',
          style: AppTheme.bodyLarge.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
          ),
          child: DropdownButton<String>(
            value: _selectedFiatCurrency,
            dropdownColor: AppTheme.darkGrey,
            style: TextStyle(color: AppTheme.white),
            underline: const SizedBox(),
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'USD', child: Text('US Dollar (USD)')),
              DropdownMenuItem(value: 'EUR', child: Text('Euro (EUR)')),
              DropdownMenuItem(
                value: 'GBP',
                child: Text('British Pound (GBP)'),
              ),
              DropdownMenuItem(
                value: 'KES',
                child: Text('Kenyan Shilling (KES)'),
              ),
              DropdownMenuItem(
                value: 'NGN',
                child: Text('Nigerian Naira (NGN)'),
              ),
              DropdownMenuItem(
                value: 'GHS',
                child: Text('Ghanaian Cedi (GHS)'),
              ),
              DropdownMenuItem(
                value: 'ZAR',
                child: Text('South African Rand (ZAR)'),
              ),
            ],
            onChanged: (value) {
              setState(() => _selectedFiatCurrency = value!);
              _calculateEstimate();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCountrySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Country',
          style: AppTheme.bodyLarge.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
          ),
          child: DropdownButton<String>(
            value: _selectedCountry,
            dropdownColor: AppTheme.darkGrey,
            style: TextStyle(color: AppTheme.white),
            underline: const SizedBox(),
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'KE', child: Text('Kenya')),
              DropdownMenuItem(value: 'NG', child: Text('Nigeria')),
              DropdownMenuItem(value: 'GH', child: Text('Ghana')),
              DropdownMenuItem(value: 'ZA', child: Text('South Africa')),
              DropdownMenuItem(value: 'UG', child: Text('Uganda')),
              DropdownMenuItem(value: 'TZ', child: Text('Tanzania')),
              DropdownMenuItem(value: 'US', child: Text('United States')),
              DropdownMenuItem(value: 'GB', child: Text('United Kingdom')),
              DropdownMenuItem(value: 'EU', child: Text('Europe')),
            ],
            onChanged: (value) {
              setState(() => _selectedCountry = value!);
              _loadSupportedMethods();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPayoutMethodSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payout Method',
          style: AppTheme.bodyLarge.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildMethodOption('card', 'Card', Icons.credit_card),
            const SizedBox(width: 8),
            _buildMethodOption('bank', 'Bank', Icons.account_balance),
            const SizedBox(width: 8),
            _buildMethodOption('mobile_money', 'Mobile', Icons.phone_android),
          ],
        ),
      ],
    );
  }

  Widget _buildMethodOption(String method, String label, IconData icon) {
    final isSelected = _selectedPayoutMethod == method;
    final isSupported = _supportedMethods?[method]?['supported'] ?? true;

    return Expanded(
      child: GestureDetector(
        onTap: isSupported
            ? () => setState(() => _selectedPayoutMethod = method)
            : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryGold.withOpacity(0.2)
                : AppTheme.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryGold
                  : (isSupported
                        ? AppTheme.primaryGold.withOpacity(0.3)
                        : Colors.grey),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSupported ? AppTheme.primaryGold : Colors.grey,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSupported ? AppTheme.white : Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPayoutDetailsForm() {
    switch (_selectedPayoutMethod) {
      case 'card':
        return _buildCardForm();
      case 'bank':
        return _buildBankForm();
      case 'mobile_money':
        return _buildMobileMoneyForm();
      default:
        return const SizedBox();
    }
  }

  Widget _buildCardForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Card Details',
          style: AppTheme.bodyLarge.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _cardNumberController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(19),
            _CardNumberFormatter(),
          ],
          style: TextStyle(color: AppTheme.white),
          decoration: _inputDecoration('Card Number', '1234 5678 9012 3456'),
          validator: (value) {
            if (value == null || value.replaceAll(' ', '').length < 13) {
              return 'Please enter a valid card number';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _expiryMonthController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                style: TextStyle(color: AppTheme.white),
                decoration: _inputDecoration('MM', '12'),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final month = int.tryParse(value);
                  if (month == null || month < 1 || month > 12) {
                    return 'Invalid month';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _expiryYearController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                style: TextStyle(color: AppTheme.white),
                decoration: _inputDecoration('YY', '25'),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final year = int.tryParse('20$value');
                  if (year == null || year < DateTime.now().year) {
                    return 'Expired';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _cvvController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                style: TextStyle(color: AppTheme.white),
                decoration: _inputDecoration('CVV', '123'),
                validator: (value) {
                  if (value == null || value.length < 3) {
                    return 'Invalid CVV';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _cardNameController,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: AppTheme.white),
          decoration: _inputDecoration('Cardholder Name', 'John Doe'),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter cardholder name';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildBankForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bank Details',
          style: AppTheme.bodyLarge.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _bankCodeController,
          style: TextStyle(color: AppTheme.white),
          decoration: _inputDecoration('Bank Code', '044'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter bank code';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _accountNumberController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(color: AppTheme.white),
          decoration: _inputDecoration('Account Number', '1234567890'),
          validator: (value) {
            if (value == null || value.length < 8) {
              return 'Please enter a valid account number';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _accountNameController,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: AppTheme.white),
          decoration: _inputDecoration('Account Name', 'John Doe'),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter account name';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildMobileMoneyForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mobile Money Details',
          style: AppTheme.bodyLarge.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
          ),
          child: DropdownButton<String>(
            value: _selectedNetwork,
            dropdownColor: AppTheme.darkGrey,
            style: TextStyle(color: AppTheme.white),
            underline: const SizedBox(),
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'MTN', child: Text('MTN Mobile Money')),
              DropdownMenuItem(value: 'Airtel', child: Text('Airtel Money')),
              DropdownMenuItem(value: 'M-Pesa', child: Text('M-Pesa')),
              DropdownMenuItem(value: 'Vodacom', child: Text('Vodacom')),
              DropdownMenuItem(value: 'Tigo', child: Text('Tigo Pesa')),
            ],
            onChanged: (value) => setState(() => _selectedNetwork = value!),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneNumberController,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: AppTheme.white),
          decoration: _inputDecoration('Phone Number', '+254712345678'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter phone number';
            }
            // Basic phone number validation
            if (!RegExp(
              r'^\+?[0-9]{10,15}$',
            ).hasMatch(value.replaceAll(' ', ''))) {
              return 'Please enter a valid phone number';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildEstimateDisplay() {
    if (_payoutEstimate == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryGold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payout Estimate',
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.primaryGold,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildEstimateRow(
            'Selling',
            '${_payoutEstimate!['tokenAmount']} ${_payoutEstimate!['tokenType']}',
          ),
          _buildEstimateRow(
            'Exchange Rate',
            '1 ${_payoutEstimate!['tokenType']} = ${CurrencyService.formatCurrency(_payoutEstimate!['exchangeRate'], _payoutEstimate!['fiatCurrency'])}',
          ),
          _buildEstimateRow(
            'Base Amount',
            CurrencyService.formatCurrency(
              _payoutEstimate!['baseFiatAmount'],
              _payoutEstimate!['fiatCurrency'],
            ),
          ),
          _buildEstimateRow(
            'Processing Fee',
            '-${CurrencyService.formatCurrency(_payoutEstimate!['payoutFee'], _payoutEstimate!['fiatCurrency'])}',
            color: Colors.red,
          ),
          const Divider(color: AppTheme.primaryGold, height: 16),
          _buildEstimateRow(
            'You Receive',
            CurrencyService.formatCurrency(
              _payoutEstimate!['finalAmount'],
              _payoutEstimate!['fiatCurrency'],
            ),
            isBold: true,
          ),
          const SizedBox(height: 8),
          Text(
            'Processing Time: ${_payoutEstimate!['processingTime']}',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEstimateRow(
    String label,
    String value, {
    Color? color,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.grey,
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? AppTheme.white,
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Cancel', style: TextStyle(color: AppTheme.grey)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _initiateSell,
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
                : const Text(
                    'Sell Tokens',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppTheme.primaryGold),
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.grey),
      filled: true,
      fillColor: AppTheme.black.withOpacity(0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppTheme.primaryGold),
      ),
    );
  }
}

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
