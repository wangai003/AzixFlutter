import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'polygon_wallet_service.dart';

/// Polygon Mining Service - Replaces Stellar Mining Service
/// Handles AKOFA token mining rewards on Polygon network
class PolygonMiningService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  double _minedTokens = 0.0;
  Timer? _miningTimer;
  final double miningRatePerHour = 1.5; // AKOFA/hour
  final StreamController<double> _tokenStreamController =
      StreamController<double>.broadcast();

  /// AKOFA Token Contract Address on Polygon (Update this with your actual deployed contract)
  /// This should be an ERC-20 token contract on Polygon network
  static const String akofaTokenContractAddress = '0xf1266ACCf0f757c61e4DFDD9EBBcaC05D2Ee375F'; // TODO: Update with actual AKOFA contract address
  
  /// Mining distributor wallet credentials (stored securely - should move to Cloud Functions in production)
  /// This wallet holds AKOFA tokens and distributes mining rewards
  static const String distributorPrivateKey = 'af611eb882635606bdad6e91a011e2658d01378a56654d5b554f9f7cb170a863'; // TODO: Move to secure Cloud Functions

  /// Set initial mined tokens (for session restoration)
  void setInitialMinedTokens(double tokens) {
    _minedTokens = tokens;
    _tokenStreamController.add(_minedTokens);
  }

  Stream<double> get minedTokenStream => _tokenStreamController.stream;

  /// Fetch the user's Polygon wallet address from Firestore
  Future<String?> getUserWalletAddress() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      // First check polygon_wallets collection
      final polygonWalletDoc = await _firestore
          .collection('polygon_wallets')
          .doc(user.uid)
          .get();

      if (polygonWalletDoc.exists) {
        final data = polygonWalletDoc.data() ?? {};
        final address = data['address'] as String?;
        final previousAddress = data['previousAddress'] as String?;
        final addressCorrected = data['addressCorrected'] == true;

        if (address != null && address.isNotEmpty) {
          // Always prefer the current stored (should already be the derived/authoritative address)
          print('🏷️ [MINING] Using Polygon wallet address from polygon_wallets: $address');
          if (previousAddress != null && previousAddress.isNotEmpty) {
            print('ℹ️ [MINING] Previous wallet address (migrated): $previousAddress');
          }
          if (!addressCorrected && previousAddress != null && previousAddress.isNotEmpty) {
            print('⚠️ [MINING] Warning: wallet was not flagged as corrected, but has previousAddress set.');
          }
          return address;
        }
      }

      // Fallback to users collection
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      return userDoc.data()?['polygonAddress'];
    } catch (e) {
      print('❌ Error fetching Polygon wallet address: $e');
      return null;
    }
  }

  /// Start the mining process
  void startMining() {
    const updateInterval = Duration(seconds: 1);
    _miningTimer?.cancel();

    _miningTimer = Timer.periodic(updateInterval, (timer) {
      _minedTokens += (miningRatePerHour / 3600);
      _tokenStreamController.add(_minedTokens);
    });
  }

  /// Stop the mining process
  void stopMining() {
    _miningTimer?.cancel();
    _miningTimer = null;
  }

  /// Save a new mining session to Firestore
  Future<DocumentReference> saveMiningSession() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final sessionEnd = DateTime.now().add(const Duration(hours: 24));

    return await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('active_mining_sessions')
        .add({
          'sessionStart': Timestamp.now(),
          'sessionEnd': Timestamp.fromDate(sessionEnd),
          'miningRate': miningRatePerHour,
          'completed': false,
          'payoutStatus': 'pending',
          'txHash': null,
          'blockchain': 'polygon', // Identify as Polygon transaction
          'network': PolygonWalletService.getNetworkInfo()['networkName'],
          'chainId': PolygonWalletService.getNetworkInfo()['chainId'],
        });
  }

  /// Delete all active mining sessions
  Future<void> deleteMiningSession() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final sessions = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('active_mining_sessions')
        .get();

    for (var doc in sessions.docs) {
      await doc.reference.delete();
    }
  }

  /// Complete the mining session safely
  Future<void> completeMiningSession(String sessionId, double amount) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final sessionRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('active_mining_sessions')
        .doc(sessionId);

    bool shouldSendTokens = false;

    try {
      await _firestore.runTransaction((transaction) async {
        final sessionDoc = await transaction.get(sessionRef);
        if (!sessionDoc.exists) return;

        final data = sessionDoc.data()!;
        final completed = data['completed'] ?? false;

        if (!completed) {
          transaction.update(sessionRef, {
            'completed': true,
            'payoutStatus': 'processing',
            'completedAt': Timestamp.now(),
          });
          shouldSendTokens = true;
        }
      });

      // ✅ Send tokens only AFTER transaction is safely committed
      if (shouldSendTokens) {
        final result = await _sendTokens(amount);

        // ✅ Log the Polygon transaction result
        await sessionRef.update({
          'payoutStatus': result['success'] ? 'success' : 'failed',
          'txHash': result['txHash'],
          'txMessage': result['message'],
          'blockchain': 'polygon',
        });
      }
    } catch (e) {
      print("❌ Error completing mining session: $e");
      await sessionRef.update({
        'payoutStatus': 'failed',
        'txMessage': e.toString(),
      });
    }
  }

  /// Send mined tokens to user's Polygon wallet
  Future<Map<String, dynamic>> _sendTokens(double amount) async {
    try {
      final userPublicKey = await getUserWalletAddress();
      if (userPublicKey == null) {
        print("❌ User Polygon wallet not found.");
        return {
          'success': false,
          'txHash': null,
          'message': 'User Polygon wallet not found. Please set up your Polygon wallet first.',
        };
      }

      print("✅ User has Polygon wallet: ${userPublicKey.substring(0, 10)}...");
      print("💰 Sending $amount AKOFA tokens via Polygon network...");

      // Call the ERC-20 token transfer method
      final result = await PolygonWalletService.sendERC20Token(
        tokenContractAddress: akofaTokenContractAddress,
        toAddress: userPublicKey,
        amount: amount,
        distributorPrivateKey: distributorPrivateKey,
      );

      if (result['success']) {
        print("✅ Sent $amount AKOFA to $userPublicKey on Polygon");
        return {
          'success': true,
          'txHash': result['txHash'],
          'message': 'Transaction successful',
        };
      } else {
        final errorMessage = result['message'] ?? 'Unknown error occurred';
        print("❌ Transaction failed: $errorMessage");
        return {
          'success': false,
          'txHash': result['txHash'],
          'message': errorMessage,
        };
      }
    } catch (e, stackTrace) {
      print("❌ Error sending tokens: $e");
      print("❌ Stack trace: $stackTrace");
      
      String errorMessage = e.toString();
      
      // Check for common error patterns
      if (errorMessage.contains('network') ||
          errorMessage.contains('connection')) {
        errorMessage = 'Network error occurred. Please check your internet connection and try again.';
      } else if (errorMessage.contains('insufficient funds') ||
                 errorMessage.contains('INSUFFICIENT_BALANCE')) {
        errorMessage = 'Insufficient balance in distributor account. Please contact support.';
      }
      
      return {
        'success': false,
        'txHash': null,
        'message': errorMessage,
      };
    }
  }

  /// Handle expired mining sessions on app reopen
  Future<void> handleExpiredSessions() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final expiredSessions = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('active_mining_sessions')
          .where('sessionEnd', isLessThanOrEqualTo: Timestamp.now())
          .where('completed', isEqualTo: false)
          .get();

      for (var doc in expiredSessions.docs) {
        final sessionData = doc.data();
        final sessionStart = (sessionData['sessionStart'] as Timestamp)
            .toDate();
        final sessionEnd = (sessionData['sessionEnd'] as Timestamp).toDate();

        // Calculate mined tokens based on full session duration (24 hours)
        final fullSessionDuration = sessionEnd.difference(sessionStart);
        final minedTokens =
            fullSessionDuration.inSeconds * (miningRatePerHour / 3600);

        // Mark as completed but unpaid (since app was closed)
        await doc.reference.update({
          'completed': true,
          'payoutStatus': 'expired_unpaid',
          'completedAt': Timestamp.now(),
          'minedTokens': minedTokens,
          'blockchain': 'polygon',
        });

        print(
          '✅ Marked expired session ${doc.id} as completed with $minedTokens AKOFA (unpaid)',
        );
      }
    } catch (e) {
      print("❌ Error handling expired sessions: $e");
    }
  }

  /// Claim unpaid mining sessions by sending tokens and marking as paid with transaction safety
  Future<void> claimUnpaidMiningSessions() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final unpaidSessions = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('active_mining_sessions')
          .where('payoutStatus', isEqualTo: 'expired_unpaid')
          .get();

      for (var doc in unpaidSessions.docs) {
        await _claimSessionWithTransaction(doc.reference, doc.data());
      }
    } catch (e) {
      print("❌ Error claiming unpaid mining sessions: $e");
    }
  }

  /// Helper method to claim a session with transaction safety
  Future<void> _claimSessionWithTransaction(
    DocumentReference sessionRef,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final sessionDoc = await transaction.get(sessionRef);
        if (!sessionDoc.exists) return;

        final currentData = sessionDoc.data() as Map<String, dynamic>;
        final payoutStatus = currentData['payoutStatus'];

        // Prevent claiming if already paid or processing
        if (payoutStatus == 'success' ||
            payoutStatus == 'failed' ||
            payoutStatus == 'processing') {
          return; // Skip this session
        }

        // Only process if still expired_unpaid
        if (payoutStatus != 'expired_unpaid') {
          return; // Skip this session
        }

        final amount = currentData['minedTokens'] as double?;
        if (amount == null) return; // Skip if no mined tokens

        // Mark as processing
        transaction.update(sessionRef, {
          'payoutStatus': 'processing',
          'claimedAt': Timestamp.now(),
        });

        // Send tokens outside transaction
        final result = await _sendTokens(amount);

        // Update final status
        transaction.update(sessionRef, {
          'payoutStatus': result['success'] ? 'success' : 'failed',
          'txHash': result['txHash'],
          'txMessage': result['message'],
          'blockchain': 'polygon',
        });
      });
    } catch (e) {
      print("❌ Error in transaction for session ${sessionRef.id}: $e");
      // Update status to failed if transaction fails
      await sessionRef.update({
        'payoutStatus': 'failed',
        'txMessage': e.toString(),
      });
    }
  }

  /// Claim a specific unpaid mining session with transaction safety
  Future<Map<String, dynamic>> claimSpecificUnpaidSession(
    String sessionId,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'User not logged in'};
    }

    final sessionRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('active_mining_sessions')
        .doc(sessionId);

    double? amountToSend;

    try {
      // Step 1: Use transaction to validate and mark as processing (atomic)
      try {
      await _firestore.runTransaction((transaction) async {
        final sessionDoc = await transaction.get(sessionRef);
        if (!sessionDoc.exists) {
          throw Exception('Session not found');
        }

        final data = sessionDoc.data() as Map<String, dynamic>;
        final payoutStatus = data['payoutStatus'];

        // Prevent claiming if already paid or processing
        if (payoutStatus == 'success' ||
            payoutStatus == 'failed' ||
            payoutStatus == 'processing') {
          throw Exception('Session already claimed or processing');
        }

        // Only allow claiming if status is 'expired_unpaid'
        if (payoutStatus != 'expired_unpaid') {
          throw Exception('Session is not eligible for claiming');
        }

        final amount = data['minedTokens'] as double?;
        if (amount == null || amount <= 0) {
          throw Exception('Invalid mined tokens amount');
        }

        // Store amount to send outside transaction
        amountToSend = amount;

        // Mark as processing to prevent double claiming (atomic update)
        transaction.update(sessionRef, {
          'payoutStatus': 'processing',
          'claimedAt': Timestamp.now(),
        });
      });
      } catch (transactionError) {
        print("❌ Transaction error: $transactionError");
        // Extract error message from exception
        String errorMessage = transactionError.toString();
        if (transactionError is Exception) {
          errorMessage = transactionError.toString().replaceFirst('Exception: ', '');
        }
        return {
          'success': false,
          'message': errorMessage,
        };
      }

      // Step 2: Send tokens OUTSIDE transaction (network call can take time)
      if (amountToSend == null) {
        return {
          'success': false,
          'message': 'Amount not set after transaction. Please try again.',
        };
      }

      print("💰 Sending ${amountToSend} AKOFA tokens to user wallet...");
      
      Map<String, dynamic> result;
      try {
        result = await _sendTokens(amountToSend!);
      } catch (sendError) {
        print("❌ Error in _sendTokens: $sendError");
        String errorMessage = sendError.toString();
        
        // Check for common errors
        if (errorMessage.toLowerCase().contains('insufficient')) {
          errorMessage = 'Insufficient funds in distributor wallet. Please contact support.';
        } else if (errorMessage.toLowerCase().contains('network')) {
          errorMessage = 'Network error. Please check your connection and try again.';
        }
        
        // Update status to failed
        try {
          await sessionRef.update({
            'payoutStatus': 'failed',
            'txMessage': errorMessage,
            'completedAt': Timestamp.now(),
          });
        } catch (updateError) {
          print("❌ Error updating failed status: $updateError");
        }
        
        return {
          'success': false,
          'message': errorMessage,
        };
      }

      // Step 3: Update final status OUTSIDE transaction
      try {
      await sessionRef.update({
        'payoutStatus': result['success'] ? 'success' : 'failed',
        'txHash': result['txHash'],
        'txMessage': result['message'],
        'completedAt': Timestamp.now(),
        'blockchain': 'polygon',
      });
      } catch (updateError) {
        print("❌ Error updating final status: $updateError");
        // Don't fail the whole operation if update fails, but log it
      }

      if (result['success']) {
        print("✅ Successfully claimed ${amountToSend} AKOFA tokens");
      } else {
        print("❌ Failed to send tokens: ${result['message']}");
      }

      return result;
    } catch (e, stackTrace) {
      print("❌ Error claiming specific unpaid session: $e");
      print("❌ Stack trace: $stackTrace");
      
      // Extract meaningful error message
      String errorMessage = e.toString();
      if (e is Exception) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
      
      // Check for common error patterns
      if (errorMessage.contains('network') ||
          errorMessage.contains('connection')) {
        errorMessage = 'Network error. Please check your connection and try again.';
      }
      
      // Mark as failed if we got past the transaction
      try {
        await sessionRef.update({
          'payoutStatus': 'failed',
          'txMessage': errorMessage,
          'completedAt': Timestamp.now(),
        });
      } catch (updateError) {
        print("❌ Error updating failed status: $updateError");
      }

      return {'success': false, 'message': errorMessage};
    }
  }

  /// Get list of unpaid mining sessions
  Future<List<Map<String, dynamic>>> getUnpaidMiningSessions() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final unpaidSessions = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('active_mining_sessions')
          .where('payoutStatus', isEqualTo: 'expired_unpaid')
          .get();

      return unpaidSessions.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'sessionStart': data['sessionStart'],
          'sessionEnd': data['sessionEnd'],
          'minedTokens': data['minedTokens'] ?? 0.0,
          'completedAt': data['completedAt'],
          'blockchain': data['blockchain'] ?? 'polygon', // Support old sessions
        };
      }).toList();
    } catch (e) {
      print("❌ Error fetching unpaid mining sessions: $e");
      return [];
    }
  }

  /// Stream of unpaid mining sessions (real-time updates)
  Stream<List<Map<String, dynamic>>> streamUnpaidMiningSessions() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('active_mining_sessions')
        .where('payoutStatus', isEqualTo: 'expired_unpaid')
        .snapshots()
        .map((snapshot) {
      print('📊 [STREAM] Unpaid sessions count: ${snapshot.docs.length}');
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'sessionStart': data['sessionStart'],
          'sessionEnd': data['sessionEnd'],
          'minedTokens': data['minedTokens'] ?? 0.0,
          'completedAt': data['completedAt'],
          'blockchain': data['blockchain'] ?? 'polygon', // Support old Stellar sessions
          'payoutStatus': data['payoutStatus'],
        };
      }).toList();
    });
  }

  /// Dispose mining stream and timer
  void dispose() {
    _miningTimer?.cancel();
    _tokenStreamController.close();
  }
}

