import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/cart_provider.dart';
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in.')));
      return;
    }
    setState(() => _loading = true);
    await FirebaseFirestore.instance.collection('orders').add({
      'buyerId': user.uid,
      'items': cart.items.map((e) => e.toJson()).toList(),
      'shippingInfo': {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
      },
      'total': cart.totalPrice,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
    cart.clearCart();
    setState(() => _loading = false);
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.white,
          title: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.primaryGold, size: 32),
              const SizedBox(width: 8),
              const Text('Order Placed'),
            ],
          ),
          content: const Text('Your order has been placed successfully!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
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