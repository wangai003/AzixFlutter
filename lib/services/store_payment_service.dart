import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'polygon_wallet_service.dart';
import 'transaction_service.dart';
import '../models/asset_config.dart';

/// Service for processing store payments with order IDs
/// Handles wallet payments for store purchases
class StorePaymentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Backend server URL - should match your backend configuration
  static const String _backendUrl = String.fromEnvironment(
    'AZIX_BACKEND_URL',
    defaultValue: 'http://localhost:3000',
  );
  // For production: 'https://your-backend.herokuapp.com'
  // For mobile testing: 'http://YOUR_IP_ADDRESS:3000'

  /// Process payment for a store order using Polygon wallet
  /// 
  /// This method:
  /// 1. Executes the Polygon wallet transaction
  /// 2. Stores payment details with order ID in backend
  /// 3. Records transaction in Firestore
  static Future<StorePaymentResult> processStorePayment({
    required String orderId,
    required String recipientAddress,
    required double amount,
    required String assetCode,
    required String password, // Required for Polygon wallet authentication
    String? storeId,
    String? storeName,
    String? memo,
    Map<String, dynamic>? additionalData,
  }) async {
    Map<String, dynamic>? previousNetwork;
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }

      // Validate order ID
      if (orderId.trim().isEmpty) {
        throw Exception('Order ID is required');
      }

      // Validate amount
      if (amount <= 0) {
        throw Exception('Amount must be greater than 0');
      }

      // Validate recipient address (must be Polygon address: 0x...)
      if (recipientAddress.trim().isEmpty) {
        throw Exception('Recipient address is required');
      }

      // Validate Polygon address format
      if (!recipientAddress.startsWith('0x') || recipientAddress.length != 42) {
        throw Exception('Invalid Polygon address format. Must start with 0x and be 42 characters long.');
      }

      // Validate asset code - only AKOFA, USDC, USDT allowed
      const allowedAssets = ['AKOFA', 'USDC', 'USDT'];
      final normalizedAssetCode = assetCode.toUpperCase();
      if (!allowedAssets.contains(normalizedAssetCode)) {
        throw Exception('Only AKOFA, USDC, and USDT are allowed for store payments. Received: $assetCode');
      }

      print('🛒 [STORE PAYMENT] Processing payment for order: $orderId');
      print('💰 Amount: $amount $assetCode');
      print('📍 Recipient: ${recipientAddress.substring(0, 10)}...');
      print('⛓️  Network: Polygon');

      // Step 0: Validate order before sending any funds
      final orderValidation = await _validateOrderBeforePayment(
        orderId: orderId,
        amount: amount,
        userId: user.uid,
      );
      if (orderValidation['success'] != true) {
        throw Exception(orderValidation['error'] ?? 'Order validation failed');
      }

      // Step 1: Execute Polygon wallet transaction
      Map<String, dynamic> transactionResult;
      String transactionHash;

      try {
        // Get contract address for the token (already validated above)
        final normalizedAssetCode = assetCode.toUpperCase();

        // Switch network based on asset (AKOFA testnet, others mainnet)
        previousNetwork = PolygonWalletService.getNetworkInfo();
        final isAkofa = normalizedAssetCode == 'AKOFA';
        PolygonWalletService.setNetwork(isTestnet: isAkofa);

        String tokenContractAddress;
        switch (normalizedAssetCode) {
          case 'AKOFA':
            tokenContractAddress = '0xf1266ACCf0f757c61e4DFDD9EBBcaC05D2Ee375F'; // AKOFA on Polygon Amoy
            break;
          case 'USDC':
            tokenContractAddress = '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359'; // USDC on Polygon
            break;
          case 'USDT':
            tokenContractAddress = '0xc2132D05D31c914a87C6611C10748AEb04B58e8F'; // USDT on Polygon
            break;
          default:
            throw Exception('Unsupported asset: $assetCode');
        }

        // Execute the payment transaction on Polygon (all are ERC-20 tokens)
        transactionResult = await PolygonWalletService.sendERC20TokenWithAuth(
          userId: user.uid,
          password: password,
          tokenContractAddress: tokenContractAddress,
          toAddress: recipientAddress,
          amount: amount,
        );

        transactionHash = transactionResult['txHash'] ?? 
                         transactionResult['transactionHash'] ?? 
                         transactionResult['hash'] ?? 
                         '';

        if (transactionHash.isEmpty) {
          throw Exception('Transaction hash not found in response');
        }

        print('✅ [STORE PAYMENT] Polygon transaction sent: $transactionHash');
      } catch (e) {
        print('❌ [STORE PAYMENT] Transaction failed: $e');
        return StorePaymentResult(
          success: false,
          orderId: orderId,
          error: 'Transaction failed: ${e.toString()}',
        );
      }

      // Step 2: Verify transaction receipt (best-effort)
      final receiptResult = await _waitForTransactionReceipt(transactionHash);
      final txStatus = receiptResult['status'] as String? ?? 'pending';
      if (txStatus != 'success') {
        return StorePaymentResult(
          success: false,
          orderId: orderId,
          transactionHash: transactionHash,
          error: txStatus == 'failed'
              ? 'Transaction failed on-chain'
              : 'Transaction not confirmed on-chain yet',
        );
      }

      // Step 3: Get sender address for storage
      String? senderAddress;
      try {
        senderAddress = await PolygonWalletService.getCorrectWalletAddress(user.uid);
        if (senderAddress == null) {
          print('⚠️  [STORE PAYMENT] Could not get sender address');
        }
      } catch (e) {
        print('⚠️  [STORE PAYMENT] Could not get sender address: $e');
      }

      // Step 4: Store payment transaction in backend
      bool backendStored = false;
      try {
        final backendResult = await _storePaymentInBackend(
          orderId: orderId,
          transactionHash: transactionHash,
          amount: amount,
          assetCode: assetCode,
          recipientAddress: recipientAddress,
          senderAddress: senderAddress,
          userId: user.uid,
          storeId: storeId,
          storeName: storeName,
          additionalData: {
            'txStatus': txStatus,
            ...?additionalData,
          },
        );

        backendStored = backendResult['success'] == true;
        print('${backendStored ? '✅' : '⚠️'} [STORE PAYMENT] Backend storage: ${backendStored ? 'Success' : 'Failed'}');
      } catch (e) {
        print('⚠️  [STORE PAYMENT] Backend storage error: $e');
        // Continue to store in Firestore but flag failure to caller
      }

      // Step 5: Store payment transaction in Firestore (local backup)
      try {
        await _storePaymentInFirestore(
          orderId: orderId,
          transactionHash: transactionHash,
          amount: amount,
          assetCode: assetCode,
          recipientAddress: recipientAddress,
          senderAddress: senderAddress,
          userId: user.uid,
          storeId: storeId,
          storeName: storeName,
          status: txStatus,
          additionalData: {
            'txStatus': txStatus,
            ...?additionalData,
          },
        );
        print('✅ [STORE PAYMENT] Firestore storage successful');
      } catch (e) {
        print('⚠️  [STORE PAYMENT] Firestore storage error: $e');
      }

      // Step 6: Record transaction in transaction history
      try {
        final networkInfo = PolygonWalletService.getNetworkInfo();
        await TransactionService.recordSend(
          amount: amount,
          assetCode: assetCode,
          recipientAddress: recipientAddress,
          memo: memo ?? 'Order: $orderId',
          stellarHash: transactionHash, // Using same field for Polygon tx hash
          additionalMetadata: {
            'orderId': orderId,
            'paymentType': 'store_payment',
            'storeId': storeId,
            'storeName': storeName,
            'blockchain': 'polygon',
            'network': networkInfo['isTestnet'] == true
                ? 'polygon-amoy'
                : 'polygon-mainnet',
            'chainId': networkInfo['chainId'],
            'txStatus': txStatus,
            ...?additionalData,
          },
        );
      } catch (e) {
        print('⚠️  [STORE PAYMENT] Transaction history recording error: $e');
      }

      if (!backendStored) {
        return StorePaymentResult(
          success: false,
          orderId: orderId,
          transactionHash: transactionHash,
          amount: amount,
          assetCode: assetCode,
          backendStored: false,
          error: 'Payment sent on-chain but backend recording failed',
        );
      }

      return StorePaymentResult(
        success: true,
        orderId: orderId,
        transactionHash: transactionHash,
        amount: amount,
        assetCode: assetCode,
        backendStored: true,
      );
    } catch (e) {
      print('❌ [STORE PAYMENT] Payment processing error: $e');
      return StorePaymentResult(
        success: false,
        orderId: orderId,
        error: e.toString(),
      );
    } finally {
      // Restore previous network if we switched
      if (previousNetwork != null) {
        final wasTestnet = previousNetwork['isTestnet'] == true;
        PolygonWalletService.setNetwork(isTestnet: wasTestnet);
      }
    }
  }

  /// Store payment transaction in backend
  static Future<Map<String, dynamic>> _storePaymentInBackend({
    required String orderId,
    required String transactionHash,
    required double amount,
    required String assetCode,
    required String recipientAddress,
    String? senderAddress,
    required String userId,
    String? storeId,
    String? storeName,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/api/store-payment/store'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'orderId': orderId,
          'transactionHash': transactionHash,
          'amount': amount,
          'assetCode': assetCode,
          'recipientAddress': recipientAddress,
          'senderAddress': senderAddress,
          'userId': userId,
          'storeId': storeId,
          'storeName': storeName,
          'additionalData': additionalData ?? {},
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Backend request timeout');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Backend storage failed');
      }
    } catch (e) {
      print('❌ [STORE PAYMENT] Backend storage error: $e');
      rethrow;
    }
  }

  /// Store payment transaction in Firestore (local backup)
  static Future<void> _storePaymentInFirestore({
    required String orderId,
    required String transactionHash,
    required double amount,
    required String assetCode,
    required String recipientAddress,
    String? senderAddress,
    required String userId,
    String? storeId,
    String? storeName,
    String status = 'completed',
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final paymentData = {
        'orderId': orderId,
        'transactionHash': transactionHash,
        'amount': amount,
        'assetCode': assetCode,
        'recipientAddress': recipientAddress,
        'senderAddress': senderAddress,
        'userId': userId,
        'storeId': storeId,
        'storeName': storeName,
        'status': status,
        'paymentType': 'wallet',
        'additionalData': additionalData ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Store in main collection
      await _firestore
          .collection('store_payment_transactions')
          .add(paymentData);

      // Store in user-specific collection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('store_payments')
          .add(paymentData);

      // Store in order-specific collection
      await _firestore
          .collection('orders')
          .doc(orderId)
          .collection('payments')
          .add(paymentData);

      // Update order status if the order exists
      final orderRef = _firestore.collection('orders').doc(orderId);
      final orderDoc = await orderRef.get();
      if (orderDoc.exists) {
        await orderRef.update({
          'paymentStatus': 'completed',
          'paymentTransactionHash': transactionHash,
          'paymentCompletedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('❌ [STORE PAYMENT] Firestore storage error: $e');
      rethrow;
    }
  }

  /// Get payment by order ID
  static Future<StorePaymentTransaction?> getPaymentByOrderId(String orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/api/store-payment/order/$orderId'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['payment'] != null) {
          return StorePaymentTransaction.fromJson(data['payment']);
        }
      }
      return null;
    } catch (e) {
      print('❌ [STORE PAYMENT] Get payment error: $e');
      return null;
    }
  }

  /// Verify payment transaction
  static Future<bool> verifyPayment({
    required String orderId,
    required String transactionHash,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/api/store-payment/verify'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'orderId': orderId,
          'transactionHash': transactionHash,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true && data['verified'] == true;
      }
      return false;
    } catch (e) {
      print('❌ [STORE PAYMENT] Verify payment error: $e');
      return false;
    }
  }

  /// Get user's store payment history
  static Stream<List<StorePaymentTransaction>> getUserPaymentHistory(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('store_payments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StorePaymentTransaction.fromFirestore(doc))
            .toList());
  }

  static Future<Map<String, dynamic>> _validateOrderBeforePayment({
    required String orderId,
    required double amount,
    required String userId,
  }) async {
    try {
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) {
        return {
          'success': false,
          'error': 'Order not found',
        };
      }

      final data = orderDoc.data() ?? {};
      final paymentStatus = (data['paymentStatus'] ?? 'pending').toString();
      if (paymentStatus == 'paid' || paymentStatus == 'completed') {
        return {
          'success': false,
          'error': 'Order is already paid',
        };
      }

      final status = (data['status'] ?? 'pending').toString();
      if (status == 'cancelled' || status == 'refunded') {
        return {
          'success': false,
          'error': 'Order is not payable (status: $status)',
        };
      }

      final totalAmount = (data['totalAmount'] as num?)?.toDouble();
      if (totalAmount != null && totalAmount > 0 && amount != totalAmount) {
        return {
          'success': false,
          'error': 'Payment amount does not match order total',
        };
      }

      final customerId = data['customerId'] ?? data['buyerId'];
      if (customerId != null && customerId != userId) {
        return {
          'success': false,
          'error': 'Order does not belong to this user',
        };
      }

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': 'Order validation failed: $e'};
    }
  }

  static Future<Map<String, dynamic>> _waitForTransactionReceipt(
    String txHash, {
    int maxAttempts = 5,
    Duration delay = const Duration(seconds: 3),
  }) async {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final receiptResult =
          await PolygonWalletService.getTransactionReceipt(txHash);
      if (receiptResult['success'] == true) {
        return {
          'status': receiptResult['status'],
          'receipt': receiptResult['receipt'],
        };
      }
      await Future.delayed(delay);
    }
    return {'status': 'pending'};
  }
}

/// Store payment result model
class StorePaymentResult {
  final bool success;
  final String orderId;
  final String? transactionHash;
  final double? amount;
  final String? assetCode;
  final bool? backendStored;
  final String? error;

  StorePaymentResult({
    required this.success,
    required this.orderId,
    this.transactionHash,
    this.amount,
    this.assetCode,
    this.backendStored,
    this.error,
  });
}

/// Store payment transaction model
class StorePaymentTransaction {
  final String id;
  final String orderId;
  final String transactionHash;
  final double amount;
  final String assetCode;
  final String? recipientAddress;
  final String? senderAddress;
  final String? userId;
  final String? storeId;
  final String? storeName;
  final String status;
  final String paymentType;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> additionalData;

  StorePaymentTransaction({
    required this.id,
    required this.orderId,
    required this.transactionHash,
    required this.amount,
    required this.assetCode,
    this.recipientAddress,
    this.senderAddress,
    this.userId,
    this.storeId,
    this.storeName,
    required this.status,
    required this.paymentType,
    this.createdAt,
    this.updatedAt,
    this.additionalData = const {},
  });

  factory StorePaymentTransaction.fromJson(Map<String, dynamic> json) {
    return StorePaymentTransaction(
      id: json['id'] ?? '',
      orderId: json['orderId'] ?? '',
      transactionHash: json['transactionHash'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      assetCode: json['assetCode'] ?? '',
      recipientAddress: json['recipientAddress'],
      senderAddress: json['senderAddress'],
      userId: json['userId'],
      storeId: json['storeId'],
      storeName: json['storeName'],
      status: json['status'] ?? 'completed',
      paymentType: json['paymentType'] ?? 'wallet',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      additionalData: Map<String, dynamic>.from(json['additionalData'] ?? {}),
    );
  }

  factory StorePaymentTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StorePaymentTransaction(
      id: doc.id,
      orderId: data['orderId'] ?? '',
      transactionHash: data['transactionHash'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      assetCode: data['assetCode'] ?? '',
      recipientAddress: data['recipientAddress'],
      senderAddress: data['senderAddress'],
      userId: data['userId'],
      storeId: data['storeId'],
      storeName: data['storeName'],
      status: data['status'] ?? 'completed',
      paymentType: data['paymentType'] ?? 'wallet',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      additionalData: Map<String, dynamic>.from(data['additionalData'] ?? {}),
    );
  }
}

