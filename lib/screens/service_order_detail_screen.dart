import 'package:flutter/material.dart';
import '../models/service_order.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/order_message.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/stellar_service.dart';

class ServiceOrderDetailScreen extends StatelessWidget {
  final ServiceOrder order;
  const ServiceOrderDetailScreen({Key? key, required this.order}) : super(key: key);

  Future<void> _showDeliveryDialog(BuildContext context) async {
    final TextEditingController messageController = TextEditingController();
    List<PlatformFile> pickedFiles = [];
    bool isUploading = false;
    showDialog(
      context: context,
      barrierDismissible: !isUploading,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Deliver Work'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Pick Files'),
                  onPressed: isUploading
                      ? null
                      : () async {
                          final result = await FilePicker.platform.pickFiles(allowMultiple: true);
                          if (result != null) {
                            setState(() {
                              pickedFiles = result.files;
                            });
                          }
                        },
                ),
                if (pickedFiles.isNotEmpty)
                  Column(
                    children: pickedFiles
                        .map((f) => ListTile(
                              leading: const Icon(Icons.insert_drive_file),
                              title: Text(f.name),
                            ))
                        .toList(),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Delivery Message',
                    hintText: 'Describe your delivery...',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isUploading ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isUploading
                    ? null
                    : () async {
                        if (pickedFiles.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please pick at least one file.')));
                          return;
                        }
                        setState(() => isUploading = true);
                        try {
                          final storage = FirebaseStorage.instance;
                          List<String> fileUrls = [];
                          for (final file in pickedFiles) {
                            final ref = storage.ref().child('service_orders/${order.id}/${file.name}');
                            UploadTask uploadTask;
                            if (file.bytes != null) {
                              uploadTask = ref.putData(file.bytes!);
                            } else if (file.path != null) {
                              uploadTask = ref.putFile(File(file.path!));
                            } else {
                              continue;
                            }
                            final snapshot = await uploadTask;
                            final url = await snapshot.ref.getDownloadURL();
                            fileUrls.add(url);
                          }
                          await FirebaseFirestore.instance.collection('service_orders').doc(order.id).update({
                            'deliveryFiles': fileUrls,
                            'deliveryMessage': messageController.text.trim(),
                            'status': 'delivered',
                            'updatedAt': DateTime.now(),
                          });
                          await _logFileUploadEvent(fileUrls, messageController.text.trim());
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work delivered successfully!')));
                        } catch (e) {
                          setState(() => isUploading = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to deliver work: '
                              '${e.toString()}')));
                        }
                      },
                child: isUploading ? const CircularProgressIndicator() : const Text('Submit Delivery'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _buyerApproveDelivery(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Delivery'),
        content: const Text('Are you sure you want to approve this delivery? This will complete the order.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Approve')),
        ],
      ),
    );
    if (confirmed == true) {
      await _updateOrderStatusWithEvent(context, 'completed', details: 'Buyer approved delivery.');
    }
  }

  Future<void> _buyerRequestRevision(BuildContext context) async {
    final TextEditingController reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Revision'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason or instructions for the revision:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Revision Instructions'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Request Revision')),
        ],
      ),
    );
    if (confirmed == true) {
      await _updateOrderStatusWithEvent(context, 'revision_requested', details: reasonController.text.trim());
    }
  }

  Widget _buildOrderChat(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final TextEditingController messageController = TextEditingController();
    final ScrollController scrollController = ScrollController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('Order Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection('service_orders')
                .doc(order.id)
                .collection('messages')
                .orderBy('timestamp', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              final messages = docs
                  .map((doc) => OrderMessage.fromJson(doc.data() as Map<String, dynamic>, doc.id))
                  .toList();
              if (messages.isEmpty) {
                return const Center(child: Text('No messages yet.'));
              }
              // Auto-scroll to latest
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (scrollController.hasClients) {
                  scrollController.jumpTo(scrollController.position.maxScrollExtent);
                }
              });
              return ListView.builder(
                controller: scrollController,
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final msg = messages[i];
                  final isMe = user != null && msg.senderId == user.uid;
                  final timeStr = DateFormat('MMM d, h:mm a').format(msg.timestamp);
                  // Avatar/initials
                  final avatar = CircleAvatar(
                    radius: 16,
                    child: Text(
                      msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                  return Row(
                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMe) avatar,
                      Flexible(
                        child: Container(
                          margin: EdgeInsets.only(
                            left: isMe ? 40 : 8,
                            right: isMe ? 8 : 40,
                            top: 4,
                            bottom: 4,
                          ),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue[200] : Colors.grey[200],
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(12),
                              topRight: const Radius.circular(12),
                              bottomLeft: Radius.circular(isMe ? 12 : 0),
                              bottomRight: Radius.circular(isMe ? 0 : 12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                Text(msg.senderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(msg.content),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  timeStr,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isMe) avatar,
                    ],
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: messageController,
                decoration: const InputDecoration(hintText: 'Type a message...'),
                onSubmitted: (_) async {
                  if (user == null) return;
                  final text = messageController.text.trim();
                  if (text.isEmpty) return;
                  final msg = OrderMessage(
                    id: '',
                    senderId: user.uid,
                    senderName: user.displayName ?? user.email ?? 'User',
                    content: text,
                    timestamp: DateTime.now(),
                  );
                  await FirebaseFirestore.instance
                      .collection('service_orders')
                      .doc(order.id)
                      .collection('messages')
                      .add(msg.toJson());
                  messageController.clear();
                  FocusScope.of(context).requestFocus(FocusNode());
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: user == null || messageController.text.trim().isEmpty
                  ? null
                  : () async {
                      final text = messageController.text.trim();
                      if (text.isEmpty) return;
                      final msg = OrderMessage(
                        id: '',
                        senderId: user.uid,
                        senderName: user.displayName ?? user.email ?? 'User',
                        content: text,
                        timestamp: DateTime.now(),
                      );
                      await FirebaseFirestore.instance
                          .collection('service_orders')
                          .doc(order.id)
                          .collection('messages')
                          .add(msg.toJson());
                      messageController.clear();
                      FocusScope.of(context).requestFocus(FocusNode());
                    },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderTimeline(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('service_orders').doc(order.id).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final List eventsRaw = (data?['events'] ?? []) as List;
        final List<_OrderEvent> events = eventsRaw.map((e) {
          final type = e['type'] ?? '';
          IconData icon;
          String label;
          switch (type) {
            case 'status_change':
              icon = Icons.sync_alt;
              label = 'Status changed: ${e['oldStatus']} → ${e['newStatus']}';
              break;
            case 'file_upload':
              icon = Icons.upload_file;
              label = 'File(s) uploaded';
              break;
            case 'chat':
              icon = Icons.chat;
              label = 'Message';
              break;
            default:
              icon = Icons.info;
              label = type;
          }
          return _OrderEvent(
            type: type,
            label: label,
            icon: icon,
            user: e['userName'] ?? e['userId'] ?? 'User',
            timestamp: e['timestamp'] is Timestamp
                ? (e['timestamp'] as Timestamp).toDate()
                : (e['timestamp'] is DateTime ? e['timestamp'] : DateTime.tryParse(e['timestamp'].toString()) ?? DateTime.now()),
            details: e['details'] ?? '',
            files: (e['files'] as List?)?.map((f) => f.toString()).toList(),
          );
        }).toList();
        events.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text('Order Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            if (events.isEmpty)
              const Text('No events yet.'),
            ...events.map((e) => ListTile(
                  leading: Icon(e.icon, color: e.type == 'chat' ? Colors.green : Colors.blue),
                  title: Text(e.label),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('By: ${e.user}'),
                      Text(DateFormat('MMM d, h:mm a').format(e.timestamp)),
                      if (e.details.isNotEmpty) Text(e.details),
                      if (e.files != null)
                        ...e.files!.map((url) => Text('File: $url', style: const TextStyle(fontSize: 12, color: Colors.blue))),
                    ],
                  ),
                )),
          ],
        );
      },
    );
  }

  Future<List<_OrderEvent>> _getTimelineEvents() async {
    final List<_OrderEvent> events = [];
    // Order placed
    events.add(_OrderEvent(
      type: 'placed',
      label: 'Order Placed',
      icon: Icons.shopping_bag,
      user: order.buyerId,
      timestamp: order.createdAt,
      details: '',
    ));
    // Status changes
    if (order.status == 'rejected') {
      events.add(_OrderEvent(
        type: 'rejected',
        label: 'Order Rejected',
        icon: Icons.cancel,
        user: order.vendorId,
        timestamp: order.updatedAt,
        details: '',
      ));
    } else {
      if (order.status != 'pending') {
        events.add(_OrderEvent(
          type: 'accepted',
          label: 'Order Accepted',
          icon: Icons.check_circle,
          user: order.vendorId,
          timestamp: order.updatedAt,
          details: '',
        ));
      }
      if (order.deliveryFiles != null && order.deliveryFiles!.isNotEmpty) {
        events.add(_OrderEvent(
          type: 'delivered',
          label: 'Work Delivered',
          icon: Icons.upload_file,
          user: order.vendorId,
          timestamp: order.updatedAt,
          details: order.deliveryMessage ?? '',
          files: order.deliveryFiles,
        ));
      }
      if (order.status == 'revision_requested') {
        events.add(_OrderEvent(
          type: 'revision',
          label: 'Revision Requested',
          icon: Icons.edit,
          user: order.buyerId,
          timestamp: order.updatedAt,
          details: order.review != null && order.review!['revisionMessage'] != null ? order.review!['revisionMessage'] : '',
        ));
      }
      if (order.status == 'completed') {
        events.add(_OrderEvent(
          type: 'completed',
          label: 'Order Completed',
          icon: Icons.verified,
          user: order.buyerId,
          timestamp: order.updatedAt,
          details: '',
        ));
      }
    }
    // Fetch chat messages
    final messagesSnap = await FirebaseFirestore.instance
        .collection('service_orders')
        .doc(order.id)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .get();
    for (final doc in messagesSnap.docs) {
      final data = doc.data();
      events.add(_OrderEvent(
        type: 'chat',
        label: 'Message',
        icon: Icons.chat,
        user: data['senderName'] ?? data['senderId'] ?? 'User',
        timestamp: data['timestamp'] is DateTime
            ? data['timestamp']
            : (data['timestamp']?.toDate() ?? DateTime.now()),
        details: data['content'] ?? '',
      ));
    }
    // Sort all events by timestamp
    events.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return events;
  }

  Future<void> _updateOrderStatusWithEvent(BuildContext context, String newStatus, {String? details}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final event = {
      'type': 'status_change',
      'timestamp': DateTime.now(),
      'userId': user.uid,
      'userName': user.displayName ?? user.email ?? 'User',
      'oldStatus': order.status,
      'newStatus': newStatus,
      'details': details ?? '',
    };
    await FirebaseFirestore.instance.collection('service_orders').doc(order.id).update({
      'status': newStatus,
      'updatedAt': DateTime.now(),
      'events': FieldValue.arrayUnion([event]),
    });
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order status updated to $newStatus.')));
  }

  Future<void> _logFileUploadEvent(List<String> fileUrls, String message) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final event = {
      'type': 'file_upload',
      'timestamp': DateTime.now(),
      'userId': user.uid,
      'userName': user.displayName ?? user.email ?? 'User',
      'files': fileUrls,
      'details': message,
    };
    await FirebaseFirestore.instance.collection('service_orders').doc(order.id).update({
      'events': FieldValue.arrayUnion([event]),
    });
  }

  Widget _buildPaymentSection(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    if (order.paymentStatus == 'paid') return const SizedBox.shrink();
    return FutureBuilder<Map<String, String>?>(
      future: StellarService().getWalletCredentials(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final creds = snapshot.data;
        if (creds == null) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No wallet found.'),
          );
        }
        return FutureBuilder<String>(
          future: StellarService().getAkofaBalance(creds['publicKey']!),
          builder: (context, balSnapshot) {
            if (!balSnapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final balance = double.tryParse(balSnapshot.data ?? '0') ?? 0.0;
            final canPay = balance >= order.price;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wallet Balance: ₳${balance.toStringAsFixed(2)}'),
                    Text('Order Amount: ₳${order.price.toStringAsFixed(2)}'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: canPay
                          ? () async {
                              try {
                                // Deduct from wallet (send Akofa to vendor or escrow)
                                // For demo, just update Firestore balances atomically
                                final orderRef = FirebaseFirestore.instance.collection('service_orders').doc(order.id);
                                final userRef = FirebaseFirestore.instance.collection('USERS').doc(user.uid);
                                final vendorRef = FirebaseFirestore.instance.collection('USERS').doc(order.vendorId);
                                await FirebaseFirestore.instance.runTransaction((txn) async {
                                  final userSnap = await txn.get(userRef);
                                  final vendorSnap = await txn.get(vendorRef);
                                  final bal = (userSnap.data()?['akofaBalance'] ?? 0.0) as num;
                                  final pending = (vendorSnap.data()?['pendingBalance'] ?? 0.0) as num;
                                  if (bal < order.price) throw Exception('Insufficient balance');
                                  txn.update(userRef, {'akofaBalance': bal - order.price});
                                  txn.update(vendorRef, {'pendingBalance': pending + order.price});
                                  txn.update(orderRef, {
                                    'paymentStatus': 'paid',
                                    'paymentDetails': {
                                      'amount': order.price,
                                      'paidAt': DateTime.now(),
                                      'payerId': user.uid,
                                    },
                                  });
                                });
                                // Log payment event
                                final event = {
                                  'type': 'payment',
                                  'timestamp': DateTime.now(),
                                  'userId': user.uid,
                                  'userName': user.displayName ?? user.email ?? 'User',
                                  'amount': order.price,
                                  'details': 'Paid for order',
                                };
                                await FirebaseFirestore.instance.collection('service_orders').doc(order.id).update({
                                  'events': FieldValue.arrayUnion([event]),
                                });
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment successful!')));
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment failed: '
                                    '${e.toString()}')));
                              }
                            }
                          : null,
                      child: const Text('Pay Now'),
                    ),
                    if (!canPay)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Insufficient balance.', style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Package: ${order.package['name'] ?? ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Buyer: ${order.buyerId}'),
              const SizedBox(height: 8),
              Text('Status: ${order.status}'),
              const SizedBox(height: 8),
              Text('Requirements: ${order.requirements}'),
              const SizedBox(height: 8),
              Text('Price: ₳${order.price.toStringAsFixed(2)}'),
              const SizedBox(height: 16),
              if (order.status == 'pending') ...[
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => _updateOrderStatusWithEvent(context, 'in_progress'),
                      child: const Text('Accept'),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: () => _updateOrderStatusWithEvent(context, 'rejected'),
                      child: const Text('Reject'),
                    ),
                  ],
                ),
              ] else if (order.status == 'in_progress' || order.status == 'revision_requested') ...[
                ElevatedButton(
                  onPressed: () => _showDeliveryDialog(context),
                  child: const Text('Deliver Work'),
                ),
              ] else if (order.status == 'delivered') ...[
                const Text('Work delivered. Waiting for buyer approval.'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => _buyerApproveDelivery(context),
                      child: const Text('Approve Delivery'),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: () => _buyerRequestRevision(context),
                      child: const Text('Request Revision'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  // Placeholder for messaging functionality
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Messaging not implemented yet.')));
                },
                icon: const Icon(Icons.message),
                label: const Text('Message Buyer'),
              ),
              if (order.deliveryFiles != null && order.deliveryFiles!.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Delivered Files:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...order.deliveryFiles!.map((url) => ListTile(
                      leading: const Icon(Icons.insert_drive_file),
                      title: Text(url.split('/').last),
                      subtitle: Text(url),
                      onTap: () {
                        // Optionally: open file or copy link
                      },
                    )),
              ],
              if (order.deliveryMessage != null && order.deliveryMessage!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Delivery Message: ${order.deliveryMessage}'),
              ],
              _buildOrderChat(context),
              _buildOrderTimeline(context),
              _buildPaymentSection(context),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderEvent {
  final String type;
  final String label;
  final IconData icon;
  final String user;
  final DateTime timestamp;
  final String details;
  final List<String>? files;
  _OrderEvent({
    required this.type,
    required this.label,
    required this.icon,
    required this.user,
    required this.timestamp,
    required this.details,
    this.files,
  });
} 