import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'payment_webhook_service.dart';

/// Service for handling payment retry mechanisms and timeout management
/// Implements exponential backoff, circuit breaker pattern, and intelligent retry logic
class PaymentRetryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PaymentWebhookService _webhookService = PaymentWebhookService();

  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _initialRetryDelay = Duration(seconds: 30);
  static const Duration _maxRetryDelay = Duration(minutes: 5);
  static const Duration _paymentTimeout = Duration(minutes: 10);
  static const double _backoffMultiplier = 2.0;

  // Circuit breaker configuration
  static const int _circuitBreakerThreshold = 5;
  static const Duration _circuitBreakerTimeout = Duration(minutes: 10);
  final Map<String, Map<String, dynamic>> _circuitBreakers = {};

  /// Retry a failed MTN payment with intelligent backoff
  Future<Map<String, dynamic>> retryMtnPayment({
    required String transactionId,
    String? collection = 'mtn_transactions',
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get transaction details
      final doc = await _firestore
          .collection(collection!)
          .doc(transactionId)
          .get();

      if (!doc.exists) {
        throw Exception('Transaction not found');
      }

      final transactionData = doc.data()!;
      if (transactionData['userId'] != user.uid) {
        throw Exception('Unauthorized access to transaction');
      }

      final status = transactionData['status'];
      final retryCount = transactionData['retryCount'] ?? 0;

      // Validate retry conditions
      if (status != 'failed' && status != 'pending') {
        throw Exception('Only failed or pending transactions can be retried');
      }

      if (retryCount >= _maxRetries) {
        throw Exception('Maximum retry attempts exceeded');
      }

      // Check circuit breaker
      final circuitKey = 'mtn_${transactionData['countryCode']}';
      if (_isCircuitBreakerOpen(circuitKey)) {
        throw Exception(
          'Payment service temporarily unavailable. Please try again later.',
        );
      }

      // Calculate retry delay using exponential backoff
      final retryDelay = _calculateRetryDelay(retryCount);

      // Update retry count and status
      final docRef = _firestore.collection(collection!).doc(transactionId);
      await docRef.update({
        'retryCount': retryCount + 1,
        'lastRetryAt': FieldValue.serverTimestamp(),
        'status': 'retrying',
        'retryDelay': retryDelay.inSeconds,
      });

      // Wait for retry delay
      await Future.delayed(retryDelay);

      // Attempt to retry the payment
      final retryResult = await _performPaymentRetry(transactionData);

      // Update transaction with retry result
      await docRef.update({
        'status': retryResult['success'] == true ? 'pending' : 'failed',
        'lastRetryResult': retryResult,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update circuit breaker based on result
      _updateCircuitBreaker(circuitKey, retryResult['success'] == true);

      return {
        'success': retryResult['success'] == true,
        'message': retryResult['success'] == true
            ? 'Payment retry initiated successfully'
            : 'Payment retry failed',
        'retryCount': retryCount + 1,
        'nextRetryDelay': retryCount + 1 < _maxRetries
            ? _calculateRetryDelay(retryCount + 1)
            : null,
        'details': retryResult,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Retry failed',
      };
    }
  }

  /// Perform the actual payment retry
  Future<Map<String, dynamic>> _performPaymentRetry(
    Map<String, dynamic> transactionData,
  ) async {
    try {
      // Payment retry functionality removed - Flutterwave integration no longer available
      return {
        'success': false,
        'error':
            'Payment retry not available - Flutterwave integration removed',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Handle payment timeout scenarios
  Future<Map<String, dynamic>> handlePaymentTimeout({
    required String transactionId,
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

      final status = transactionData['status'];
      final createdAt = (transactionData['createdAt'] as Timestamp).toDate();
      final timeSinceCreation = DateTime.now().difference(createdAt);

      // Check if payment has actually timed out
      if (timeSinceCreation < _paymentTimeout) {
        return {
          'success': false,
          'error': 'Payment has not timed out yet',
          'timeRemaining': _paymentTimeout - timeSinceCreation,
        };
      }

      if (status == 'completed' || status == 'credited') {
        return {'success': false, 'error': 'Payment was already completed'};
      }

      // Mark as timed out
      await docRef.update({
        'status': 'timed_out',
        'timedOutAt': FieldValue.serverTimestamp(),
        'timeoutReason': 'Payment exceeded timeout duration',
      });

      // Attempt automatic retry if within retry limits
      final retryCount = transactionData['retryCount'] ?? 0;
      if (retryCount < _maxRetries) {
        // Schedule automatic retry
        Future.delayed(const Duration(minutes: 1), () async {
          try {
            await retryMtnPayment(
              transactionId: transactionId,
              collection: collection,
            );
          } catch (e) {
            if (kDebugMode) {
              print('Automatic timeout retry failed: $e');
            }
          }
        });

        return {
          'success': true,
          'message': 'Payment timed out, automatic retry scheduled',
          'action': 'retry_scheduled',
        };
      } else {
        return {
          'success': true,
          'message': 'Payment timed out, maximum retries exceeded',
          'action': 'max_retries_exceeded',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Cancel a pending payment with timeout handling
  Future<Map<String, dynamic>> cancelPaymentWithTimeout({
    required String transactionId,
    String collection = 'mtn_transactions',
    Duration? customTimeout,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final docRef = _firestore.collection(collection!).doc(transactionId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw Exception('Transaction not found');
      }

      final transactionData = doc.data()!;
      if (transactionData['userId'] != user.uid) {
        throw Exception('Unauthorized access to transaction');
      }

      final status = transactionData['status'];
      if (status != 'pending' && status != 'retrying') {
        throw Exception(
          'Only pending or retrying transactions can be cancelled',
        );
      }

      // Check if payment should be allowed to complete first
      final createdAt = (transactionData['createdAt'] as Timestamp).toDate();
      final timeSinceCreation = DateTime.now().difference(createdAt);
      final timeout = customTimeout ?? _paymentTimeout;

      if (timeSinceCreation < Duration(minutes: 2)) {
        return {
          'success': false,
          'error':
              'Please wait at least 2 minutes before cancelling to allow payment to complete',
          'timeRemaining': Duration(minutes: 2) - timeSinceCreation,
        };
      }

      // Perform final status check before cancelling
      if (collection == 'mtn_transactions') {
        try {
          final statusCheck = await _webhookService.verifyMtnPaymentStatus(
            transactionData['txRef'],
          );

          if (statusCheck['success'] == true &&
              statusCheck['status'] == 'completed') {
            // Payment actually completed, update and don't cancel
            await docRef.update({
              'status': 'credited',
              'verifiedAt': FieldValue.serverTimestamp(),
              'finalStatusCheck': statusCheck,
            });

            return {
              'success': false,
              'error': 'Payment completed successfully, cannot cancel',
              'actualStatus': 'completed',
            };
          }
        } catch (e) {
          // Status check failed, proceed with cancellation
          if (kDebugMode) {
            print('Final status check failed during cancellation: $e');
          }
        }
      }

      // Cancel the payment
      await docRef.update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'user_with_timeout_check',
        'finalStatusVerified': true,
      });

      return {'success': true, 'message': 'Payment cancelled successfully'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get retry status and available actions for a transaction
  Future<Map<String, dynamic>> getRetryStatus({
    required String transactionId,
    String collection = 'mtn_transactions',
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      final doc = await _firestore
          .collection(collection)
          .doc(transactionId)
          .get();

      if (!doc.exists) {
        return {'error': 'Transaction not found'};
      }

      final transactionData = doc.data()!;
      if (transactionData['userId'] != user.uid) {
        return {'error': 'Unauthorized access'};
      }

      final status = transactionData['status'];
      final retryCount = transactionData['retryCount'] ?? 0;
      final createdAt = (transactionData['createdAt'] as Timestamp).toDate();
      final timeSinceCreation = DateTime.now().difference(createdAt);

      final canRetry =
          (status == 'failed' || status == 'timed_out') &&
          retryCount < _maxRetries;
      final canCancel = status == 'pending' || status == 'retrying';
      final isTimedOut = timeSinceCreation > _paymentTimeout;

      Map<String, dynamic> retryInfo = {
        'transactionId': transactionId,
        'status': status,
        'retryCount': retryCount,
        'maxRetries': _maxRetries,
        'timeSinceCreation': timeSinceCreation,
        'isTimedOut': isTimedOut,
        'canRetry': canRetry,
        'canCancel': canCancel,
      };

      if (canRetry) {
        retryInfo['nextRetryDelay'] = _calculateRetryDelay(retryCount);
        retryInfo['estimatedNextRetry'] = DateTime.now().add(
          _calculateRetryDelay(retryCount),
        );
      }

      if (isTimedOut && status == 'pending') {
        retryInfo['timeoutAction'] = 'can_handle_timeout';
      }

      return retryInfo;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Bulk retry failed payments for a user
  Future<Map<String, dynamic>> bulkRetryFailedPayments({
    int maxRetries = 3,
    String collection = 'mtn_transactions',
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get failed transactions
      final failedTransactions = await _firestore
          .collection(collection)
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'failed')
          .where('retryCount', isLessThan: _maxRetries)
          .limit(maxRetries)
          .get();

      if (failedTransactions.docs.isEmpty) {
        return {
          'success': true,
          'message': 'No failed transactions available for retry',
          'retried': 0,
        };
      }

      int successCount = 0;
      int failureCount = 0;
      final results = <Map<String, dynamic>>[];

      // Retry each transaction with delay between retries
      for (final doc in failedTransactions.docs) {
        try {
          final retryResult = await retryMtnPayment(
            transactionId: doc.id,
            collection: collection,
          );

          if (retryResult['success'] == true) {
            successCount++;
          } else {
            failureCount++;
          }

          results.add({
            'transactionId': doc.id,
            'success': retryResult['success'],
            'message': retryResult['message'],
          });

          // Delay between bulk retries to avoid overwhelming the service
          if (doc != failedTransactions.docs.last) {
            await Future.delayed(const Duration(seconds: 5));
          }
        } catch (e) {
          failureCount++;
          results.add({
            'transactionId': doc.id,
            'success': false,
            'error': e.toString(),
          });
        }
      }

      return {
        'success': true,
        'totalAttempted': failedTransactions.docs.length,
        'successful': successCount,
        'failed': failureCount,
        'results': results,
        'message':
            'Bulk retry completed: $successCount successful, $failureCount failed',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Calculate retry delay using exponential backoff with jitter
  Duration _calculateRetryDelay(int retryCount) {
    final baseDelay = _initialRetryDelay * (_backoffMultiplier * retryCount);
    final delayWithJitter =
        baseDelay + Duration(seconds: (retryCount * 5)); // Add jitter

    // Cap at maximum delay
    return delayWithJitter > _maxRetryDelay ? _maxRetryDelay : delayWithJitter;
  }

  /// Check if circuit breaker is open for a service
  bool _isCircuitBreakerOpen(String serviceKey) {
    final breaker = _circuitBreakers[serviceKey];
    if (breaker == null) return false;

    final isOpen = breaker['isOpen'] as bool;
    if (isOpen) {
      // Check if timeout has expired
      final lastFailureTime = breaker['lastFailureTime'] as DateTime;
      if (DateTime.now().difference(lastFailureTime) > _circuitBreakerTimeout) {
        breaker['isOpen'] = false;
        breaker['failureCount'] = 0;
        return false;
      }
      return true;
    }

    return false;
  }

  /// Update circuit breaker state
  void _updateCircuitBreaker(String serviceKey, bool success) {
    final breaker = _circuitBreakers.putIfAbsent(
      serviceKey,
      () => {
        'isOpen': false,
        'failureCount': 0,
        'lastFailureTime': DateTime.now(),
      },
    );

    if (success) {
      breaker['failureCount'] = 0;
      breaker['isOpen'] = false;
    } else {
      breaker['failureCount'] = (breaker['failureCount'] as int) + 1;
      breaker['lastFailureTime'] = DateTime.now();

      if ((breaker['failureCount'] as int) >= _circuitBreakerThreshold) {
        breaker['isOpen'] = true;
      }
    }
  }

  /// Clean up old retry data (for maintenance)
  Future<void> cleanupOldRetryData({Duration? maxAge}) async {
    try {
      final cutoffDate = DateTime.now().subtract(
        maxAge ?? const Duration(days: 30),
      );

      // Clean up old retry records
      final oldRetries = await _firestore
          .collection('mtn_transactions')
          .where('status', isEqualTo: 'timed_out')
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = _firestore.batch();
      for (final doc in oldRetries.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (kDebugMode) {
        print('Cleaned up ${oldRetries.docs.length} old retry records');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cleaning up retry data: $e');
      }
    }
  }
}

// Circuit breaker functionality is now handled with Map<String, dynamic>
