import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/enhanced_wallet_provider.dart';
import '../theme/app_theme.dart';

class MpesaPurchaseDialog extends StatefulWidget {
  final EnhancedWalletProvider walletProvider;

  const MpesaPurchaseDialog({
    super.key,
    required this.walletProvider,
  });

  @override
  State<MpesaPurchaseDialog> createState() => _MpesaPurchaseDialogState();
}

class _MpesaPurchaseDialogState extends State<MpesaPurchaseDialog> {
  final _phoneController = TextEditingController();
  double _selectedAmount = 100.0;
  bool _isProcessing = false;
  String? _error;

  final List<double> _presetAmounts = [100, 500, 1000, 5000];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.darkGrey,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
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
              'Purchase AKOFA tokens instantly using M-Pesa',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.grey,
              ),
            ),

            const SizedBox(height: 24),

            // Amount Selection
            Text(
              'Select Amount (KES)',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Preset Amounts
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetAmounts.map((amount) {
                final isSelected = _selectedAmount == amount;
                return GestureDetector(
                  onTap: () => setState(() => _selectedAmount = amount),
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
                      'KES ${amount.toInt()}',
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

            // Custom Amount
            TextFormField(
              initialValue: _selectedAmount.toStringAsFixed(0),
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
              ),
              onChanged: (value) {
                final amount = double.tryParse(value);
                if (amount != null && amount >= 100 && amount <= 50000) {
                  setState(() => _selectedAmount = amount);
                }
              },
            ),

            const SizedBox(height: 16),

            // Conversion Display
            Container(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'You Pay',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.grey,
                        ),
                      ),
                      Text(
                        'KES ${_selectedAmount.toInt()}',
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
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.grey,
                        ),
                      ),
                      Text(
                        '${(_selectedAmount * 0.01).toStringAsFixed(2)} AKOFA',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.primaryGold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rate: 100 KES = 1 AKOFA',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.grey.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Phone Number
            TextFormField(
              controller: _phoneController,
              style: TextStyle(color: AppTheme.white),
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'M-Pesa Phone Number',
                labelStyle: TextStyle(color: AppTheme.grey),
                hintText: '0712345678',
                hintStyle: TextStyle(color: AppTheme.grey.withOpacity(0.5)),
                prefixIcon: Icon(Icons.phone, color: AppTheme.primaryGold),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryGold),
                ),
              ),
              validator: _validatePhoneNumber,
            ),

            const SizedBox(height: 16),

            // Information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You will receive an M-Pesa prompt on your phone to complete the payment.',
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.red,
                        ),
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
                    onPressed: _isProcessing ? null : () => Navigator.pop(context),
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
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

  Future<void> _initiatePurchase() async {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) {
      setState(() => _error = 'Please enter phone number');
      return;
    }

    if (_selectedAmount < 100) {
      setState(() => _error = 'Minimum purchase amount is KES 100');
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final result = await widget.walletProvider.purchaseAkofaWithMpesa(
        phoneNumber: phoneNumber,
        amountKES: _selectedAmount,
      );

      if (result['success'] == true) {
        Navigator.pop(context);
        _showPaymentPendingDialog(result);
      } else {
        setState(() {
          _error = result['error'] ?? 'Failed to initiate purchase';
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

  void _showPaymentPendingDialog(Map<String, dynamic> result) {
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
            Icon(
              Icons.phone_android,
              color: AppTheme.primaryGold,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Check your phone for the M-Pesa payment prompt.',
              style: TextStyle(color: AppTheme.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Amount: KES ${_selectedAmount.toInt()}',
              style: TextStyle(color: AppTheme.grey),
            ),
            Text(
              'Tokens: ${(_selectedAmount * 0.01).toStringAsFixed(2)} AKOFA',
              style: TextStyle(color: AppTheme.primaryGold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: AppTheme.primaryGold),
            ),
          ),
        ],
      ),
    );
  }
}