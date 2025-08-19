import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/cart_provider.dart';
import '../providers/marketplace_provider.dart';
import '../providers/stellar_provider.dart';
import '../theme/app_theme.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({Key? key}) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    
    final cart = Provider.of<CartProvider>(context, listen: false);
    final marketplace = Provider.of<MarketplaceProvider>(context, listen: false);
    final stellar = Provider.of<StellarProvider>(context, listen: false);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to complete checkout.'))
      );
      return;
    }

    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty.'))
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // Check if user has sufficient AKOFA balance
      await stellar.refreshBalance();
      final userBalance = double.tryParse(stellar.akofaBalance) ?? 0.0;
      final totalAmount = cart.totalPrice;

      if (userBalance < totalAmount) {
        setState(() => _loading = false);
        _showInsufficientBalanceDialog(context, userBalance, totalAmount);
        return;
      }

      // Show payment confirmation dialog
      final confirmed = await _showPaymentConfirmationDialog(context, totalAmount);
      if (!confirmed) {
        setState(() => _loading = false);
        return;
      }

      // Process payment using MarketplaceProvider
      final paymentResult = await marketplace.processCartPayment(
        cartItems: cart.items,
        shippingInfo: {
          'name': _nameController.text.trim(),
          'address': _addressController.text.trim(),
          'phone': _phoneController.text.trim(),
        },
      );

      setState(() => _loading = false);

      if (paymentResult['success'] == true) {
        // Clear cart and show success
        cart.clearCart();
        
        if (mounted) {
          _showSuccessDialog(context, paymentResult);
        }
      } else {
        // Show error
        if (mounted) {
          _showErrorDialog(context, paymentResult['error'] ?? 'Payment failed');
        }
      }

    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        _showErrorDialog(context, e.toString());
      }
    }
  }

  Future<bool> _showPaymentConfirmationDialog(BuildContext context, double amount) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.white,
        title: Row(
          children: [
            Icon(Icons.payment, color: AppTheme.primaryGold, size: 28),
            const SizedBox(width: 8),
            const Text('Confirm Payment'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Amount: ${amount.toStringAsFixed(6)} AKOFA'),
            const SizedBox(height: 8),
            Text(
              'This payment will be processed using your AKOFA tokens via the Stellar blockchain.',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: AppTheme.black,
            ),
            child: const Text('Pay with AKOFA'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showInsufficientBalanceDialog(BuildContext context, double balance, double required) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.white,
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            const Text('Insufficient Balance'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your AKOFA Balance: ${balance.toStringAsFixed(6)}'),
            Text('Required Amount: ${required.toStringAsFixed(6)}'),
            const SizedBox(height: 8),
            Text(
              'You need ${(required - balance).toStringAsFixed(6)} more AKOFA to complete this purchase.',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to buy AKOFA screen or wallet
              Navigator.of(context).pushReplacementNamed('/wallet');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: AppTheme.black,
            ),
            child: const Text('Get AKOFA'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, Map<String, dynamic> paymentResult) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.white,
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 8),
            const Text('Payment Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your order has been placed and paid successfully!'),
            const SizedBox(height: 8),
            Text('Order ID: ${paymentResult['orderId']}'),
            Text('Amount Paid: ${paymentResult['totalAmount'].toStringAsFixed(6)} AKOFA'),
            const SizedBox(height: 8),
            Text(
              'Vendors have been notified and will begin processing your order.',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close checkout
              Navigator.of(context).pop(); // Close cart
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: AppTheme.black,
            ),
            child: const Text('Continue Shopping'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.white,
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            const Text('Payment Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sorry, we could not process your payment.'),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTheme.bodyMedium.copyWith(color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: Text('Checkout', style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Text('Shipping Information', style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: 'Full Name'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(labelText: 'Address'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(labelText: 'Phone Number'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),
                    Divider(color: AppTheme.lightGrey),
                    const SizedBox(height: 12),
                    Text('Order Summary', style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold)),
                    ...cart.items.map((item) => ListTile(
                          title: Text(item.product.name, style: AppTheme.bodyMedium),
                          subtitle: Text('x${item.quantity}', style: AppTheme.bodySmall),
                          trailing: Text('Ksh ${item.product.price * item.quantity}', style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryGold)),
                        )),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total:', style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold)),
                        Text('Ksh ${cart.totalPrice}', style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primaryGold)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold,
                          foregroundColor: AppTheme.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: cart.items.isEmpty ? null : () => _submitOrder(context),
                        child: const Text('Confirm Order'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 