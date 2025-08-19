import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/marketplace_theme.dart';
import '../../services/order_service.dart';
import 'functional_cart_screen.dart';
import 'order_confirmation_screen.dart';

/// Complete checkout screen with payment and shipping
class CheckoutScreen extends StatefulWidget {
  final List<CartItem> cartItems;
  
  const CheckoutScreen({Key? key, required this.cartItems}) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  
  String _selectedPaymentMethod = 'AKOFA';
  bool _isLoading = false;
  
  final OrderService _orderService = OrderService();
  
  final List<String> _paymentMethods = [
    'AKOFA',
    'M-Pesa',
    'Credit Card',
    'PayPal',
    'Bank Transfer',
  ];

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketplaceTheme.gray50,
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildOrderSummary(),
                    const SizedBox(height: 16),
                    _buildShippingSection(),
                    const SizedBox(height: 16),
                    _buildPaymentSection(),
                    const SizedBox(height: 16),
                    _buildOrderNotesSection(),
                  ],
                ),
              ),
            ),
            _buildCheckoutBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final subtotal = _calculateSubtotal();
    final shipping = _calculateShipping();
    final total = subtotal + shipping;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Cart Items List
          ...widget.cartItems.map((item) => _buildOrderItem(item)),
          
          const Divider(height: 24),
          
          // Pricing Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal:'),
              Text('₳${subtotal.toStringAsFixed(2)}'),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Shipping:'),
              Text(
                shipping > 0 ? '₳${shipping.toStringAsFixed(2)}' : 'Free',
                style: TextStyle(
                  color: shipping > 0 ? Colors.black : MarketplaceTheme.success,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₳${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: MarketplaceTheme.primaryGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(CartItem item) {
    final isProduct = item.product != null;
    final name = isProduct ? item.product!.name : item.service!.title;
    final price = isProduct 
        ? item.product!.price 
        : item.service!.packages[item.packageIndex].price;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: MarketplaceTheme.gray200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isProduct ? Icons.inventory_2 : Icons.design_services,
              color: MarketplaceTheme.gray500,
              size: 20,
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isProduct && item.service!.packages.isNotEmpty)
                  Text(
                    item.service!.packages[item.packageIndex].name,
                    style: TextStyle(
                      color: MarketplaceTheme.primaryBlue,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          
          Text(
            '${item.quantity}x ₳${price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShippingSection() {
    final hasProducts = widget.cartItems.any((item) => item.product != null);
    
    if (!hasProducts) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: MarketplaceTheme.info,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Your order contains only services. No shipping address required.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shipping Address',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Street Address',
              hintText: 'Enter your street address',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Address is required' : null,
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'City is required' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _stateController,
                  decoration: const InputDecoration(
                    labelText: 'State',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'State is required' : null,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _zipController,
                  decoration: const InputDecoration(
                    labelText: 'ZIP Code',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'ZIP code is required' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) => value?.isEmpty ?? true ? 'Phone is required' : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 16),
          
          ..._paymentMethods.map((method) => _buildPaymentOption(method)),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String method) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: RadioListTile<String>(
        title: Row(
          children: [
            _getPaymentIcon(method),
            const SizedBox(width: 12),
            Text(method),
          ],
        ),
        value: method,
        groupValue: _selectedPaymentMethod,
        onChanged: (value) {
          setState(() {
            _selectedPaymentMethod = value!;
          });
        },
        activeColor: MarketplaceTheme.primaryBlue,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _getPaymentIcon(String method) {
    IconData icon;
    Color color;
    
    switch (method) {
      case 'AKOFA':
        icon = Icons.account_balance_wallet;
        color = const Color(0xFFFFD700); // Gold color
        break;
      case 'M-Pesa':
        icon = Icons.phone_android;
        color = Colors.green;
        break;
      case 'Credit Card':
        icon = Icons.credit_card;
        color = Colors.blue;
        break;
      case 'PayPal':
        icon = Icons.payment;
        color = Colors.indigo;
        break;
      default:
        icon = Icons.account_balance;
        color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildOrderNotesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Notes (Optional)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              hintText: 'Special instructions for your order...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar() {
    final total = _calculateSubtotal() + _calculateShipping();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _placeOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: MarketplaceTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Place Order • ₳${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  double _calculateSubtotal() {
    return widget.cartItems.fold(0.0, (total, item) {
      final price = item.product != null 
          ? item.product!.price 
          : item.service!.packages[item.packageIndex].price;
      return total + (price * item.quantity);
    });
  }

  double _calculateShipping() {
    // Free shipping for now
    return 0.0;
  }

  String _getShippingAddress() {
    return '${_addressController.text.trim()}, ${_cityController.text.trim()}, ${_stateController.text.trim()} ${_zipController.text.trim()}';
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to place order')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final List<String> orderIds = [];
      
      // Place orders for each vendor separately
      final vendorGroups = _groupItemsByVendor();
      
      for (final vendorEntry in vendorGroups.entries) {
        final vendorId = vendorEntry.key;
        final items = vendorEntry.value;
        
        for (final item in items) {
          String orderId;
          
          if (item.product != null) {
            // Place product order
            orderId = await _orderService.placeProductOrder(
              product: item.product!,
              quantity: item.quantity,
              shippingAddress: _getShippingAddress(),
              paymentMethod: _selectedPaymentMethod,
              additionalInfo: {
                'orderNotes': _notesController.text.trim(),
                'phone': _phoneController.text.trim(),
              },
            );
          } else {
            // Place service order
            orderId = await _orderService.placeServiceOrder(
              service: item.service!,
              package: item.service!.packages[item.packageIndex],
              requirements: _notesController.text.trim(),
              paymentMethod: _selectedPaymentMethod,
              additionalInfo: {
                'phone': _phoneController.text.trim(),
              },
            );
          }
          
          orderIds.add(orderId);
        }
      }
      
      // Clear cart after successful orders
      await _clearCart();
      
      // Navigate to confirmation
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(
            orderId: orderIds.first, // Show first order ID
            totalAmount: _calculateSubtotal() + _calculateShipping(),
          ),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error placing order: ${e.toString()}'),
          backgroundColor: MarketplaceTheme.error,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, List<CartItem>> _groupItemsByVendor() {
    final Map<String, List<CartItem>> vendorGroups = {};
    
    for (final item in widget.cartItems) {
      final vendorId = item.product?.vendorId ?? item.service?.vendorId ?? 'unknown';
      
      if (!vendorGroups.containsKey(vendorId)) {
        vendorGroups[vendorId] = [];
      }
      vendorGroups[vendorId]!.add(item);
    }
    
    return vendorGroups;
  }

  Future<void> _clearCart() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('carts')
          .doc(user.uid)
          .delete();
    } catch (e) {
      print('Error clearing cart: $e');
    }
  }
}
