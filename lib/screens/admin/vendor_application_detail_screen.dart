import 'package:flutter/material.dart';
import '../../models/vendor_application.dart';
import '../../services/admin_service.dart';

class VendorApplicationDetailScreen extends StatefulWidget {
  final VendorApplication application;
  const VendorApplicationDetailScreen({Key? key, required this.application}) : super(key: key);

  @override
  State<VendorApplicationDetailScreen> createState() => _VendorApplicationDetailScreenState();
}

class _VendorApplicationDetailScreenState extends State<VendorApplicationDetailScreen> {
  bool _loading = false;

  Future<void> _approve() async {
    setState(() => _loading = true);
    final success = await AdminService.approveVendorApplication(widget.application.id);
    setState(() => _loading = false);
    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application approved.')));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to approve application.')));
    }
  }

  Future<void> _reject() async {
    final reasonController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Application'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Rejection Reason'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, reasonController.text), child: const Text('Reject')),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    setState(() => _loading = true);
    final success = await AdminService.rejectVendorApplication(widget.application.id, result.trim());
    setState(() => _loading = false);
    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application rejected.')));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to reject application.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.application;
    return Scaffold(
      appBar: AppBar(title: const Text('Vendor Application Details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Text('Type: ${app.type}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('User ID: ${app.uid}'),
                  Text('Status: ${app.status}'),
                  if (app.goodsVendorData != null) ...[
                    const SizedBox(height: 16),
                    const Text('Goods Vendor Data:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Business Name: ${app.goodsVendorData!.businessName}'),
                    Text('Business License: ${app.goodsVendorData!.businessLicense}'),
                    Text('Product Categories: ${app.goodsVendorData!.productCategories.join(", ")}'),
                    Text('Shipping Regions: ${app.goodsVendorData!.shippingRegions.join(", ")}'),
                    Text('Contact Info: ${app.goodsVendorData!.contactInfo}'),
                  ],
                  if (app.serviceVendorData != null) ...[
                    const SizedBox(height: 16),
                    const Text('Service Vendor Data:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Skills: ${app.serviceVendorData!.skills.join(", ")}'),
                    Text('Portfolio Links: ${app.serviceVendorData!.portfolioLinks.join(", ")}'),
                    Text('Service Categories: ${app.serviceVendorData!.serviceCategories.join(", ")}'),
                    Text('Pricing Model: ${app.serviceVendorData!.pricingModel}'),
                    Text('Bio: ${app.serviceVendorData!.bio}'),
                  ],
                  if (app.rejectionReason != null && app.rejectionReason!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Rejection Reason: ${app.rejectionReason}', style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: app.status == 'pending' ? _approve : null,
                        child: const Text('Approve'),
                      ),
                      ElevatedButton(
                        onPressed: app.status == 'pending' ? _reject : null,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Reject'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
} 