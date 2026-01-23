import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../services/pesapal_service.dart';
import '../services/currency_service.dart';
import '../theme/app_theme.dart';
import 'pesapal_payment_webview.dart';

/// Card Payment Dialog for token purchases via PesaPal
///
/// Allows users to purchase AKOFA, USDC, or USDT tokens using credit/debit cards
/// through the PesaPal payment gateway.
/// 
/// Supports two modes:
/// 1. Legacy mode: Pass akofaAmount, userId, email, etc. directly
/// 2. New mode: Pass walletProvider and optional pre-selected token parameters
class CardPaymentDialog extends StatefulWidget {
  // Legacy parameters (optional)
  final double? akofaAmount;
  final String? userId;
  final String? email;
  final String? phoneNumber;
  final String? countryCode;
  
  // New mode parameters
  final dynamic walletProvider; // EnhancedWalletProvider
  
  // Pre-selected token parameters (from multi-token dialog)
  final String? tokenSymbol;
  final double? tokenAmount;
  final double? amountKES;
  final double? pricePerTokenKES;
  final String? priceLockId;

  const CardPaymentDialog({
    super.key,
    this.akofaAmount,
    this.userId,
    this.email,
    this.phoneNumber,
    this.countryCode,
    this.walletProvider,
    this.tokenSymbol,
    this.tokenAmount,
    this.amountKES,
    this.pricePerTokenKES,
    this.priceLockId,
  });

  @override
  State<CardPaymentDialog> createState() => _CardPaymentDialogState();
}

class _CardPaymentDialogState extends State<CardPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pesapalService = PesapalService();

  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _customAmountController = TextEditingController();

  bool _isLoading = false;
  bool _isCheckingStatus = false;
  String? _selectedCurrency = 'KES';
  late double _amountKES;
  late String _selectedToken;
  late double _tokenAmount;
  late double? _pricePerTokenKES;
  Map<String, double> _currencyPrices = {};
  String? _currentOrderTrackingId;

  // Preset purchase amounts in KES
  final List<double> _presetAmounts = [10, 50, 100, 500, 1000, 5000, 10000, 50000];

  @override
  void initState() {
    super.initState();
    
    // Initialize with pre-selected values if available (new mode)
    _selectedToken = widget.tokenSymbol ?? 'AKOFA';
    _pricePerTokenKES = widget.pricePerTokenKES;
    
    // Set amount - prefer explicit amountKES, then calculate from akofaAmount
    if (widget.amountKES != null) {
      _amountKES = widget.amountKES!;
      _tokenAmount = widget.tokenAmount ?? (_amountKES / 5.52);
    } else if (widget.akofaAmount != null) {
      _amountKES = widget.akofaAmount! * 5.52; // Convert AKOFA to KES
      _tokenAmount = widget.akofaAmount!;
    } else {
      _amountKES = 10.0;
      _tokenAmount = _amountKES / 5.52;
    }
    
    // Set initial values from legacy or new mode
    _emailController.text = widget.email ?? '';
    _phoneController.text = widget.phoneNumber ?? '';
    _customAmountController.text = _amountKES.toStringAsFixed(0);
    _loadCurrencyPrices();
  }
  
  // Token conversion rate (1 AKOFA = 5.52 KES for AKOFA token)
  double get _tokenConversionRate {
    if (_pricePerTokenKES != null) return 1.0 / _pricePerTokenKES!;
    return _selectedToken == 'AKOFA' ? (1 / 5.52) : 1.0 / 155.0; // Default rates
  }
  
  // Check if we have pre-selected values from token dialog
  bool get _hasPreselectedValues => widget.tokenSymbol != null && widget.tokenAmount != null && widget.amountKES != null;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _customAmountController.dispose();
    _pesapalService.dispose();
    super.dispose();
  }

  Future<void> _loadCurrencyPrices() async {
    try {
      final popularCurrencies = CurrencyService.getPopularCurrenciesForRegion(
        'global',
      );
      
      // Calculate USD equivalent first
      final tokenAmountForPrice = _amountKES * _tokenConversionRate;
      final usdAmount = tokenAmountForPrice * 0.10; // Approximate USD value
      
      _currencyPrices = await CurrencyService.getAkofaPricesInCurrencies(
        usdAmount,
        popularCurrencies,
      );

      // Ensure KES is always available
      _currencyPrices['KES'] = _amountKES;

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading currency prices: $e');
    }
  }

  double get _displayTokenAmount => _amountKES * _tokenConversionRate;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.darkGrey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(maxWidth: 500, maxHeight: _hasPreselectedValues ? 550 : 700),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                // Only show amount section if no pre-selected values
                if (!_hasPreselectedValues) ...[
                  _buildAmountSection(),
                  const SizedBox(height: 24),
                ],
                _buildConversionDisplay(),
                const SizedBox(height: 24),
                _buildContactInfo(),
                const SizedBox(height: 24),
                _buildInfoBox(),
                const SizedBox(height: 24),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
                Row(
                  children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                      Icons.credit_card,
                      color: AppTheme.primaryGold,
                      size: 28,
              ),
                    ),
                    const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                    Text(
                  _hasPreselectedValues ? 'Confirm Card Payment' : 'Card Payment',
                      style: AppTheme.headingMedium.copyWith(
                        color: AppTheme.primaryGold,
                      ),
                ),
                Text(
                  _hasPreselectedValues 
                    ? 'Enter your details to complete payment'
                    : 'Powered by PesaPal',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                ),
              ],
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.close, color: AppTheme.grey),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildAmountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Amount (KES)',
          style: AppTheme.bodyLarge.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        
        // Preset amounts grid
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presetAmounts.map((amount) {
            final isSelected = _amountKES == amount;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _amountKES = amount;
                  _customAmountController.text = amount.toStringAsFixed(0);
                });
                _loadCurrencyPrices();
              },
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
                  'KES ${_formatAmount(amount)}',
                  style: AppTheme.bodyMedium.copyWith(
                    color: isSelected ? AppTheme.black : AppTheme.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        
        const SizedBox(height: 16),
        
        // Custom amount input
        TextFormField(
          controller: _customAmountController,
          style: TextStyle(color: AppTheme.white),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Custom Amount (KES)',
            labelStyle: TextStyle(color: AppTheme.grey),
            prefixIcon: Icon(Icons.attach_money, color: AppTheme.primaryGold),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryGold),
            ),
            hintText: 'Min: 100, Max: 500,000',
            hintStyle: TextStyle(color: AppTheme.grey.withOpacity(0.5)),
          ),
          onChanged: (value) {
            final amount = double.tryParse(value);
            if (amount != null && amount >= 100 && amount <= 500000) {
              setState(() => _amountKES = amount);
              _loadCurrencyPrices();
            }
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter an amount';
            }
            final amount = double.tryParse(value);
            if (amount == null || amount < 100) {
              return 'Minimum amount is KES 100';
            }
            if (amount > 500000) {
              return 'Maximum amount is KES 500,000';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildConversionDisplay() {
    return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
        color: AppTheme.primaryGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryGold.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
          // Price Lock indicator (if pre-selected from token dialog)
          if (_hasPreselectedValues && widget.priceLockId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Price Locked',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                'You Pay',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                          ),
                          Text(
                'KES ${_formatAmount(_amountKES)}',
                            style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.white,
                  fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
          const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                'You Receive',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _selectedToken,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                          Text(
                    _tokenAmount.toStringAsFixed(_selectedToken == 'AKOFA' ? 2 : 6),
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          const SizedBox(height: 8),
          Divider(color: AppTheme.primaryGold.withOpacity(0.2)),
          const SizedBox(height: 8),
          Text(
            _hasPreselectedValues && _pricePerTokenKES != null
              ? 'Rate: KES ${_pricePerTokenKES!.toStringAsFixed(2)} = 1 $_selectedToken'
              : 'Rate: 1 AKOFA = 5.52 KES',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.grey.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact Information',
          style: AppTheme.bodyLarge.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        
        // Email field (required)
                TextFormField(
          controller: _emailController,
                  style: TextStyle(color: AppTheme.white),
          keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
            labelText: 'Email Address *',
            labelStyle: TextStyle(color: AppTheme.grey),
            prefixIcon: Icon(Icons.email, color: AppTheme.primaryGold),
                    enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryGold),
            ),
          ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
              return 'Email is required';
                    }
            if (!value.contains('@')) {
              return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
        
                const SizedBox(height: 16),

        // Name fields row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                controller: _firstNameController,
                        style: TextStyle(color: AppTheme.white),
                textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                  labelText: 'First Name',
                  labelStyle: TextStyle(color: AppTheme.grey),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.primaryGold),
                            ),
                          ),
                        ),
            ),
            const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                controller: _lastNameController,
                        style: TextStyle(color: AppTheme.white),
                textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                  labelText: 'Last Name',
                  labelStyle: TextStyle(color: AppTheme.grey),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.primaryGold),
                  ),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Phone number (optional)
        TextFormField(
          controller: _phoneController,
          style: TextStyle(color: AppTheme.white),
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Phone Number (Optional)',
            labelStyle: TextStyle(color: AppTheme.grey),
            prefixIcon: Icon(Icons.phone, color: AppTheme.primaryGold),
            hintText: '0712345678',
            hintStyle: TextStyle(color: AppTheme.grey.withOpacity(0.5)),
                          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryGold),
                            ),
                          ),
                        ),
      ],
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Secure Card Payment',
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You will be redirected to PesaPal\'s secure payment page to complete your transaction. Supports Visa, Mastercard, and other major cards.',
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.blue.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCardLogo('assets/images/visa.png', 'Visa'),
              const SizedBox(width: 16),
              _buildCardLogo('assets/images/mastercard.png', 'MC'),
              const SizedBox(width: 16),
              Icon(Icons.lock, color: Colors.green, size: 20),
              const SizedBox(width: 4),
              Text(
                'SSL Secured',
                style: AppTheme.bodySmall.copyWith(color: Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardLogo(String asset, String label) {
    // Using placeholder icons since actual card logos need assets
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTheme.bodySmall.copyWith(
          color: AppTheme.white,
          fontWeight: FontWeight.bold,
        ),
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
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: AppTheme.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
          flex: 2,
                      child: ElevatedButton(
            onPressed: _isLoading ? null : _initiatePayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold,
                          foregroundColor: AppTheme.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                    width: 24,
                    height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.credit_card, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Pay KES ${_formatAmount(_amountKES)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  Future<void> _initiatePayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final walletAddress = widget.walletProvider?.address as String?;
      if (walletAddress == null || walletAddress.isEmpty) {
        _showError('Please create a Polygon wallet before purchasing tokens.');
        return;
      }

      final result = await _pesapalService.initiateCardPayment(
        amountKES: _amountKES,
        tokenAmount: _tokenAmount,
        tokenSymbol: _selectedToken,
        email: _emailController.text.trim(),
        walletAddress: walletAddress,
        phone: _phoneController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        countryCode: widget.countryCode ?? 'KE',
        pricePerTokenKES: _pricePerTokenKES,
        priceLockId: widget.priceLockId,
      );

      if (result['success'] == true) {
        final redirectUrl = result['redirectUrl'] as String?;
        final orderTrackingId = result['orderTrackingId'] as String?;

        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          _currentOrderTrackingId = orderTrackingId;
          
          // Close this dialog
          if (mounted) Navigator.pop(context);
          
          // Open PesaPal payment page in-app webview
          if (mounted) {
            final webViewResult = await showPesapalPaymentWebView(
              context: context,
              paymentUrl: redirectUrl,
              orderTrackingId: orderTrackingId ?? '',
              amount: _amountKES,
              tokenAmount: result['tokenAmount'] as double? ?? _tokenAmount,
              tokenSymbol: result['tokenSymbol'] as String? ?? _selectedToken,
              currency: 'KES',
            );
            
            // Handle the result from webview
            if (webViewResult != null) {
              if (webViewResult['status'] == 'completed') {
                _showSuccessMessage(
                  webViewResult['tokenAmount'] as double? ?? _tokenAmount,
                  txHash: webViewResult['txHash'] as String?,
                  tokenSymbol: webViewResult['tokenSymbol'] as String? ?? _selectedToken,
                );
              } else if (webViewResult['checkStatus'] == true) {
                // User wants to check payment status
                _showPaymentPendingDialog(
                  orderTrackingId: orderTrackingId ?? '',
                  tokenAmount: result['tokenAmount'] as double? ?? _tokenAmount,
                  tokenSymbol: result['tokenSymbol'] as String? ?? _selectedToken,
                  amountKES: _amountKES,
                );
              }
            }
          }
        } else {
          _showError('No payment URL received');
        }
      } else {
        _showError(result['error'] ?? 'Failed to initiate payment');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessMessage(double tokenAmount, {String? txHash, String? tokenSymbol}) {
    if (!mounted) return;
    
    final symbol = tokenSymbol ?? _selectedToken;
    final decimals = symbol == 'AKOFA' ? 2 : 6;
    final txHashDisplay = txHash != null && txHash.isNotEmpty 
        ? '\nTx: ${txHash.substring(0, 8)}...${txHash.substring(txHash.length - 6)}'
        : '';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Successful! ✓',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              '${tokenAmount.toStringAsFixed(decimals)} $symbol credited to your wallet',
            ),
            if (txHash != null && txHash.isNotEmpty)
              Text(
                'Tx: ${txHash.substring(0, 10)}...${txHash.substring(txHash.length - 6)}',
                style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showPaymentPendingDialog({
    required String orderTrackingId,
    required double tokenAmount,
    required String tokenSymbol,
    required double amountKES,
  }) {
    final decimals = tokenSymbol == 'AKOFA' ? 2 : 6;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: AppTheme.darkGrey,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.credit_card, color: AppTheme.primaryGold),
                const SizedBox(width: 12),
                Text(
                  'Payment Initiated',
                  style: TextStyle(color: AppTheme.primaryGold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.open_in_browser,
                        color: AppTheme.primaryGold,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Complete your payment on PesaPal',
                        style: TextStyle(color: AppTheme.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Amount:',
                            style: TextStyle(color: AppTheme.grey),
                          ),
                          Text(
                            'KES ${amountKES.toInt()}',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tokens:',
                            style: TextStyle(color: AppTheme.grey),
                          ),
                          Text(
                            '${tokenAmount.toStringAsFixed(decimals)} $tokenSymbol',
                            style: TextStyle(
                              color: AppTheme.primaryGold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Click "Check Status" after completing payment.',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: _isCheckingStatus
                    ? null
                    : () async {
                        setDialogState(() => _isCheckingStatus = true);
                        
                        final status = await _pesapalService.queryPaymentStatus(
                          orderTrackingId: orderTrackingId,
                        );
                        
                        setDialogState(() => _isCheckingStatus = false);
                        
                        if (!mounted) return;
                        
                        if (status['status'] == 'completed') {
                          Navigator.pop(dialogContext);
                          final completedTokenAmount = (status['tokenAmount'] as num?)?.toDouble() ?? tokenAmount;
                          final completedTokenSymbol = status['tokenSymbol'] as String? ?? tokenSymbol;
                          final completedDecimals = completedTokenSymbol == 'AKOFA' ? 2 : 6;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Payment successful! ${completedTokenAmount.toStringAsFixed(completedDecimals)} $completedTokenSymbol credited.',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else if (status['status'] == 'failed') {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                status['message'] ?? 'Payment failed',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                status['message'] ?? 'Payment is still being processed...',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                child: _isCheckingStatus
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryGold,
                        ),
                      )
                    : Text(
                        'Check Status',
                        style: TextStyle(color: AppTheme.primaryGold),
                      ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Close',
                  style: TextStyle(color: AppTheme.grey),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
