import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/marketplace_theme.dart';
import '../../models/product.dart';
import '../../models/service.dart';
import '../../services/order_service.dart';
import 'checkout_screen.dart';

/// Complete functional shopping cart with checkout flow
class FunctionalCartScreen extends StatefulWidget {
  const FunctionalCartScreen({Key? key}) : super(key: key);

  @override
  State<FunctionalCartScreen> createState() => _FunctionalCartScreenState();
}

class _FunctionalCartScreenState extends State<FunctionalCartScreen> {
  final OrderService _orderService = OrderService();
  List<CartItem> _cartItems = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }
  
  Future<void> _loadCartItems() async {
    setState(() => _isLoading = true);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      // Load cart items from Firestore
      final cartDoc = await FirebaseFirestore.instance
          .collection('carts')
          .doc(user.uid)
          .get();
      
      if (cartDoc.exists) {
        final cartData = cartDoc.data()!;
        final items = cartData['items'] as List? ?? [];
        
        _cartItems = await Future.wait(
          items.map((item) => _loadCartItem(item)).toList(),
        );
        
        // Remove invalid items
        _cartItems.removeWhere((item) => item.product == null && item.service == null);
      }
    } catch (e) {
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<CartItem> _loadCartItem(Map<String, dynamic> itemData) async {
    final type = itemData['type'] ?? 'product';
    final id = itemData['id'] ?? '';
    final quantity = itemData['quantity'] ?? 1;
    
    if (type == 'product') {
      try {
        final productDoc = await FirebaseFirestore.instance
            .collection('products')
            .doc(id)
            .get();
        
        if (productDoc.exists) {
          final product = Product.fromJson(
            productDoc.data()!,
            productDoc.id,
          );
          return CartItem(product: product, quantity: quantity);
        }
      } catch (e) {
      }
    } else if (type == 'service') {
      try {
        final serviceDoc = await FirebaseFirestore.instance
            .collection('services')
            .doc(id)
            .get();
        
        if (serviceDoc.exists) {
          final service = Service.fromJson(
            serviceDoc.data()!,
            serviceDoc.id,
          );
          final packageIndex = itemData['packageIndex'] ?? 0;
          return CartItem(
            service: service,
            packageIndex: packageIndex,
            quantity: quantity,
          );
        }
      } catch (e) {
      }
    }
    
    return CartItem(); // Invalid item
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: MarketplaceTheme.gray50,
        appBar: AppBar(
          title: const Text('Shopping Cart'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      backgroundColor: MarketplaceTheme.gray50,
      appBar: AppBar(
        title: Text('Shopping Cart (${_cartItems.length})'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          if (_cartItems.isNotEmpty)
            TextButton(
              onPressed: _clearCart,
              child: const Text('Clear All'),
            ),
        ],
      ),
      body: _cartItems.isEmpty ? _buildEmptyCart() : _buildCartContent(),
      bottomNavigationBar: _cartItems.isNotEmpty ? _buildCheckoutBar() : null,
    );
  }
  
  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 100,
            color: MarketplaceTheme.gray400,
          ),
          const SizedBox(height: 24),
          const Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Add some products or services to get started',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: MarketplaceTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('Start Shopping'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCartContent() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _cartItems.length,
            itemBuilder: (context, index) {
              final item = _cartItems[index];
              return _buildCartItemCard(item, index);
            },
          ),
        ),
        _buildOrderSummary(),
      ],
    );
  }
  
  Widget _buildCartItemCard(CartItem item, int index) {
    final isProduct = item.product != null;
    final name = isProduct ? item.product!.name : item.service!.title;
    final price = isProduct 
        ? item.product!.price 
        : item.service!.packages[item.packageIndex].price;
    final imageUrl = isProduct 
        ? (item.product!.images.isNotEmpty ? item.product!.images.first : '')
        : (item.service!.images.isNotEmpty ? item.service!.images.first : '');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Item Image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: MarketplaceTheme.gray200,
                image: imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: imageUrl.isEmpty
                  ? Icon(
                      isProduct ? Icons.inventory_2 : Icons.design_services,
                      color: MarketplaceTheme.gray500,
                    )
                  : null,
            ),
            
            const SizedBox(width: 16),
            
            // Item Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  if (!isProduct && item.service!.packages.isNotEmpty)
                    Text(
                      'Package: ${item.service!.packages[item.packageIndex].name}',
                      style: TextStyle(
                        color: MarketplaceTheme.primaryBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Text(
                        '₳${price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: MarketplaceTheme.primaryGreen,
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // Quantity Controls
                      _buildQuantityControls(item, index),
                    ],
                  ),
                ],
              ),
            ),
            
            // Remove Button
            IconButton(
              onPressed: () => _removeItem(index),
              icon: const Icon(
                Icons.delete_outline,
                color: MarketplaceTheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuantityControls(CartItem item, int index) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => _updateQuantity(index, item.quantity - 1),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: MarketplaceTheme.gray300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.remove, size: 16),
          ),
        ),
        
        Container(
          width: 50,
          height: 32,
          alignment: Alignment.center,
          child: Text(
            item.quantity.toString(),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        
        GestureDetector(
          onTap: () => _updateQuantity(index, item.quantity + 1),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: MarketplaceTheme.gray300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add, size: 16),
          ),
        ),
      ],
    );
  }
  
  Widget _buildOrderSummary() {
    final subtotal = _calculateSubtotal();
    final shipping = _calculateShipping();
    final total = subtotal + shipping;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: MarketplaceTheme.gray200),
        ),
      ),
      child: Column(
        children: [
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
          
          const Divider(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₳${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
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
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(color: Colors.grey),
                  ),
                  Text(
                    '₳${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: MarketplaceTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 16),
            
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _proceedToCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MarketplaceTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Proceed to Checkout',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  double _calculateSubtotal() {
    return _cartItems.fold(0.0, (total, item) {
      final price = item.product != null 
          ? item.product!.price 
          : item.service!.packages[item.packageIndex].price;
      return total + (price * item.quantity);
    });
  }
  
  double _calculateShipping() {
    // Free shipping for services, basic shipping calculation for products
    final hasProducts = _cartItems.any((item) => item.product != null);
    return hasProducts ? 0.0 : 0.0; // Free shipping for now
  }
  
  Future<void> _updateQuantity(int index, int newQuantity) async {
    if (newQuantity <= 0) {
      _removeItem(index);
      return;
    }
    
    setState(() {
      _cartItems[index].quantity = newQuantity;
    });
    
    await _saveCart();
  }
  
  Future<void> _removeItem(int index) async {
    setState(() {
      _cartItems.removeAt(index);
    });
    
    await _saveCart();
  }
  
  Future<void> _clearCart() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Are you sure you want to remove all items from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: MarketplaceTheme.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() {
        _cartItems.clear();
      });
      await _saveCart();
    }
  }
  
  Future<void> _saveCart() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final cartData = {
        'items': _cartItems.map((item) => {
          'type': item.product != null ? 'product' : 'service',
          'id': item.product?.id ?? item.service?.id,
          'quantity': item.quantity,
          if (item.service != null) 'packageIndex': item.packageIndex,
        }).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await FirebaseFirestore.instance
          .collection('carts')
          .doc(user.uid)
          .set(cartData);
    } catch (e) {
    }
  }
  
  void _proceedToCheckout() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(cartItems: _cartItems),
      ),
    );
  }
}

/// Cart item model
class CartItem {
  Product? product;
  Service? service;
  int packageIndex;
  int quantity;
  
  CartItem({
    this.product,
    this.service,
    this.packageIndex = 0,
    this.quantity = 1,
  });
}
