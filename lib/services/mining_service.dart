import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

class MiningService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  double _minedTokens = 0.0;
  Timer? _miningTimer;
  final double miningRatePerHour = 0.25; // AKOFA/hour
  final StreamController<double> _tokenStreamController =
      StreamController<double>.broadcast();

  /// Set initial mined tokens (for session restoration)
  void setInitialMinedTokens(double tokens) {
    _minedTokens = tokens;
    _tokenStreamController.add(_minedTokens);
  }

  Stream<double> get minedTokenStream => _tokenStreamController.stream;

  /// Fetch the user's Stellar wallet address from Firestore
  Future<String?> getUserWalletAddress() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final walletDoc = await _firestore
        .collection('secure_wallets')
        .doc(user.uid)
        .get();

    if (!walletDoc.exists) return null;
    return walletDoc.data()?['publicKey'];
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
        .collection('users') // ✅ lowercase best practice
        .doc(user.uid)
        .collection('active_mining_sessions')
        .add({
          'sessionStart': Timestamp.now(),
          'sessionEnd': Timestamp.fromDate(sessionEnd),
          'miningRate': miningRatePerHour,
          'completed': false,
          'payoutStatus': 'pending', // new field to track payout
          'txHash': null,
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

        // ✅ Log the Stellar transaction result
        await sessionRef.update({
          'payoutStatus': result['success'] ? 'success' : 'failed',
          'txHash': result['txHash'],
          'txMessage': result['message'],
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

  /// Send mined tokens to user's Stellar wallet
  Future<Map<String, dynamic>> _sendTokens(double amount) async {
    try {
      final userPublicKey = await getUserWalletAddress();
      if (userPublicKey == null) {
        print("❌ User wallet not found.");
        return {
          'success': false,
          'txHash': null,
          'message': 'User wallet not found',
        };
      }

      // ⚠️ Temporarily keep this here for testing (will move to Cloud Function)
      const distributorSecret =
          "SCB3ICTKZ3FQX6R6JRBV2427JVPGN7IELDUWQOKDFGT5BGKQKWBURPIR";
      const issuerPublicKey =
          "GAXGCEV2XGCUORUWQ4B2NTRVLKUVDCOQT2EL5C3GY3X72LFR2G3QKSKW";

      final sdk = StellarSDK.TESTNET;
      final distributorKeyPair = KeyPair.fromSecretSeed(distributorSecret);
      final distributorAccount = await sdk.accounts.account(
        distributorKeyPair.accountId,
      );

      final akofaAsset = AssetTypeCreditAlphaNum12('AKOFA', issuerPublicKey);

      final transaction = TransactionBuilder(distributorAccount)
          .addOperation(
            PaymentOperationBuilder(
              userPublicKey,
              akofaAsset,
              amount.toStringAsFixed(6),
            ).build(),
          )
          .addMemo(Memo.text('AKOFA Mining Reward'))
          .build();

      transaction.sign(distributorKeyPair, Network.TESTNET);
      final response = await sdk.submitTransaction(transaction);

      if (response.success) {
        print("✅ Sent $amount AKOFA to $userPublicKey");
        return {
          'success': true,
          'txHash': response.hash,
          'message': 'Transaction successful',
        };
      } else {
        print("❌ Transaction failed: ${response.resultXdr}");
        return {
          'success': false,
          'txHash': response.hash,
          'message': 'Transaction failed: ${response.resultXdr}',
        };
      }
    } catch (e) {
      print("❌ Error sending tokens: $e");
      return {'success': false, 'txHash': null, 'message': e.toString()};
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

      // Step 2: Send tokens OUTSIDE transaction (network call can take time)
      if (amountToSend == null) {
        throw Exception('Amount not set after transaction');
      }

      print("💰 Sending ${amountToSend} AKOFA tokens to user wallet...");
      final result = await _sendTokens(amountToSend!);

      // Step 3: Update final status OUTSIDE transaction
      await sessionRef.update({
        'payoutStatus': result['success'] ? 'success' : 'failed',
        'txHash': result['txHash'],
        'txMessage': result['message'],
        'completedAt': Timestamp.now(),
      });

      if (result['success']) {
        print("✅ Successfully claimed ${amountToSend} AKOFA tokens");
      } else {
        print("❌ Failed to send tokens: ${result['message']}");
      }

      return result;
    } catch (e) {
      print("❌ Error claiming specific unpaid session: $e");
      
      // Mark as failed if we got past the transaction
      try {
        await sessionRef.update({
          'payoutStatus': 'failed',
          'txMessage': e.toString(),
          'completedAt': Timestamp.now(),
        });
      } catch (updateError) {
        print("❌ Error updating failed status: $updateError");
      }

      return {'success': false, 'message': e.toString()};
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
        };
      }).toList();
    } catch (e) {
      print("❌ Error fetching unpaid mining sessions: $e");
      return [];
    }
  }

  /// Dispose mining stream and timer
  void dispose() {
    _miningTimer?.cancel();
    _tokenStreamController.close();
  }
}
