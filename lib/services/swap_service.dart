import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as stellar;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'stellar_service.dart';
import '../models/transaction.dart' as app_transaction;

class SwapService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final stellar.StellarSDK _sdk = stellar.StellarSDK.TESTNET; // or stellar.StellarSDK.PUBLIC
  final StellarService _stellarService = StellarService();
  
  // Supported assets for swapping
  static const Map<String, Map<String, String>> supportedAssets = {
    'XLM': {
      'code': 'XLM',
      'issuer': 'native',
      'name': 'Stellar Lumens',
      'type': 'native'
    },
    'AKOFA': {
      'code': 'AKOFA',
      'issuer': 'GDOMDAYWWHIDDETBRW4V36UBJULCCRO3H3FYZODRHUO376KS7SDHLOPU',
      'name': 'Akofa Coin',
      'type': 'custom'
    },
    'USDC': {
      'code': 'USDC',
      'issuer': 'GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
      'name': 'USD Coin',
      'type': 'stablecoin'
    },
    'BTC': {
      'code': 'BTC',
      'issuer': 'GAUTUYY2THLF7SGITDFMXJVYH3LHDSMGEAKSBU267M2K7A3W543CKUEF',
      'name': 'Bitcoin',
      'type': 'crypto'
    },
    'ETH': {
      'code': 'ETH',
      'issuer': 'GBDEVU63Y6NTHJQQZIKVTC23NWLQVP3WJ2RI2OTSJTNYOIGICST6DUXR',
      'name': 'Ethereum',
      'type': 'crypto'
    }
  };
  
  // Get list of supported assets
  List<Map<String, String>> getSupportedAssets() {
    return supportedAssets.values.toList();
  }
  
  // Check if asset has a trustline
  Future<bool> hasAssetTrustline(String publicKey, String assetCode, String assetIssuer) async {
    try {
      // XLM is native and doesn't need a trustline
      if (assetCode == 'XLM') {
        return true;
      }
      
      final account = await _sdk.accounts.account(publicKey);
      
      // Check if any balance entry matches the asset
      return account.balances.any((balance) => 
        balance.assetType != 'native' && 
        balance.assetCode == assetCode && 
        balance.assetIssuer == assetIssuer
      );
    } catch (e) {
      // If account doesn't exist yet on the network, it definitely doesn't have a trustline
      if (e.toString().contains('404')) {
        return false;
      }
      throw Exception('Failed to check asset trustline: $e');
    }
  }
  
  // Add trustline for an asset
  Future<Map<String, dynamic>> addAssetTrustline(String publicKey, String assetCode, String assetIssuer) async {
    try {
      if (kDebugMode) {
        print('Adding trustline for $assetCode (issuer: $assetIssuer)');
      }
      
      // XLM is native and doesn't need a trustline
      if (assetCode == 'XLM') {
        return {
          'success': true,
          'message': 'XLM is native and does not require a trustline',
          'status': 'not_needed'
        };
      }
      
      // Check if trustline already exists
      bool hasTrustline = await hasAssetTrustline(publicKey, assetCode, assetIssuer);
      if (hasTrustline) {
        return {
          'success': true,
          'message': 'Trustline already exists',
          'status': 'existing'
        };
      }
      
      // Get wallet credentials
      Map<String, String>? credentials = await _stellarService.getWalletCredentials();
      if (credentials == null) {
        return {
          'success': false,
          'message': 'Failed to retrieve wallet credentials',
          'status': 'credential_error'
        };
      }
      
      // Validate secret key
      final secretKey = credentials['secretKey'];
      if (secretKey == null || secretKey.isEmpty) {
        return {
          'success': false,
          'message': 'Secret key is missing or invalid',
          'status': 'secret_key_error'
        };
      }
      
      // Create key pair and validate
      stellar.KeyPair sourceKeyPair = stellar.KeyPair.fromSecretSeed(secretKey);
      if (sourceKeyPair.accountId != publicKey) {
        return {
          'success': false,
          'message': 'Key pair mismatch',
          'status': 'key_mismatch'
        };
      }
      
      // Check if account has enough XLM for the transaction
      final xlmCheck = await _stellarService.hasEnoughXlmForTransaction(publicKey);
      if (!xlmCheck['hasEnough']) {
        return {
          'success': false,
          'message': 'Insufficient XLM balance for adding trustline',
          'status': 'insufficient_xlm'
        };
      }
      
      // Load source account
      stellar.AccountResponse sourceAccount = await _sdk.accounts.account(publicKey);
      
      // Create the asset
      stellar.Asset asset = stellar.Asset.createNonNativeAsset(assetCode, assetIssuer);
      
      // Create the ChangeTrust operation
      stellar.ChangeTrustOperationBuilder changeTrustOp = stellar.ChangeTrustOperationBuilder(asset, "922337203685.4775807");
      
      // Add a memo to identify the transaction
      stellar.MemoText memo = stellar.MemoText("Add $assetCode Trustline");
      
      // Build the transaction
      stellar.TransactionBuilder transactionBuilder = stellar.TransactionBuilder(sourceAccount)
        ..addOperation(changeTrustOp.build())
        ..addMemo(memo);
      
      // Build the transaction
      stellar.Transaction transaction = transactionBuilder.build();
      
      // Sign the transaction
      transaction.sign(sourceKeyPair, stellar.Network.TESTNET);
      
      // Submit the transaction
      stellar.SubmitTransactionResponse response = await _sdk.submitTransaction(transaction);
      
      if (response.success) {
        // Record the successful trustline addition in Firestore
        try {
          final String uid = _auth.currentUser!.uid;
          await _firestore.collection('trustlines').doc('${uid}_$assetCode').set({
            'userId': uid,
            'publicKey': publicKey,
            'assetCode': assetCode,
            'assetIssuer': assetIssuer,
            'transactionHash': response.hash,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (recordError) {
          // Just log the error, don't fail the operation
          if (kDebugMode) {
            print('Failed to record trustline in Firestore: $recordError');
          }
        }
        
        return {
          'success': true,
          'message': '$assetCode trustline added successfully',
          'hash': response.hash,
          'status': 'success'
        };
      } else {
        return {
          'success': false,
          'message': 'Transaction failed',
          'error': response.extras.toString(),
          'status': 'transaction_failed'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to add trustline',
        'error': e.toString(),
        'status': 'error'
      };
    }
  }
  
  // Get asset balance
  Future<String> getAssetBalance(String publicKey, String assetCode, String assetIssuer) async {
    try {
      final account = await _sdk.accounts.account(publicKey);
      
      if (assetCode == 'XLM') {
        // Find the native XLM balance
        for (var balance in account.balances) {
          if (balance.assetType == 'native') {
            return balance.balance;
          }
        }
        return "0";
      } else {
        // Find the specific asset balance
        for (var balance in account.balances) {
          if (balance.assetType != 'native' && 
              balance.assetCode == assetCode && 
              balance.assetIssuer == assetIssuer) {
            return balance.balance;
          }
        }
        return "0"; // No balance found for this asset
      }
    } catch (e) {
      if (e.toString().contains('404')) {
        // Account doesn't exist on the network yet
        return "0";
      }
      throw Exception('Failed to fetch asset balance: $e');
    }
  }
  
  // Get exchange rate between two assets
  Future<double> getExchangeRate(String fromAssetCode, String toAssetCode) async {
    try {
      // In a real implementation, you would fetch the current exchange rate from an API
      // For this example, we'll use hardcoded rates
      
      // Base rates against XLM
      Map<String, double> xlmRates = {
        'XLM': 1.0,
        'AKOFA': 0.5, // 1 XLM = 0.5 AKOFA
        'USDC': 3.0, // 1 XLM = 0.33 USDC (or 3 XLM = 1 USDC)
        'BTC': 0.0000025, // 1 XLM = 0.0000025 BTC
        'ETH': 0.000035, // 1 XLM = 0.000035 ETH
      };
      
      // Calculate the exchange rate
      if (fromAssetCode == 'XLM') {
        return xlmRates[toAssetCode] ?? 1.0;
      } else if (toAssetCode == 'XLM') {
        return 1.0 / (xlmRates[fromAssetCode] ?? 1.0);
      } else {
        // Cross rate: fromAsset -> XLM -> toAsset
        double fromToXlm = 1.0 / (xlmRates[fromAssetCode] ?? 1.0);
        double xlmToTo = xlmRates[toAssetCode] ?? 1.0;
        return fromToXlm * xlmToTo;
      }
    } catch (e) {
      throw Exception('Failed to get exchange rate: $e');
    }
  }
  
  // Execute a swap between two assets
  Future<Map<String, dynamic>> executeSwap(
    String fromAssetCode,
    String toAssetCode,
    double amount
  ) async {
    try {
      if (kDebugMode) {
        print('Executing swap: $amount $fromAssetCode -> $toAssetCode');
      }
      
      // Get wallet credentials
      Map<String, String>? credentials = await _stellarService.getWalletCredentials();
      if (credentials == null) {
        return {
          'success': false,
          'message': 'Failed to retrieve wallet credentials',
          'status': 'credential_error'
        };
      }
      
      final publicKey = credentials['publicKey'];
      final secretKey = credentials['secretKey'];
      
      if (publicKey == null || secretKey == null) {
        return {
          'success': false,
          'message': 'Invalid wallet credentials',
          'status': 'invalid_credentials'
        };
      }
      
      // Get asset details
      final fromAsset = supportedAssets[fromAssetCode];
      final toAsset = supportedAssets[toAssetCode];
      
      if (fromAsset == null || toAsset == null) {
        return {
          'success': false,
          'message': 'Unsupported asset',
          'status': 'unsupported_asset'
        };
      }
      
      // Check if user has enough balance
      final fromBalance = await getAssetBalance(
        publicKey, 
        fromAsset['code']!, 
        fromAsset['issuer'] == 'native' ? '' : fromAsset['issuer']!
      );
      
      if (double.parse(fromBalance) < amount) {
        return {
          'success': false,
          'message': 'Insufficient balance',
          'status': 'insufficient_balance'
        };
      }
      
      // Check if user has trustline for the destination asset
      if (toAssetCode != 'XLM') {
        final hasTrustline = await hasAssetTrustline(
          publicKey, 
          toAsset['code']!, 
          toAsset['issuer']!
        );
        
        if (!hasTrustline) {
          // Add trustline for the destination asset
          final trustlineResult = await addAssetTrustline(
            publicKey, 
            toAsset['code']!, 
            toAsset['issuer']!
          );
          
          if (trustlineResult['success'] != true) {
            return {
              'success': false,
              'message': 'Failed to add trustline for ${toAsset['code']}',
              'status': 'trustline_error'
            };
          }
        }
      }
      
      // Get exchange rate
      final exchangeRate = await getExchangeRate(fromAssetCode, toAssetCode);
      
      // Calculate the amount to receive
      final receiveAmount = amount * exchangeRate;
      
      // Create the path payment operation
      // This will swap the assets through the Stellar DEX
      try {
        // Load source account
        stellar.AccountResponse sourceAccount = await _sdk.accounts.account(publicKey);
        
        // Create the source asset
        stellar.Asset sourceAsset;
        if (fromAssetCode == 'XLM') {
          sourceAsset = stellar.Asset.NATIVE;
        } else {
          sourceAsset = stellar.Asset.createNonNativeAsset(
            fromAsset['code']!, 
            fromAsset['issuer']!
          );
        }
        
        // Create the destination asset
        stellar.Asset destinationAsset;
        if (toAssetCode == 'XLM') {
          destinationAsset = stellar.Asset.NATIVE;
        } else {
          destinationAsset = stellar.Asset.createNonNativeAsset(
            toAsset['code']!, 
            toAsset['issuer']!
          );
        }
        
        // Create the path payment operation
        stellar.PathPaymentStrictSendOperationBuilder pathPaymentOp = stellar.PathPaymentStrictSendOperationBuilder(
          sourceAsset,
          amount.toString(),
          publicKey, // Send to self
          destinationAsset,
          (receiveAmount * 0.95).toString() // Accept 5% slippage
        );
        
        // Add a memo to identify the transaction
        stellar.MemoText memo = stellar.MemoText("Swap $fromAssetCode to $toAssetCode");
        
        // Build the transaction
        stellar.TransactionBuilder transactionBuilder = stellar.TransactionBuilder(sourceAccount)
          ..addOperation(pathPaymentOp.build())
          ..addMemo(memo);
        
        // Build the transaction
        stellar.Transaction transaction = transactionBuilder.build();
        
        // Sign the transaction
        transaction.sign(stellar.KeyPair.fromSecretSeed(secretKey), stellar.Network.TESTNET);
        
        // Submit the transaction
        stellar.SubmitTransactionResponse response = await _sdk.submitTransaction(transaction);
        
        if (response.success) {
          // Record the swap in Firestore
          final swapRecord = await _recordSwap(
            publicKey,
            fromAssetCode,
            toAssetCode,
            amount,
            receiveAmount,
            exchangeRate
          );
          
          return {
            'success': true,
            'message': 'Swap executed successfully',
            'fromAmount': amount,
            'toAmount': receiveAmount,
            'exchangeRate': exchangeRate,
            'swapId': swapRecord.id,
            'hash': response.hash,
            'status': 'success'
          };
        } else {
          return {
            'success': false,
            'message': 'Transaction failed',
            'error': response.extras.toString(),
            'status': 'transaction_failed'
          };
        }
      } catch (txError) {
        return {
          'success': false,
          'message': 'Failed to execute swap transaction',
          'error': txError.toString(),
          'status': 'transaction_error'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to execute swap',
        'error': e.toString(),
        'status': 'error'
      };
    }
  }
  
  // Record a swap in Firestore
  Future<DocumentReference> _recordSwap(
    String publicKey,
    String fromAssetCode,
    String toAssetCode,
    double fromAmount,
    double toAmount,
    double exchangeRate
  ) async {
    final String uid = _auth.currentUser!.uid;
    
    return await _firestore.collection('swaps').add({
      'userId': uid,
      'publicKey': publicKey,
      'fromAssetCode': fromAssetCode,
      'toAssetCode': toAssetCode,
      'fromAmount': fromAmount,
      'toAmount': toAmount,
      'exchangeRate': exchangeRate,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'completed'
    });
  }
  
  // Get swap history for current user
  Future<List<Map<String, dynamic>>> getSwapHistory() async {
    try {
      final String uid = _auth.currentUser!.uid;
      
      final querySnapshot = await _firestore.collection('swaps')
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .get();
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting swap history: $e');
      }
      return [];
    }
  }
}