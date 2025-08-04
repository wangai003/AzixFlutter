import 'package:flutter/material.dart';

class OrderConfirmationScreen extends StatelessWidget {
  final String serviceTitle;
  final String packageName;
  final double price;

  const OrderConfirmationScreen({
    Key? key,
    required this.serviceTitle,
    required this.packageName,
    required this.price,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Placed')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 24),
              const Text('Your order has been placed!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('Service: $serviceTitle', style: const TextStyle(fontSize: 16)),
              Text('Package: $packageName', style: const TextStyle(fontSize: 16)),
              Text('Price: ₳$price', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Back to Marketplace'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 