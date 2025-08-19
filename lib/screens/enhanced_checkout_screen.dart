import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/unified_cart_provider.dart';
import '../providers/marketplace_provider.dart';
import '../providers/stellar_provider.dart';
import '../models/unified_cart_item.dart';
import '../theme/app_theme.dart';

/// Enhanced checkout screen for unified cart (products + services)
class EnhancedCheckoutScreen extends StatefulWidget {
  const EnhancedCheckoutScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedCheckoutScreen> createState() => _EnhancedCheckoutScreenState();
}

class _EnhancedCheckoutScreenState extends State<EnhancedCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  
  bool _loading = false;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    // Pre-fill user data
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameController.text = user.displayName ?? '';
      _emailController.text = user.email ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<UnifiedCartProvider, MarketplaceProvider, StellarProvider>(
      builder: (context, cart, marketplace, stellar, _) {
        return Scaffold(
          backgroundColor: AppTheme.black,
          appBar: AppBar(
            backgroundColor: AppTheme.black,
            elevation: 0,
            title: Row(
              children: [
                Icon(Icons.shopping_cart_checkout, color: AppTheme.primaryGold, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Checkout',
                  style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold),
                ),
              ],
            ),
          ),
          body: cart.isEmpty
              ? _buildEmptyCart()
              : Column(
                  children: [
                    // Progress Indicator
                    _buildProgressIndicator(),
                    
                    // Main Content
                    Expanded(
                      child: _buildStepContent(cart, marketplace, stellar),
                    ),
                    
                    // Bottom Navigation
                    _buildBottomNavigation(cart, marketplace, stellar),
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
          Icon(Icons.remove_shopping_cart, size: 80, color: AppTheme.grey),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: AppTheme.headingMedium.copyWith(color: AppTheme.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
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

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStepIndicator(0, 'Review', Icons.receipt_long),
          Expanded(child: _buildStepLine(0)),
          _buildStepIndicator(1, 'Shipping', Icons.local_shipping),
          Expanded(child: _buildStepLine(1)),
          _buildStepIndicator(2, 'Payment', Icons.payment),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, IconData icon) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;
    
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCompleted
                ? AppTheme.successGreen
                : isActive
                    ? AppTheme.primaryGold
                    : AppTheme.grey,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCompleted ? Icons.check : icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: isActive ? AppTheme.primaryGold : AppTheme.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int step) {
    final isCompleted = _currentStep > step;
    
    return Container(
      height: 2,
      color: isCompleted ? AppTheme.successGreen : AppTheme.grey,
    );
  }

  Widget _buildStepContent(
    UnifiedCartProvider cart,
    MarketplaceProvider marketplace,
    StellarProvider stellar,
  ) {
    switch (_currentStep) {
      case 0:
        return _buildReviewStep(cart);
      case 1:
        return _buildShippingStep();
      case 2:
        return _buildPaymentStep(cart, stellar);
      default:
        return Container();
    }
  }

  Widget _buildReviewStep(UnifiedCartProvider cart) {
    final itemsByVendor = cart.itemsByVendor;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Your Order',
            style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
          ),
          const SizedBox(height: 16),
          
          // Order Summary
          _buildOrderSummaryCard(cart),
          
          const SizedBox(height: 16),
          
          // Items by Vendor
          ...itemsByVendor.entries.map((entry) {
            return _buildVendorOrderSection(entry.key, entry.value);
          }),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard(UnifiedCartProvider cart) {
    final summary = cart.getCartSummary();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Products', '${summary['productCount']} items'),
          _buildSummaryRow('Services', '${summary['serviceCount']} items'),
          _buildSummaryRow('Vendors', '${summary['vendorCount']} vendors'),
          const Divider(color: AppTheme.grey),
          _buildSummaryRow(
            'Total',
            '₳${cart.totalPrice.toStringAsFixed(6)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: (isTotal ? AppTheme.bodyLarge : AppTheme.bodyMedium).copyWith(
              color: isTotal ? AppTheme.primaryGold : Colors.white,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: (isTotal ? AppTheme.bodyLarge : AppTheme.bodyMedium).copyWith(
              color: isTotal ? AppTheme.primaryGold : Colors.white,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorOrderSection(String vendorId, List<UnifiedCartItem> items) {
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
                Text(
                  'Vendor ${vendorId.substring(0, 8)}...',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.bold,
                  ),
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
          
          // Items
          ...items.map((item) => _buildOrderItemTile(item)),
        ],
      ),
    );
  }

  Widget _buildOrderItemTile(UnifiedCartItem item) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Item Image
          Container(
            width: 50,
            height: 50,
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
                    size: 20,
                  )
                : null,
          ),
          
          const SizedBox(width: 12),
          
          // Item Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.type.icon} ${item.name}',
                  style: AppTheme.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty: ${item.quantity} × ₳${item.unitPrice.toStringAsFixed(2)}',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                ),
              ],
            ),
          ),
          
          // Total Price
          Text(
            '₳${item.totalPrice.toStringAsFixed(2)}',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.primaryGold,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShippingStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shipping Information',
              style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person,
              validator: (value) => value?.isEmpty == true ? 'Name is required' : null,
            ),
            
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value?.isEmpty == true) return 'Email is required';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (value) => value?.isEmpty == true ? 'Phone number is required' : null,
            ),
            
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: _addressController,
              label: 'Shipping Address',
              icon: Icons.location_on,
              maxLines: 3,
              validator: (value) => value?.isEmpty == true ? 'Address is required' : null,
            ),
            
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: _notesController,
              label: 'Order Notes (Optional)',
              icon: Icons.note,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: AppTheme.bodyMedium.copyWith(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
        prefixIcon: Icon(icon, color: AppTheme.primaryGold),
        filled: true,
        fillColor: AppTheme.darkGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryGold),
        ),
      ),
    );
  }

  Widget _buildPaymentStep(UnifiedCartProvider cart, StellarProvider stellar) {
    final userBalance = double.tryParse(stellar.akofaBalance) ?? 0.0;
    final totalAmount = cart.totalPrice;
    final hasEnoughBalance = userBalance >= totalAmount;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Confirmation',
            style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
          ),
          const SizedBox(height: 16),
          
          // Payment Method
          Container(
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
                  children: [
                    Icon(Icons.account_balance_wallet, color: AppTheme.primaryGold),
                    const SizedBox(width: 8),
                    Text(
                      'AKOFA Wallet Payment',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildPaymentRow('Order Total', '₳${totalAmount.toStringAsFixed(6)}'),
                _buildPaymentRow('Your Balance', '₳${userBalance.toStringAsFixed(6)}'),
                const Divider(color: AppTheme.grey),
                _buildPaymentRow(
                  hasEnoughBalance ? 'Remaining Balance' : 'Additional Needed',
                  hasEnoughBalance
                      ? '₳${(userBalance - totalAmount).toStringAsFixed(6)}'
                      : '₳${(totalAmount - userBalance).toStringAsFixed(6)}',
                  isHighlight: true,
                  isError: !hasEnoughBalance,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Balance Warning
          if (!hasEnoughBalance)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Insufficient Balance',
                          style: AppTheme.bodyLarge.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'You need more AKOFA to complete this purchase. Please top up your wallet.',
                          style: AppTheme.bodyMedium.copyWith(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Transaction Security Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.successGreen),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.security, color: AppTheme.successGreen),
                    const SizedBox(width: 8),
                    Text(
                      'Secure Transaction',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.successGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Payments processed via Stellar blockchain\n'
                  '• Vendors receive payments instantly\n'
                  '• Complete transaction history recorded\n'
                  '• Refund protection for cancelled orders',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.successGreen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, String value, {bool isHighlight = false, bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(
              color: isHighlight ? (isError ? Colors.red : AppTheme.primaryGold) : Colors.white,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(
              color: isHighlight ? (isError ? Colors.red : AppTheme.primaryGold) : Colors.white,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation(
    UnifiedCartProvider cart,
    MarketplaceProvider marketplace,
    StellarProvider stellar,
  ) {
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
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _loading ? null : () => setState(() => _currentStep--),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryGold,
                  side: BorderSide(color: AppTheme.primaryGold),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Back'),
              ),
            ),
          
          if (_currentStep > 0) const SizedBox(width: 16),
          
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _loading ? null : () => _handleNextStep(cart, marketplace, stellar),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.black,
                      ),
                    )
                  : Text(_getNextButtonText()),
            ),
          ),
        ],
      ),
    );
  }

  String _getNextButtonText() {
    switch (_currentStep) {
      case 0:
        return 'Continue to Shipping';
      case 1:
        return 'Continue to Payment';
      case 2:
        return 'Complete Order';
      default:
        return 'Next';
    }
  }

  void _handleNextStep(
    UnifiedCartProvider cart,
    MarketplaceProvider marketplace,
    StellarProvider stellar,
  ) async {
    switch (_currentStep) {
      case 0:
        setState(() => _currentStep++);
        break;
      case 1:
        if (_formKey.currentState!.validate()) {
          setState(() => _currentStep++);
        }
        break;
      case 2:
        await _processOrder(cart, marketplace, stellar);
        break;
    }
  }

  Future<void> _processOrder(
    UnifiedCartProvider cart,
    MarketplaceProvider marketplace,
    StellarProvider stellar,
  ) async {
    setState(() => _loading = true);

    try {
      // TODO: Process unified cart with both products and services
      // For now, show success message
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        // Clear cart
        await cart.clearCart();
        
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.darkGrey,
            title: Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.successGreen, size: 32),
                const SizedBox(width: 8),
                const Text('Order Placed!'),
              ],
            ),
            content: const Text(
              'Your order has been successfully placed. You will receive notifications about order progress.',
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _loading = false);
  }
}
