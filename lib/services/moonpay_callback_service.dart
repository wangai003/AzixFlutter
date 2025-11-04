import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'enhanced_stellar_service.dart';
import '../models/transaction.dart' as app_transaction;

/// Service for handling MoonPay webhook callbacks and transaction monitoring
class MoonPayCallbackService {
  static const String _baseUrl = 'https://api.moonpay.com';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final EnhancedStellarService _stellarService = EnhancedStellarService();

  // Environment-based API key management
  static String get _apiKey {
    final key = dotenv.env['MOONPAY_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('MOONPAY_API_KEY not found in environment variables');
    }
    return key;
  }

  static String get _secretKey {
    final key = dotenv.env['MOONPAY_SECRET_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('MOONPAY_SECRET_KEY not found in environment variables');
    }
    return key;
  }

  /// Verify MoonPay webhook signature
  static bool verifyWebhookSignature(
    String payload,
    String signature,
    String secret,
  ) {
    try {
      // MoonPay uses HMAC-SHA256 for webhook signatures
      final key = utf8.encode(secret);
      final bytes = utf8.encode(payload);
      final hmacSha256 = Hmac(sha256, key);
      final digest = hmacSha256.convert(bytes);
      final expectedSignature = 'sha256=${digest.toString()}';

      return signature == expectedSignature;
    } catch (e) {
      debugPrint('Webhook signature verification failed: $e');
      return false;
    }
  }

  /// Process MoonPay webhook payload
  Future<Map<String, dynamic>> processWebhookPayload(
    Map<String, dynamic> payload,
    String signature,
  ) async {
    try {
      // Verify webhook signature
      final payloadString = json.encode(payload);
      if (!verifyWebhookSignature(payloadString, signature, _secretKey)) {
        throw Exception('Invalid webhook signature');
      }

      final eventType = payload['type'];
      final data = payload['data'];

      debugPrint('Processing MoonPay webhook: $eventType');

      switch (eventType) {
        case 'transaction_created':
          return await _handleTransactionCreated(data);
        case 'transaction_updated':
          return await _handleTransactionUpdated(data);
        case 'transaction_failed':
          return await _handleTransactionFailed(data);
        default:
          debugPrint('Unhandled webhook event type: $eventType');
          return {'success': true, 'message': 'Event type not handled'};
      }
    } catch (e) {
      debugPrint('Error processing webhook: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Handle transaction created webhook
  Future<Map<String, dynamic>> _handleTransactionCreated(
    Map<String, dynamic> data,
  ) async {
    try {
      final transactionId = data['id'];
      final externalCustomerId = data['externalCustomerId'];
      final walletAddress = data['walletAddress'];
      final currencyCode = data['currency']['code'];
      final baseCurrencyAmount = data['baseCurrencyAmount'];
      final quoteCurrencyAmount = data['quoteCurrencyAmount'];

      // Store transaction in Firestore
      await _storeMoonPayTransaction(data);

      // Update user transaction status if user is found
      if (externalCustomerId != null) {
        await _updateUserTransactionStatus(
          externalCustomerId,
          transactionId,
          'created',
          data,
        );
      }

      return {
        'success': true,
        'message': 'Transaction created webhook processed',
        'transactionId': transactionId,
      };
    } catch (e) {
      debugPrint('Error handling transaction created: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Handle transaction updated webhook
  Future<Map<String, dynamic>> _handleTransactionUpdated(
    Map<String, dynamic> data,
  ) async {
    try {
      final transactionId = data['id'];
      final status = data['status'];
      final externalCustomerId = data['externalCustomerId'];
      final walletAddress = data['walletAddress'];

      debugPrint('Transaction $transactionId status updated to: $status');

      // Update transaction in Firestore
      await _updateMoonPayTransaction(transactionId, data);

      // Handle status-specific logic
      if (status == 'completed' || status == 'paid') {
        await _handleTransactionCompleted(data);
      } else if (status == 'failed' || status == 'cancelled') {
        await _handleTransactionFailed(data);
      }

      // Update user transaction status
      if (externalCustomerId != null) {
        await _updateUserTransactionStatus(
          externalCustomerId,
          transactionId,
          status,
          data,
        );
      }

      return {
        'success': true,
        'message': 'Transaction updated webhook processed',
        'transactionId': transactionId,
        'status': status,
      };
    } catch (e) {
      debugPrint('Error handling transaction updated: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Handle transaction failed webhook
  Future<Map<String, dynamic>> _handleTransactionFailed(
    Map<String, dynamic> data,
  ) async {
    try {
      final transactionId = data['id'];
      final externalCustomerId = data['externalCustomerId'];
      final failureReason = data['failureReason'];

      debugPrint('Transaction $transactionId failed: $failureReason');

      // Update transaction in Firestore
      await _updateMoonPayTransaction(transactionId, {
        ...data,
        'processedAt': DateTime.now().toIso8601String(),
      });

      // Update user transaction status
      if (externalCustomerId != null) {
        await _updateUserTransactionStatus(
          externalCustomerId,
          transactionId,
          'failed',
          data,
        );
      }

      return {
        'success': true,
        'message': 'Transaction failed webhook processed',
        'transactionId': transactionId,
      };
    } catch (e) {
      debugPrint('Error handling transaction failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Handle transaction completion
  Future<void> _handleTransactionCompleted(Map<String, dynamic> data) async {
    try {
      final transactionId = data['id'];
      final walletAddress = data['walletAddress'];
      final currencyCode = data['currency']['code'];
      final quoteCurrencyAmount = data['quoteCurrencyAmount'];
      final externalCustomerId = data['externalCustomerId'];

      // Record transaction in user's transaction history
      if (externalCustomerId != null) {
        await _recordCompletedTransaction(
          externalCustomerId,
          transactionId,
          data,
        );
      }

      // Trigger balance refresh for the user (this would be handled by the provider)
      // For now, we'll just log it
      debugPrint(
        'MoonPay transaction completed: $transactionId for wallet $walletAddress',
      );
    } catch (e) {
      debugPrint('Error handling transaction completion: $e');
    }
  }

  /// Store MoonPay transaction in Firestore
  Future<void> _storeMoonPayTransaction(Map<String, dynamic> data) async {
    try {
      final transactionId = data['id'];
      final externalCustomerId = data['externalCustomerId'];

      final transactionData = {
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'processed': false,
      };

      // Store in global moonpay_transactions collection
      await _firestore
          .collection('moonpay_transactions')
          .doc(transactionId)
          .set(transactionData);

      // Also store in user's transactions if externalCustomerId exists
      if (externalCustomerId != null) {
        await _firestore
            .collection('users')
            .doc(externalCustomerId)
            .collection('moonpay_transactions')
            .doc(transactionId)
            .set(transactionData);
      }
    } catch (e) {
      debugPrint('Error storing MoonPay transaction: $e');
      rethrow;
    }
  }

  /// Update MoonPay transaction in Firestore
  Future<void> _updateMoonPayTransaction(
    String transactionId,
    Map<String, dynamic> data,
  ) async {
    try {
      final updateData = {...data, 'updatedAt': FieldValue.serverTimestamp()};

      // Update in global collection
      await _firestore
          .collection('moonpay_transactions')
          .doc(transactionId)
          .update(updateData);

      // Update in user's collection if externalCustomerId exists
      final externalCustomerId = data['externalCustomerId'];
      if (externalCustomerId != null) {
        await _firestore
            .collection('users')
            .doc(externalCustomerId)
            .collection('moonpay_transactions')
            .doc(transactionId)
            .update(updateData);
      }
    } catch (e) {
      debugPrint('Error updating MoonPay transaction: $e');
      rethrow;
    }
  }

  /// Update user transaction status
  Future<void> _updateUserTransactionStatus(
    String userId,
    String transactionId,
    String status,
    Map<String, dynamic> transactionData,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('moonpay_status')
          .doc(transactionId)
          .set({
            'status': status,
            'transactionId': transactionId,
            'updatedAt': FieldValue.serverTimestamp(),
            'transactionData': transactionData,
          });
    } catch (e) {
      debugPrint('Error updating user transaction status: $e');
    }
  }

  /// Record completed transaction in user's transaction history
  Future<void> _recordCompletedTransaction(
    String userId,
    String transactionId,
    Map<String, dynamic> transactionData,
  ) async {
    try {
      final currencyCode = transactionData['currency']['code'];
      final quoteCurrencyAmount = transactionData['quoteCurrencyAmount'];
      final walletAddress = transactionData['walletAddress'];

      // Create transaction record
      final transaction = app_transaction.Transaction(
        id: 'moonpay_$transactionId',
        userId: userId,
        type: 'receive',
        status: 'completed',
        assetCode: currencyCode.toUpperCase(),
        amount: quoteCurrencyAmount.toDouble(),
        senderAddress: 'MoonPay',
        recipientAddress: walletAddress,
        timestamp: DateTime.now(),
        description: 'MoonPay Purchase',
        memo: 'MoonPay transaction $transactionId',
        transactionHash: transactionId, // MoonPay transaction ID
        metadata: {
          'externalTransactionId': transactionId,
          'provider': 'moonpay',
          'baseCurrencyAmount': transactionData['baseCurrencyAmount'],
          'baseCurrencyCode': transactionData['baseCurrency']['code'],
        },
      );

      // Store in user's transactions
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(transaction.id)
          .set(transaction.toFirestore());
    } catch (e) {
      debugPrint('Error recording completed transaction: $e');
    }
  }

  /// Poll transaction status (fallback for webhook failures)
  Future<Map<String, dynamic>?> pollTransactionStatus(
    String transactionId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/v1/transactions/$transactionId'),
        headers: {'Authorization': 'Bearer $_apiKey'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Process the status update
        await _handleTransactionUpdated(data);

        return data;
      } else {
        debugPrint('Failed to poll transaction status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error polling transaction status: $e');
      return null;
    }
  }

  /// Get user's MoonPay transactions
  Future<List<Map<String, dynamic>>> getUserMoonPayTransactions(
    String userId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('moonpay_transactions')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error getting user MoonPay transactions: $e');
      return [];
    }
  }

  /// Get pending MoonPay transactions for a user
  Future<List<Map<String, dynamic>>> getPendingMoonPayTransactions(
    String userId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('moonpay_transactions')
          .where(
            'status',
            whereIn: ['pending', 'waitingPayment', 'waitingAuthorization'],
          )
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error getting pending MoonPay transactions: $e');
      return [];
    }
  }

  /// Check for stuck transactions and retry processing
  Future<void> checkAndRetryStuckTransactions() async {
    try {
      // Get transactions that are older than 30 minutes and still pending
      final thirtyMinutesAgo = DateTime.now().subtract(
        const Duration(minutes: 30),
      );

      final snapshot = await _firestore
          .collection('moonpay_transactions')
          .where(
            'status',
            whereIn: ['pending', 'waitingPayment', 'waitingAuthorization'],
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(thirtyMinutesAgo))
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final transactionId = data['id'];

        debugPrint('Retrying stuck transaction: $transactionId');

        // Poll the current status
        await pollTransactionStatus(transactionId);
      }
    } catch (e) {
      debugPrint('Error checking stuck transactions: $e');
    }
  }

  /// Clean up old processed transactions (older than 30 days)
  Future<void> cleanupOldTransactions() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      final batch = _firestore.batch();

      // Clean up from global collection
      final globalSnapshot = await _firestore
          .collection('moonpay_transactions')
          .where('status', whereIn: ['completed', 'failed', 'cancelled'])
          .where('createdAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      for (final doc in globalSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Clean up from user collections
      final usersSnapshot = await _firestore.collection('users').get();
      for (final userDoc in usersSnapshot.docs) {
        final userTransactions = await userDoc.reference
            .collection('moonpay_transactions')
            .where('status', whereIn: ['completed', 'failed', 'cancelled'])
            .where('createdAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
            .get();

        for (final doc in userTransactions.docs) {
          batch.delete(doc.reference);
        }
      }

      await batch.commit();
      debugPrint(
        'Cleaned up ${globalSnapshot.docs.length} old MoonPay transactions',
      );
    } catch (e) {
      debugPrint('Error cleaning up old transactions: $e');
    }
  }
}
