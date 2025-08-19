import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';
import '../models/service.dart';
import 'notification_service.dart';

/// Complete order management service for the marketplace
class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Place an order for a product
  Future<String> placeProductOrder({
    required Product product,
    required int quantity,
    required String shippingAddress,
    required String paymentMethod,
    Map<String, dynamic>? additionalInfo,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final totalAmount = product.price * quantity;
    
    // Create order document
    final orderData = {
      'customerId': user.uid,
      'customerName': user.displayName ?? 'Unknown Customer',
      'customerEmail': user.email,
      'vendorId': product.vendorId,
      'orderType': 'product',
      'productId': product.id,
      'productName': product.name,
      'quantity': quantity,
      'unitPrice': product.price,
      'totalAmount': totalAmount,
      'shippingAddress': shippingAddress,
      'paymentMethod': paymentMethod,
      'status': 'pending',
      'paymentStatus': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'estimatedDelivery': _calculateDeliveryDate(7), // Default 7 days
      'tracking': {
        'events': [
          {
            'status': 'pending',
            'timestamp': FieldValue.serverTimestamp(),
            'description': 'Order placed successfully',
          }
        ]
      },
      ...?additionalInfo,
    };

    // Add order to Firestore
    final orderRef = await _firestore.collection('orders').add(orderData);
    
    // Update product inventory
    await _updateProductInventory(product.id!, quantity);
    
    // Update vendor analytics
    await _updateVendorAnalytics(product.vendorId, totalAmount);
    
    // Send notifications (placeholder)
    await _sendOrderNotifications(orderRef.id, product.vendorId, user.uid);
    
    return orderRef.id;
  }

  /// Place an order for a service
  Future<String> placeServiceOrder({
    required Service service,
    required ServicePackage package,
    required String requirements,
    required String paymentMethod,
    Map<String, dynamic>? additionalInfo,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Create order document
    final orderData = {
      'customerId': user.uid,
      'customerName': user.displayName ?? 'Unknown Customer',
      'customerEmail': user.email,
      'vendorId': service.vendorId,
      'orderType': 'service',
      'serviceId': service.id,
      'serviceName': service.title,
      'packageName': package.name,
      'packageDescription': package.description,
      'totalAmount': package.price,
      'deliveryTime': package.deliveryTime,
      'requirements': requirements,
      'paymentMethod': paymentMethod,
      'status': 'pending',
      'paymentStatus': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'estimatedDelivery': _calculateDeliveryDate(package.deliveryTime),
      'tracking': {
        'events': [
          {
            'status': 'pending',
            'timestamp': FieldValue.serverTimestamp(),
            'description': 'Service order placed successfully',
          }
        ]
      },
      ...?additionalInfo,
    };

    // Add order to Firestore
    final orderRef = await _firestore.collection('orders').add(orderData);
    
    // Update vendor analytics
    await _updateVendorAnalytics(service.vendorId, package.price);
    
    // Send notifications (placeholder)
    await _sendOrderNotifications(orderRef.id, service.vendorId, user.uid);
    
    return orderRef.id;
  }

  /// Get user's orders
  Stream<QuerySnapshot> getUserOrders(String userId) {
    return _firestore
        .collection('orders')
        .where('customerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get vendor's orders
  Stream<QuerySnapshot> getVendorOrders(String vendorId) {
    return _firestore
        .collection('orders')
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Update order status
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
      'tracking.events': FieldValue.arrayUnion([
        {
          'status': newStatus,
          'timestamp': FieldValue.serverTimestamp(),
          'description': _getStatusDescription(newStatus),
        }
      ]),
    });
  }

  /// Cancel an order
  Future<void> cancelOrder(String orderId, String reason) async {
    final orderDoc = await _firestore.collection('orders').doc(orderId).get();
    if (!orderDoc.exists) throw Exception('Order not found');

    final orderData = orderDoc.data()!;
    
    // Update order status
    await _firestore.collection('orders').doc(orderId).update({
      'status': 'cancelled',
      'cancellationReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
      'tracking.events': FieldValue.arrayUnion([
        {
          'status': 'cancelled',
          'timestamp': FieldValue.serverTimestamp(),
          'description': 'Order cancelled: $reason',
        }
      ]),
    });

    // Restore inventory if it's a product order
    if (orderData['orderType'] == 'product') {
      await _restoreProductInventory(
        orderData['productId'],
        orderData['quantity'],
      );
    }
  }

  /// Process payment (placeholder for real payment integration)
  Future<bool> processPayment({
    required String orderId,
    required String paymentMethod,
    required double amount,
  }) async {
    try {
      // TODO: Integrate with actual payment provider (Stripe, M-Pesa, etc.)
      
      // For now, simulate payment processing
      await Future.delayed(const Duration(seconds: 2));
      
      // Update order payment status
      await _firestore.collection('orders').doc(orderId).update({
        'paymentStatus': 'completed',
        'paymentCompletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'tracking.events': FieldValue.arrayUnion([
          {
            'status': 'payment_completed',
            'timestamp': FieldValue.serverTimestamp(),
            'description': 'Payment processed successfully',
          }
        ]),
      });
      
      return true;
    } catch (e) {
      // Update payment status to failed
      await _firestore.collection('orders').doc(orderId).update({
        'paymentStatus': 'failed',
        'paymentError': e.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return false;
    }
  }

  /// Private helper methods
  
  DateTime _calculateDeliveryDate(int deliveryDays) {
    return DateTime.now().add(Duration(days: deliveryDays));
  }

  Future<void> _updateProductInventory(String productId, int quantity) async {
    await _firestore.collection('products').doc(productId).update({
      'inventory': FieldValue.increment(-quantity),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _restoreProductInventory(String productId, int quantity) async {
    await _firestore.collection('products').doc(productId).update({
      'inventory': FieldValue.increment(quantity),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateVendorAnalytics(String vendorId, double amount) async {
    await _firestore.collection('vendor_profiles').doc(vendorId).update({
      'analytics.totalSales': FieldValue.increment(amount),
      'analytics.totalOrders': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _sendOrderNotifications(
    String orderId,
    String vendorId,
    String customerId,
  ) async {
    try {
      // Get order details
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) return;
      
      final orderData = orderDoc.data()!;
      final productName = orderData['productName'] ?? orderData['serviceName'] ?? 'Unknown Item';
      final customerName = orderData['customerName'] ?? 'Unknown Customer';
      final totalAmount = orderData['totalAmount'] ?? 0.0;
      
      // Send notification to vendor
      await NotificationService.sendOrderNotification(
        vendorId: vendorId,
        orderId: orderId,
        customerName: customerName,
        productName: productName,
        amount: totalAmount,
        orderType: OrderNotificationType.newOrder,
      );
      
      // Send confirmation to customer
      await NotificationService.createNotification(
        userId: customerId,
        type: NotificationType.order,
        title: '✅ Order Placed Successfully',
        message: 'Your order for $productName has been placed and is awaiting vendor confirmation.',
        data: {
          'orderId': orderId,
          'productName': productName,
          'amount': totalAmount,
        },
      );
    } catch (e) {
      print('Error sending order notifications: $e');
    }
  }

  String _getStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Order is awaiting vendor confirmation';
      case 'confirmed':
        return 'Order confirmed by vendor';
      case 'processing':
        return 'Order is being processed';
      case 'shipped':
        return 'Order has been shipped';
      case 'delivered':
        return 'Order delivered successfully';
      case 'completed':
        return 'Order completed';
      case 'cancelled':
        return 'Order has been cancelled';
      default:
        return 'Order status updated';
    }
  }

  /// Get order details
  Future<DocumentSnapshot> getOrderDetails(String orderId) {
    return _firestore.collection('orders').doc(orderId).get();
  }

  /// Add message to order (for communication)
  Future<void> addOrderMessage({
    required String orderId,
    required String senderId,
    required String message,
    List<String>? attachments,
  }) async {
    await _firestore
        .collection('orders')
        .doc(orderId)
        .collection('messages')
        .add({
      'senderId': senderId,
      'message': message,
      'attachments': attachments ?? [],
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Get order messages
  Stream<QuerySnapshot> getOrderMessages(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Rate and review an order
  Future<void> rateOrder({
    required String orderId,
    required String vendorId,
    required double rating,
    required String review,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Add review to reviews collection
    await _firestore.collection('reviews').add({
      'orderId': orderId,
      'customerId': user.uid,
      'customerName': user.displayName ?? 'Anonymous',
      'vendorId': vendorId,
      'rating': rating,
      'review': review,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update order with review
    await _firestore.collection('orders').doc(orderId).update({
      'hasReview': true,
      'customerRating': rating,
      'customerReview': review,
      'reviewedAt': FieldValue.serverTimestamp(),
    });

    // Update vendor analytics
    await _updateVendorRating(vendorId, rating);
  }

  Future<void> _updateVendorRating(String vendorId, double newRating) async {
    final vendorDoc = await _firestore.collection('vendor_profiles').doc(vendorId).get();
    if (!vendorDoc.exists) return;

    final data = vendorDoc.data()!;
    final analytics = data['analytics'] as Map<String, dynamic>? ?? {};
    
    final currentRating = (analytics['rating'] ?? 0.0) as double;
    final reviewCount = (analytics['reviewCount'] ?? 0) as int;
    
    final totalRating = (currentRating * reviewCount) + newRating;
    final newReviewCount = reviewCount + 1;
    final averageRating = totalRating / newReviewCount;

    await _firestore.collection('vendor_profiles').doc(vendorId).update({
      'analytics.rating': averageRating,
      'analytics.reviewCount': newReviewCount,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
