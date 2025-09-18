import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../services/stellar_service.dart';
import '../models/product.dart';
import '../models/service.dart';
import '../models/cart_item.dart';
import '../models/service_order.dart';
import '../models/order.dart';

/// Unified marketplace provider for payments, orders, and state management
class MarketplaceProvider extends ChangeNotifier {
  final StellarService _stellarService;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // Loading states
  bool _isProcessingPayment = false;
  bool _isLoadingOrders = false;
  bool _isLoadingProducts = false;
  bool _isLoadingServices = false;

  // Error state
  String? _error;

  // Order data
  List<Order> _userOrders = [];
  List<Order> _vendorOrders = [];
  List<ServiceOrder> _userServiceOrders = [];
  List<ServiceOrder> _vendorServiceOrders = [];

  // Search and filtering
  String _searchQuery = '';
  String _selectedCategory = 'All';
  List<Product> _filteredProducts = [];
  List<Service> _filteredServices = [];

  MarketplaceProvider({
    StellarService? stellarService,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _stellarService = stellarService ?? StellarService(),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance {
    _initialize();
  }

  // Getters
  bool get isProcessingPayment => _isProcessingPayment;
  bool get isLoadingOrders => _isLoadingOrders;
  bool get isLoadingProducts => _isLoadingProducts;
  bool get isLoadingServices => _isLoadingServices;
  String? get error => _error;
  List<Order> get userOrders => _userOrders;
  List<Order> get vendorOrders => _vendorOrders;
  List<ServiceOrder> get userServiceOrders => _userServiceOrders;
  List<ServiceOrder> get vendorServiceOrders => _vendorServiceOrders;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  List<Product> get filteredProducts => _filteredProducts;
  List<Service> get filteredServices => _filteredServices;

  /// Initialize the provider
  void _initialize() {
    _loadUserOrders();
    _loadVendorOrders();
  }

  /// Set error state
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ==================== PAYMENT SYSTEM ====================

  /// Process payment for cart items using AKOFA tokens via Stellar
  Future<Map<String, dynamic>> processCartPayment({
    required List<CartItem> cartItems,
    required Map<String, String> shippingInfo,
  }) async {
    _isProcessingPayment = true;
    _setError(null);
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Calculate total amount
      final totalAmount = cartItems.fold<double>(
        0.0, 
        (sum, item) => sum + (item.product.price * item.quantity)
      );


      // Check user balance first
      final userBalance = await _getUserAkofaBalance(user.uid);
      if (userBalance < totalAmount) {
        throw Exception('Insufficient AKOFA balance. You have ${userBalance.toStringAsFixed(6)} but need ${totalAmount.toStringAsFixed(6)}');
      }

      // Create order document first
      final vendorIds = cartItems.map((item) => item.product.vendorId).toSet().toList();
      final orderData = {
        'buyerId': user.uid,
        'vendorIds': vendorIds, // Add this field for easier querying
        'items': cartItems.map((item) => {
          'productId': item.product.id,
          'productName': item.product.name,
          'vendorId': item.product.vendorId,
          'quantity': item.quantity,
          'price': item.product.price,
          'subtotal': item.product.price * item.quantity,
        }).toList(),
        'shippingInfo': shippingInfo,
        'totalAmount': totalAmount,
        'status': 'payment_processing',
        'paymentStatus': 'processing',
        'paymentMethod': 'AKOFA',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final orderRef = await _firestore.collection('orders').add(orderData);
      final orderId = orderRef.id;

      // Process payment via Stellar for each vendor
      final vendorPayments = <String, double>{};
      for (final item in cartItems) {
        final vendorId = item.product.vendorId;
        final amount = item.product.price * item.quantity;
        vendorPayments[vendorId] = (vendorPayments[vendorId] ?? 0.0) + amount;
      }

      // Execute Stellar transactions for each vendor
      final paymentResults = <String, Map<String, dynamic>>{};
      for (final entry in vendorPayments.entries) {
        final vendorId = entry.key;
        final amount = entry.value;

        try {
          // Get vendor's Stellar public key
          final vendorDoc = await _firestore.collection('USER').doc(vendorId).get();
          final vendorData = vendorDoc.data();
          
          if (vendorData == null) {
            throw Exception('Vendor $vendorId not found');
          }

          // Check if vendor has Stellar wallet
          final vendorPublicKey = vendorData['stellarPublicKey'] as String?;
          if (vendorPublicKey == null || vendorPublicKey.isEmpty) {
            // Fallback: Update Firestore balance directly for vendors without Stellar
            await _processFirestorePayment(user.uid, vendorId, amount, orderId);
            paymentResults[vendorId] = {'success': true, 'method': 'firestore'};
          } else {
            // Process via Stellar blockchain
            final stellarResult = await _stellarService.sendAsset(
              'AKOFA',
              vendorPublicKey,
              amount.toString(),
              memo: 'Marketplace Payment - Order: $orderId',
            );

            if (stellarResult['success'] == true) {
              paymentResults[vendorId] = {
                'success': true,
                'method': 'stellar',
                'hash': stellarResult['hash'],
              };
            } else {
              throw Exception('Stellar payment failed for vendor $vendorId: ${stellarResult['error']}');
            }
          }
        } catch (e) {
          // Rollback previous payments if any vendor fails
          await _rollbackPayments(paymentResults, orderId);
          throw Exception('Payment failed for vendor $vendorId: $e');
        }
      }

      // Update order status to completed
      await orderRef.update({
        'status': 'paid',
        'paymentStatus': 'completed',
        'paymentResults': paymentResults,
        'paidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notifications to vendors
      await _notifyVendorsOfNewOrder(orderId, cartItems);

      _isProcessingPayment = false;
      notifyListeners();

      return {
        'success': true,
        'orderId': orderId,
        'totalAmount': totalAmount,
        'paymentResults': paymentResults,
      };

    } catch (e) {
      _isProcessingPayment = false;
      _setError('Payment failed: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Process payment for a service order
  Future<Map<String, dynamic>> processServicePayment({
    required ServiceOrder serviceOrder,
  }) async {
    _isProcessingPayment = true;
    _setError(null);
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }


      // Check user balance
      final userBalance = await _getUserAkofaBalance(user.uid);
      if (userBalance < serviceOrder.price) {
        throw Exception('Insufficient AKOFA balance. You have ${userBalance.toStringAsFixed(6)} but need ${serviceOrder.price.toStringAsFixed(6)}');
      }

      // Get vendor's Stellar public key
      final vendorDoc = await _firestore.collection('USER').doc(serviceOrder.vendorId).get();
      final vendorData = vendorDoc.data();
      
      if (vendorData == null) {
        throw Exception('Vendor not found');
      }

      final vendorPublicKey = vendorData['stellarPublicKey'] as String?;
      Map<String, dynamic> paymentResult;

      if (vendorPublicKey == null || vendorPublicKey.isEmpty) {
        // Fallback: Update Firestore balance directly
        await _processFirestorePayment(user.uid, serviceOrder.vendorId, serviceOrder.price, serviceOrder.id);
        paymentResult = {'success': true, 'method': 'firestore'};
      } else {
        // Process via Stellar blockchain
        final stellarResult = await _stellarService.sendAsset(
          'AKOFA',
          vendorPublicKey,
          serviceOrder.price.toString(),
          memo: 'Service Payment - Order: ${serviceOrder.id}',
        );

        if (stellarResult['success'] != true) {
          throw Exception('Stellar payment failed: ${stellarResult['error']}');
        }

        paymentResult = {
          'success': true,
          'method': 'stellar',
          'hash': stellarResult['hash'],
        };
      }

      // Update service order status
      await _firestore.collection('service_orders').doc(serviceOrder.id).update({
        'paymentStatus': 'paid',
        'status': 'in_progress',
        'paymentResult': paymentResult,
        'paidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to vendor
      await _notifyVendorOfServiceOrder(serviceOrder);

      _isProcessingPayment = false;
      notifyListeners();

      return {
        'success': true,
        'orderId': serviceOrder.id,
        'amount': serviceOrder.price,
        'paymentResult': paymentResult,
      };

    } catch (e) {
      _isProcessingPayment = false;
      _setError('Service payment failed: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ==================== HELPER METHODS ====================

  /// Get user's AKOFA balance from Stellar wallet
  Future<double> _getUserAkofaBalance(String userId) async {
    try {
      // Get balance from Stellar service
      final balance = await _stellarService.getAkofaBalance(''); // Uses current user's wallet
      return double.tryParse(balance) ?? 0.0;
    } catch (e) {
      // Fallback to Firestore balance
      final userDoc = await _firestore.collection('USER').doc(userId).get();
      final userData = userDoc.data();
      return (userData?['akofaBalance'] ?? 0.0).toDouble();
    }
  }

  /// Process payment via Firestore balance manipulation (fallback)
  Future<void> _processFirestorePayment(String buyerId, String vendorId, double amount, String orderId) async {
    await _firestore.runTransaction((transaction) async {
      final buyerRef = _firestore.collection('USER').doc(buyerId);
      final vendorRef = _firestore.collection('USER').doc(vendorId);

      final buyerSnap = await transaction.get(buyerRef);
      final vendorSnap = await transaction.get(vendorRef);

      final buyerBalance = (buyerSnap.data()?['akofaBalance'] ?? 0.0).toDouble();
      final vendorBalance = (vendorSnap.data()?['akofaBalance'] ?? 0.0).toDouble();

      if (buyerBalance < amount) {
        throw Exception('Insufficient balance for Firestore payment');
      }

      // Update balances
      transaction.update(buyerRef, {
        'akofaBalance': buyerBalance - amount,
        'lastTransaction': FieldValue.serverTimestamp(),
      });

      transaction.update(vendorRef, {
        'akofaBalance': vendorBalance + amount,
        'pendingBalance': FieldValue.increment(amount),
        'lastTransaction': FieldValue.serverTimestamp(),
      });

      // Record transaction
      transaction.set(_firestore.collection('marketplace_transactions').doc(), {
        'buyerId': buyerId,
        'vendorId': vendorId,
        'orderId': orderId,
        'amount': amount,
        'type': 'marketplace_payment',
        'method': 'firestore',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Rollback payments in case of failure
  Future<void> _rollbackPayments(Map<String, Map<String, dynamic>> paymentResults, String orderId) async {
    
    // Update order status to failed
    await _firestore.collection('orders').doc(orderId).update({
      'status': 'payment_failed',
      'paymentStatus': 'failed',
      'failedAt': FieldValue.serverTimestamp(),
    });

    // Note: Stellar transactions cannot be reversed, but we can log the issue
    // for manual resolution if needed
    for (final entry in paymentResults.entries) {
      final vendorId = entry.key;
      final result = entry.value;
      
      if (result['method'] == 'stellar') {
        // Log for manual resolution
        await _firestore.collection('payment_issues').add({
          'type': 'rollback_needed',
          'orderId': orderId,
          'vendorId': vendorId,
          'stellarHash': result['hash'],
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  /// Send notifications to vendors about new orders
  Future<void> _notifyVendorsOfNewOrder(String orderId, List<CartItem> cartItems) async {
    final vendorItems = <String, List<CartItem>>{};
    
    // Group items by vendor
    for (final item in cartItems) {
      final vendorId = item.product.vendorId;
      vendorItems[vendorId] ??= [];
      vendorItems[vendorId]!.add(item);
    }

    // Send notification to each vendor
    for (final entry in vendorItems.entries) {
      final vendorId = entry.key;
      final items = entry.value;
      
      final itemNames = items.map((item) => '${item.quantity}x ${item.product.name}').join(', ');
      
      await _firestore.collection('notifications').add({
        'userId': vendorId,
        'title': 'New Order Received!',
        'message': 'You have a new order: $itemNames',
        'type': 'order',
        'orderId': orderId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Send notification to vendor about service order
  Future<void> _notifyVendorOfServiceOrder(ServiceOrder serviceOrder) async {
    await _firestore.collection('notifications').add({
      'userId': serviceOrder.vendorId,
      'title': 'New Service Order!',
      'message': 'You have a new service order for ${serviceOrder.package['name']}',
      'type': 'service_order',
      'orderId': serviceOrder.id,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== ORDER MANAGEMENT ====================

  /// Load user's orders
  Future<void> _loadUserOrders() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isLoadingOrders = true;
    notifyListeners();

    try {
      // Load product orders
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('buyerId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      _userOrders = ordersSnapshot.docs
          .map((doc) => Order.fromFirestore(doc.id, doc.data()))
          .toList();

      // Load service orders
      final serviceOrdersSnapshot = await _firestore
          .collection('service_orders')
          .where('buyerId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      _userServiceOrders = serviceOrdersSnapshot.docs
          .map((doc) => ServiceOrder.fromFirestore(doc.id, doc.data()))
          .toList();

    } catch (e) {
      _setError('Failed to load orders: $e');
    }

    _isLoadingOrders = false;
    notifyListeners();
  }

  /// Load vendor's orders
  Future<void> _loadVendorOrders() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Check if user is a vendor
      final userDoc = await _firestore.collection('USER').doc(user.uid).get();
      final userData = userDoc.data();
      final role = userData?['role'] as String?;

      if (role != null && role.contains('vendor')) {
        // Load product orders for vendor
        final ordersSnapshot = await _firestore
            .collection('orders')
            .where('vendorIds', arrayContains: user.uid)
            .orderBy('createdAt', descending: true)
            .get();

        _vendorOrders = ordersSnapshot.docs
            .map((doc) => Order.fromFirestore(doc.id, doc.data()))
            .where((order) => order.vendorIds.contains(user.uid))
            .toList();

        // Load service orders for vendor
        final serviceOrdersSnapshot = await _firestore
            .collection('service_orders')
            .where('vendorId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .get();

        _vendorServiceOrders = serviceOrdersSnapshot.docs
            .map((doc) => ServiceOrder.fromFirestore(doc.id, doc.data()))
            .toList();
      }
    } catch (e) {
    }

    notifyListeners();
  }

  /// Refresh orders
  Future<void> refreshOrders() async {
    await _loadUserOrders();
    await _loadVendorOrders();
  }

  // ==================== ORDER STATUS MANAGEMENT ====================

  /// Update order status (vendor action)
  Future<bool> updateOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    String? trackingNumber,
    String? notes,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final updateData = <String, dynamic>{
        'status': newStatus.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add status-specific fields
      switch (newStatus) {
        case OrderStatus.confirmed:
          // Order confirmed by vendor
          break;
        case OrderStatus.processing:
          // Order is being processed
          break;
        case OrderStatus.shipped:
          updateData['shippedAt'] = FieldValue.serverTimestamp();
          if (trackingNumber != null) {
            updateData['trackingNumber'] = trackingNumber;
          }
          break;
        case OrderStatus.delivered:
          updateData['deliveredAt'] = FieldValue.serverTimestamp();
          break;
        case OrderStatus.cancelled:
          // Handle refund if payment was made
          await _handleOrderCancellation(orderId);
          break;
        default:
          break;
      }

      // Update order
      await _firestore.collection('orders').doc(orderId).update(updateData);

      // Add event to order history
      await _addOrderEvent(
        orderId: orderId,
        type: 'status_update',
        details: 'Order status changed to ${newStatus.displayName}',
        metadata: {
          'newStatus': newStatus.toString(),
          'trackingNumber': trackingNumber,
          'notes': notes,
        },
      );

      // Send notification to buyer
      await _notifyBuyerOfStatusUpdate(orderId, newStatus);

      // Refresh orders
      await refreshOrders();

      return true;
    } catch (e) {
      _setError('Failed to update order status: $e');
      return false;
    }
  }

  /// Update service order status
  Future<bool> updateServiceOrderStatus({
    required String serviceOrderId,
    required String newStatus,
    String? notes,
    List<String>? deliveryFiles,
    String? deliveryMessage,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final updateData = <String, dynamic>{
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'delivered') {
        updateData['deliveryFiles'] = deliveryFiles ?? [];
        updateData['deliveryMessage'] = deliveryMessage ?? '';
        updateData['deliveredAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection('service_orders').doc(serviceOrderId).update(updateData);

      // Add event
      await _addServiceOrderEvent(
        serviceOrderId: serviceOrderId,
        type: 'status_update',
        details: 'Service order status changed to $newStatus',
        metadata: {
          'newStatus': newStatus,
          'notes': notes,
          'deliveryFiles': deliveryFiles,
        },
      );

      await refreshOrders();
      return true;
    } catch (e) {
      _setError('Failed to update service order status: $e');
      return false;
    }
  }

  /// Handle order cancellation and refunds
  Future<void> _handleOrderCancellation(String orderId) async {
    try {
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) return;

      final orderData = orderDoc.data()!;
      final paymentStatus = orderData['paymentStatus'] as String?;
      
      if (paymentStatus == 'paid') {
        // Process refund
        final buyerId = orderData['buyerId'] as String;
        final totalAmount = (orderData['totalAmount'] as num).toDouble();
        
        // For now, just update Firestore balance (in production, use Stellar refund)
        await _firestore.collection('USER').doc(buyerId).update({
          'akofaBalance': FieldValue.increment(totalAmount),
        });

        // Update payment status
        await _firestore.collection('orders').doc(orderId).update({
          'paymentStatus': 'refunded',
          'refundedAt': FieldValue.serverTimestamp(),
        });

        // Record refund transaction
        await _firestore.collection('marketplace_transactions').add({
          'type': 'refund',
          'orderId': orderId,
          'buyerId': buyerId,
          'amount': totalAmount,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
    }
  }

  /// Add event to order history
  Future<void> _addOrderEvent({
    required String orderId,
    required String type,
    required String details,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final event = OrderEvent(
      type: type,
      timestamp: DateTime.now(),
      userId: user.uid,
      userName: user.displayName ?? user.email ?? 'User',
      details: details,
      metadata: metadata,
    );

    await _firestore.collection('orders').doc(orderId).update({
      'events': FieldValue.arrayUnion([event.toMap()]),
    });
  }

  /// Add event to service order history
  Future<void> _addServiceOrderEvent({
    required String serviceOrderId,
    required String type,
    required String details,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final event = {
      'type': type,
      'timestamp': DateTime.now(),
      'userId': user.uid,
      'userName': user.displayName ?? user.email ?? 'User',
      'details': details,
      'metadata': metadata,
    };

    await _firestore.collection('service_orders').doc(serviceOrderId).update({
      'events': FieldValue.arrayUnion([event]),
    });
  }

  /// Send notification to buyer about status update
  Future<void> _notifyBuyerOfStatusUpdate(String orderId, OrderStatus status) async {
    try {
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) return;

      final orderData = orderDoc.data()!;
      final buyerId = orderData['buyerId'] as String;

      await _firestore.collection('notifications').add({
        'userId': buyerId,
        'title': 'Order Update',
        'message': 'Your order status has been updated to ${status.displayName}',
        'type': 'order_update',
        'orderId': orderId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
    }
  }

  // ==================== ORDER ANALYTICS ====================

  /// Get order statistics for vendor
  Map<String, dynamic> getVendorOrderStats() {
    final productOrders = _vendorOrders;
    final serviceOrders = _vendorServiceOrders;

    return {
      'totalOrders': productOrders.length + serviceOrders.length,
      'pendingOrders': productOrders.where((o) => o.status == OrderStatus.pending).length +
                      serviceOrders.where((o) => o.status == 'pending').length,
      'processingOrders': productOrders.where((o) => o.status == OrderStatus.processing).length +
                          serviceOrders.where((o) => o.status == 'in_progress').length,
      'completedOrders': productOrders.where((o) => o.status == OrderStatus.delivered).length +
                         serviceOrders.where((o) => o.status == 'delivered').length,
      'totalRevenue': productOrders.fold(0.0, (sum, order) => sum + order.totalAmount) +
                      serviceOrders.fold(0.0, (sum, order) => sum + order.price),
      'pendingRevenue': productOrders
                           .where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.processing)
                           .fold(0.0, (sum, order) => sum + order.totalAmount) +
                       serviceOrders
                           .where((o) => o.status == 'pending' || o.status == 'in_progress')
                           .fold(0.0, (sum, order) => sum + order.price),
    };
  }

  /// Get recent order activity
  List<Map<String, dynamic>> getRecentOrderActivity({int limit = 10}) {
    final allActivities = <Map<String, dynamic>>[];

    // Add product order events
    for (final order in _vendorOrders.take(limit)) {
      for (final event in order.events.take(3)) {
        allActivities.add({
          'type': 'product_order',
          'orderId': order.id,
          'event': event,
          'timestamp': event.timestamp,
        });
      }
    }

    // Add service order events (simplified)
    for (final order in _vendorServiceOrders.take(limit)) {
      allActivities.add({
        'type': 'service_order',
        'orderId': order.id,
        'event': {
          'type': 'order',
          'details': 'Service order received',
          'timestamp': order.createdAt,
        },
        'timestamp': order.createdAt,
      });
    }

    // Sort by timestamp and limit
    allActivities.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
    return allActivities.take(limit).toList();
  }

  // ==================== SEARCH & FILTERING ====================

  /// Update search query
  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Update selected category
  void updateSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// Filter products based on search and category
  void filterProducts(List<Product> allProducts) {
    _filteredProducts = allProducts.where((product) {
      final matchesSearch = _searchQuery.isEmpty ||
          product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.description.toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesCategory = _selectedCategory == 'All' ||
          product.category == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    notifyListeners();
  }

  /// Filter services based on search and category
  void filterServices(List<Service> allServices) {
    _filteredServices = allServices.where((service) {
      final matchesSearch = _searchQuery.isEmpty ||
          service.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          service.description.toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesCategory = _selectedCategory == 'All' ||
          service.category == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
