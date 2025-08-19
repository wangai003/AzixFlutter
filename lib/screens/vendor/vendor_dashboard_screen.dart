import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../vendor/product_management_screen.dart';
import '../vendor/service_management_screen.dart';
import '../../providers/marketplace_provider.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'vendor_orders_screen.dart';

class VendorDashboardScreen extends StatelessWidget {
  const VendorDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('You must be logged in as a vendor.')),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.store, color: AppTheme.primaryGold, size: 28),
            const SizedBox(width: 10),
            Text('Vendor Dashboard', style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold)),
          ],
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('USER').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.amber));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('User data not found.', style: TextStyle(color: Colors.white)));
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final available = (data['akofaBalance'] ?? 0.0) as num;
          final pending = (data['pendingBalance'] ?? 0.0) as num;
          // Responsive layout
          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 700;
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top stats row
                    Flex(
                      direction: isMobile ? Axis.vertical : Axis.horizontal,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatCard(
                          title: 'Available Balance',
                          value: '₳${available.toStringAsFixed(2)}',
                          icon: Icons.account_balance_wallet,
                          color: AppTheme.primaryGold,
                        ),
                        SizedBox(width: isMobile ? 0 : 24, height: isMobile ? 16 : 0),
                        _StatCard(
                          title: 'Pending Balance',
                          value: '₳${pending.toStringAsFixed(2)}',
                          icon: Icons.hourglass_top,
                          color: Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Quick actions
                    Flex(
                      direction: isMobile ? Axis.vertical : Axis.horizontal,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _QuickActionCard(
                          icon: Icons.inventory_2,
                          label: 'Product Management',
                          color: AppTheme.primaryGold,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductManagementScreen())),
                        ),
                        SizedBox(width: isMobile ? 0 : 18, height: isMobile ? 18 : 0),
                        _QuickActionCard(
                          icon: Icons.design_services,
                          label: 'Service Management',
                          color: Colors.white,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServiceManagementScreen())),
                        ),
                        SizedBox(width: isMobile ? 0 : 18, height: isMobile ? 18 : 0),
                        _QuickActionCard(
                          icon: Icons.list_alt,
                          label: 'Manage Orders',
                          color: Colors.blueAccent,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorOrdersScreen())),
                        ),
                        SizedBox(width: isMobile ? 0 : 18, height: isMobile ? 18 : 0),
                        _QuickActionCard(
                          icon: Icons.payments,
                          label: 'Payouts',
                          color: Colors.greenAccent,
                          onTap: () => _showPayoutDialog(context, available.toDouble(), user.uid),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Analytics widgets
                    _VendorAnalyticsRow(vendorId: user.uid, isMobile: isMobile),
                    const SizedBox(height: 32),
                    // Recent activity and notifications
                    _VendorRecentActivityAndNotifications(vendorId: user.uid),
                    const SizedBox(height: 32),
                    // Payout history
                    Text('Payout Request History', style: AppTheme.headingSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _PayoutRequestHistory(vendorId: user.uid),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showPayoutDialog(BuildContext context, double maxAmount, String vendorId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _PayoutRequestDialog(
        maxAmount: maxAmount,
        vendorId: vendorId,
      ),
    );
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout request submitted!')),
      );
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.9), Colors.black],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Payout dialog and history remain as before, but styled for dark mode ---
class _PayoutRequestDialog extends StatefulWidget {
  final double maxAmount;
  final String vendorId;
  const _PayoutRequestDialog({required this.maxAmount, required this.vendorId});

  @override
  State<_PayoutRequestDialog> createState() => _PayoutRequestDialogState();
}

class _PayoutRequestDialogState extends State<_PayoutRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _addressController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.black,
      title: Text('Request Payout', style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amountController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Amount (max: ₳${widget.maxAmount.toStringAsFixed(2)})',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (val) {
                final amount = double.tryParse(val ?? '');
                if (amount == null || amount <= 0) {
                  return 'Enter a valid amount';
                }
                if (amount > widget.maxAmount) {
                  return 'Amount exceeds available balance';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Stellar Wallet Address',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Enter a Stellar address';
                }
                return null;
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGold,
            foregroundColor: AppTheme.black,
          ),
          onPressed: _submitting ? null : () async {
            if (!_formKey.currentState!.validate()) return;
            setState(() { _submitting = true; _error = null; });
            try {
              final amount = double.parse(_amountController.text);
              final address = _addressController.text.trim();
              await FirebaseFirestore.instance.collection('payout_requests').add({
                'vendorId': widget.vendorId,
                'amount': amount,
                'destination': address,
                'status': 'pending',
                'requestedAt': DateTime.now(),
              });
              Navigator.pop(context, true);
            } catch (e) {
              setState(() { _error = 'Failed to submit request: ${e.toString()}'; _submitting = false; });
            }
          },
          child: _submitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Submit'),
        ),
      ],
    );
  }
}

class _PayoutRequestHistory extends StatelessWidget {
  final String vendorId;
  const _PayoutRequestHistory({required this.vendorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('payout_requests')
          .where('vendorId', isEqualTo: vendorId)
          .orderBy('requestedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No payout requests yet.', style: TextStyle(color: Colors.white70)),
          );
        }
        final requests = snapshot.data!.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const Divider(color: Colors.white12),
          itemBuilder: (context, i) {
            final req = requests[i];
            return ListTile(
              leading: Icon(
                req['status'] == 'paid'
                    ? Icons.check_circle
                    : req['status'] == 'rejected'
                        ? Icons.cancel
                        : Icons.hourglass_top,
                color: req['status'] == 'paid'
                    ? Colors.green
                    : req['status'] == 'rejected'
                        ? Colors.red
                        : Colors.orange,
              ),
              title: Text('₳${(req['amount'] as num).toStringAsFixed(2)} to ${(req['destination'] as String).substring(0, 6)}...', style: const TextStyle(color: Colors.white)),
              subtitle: Text('Status: ${req['status'] ?? ''}\nRequested: ${req['requestedAt'] != null ? (req['requestedAt'] as Timestamp).toDate().toLocal() : ''}', style: const TextStyle(color: Colors.white70)),
              isThreeLine: true,
              trailing: req['status'] == 'paid' && req['processedAt'] != null
                  ? Text('Paid\n${(req['processedAt'] as Timestamp).toDate().toLocal().toString().split(".")[0]}', style: const TextStyle(color: Colors.green))
                  : null,
            );
          },
        );
      },
    );
  }
}

// --- Analytics Row ---
class _VendorAnalyticsRow extends StatelessWidget {
  final String vendorId;
  final bool isMobile;
  const _VendorAnalyticsRow({required this.vendorId, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: _fetchVendorAnalytics(vendorId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AnalyticsCard(label: 'Orders', value: '...', icon: Icons.shopping_bag, color: Colors.white),
              if (!isMobile) SizedBox(width: 18),
              _AnalyticsCard(label: 'Sales', value: '...', icon: Icons.attach_money, color: AppTheme.primaryGold),
              if (!isMobile) SizedBox(width: 18),
              _AnalyticsCard(label: 'Reviews', value: '...', icon: Icons.star, color: Colors.orange),
            ],
          );
        }
        final data = snapshot.data!;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _AnalyticsCard(label: 'Orders', value: data[0].toString(), icon: Icons.shopping_bag, color: Colors.white),
            if (!isMobile) SizedBox(width: 18),
            _AnalyticsCard(label: 'Sales', value: data[1].toString(), icon: Icons.attach_money, color: AppTheme.primaryGold),
            if (!isMobile) SizedBox(width: 18),
            _AnalyticsCard(label: 'Reviews', value: data[2].toString(), icon: Icons.star, color: Colors.orange),
          ],
        );
      },
    );
  }

  Future<List<int>> _fetchVendorAnalytics(String vendorId) async {
    // Orders: count of orders (goods + service)
    final ordersSnap = await FirebaseFirestore.instance
        .collection('orders')
        .where('vendorId', isEqualTo: vendorId)
        .get();
    final serviceOrdersSnap = await FirebaseFirestore.instance
        .collection('service_orders')
        .where('vendorId', isEqualTo: vendorId)
        .get();
    final totalOrders = ordersSnap.docs.length + serviceOrdersSnap.docs.length;
    // Sales: sum of total (goods) + price (service)
    double sales = 0;
    for (final doc in ordersSnap.docs) {
      final data = doc.data();
      sales += (data['total'] ?? 0).toDouble();
    }
    for (final doc in serviceOrdersSnap.docs) {
      final data = doc.data();
      sales += (data['price'] ?? 0).toDouble();
    }
    // Reviews: count of reviews for this vendor's products/services
    final reviewsSnap = await FirebaseFirestore.instance
        .collection('reviews')
        .where('vendorId', isEqualTo: vendorId)
        .get();
    final totalReviews = reviewsSnap.docs.length;
    return [totalOrders, sales.toInt(), totalReviews];
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _AnalyticsCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22)),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// --- Recent Activity & Notifications ---
class _VendorRecentActivityAndNotifications extends StatelessWidget {
  final String vendorId;
  const _VendorRecentActivityAndNotifications({required this.vendorId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Activity', style: AppTheme.headingSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _VendorRecentOrders(vendorId: vendorId),
        const SizedBox(height: 24),
        Text('Notifications', style: AppTheme.headingSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _VendorNotifications(vendorId: vendorId),
      ],
    );
  }
}

class _VendorRecentOrders extends StatelessWidget {
  final String vendorId;
  const _VendorRecentOrders({required this.vendorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('vendorId', isEqualTo: vendorId)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }
        final orders = snapshot.data!.docs;
        if (orders.isEmpty) {
          return const Text('No recent orders.', style: TextStyle(color: Colors.white70));
        }
        return Column(
          children: orders.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final date = (data['timestamp'] as Timestamp?)?.toDate();
            return ListTile(
              tileColor: Colors.white10,
              leading: Icon(Icons.shopping_bag, color: AppTheme.primaryGold),
              title: Text('Order: ₳${(data['total'] ?? 0).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
              subtitle: Text(date != null ? DateFormat('yMMMd – HH:mm').format(date) : '', style: const TextStyle(color: Colors.white70)),
              trailing: Text(data['status'] ?? '', style: const TextStyle(color: Colors.white)),
            );
          }).toList(),
        );
      },
    );
  }
}

class _VendorNotifications extends StatelessWidget {
  final String vendorId;
  const _VendorNotifications({required this.vendorId});

  @override
  Widget build(BuildContext context) {
    if (vendorId == null || vendorId.isEmpty) {
      return const Text('No notifications: vendor not found.', style: TextStyle(color: Colors.white70));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', whereIn: [vendorId, null])
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }
        final notifs = snapshot.data!.docs;
        if (notifs.isEmpty) {
          return const Text('No notifications.', style: TextStyle(color: Colors.white70));
        }
        return Column(
          children: notifs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final date = (data['createdAt'] as Timestamp?)?.toDate();
            return ListTile(
              tileColor: Colors.white10,
              leading: Icon(Icons.notifications, color: AppTheme.primaryGold),
              title: Text(data['title'] ?? 'Notification', style: const TextStyle(color: Colors.white)),
              subtitle: Text(data['body'] ?? '', style: const TextStyle(color: Colors.white70)),
              trailing: Text(date != null ? DateFormat('yMMMd – HH:mm').format(date) : '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            );
          }).toList(),
        );
      },
    );
  }
}

// --- Vendor Orders Screen ---
class VendorOrdersScreen extends StatelessWidget {
  const VendorOrdersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('You must be logged in as a vendor.')),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Orders'),
          backgroundColor: AppTheme.black,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Goods Orders'),
              Tab(text: 'Service Orders'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Goods Orders
            _VendorGoodsOrdersTab(vendorId: user.uid),
            // Service Orders
            _VendorServiceOrdersTab(vendorId: user.uid),
          ],
        ),
      ),
    );
  }
}

class _VendorGoodsOrdersTab extends StatelessWidget {
  final String vendorId;
  const _VendorGoodsOrdersTab({required this.vendorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('vendorId', isEqualTo: vendorId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data!.docs;
        if (orders.isEmpty) {
          return const Center(child: Text('No goods orders found.'));
        }
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, idx) {
            final data = orders[idx].data() as Map<String, dynamic>;
            final date = (data['timestamp'] as Timestamp?)?.toDate();
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                leading: const Icon(Icons.shopping_bag, color: Colors.amber),
                title: Text('Order: ₳${(data['total'] ?? 0).toStringAsFixed(2)}'),
                subtitle: Text(date != null ? DateFormat('yMMMd – HH:mm').format(date) : ''),
                trailing: Text(data['status'] ?? ''),
                onTap: () {
                  // Optionally: show order details dialog
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Order Details'),
                      content: SingleChildScrollView(
                        child: Text(data.toString()),
                      ),
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _VendorServiceOrdersTab extends StatelessWidget {
  final String vendorId;
  const _VendorServiceOrdersTab({required this.vendorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('service_orders')
          .where('vendorId', isEqualTo: vendorId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data!.docs;
        if (orders.isEmpty) {
          return const Center(child: Text('No service orders found.'));
        }
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, idx) {
            final data = orders[idx].data() as Map<String, dynamic>;
            final date = (data['createdAt'] as Timestamp?)?.toDate();
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                leading: const Icon(Icons.design_services, color: Colors.blueAccent),
                title: Text('Service: ${data['serviceId'] ?? ''}'),
                subtitle: Text(date != null ? DateFormat('yMMMd – HH:mm').format(date) : ''),
                trailing: Text(data['status'] ?? ''),
                onTap: () {
                  // Optionally: show order details dialog
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Service Order Details'),
                      content: SingleChildScrollView(
                        child: Text(data.toString()),
                      ),
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
} 