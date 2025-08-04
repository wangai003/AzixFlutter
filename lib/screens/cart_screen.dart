import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import 'checkout_screen.dart';
import '../theme/app_theme.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final wishlist = Provider.of<WishlistProvider>(context, listen: false);
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        elevation: 0.5,
        title: Row(
          children: [
            const Icon(Icons.shopping_cart, color: AppTheme.primaryGold),
            const SizedBox(width: 8),
            Text('Your Cart', style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold)),
          ],
        ),
      ),
      body: cart.items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.remove_shopping_cart, size: 64, color: AppTheme.primaryGold.withOpacity(0.7)),
                  const SizedBox(height: 16),
                  Text('Your cart is empty.', style: AppTheme.headingSmall.copyWith(color: AppTheme.black)),
                  const SizedBox(height: 8),
                  Text('Start shopping and add items to your cart!', style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey)),
                ],
              ),
            )
          : Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 120),
                  child: ListView.separated(
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGold.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                              child: item.product.images.isNotEmpty
                                  ? Image.network(
                                      item.product.images.first, 
                                      width: 90, 
                                      height: 90, 
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Image.network(
                                        'https://placehold.co/600x400', 
                                        width: 90, 
                                        height: 90, 
                                        fit: BoxFit.cover
                                      ),
                                    )
                                  : Image.network('https://placehold.co/600x400', width: 90, height: 90, fit: BoxFit.cover),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.product.name, style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: AppTheme.black), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text('Ksh ${item.product.price}', style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _QuantityControl(
                                          quantity: item.quantity,
                                          onDecrement: item.quantity > 1 ? () => cart.updateQuantity(item.product.id, item.quantity - 1) : null,
                                          onIncrement: () => cart.updateQuantity(item.product.id, item.quantity + 1),
                                        ),
                                        const SizedBox(width: 12),
                                        IconButton(
                                          icon: const Icon(Icons.favorite_border),
                                          color: AppTheme.primaryGold,
                                          tooltip: 'Move to Wishlist',
                                          onPressed: () {
                                            wishlist.addToWishlist(item.product);
                                            cart.removeFromCart(item.product.id);
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Moved to wishlist!')));
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          color: Colors.red,
                                          tooltip: 'Remove',
                                          onPressed: () => cart.removeFromCart(item.product.id),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Sticky bottom bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGold.withOpacity(0.10),
                          blurRadius: 24,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total', style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold)),
                            Text('Ksh ${cart.totalPrice}', style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primaryGold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGold,
                              foregroundColor: AppTheme.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.payment),
                            label: const Text('Proceed to Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: cart.items.isEmpty ? null : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _QuantityControl extends StatelessWidget {
  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  const _QuantityControl({required this.quantity, this.onDecrement, this.onIncrement});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryGold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 20),
            color: AppTheme.primaryGold,
            onPressed: onDecrement,
            splashRadius: 18,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('$quantity', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            color: AppTheme.primaryGold,
            onPressed: onIncrement,
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
} 