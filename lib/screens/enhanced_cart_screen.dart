import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/unified_cart_provider.dart';

import '../providers/stellar_provider.dart';
import '../models/unified_cart_item.dart';
import '../theme/app_theme.dart';
import 'enhanced_checkout_screen.dart';

/// Enhanced cart screen supporting both products and services
class EnhancedCartScreen extends StatefulWidget {
  const EnhancedCartScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedCartScreen> createState() => _EnhancedCartScreenState();
}

class _EnhancedCartScreenState extends State<EnhancedCartScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize cart when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UnifiedCartProvider>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<UnifiedCartProvider, StellarProvider>(
      builder: (context, cart, stellar, _) {
        return Scaffold(
          backgroundColor: AppTheme.black,
          appBar: AppBar(
            backgroundColor: AppTheme.black,
            elevation: 0,
            title: Row(
              children: [
                Icon(Icons.shopping_cart, color: AppTheme.primaryGold, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Shopping Cart',
                  style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold),
                ),
              ],
            ),
            actions: [
              if (cart.isNotEmpty)
                IconButton(
                  onPressed: () => _showClearCartDialog(context, cart),
                  icon: Icon(Icons.delete_sweep, color: AppTheme.grey),
                ),
            ],
          ),
          body: cart.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryGold),
                )
              : cart.isEmpty
                  ? _buildEmptyCart()
                  : Column(
                      children: [
                        // Cart Summary Header
                        _buildCartSummaryHeader(cart),
                        
                        // Cart Items
                        Expanded(
                          child: _buildCartItems(cart),
                        ),
                        
                        // Checkout Section
                        _buildCheckoutSection(cart, stellar),
                      ],
                    ),
        );
      },
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: AppTheme.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: AppTheme.headingMedium.copyWith(color: AppTheme.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some products or services to get started',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.lightGrey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: AppTheme.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Continue Shopping'),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummaryHeader(UnifiedCartProvider cart) {
    final summary = cart.getCartSummary();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cart Summary',
                style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${summary['totalItems']} items',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryItem(
                '📦 Products',
                summary['productCount'].toString(),
              ),
              const SizedBox(width: 16),
              _buildSummaryItem(
                '🛠️ Services',
                summary['serviceCount'].toString(),
              ),
              const SizedBox(width: 16),
              _buildSummaryItem(
                '🏪 Vendors',
                summary['vendorCount'].toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: AppTheme.headingSmall.copyWith(color: Colors.white),
          ),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCartItems(UnifiedCartProvider cart) {
    final itemsByVendor = cart.itemsByVendor;
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: itemsByVendor.keys.length,
      itemBuilder: (context, index) {
        final vendorId = itemsByVendor.keys.elementAt(index);
        final vendorItems = itemsByVendor[vendorId]!;
        
        return _buildVendorSection(vendorId, vendorItems, cart);
      },
    );
  }

  Widget _buildVendorSection(
    String vendorId, 
    List<UnifiedCartItem> items, 
    UnifiedCartProvider cart,
  ) {
    final vendorTotal = items.fold(0.0, (sum, item) => sum + item.totalPrice);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vendor Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryGold.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.store, color: AppTheme.primaryGold, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Vendor ${vendorId.substring(0, 8)}...',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '₳${vendorTotal.toStringAsFixed(2)}',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Vendor Items
          ...items.map((item) => _buildCartItemTile(item, cart)),
        ],
      ),
    );
  }

  Widget _buildCartItemTile(UnifiedCartItem item, UnifiedCartProvider cart) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item Image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.lightGrey,
              borderRadius: BorderRadius.circular(8),
              image: item.imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(item.imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: item.imageUrl == null
                ? Icon(
                    item.type == CartItemType.product ? Icons.inventory : Icons.design_services,
                    color: AppTheme.grey,
                    size: 24,
                  )
                : null,
          ),
          
          const SizedBox(width: 12),
          
          // Item Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.type.icon,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.name,
                        style: AppTheme.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 4),
                
                Text(
                  item.deliveryInfo,
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                ),
                
                const SizedBox(height: 8),
                
                // Price and Quantity
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₳${item.unitPrice.toStringAsFixed(2)}',
                          style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                        ),
                        Text(
                          '₳${item.totalPrice.toStringAsFixed(2)}',
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.primaryGold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    
                    Row(
                      children: [
                        // Quantity Controls (for products)
                        if (item.supportsQuantity) ...[
                          _buildQuantityButton(
                            Icons.remove,
                            () => _updateQuantity(item, cart, item.quantity - 1),
                            enabled: item.quantity > 1,
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              item.quantity.toString(),
                              style: AppTheme.bodyLarge.copyWith(color: Colors.white),
                            ),
                          ),
                          _buildQuantityButton(
                            Icons.add,
                            () => _updateQuantity(item, cart, item.quantity + 1),
                            enabled: true,
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGold.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Qty: ${item.quantity}',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.primaryGold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        
                        const SizedBox(width: 8),
                        
                        // Remove Button
                        IconButton(
                          onPressed: () => _removeItem(item, cart),
                          icon: Icon(Icons.delete, color: Colors.red.shade400, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Service Requirements (if applicable)
                if (item.type == CartItemType.service && 
                    item.serviceRequirements != null && 
                    item.serviceRequirements!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.black,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Requirements:',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.primaryGold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...item.serviceRequirements!.entries.map(
                          (entry) => Text(
                            '• ${entry.key}: ${entry.value}',
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback onPressed, {required bool enabled}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: enabled ? AppTheme.primaryGold.withOpacity(0.2) : AppTheme.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        icon: Icon(
          icon,
          size: 16,
          color: enabled ? AppTheme.primaryGold : AppTheme.grey,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildCheckoutSection(UnifiedCartProvider cart, StellarProvider stellar) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Total Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total (${cart.itemCount} items)',
                style: AppTheme.bodyLarge.copyWith(color: Colors.white),
              ),
              Text(
                '₳${cart.totalPrice.toStringAsFixed(6)}',
                style: AppTheme.headingMedium.copyWith(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Balance Check
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Balance',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
              ),
              Text(
                '₳${stellar.akofaBalance}',
                style: AppTheme.bodyMedium.copyWith(
                  color: (double.tryParse(stellar.akofaBalance) ?? 0.0) >= cart.totalPrice
                      ? AppTheme.successGreen
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Checkout Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: cart.isEmpty ? null : () => _proceedToCheckout(context, cart),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Proceed to Checkout',
                style: AppTheme.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateQuantity(UnifiedCartItem item, UnifiedCartProvider cart, int newQuantity) {
    if (item.type == CartItemType.product) {
      cart.updateProductQuantity(item.product!.id, newQuantity);
    }
  }

  void _removeItem(UnifiedCartItem item, UnifiedCartProvider cart) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text(
          'Remove Item',
          style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold),
        ),
        content: Text(
          'Are you sure you want to remove "${item.name}" from your cart?',
          style: AppTheme.bodyMedium.copyWith(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              cart.removeItem(item.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showClearCartDialog(BuildContext context, UnifiedCartProvider cart) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text(
          'Clear Cart',
          style: AppTheme.headingSmall.copyWith(color: Colors.red),
        ),
        content: Text(
          'Are you sure you want to remove all items from your cart?',
          style: AppTheme.bodyMedium.copyWith(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              cart.clearCart();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _proceedToCheckout(BuildContext context, UnifiedCartProvider cart) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EnhancedCheckoutScreen(),
      ),
    );
  }
}
