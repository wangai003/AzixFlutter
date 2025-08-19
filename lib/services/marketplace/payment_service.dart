import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/stellar_service.dart';
import '../../models/marketplace/order.dart';

/// Advanced payment service with escrow and multi-currency support
class MarketplacePaymentService {
  final StellarService _stellarService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  MarketplacePaymentService({
    required StellarService stellarService,
  }) : _stellarService = stellarService;
  
  /// Process order payment with automatic escrow
  Future<PaymentResult> processOrderPayment({
    required String orderId,
    required String buyerId,
    required double amount,
    required String currency,
    required PaymentMethod paymentMethod,
    required bool useEscrow,
  }) async {
    try {
      // Create payment record
      final paymentId = await _createPaymentRecord(
        orderId: orderId,
        buyerId: buyerId,
        amount: amount,
        currency: currency,
        method: paymentMethod,
        useEscrow: useEscrow,
      );
      
      // Process payment based on method
      PaymentProcessResult processResult;
      
      switch (paymentMethod) {
        case PaymentMethod.akofa:
          processResult = await _processAkofaPayment(
            paymentId: paymentId,
            buyerId: buyerId,
            amount: amount,
            useEscrow: useEscrow,
            orderId: orderId,
          );
          break;
          
        case PaymentMethod.stellar:
          processResult = await _processStellarPayment(
            paymentId: paymentId,
            buyerId: buyerId,
            amount: amount,
            currency: currency,
            useEscrow: useEscrow,
            orderId: orderId,
          );
          break;
          
        case PaymentMethod.mpesa:
          processResult = await _processMpesaPayment(
            paymentId: paymentId,
            buyerId: buyerId,
            amount: amount,
            useEscrow: useEscrow,
            orderId: orderId,
          );
          break;
          
        case PaymentMethod.stripe:
          processResult = await _processStripePayment(
            paymentId: paymentId,
            buyerId: buyerId,
            amount: amount,
            currency: currency,
            useEscrow: useEscrow,
            orderId: orderId,
          );
          break;
          
        case PaymentMethod.crypto:
          processResult = await _processCryptoPayment(
            paymentId: paymentId,
            buyerId: buyerId,
            amount: amount,
            currency: currency,
            useEscrow: useEscrow,
            orderId: orderId,
          );
          break;
      }
      
      // Update payment status
      await _updatePaymentStatus(paymentId, processResult.status, processResult.transactionId);
      
      // Create escrow if payment successful and requested
      String? escrowId;
      if (processResult.success && useEscrow) {
        escrowId = await _createEscrow(
          paymentId: paymentId,
          orderId: orderId,
          amount: amount,
          currency: currency,
        );
      }
      
      // Update order status
      if (processResult.success) {
        await _updateOrderPaymentStatus(orderId, PaymentStatus.paid, escrowId);
      } else {
        await _updateOrderPaymentStatus(orderId, PaymentStatus.failed, null);
      }
      
      return PaymentResult(
        success: processResult.success,
        paymentId: paymentId,
        transactionId: processResult.transactionId,
        escrowId: escrowId,
        message: processResult.message,
      );
      
    } catch (e) {
      return PaymentResult(
        success: false,
        paymentId: '',
        transactionId: null,
        escrowId: null,
        message: 'Payment processing failed: ${e.toString()}',
      );
    }
  }
  
  /// Process AKOFA payment
  Future<PaymentProcessResult> _processAkofaPayment({
    required String paymentId,
    required String buyerId,
    required double amount,
    required bool useEscrow,
    required String orderId,
  }) async {
    try {
      // Get buyer's AKOFA balance
      final buyerDoc = await _firestore.collection('users').doc(buyerId).get();
      final currentBalance = (buyerDoc.data()?['akofaBalance'] ?? 0.0).toDouble();
      
      if (currentBalance < amount) {
        return PaymentProcessResult(
          success: false,
          status: PaymentStatus.failed,
          transactionId: null,
          message: 'Insufficient AKOFA balance',
        );
      }
      
      // Create transaction ID
      final transactionId = 'akofa_${DateTime.now().millisecondsSinceEpoch}';
      
      if (useEscrow) {
        // Transfer to escrow account
        final escrowAccount = await _getEscrowAccount();
        await _stellarService.sendAsset(escrowAccount, amount.toString(), 'AKOFA');
      } else {
        // Direct transfer to vendor
        final order = await _getOrder(orderId);
        await _stellarService.sendAsset(order.vendorId, amount.toString(), 'AKOFA');
      }
      
      // Update buyer balance
      await _firestore.collection('users').doc(buyerId).update({
        'akofaBalance': FieldValue.increment(-amount),
        'lastTransaction': FieldValue.serverTimestamp(),
      });
      
      return PaymentProcessResult(
        success: true,
        status: useEscrow ? PaymentStatus.escrowed : PaymentStatus.paid,
        transactionId: transactionId,
        message: 'AKOFA payment successful',
      );
      
    } catch (e) {
      return PaymentProcessResult(
        success: false,
        status: PaymentStatus.failed,
        transactionId: null,
        message: 'AKOFA payment failed: ${e.toString()}',
      );
    }
  }
  
  /// Process Stellar payment
  Future<PaymentProcessResult> _processStellarPayment({
    required String paymentId,
    required String buyerId,
    required double amount,
    required String currency,
    required bool useEscrow,
    required String orderId,
  }) async {
    try {
      final transactionId = 'stellar_${DateTime.now().millisecondsSinceEpoch}';
      
      if (useEscrow) {
        final escrowAccount = await _getEscrowAccount();
        await _stellarService.sendAsset(escrowAccount, amount.toString(), currency);
      } else {
        final order = await _getOrder(orderId);
        await _stellarService.sendAsset(order.vendorId, amount.toString(), currency);
      }
      
      return PaymentProcessResult(
        success: true,
        status: useEscrow ? PaymentStatus.escrowed : PaymentStatus.paid,
        transactionId: transactionId,
        message: 'Stellar payment successful',
      );
      
    } catch (e) {
      return PaymentProcessResult(
        success: false,
        status: PaymentStatus.failed,
        transactionId: null,
        message: 'Stellar payment failed: ${e.toString()}',
      );
    }
  }
  
  /// Process M-Pesa payment
  Future<PaymentProcessResult> _processMpesaPayment({
    required String paymentId,
    required String buyerId,
    required double amount,
    required bool useEscrow,
    required String orderId,
  }) async {
    try {
      // Get user phone number
      final userDoc = await _firestore.collection('users').doc(buyerId).get();
      final phoneNumber = userDoc.data()?['phoneNumber'] as String?;
      
      if (phoneNumber == null) {
        return PaymentProcessResult(
          success: false,
          status: PaymentStatus.failed,
          transactionId: null,
          message: 'Phone number required for M-Pesa payment',
        );
      }
      
      // Initiate STK Push (this would integrate with actual M-Pesa API)
      final stkResult = await _initiateStkPush(
        phoneNumber: phoneNumber,
        amount: amount,
        reference: paymentId,
      );
      
      if (!stkResult.success) {
        return PaymentProcessResult(
          success: false,
          status: PaymentStatus.failed,
          transactionId: null,
          message: stkResult.message,
        );
      }
      
      // For demo purposes, simulate successful payment
      // In production, this would be handled by M-Pesa callback
      return PaymentProcessResult(
        success: true,
        status: PaymentStatus.processing,
        transactionId: stkResult.transactionId,
        message: 'M-Pesa payment initiated. Please complete on your phone.',
      );
      
    } catch (e) {
      return PaymentProcessResult(
        success: false,
        status: PaymentStatus.failed,
        transactionId: null,
        message: 'M-Pesa payment failed: ${e.toString()}',
      );
    }
  }
  
  /// Process Stripe payment
  Future<PaymentProcessResult> _processStripePayment({
    required String paymentId,
    required String buyerId,
    required double amount,
    required String currency,
    required bool useEscrow,
    required String orderId,
  }) async {
    try {
      // This would integrate with actual Stripe SDK
      // For demo purposes, simulate successful payment
      final transactionId = 'stripe_${DateTime.now().millisecondsSinceEpoch}';
      
      return PaymentProcessResult(
        success: true,
        status: useEscrow ? PaymentStatus.escrowed : PaymentStatus.paid,
        transactionId: transactionId,
        message: 'Stripe payment successful',
      );
      
    } catch (e) {
      return PaymentProcessResult(
        success: false,
        status: PaymentStatus.failed,
        transactionId: null,
        message: 'Stripe payment failed: ${e.toString()}',
      );
    }
  }
  
  /// Process cryptocurrency payment
  Future<PaymentProcessResult> _processCryptoPayment({
    required String paymentId,
    required String buyerId,
    required double amount,
    required String currency,
    required bool useEscrow,
    required String orderId,
  }) async {
    try {
      // This would integrate with crypto payment processors
      // For demo purposes, simulate successful payment
      final transactionId = 'crypto_${DateTime.now().millisecondsSinceEpoch}';
      
      return PaymentProcessResult(
        success: true,
        status: useEscrow ? PaymentStatus.escrowed : PaymentStatus.paid,
        transactionId: transactionId,
        message: 'Cryptocurrency payment successful',
      );
      
    } catch (e) {
      return PaymentProcessResult(
        success: false,
        status: PaymentStatus.failed,
        transactionId: null,
        message: 'Cryptocurrency payment failed: ${e.toString()}',
      );
    }
  }
  
  /// Create escrow for secure transaction
  Future<String> _createEscrow({
    required String paymentId,
    required String orderId,
    required double amount,
    required String currency,
  }) async {
    final escrowId = 'escrow_${DateTime.now().millisecondsSinceEpoch}';
    
    final escrowData = {
      'escrowId': escrowId,
      'paymentId': paymentId,
      'orderId': orderId,
      'amount': amount,
      'currency': currency,
      'status': EscrowStatus.held.toString(),
      'createdAt': FieldValue.serverTimestamp(),
      'releaseScheduledAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 7)), // Auto-release after 7 days
      ),
      'events': [],
    };
    
    await _firestore.collection('escrows').doc(escrowId).set(escrowData);
    
    // Add escrow event
    await _addEscrowEvent(
      escrowId: escrowId,
      action: 'created',
      description: 'Escrow created for order payment',
    );
    
    return escrowId;
  }
  
  /// Release escrow to vendor
  Future<EscrowReleaseResult> releaseEscrow({
    required String escrowId,
    required String actorId,
    required String reason,
  }) async {
    try {
      final escrowDoc = await _firestore.collection('escrows').doc(escrowId).get();
      
      if (!escrowDoc.exists) {
        return EscrowReleaseResult(
          success: false,
          message: 'Escrow not found',
        );
      }
      
      final escrowData = escrowDoc.data()!;
      final status = EscrowStatus.values.firstWhere(
        (s) => s.toString() == escrowData['status'],
      );
      
      if (status != EscrowStatus.held) {
        return EscrowReleaseResult(
          success: false,
          message: 'Escrow cannot be released in current status: $status',
        );
      }
      
      // Get order to find vendor
      final orderId = escrowData['orderId'] as String;
      final order = await _getOrder(orderId);
      
      // Transfer funds to vendor
      final amount = (escrowData['amount'] as num).toDouble();
      final currency = escrowData['currency'] as String;
      
      await _stellarService.sendAsset(order.vendorId, amount.toString(), currency);
      
      // Update escrow status
      await _firestore.collection('escrows').doc(escrowId).update({
        'status': EscrowStatus.released.toString(),
        'releasedAt': FieldValue.serverTimestamp(),
        'releaseReason': reason,
        'releasedBy': actorId,
      });
      
      // Add escrow event
      await _addEscrowEvent(
        escrowId: escrowId,
        action: 'released',
        description: 'Escrow released to vendor: $reason',
        actorId: actorId,
      );
      
      // Update order payment status
      await _updateOrderPaymentStatus(orderId, PaymentStatus.released, null);
      
      return EscrowReleaseResult(
        success: true,
        message: 'Escrow successfully released to vendor',
      );
      
    } catch (e) {
      return EscrowReleaseResult(
        success: false,
        message: 'Failed to release escrow: ${e.toString()}',
      );
    }
  }
  
  /// Refund escrow to buyer
  Future<EscrowRefundResult> refundEscrow({
    required String escrowId,
    required String actorId,
    required String reason,
  }) async {
    try {
      final escrowDoc = await _firestore.collection('escrows').doc(escrowId).get();
      
      if (!escrowDoc.exists) {
        return EscrowRefundResult(
          success: false,
          message: 'Escrow not found',
        );
      }
      
      final escrowData = escrowDoc.data()!;
      final status = EscrowStatus.values.firstWhere(
        (s) => s.toString() == escrowData['status'],
      );
      
      if (status != EscrowStatus.held) {
        return EscrowRefundResult(
          success: false,
          message: 'Escrow cannot be refunded in current status: $status',
        );
      }
      
      // Get order to find buyer
      final orderId = escrowData['orderId'] as String;
      final order = await _getOrder(orderId);
      
      // Refund to buyer
      final amount = (escrowData['amount'] as num).toDouble();
      final currency = escrowData['currency'] as String;
      
      if (currency == 'AKOFA') {
        // Refund AKOFA to user balance
        await _firestore.collection('users').doc(order.buyerId).update({
          'akofaBalance': FieldValue.increment(amount),
        });
      } else {
        // Refund other currencies via Stellar
        await _stellarService.sendAsset(order.buyerId, amount.toString(), currency);
      }
      
      // Update escrow status
      await _firestore.collection('escrows').doc(escrowId).update({
        'status': EscrowStatus.refunded.toString(),
        'refundedAt': FieldValue.serverTimestamp(),
        'refundReason': reason,
        'refundedBy': actorId,
      });
      
      // Add escrow event
      await _addEscrowEvent(
        escrowId: escrowId,
        action: 'refunded',
        description: 'Escrow refunded to buyer: $reason',
        actorId: actorId,
      );
      
      // Update order payment status
      await _updateOrderPaymentStatus(orderId, PaymentStatus.refunded, null);
      
      return EscrowRefundResult(
        success: true,
        message: 'Escrow successfully refunded to buyer',
      );
      
    } catch (e) {
      return EscrowRefundResult(
        success: false,
        message: 'Failed to refund escrow: ${e.toString()}',
      );
    }
  }
  
  /// Process dispute resolution
  Future<DisputeResolutionResult> resolveDispute({
    required String escrowId,
    required String resolution,
    required DisputeResolution resolutionType,
    required String adminId,
  }) async {
    try {
      final escrowDoc = await _firestore.collection('escrows').doc(escrowId).get();
      
      if (!escrowDoc.exists) {
        return DisputeResolutionResult(
          success: false,
          message: 'Escrow not found',
        );
      }
      
      switch (resolutionType) {
        case DisputeResolution.releaseToVendor:
          final releaseResult = await releaseEscrow(
            escrowId: escrowId,
            actorId: adminId,
            reason: 'Dispute resolved in favor of vendor: $resolution',
          );
          return DisputeResolutionResult(
            success: releaseResult.success,
            message: releaseResult.message,
          );
          
        case DisputeResolution.refundToBuyer:
          final refundResult = await refundEscrow(
            escrowId: escrowId,
            actorId: adminId,
            reason: 'Dispute resolved in favor of buyer: $resolution',
          );
          return DisputeResolutionResult(
            success: refundResult.success,
            message: refundResult.message,
          );
          
        case DisputeResolution.partialRefund:
          // TODO: Implement partial refund logic
          return DisputeResolutionResult(
            success: false,
            message: 'Partial refund not yet implemented',
          );
          
        case DisputeResolution.split:
          // TODO: Implement split resolution logic
          return DisputeResolutionResult(
            success: false,
            message: 'Split resolution not yet implemented',
          );
      }
      
    } catch (e) {
      return DisputeResolutionResult(
        success: false,
        message: 'Failed to resolve dispute: ${e.toString()}',
      );
    }
  }
  
  /// Auto-release expired escrows
  Future<void> processExpiredEscrows() async {
    try {
      final now = Timestamp.now();
      
      final expiredEscrows = await _firestore
          .collection('escrows')
          .where('status', isEqualTo: EscrowStatus.held.toString())
          .where('releaseScheduledAt', isLessThanOrEqualTo: now)
          .get();
      
      for (final doc in expiredEscrows.docs) {
        final escrowId = doc.id;
        await releaseEscrow(
          escrowId: escrowId,
          actorId: 'system',
          reason: 'Auto-released after expiration period',
        );
      }
      
    } catch (e) {
      print('Error processing expired escrows: $e');
    }
  }
  
  /// Get payment history for user
  Future<List<PaymentRecord>> getPaymentHistory({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('payments')
          .where('buyerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return PaymentRecord.fromJson(data, doc.id);
      }).toList();
      
    } catch (e) {
      print('Error getting payment history: $e');
      return [];
    }
  }
  
  /// Helper methods
  
  Future<String> _createPaymentRecord({
    required String orderId,
    required String buyerId,
    required double amount,
    required String currency,
    required PaymentMethod method,
    required bool useEscrow,
  }) async {
    final paymentId = 'payment_${DateTime.now().millisecondsSinceEpoch}';
    
    final paymentData = {
      'paymentId': paymentId,
      'orderId': orderId,
      'buyerId': buyerId,
      'amount': amount,
      'currency': currency,
      'method': method.toString(),
      'useEscrow': useEscrow,
      'status': PaymentStatus.pending.toString(),
      'createdAt': FieldValue.serverTimestamp(),
    };
    
    await _firestore.collection('payments').doc(paymentId).set(paymentData);
    
    return paymentId;
  }
  
  Future<void> _updatePaymentStatus(
    String paymentId,
    PaymentStatus status,
    String? transactionId,
  ) async {
    final updates = <String, dynamic>{
      'status': status.toString(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    if (transactionId != null) {
      updates['transactionId'] = transactionId;
    }
    
    await _firestore.collection('payments').doc(paymentId).update(updates);
  }
  
  Future<void> _updateOrderPaymentStatus(
    String orderId,
    PaymentStatus status,
    String? escrowId,
  ) async {
    final updates = <String, dynamic>{
      'paymentStatus': status.toString(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    if (escrowId != null) {
      updates['escrowId'] = escrowId;
    }
    
    await _firestore.collection('marketplace_orders').doc(orderId).update(updates);
  }
  
  Future<MarketplaceOrder> _getOrder(String orderId) async {
    final doc = await _firestore.collection('marketplace_orders').doc(orderId).get();
    return MarketplaceOrder.fromJson(doc.data()!, orderId);
  }
  
  Future<String> _getEscrowAccount() async {
    // In production, this would be a dedicated escrow account
    return 'ESCROW_ACCOUNT_ID';
  }
  
  Future<StkPushResult> _initiateStkPush({
    required String phoneNumber,
    required double amount,
    required String reference,
  }) async {
    // This would integrate with actual M-Pesa STK Push API
    // For demo purposes, simulate successful initiation
    return StkPushResult(
      success: true,
      transactionId: 'mpesa_${DateTime.now().millisecondsSinceEpoch}',
      message: 'STK Push initiated successfully',
    );
  }
  
  Future<void> _addEscrowEvent({
    required String escrowId,
    required String action,
    required String description,
    String? actorId,
  }) async {
    final event = {
      'timestamp': FieldValue.serverTimestamp(),
      'action': action,
      'description': description,
      'actorId': actorId,
    };
    
    await _firestore.collection('escrows').doc(escrowId).update({
      'events': FieldValue.arrayUnion([event]),
    });
  }
}

/// Payment method options
enum PaymentMethod {
  akofa,     // Native AKOFA tokens
  stellar,   // Stellar network assets
  mpesa,     // M-Pesa mobile money
  stripe,    // Stripe card payments
  crypto,    // Cryptocurrency
}

/// Payment processing result
class PaymentProcessResult {
  final bool success;
  final PaymentStatus status;
  final String? transactionId;
  final String message;
  
  PaymentProcessResult({
    required this.success,
    required this.status,
    required this.transactionId,
    required this.message,
  });
}

/// Final payment result
class PaymentResult {
  final bool success;
  final String paymentId;
  final String? transactionId;
  final String? escrowId;
  final String message;
  
  PaymentResult({
    required this.success,
    required this.paymentId,
    required this.transactionId,
    required this.escrowId,
    required this.message,
  });
}

/// Escrow release result
class EscrowReleaseResult {
  final bool success;
  final String message;
  
  EscrowReleaseResult({
    required this.success,
    required this.message,
  });
}

/// Escrow refund result
class EscrowRefundResult {
  final bool success;
  final String message;
  
  EscrowRefundResult({
    required this.success,
    required this.message,
  });
}

/// Dispute resolution result
class DisputeResolutionResult {
  final bool success;
  final String message;
  
  DisputeResolutionResult({
    required this.success,
    required this.message,
  });
}

/// Dispute resolution types
enum DisputeResolution {
  releaseToVendor,  // Release full amount to vendor
  refundToBuyer,    // Refund full amount to buyer
  partialRefund,    // Partial refund to buyer, rest to vendor
  split,            // Split amount between buyer and vendor
}

/// STK Push result
class StkPushResult {
  final bool success;
  final String? transactionId;
  final String message;
  
  StkPushResult({
    required this.success,
    required this.transactionId,
    required this.message,
  });
}

/// Payment record model
class PaymentRecord {
  final String id;
  final String orderId;
  final String buyerId;
  final double amount;
  final String currency;
  final PaymentMethod method;
  final PaymentStatus status;
  final bool useEscrow;
  final String? transactionId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  PaymentRecord({
    required this.id,
    required this.orderId,
    required this.buyerId,
    required this.amount,
    required this.currency,
    required this.method,
    required this.status,
    required this.useEscrow,
    this.transactionId,
    required this.createdAt,
    this.updatedAt,
  });
  
  factory PaymentRecord.fromJson(Map<String, dynamic> json, String id) {
    return PaymentRecord(
      id: id,
      orderId: json['orderId'] ?? '',
      buyerId: json['buyerId'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      currency: json['currency'] ?? 'AKOFA',
      method: PaymentMethod.values.firstWhere(
        (m) => m.toString() == json['method'],
        orElse: () => PaymentMethod.akofa,
      ),
      status: PaymentStatus.values.firstWhere(
        (s) => s.toString() == json['status'],
        orElse: () => PaymentStatus.pending,
      ),
      useEscrow: json['useEscrow'] ?? false,
      transactionId: json['transactionId'],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
