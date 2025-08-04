import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wishlist_provider.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final wishlist = Provider.of<WishlistProvider>(context);
    final cart = Provider.of<CartProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: Text('Wishlist', style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold)),
      ),
      body: wishlist.items.isEmpty
          ? const Center(child: Text('Your wishlist is empty.'))
          : ListView.builder(
              itemCount: wishlist.items.length,
              itemBuilder: (context, index) {
                final product = wishlist.items[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: product.images.isNotEmpty
                        ? Image.network(
                            product.images.first, 
                            width: 56, 
                            height: 56, 
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Image.network(
                              'https://placehold.co/600x400', 
                              width: 56, 
                              height: 56, 
                              fit: BoxFit.cover
                            ),
                          )
                        : Image.network('https://placehold.co/600x400', width: 56, height: 56, fit: BoxFit.cover),
                    title: Text(product.name, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text('Ksh ${product.price}', style: AppTheme.bodySmall.copyWith(color: AppTheme.primaryGold)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.shopping_cart),
                          color: AppTheme.primaryGold,
                          onPressed: () {
                            wishlist.moveToCart(product, cart.addToCart);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Moved to cart!')));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          color: Colors.red,
                          onPressed: () {
                            wishlist.removeFromWishlist(product.id);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
} 