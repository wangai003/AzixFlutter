import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/marketplace_theme.dart';
import '../../models/product.dart';
import '../../services/order_service.dart';
import 'order_confirmation_screen.dart';

/// Complete product detail screen with order placement
class ProductDetailScreen extends StatefulWidget {
  final Product product;
  
  const ProductDetailScreen({Key? key, required this.product}) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final PageController _imageController = PageController();
  final TextEditingController _addressController = TextEditingController();
  
  int _currentImageIndex = 0;
  int _quantity = 1;
  String _selectedPaymentMethod = 'AKOFA';
  bool _isLoading = false;
  bool _showOrderForm = false;
  
  final OrderService _orderService = OrderService();
  
  final List<String> _paymentMethods = [
    'AKOFA',
    'M-Pesa',
    'Credit Card',
    'PayPal',
  ];

  @override
  void dispose() {
    _imageController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketplaceTheme.gray50,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildImageGallery(),
                _buildProductInfo(),
                _buildVendorInfo(),
                _buildOrderSection(),
                if (_showOrderForm) _buildOrderForm(),
                const SizedBox(height: 100), // Space for FAB
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 60,
      floating: true,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 1,
      title: Text(
        widget.product.name,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      actions: [
        IconButton(
          onPressed: _toggleFavorite,
          icon: const Icon(Icons.favorite_border),
        ),
        IconButton(
          onPressed: _shareProduct,
          icon: const Icon(Icons.share),
        ),
      ],
    );
  }

  Widget _buildImageGallery() {
    final images = widget.product.images;
    
    return Container(
      height: 300,
      color: Colors.white,
      child: images.isNotEmpty
          ? Stack(
              children: [
                PageView.builder(
                  controller: _imageController,
                  itemCount: images.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentImageIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return Image.network(
                      images[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: MarketplaceTheme.gray200,
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 64,
                            color: Colors.grey,
                          ),
                        );
                      },
                    );
                  },
                ),
                
                // Image indicators
                if (images.length > 1)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: images.asMap().entries.map((entry) {
                        final index = entry.key;
                        return Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentImageIndex == index
                                ? Colors.white
                                : Colors.white.withOpacity(0.5),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            )
          : Container(
              color: MarketplaceTheme.gray200,
              child: const Center(
                child: Icon(
                  Icons.inventory_2,
                  size: 64,
                  color: Colors.grey,
                ),
              ),
            ),
    );
  }

  Widget _buildProductInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
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
          // Product name and category
          Text(
            widget.product.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: MarketplaceTheme.getCategoryColor(widget.product.category).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.product.category,
              style: TextStyle(
                color: MarketplaceTheme.getCategoryColor(widget.product.category),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Price and stock
          Row(
            children: [
              Text(
                '₳${widget.product.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: MarketplaceTheme.primaryGreen,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.product.inventory > 0 
                      ? MarketplaceTheme.success.withOpacity(0.1)
                      : MarketplaceTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.product.inventory > 0 ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: widget.product.inventory > 0 
                          ? MarketplaceTheme.success 
                          : MarketplaceTheme.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.product.inventory > 0 
                          ? '${widget.product.inventory} in stock'
                          : 'Out of stock',
                      style: TextStyle(
                        color: widget.product.inventory > 0 
                            ? MarketplaceTheme.success 
                            : MarketplaceTheme.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Description
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.product.description,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
          
          // Additional product details
          if (widget.product.metadata.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Product Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...widget.product.metadata.entries.map((entry) {
              if (entry.value != null && entry.value.toString().isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        '${_formatMetadataKey(entry.key)}:',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Text(entry.value.toString()),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildVendorInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vendor_profiles')
            .doc(widget.product.vendorId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final vendorData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final businessName = vendorData['businessName'] ?? 'Unknown Vendor';
          final analytics = vendorData['analytics'] as Map<String, dynamic>? ?? {};
          final rating = (analytics['rating'] ?? 0.0) as double;
          final reviewCount = analytics['reviewCount'] ?? 0;
          
          return Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: MarketplaceTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Icon(
                  Icons.store,
                  color: MarketplaceTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      businessName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      children: [
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              index < rating.floor() ? Icons.star : Icons.star_border,
                              size: 16,
                              color: Colors.orange,
                            );
                          }),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${rating.toStringAsFixed(1)} ($reviewCount reviews)',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _viewVendorProfile,
                child: const Text('View Store'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderSection() {
    if (widget.product.inventory == 0) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MarketplaceTheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MarketplaceTheme.error.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info, color: MarketplaceTheme.error),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'This product is currently out of stock. Check back later!',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            'Quantity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildQuantityButton(
                Icons.remove,
                () => setState(() {
                  if (_quantity > 1) _quantity--;
                }),
              ),
              const SizedBox(width: 16),
              Text(
                _quantity.toString(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              _buildQuantityButton(
                Icons.add,
                () => setState(() {
                  if (_quantity < widget.product.inventory) _quantity++;
                }),
              ),
              const Spacer(),
              Text(
                'Total: ₳${(widget.product.price * _quantity).toStringAsFixed(2)}',
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

  Widget _buildQuantityButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(color: MarketplaceTheme.gray300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }

  Widget _buildOrderForm() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Row(
            children: [
              const Text(
                'Order Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _showOrderForm = false),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Shipping Address
          const Text(
            'Shipping Address',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              hintText: 'Enter your shipping address',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          
          const SizedBox(height: 16),
          
          // Payment Method
          const Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedPaymentMethod,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            items: _paymentMethods.map((method) {
              return DropdownMenuItem(
                value: method,
                child: Text(method),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPaymentMethod = value!;
              });
            },
          ),
          
          const SizedBox(height: 20),
          
          // Order Summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MarketplaceTheme.gray50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal:'),
                    Text('₳${(widget.product.price * _quantity).toStringAsFixed(2)}'),
                  ],
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Shipping:'),
                    Text('Free'),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₳${(widget.product.price * _quantity).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: MarketplaceTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Place Order Button
          SizedBox(
            width: double.infinity,
            height: 50,
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
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Place Order',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    if (widget.product.inventory == 0) {
      return FloatingActionButton.extended(
        onPressed: null,
        backgroundColor: Colors.grey,
        icon: const Icon(Icons.inventory_2, color: Colors.white),
        label: const Text(
          'Out of Stock',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return FloatingActionButton.extended(
      onPressed: () {
        setState(() {
          _showOrderForm = !_showOrderForm;
        });
      },
      backgroundColor: MarketplaceTheme.primaryBlue,
      icon: Icon(
        _showOrderForm ? Icons.close : Icons.shopping_cart,
        color: Colors.white,
      ),
      label: Text(
        _showOrderForm ? 'Close' : 'Buy Now',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Future<void> _placeOrder() async {
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter shipping address')),
      );
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
      final orderId = await _orderService.placeProductOrder(
        product: widget.product,
        quantity: _quantity,
        shippingAddress: _addressController.text.trim(),
        paymentMethod: _selectedPaymentMethod,
      );

      // Navigate to order confirmation
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(
            orderId: orderId,
            totalAmount: widget.product.price * _quantity,
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

  void _toggleFavorite() {
    // TODO: Implement favorite functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to favorites!')),
    );
  }

  void _shareProduct() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon!')),
    );
  }

  void _viewVendorProfile() {
    // TODO: Navigate to vendor profile screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vendor profile coming soon!')),
    );
  }

  String _formatMetadataKey(String key) {
    return key.split('_').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}
