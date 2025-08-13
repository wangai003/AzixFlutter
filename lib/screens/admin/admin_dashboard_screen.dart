import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/vendor_application.dart';
import '../../services/admin_service.dart';
import 'vendor_application_detail_screen.dart';
import '../../models/payout_request.dart';
import '../../models/notification.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  bool _checkingAdmin = true;
  bool _isAdmin = false;

  String _statusFilter = 'pending';
  String _typeFilter = 'all';
  String _searchQuery = '';
  late Future<List<VendorApplication>> _futureApplications;

  late TabController _tabController;
  final List<Tab> _tabs = const [
    Tab(text: 'Vendor Applications'),
    Tab(text: 'Payout Requests'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _checkAdmin();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isAdmin = false;
        _checkingAdmin = false;
      });
      return;
    }
          final doc = await FirebaseFirestore.instance.collection('USER').doc(user.uid).get();
    final role = doc.data()?['role'];
    setState(() {
      _isAdmin = role == 'admin';
      _checkingAdmin = false;
      if (_isAdmin) {
        _futureApplications = AdminService.fetchVendorApplications(
          status: _statusFilter,
          type: _typeFilter,
          searchQuery: _searchQuery,
        );
      }
    });
  }

  void _refetchApplications() {
    setState(() {
      _futureApplications = AdminService.fetchVendorApplications(
        status: _statusFilter,
        type: _typeFilter,
        searchQuery: _searchQuery,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text('Admin Dashboard')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Dashboard')),
        body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              const Text('Access denied. You are not an admin.', style: TextStyle(fontSize: 18, color: Colors.red)),
                const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                child: const Text('Return to Home'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
              children: [
          _buildVendorApplicationsTab(),
          _buildPayoutRequestsTab(),
        ],
      ),
    );
  }

  Widget _buildVendorApplicationsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // Status filter
              DropdownButton<String>(
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _statusFilter = val);
                    _refetchApplications();
                  }
                },
              ),
              const SizedBox(width: 12),
              // Type filter
              DropdownButton<String>(
                value: _typeFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Types')),
                  DropdownMenuItem(value: 'goods', child: Text('Goods')),
                  DropdownMenuItem(value: 'service', child: Text('Service')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _typeFilter = val);
                    _refetchApplications();
                  }
                },
              ),
              const SizedBox(width: 12),
              // Search bar
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(hintText: 'Search by user ID...'),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                    _refetchApplications();
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<VendorApplication>>(
            future: _futureApplications,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final applications = snapshot.data!;
              if (applications.isEmpty) {
                return const Center(child: Text('No applications found.'));
              }
              return ListView.builder(
                itemCount: applications.length,
                itemBuilder: (context, index) {
                  final app = applications[index];
                  return ListTile(
                    title: Text('${app.type.toUpperCase()} Vendor'),
                    subtitle: Text('User: ${app.uid}\nStatus: ${app.status}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
            context,
            MaterialPageRoute(
                          builder: (_) => VendorApplicationDetailScreen(application: app),
                        ),
                      ).then((_) {
                        _refetchApplications();
                      });
                    },
                  );
                },
              );
            },
          ),
          ),
      ],
    );
  }

  Widget _buildPayoutRequestsTab() {
    return _AdminPayoutRequestsTab();
  }
}

class _AdminPayoutRequestsTab extends StatefulWidget {
  @override
  State<_AdminPayoutRequestsTab> createState() => _AdminPayoutRequestsTabState();
}

class _AdminPayoutRequestsTabState extends State<_AdminPayoutRequestsTab> {
  String _statusFilter = 'pending';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              const Text('Status:'),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _statusFilter = val);
                },
              ),
            ],
                ),
              ),
              Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _statusFilter == 'all'
                ? FirebaseFirestore.instance.collection('payout_requests').orderBy('requestedAt', descending: true).snapshots()
                : FirebaseFirestore.instance.collection('payout_requests').where('status', isEqualTo: _statusFilter).orderBy('requestedAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No payout requests found.'));
              }
              final requests = snapshot.data!.docs
                  .map((doc) => PayoutRequest.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                  .toList();
              return ListView.separated(
                itemCount: requests.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, i) {
                  final req = requests[i];
                  return ListTile(
                    leading: Icon(
                      req.status == 'paid'
                          ? Icons.check_circle
                          : req.status == 'rejected'
                              ? Icons.cancel
                              : req.status == 'approved'
                                  ? Icons.verified
                                  : Icons.hourglass_top,
                      color: req.status == 'paid'
                          ? Colors.green
                          : req.status == 'rejected'
                              ? Colors.red
                              : req.status == 'approved'
                                  ? Colors.blue
                                  : Colors.orange,
                    ),
                    title: Text('₳${req.amount.toStringAsFixed(2)} to ${req.destination.substring(0, 6)}...'),
                    subtitle: Text('Vendor: ${req.vendorId}\nStatus: ${req.status}\nRequested: ${req.requestedAt.toLocal()}'),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (req.status == 'pending')
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            tooltip: 'Approve',
                            onPressed: () => _updateStatus(req, 'approved'),
                          ),
                        if (req.status == 'pending')
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            tooltip: 'Reject',
                            onPressed: () => _updateStatus(req, 'rejected'),
                          ),
                        if (req.status == 'approved')
                          IconButton(
                            icon: const Icon(Icons.attach_money, color: Colors.blue),
                            tooltip: 'Mark as Paid',
                            onPressed: () => _markAsPaid(req),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _updateStatus(PayoutRequest req, String status) async {
    String? adminNote;
    if (status == 'rejected' || status == 'approved') {
      adminNote = await _promptForNote(context, status == 'rejected' ? 'Reason for Rejection (optional)' : 'Note (optional)');
    }
    await FirebaseFirestore.instance.collection('payout_requests').doc(req.id).update({
      'status': status,
      if (status == 'rejected') 'processedAt': DateTime.now(),
      if (adminNote != null && adminNote.isNotEmpty) 'adminNote': adminNote,
    });
    // Send notification
    String title = 'Payout Request Update';
    String message = '';
    if (status == 'approved') {
      message = 'Your payout request for ₳${req.amount.toStringAsFixed(2)} has been approved.';
      if (adminNote != null && adminNote.isNotEmpty) {
        message += '\nNote: $adminNote';
      }
    } else if (status == 'rejected') {
      message = 'Your payout request for ₳${req.amount.toStringAsFixed(2)} was rejected.';
      if (adminNote != null && adminNote.isNotEmpty) {
        message += '\nReason: $adminNote';
      }
    }
    if (message.isNotEmpty) {
      final notification = NotificationModel(
        id: '',
        title: title,
        message: message,
        type: 'transaction',
        createdAt: DateTime.now(),
        isRead: false,
        userId: req.vendorId,
      );
      await FirebaseFirestore.instance.collection('notifications').add(notification.toMap());
    }
  }

  Future<void> _markAsPaid(PayoutRequest req) async {
    final adminNote = await _promptForNote(context, 'Note for Vendor (optional)');
    // Mark as paid and deduct from vendor's akofaBalance
    final batch = FirebaseFirestore.instance.batch();
    final payoutRef = FirebaseFirestore.instance.collection('payout_requests').doc(req.id);
            final vendorRef = FirebaseFirestore.instance.collection('USER').doc(req.vendorId);
    batch.update(payoutRef, {
      'status': 'paid',
      'processedAt': DateTime.now(),
      if (adminNote != null && adminNote.isNotEmpty) 'adminNote': adminNote,
    });
    batch.update(vendorRef, {
      'akofaBalance': FieldValue.increment(-req.amount),
    });
    await batch.commit();
    // Send notification
    String message = 'Your payout of ₳${req.amount.toStringAsFixed(2)} has been sent to your Stellar wallet.';
    if (adminNote != null && adminNote.isNotEmpty) {
      message += '\nNote: $adminNote';
    }
    final notification = NotificationModel(
      id: '',
      title: 'Payout Sent',
      message: message,
      type: 'transaction',
      createdAt: DateTime.now(),
      isRead: false,
      userId: req.vendorId,
    );
    await FirebaseFirestore.instance.collection('notifications').add(notification.toMap());
  }

  Future<String?> _promptForNote(BuildContext context, String label) async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: label),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
} 