import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart' as crypto;

/// Service for handling payment webhooks and status verification
/// Provides client-side polling fallback for webhook-based confirmations
class PaymentWebhookService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Webhook endpoints (configured in Firebase Functions)
  static const String _webhookBaseUrl =
      'https://your-region-your-project.cloudfunctions.net';

  /// Verify MTN payment status (polling fallback for webhooks)
  Future<Map<String, dynamic>> verifyMtnPaymentStatus(String txRef) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Call Firebase Function for verification
      final response = await http.post(
        Uri.parse('$_webhookBaseUrl/verifyMtnPayment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await user.getIdToken()}',
        },
        body: jsonEncode({'txRef': txRef}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Verification failed: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Payment verification error: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get transaction status from local database
  Future<Map<String, dynamic>?> getTransactionStatus(
    String txRef, {
    String collection = 'mtn_transactions',
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final querySnapshot = await _firestore
          .collection(collection)
          .where('txRef', isEqualTo: txRef)
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return {'id': doc.id, ...doc.data()};
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching transaction status: $e');
      }
      return null;
    }
  }

  /// Poll for payment status updates
  Future<Map<String, dynamic>> pollPaymentStatus(
    String txRef, {
    String collection = 'mtn_transactions',
    Duration timeout = const Duration(minutes: 10),
    Duration interval = const Duration(seconds: 30),
  }) async {
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < timeout) {
      try {
        // Check local database first
        final localStatus = await getTransactionStatus(
          txRef,
          collection: collection,
        );
        if (localStatus != null) {
          final status = localStatus['status'];
          if (status == 'credited') {
            return {
              'success': true,
              'status': 'completed',
              'data': localStatus,
              'source': 'local',
            };
          } else if (status == 'failed') {
            return {
              'success': false,
              'status': 'failed',
              'data': localStatus,
              'source': 'local',
            };
          }
        }

        // If not found locally or still pending, verify with provider
        if (collection == 'mtn_transactions') {
          final remoteStatus = await verifyMtnPaymentStatus(txRef);
          if (remoteStatus['success'] == true) {
            if (remoteStatus['status'] == 'completed') {
              return {
                'success': true,
                'status': 'completed',
                'data': remoteStatus['data'],
                'source': 'remote',
              };
            } else if (remoteStatus['status'] == 'failed') {
              return {
                'success': false,
                'status': 'failed',
                'data': remoteStatus['data'],
                'source': 'remote',
              };
            }
          }
        }

        // Wait before next poll
        await Future.delayed(interval);
      } catch (e) {
        if (kDebugMode) {
          print('Polling error: $e');
        }
        // Continue polling despite errors
      }
    }

    return {
      'success': false,
      'status': 'timeout',
      'error': 'Payment verification timeout',
    };
  }

  /// Validate webhook signature (client-side validation for testing)
  static bool validateWebhookSignature(
    String payload,
    String signature,
    String secret,
  ) {
    final expectedSignature = crypto.Hmac(
      crypto.sha256,
      utf8.encode(secret),
    ).convert(utf8.encode(payload)).toString();

    return signature == expectedSignature;
  }

  /// Get user's transaction history
  Future<List<Map<String, dynamic>>> getTransactionHistory({
    String collection = 'mtn_transactions',
    int limit = 50,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final querySnapshot = await _firestore
          .collection(collection)
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
          'createdAt': doc.data()['createdAt']?.toDate()?.toIso8601String(),
          'creditedAt': doc.data()['creditedAt']?.toDate()?.toIso8601String(),
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching transaction history: $e');
      }
      return [];
    }
  }

  /// Retry failed payment
  Future<Map<String, dynamic>> retryPayment(
    String transactionId, {
    String collection = 'mtn_transactions',
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get transaction details
      final doc = await _firestore
          .collection(collection)
          .doc(transactionId)
          .get();

      if (!doc.exists) {
        throw Exception('Transaction not found');
      }

      final transactionData = doc.data()!;
      if (transactionData['userId'] != user.uid) {
        throw Exception('Unauthorized access to transaction');
      }

      if (transactionData['status'] != 'failed') {
        throw Exception('Only failed transactions can be retried');
      }

      // Check retry limits (max 3 retries per transaction)
      final retryCount = transactionData['retryCount'] ?? 0;
      if (retryCount >= 3) {
        throw Exception('Maximum retry attempts exceeded');
      }

      // Update retry count
      final docRef = _firestore.collection(collection).doc(transactionId);
      await docRef.update({
        'retryCount': retryCount + 1,
        'lastRetryAt': FieldValue.serverTimestamp(),
      });

      // For MTN payments, retry functionality removed - Flutterwave integration no longer available
      if (collection == 'mtn_transactions') {
        return {
          'success': false,
          'error':
              'Retry functionality not available - Flutterwave integration removed',
        };
      }

      return {'success': false, 'error': 'Unsupported payment type for retry'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Cancel pending payment
  Future<Map<String, dynamic>> cancelPayment(
    String transactionId, {
    String collection = 'mtn_transactions',
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final docRef = _firestore.collection(collection).doc(transactionId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw Exception('Transaction not found');
      }

      final transactionData = doc.data()!;
      if (transactionData['userId'] != user.uid) {
        throw Exception('Unauthorized access to transaction');
      }

      if (transactionData['status'] != 'pending') {
        throw Exception('Only pending transactions can be cancelled');
      }

      // Update status to cancelled
      await docRef.update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'user',
      });

      return {'success': true, 'message': 'Payment cancelled successfully'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get payment statistics for user
  Future<Map<String, dynamic>> getPaymentStatistics() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'totalTransactions': 0,
          'successfulTransactions': 0,
          'failedTransactions': 0,
          'totalAmount': 0.0,
          'totalAkofa': 0.0,
        };
      }

      final transactions = await getTransactionHistory();

      int totalTransactions = transactions.length;
      int successfulTransactions = 0;
      int failedTransactions = 0;
      double totalAmount = 0.0;
      double totalAkofa = 0.0;

      for (final tx in transactions) {
        if (tx['status'] == 'credited') {
          successfulTransactions++;
        } else if (tx['status'] == 'failed') {
          failedTransactions++;
        }

        totalAmount += (tx['amount'] as num?)?.toDouble() ?? 0.0;
        totalAkofa += (tx['akofaAmount'] as num?)?.toDouble() ?? 0.0;
      }

      return {
        'totalTransactions': totalTransactions,
        'successfulTransactions': successfulTransactions,
        'failedTransactions': failedTransactions,
        'successRate': totalTransactions > 0
            ? (successfulTransactions / totalTransactions) * 100
            : 0.0,
        'totalAmount': totalAmount,
        'totalAkofa': totalAkofa,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching payment statistics: $e');
      }
      return {'error': e.toString()};
    }
  }
}
