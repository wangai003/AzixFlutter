import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stellar_provider.dart';
import '../theme/app_theme.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_functions/cloud_functions.dart';

class BuyDialog extends StatefulWidget {
  const BuyDialog({Key? key}) : super(key: key);

  @override
  State<BuyDialog> createState() => _BuyDialogState();
}

class _BuyDialogState extends State<BuyDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String _selectedMethod = 'mpesa';
  String? _successMessage;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppTheme.black,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SizedBox(
          width: 350,
          child: _successMessage != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 48),
                    const SizedBox(height: 16),
                    Text(_successMessage!, style: TextStyle(color: Colors.green, fontSize: 18)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Close'),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Buy Akofa Coin', style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('M-Pesa'),
                            selected: _selectedMethod == 'mpesa',
                            onSelected: (selected) {
                              setState(() => _selectedMethod = 'mpesa');
                            },
                          ),
                          const SizedBox(width: 12),
                          ChoiceChip(
                            label: const Text('Card'),
                            selected: _selectedMethod == 'card',
                            onSelected: (selected) {
                              setState(() => _selectedMethod = 'card');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_selectedMethod == 'mpesa')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: AppTheme.darkGrey.withOpacity(0.3),
                            ),
                            style: TextStyle(color: AppTheme.white),
                          ),
                        ),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Amount of Akofa',
                          labelStyle: TextStyle(color: AppTheme.grey),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: AppTheme.darkGrey.withOpacity(0.3),
                        ),
                        style: TextStyle(color: AppTheme.white),
                      ),
                      const SizedBox(height: 16),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(_error!, style: TextStyle(color: Colors.red)),
                        ),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _buyAkofa,
                                child: Text('Buy with ${_selectedMethod == 'mpesa' ? 'M-Pesa' : 'Card'}'),
                              ),
                            ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _buyAkofa() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() {
        _isLoading = false;
        _error = 'Enter a valid amount.';
      });
      return;
    }
    try {
      final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
      if (_selectedMethod == 'mpesa') {
        final phoneNumber = _phoneController.text.trim();
        if (phoneNumber.isEmpty) {
          setState(() {
            _isLoading = false;
            _error = 'Enter a valid phone number.';
          });
          return;
        }
        final mpesaResult = await stellarProvider.initiateMpesaPayment(phoneNumber, amount);
        if (mpesaResult['success'] == true) {
          await stellarProvider.creditUserAsset('AKOFA', amount);
          setState(() {
            _isLoading = false;
            _successMessage = 'Purchase successful! $amount Akofa Coin credited.';
          });
        } else {
          setState(() {
            _isLoading = false;
            _error = mpesaResult['message'] ?? 'M-Pesa payment failed.';
          });
        }
      } else {
        // Stripe/Card payment
        // 1. Call backend to create PaymentIntent
        final response = await FirebaseFunctions.instance.httpsCallable('createPaymentIntent').call({
          'amount': (amount * 100).toInt(), // Stripe expects cents
          'currency': 'usd',
        });
        final clientSecret = response.data['clientSecret'];
        // 2. Present the payment sheet
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: 'AZIX',
          ),
        );
        await Stripe.instance.presentPaymentSheet();
        // 3. On success, credit Akofa Coin
        await stellarProvider.creditUserAsset('AKOFA', amount);
        setState(() {
          _isLoading = false;
          _successMessage = 'Purchase successful! $amount Akofa Coin credited.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to complete purchase: $e';
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}