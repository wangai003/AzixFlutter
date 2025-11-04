import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as stellar;
import 'package:http/http.dart' as http;
import 'raffle_service.dart';
import 'secure_wallet_service.dart';
import '../models/raffle_model.dart';

/// Soroban Raffle Service - Integrates Soroban contract interactions with Flutter frontend
/// Handles contract deployment, raffle operations, and transaction management
class SorobanRaffleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final stellar.StellarSDK _sdk = stellar.StellarSDK.TESTNET;

  // Contract configuration
  static const String _contractId =
      'CA7QYNF7SOWQ3GLR2BGMZEHXAVIRZA4KVWLTJJFC7MGXUA74P7UJVSG4'; // Deployed contract ID
  static const String _akofaTokenId =
      'GAXGCEV2XGCUORUWQ4B2NTRVLKUVDCOQT2EL5C3GY3X72LFR2G3QKSKW'; // AKOFA token contract

  // Network configuration
  static const String _networkPassphrase = 'Test SDF Network ; September 2015';
  static const String _sorobanRpcUrl = 'https://soroban-testnet.stellar.org';

  /// Initialize the Soroban raffle service
  static Future<void> initialize() async {
    // Verify contract deployment and configuration
    try {
      final contractExists = await _checkContractDeployment();
      if (!contractExists) {
        throw Exception('Raffle contract not found on network');
      }
      print('✅ Soroban raffle service initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize Soroban raffle service: $e');
      rethrow;
    }
  }

  /// Check if the raffle contract is deployed and accessible
  static Future<bool> _checkContractDeployment() async {
    try {
      // Attempt to call a simple view function to verify contract exists
      final account = await _sdk.accounts.account(_contractId);
      return account.accountId == _contractId;
    } catch (e) {
      print('Contract deployment check failed: $e');
      return false;
    }
  }

  /// Get contract instance for Soroban operations
  /// Note: This is a placeholder for when Soroban SDK support is available
  static dynamic _getContractClient() {
    // TODO: Implement proper Soroban contract client when SDK supports it
    // For now, return null to indicate contract calls are not yet implemented
    return null;
  }

  /// Verify user has sufficient AKOFA balance for raffle entry
  static Future<Map<String, dynamic>> verifyAkofaBalance({
    required String userId,
    required double requiredAmount,
  }) async {
    try {
      // Get user's wallet public key
      final publicKey = await SecureWalletService.getWalletPublicKey(userId);
      if (publicKey == null) {
        return {
          'success': false,
          'error': 'No wallet found for user',
          'hasWallet': false,
        };
      }

      // Check AKOFA balance on-chain
      final account = await _sdk.accounts.account(publicKey);
      final akofaBalance = account.balances!.firstWhere(
        (b) => b.assetCode == 'AKOFA' && b.assetIssuer == _akofaTokenId,
        orElse: () => throw Exception('AKOFA trustline not found'),
      );

      final balance = double.tryParse(akofaBalance.balance) ?? 0.0;
      final hasSufficientBalance = balance >= requiredAmount;

      return {
        'success': true,
        'hasWallet': true,
        'balance': balance,
        'requiredAmount': requiredAmount,
        'sufficient': hasSufficientBalance,
        'publicKey': publicKey,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'hasWallet': false};
    }
  }

  /// Enter a raffle on-chain
  static Future<Map<String, dynamic>> enterRaffle({
    required String raffleId,
    required String userId,
    required String password,
    required double entryAmount,
  }) async {
    try {
      // First verify balance
      final balanceCheck = await verifyAkofaBalance(
        userId: userId,
        requiredAmount: entryAmount,
      );

      if (!balanceCheck['success'] || !balanceCheck['sufficient']) {
        return {
          'success': false,
          'error': balanceCheck['error'] ?? 'Insufficient AKOFA balance',
          'balanceCheck': balanceCheck,
        };
      }

      // Authenticate and decrypt wallet
      final authResult = await SecureWalletService.authenticateAndDecryptWallet(
        userId,
        password,
      );

      if (!authResult['success']) {
        return {
          'success': false,
          'error': 'Wallet authentication failed: ${authResult['error']}',
        };
      }

      final publicKey = authResult['publicKey'] as String;
      final secretKey = authResult['secretKey'] as String;

      // Get raffle details from Firebase
      final raffle = await RaffleService.getRaffle(raffleId);
      if (raffle == null) {
        return {'success': false, 'error': 'Raffle not found'};
      }

      // Convert raffle ID to u64 for contract
      final raffleIdU64 = _stringToU64(raffleId);

      // Create payment transaction to contract
      final keyPair = stellar.KeyPair.fromSecretSeed(secretKey);
      final sourceAccount = await _sdk.accounts.account(publicKey);

      // Create payment operation to contract address
      final akofaAsset = stellar.AssetTypeCreditAlphaNum12(
        'AKOFA',
        _akofaTokenId,
      );

      final paymentOp = stellar.PaymentOperationBuilder(
        _contractId, // Send to contract
        akofaAsset,
        entryAmount.toStringAsFixed(7),
      );

      // Build transaction
      final transactionBuilder = stellar.TransactionBuilder(sourceAccount);
      transactionBuilder.addOperation(paymentOp.build());
      transactionBuilder.addMemo(stellar.MemoText('Raffle entry: $raffleId'));

      final transaction = transactionBuilder.build();
      transaction.sign(keyPair, stellar.Network.TESTNET);

      // Submit transaction to Stellar network
      final response = await _sdk.submitTransaction(transaction);

      if (response.success) {
        // Record entry in Firebase with blockchain verification
        await RaffleService.enterRaffle(
          raffleId: raffleId,
          userId: userId,
          userName: '', // Will be populated from user data
          verificationData: {
            'sorobanTxHash': response.hash,
            'entryAmount': entryAmount,
            'blockchainVerified': true,
            'contractId': _contractId,
            'network': 'testnet',
          },
          transactionId: response.hash,
        );

        return {
          'success': true,
          'transactionHash': response.hash,
          'raffleId': raffleId,
          'entryAmount': entryAmount,
          'explorerUrl': _getExplorerUrl(response.hash!),
          'contractId': _contractId,
        };
      } else {
        return {
          'success': false,
          'error': 'Transaction failed: ${response.extras?.resultCodes}',
          'details': response.extras?.toString(),
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Draw raffle winners on-chain
  static Future<Map<String, dynamic>> drawWinners({
    required String raffleId,
    required int numberOfWinners,
  }) async {
    try {
      // Convert raffle ID to u64
      final raffleIdU64 = _stringToU64(raffleId);

      // For now, use Firebase-based winner selection
      // In production, this would trigger an on-chain draw via contract call
      final entries = await _firestore
          .collection('raffle_entries')
          .where('raffleId', isEqualTo: raffleId)
          .where('isValid', isEqualTo: true)
          .get();

      if (entries.docs.length < numberOfWinners) {
        return {
          'success': false,
          'error':
              'Not enough valid entries for the requested number of winners',
          'entriesCount': entries.docs.length,
          'requestedWinners': numberOfWinners,
        };
      }

      // Select winners randomly
      final random = Random.secure();
      final allEntries = entries.docs.toList();
      final selectedEntries = <QueryDocumentSnapshot>[];

      for (int i = 0; i < numberOfWinners && allEntries.isNotEmpty; i++) {
        final randomIndex = random.nextInt(allEntries.length);
        selectedEntries.add(allEntries.removeAt(randomIndex));
      }

      // Create winner records
      final winners = <Map<String, dynamic>>[];
      for (int i = 0; i < selectedEntries.length; i++) {
        final entry = selectedEntries[i];
        final entryData = entry.data() as Map<String, dynamic>;

        final winnerData = {
          'raffleId': raffleId,
          'entryId': entry.id,
          'winnerUserId': entryData['userId'],
          'winnerName': entryData['userName'],
          'winnerEmail': entryData['userEmail'] ?? '',
          'winnerPosition': i + 1,
          'prizeDetails': {
            'amount': 0,
            'asset': 'AKOFA',
          }, // Will be updated with actual prize
          'drawDate': FieldValue.serverTimestamp(),
          'drawMethod': 'random_selection',
          'claimStatus': 'unclaimed',
        };

        final winnerRef = await _firestore
            .collection('raffle_winners')
            .add(winnerData);
        winnerData['id'] = winnerRef.id;
        winners.add(winnerData);
      }

      // Update raffle status to completed
      await _firestore.collection('raffles').doc(raffleId).update({
        'status': 'RaffleStatus.completed',
        'drawDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Record the draw on blockchain (would be contract call in production)
      // For now, we record it in Firebase with blockchain reference
      final drawRecord = {
        'raffleId': raffleId,
        'numberOfWinners': numberOfWinners,
        'winners': winners,
        'drawMethod':
            'firebase_coordinated', // Will be 'soroban' when contract implemented
        'timestamp': FieldValue.serverTimestamp(),
        'contractId': _contractId,
      };

      await _firestore.collection('raffle_draws').add(drawRecord);

      return {
        'success': true,
        'winners': winners,
        'drawMethod': 'firebase_coordinated',
        'contractId': _contractId,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Distribute prizes to winners
  static Future<Map<String, dynamic>> distributePrizes({
    required String raffleId,
  }) async {
    try {
      // Get raffle details to determine prize pool
      final raffle = await RaffleService.getRaffle(raffleId);
      if (raffle == null) {
        return {'success': false, 'error': 'Raffle not found'};
      }

      // Get all winners for this raffle
      final winners = await _firestore
          .collection('raffle_winners')
          .where('raffleId', isEqualTo: raffleId)
          .get();

      if (winners.docs.isEmpty) {
        return {'success': false, 'error': 'No winners found for this raffle'};
      }

      // Calculate prize per winner (simple equal distribution for now)
      final totalPrizePool = raffle.prizeDetails['totalValue'] ?? 0;
      final prizePerWinner = totalPrizePool / winners.docs.length;

      // Update each winner with their prize amount
      for (final winnerDoc in winners.docs) {
        await _firestore.collection('raffle_winners').doc(winnerDoc.id).update({
          'prizeDetails': {
            'amount': prizePerWinner,
            'asset': 'AKOFA',
            'totalValue': prizePerWinner,
          },
          'prizeAmount': prizePerWinner,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Record prize distribution
      final distributionRecord = {
        'raffleId': raffleId,
        'totalPrizePool': totalPrizePool,
        'numberOfWinners': winners.docs.length,
        'prizePerWinner': prizePerWinner,
        'distributedAt': FieldValue.serverTimestamp(),
        'distributionMethod':
            'firebase_coordinated', // Will be 'soroban' when contract implemented
        'contractId': _contractId,
        'blockchainVerified':
            false, // Will be true when contract call implemented
      };

      await _firestore
          .collection('prize_distributions')
          .add(distributionRecord);

      return {
        'success': true,
        'message': 'Prize distribution completed',
        'raffleId': raffleId,
        'totalPrizePool': totalPrizePool,
        'numberOfWinners': winners.docs.length,
        'prizePerWinner': prizePerWinner,
        'method': 'firebase_coordinated',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Claim prize for a winner
  static Future<Map<String, dynamic>> claimPrize({
    required String winnerId,
    required String userId,
    required String password,
  }) async {
    try {
      // Authenticate wallet
      final authResult = await SecureWalletService.authenticateAndDecryptWallet(
        userId,
        password,
      );

      if (!authResult['success']) {
        return {
          'success': false,
          'error': 'Wallet authentication failed: ${authResult['error']}',
        };
      }

      // Get winner details from Firebase
      final winnerDoc = await _firestore
          .collection('raffle_winners')
          .doc(winnerId)
          .get();
      if (!winnerDoc.exists) {
        return {'success': false, 'error': 'Winner record not found'};
      }

      final winnerData = winnerDoc.data()!;
      final prizeAmount = winnerData['prizeAmount'] as num?;
      final raffleId = winnerData['raffleId'] as String?;

      if (prizeAmount == null || raffleId == null) {
        return {'success': false, 'error': 'Invalid winner data'};
      }

      // In production, this would trigger a contract call to claim the prize
      // For now, we record the claim in Firebase with blockchain reference
      final claimRecord = {
        'winnerId': winnerId,
        'userId': userId,
        'raffleId': raffleId,
        'prizeAmount': prizeAmount,
        'claimedAt': FieldValue.serverTimestamp(),
        'claimMethod':
            'firebase_coordinated', // Will be 'soroban' when contract implemented
        'contractId': _contractId,
        'blockchainVerified':
            false, // Will be true when contract call implemented
      };

      await _firestore.collection('prize_claims').add(claimRecord);

      // Update winner status
      await _firestore.collection('raffle_winners').doc(winnerId).update({
        'claimed': true,
        'claimedAt': FieldValue.serverTimestamp(),
        'claimTxHash':
            'firebase_claim_${DateTime.now().millisecondsSinceEpoch}',
      });

      return {
        'success': true,
        'winnerId': winnerId,
        'prizeAmount': prizeAmount,
        'message': 'Prize claim recorded successfully',
        'claimMethod': 'firebase_coordinated',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get raffle details from contract
  static Future<Map<String, dynamic>?> getRaffleDetails(String raffleId) async {
    try {
      // For now, get details from Firebase until Soroban SDK supports contract calls
      final raffle = await RaffleService.getRaffle(raffleId);
      if (raffle != null) {
        return {
          'id': raffle.id,
          'title': raffle.title,
          'creator': raffle.creatorId,
          'entryRequirement': raffle.entryRequirements['amount'] ?? 0,
          'prizeAmount': raffle.prizeDetails['totalValue'] ?? 0,
          'numWinners':
              raffle.maxEntries, // Using maxEntries as proxy for winners
          'participants': [], // Would be populated from contract in production
          'winners': [], // Would be populated from contract in production
          'isDrawn': raffle.status == RaffleStatus.completed,
          'contractId': _contractId,
          'blockchainVerified': false, // Will be true when contract implemented
        };
      }
      return null;
    } catch (e) {
      print('Error getting raffle details: $e');
      return null;
    }
  }

  /// Get participants for a raffle
  static Future<List<String>?> getRaffleParticipants(String raffleId) async {
    try {
      // For now, get from Firebase until contract calls are implemented
      final entries = await _firestore
          .collection('raffle_entries')
          .where('raffleId', isEqualTo: raffleId)
          .get();

      return entries.docs.map((doc) => doc.data()['userId'] as String).toList();
    } catch (e) {
      print('Error getting raffle participants: $e');
      return null;
    }
  }

  /// Get winners for a raffle
  static Future<List<String>?> getRaffleWinners(String raffleId) async {
    try {
      // For now, get from Firebase until contract calls are implemented
      final winners = await _firestore
          .collection('raffle_winners')
          .where('raffleId', isEqualTo: raffleId)
          .get();

      return winners.docs.map((doc) => doc.data()['userId'] as String).toList();
    } catch (e) {
      print('Error getting raffle winners: $e');
      return null;
    }
  }

  /// Get transaction status and explorer URL
  static String getTransactionExplorerUrl(String transactionHash) {
    return _getExplorerUrl(transactionHash);
  }

  /// Check transaction status on Stellar network
  static Future<Map<String, dynamic>> checkTransactionStatus(
    String transactionHash,
  ) async {
    try {
      final transaction = await _sdk.transactions.transaction(transactionHash);

      return {
        'success': true,
        'hash': transaction.hash,
        'ledger': transaction.ledger,
        'operationCount': transaction.operationCount,
        'feeCharged': transaction.feeCharged,
        'sourceAccount': transaction.sourceAccount,
        'successful': transaction.successful,
        'explorerUrl': _getExplorerUrl(transactionHash),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Helper methods

  /// Convert string ID to u64 for contract calls
  static int _stringToU64(String id) {
    // Simple hash function to convert string to u64
    // In production, use a proper ID generation strategy
    final bytes = utf8.encode(id);
    // Use a simple hash since crypto is not imported
    int hash = 0;
    for (int i = 0; i < bytes.length; i++) {
      hash = (hash * 31 + bytes[i]) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// Parse raffle data from contract response
  static Map<String, dynamic> _parseRaffleFromContract(dynamic contractResult) {
    // Parse Soroban contract response
    // This would depend on the exact contract return format
    return {
      'creator': 'contract_creator',
      'title': 'Raffle Title',
      'entryRequirement': 100,
      'prizeAmount': 1000,
      'numWinners': 1,
      'participants': [],
      'winners': [],
      'isDrawn': false,
    };
  }

  /// Parse participants from contract response
  static List<String> _parseParticipantsFromContract(dynamic contractResult) {
    // Parse participants list from contract
    return [];
  }

  /// Parse winners from contract response
  static List<String> _parseWinnersFromContract(dynamic contractResult) {
    // Parse winners list from contract
    return [];
  }

  /// Get Stellar explorer URL for transaction
  static String _getExplorerUrl(String transactionHash) {
    return 'https://stellar.expert/explorer/testnet/tx/$transactionHash';
  }

  /// Get Soroban explorer URL
  static String getSorobanExplorerUrl(String contractId) {
    return 'https://stellar.expert/explorer/testnet/contract/$contractId';
  }

  /// Get network status
  static Future<Map<String, dynamic>> getNetworkStatus() async {
    try {
      // Get latest ledger information
      final ledgerResponse = await _sdk.ledgers.ledger(1); // Get latest ledger
      return {
        'success': true,
        'latestLedger': ledgerResponse.sequence,
        'networkPassphrase': _networkPassphrase,
        'rpcUrl': _sorobanRpcUrl,
        'contractId': _contractId,
        'akofaTokenId': _akofaTokenId,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Add proper error handling and fallback mechanisms for blockchain operations
  static Future<Map<String, dynamic>> _handleBlockchainOperation({
    required Future<Map<String, dynamic>> Function() blockchainOperation,
    required Map<String, dynamic> Function() fallbackOperation,
    String operationName = 'blockchain operation',
  }) async {
    try {
      // First attempt: Try blockchain operation
      final blockchainResult = await blockchainOperation();

      if (blockchainResult['success'] == true) {
        return {
          ...blockchainResult,
          'method': 'blockchain',
          'fallbackUsed': false,
        };
      }

      // If blockchain operation fails, log the error and try fallback
      print(
        '⚠️ Blockchain operation failed for $operationName: ${blockchainResult['error']}',
      );
      print('🔄 Attempting fallback operation...');

      final fallbackResult = await fallbackOperation();

      return {
        ...fallbackResult,
        'method': 'fallback',
        'fallbackUsed': true,
        'originalError': blockchainResult['error'],
      };
    } catch (e) {
      // If blockchain operation throws an exception, try fallback
      print('❌ Blockchain operation threw exception for $operationName: $e');
      print('🔄 Attempting fallback operation...');

      try {
        final fallbackResult = await fallbackOperation();
        return {
          ...fallbackResult,
          'method': 'fallback',
          'fallbackUsed': true,
          'originalError': e.toString(),
        };
      } catch (fallbackError) {
        // If both blockchain and fallback fail, return comprehensive error
        return {
          'success': false,
          'error': 'Both blockchain and fallback operations failed',
          'blockchainError': e.toString(),
          'fallbackError': fallbackError.toString(),
          'method': 'failed',
          'fallbackUsed': false,
        };
      }
    }
  }

  /// Verify blockchain transaction status with retry logic
  static Future<Map<String, dynamic>> verifyTransactionWithRetry(
    String transactionHash, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final status = await checkTransactionStatus(transactionHash);

        if (status['success'] == true && status['successful'] == true) {
          return {
            'success': true,
            'verified': true,
            'attempt': attempt,
            'transaction': status,
          };
        }

        // If transaction failed, don't retry
        if (status['success'] == true && status['successful'] == false) {
          return {
            'success': false,
            'verified': false,
            'error': 'Transaction failed on blockchain',
            'attempt': attempt,
            'transaction': status,
          };
        }

        // If we can't get status and it's not the last attempt, wait and retry
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay);
        }
      } catch (e) {
        if (attempt == maxRetries) {
          return {
            'success': false,
            'verified': false,
            'error':
                'Failed to verify transaction after $maxRetries attempts: $e',
            'attempt': attempt,
          };
        }
        await Future.delayed(retryDelay);
      }
    }

    return {
      'success': false,
      'verified': false,
      'error': 'Transaction verification timed out',
      'attempts': maxRetries,
    };
  }
}
