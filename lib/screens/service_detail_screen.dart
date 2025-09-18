import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/service_order.dart';
import '../services/service_order_service.dart';
import 'order_confirmation_screen.dart';

class ServiceDetailScreen extends StatelessWidget {
  final Service service;
  const ServiceDetailScreen({Key? key, required this.service})
    : super(key: key);

  Future<Map<String, dynamic>?> _fetchVendor() async {
    final doc = await FirebaseFirestore.instance
        .collection('USER')
        .doc(service.vendorId)
        .get();
    return doc.data();
  }

  Stream<QuerySnapshot> _reviewsStream() {
    return FirebaseFirestore.instance
        .collection('reviews')
        .where('serviceId', isEqualTo: service.id)
        .snapshots();
  }

  Future<bool> _isVerifiedBuyer(String userId) async {
    final orders = await FirebaseFirestore.instance
        .collection('orders')
        .where('buyerId', isEqualTo: userId)
        .where('serviceId', isEqualTo: service.id)
        .where('status', isEqualTo: 'completed')
        .limit(1)
        .get();
    return orders.docs.isNotEmpty;
  }

  void _showOrderDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to order a service.'),
        ),
      );
      return;
    }
    int selectedPackage = 0;
    final requirementsController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Order Service'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<int>(
                  value: selectedPackage,
                  isExpanded: true,
                  items: List.generate(
                    service.packages.length,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(service.packages[i].name),
                    ),
                  ),
                  onChanged: (val) =>
                      setState(() => selectedPackage = val ?? 0),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: requirementsController,
                  decoration: const InputDecoration(
                    labelText: 'Your requirements',
                    hintText: 'Describe what you need...',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final package = service.packages[selectedPackage];
                  final order = ServiceOrder(
                    id: '',
                    serviceId: service.id,
                    buyerId: user.uid,
                    vendorId: service.vendorId,
                    package: package.toJson(),
                    requirements: requirementsController.text.trim(),
                    status: 'pending',
                    price: package.price,
                    milestones: null,
                    messages: null,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                    deliveryFiles: null,
                    deliveryMessage: null,
                    review: null,
                  );
                  try {
                    final serviceOrderService = ServiceOrderService();
                    await serviceOrderService.createServiceOrder(order);
                    Navigator.pop(context); // Close dialog
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderConfirmationScreen(
                          serviceTitle: service.title,
                          packageName: package.name,
                          price: package.price,
                        ),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to place order: '
                          '${e.toString()}',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Submit Order'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(service.title)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (service.images.isNotEmpty)
              SizedBox(
                height: 220,
                child: PageView(
                  children: service.images
                      .map(
                        (url) => Image.network(
                          url,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.network(
                                'https://placehold.co/600x400/FFD700/000000?text=Service+Image',
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                        ),
                      )
                      .toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Category: ${service.category}'),
                  const SizedBox(height: 8),
                  Text('Requirements: ${service.requirements.join(", ")}'),
                  const SizedBox(height: 16),
                  Text(service.description),
                  const SizedBox(height: 24),
                  // Packages
                  const Text(
                    'Packages:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  ...service.packages.map(
                    (pkg) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(pkg.name),
                        subtitle: Text(pkg.description),
                        trailing: SizedBox(
                          width: 100,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Price: ${pkg.price}',
                                style: const TextStyle(fontSize: 12),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Delivery: ${pkg.deliveryTime} days',
                                style: const TextStyle(fontSize: 10),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
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
                        leading:
                            vendor['profilePic'] != null &&
                                vendor['profilePic'] != ''
                            ? CircleAvatar(
                                backgroundImage: NetworkImage(
                                  vendor['profilePic'],
                                ),
                              )
                            : const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(vendor['displayName'] ?? 'Vendor'),
                        subtitle: const Text('View Vendor Profile'),
                        onTap: () {},
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => _showOrderDialog(context),
                      child: const Text('Order Service'),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Reviews',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
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
                            return ListTile(
                              leading: const Icon(Icons.person),
                              title: Text(data['reviewerName'] ?? 'User'),
                              subtitle: Text(data['comment'] ?? ''),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 18,
                                  ),
                                  Text('${data['rating'] ?? '-'}'),
                                ],
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () async {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'You must be logged in to leave a review.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              final isVerified = await _isVerifiedBuyer(
                                user.uid,
                              );
                              if (!isVerified) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Only buyers who have purchased this service can leave a review.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              int rating = 5;
                              final commentController = TextEditingController();
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Leave a Review'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: List.generate(
                                          5,
                                          (i) => IconButton(
                                            icon: Icon(
                                              Icons.star,
                                              color: i < rating
                                                  ? Colors.amber
                                                  : Colors.grey,
                                            ),
                                            onPressed: () {
                                              rating = i + 1;
                                              (context as Element)
                                                  .markNeedsBuild();
                                            },
                                          ),
                                        ),
                                      ),
                                      TextField(
                                        controller: commentController,
                                        decoration: const InputDecoration(
                                          labelText: 'Comment',
                                        ),
                                        maxLines: 2,
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        final reviewerName =
                                            user.displayName ??
                                            user.email ??
                                            'User';
                                        await FirebaseFirestore.instance
                                            .collection('reviews')
                                            .add({
                                              'serviceId': service.id,
                                              'reviewerId': user.uid,
                                              'reviewerName': reviewerName,
                                              'rating': rating,
                                              'comment': commentController.text
                                                  .trim(),
                                              'timestamp':
                                                  FieldValue.serverTimestamp(),
                                            });
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Submit'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: const Text('Leave a Review'),
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
    );
  }
}
