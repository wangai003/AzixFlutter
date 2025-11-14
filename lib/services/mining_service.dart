import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as stellar;

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

  /// Check if user has AKOFA trustline
  Future<bool> _hasAkofaTrustline(String publicKey) async {
    try {
      const issuerPublicKey =
          "GAXGCEV2XGCUORUWQ4B2NTRVLKUVDCOQT2EL5C3GY3X72LFR2G3QKSKW";
      final sdk = stellar.StellarSDK.TESTNET;
      
      try {
        final account = await sdk.accounts.account(publicKey);
        
        if (account.balances == null || account.balances!.isEmpty) {
          return false;
        }
        
        for (var balance in account.balances!) {
          if (balance.assetType != 'native' &&
              balance.assetCode == 'AKOFA' &&
              balance.assetIssuer == issuerPublicKey) {
            return true;
          }
        }
        return false;
      } catch (accountError) {
        print("❌ Error fetching account for trustline check: $accountError");
        // If account doesn't exist or network error, assume no trustline
        return false;
      }
    } catch (e) {
      print("❌ Error checking trustline: $e");
      // Return false on any error to be safe - we'll show error message in _sendTokens
      return false;
    }
  }

  /// Decode Stellar transaction error from XDR
  String _decodeTransactionError(String? resultXdr) {
    if (resultXdr == null || resultXdr.isEmpty) {
      return 'Transaction failed with unknown error';
    }

    // Check for common error patterns
    if (resultXdr.contains('op_no_trust') || 
        resultXdr.contains('NO_TRUST') ||
        resultXdr.contains('PAYMENT_NO_TRUST')) {
      return 'Missing AKOFA trustline. Please set up your wallet to receive AKOFA tokens. Go to your wallet screen and ensure the AKOFA trustline is created.';
    } else if (resultXdr.contains('op_underfunded') ||
               resultXdr.contains('UNDERFUNDED') ||
               resultXdr.contains('INSUFFICIENT_BALANCE')) {
      return 'Insufficient balance in distributor account. Please contact support.';
    } else if (resultXdr.contains('op_bad_auth') ||
               resultXdr.contains('BAD_AUTH')) {
      return 'Transaction authentication failed. Please contact support.';
    } else if (resultXdr.contains('op_no_destination') ||
               resultXdr.contains('NO_ACCOUNT')) {
      return 'Recipient account not found. Please ensure your wallet is properly set up.';
    } else if (resultXdr.contains('op_line_full') ||
               resultXdr.contains('LINE_FULL')) {
      return 'Trustline limit reached. Please contact support.';
    } else {
      // Try to provide a more readable error message
      return 'Transaction failed. Error code: ${resultXdr.substring(0, resultXdr.length > 50 ? 50 : resultXdr.length)}...';
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
          'message': 'User wallet not found. Please set up your wallet first.',
        };
      }

      // Check if user has AKOFA trustline before attempting to send
      print("🔍 Checking if user has AKOFA trustline...");
      bool hasTrustline = false;
      try {
        hasTrustline = await _hasAkofaTrustline(userPublicKey);
      } catch (trustlineCheckError) {
        print("❌ Error checking trustline: $trustlineCheckError");
        // Continue anyway - we'll get a better error from the transaction
      }
      
      if (!hasTrustline) {
        print("❌ User does not have AKOFA trustline");
        return {
          'success': false,
          'txHash': null,
          'message': 'Missing AKOFA trustline. Please go to your wallet screen and set up the AKOFA trustline to receive mining rewards. You need to create a trustline for the AKOFA asset before you can receive tokens.',
        };
      }

      print("✅ User has AKOFA trustline, proceeding with payment...");

      // ⚠️ Temporarily keep this here for testing (will move to Cloud Function)
      const distributorSecret =
          "SCB3ICTKZ3FQX6R6JRBV2427JVPGN7IELDUWQOKDFGT5BGKQKWBURPIR";
      const issuerPublicKey =
          "GAXGCEV2XGCUORUWQ4B2NTRVLKUVDCOQT2EL5C3GY3X72LFR2G3QKSKW";

      final sdk = stellar.StellarSDK.TESTNET;
      final distributorKeyPair = stellar.KeyPair.fromSecretSeed(distributorSecret);
      
      stellar.AccountResponse distributorAccount;
      try {
        distributorAccount = await sdk.accounts.account(
          distributorKeyPair.accountId,
        );
      } catch (accountError) {
        print("❌ Error fetching distributor account: $accountError");
        return {
          'success': false,
          'txHash': null,
          'message': 'Network error: Could not connect to Stellar network. Please check your internet connection and try again.',
        };
      }

      final akofaAsset = stellar.AssetTypeCreditAlphaNum12('AKOFA', issuerPublicKey);

      stellar.Transaction transaction;
      try {
        transaction = stellar.TransactionBuilder(distributorAccount)
            .addOperation(
              stellar.PaymentOperationBuilder(
                userPublicKey,
                akofaAsset,
                amount.toStringAsFixed(6),
              ).build(),
            )
            .addMemo(stellar.Memo.text('AKOFA Mining Reward'))
            .build();
      } catch (buildError) {
        print("❌ Error building transaction: $buildError");
        return {
          'success': false,
          'txHash': null,
          'message': 'Error building transaction. Please try again.',
        };
      }

      try {
        transaction.sign(distributorKeyPair, stellar.Network.TESTNET);
      } catch (signError) {
        print("❌ Error signing transaction: $signError");
        return {
          'success': false,
          'txHash': null,
          'message': 'Error signing transaction. Please contact support.',
        };
      }

      stellar.SubmitTransactionResponse response;
      try {
        response = await sdk.submitTransaction(transaction);
      } catch (submitError) {
        print("❌ Error submitting transaction: $submitError");
        String errorMessage = submitError.toString();
        
        // Check for common error patterns
        if (errorMessage.contains('Dart exception thrown from converted Future') ||
            errorMessage.contains('network') ||
            errorMessage.contains('connection')) {
          errorMessage = 'Network error occurred. Please check your internet connection and try again.';
        } else if (errorMessage.contains('trustline') || 
                   errorMessage.contains('NO_TRUST')) {
          errorMessage = 'Missing AKOFA trustline. Please set up your wallet to receive AKOFA tokens.';
        }
        
        return {
          'success': false,
          'txHash': null,
          'message': errorMessage,
        };
      }

      if (response.success) {
        print("✅ Sent $amount AKOFA to $userPublicKey");
        return {
          'success': true,
          'txHash': response.hash,
          'message': 'Transaction successful',
        };
      } else {
        final errorMessage = _decodeTransactionError(response.resultXdr);
        print("❌ Transaction failed: ${response.resultXdr}");
        print("❌ Decoded error: $errorMessage");
        return {
          'success': false,
          'txHash': response.hash,
          'message': errorMessage,
        };
      }
    } catch (e, stackTrace) {
      print("❌ Error sending tokens: $e");
      print("❌ Stack trace: $stackTrace");
      
      String errorMessage = e.toString();
      
      // Check if it's a trustline-related error
      if (errorMessage.contains('trustline') || 
          errorMessage.contains('NO_TRUST') ||
          errorMessage.contains('op_no_trust')) {
        errorMessage = 'Missing AKOFA trustline. Please set up your wallet to receive AKOFA tokens. Go to your wallet screen and ensure the AKOFA trustline is created.';
      } else if (errorMessage.contains('Dart exception thrown from converted Future') ||
                 errorMessage.contains('network') ||
                 errorMessage.contains('connection')) {
        errorMessage = 'Network error occurred. Please check your internet connection and try again.';
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
        
        // Check if it's a trustline error
        if (errorMessage.toLowerCase().contains('trustline') ||
            errorMessage.toLowerCase().contains('no_trust')) {
          errorMessage = 'Missing AKOFA trustline. Please set up your wallet to receive AKOFA tokens. Go to your wallet screen and ensure the AKOFA trustline is created.';
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
      if (errorMessage.contains('Dart exception thrown from converted Future')) {
        errorMessage = 'Network error occurred. Please check your internet connection and try again.';
      } else if (errorMessage.toLowerCase().contains('trustline')) {
        errorMessage = 'Missing AKOFA trustline. Please set up your wallet to receive AKOFA tokens.';
      } else if (errorMessage.toLowerCase().contains('network') ||
                 errorMessage.toLowerCase().contains('connection')) {
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
