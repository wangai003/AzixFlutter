import 'package:cloud_firestore/cloud_firestore.dart';
import 'stellar_service.dart';
import 'notification_service.dart';

/// Comprehensive payment service supporting multiple payment methods
class PaymentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final StellarService _stellarService = StellarService();

  /// Process payment for an order
  static Future<PaymentResult> processPayment({
    required String orderId,
    required double amount,
    required PaymentMethod paymentMethod,
    required String customerId,
    required String vendorId,
    Map<String, dynamic>? paymentData,
  }) async {
    try {
      PaymentResult result;
      
      switch (paymentMethod) {
        case PaymentMethod.akofa:
          result = await _processAkofaPayment(orderId, amount, customerId, vendorId);
          break;
        case PaymentMethod.mpesa:
          result = await _processMpesaPayment(orderId, amount, paymentData);
          break;
        case PaymentMethod.creditCard:
          result = await _processCreditCardPayment(orderId, amount, paymentData);
          break;
        case PaymentMethod.paypal:
          result = await _processPaypalPayment(orderId, amount, paymentData);
          break;
        case PaymentMethod.bankTransfer:
          result = await _processBankTransferPayment(orderId, amount, paymentData);
          break;
        default:
          throw Exception('Unsupported payment method');
      }
      
      // Record payment transaction
      await _recordPaymentTransaction(result);
      
      // Update order status
      if (result.status == PaymentStatus.completed) {
        await _updateOrderPaymentStatus(orderId, 'completed', result.transactionId);
        
        // Send payment notifications
        await _sendPaymentNotifications(orderId, customerId, vendorId, amount, result);
      }
      
      return result;
    } catch (e) {
      return PaymentResult(
        status: PaymentStatus.failed,
        transactionId: '',
        orderId: orderId,
        amount: amount,
        paymentMethod: paymentMethod,
        errorMessage: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Process AKOFA token payment
  static Future<PaymentResult> _processAkofaPayment(
    String orderId,
    double amount,
    String customerId,
    String vendorId,
  ) async {
    try {
      // Get customer's AKOFA wallet
      final customerWallet = await _getAkofaWallet(customerId);
      if (customerWallet == null) {
        throw Exception('Customer AKOFA wallet not found');
      }
      
      // Get vendor's AKOFA wallet
      final vendorWallet = await _getAkofaWallet(vendorId);
      if (vendorWallet == null) {
        throw Exception('Vendor AKOFA wallet not found');
      }
      
      // Check customer balance (simplified - in real implementation get from Stellar)
      // final balance = await _stellarService.getAccountBalance(customerWallet['publicKey']);
      // if (balance < amount) {
      //   throw Exception('Insufficient AKOFA balance');
      // }
      
      // Process the transfer
      final result = await _stellarService.sendAsset(
        vendorWallet['publicKey'],
        amount.toString(),
        'Payment for order: $orderId',
      );
      final transactionId = result['hash'] ?? result.toString();
      
      return PaymentResult(
        status: PaymentStatus.completed,
        transactionId: transactionId,
        orderId: orderId,
        amount: amount,
        paymentMethod: PaymentMethod.akofa,
        timestamp: DateTime.now(),
        additionalData: {
          'fromWallet': customerWallet['publicKey'],
          'toWallet': vendorWallet['publicKey'],
          'stellarTxId': transactionId,
        },
      );
    } catch (e) {
      throw Exception('AKOFA payment failed: $e');
    }
  }

  /// Process M-Pesa payment (simulation)
  static Future<PaymentResult> _processMpesaPayment(
    String orderId,
    double amount,
    Map<String, dynamic>? paymentData,
  ) async {
    try {
      // In a real implementation, this would integrate with M-Pesa API
      // For now, we'll simulate the process
      
      final phoneNumber = paymentData?['phoneNumber'] ?? '';
      if (phoneNumber.isEmpty) {
        throw Exception('Phone number required for M-Pesa payment');
      }
      
      // Simulate M-Pesa STK push
      await Future.delayed(const Duration(seconds: 2));
      
      // Simulate success (in real implementation, you'd check M-Pesa callback)
      final transactionId = 'MPX${DateTime.now().millisecondsSinceEpoch}';
      
      return PaymentResult(
        status: PaymentStatus.completed,
        transactionId: transactionId,
        orderId: orderId,
        amount: amount,
        paymentMethod: PaymentMethod.mpesa,
        timestamp: DateTime.now(),
        additionalData: {
          'phoneNumber': phoneNumber,
          'mpesaReceiptNumber': transactionId,
        },
      );
    } catch (e) {
      throw Exception('M-Pesa payment failed: $e');
    }
  }

  /// Process Credit Card payment (simulation)
  static Future<PaymentResult> _processCreditCardPayment(
    String orderId,
    double amount,
    Map<String, dynamic>? paymentData,
  ) async {
    try {
      // In a real implementation, this would integrate with Stripe, Square, etc.
      
      final cardNumber = paymentData?['cardNumber'] ?? '';
      final expiryDate = paymentData?['expiryDate'] ?? '';
      final cvv = paymentData?['cvv'] ?? '';
      
      if (cardNumber.isEmpty || expiryDate.isEmpty || cvv.isEmpty) {
        throw Exception('Complete card details required');
      }
      
      // Simulate card processing
      await Future.delayed(const Duration(seconds: 3));
      
      // Simulate success
      final transactionId = 'CC${DateTime.now().millisecondsSinceEpoch}';
      
      return PaymentResult(
        status: PaymentStatus.completed,
        transactionId: transactionId,
        orderId: orderId,
        amount: amount,
        paymentMethod: PaymentMethod.creditCard,
        timestamp: DateTime.now(),
        additionalData: {
          'cardLast4': cardNumber.substring(cardNumber.length - 4),
          'authCode': 'AUTH${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
        },
      );
    } catch (e) {
      throw Exception('Credit card payment failed: $e');
    }
  }

  /// Process PayPal payment (simulation)
  static Future<PaymentResult> _processPaypalPayment(
    String orderId,
    double amount,
    Map<String, dynamic>? paymentData,
  ) async {
    try {
      // In a real implementation, this would integrate with PayPal SDK
      
      await Future.delayed(const Duration(seconds: 2));
      
      final transactionId = 'PP${DateTime.now().millisecondsSinceEpoch}';
      
      return PaymentResult(
        status: PaymentStatus.completed,
        transactionId: transactionId,
        orderId: orderId,
        amount: amount,
        paymentMethod: PaymentMethod.paypal,
        timestamp: DateTime.now(),
        additionalData: {
          'paypalTransactionId': transactionId,
          'payerEmail': paymentData?['email'] ?? '',
        },
      );
    } catch (e) {
      throw Exception('PayPal payment failed: $e');
    }
  }

  /// Process Bank Transfer payment
  static Future<PaymentResult> _processBankTransferPayment(
    String orderId,
    double amount,
    Map<String, dynamic>? paymentData,
  ) async {
    try {
      // Bank transfers are typically manual verification
      final transactionId = 'BT${DateTime.now().millisecondsSinceEpoch}';
      
      return PaymentResult(
        status: PaymentStatus.pending, // Manual verification required
        transactionId: transactionId,
        orderId: orderId,
        amount: amount,
        paymentMethod: PaymentMethod.bankTransfer,
        timestamp: DateTime.now(),
        additionalData: {
          'bankName': paymentData?['bankName'] ?? '',
          'accountNumber': paymentData?['accountNumber'] ?? '',
          'referenceNumber': paymentData?['referenceNumber'] ?? '',
        },
      );
    } catch (e) {
      throw Exception('Bank transfer processing failed: $e');
    }
  }

  /// Get AKOFA wallet for user
  static Future<Map<String, dynamic>?> _getAkofaWallet(String userId) async {
    try {
      final doc = await _firestore.collection('wallets').doc(userId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      return null;
    }
  }

  /// Record payment transaction in Firestore
  static Future<void> _recordPaymentTransaction(PaymentResult result) async {
    try {
      await _firestore.collection('payment_transactions').add({
        'orderId': result.orderId,
        'transactionId': result.transactionId,
        'amount': result.amount,
        'paymentMethod': result.paymentMethod.toString(),
        'status': result.status.toString(),
        'timestamp': Timestamp.fromDate(result.timestamp),
        'errorMessage': result.errorMessage,
        'additionalData': result.additionalData,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
    }
  }

  /// Update order payment status
  static Future<void> _updateOrderPaymentStatus(
    String orderId,
    String paymentStatus,
    String transactionId,
  ) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'paymentStatus': paymentStatus,
        'paymentTransactionId': transactionId,
        'paymentCompletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
    }
  }

  /// Send payment notifications
  static Future<void> _sendPaymentNotifications(
    String orderId,
    String customerId,
    String vendorId,
    double amount,
    PaymentResult result,
  ) async {
    try {
      // Get order details
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) return;
      
      final orderData = orderDoc.data()!;
      final productName = orderData['productName'] ?? orderData['serviceName'] ?? 'Unknown Item';
      
      if (result.status == PaymentStatus.completed) {
        // Notify customer of successful payment
        await NotificationService.createNotification(
          userId: customerId,
          type: NotificationType.payment,
          title: '💰 Payment Successful',
          message: 'Your payment of ₳${amount.toStringAsFixed(2)} for $productName has been processed successfully.',
          data: {
            'orderId': orderId,
            'transactionId': result.transactionId,
            'amount': amount,
            'paymentMethod': result.paymentMethod.toString(),
          },
        );
        
        // Notify vendor of payment received
        await NotificationService.sendOrderNotification(
          vendorId: vendorId,
          orderId: orderId,
          customerName: orderData['customerName'] ?? 'Customer',
          productName: productName,
          amount: amount,
          orderType: OrderNotificationType.paymentReceived,
        );
      } else if (result.status == PaymentStatus.failed) {
        // Notify customer of failed payment
        await NotificationService.createNotification(
          userId: customerId,
          type: NotificationType.payment,
          title: '❌ Payment Failed',
          message: 'Your payment for $productName could not be processed. ${result.errorMessage ?? "Please try again."}',
          data: {
            'orderId': orderId,
            'errorMessage': result.errorMessage,
          },
        );
      }
    } catch (e) {
    }
  }

  /// Refund payment
  static Future<RefundResult> processRefund({
    required String orderId,
    required String transactionId,
    required double amount,
    required PaymentMethod originalPaymentMethod,
    required String customerId,
    String? reason,
  }) async {
    try {
      RefundResult result;
      
      switch (originalPaymentMethod) {
        case PaymentMethod.akofa:
          result = await _processAkofaRefund(orderId, transactionId, amount, customerId);
          break;
        case PaymentMethod.mpesa:
          result = await _processMpesaRefund(orderId, transactionId, amount);
          break;
        case PaymentMethod.creditCard:
          result = await _processCreditCardRefund(orderId, transactionId, amount);
          break;
        case PaymentMethod.paypal:
          result = await _processPaypalRefund(orderId, transactionId, amount);
          break;
        case PaymentMethod.bankTransfer:
          result = await _processBankTransferRefund(orderId, transactionId, amount);
          break;
        default:
          throw Exception('Refund not supported for this payment method');
      }
      
      // Record refund transaction
      await _recordRefundTransaction(result, reason);
      
      // Send refund notification
      if (result.status == RefundStatus.completed) {
        await NotificationService.createNotification(
          userId: customerId,
          type: NotificationType.payment,
          title: '💰 Refund Processed',
          message: 'Your refund of ₳${amount.toStringAsFixed(2)} has been processed successfully.',
          data: {
            'orderId': orderId,
            'refundId': result.refundId,
            'amount': amount,
            'reason': reason,
          },
        );
      }
      
      return result;
    } catch (e) {
      return RefundResult(
        status: RefundStatus.failed,
        refundId: '',
        orderId: orderId,
        amount: amount,
        errorMessage: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Process AKOFA refund
  static Future<RefundResult> _processAkofaRefund(
    String orderId,
    String transactionId,
    double amount,
    String customerId,
  ) async {
    try {
      // In a real implementation, you would reverse the Stellar transaction
      // For now, we'll simulate this
      
      final refundId = 'AKRF${DateTime.now().millisecondsSinceEpoch}';
      
      return RefundResult(
        status: RefundStatus.completed,
        refundId: refundId,
        orderId: orderId,
        amount: amount,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      throw Exception('AKOFA refund failed: $e');
    }
  }

  /// Process M-Pesa refund (simulation)
  static Future<RefundResult> _processMpesaRefund(
    String orderId,
    String transactionId,
    double amount,
  ) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      
      final refundId = 'MPRF${DateTime.now().millisecondsSinceEpoch}';
      
      return RefundResult(
        status: RefundStatus.completed,
        refundId: refundId,
        orderId: orderId,
        amount: amount,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      throw Exception('M-Pesa refund failed: $e');
    }
  }

  /// Process Credit Card refund (simulation)
  static Future<RefundResult> _processCreditCardRefund(
    String orderId,
    String transactionId,
    double amount,
  ) async {
    try {
      await Future.delayed(const Duration(seconds: 3));
      
      final refundId = 'CCRF${DateTime.now().millisecondsSinceEpoch}';
      
      return RefundResult(
        status: RefundStatus.completed,
        refundId: refundId,
        orderId: orderId,
        amount: amount,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Credit card refund failed: $e');
    }
  }

  /// Process PayPal refund (simulation)
  static Future<RefundResult> _processPaypalRefund(
    String orderId,
    String transactionId,
    double amount,
  ) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      
      final refundId = 'PPRF${DateTime.now().millisecondsSinceEpoch}';
      
      return RefundResult(
        status: RefundStatus.completed,
        refundId: refundId,
        orderId: orderId,
        amount: amount,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      throw Exception('PayPal refund failed: $e');
    }
  }

  /// Process Bank Transfer refund
  static Future<RefundResult> _processBankTransferRefund(
    String orderId,
    String transactionId,
    double amount,
  ) async {
    try {
      final refundId = 'BTRF${DateTime.now().millisecondsSinceEpoch}';
      
      return RefundResult(
        status: RefundStatus.pending, // Manual processing required
        refundId: refundId,
        orderId: orderId,
        amount: amount,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Bank transfer refund failed: $e');
    }
  }

  /// Record refund transaction
  static Future<void> _recordRefundTransaction(
    RefundResult result,
    String? reason,
  ) async {
    try {
      await _firestore.collection('refund_transactions').add({
        'orderId': result.orderId,
        'refundId': result.refundId,
        'amount': result.amount,
        'status': result.status.toString(),
        'reason': reason,
        'timestamp': Timestamp.fromDate(result.timestamp),
        'errorMessage': result.errorMessage,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
    }
  }

  /// Get payment history for user
  static Stream<List<PaymentTransaction>> getPaymentHistory(String userId) {
    return _firestore
        .collection('payment_transactions')
        .where('customerId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentTransaction.fromFirestore(doc))
            .toList());
  }

  /// Get available payment methods for region
  static List<PaymentMethod> getAvailablePaymentMethods(String region) {
    // In a real implementation, this would be based on user location
    return [
      PaymentMethod.akofa,
      PaymentMethod.mpesa,
      PaymentMethod.creditCard,
      PaymentMethod.paypal,
      PaymentMethod.bankTransfer,
    ];
  }
}

/// Payment methods enum
enum PaymentMethod {
  akofa,
  mpesa,
  creditCard,
  paypal,
  bankTransfer,
}

/// Payment status enum
enum PaymentStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
}

/// Refund status enum
enum RefundStatus {
  pending,
  processing,
  completed,
  failed,
}

/// Payment result model
class PaymentResult {
  final PaymentStatus status;
  final String transactionId;
  final String orderId;
  final double amount;
  final PaymentMethod paymentMethod;
  final String? errorMessage;
  final DateTime timestamp;
  final Map<String, dynamic> additionalData;

  PaymentResult({
    required this.status,
    required this.transactionId,
    required this.orderId,
    required this.amount,
    required this.paymentMethod,
    this.errorMessage,
    required this.timestamp,
    this.additionalData = const {},
  });
}

/// Refund result model
class RefundResult {
  final RefundStatus status;
  final String refundId;
  final String orderId;
  final double amount;
  final String? errorMessage;
  final DateTime timestamp;

  RefundResult({
    required this.status,
    required this.refundId,
    required this.orderId,
    required this.amount,
    this.errorMessage,
    required this.timestamp,
  });
}

/// Payment transaction model
class PaymentTransaction {
  final String id;
  final String orderId;
  final String transactionId;
  final double amount;
  final PaymentMethod paymentMethod;
  final PaymentStatus status;
  final DateTime timestamp;
  final String? errorMessage;
  final Map<String, dynamic> additionalData;

  PaymentTransaction({
    required this.id,
    required this.orderId,
    required this.transactionId,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.timestamp,
    this.errorMessage,
    this.additionalData = const {},
  });

  factory PaymentTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentTransaction(
      id: doc.id,
      orderId: data['orderId'] ?? '',
      transactionId: data['transactionId'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.toString() == data['paymentMethod'],
        orElse: () => PaymentMethod.akofa,
      ),
      status: PaymentStatus.values.firstWhere(
        (e) => e.toString() == data['status'],
        orElse: () => PaymentStatus.pending,
      ),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      errorMessage: data['errorMessage'],
      additionalData: Map<String, dynamic>.from(data['additionalData'] ?? {}),
    );
  }
}
