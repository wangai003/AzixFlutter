import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import 'cart_screen.dart';
import '../theme/app_theme.dart';

class ProductDetailScreen extends StatelessWidget {
  final Product product;
  const ProductDetailScreen({Key? key, required this.product}) : super(key: key);

  Future<Map<String, dynamic>?> _fetchVendor() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(product.vendorId).get();
    return doc.data();
  }

  Stream<QuerySnapshot> _reviewsStream() {
    return FirebaseFirestore.instance
        .collection('reviews')
        .where('productId', isEqualTo: product.id)
        .snapshots();
  }

  Future<bool> _isVerifiedBuyer(String userId) async {
    final orders = await FirebaseFirestore.instance
        .collection('orders')
        .where('buyerId', isEqualTo: userId)
        .where('productId', isEqualTo: product.id)
        .where('status', isEqualTo: 'completed')
        .limit(1)
        .get();
    return orders.docs.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final images = (product.images.isNotEmpty ? product.images : ['https://placehold.co/600x400']);
    final pageController = PageController();
    int selectedImage = 0;
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: Text(product.name, style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart, color: AppTheme.primaryGold),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modern image carousel with thumbnails
                StatefulBuilder(
                  builder: (context, setState) => Column(
                    children: [
                      SizedBox(
                        height: 280,
                        child: PageView.builder(
                          controller: pageController,
                          itemCount: images.length,
                          onPageChanged: (i) => setState(() => selectedImage = i),
                          itemBuilder: (context, i) => ClipRRect(
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                            child: Image.network(
                              images[i],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) => Image.network('https://placehold.co/600x400', fit: BoxFit.cover, width: double.infinity),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 60,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          itemBuilder: (context, i) => GestureDetector(
                            onTap: () {
                              pageController.jumpToPage(i);
                              setState(() => selectedImage = i);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: selectedImage == i ? AppTheme.primaryGold : Colors.transparent,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  images[i],
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Image.network('https://placehold.co/600x400', width: 56, height: 56, fit: BoxFit.cover),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(product.name, style: AppTheme.headingLarge.copyWith(color: AppTheme.black)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGold,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('Ksh ${product.price}', style: AppTheme.headingSmall.copyWith(color: AppTheme.black, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.inventory, color: AppTheme.primaryGold, size: 18),
                          const SizedBox(width: 4),
                          Text('In Stock: ${product.inventory}', style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
                          const SizedBox(width: 16),
                          Icon(Icons.category, color: AppTheme.primaryGold, size: 18),
                          const SizedBox(width: 4),
                          Text(product.category, style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (product.shippingOptions.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.local_shipping, color: AppTheme.primaryGold, size: 18),
                            const SizedBox(width: 4),
                            Text('Ships to: ${product.shippingOptions.join(", ")}', style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
                          ],
                        ),
                      const SizedBox(height: 16),
                      Text(product.description, style: AppTheme.bodyMedium.copyWith(color: AppTheme.black)),
                      const SizedBox(height: 24),
                      // Vendor info
                      FutureBuilder<Map<String, dynamic>?>(
                        future: _fetchVendor(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const ListTile(
                              leading: CircleAvatar(child: Icon(Icons.person)),
                              title: Text('Loading vendor...'),
                            );
                          }
                          final vendor = snapshot.data;
                          if (vendor == null) {
                            return const ListTile(
                              leading: CircleAvatar(child: Icon(Icons.person)),
                              title: Text('Vendor not found'),
                            );
                          }
                          return ListTile(
                            leading: vendor['profilePic'] != null && vendor['profilePic'] != ''
                                ? CircleAvatar(backgroundImage: NetworkImage(vendor['profilePic']))
                                : const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(vendor['displayName'] ?? 'Vendor', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                            subtitle: const Text('View Vendor Profile'),
                            onTap: () {},
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      // Wishlist and Add to Cart
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGold,
                                foregroundColor: AppTheme.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              icon: const Icon(Icons.shopping_cart),
                              label: const Text('Add to Cart'),
                              onPressed: () {
                                Provider.of<CartProvider>(context, listen: false).addToCart(product);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart!')));
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.favorite_border),
                            color: AppTheme.primaryGold,
                            iconSize: 32,
                            onPressed: () {
                              // TODO: Add to wishlist logic
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to wishlist!')));
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text('Reviews', style: AppTheme.headingSmall.copyWith(color: AppTheme.black, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      StreamBuilder<QuerySnapshot>(
                        stream: _reviewsStream(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            );
                          }
                          final reviews = snapshot.data!.docs;
                          return Column(
                            children: [
                              if (reviews.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('No reviews yet.'),
                                ),
                              ...reviews.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  child: ListTile(
                                    leading: const Icon(Icons.person),
                                    title: Text(data['reviewerName'] ?? 'User', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                                    subtitle: Text(data['comment'] ?? ''),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star, color: Colors.amber, size: 18),
                                        Text('${data['rating'] ?? '-'}'),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryGold,
                                  foregroundColor: AppTheme.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.rate_review),
                                label: const Text('Leave a Review'),
                                onPressed: () async {
                                  final user = FirebaseAuth.instance.currentUser;
                                  if (user == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in to leave a review.')));
                                    return;
                                  }
                                  final isVerified = await _isVerifiedBuyer(user.uid);
                                  if (!isVerified) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only buyers who have purchased this product can leave a review.')));
                                    return;
                                  }
                                  int rating = 5;
                                  final commentController = TextEditingController();
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: AppTheme.white,
                                      title: const Text('Leave a Review'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: List.generate(5, (i) => IconButton(
                                              icon: Icon(
                                                Icons.star,
                                                color: i < rating ? Colors.amber : Colors.grey,
                                              ),
                                              onPressed: () {
                                                rating = i + 1;
                                                (context as Element).markNeedsBuild();
                                              },
                                            )),
                                          ),
                                          TextField(
                                            controller: commentController,
                                            decoration: const InputDecoration(labelText: 'Comment'),
                                            maxLines: 2,
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primaryGold,
                                            foregroundColor: AppTheme.black,
                                          ),
                                          onPressed: () async {
                                            final reviewerName = user.displayName ?? user.email ?? 'User';
                                            await FirebaseFirestore.instance.collection('reviews').add({
                                              'productId': product.id,
                                              'reviewerId': user.uid,
                                              'reviewerName': reviewerName,
                                              'rating': rating,
                                              'comment': commentController.text.trim(),
                                              'timestamp': FieldValue.serverTimestamp(),
                                            });
                                            Navigator.pop(context);
                                          },
                                          child: const Text('Submit'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Sticky bottom bar for actions
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: AppTheme.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGold,
                        foregroundColor: AppTheme.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text('Add to Cart'),
                      onPressed: () {
                        Provider.of<CartProvider>(context, listen: false).addToCart(product);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart!')));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.favorite_border),
                    color: AppTheme.primaryGold,
                    iconSize: 32,
                    onPressed: () {
                      // TODO: Add to wishlist logic
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to wishlist!')));
                    },
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