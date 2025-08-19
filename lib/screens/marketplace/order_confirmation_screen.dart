import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/marketplace_theme.dart';
import '../main_navigation.dart';

/// Order confirmation screen
class OrderConfirmationScreen extends StatelessWidget {
  final String orderId;
  final double totalAmount;
  
  const OrderConfirmationScreen({
    Key? key,
    required this.orderId,
    required this.totalAmount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketplaceTheme.gray50,
      appBar: AppBar(
        title: const Text('Order Confirmation'),
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: MarketplaceTheme.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 60,
                  color: MarketplaceTheme.success,
                ),
              ),
              
              const SizedBox(height: 24),
              
              const Text(
                '🎉 Order Placed Successfully!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Order ID: #${orderId.substring(0, 8).toUpperCase()}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MarketplaceTheme.primaryBlue,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Total: ₳${totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: MarketplaceTheme.primaryGreen,
                ),
              ),
              
              const SizedBox(height: 24),
              
              Container(
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
                child: const Column(
                  children: [
                    Text(
                      'What happens next?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '• The vendor will confirm your order\n'
                      '• You\'ll receive updates via notifications\n'
                      '• Payment will be processed securely\n'
                      '• Track your order in the Orders section',
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const MainNavigation()),
                        (route) => false,
                      ),
                      child: const Text('Continue Shopping'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _viewOrderDetails(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MarketplaceTheme.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('View Order'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewOrderDetails(BuildContext context) {
    // TODO: Navigate to order details screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order tracking coming soon!')),
    );
  }
}
