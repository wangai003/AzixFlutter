import 'package:flutter/material.dart';

class VendorTypeSelectionScreen extends StatelessWidget {
  const VendorTypeSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Become a Vendor')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/onboarding/goods');
              },
              child: const Text('Onboard as Goods Vendor'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/onboarding/service');
              },
              child: const Text('Onboard as Service Vendor'),
            ),
          ],
        ),
      ),
    );
  }
} 