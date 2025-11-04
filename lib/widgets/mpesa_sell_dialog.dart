import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/enhanced_wallet_provider.dart';
import '../theme/app_theme.dart';
import '../services/currency_service.dart';

class MpesaSellDialog extends StatefulWidget {
  final EnhancedWalletProvider walletProvider;

  const MpesaSellDialog({super.key, required this.walletProvider});

  @override
  State<MpesaSellDialog> createState() => _MpesaSellDialogState();
}

class _MpesaSellDialogState extends State<MpesaSellDialog>
    with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  double _selectedAmount = 100.0; // AKOFA amount to sell
  bool _isProcessing = false;
  bool _isCalculating = false;
  String? _error;
  Map<String, dynamic>? _sellEstimate;
  String _selectedCurrency = 'KES';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<double> _presetAmounts = [
    100,
    250,
    500,
    1000,
    2500,
    5000,
  ]; // AKOFA amounts

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _calculateSellEstimate();
    _amountController.text = _selectedAmount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _calculateSellEstimate() async {
    if (_selectedAmount <= 0) return;

    setState(() => _isCalculating = true);
    try {
      // Simulate API call for sell estimate
      await Future.delayed(const Duration(milliseconds: 500));

      final kesAmount = _selectedAmount * 100; // 1 AKOFA = 100 KES
      final fee = kesAmount * 0.02; // 2% fee
      final finalAmount = kesAmount - fee;

      setState(() {
        _sellEstimate = {
          'akofaAmount': _selectedAmount,
          'kesAmount': kesAmount,
          'fee': fee,
          'finalAmount': finalAmount,
          'exchangeRate': 100.0,
          'processingTime': '2-5 minutes',
        };
      });
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isCalculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final akofaBalance =
        double.tryParse(widget.walletProvider.akofaBalance) ?? 0.0;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        backgroundColor: AppTheme.darkGrey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 450, maxHeight: 700),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced Header with Animation
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGold.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.sell,
                            color: AppTheme.primaryGold,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sell AKOFA Tokens',
                              style: AppTheme.headingMedium.copyWith(
                                color: AppTheme.primaryGold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Convert to instant cash',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.grey,
                              ),
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
                ),

                const SizedBox(height: 24),

                // Dynamic Amount Selection with Slider
                _buildAmountSelector(akofaBalance),

                const SizedBox(height: 20),

                // Real-time Sell Estimate
                if (_sellEstimate != null) _buildSellEstimateCard(),

                const SizedBox(height: 20),

                // Phone Number Input with Validation
                _buildPhoneNumberField(),

                const SizedBox(height: 16),

                // Balance and Warnings
                _buildBalanceAndWarnings(akofaBalance),

                // Error Display
                if (_error != null) _buildErrorDisplay(),

                const SizedBox(height: 24),

                // Enhanced Action Buttons
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountSelector(double akofaBalance) {
    // Ensure minimum balance for slider
    final minAmount = 100.0;
    final maxAmount = akofaBalance.clamp(minAmount, 50000.0);

    // Adjust selected amount if it's outside bounds
    if (_selectedAmount < minAmount) {
      _selectedAmount = minAmount;
    } else if (_selectedAmount > maxAmount) {
      _selectedAmount = maxAmount;
    }

    // Calculate divisions safely
    final range = maxAmount - minAmount;
    final divisions = range > 0 ? (range / 50).round().clamp(1, 100) : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select Amount',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${_selectedAmount.toInt()} AKOFA',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.primaryGold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Slider for amount selection
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppTheme.primaryGold,
            inactiveTrackColor: AppTheme.grey.withOpacity(0.3),
            thumbColor: AppTheme.primaryGold,
            overlayColor: AppTheme.primaryGold.withOpacity(0.2),
            valueIndicatorColor: AppTheme.primaryGold,
            valueIndicatorTextStyle: TextStyle(color: AppTheme.black),
          ),
          child: Slider(
            value: _selectedAmount,
            min: minAmount,
            max: maxAmount,
            divisions: divisions,
            label: '${_selectedAmount.toInt()} AKOFA',
            onChanged: (value) {
              setState(() => _selectedAmount = value);
              _calculateSellEstimate();
            },
          ),
        ),

        const SizedBox(height: 12),

        // Quick preset buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presetAmounts
              .where((amount) => amount <= akofaBalance)
              .map((amount) {
                final isSelected = (_selectedAmount - amount).abs() < 1;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedAmount = amount.toDouble());
                      _calculateSellEstimate();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryGold
                            : AppTheme.darkGrey.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryGold
                              : AppTheme.primaryGold.withOpacity(0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        '${amount.toInt()}',
                        style: AppTheme.bodyMedium.copyWith(
                          color: isSelected ? AppTheme.black : AppTheme.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(),
        ),

        const SizedBox(height: 12),

        // Custom amount input
        TextFormField(
          controller: _amountController,
          style: TextStyle(color: AppTheme.white),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Or enter custom amount',
            labelStyle: TextStyle(color: AppTheme.grey),
            prefixIcon: Icon(Icons.edit, color: AppTheme.primaryGold),
            suffixText: 'AKOFA',
            suffixStyle: TextStyle(color: AppTheme.primaryGold),
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
            if (amount != null &&
                amount >= 100 &&
                amount <= akofaBalance &&
                amount <= 50000) {
              setState(() => _selectedAmount = amount);
              _calculateSellEstimate();
            }
          },
        ),
      ],
    );
  }

  Widget _buildSellEstimateCard() {
    if (_sellEstimate == null) return const SizedBox();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGold.withOpacity(0.1),
            AppTheme.primaryGold.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sell Summary',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isCalculating)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryGold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEstimateRow(
            'Selling',
            '${_sellEstimate!['akofaAmount'].toInt()} AKOFA',
          ),
          _buildEstimateRow(
            'Exchange Rate',
            '1 AKOFA = ${_sellEstimate!['exchangeRate']} KES',
          ),
          _buildEstimateRow(
            'Gross Amount',
            'KES ${_sellEstimate!['kesAmount'].toInt()}',
          ),
          _buildEstimateRow(
            'Processing Fee (2%)',
            '-KES ${_sellEstimate!['fee'].toInt()}',
            color: Colors.red,
          ),
          const Divider(color: AppTheme.primaryGold, height: 16),
          _buildEstimateRow(
            'You Receive',
            'KES ${_sellEstimate!['finalAmount'].toInt()}',
            isBold: true,
            color: AppTheme.primaryGold,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, color: AppTheme.grey, size: 16),
              const SizedBox(width: 4),
              Text(
                'Processing time: ${_sellEstimate!['processingTime']}',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
              ),
            ],
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
      padding: const EdgeInsets.only(bottom: 8),
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
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneNumberField() {
    return TextFormField(
      controller: _phoneController,
      style: TextStyle(color: AppTheme.white),
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: 'M-Pesa Phone Number',
        labelStyle: TextStyle(color: AppTheme.grey),
        hintText: '0712345678 or 254712345678',
        hintStyle: TextStyle(color: AppTheme.grey.withOpacity(0.5)),
        prefixIcon: Icon(Icons.phone_android, color: AppTheme.primaryGold),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryGold),
        ),
        suffixIcon:
            _phoneController.text.isNotEmpty &&
                _validatePhoneNumber(_phoneController.text) == null
            ? Icon(Icons.check_circle, color: Colors.green)
            : null,
      ),
      validator: _validatePhoneNumber,
      onChanged: (value) => setState(() {}),
    );
  }

  Widget _buildBalanceAndWarnings(double akofaBalance) {
    return Column(
      children: [
        // Balance Info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.blue, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Balance',
                      style: AppTheme.bodySmall.copyWith(color: Colors.blue),
                    ),
                    Text(
                      '${akofaBalance.toStringAsFixed(2)} AKOFA',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Warnings
        if (_selectedAmount > akofaBalance * 0.8) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You\'re selling more than 80% of your balance. Consider keeping some tokens for transactions.',
                    style: AppTheme.bodySmall.copyWith(color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorDisplay() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: AppTheme.bodySmall.copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final isValid =
        _phoneController.text.isNotEmpty &&
        _validatePhoneNumber(_phoneController.text) == null &&
        _selectedAmount >= 100;

    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _isProcessing ? null : () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.grey, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: (_isProcessing || !isValid) ? null : _initiateSell,
            style: ElevatedButton.styleFrom(
              backgroundColor: isValid ? AppTheme.primaryGold : AppTheme.grey,
              foregroundColor: isValid ? AppTheme.black : AppTheme.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: isValid ? 4 : 0,
            ),
            child: _isProcessing
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
                      Icon(Icons.swap_horiz, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Sell Tokens',
                        style: TextStyle(
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

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter phone number';
    }

    if (value.length < 9 || value.length > 12) {
      return 'Invalid phone number length';
    }

    return null;
  }

  Future<void> _initiateSell() async {
    final phoneNumber = _phoneController.text.trim();
    final akofaBalance =
        double.tryParse(widget.walletProvider.akofaBalance) ?? 0.0;

    if (phoneNumber.isEmpty) {
      setState(() => _error = 'Please enter phone number');
      return;
    }

    if (_selectedAmount < 100) {
      setState(() => _error = 'Minimum sell amount is 100 AKOFA');
      return;
    }

    if (_selectedAmount > akofaBalance) {
      setState(() => _error = 'Insufficient AKOFA balance');
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final result = await widget.walletProvider.sellAkofaWithMpesa(
        phoneNumber: phoneNumber,
        akofaAmount: _selectedAmount,
      );

      if (result['success'] == true) {
        Navigator.pop(context);
        _showSellPendingDialog(result);
      } else {
        setState(() {
          _error = result['error'] ?? 'Failed to initiate sell transaction';
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

  void _showSellPendingDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text(
          'Sell Transaction Initiated',
          style: TextStyle(color: AppTheme.primaryGold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz, color: AppTheme.primaryGold, size: 48),
            const SizedBox(height: 16),
            Text(
              'Your sell transaction has been initiated. You will receive M-Pesa payment shortly.',
              style: TextStyle(color: AppTheme.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Amount Sold: ${_selectedAmount.toInt()} AKOFA',
              style: TextStyle(color: AppTheme.grey),
            ),
            Text(
              'Payment: KES ${(_selectedAmount * 100).toInt()}',
              style: TextStyle(color: AppTheme.primaryGold),
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
