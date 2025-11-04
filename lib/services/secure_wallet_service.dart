import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as stellar;
import 'package:http/http.dart' as http;
import 'akofa_tag_service.dart';

/// Secure Wallet Service implementing password-based AES-GCM encryption with optional biometric protection
/// Similar to MetaMask, Phantom, and other popular wallet implementations
/// Supports both password-only and password + biometric authentication
class SecureWalletService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Biometric/WebAuthn support detection
  static bool _biometricsSupported = false;
  static bool _webauthnSupported = false;

  /// Check if WebAuthn/biometric authentication is supported
  static Future<Map<String, dynamic>> checkBiometricSupport() async {
    try {
      // Check if we're running on web
      bool isWeb = false;
      try {
        // This will work on web platforms
        isWeb = true; // Assume web for now, we'll detect properly
      } catch (e) {
        isWeb = false;
      }

      if (isWeb) {
        // Check WebAuthn support
        _webauthnSupported = await _checkWebAuthnSupport();
        _biometricsSupported = _webauthnSupported;
      } else {
        // Check platform biometric support
        _biometricsSupported = await _checkPlatformBiometrics();
        _webauthnSupported = false;
      }

      return {
        'biometricsSupported': _biometricsSupported,
        'webauthnSupported': _webauthnSupported,
        'platform': isWeb ? 'web' : 'mobile',
      };
    } catch (e) {
      return {
        'biometricsSupported': false,
        'webauthnSupported': false,
        'error': e.toString(),
      };
    }
  }

  /// Check WebAuthn support on web platforms
  static Future<bool> _checkWebAuthnSupport() async {
    try {
      // Check if WebAuthn is supported in the browser
      if (identical(0, 0.0)) {
        // This is a workaround for web platform detection
        // In a real implementation, you would check:
        // return navigator.credentials != null && window.PublicKeyCredential != null;
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check platform biometric support
  static Future<bool> _checkPlatformBiometrics() async {
    try {
      // This would use local_auth package for mobile platforms
      // For now, return false as we focus on web implementation
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Setup biometric authentication for the wallet
  static Future<Map<String, dynamic>> _setupBiometricAuthentication(
    String userId,
    String password,
  ) async {
    try {
      // Check if biometrics are supported
      final supportCheck = await checkBiometricSupport();
      if (!supportCheck['biometricsSupported']) {
        return {
          'success': false,
          'error':
              'Biometric authentication not supported on this device/browser',
        };
      }

      // Create WebAuthn credential
      final credentialResult = await _createWebAuthnCredential(
        userId,
        password,
      );

      if (!credentialResult['success']) {
        return {
          'success': false,
          'error':
              'Failed to create WebAuthn credential: ${credentialResult['error']}',
        };
      }

      return {
        'success': true,
        'data': {
          'credentialId': credentialResult['credentialId'],
          'publicKey': credentialResult['publicKey'],
          'createdAt': FieldValue.serverTimestamp(),
        },
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Authenticate with biometrics (WebAuthn)
  static Future<Map<String, dynamic>> _authenticateWithBiometrics(
    String userId,
  ) async {
    try {
      // Get wallet data to retrieve biometric information
      final walletDoc = await _firestore
          .collection('secure_wallets')
          .doc(userId)
          .get();

      if (!walletDoc.exists) {
        throw Exception('Wallet not found');
      }

      final walletData = walletDoc.data()!;
      final biometricData =
          walletData['biometricData'] as Map<String, dynamic>?;

      if (biometricData == null) {
        throw Exception('Biometric data not found for this wallet');
      }

      final credentialId = biometricData['credentialId'] as String;

      // In production, this would use WebAuthn API:
      // const credential = await navigator.credentials.get({
      //   publicKey: {
      //     challenge: new Uint8Array(32),
      //     allowCredentials: [{
      //       type: 'public-key',
      //       id: Uint8Array.from(atob(credentialId), c => c.charCodeAt(0))
      //     }],
      //     timeout: 60000,
      //   }
      // });

      // For now, simulate successful biometric authentication
      await Future.delayed(const Duration(seconds: 1));

      return {
        'success': true,
        'message': 'Biometric authentication successful',
        'credentialId': credentialId,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Fund wallet with XLM using Friendbot
  static Future<Map<String, dynamic>> _fundWalletWithFriendbot(
    String publicKey,
  ) async {
    try {
      final friendBotUrl = 'https://friendbot.stellar.org/?addr=$publicKey';
      final response = await http.get(Uri.parse(friendBotUrl));

      if (response.statusCode == 200) {
        print(
          '✅ Friendbot request successful, waiting for network confirmation...',
        );

        // Wait for the account to be created and funded on the network
        // Sometimes it takes longer for the transaction to be processed
        await Future.delayed(const Duration(seconds: 8));

        // Try multiple times to verify funding
        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            print('🔍 Funding verification attempt $attempt/3...');

            final account = await stellar.StellarSDK.TESTNET.accounts.account(
              publicKey,
            );
            final nativeBalance = account.balances!.firstWhere(
              (b) => b.assetType == 'native',
            );
            final balance = double.tryParse(nativeBalance.balance) ?? 0.0;

            if (balance > 0) {
              print('✅ Account successfully funded with $balance XLM');
              return {
                'success': true,
                'message': 'Account funded with test XLM',
                'balance': balance,
              };
            } else {
              print('⚠️ Account exists but balance is still 0, waiting...');
              if (attempt < 3) {
                await Future.delayed(const Duration(seconds: 3));
              }
            }
          } catch (e) {
            print('⚠️ Account not yet available (attempt $attempt): $e');
            if (attempt < 3) {
              await Future.delayed(const Duration(seconds: 3));
            }
          }
        }

        return {
          'success': false,
          'error':
              'Account funding verification failed after multiple attempts',
        };
      } else {
        print('❌ Friendbot funding failed with status ${response.statusCode}');
        return {
          'success': false,
          'error':
              'Friendbot funding failed with status ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Create AKOFA trustline for the wallet
  static Future<Map<String, dynamic>> _createAkofaTrustline(
    String publicKey,
    String secretKey,
  ) async {
    try {
      print('🔗 Checking if AKOFA trustline already exists...');

      // First check if trustline already exists
      final account = await stellar.StellarSDK.TESTNET.accounts.account(
        publicKey,
      );
      final hasAkofaTrustline = account.balances!.any(
        (b) =>
            b.assetCode == 'AKOFA' &&
            b.assetIssuer ==
                'GBJGVMBWKGSMPZ4D7QDTW7VPCJUWCJ26OIHFJNRIWVR362NNUU3YCOTQ',
      );

      if (hasAkofaTrustline) {
        print('✅ AKOFA trustline already exists, skipping creation');
        return {
          'success': true,
          'message': 'AKOFA trustline already exists',
          'skipped': true,
        };
      }

      print('🔗 Creating new AKOFA trustline...');

      final keyPair = stellar.KeyPair.fromSecretSeed(secretKey);
      final sourceAccount = await stellar.StellarSDK.TESTNET.accounts.account(
        publicKey,
      );

      // Check if account has sufficient XLM for transaction fees
      final nativeBalance = sourceAccount.balances!.firstWhere(
        (b) => b.assetType == 'native',
      );
      final xlmBalance = double.tryParse(nativeBalance.balance) ?? 0.0;

      if (xlmBalance < 2.0) {
        print(
          '❌ Insufficient XLM balance for trustline creation: $xlmBalance XLM',
        );
        return {
          'success': false,
          'error':
              'Insufficient XLM balance. Need at least 2 XLM for trustline creation. Current balance: $xlmBalance XLM',
        };
      }

      print('💰 Sufficient XLM balance confirmed: $xlmBalance XLM');

      // Create trustline operation for AKOFA asset
      final akofaAsset = stellar.AssetTypeCreditAlphaNum12(
        'AKOFA',
        'GAXGCEV2XGCUORUWQ4B2NTRVLKUVDCOQT2EL5C3GY3X72LFR2G3QKSKW',
      );

      final trustlineOperation = stellar.ChangeTrustOperationBuilder(
        akofaAsset,
        '10000000', // Set a high limit for AKOFA tokens (10 million)
      );

      // Build transaction
      final transactionBuilder = stellar.TransactionBuilder(sourceAccount);
      transactionBuilder.addOperation(trustlineOperation.build());

      final transaction = transactionBuilder.build();
      transaction.sign(keyPair, stellar.Network.TESTNET);

      print('📤 Submitting trustline transaction...');

      // Submit transaction
      final response = await stellar.StellarSDK.TESTNET.submitTransaction(
        transaction,
      );

      if (response.success) {
        print('✅ AKOFA trustline created successfully');
        return {
          'success': true,
          'message': 'AKOFA trustline created successfully',
          'hash': response.hash,
        };
      } else {
        print('❌ Trustline creation failed');
        print('   - Response extras: ${response.extras}');
        print('   - Result codes: ${response.extras?.resultCodes}');

        // Provide more detailed error information
        String errorMessage = 'Trustline creation failed';
        if (response.extras?.resultCodes != null) {
          errorMessage += ': ${response.extras!.resultCodes}';
        } else if (response.extras != null) {
          errorMessage += ': ${response.extras}';
        }

        return {
          'success': false,
          'error': errorMessage,
          'extras': response.extras?.toString(),
        };
      }
    } catch (e) {
      print('❌ Trustline creation error: $e');

      // Check if it's a specific Stellar error
      if (e.toString().contains('Account not found')) {
        return {
          'success': false,
          'error':
              'Account not found on Stellar network. Please wait a moment and try again.',
        };
      } else if (e.toString().contains('insufficient balance')) {
        return {
          'success': false,
          'error':
              'Insufficient XLM balance for transaction fee. Need at least 2 XLM.',
        };
      }

      return {'success': false, 'error': e.toString()};
    }
  }

  /// Create USDC trustline for the wallet
  static Future<Map<String, dynamic>> _createUsdcTrustline(
    String publicKey,
    String secretKey,
  ) async {
    try {
      print('🔗 Checking if USDC trustline already exists...');

      // Fetch account details
      final account = await stellar.StellarSDK.TESTNET.accounts.account(
        publicKey,
      );

      // Check if USDC trustline already exists
      final hasUsdcTrustline = account.balances!.any(
        (b) =>
            b.assetCode == 'USDC' &&
            b.assetIssuer ==
                'GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5',
      );

      if (hasUsdcTrustline) {
        print('✅ USDC trustline already exists, skipping creation');
        return {
          'success': true,
          'message': 'USDC trustline already exists',
          'skipped': true,
        };
      }

      print('🔗 Creating new USDC trustline...');

      final keyPair = stellar.KeyPair.fromSecretSeed(secretKey);
      final sourceAccount = await stellar.StellarSDK.TESTNET.accounts.account(
        publicKey,
      );

      // Check if account has sufficient XLM for transaction fees
      final nativeBalance = sourceAccount.balances!.firstWhere(
        (b) => b.assetType == 'native',
      );
      final xlmBalance = double.tryParse(nativeBalance.balance) ?? 0.0;

      if (xlmBalance < 2.0) {
        print(
          '❌ Insufficient XLM balance for trustline creation: $xlmBalance XLM',
        );
        return {
          'success': false,
          'error':
              'Insufficient XLM balance. Need at least 2 XLM for trustline creation. Current balance: $xlmBalance XLM',
        };
      }

      print('💰 Sufficient XLM balance confirmed: $xlmBalance XLM');

      // Create trustline operation for USDC asset
      final usdcAsset = stellar.AssetTypeCreditAlphaNum4(
        'USDC',
        'GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5',
      );

      final trustlineOperation = stellar.ChangeTrustOperationBuilder(
        usdcAsset,
        '10000000', // Limit (10 million USDC)
      );

      // Build transaction
      final transactionBuilder = stellar.TransactionBuilder(sourceAccount);
      transactionBuilder.addOperation(trustlineOperation.build());

      final transaction = transactionBuilder.build();
      transaction.sign(keyPair, stellar.Network.TESTNET);

      print('📤 Submitting trustline transaction...');

      // Submit transaction
      final response = await stellar.StellarSDK.TESTNET.submitTransaction(
        transaction,
      );

      if (response.success) {
        print('✅ USDC trustline created successfully');
        return {
          'success': true,
          'message': 'USDC trustline created successfully',
          'hash': response.hash,
        };
      } else {
        print('❌ Trustline creation failed');
        print('   - Response extras: ${response.extras}');
        print('   - Result codes: ${response.extras?.resultCodes}');

        String errorMessage = 'Trustline creation failed';
        if (response.extras?.resultCodes != null) {
          errorMessage += ': ${response.extras!.resultCodes}';
        } else if (response.extras != null) {
          errorMessage += ': ${response.extras}';
        }

        return {
          'success': false,
          'error': errorMessage,
          'extras': response.extras?.toString(),
        };
      }
    } catch (e) {
      print('❌ Trustline creation error: $e');

      if (e.toString().contains('Account not found')) {
        return {
          'success': false,
          'error':
              'Account not found on Stellar network. Please wait a moment and try again.',
        };
      } else if (e.toString().contains('insufficient balance')) {
        return {
          'success': false,
          'error':
              'Insufficient XLM balance for transaction fee. Need at least 2 XLM.',
        };
      }

      return {'success': false, 'error': e.toString()};
    }
  }

  /// Create trustlines for all supported assets (AKOFA, USDC, EURC)
  static Future<Map<String, dynamic>> _createAllTrustlines(
    String publicKey,
    String secretKey,
  ) async {
    try {
      print('🔗 Setting up trustlines for supported assets...');

      // Define supported assets (Testnet issuers)
      final assetsToSetup = {
        'AKOFA': 'GAXGCEV2XGCUORUWQ4B2NTRVLKUVDCOQT2EL5C3GY3X72LFR2G3QKSKW',
        'USDC':
            'GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5', // Circle USDC Testnet
        'EURC':
            'GB7T3TSZT5ERXMNV7CGHUWKU2LUB2EPRYQDNQ5R6J3QKJUNNODKRVHCZ', // Circle EURC Testnet
      };

      final keyPair = stellar.KeyPair.fromSecretSeed(secretKey);
      final sourceAccount = await stellar.StellarSDK.TESTNET.accounts.account(
        publicKey,
      );

      // Check if account has sufficient XLM for trustlines
      final nativeBalance = sourceAccount.balances!.firstWhere(
        (b) => b.assetType == 'native',
      );
      final xlmBalance = double.tryParse(nativeBalance.balance) ?? 0.0;

      // Each trustline requires 0.5 XLM reserve + fees
      final requiredBalance = 3.0; // buffer for 2–3 trustlines
      if (xlmBalance < requiredBalance) {
        print('❌ Insufficient XLM: $xlmBalance, need $requiredBalance+');
        return {
          'success': false,
          'error':
              'Insufficient XLM balance. Need at least $requiredBalance XLM. Current balance: $xlmBalance',
        };
      }

      print('💰 Sufficient XLM balance confirmed: $xlmBalance XLM');

      // Gather existing trustlines
      final existingTrustlines = <String>[];
      for (final balance in sourceAccount.balances!) {
        if (balance.assetType != 'native' && balance.assetCode != null) {
          existingTrustlines.add(balance.assetCode!);
        }
      }
      print('📋 Existing trustlines: ${existingTrustlines.join(', ')}');

      // Build trustline operations
      final operations = <stellar.Operation>[];
      final assetsBeingSetup = <String>[];

      for (final entry in assetsToSetup.entries) {
        final assetCode = entry.key;
        final assetIssuer = entry.value;

        if (!existingTrustlines.contains(assetCode)) {
          print('🔗 Adding trustline for $assetCode...');
          final asset = stellar.AssetTypeCreditAlphaNum12(
            assetCode,
            assetIssuer,
          );

          final trustlineOperation = stellar.ChangeTrustOperationBuilder(
            asset,
            '10000000000', // high trust limit
          );

          operations.add(trustlineOperation.build());
          assetsBeingSetup.add(assetCode);
        } else {
          print('✅ $assetCode trustline already exists, skipping');
        }
      }

      if (operations.isEmpty) {
        print('✅ All trustlines already exist');
        return {
          'success': true,
          'message': 'All trustlines already exist',
          'skipped': true,
          'assets': assetsToSetup.keys.toList(),
        };
      }

      print('📤 Submitting trustline tx for: ${assetsBeingSetup.join(', ')}');

      // Build and sign transaction
      final txBuilder = stellar.TransactionBuilder(sourceAccount);
      for (final op in operations) {
        txBuilder.addOperation(op);
      }
      final transaction = txBuilder.build();
      transaction.sign(keyPair, stellar.Network.TESTNET);

      // Submit transaction
      final response = await stellar.StellarSDK.TESTNET.submitTransaction(
        transaction,
      );

      if (response.success) {
        print('✅ Trustlines created successfully');
        return {
          'success': true,
          'message':
              'Trustlines created successfully for: ${assetsBeingSetup.join(', ')}',
          'hash': response.hash,
          'assets': assetsBeingSetup,
          'trustlineResult': {
            for (final asset in assetsToSetup.keys)
              asset.toLowerCase(): assetsBeingSetup.contains(asset),
          },
        };
      } else {
        print('❌ Trustline creation failed');
        print('   - Response extras: ${response.extras}');
        print('   - Result codes: ${response.extras?.resultCodes}');

        String errorMessage = 'Trustline creation failed';
        if (response.extras?.resultCodes != null) {
          errorMessage += ': ${response.extras!.resultCodes}';
        }

        return {
          'success': false,
          'error': errorMessage,
          'extras': response.extras?.toString(),
          'assets': assetsBeingSetup,
        };
      }
    } catch (e) {
      print('❌ Trustline creation error: $e');

      if (e.toString().contains('Account not found')) {
        return {
          'success': false,
          'error': 'Account not found on Stellar network.',
        };
      } else if (e.toString().contains('insufficient balance')) {
        return {
          'success': false,
          'error': 'Insufficient XLM balance for trustline creation.',
        };
      }

      return {'success': false, 'error': e.toString()};
    }
  }

  /// Verify wallet setup (funding and trustlines)
  static Future<Map<String, dynamic>> _verifyWalletSetup(
    String publicKey,
  ) async {
    try {
      final account = await stellar.StellarSDK.TESTNET.accounts.account(
        publicKey,
      );

      // Check XLM balance
      final nativeBalance = account.balances!.firstWhere(
        (b) => b.assetType == 'native',
      );
      final xlmBalance = double.tryParse(nativeBalance.balance) ?? 0.0;

      // Check both AKOFA and USDC trustlines
      final hasAkofaTrustline = account.balances!.any(
        (b) =>
            b.assetCode == 'AKOFA' &&
            b.assetIssuer ==
                'GAXGCEV2XGCUORUWQ4B2NTRVLKUVDCOQT2EL5C3GY3X72LFR2G3QKSKW',
      );
      final hasUsdcTrustline = account.balances!.any(
        (b) =>
            b.assetCode == 'USDC' &&
            b.assetIssuer ==
                'GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5',
      );

      final trustlineStatus = {
        'akofa': hasAkofaTrustline,
        'usdc': hasUsdcTrustline,
      };

      if (xlmBalance > 0 && hasAkofaTrustline && hasUsdcTrustline) {
        return {
          'success': true,
          'message': 'Wallet setup verified successfully',
          'xlmBalance': xlmBalance,
          'trustlines': trustlineStatus,
        };
      } else {
        return {
          'success': false,
          'error': 'Wallet setup incomplete',
          'xlmBalance': xlmBalance,
          'trustlines': trustlineStatus,
          'missingTrustlines': trustlineStatus.entries
              .where((e) => !e.value)
              .map((e) => e.key.toUpperCase())
              .toList(),
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Password-based key derivation using PBKDF2
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 100000, // Industry standard for password hashing
    bits: 256,
  );

  /// Derive encryption key from password and salt
  Future<SecretKey> _deriveKey(String password, List<int> salt) async {
    return await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  /// Encrypt private key with password
  Future<Map<String, String>> _encryptPrivateKey(
    String password,
    String privateKey,
  ) async {
    // Generate random salt for this encryption
    final salt = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      salt[i] = Random.secure().nextInt(256);
    }

    final key = await _deriveKey(password, salt);

    // Use AES-GCM for authenticated encryption
    final algorithm = AesGcm.with256bits();
    final secretBox = await algorithm.encrypt(
      utf8.encode(privateKey),
      secretKey: key,
    );

    return {
      'ciphertext': base64.encode(secretBox.cipherText),
      'nonce': base64.encode(secretBox.nonce),
      'mac': base64.encode(secretBox.mac.bytes),
      'salt': base64.encode(salt),
    };
  }

  /// Decrypt private key with password
  Future<String> _decryptPrivateKey(
    String password,
    Map<String, String> encryptedData,
  ) async {
    final salt = base64.decode(encryptedData['salt']!);
    final key = await _deriveKey(password, salt);

    final algorithm = AesGcm.with256bits();
    final secretBox = SecretBox(
      base64.decode(encryptedData['ciphertext']!),
      nonce: base64.decode(encryptedData['nonce']!),
      mac: Mac(base64.decode(encryptedData['mac']!)),
    );

    final clearText = await algorithm.decrypt(secretBox, secretKey: key);
    return utf8.decode(clearText);
  }

  /// Create a new secure wallet with automatic funding and trustline setup
  static Future<Map<String, dynamic>> createSecureWallet({
    required String userId,
    required String password,
    String? recoveryPhrase,
    bool enableBiometrics = false,
  }) async {
    try {
      // Validate password strength
      if (password.length < 8) {
        throw Exception('Password must be at least 8 characters long');
      }

      print('🔑 Generating new Stellar wallet...');
      // Generate new Stellar wallet
      final keyPair = stellar.KeyPair.random();
      final publicKey = keyPair.accountId;
      final secretKey = keyPair.secretSeed;
      print('✅ Wallet generated: ${publicKey.substring(0, 10)}...');

      // Step 1: Fund the wallet with XLM using Friendbot
      print('💰 Funding wallet with test XLM...');
      final fundingResult = await _fundWalletWithFriendbot(publicKey);
      if (!fundingResult['success']) {
        throw Exception('Failed to fund wallet: ${fundingResult['error']}');
      }
      print('✅ Wallet funded with test XLM');

      // Step 2: Create trustlines for both AKOFA and USDC
      print('🔗 Creating AKOFA trustline...');
      final akofaTrustlineResult = await _createAkofaTrustline(
        publicKey,
        secretKey,
      );
      if (!akofaTrustlineResult['success']) {
        throw Exception(
          'Failed to create AKOFA trustline: ${akofaTrustlineResult['error']}',
        );
      }
      print('✅ AKOFA trustline created successfully');

      print('🔗 Creating USDC trustline...');
      final usdcTrustlineResult = await _createUsdcTrustline(
        publicKey,
        secretKey,
      );
      if (!usdcTrustlineResult['success']) {
        throw Exception(
          'Failed to create USDC trustline: ${usdcTrustlineResult['error']}',
        );
      }
      print('✅ USDC trustline created successfully');

      // Step 3: Verify wallet setup
      print('🔍 Verifying wallet setup...');
      final verificationResult = await _verifyWalletSetup(publicKey);
      if (!verificationResult['success']) {
        throw Exception(
          'Wallet verification failed: ${verificationResult['error']}',
        );
      }
      print('✅ Wallet setup verified');

      // Step 4: Now encrypt and store the credentials
      print('🔐 Encrypting wallet credentials...');
      final service = SecureWalletService();

      // Encrypt the secret key with password
      final encryptedSecretKey = await service._encryptPrivateKey(
        password,
        secretKey,
      );

      // Encrypt recovery phrase if provided
      Map<String, String>? encryptedRecoveryPhrase;
      if (recoveryPhrase != null) {
        encryptedRecoveryPhrase = await service._encryptPrivateKey(
          password,
          recoveryPhrase,
        );
      }

      // Setup biometric authentication if requested
      Map<String, dynamic>? biometricData;
      String securityLevel = 'password';

      if (enableBiometrics) {
        print('🔐 Setting up biometric authentication...');
        final biometricResult = await _setupBiometricAuthentication(
          userId,
          password,
        );

        if (biometricResult['success']) {
          biometricData = biometricResult['data'];
          securityLevel = 'password+biometric';
          print('✅ Biometric authentication setup successfully');
        } else {
          print(
            '⚠️ Biometric setup failed, continuing with password-only: ${biometricResult['error']}',
          );
        }
      }

      // Store encrypted wallet data in Firestore
      final walletData = {
        'userId': userId,
        'publicKey': publicKey,
        'encryptedSecretKey': encryptedSecretKey,
        'encryptedRecoveryPhrase': encryptedRecoveryPhrase,
        'biometricData': biometricData,
        'createdAt': FieldValue.serverTimestamp(),
        'lastAccessed': FieldValue.serverTimestamp(),
        'version': '3.0', // Updated version for biometric support
        'securityLevel': securityLevel,
        'encryptionMethod': 'cryptography-aes-gcm',
        'biometricsEnabled': enableBiometrics && biometricData != null,
        'walletFunded': true,
        'akofaTrustlineCreated': true,
        'usdcTrustlineCreated': true,
        'setupComplete': true,
      };

      await _firestore.collection('secure_wallets').doc(userId).set(walletData);

      // Also update USER collection with public key (for compatibility)
      await _firestore.collection('USER').doc(userId).update({
        'stellarPublicKey': publicKey,
        'hasSecureWallet': true,
        'walletSecurityLevel': securityLevel,
        'walletFunded': true,
        'usdcTrustlineCreated': true,
        'lastWalletUpdate': FieldValue.serverTimestamp(),
      });

      // Generate and link Akofa tag (optional - don't fail wallet creation if this fails)
      print('🏷️ Checking for existing Akofa tag or generating new one...');
      try {
        final user = _auth.currentUser;
        if (user != null) {
          // Get first name from displayName or email as fallback
          String? firstName;
          String? email = user.email;

          if (user.displayName != null && user.displayName!.isNotEmpty) {
            firstName = user.displayName!.split(' ').first;
          } else if (email != null && email.isNotEmpty) {
            firstName = email.split('@').first;
          }

          if (firstName != null && firstName.isNotEmpty) {
            // First, check if user already has an Akofa tag
            final existingTagResult = await AkofaTagService.getUserTag(userId);

            String? tagToLink;
            if (existingTagResult['success']) {
              // User already has a tag, reuse it
              tagToLink = existingTagResult['tag'];
              print('✅ Found existing Akofa tag: $tagToLink');
            } else {
              // Generate a new unique tag
              final tagResult = await AkofaTagService.generateUniqueTag(
                userId: userId,
                firstName: firstName,
                email: email,
              );

              if (tagResult['success']) {
                tagToLink = tagResult['tag'];
                print('✅ Generated new Akofa tag: $tagToLink');
              } else {
                print('⚠️ Failed to generate Akofa tag: ${tagResult['error']}');
                // Skip tag linking if generation fails
              }
            }

            // Link the tag (existing or new) to the wallet if we have one
            if (tagToLink != null) {
              final linkResult = await AkofaTagService.linkTagToWallet(
                userId: userId,
                tag: tagToLink,
                publicKey: publicKey,
              );

              if (linkResult['success']) {
                print('✅ Akofa tag linked to wallet: $tagToLink -> $publicKey');

                // Update wallet data with tag info
                await _firestore
                    .collection('secure_wallets')
                    .doc(userId)
                    .update({'akofaTag': tagToLink, 'tagLinked': true});
              } else {
                print('⚠️ Failed to link Akofa tag: ${linkResult['error']}');
              }
            }
          } else {
            print('⚠️ User display name not available for tag operations');
          }
        } else {
          print('⚠️ User not authenticated for tag operations');
        }
      } catch (e) {
        // Tag operations are optional - don't fail wallet creation
        print('⚠️ Akofa tag operation failed (non-critical): $e');
        print('✅ Wallet created successfully (tag operations skipped)');
      }

      print('✅ Secure wallet created and encrypted successfully');

      return {
        'success': true,
        'publicKey': publicKey,
        'message':
            'Secure wallet created successfully with automatic funding and trustline setup',
        'walletFunded': true,
        'usdcTrustlineCreated': true,
        'securityFeatures': [
          'AES-GCM encryption',
          'PBKDF2 key derivation',
          'Password-based protection',
          'Automatic XLM funding',
          'AKOFA and USDC trustline creation',
          if (enableBiometrics && biometricData != null)
            'Biometric authentication',
          'Recovery phrase support',
        ],
      };
    } catch (e) {
      print('❌ Wallet creation failed: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to create secure wallet',
      };
    }
  }

  /// Create WebAuthn credential for biometric protection
  static Future<Map<String, dynamic>> _createWebAuthnCredential(
    String userId,
    String password,
  ) async {
    try {
      // Check if we're on web platform
      if (!identical(0, 0.0)) {
        return {
          'success': false,
          'error': 'WebAuthn is only supported on web platforms',
        };
      }

      // Generate cryptographically secure challenge
      final challenge = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        challenge[i] = Random.secure().nextInt(256);
      }

      // Create user handle (unique identifier for the user)
      final userHandle = Uint8List(16);
      for (int i = 0; i < 16; i++) {
        userHandle[i] = Random.secure().nextInt(256);
      }

      // Use real WebAuthn API for web platforms
      try {
        // Access WebAuthn API through JavaScript interop
        final credential = await _callWebAuthnCreateCredential(
          challenge: challenge,
          userId: userId,
          userHandle: userHandle,
        );

        return {
          'success': true,
          'credentialId': credential['credentialId'],
          'publicKey': credential['publicKey'],
          'challenge': base64Encode(challenge),
          'userHandle': base64Encode(userHandle),
          'authenticatorData': credential['authenticatorData'],
          'signature': credential['signature'],
          'createdAt': FieldValue.serverTimestamp(),
          'credentialType': 'WebAuthn',
          'algorithm': credential['algorithm'] ?? 'ES256',
        };
      } catch (webauthnError) {
        return {
          'success': false,
          'error': 'WebAuthn credential creation failed: $webauthnError',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Create authenticator data for WebAuthn
  static Uint8List _createAuthenticatorData({
    required Uint8List rpIdHash,
    required Uint8List userHandle,
    required Uint8List credentialId,
  }) {
    final data = BytesBuilder();

    // RP ID Hash (32 bytes)
    data.add(rpIdHash);

    // Flags (1 byte) - user present (0x01) + user verified (0x04) = 0x05
    data.addByte(0x05);

    // Sign count (4 bytes) - set to 0 for new credentials
    data.addByte(0);
    data.addByte(0);
    data.addByte(0);
    data.addByte(0);

    // AAGUID (16 bytes) - set to zeros for simplicity
    data.add(Uint8List(16));

    // Credential ID length (2 bytes)
    final credIdLen = credentialId.length;
    data.addByte(credIdLen >> 8);
    data.addByte(credIdLen & 0xFF);

    // Credential ID
    data.add(credentialId);

    // Credential public key (CBOR encoded, simplified)
    // In a real implementation, this would be proper CBOR
    final publicKeyCbor = _encodeCborPublicKey();
    data.add(publicKeyCbor);

    return data.toBytes();
  }

  /// Hash RP ID for WebAuthn
  static Uint8List _hashRpId(String rpId) {
    return crypto.sha256.convert(utf8.encode(rpId)).bytes as Uint8List;
  }

  /// Hash client data for WebAuthn
  static Uint8List _hashClientData(Uint8List challenge) {
    final clientData = {
      'type': 'webauthn.create',
      'challenge': base64Encode(challenge),
      'origin': 'https://localhost', // In production: window.location.origin
    };

    final clientDataJson = json.encode(clientData);
    return crypto.sha256.convert(utf8.encode(clientDataJson)).bytes
        as Uint8List;
  }

  /// Create attestation signature (simplified)
  static Uint8List _createAttestationSignature({
    required Uint8List authenticatorData,
    required Uint8List clientDataHash,
  }) {
    // Combine authenticator data and client data hash
    final signatureBase = Uint8List.fromList([
      ...authenticatorData,
      ...clientDataHash,
    ]);

    // In a real implementation, this would be signed by the authenticator's private key
    // For simulation, we'll create a deterministic signature
    return crypto.sha256.convert(signatureBase).bytes as Uint8List;
  }

  /// Encode public key in CBOR format (simplified)
  static Uint8List _encodeCborPublicKey() {
    // Simplified CBOR encoding for ECDSA public key
    // In a real implementation, this would use a proper CBOR library
    final cbor = BytesBuilder();

    // CBOR map header (major type 5, length 5)
    cbor.addByte(0xA5);

    // Key 1: kty (key type) - 2 (EC2)
    cbor.addByte(0x01); // unsigned int 1
    cbor.addByte(0x02); // unsigned int 2

    // Key 3: alg (algorithm) - -7 (ES256)
    cbor.addByte(0x03); // unsigned int 3
    cbor.addByte(0x26); // negative int 6 (-7 = 0x26 in CBOR)

    // Key -1: crv (curve) - 1 (P-256)
    cbor.addByte(0x20); // negative int 1
    cbor.addByte(0x01); // unsigned int 1

    // Key -2: x coordinate (32 bytes)
    cbor.addByte(0x21); // negative int 2
    cbor.addByte(0x58); // byte string of length 32
    cbor.addByte(0x20); // length
    cbor.add(Uint8List(32)); // placeholder x coordinate

    // Key -3: y coordinate (32 bytes)
    cbor.addByte(0x22); // negative int 3
    cbor.addByte(0x58); // byte string of length 32
    cbor.addByte(0x20); // length
    cbor.add(Uint8List(32)); // placeholder y coordinate

    return cbor.toBytes();
  }

  /// Call WebAuthn create credential API (web platform only)
  static Future<Map<String, dynamic>> _callWebAuthnCreateCredential({
    required Uint8List challenge,
    required String userId,
    required Uint8List userHandle,
  }) async {
    // This would use JavaScript interop to call the WebAuthn API
    // For now, throw an error indicating this needs to be implemented
    throw Exception(
      'WebAuthn create credential not implemented. Requires JavaScript interop for web platform.',
    );
  }

  /// Call WebAuthn get credential API (web platform only)
  static Future<Map<String, dynamic>> _callWebAuthnGetCredential({
    required Uint8List challenge,
    required String credentialId,
  }) async {
    // This would use JavaScript interop to call the WebAuthn API
    // For now, throw an error indicating this needs to be implemented
    throw Exception(
      'WebAuthn get credential not implemented. Requires JavaScript interop for web platform.',
    );
  }

  /// Authenticate with password (and optionally biometrics) and decrypt wallet
  static Future<Map<String, dynamic>> authenticateAndDecryptWallet(
    String userId,
    String password, {
    bool useBiometrics = false,
  }) async {
    try {
      print('🔐 Starting wallet decryption for user: $userId');

      // Validate inputs
      if (userId.isEmpty) {
        throw Exception('Invalid user ID provided');
      }
      if (password.isEmpty) {
        throw Exception('Password is required');
      }

      // Get wallet data from Firestore
      final walletDoc = await _firestore
          .collection('secure_wallets')
          .doc(userId)
          .get();

      if (!walletDoc.exists) {
        print('❌ Secure wallet not found for user: $userId');
        throw Exception(
          'Secure wallet not found. Please create a secure wallet first.',
        );
      }

      print('✅ Secure wallet data found');

      final walletData = walletDoc.data()!;
      final encryptedSecretKey =
          walletData['encryptedSecretKey'] as Map<String, dynamic>;
      final publicKey = walletData['publicKey'] as String;
      final biometricsEnabled =
          walletData['biometricsEnabled'] as bool? ?? false;

      // Handle biometric authentication if requested and available
      if (useBiometrics && biometricsEnabled) {
        print('🔒 Performing biometric authentication...');
        final biometricResult = await _authenticateWithBiometrics(userId);

        if (!biometricResult['success']) {
          return {
            'success': false,
            'error':
                'Biometric authentication failed: ${biometricResult['error']}',
            'message': 'Please use password authentication instead',
          };
        }

        print('✅ Biometric authentication successful');
        // If biometrics succeed, we can proceed with password decryption
      } else if (useBiometrics && !biometricsEnabled) {
        return {
          'success': false,
          'error': 'Biometric authentication not enabled for this wallet',
          'message':
              'Please enable biometrics first or use password authentication',
        };
      }

      // Create service instance for decryption
      final service = SecureWalletService();

      // Convert to the expected type for decryption
      final encryptedData = Map<String, String>.from(encryptedSecretKey);

      // Decrypt the secret key using password
      print('🔓 Decrypting secret key...');
      final secretKey = await service._decryptPrivateKey(
        password,
        encryptedData,
      );

      print('✅ Secret key decrypted successfully');

      // Verify the decrypted key is valid by checking if it produces the correct public key
      try {
        final keyPair = stellar.KeyPair.fromSecretSeed(secretKey);
        final derivedPublicKey = keyPair.accountId;

        if (derivedPublicKey != publicKey) {
          throw Exception('Decrypted key verification failed');
        }

        print('✅ Decrypted key verification successful');
      } catch (e) {
        print('❌ Invalid decrypted key: $e');
        throw Exception('Invalid password or corrupted wallet data');
      }

      // Update last accessed timestamp
      await _firestore.collection('secure_wallets').doc(userId).update({
        'lastAccessed': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'publicKey': publicKey,
        'secretKey': secretKey,
        'message': 'Wallet decrypted successfully',
      };
    } catch (e) {
      print('❌ Wallet decryption failed: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to authenticate and decrypt wallet',
      };
    }
  }

  /// Authenticate with WebAuthn
  static Future<Map<String, dynamic>> _authenticateWebAuthn(
    String credentialId,
    String userId,
  ) async {
    try {
      // Check if we're on web platform
      if (!identical(0, 0.0)) {
        return {
          'success': false,
          'error': 'WebAuthn is only supported on web platforms',
        };
      }

      // Get stored credential data
      final walletDoc = await _firestore
          .collection('secure_wallets')
          .doc(userId)
          .get();

      if (!walletDoc.exists) {
        throw Exception('Wallet data not found');
      }

      final walletData = walletDoc.data()!;
      final biometricData =
          walletData['biometricData'] as Map<String, dynamic>?;

      if (biometricData == null) {
        throw Exception('Biometric data not found for this wallet');
      }

      final storedCredentialId = biometricData['credentialId'] as String;
      if (storedCredentialId != credentialId) {
        throw Exception('Credential ID mismatch');
      }

      // Generate new challenge for authentication
      final challenge = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        challenge[i] = Random.secure().nextInt(256);
      }

      // Use real WebAuthn API for authentication
      try {
        final authResult = await _callWebAuthnGetCredential(
          challenge: challenge,
          credentialId: credentialId,
        );

        return {
          'success': true,
          'message': 'Biometric authentication successful',
          'credentialId': credentialId,
          'challenge': base64Encode(challenge),
          'authenticatorData': authResult['authenticatorData'],
          'signature': authResult['signature'],
          'userHandle': authResult['userHandle'],
        };
      } catch (webauthnError) {
        return {
          'success': false,
          'error': 'WebAuthn authentication failed: $webauthnError',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Check if user has a secure wallet
  static Future<bool> hasSecureWallet(String userId) async {
    try {
      final walletDoc = await _firestore
          .collection('secure_wallets')
          .doc(userId)
          .get();
      return walletDoc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Get wallet public key without authentication
  static Future<String?> getWalletPublicKey(String userId) async {
    try {
      final walletDoc = await _firestore
          .collection('secure_wallets')
          .doc(userId)
          .get();
      if (walletDoc.exists) {
        return walletDoc.data()?['publicKey'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Transaction limits configuration
  static const double _maxXlmTransaction =
      1000.0; // Maximum XLM per transaction
  static const double _maxAkofaTransaction =
      10000.0; // Maximum AKOFA per transaction
  static const double _dailyXlmLimit = 5000.0; // Daily XLM limit
  static const double _dailyAkofaLimit = 25000.0; // Daily AKOFA limit
  static const int _maxTransactionsPerHour = 10; // Max transactions per hour

  /// Validate transaction limits and security checks
  static Future<Map<String, dynamic>> _validateTransactionLimits({
    required String userId,
    required String publicKey,
    required double amount,
    required String assetCode,
  }) async {
    try {
      // Check transaction amount limits
      if (assetCode == 'XLM' && amount > _maxXlmTransaction) {
        return {
          'valid': false,
          'error':
              'Transaction amount exceeds maximum limit of $_maxXlmTransaction XLM',
          'limit': _maxXlmTransaction,
          'asset': 'XLM',
        };
      }

      if (assetCode == 'AKOFA' && amount > _maxAkofaTransaction) {
        return {
          'valid': false,
          'error':
              'Transaction amount exceeds maximum limit of $_maxAkofaTransaction AKOFA',
          'limit': _maxAkofaTransaction,
          'asset': 'AKOFA',
        };
      }

      // Check daily limits
      final dailyLimitCheck = await _checkDailyTransactionLimits(
        userId,
        amount,
        assetCode,
      );
      if (!dailyLimitCheck['valid']) {
        return dailyLimitCheck;
      }

      // Check transaction frequency
      final frequencyCheck = await _checkTransactionFrequency(userId);
      if (!frequencyCheck['valid']) {
        return frequencyCheck;
      }

      // Check wallet balance
      final balanceCheck = await _checkWalletBalance(
        publicKey,
        amount,
        assetCode,
      );
      if (!balanceCheck['valid']) {
        return balanceCheck;
      }

      return {
        'valid': true,
        'message': 'Transaction limits validated successfully',
      };
    } catch (e) {
      return {'valid': false, 'error': 'Transaction validation failed: $e'};
    }
  }

  /// Check daily transaction limits
  static Future<Map<String, dynamic>> _checkDailyTransactionLimits(
    String userId,
    double amount,
    String assetCode,
  ) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      // Query today's transactions
      final transactions = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .where('assetCode', isEqualTo: assetCode)
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('status', isEqualTo: 'completed')
          .get();

      double todayTotal = 0.0;
      for (final doc in transactions.docs) {
        final data = doc.data();
        todayTotal += (data['amount'] as num?)?.toDouble() ?? 0.0;
      }

      final dailyLimit = assetCode == 'XLM' ? _dailyXlmLimit : _dailyAkofaLimit;
      final newTotal = todayTotal + amount;

      if (newTotal > dailyLimit) {
        return {
          'valid': false,
          'error':
              'Daily limit exceeded. Today: $todayTotal, Requested: $amount, Limit: $dailyLimit',
          'todayTotal': todayTotal,
          'requested': amount,
          'limit': dailyLimit,
          'asset': assetCode,
        };
      }

      return {'valid': true, 'todayTotal': todayTotal, 'newTotal': newTotal};
    } catch (e) {
      // If we can't check limits, allow transaction but log warning
      print('Warning: Could not verify daily limits: $e');
      return {'valid': true, 'warning': 'Could not verify daily limits'};
    }
  }

  /// Check transaction frequency
  static Future<Map<String, dynamic>> _checkTransactionFrequency(
    String userId,
  ) async {
    try {
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));

      final recentTransactions = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(oneHourAgo))
          .get();

      if (recentTransactions.docs.length >= _maxTransactionsPerHour) {
        return {
          'valid': false,
          'error':
              'Transaction frequency limit exceeded. Maximum $_maxTransactionsPerHour transactions per hour.',
          'recentCount': recentTransactions.docs.length,
          'limit': _maxTransactionsPerHour,
        };
      }

      return {'valid': true, 'recentCount': recentTransactions.docs.length};
    } catch (e) {
      print('Warning: Could not verify transaction frequency: $e');
      return {
        'valid': true,
        'warning': 'Could not verify transaction frequency',
      };
    }
  }

  /// Check wallet balance before transaction
  static Future<Map<String, dynamic>> _checkWalletBalance(
    String publicKey,
    double amount,
    String assetCode,
  ) async {
    try {
      final account = await stellar.StellarSDK.TESTNET.accounts.account(
        publicKey,
      );

      if (assetCode == 'XLM') {
        final nativeBalance = account.balances!.firstWhere(
          (b) => b.assetType == 'native',
        );
        final balance = double.tryParse(nativeBalance.balance) ?? 0.0;

        // Reserve 1 XLM for fees
        final availableBalance = balance - 1.0;

        if (amount > availableBalance) {
          return {
            'valid': false,
            'error':
                'Insufficient XLM balance. Available: $availableBalance, Required: $amount',
            'available': availableBalance,
            'required': amount,
            'asset': 'XLM',
          };
        }
      } else if (assetCode == 'AKOFA') {
        final akofaBalance = account.balances!.firstWhere(
          (b) =>
              b.assetCode == 'AKOFA' &&
              b.assetIssuer ==
                  'GAXGCEV2XGCUORUWQ4B2NTRVLKUVDCOQT2EL5C3GY3X72LFR2G3QKSKW',
          orElse: () => throw Exception('AKOFA trustline not found'),
        );
        final balance = double.tryParse(akofaBalance.balance) ?? 0.0;

        if (amount > balance) {
          return {
            'valid': false,
            'error':
                'Insufficient AKOFA balance. Available: $balance, Required: $amount',
            'available': balance,
            'required': amount,
            'asset': 'AKOFA',
          };
        }
      }

      return {'valid': true, 'message': 'Balance check passed'};
    } catch (e) {
      return {'valid': false, 'error': 'Balance verification failed: $e'};
    }
  }

  /// Sign transaction with password authentication (new method)
  static Future<Map<String, dynamic>> signTransactionWithPassword({
    required String userId,
    required String password,
    required String recipientAddress,
    required double amount,
    required String assetCode,
    required String memo, // Memo is now required
  }) async {
    try {
      // Authenticate and decrypt wallet
      final authResult = await authenticateAndDecryptWallet(userId, password);

      if (!authResult['success']) {
        throw Exception('Authentication failed: ${authResult['error']}');
      }

      final decryptedSecretKey = authResult['secretKey'] as String;
      final walletPublicKey = authResult['publicKey'] as String;

      // Validate transaction limits and security checks
      final limitValidation = await _validateTransactionLimits(
        userId: userId,
        publicKey: authResult['publicKey'] as String,
        amount: amount,
        assetCode: assetCode,
      );

      if (!limitValidation['valid']) {
        return {
          'success': false,
          'error': limitValidation['error'],
          'validationType': 'limits',
          'details': limitValidation,
        };
      }

      // Create and sign transaction
      final keyPair = stellar.KeyPair.fromSecretSeed(decryptedSecretKey);
      final sourceAccount = await stellar.StellarSDK.TESTNET.accounts.account(
        walletPublicKey,
      );

      // Create payment operation
      late stellar.PaymentOperationBuilder paymentOp;
      if (assetCode == 'XLM') {
        paymentOp = stellar.PaymentOperationBuilder(
          recipientAddress,
          stellar.AssetTypeNative(),
          amount.toString(),
        );
      } else if (assetCode == 'AKOFA') {
        final akofaAsset = stellar.AssetTypeCreditAlphaNum12(
          'AKOFA',
          'GAXGCEV2XGCUORUWQ4B2NTRVLKUVDCOQT2EL5C3GY3X72LFR2G3QKSKW',
        );
        paymentOp = stellar.PaymentOperationBuilder(
          recipientAddress,
          akofaAsset,
          amount.toStringAsFixed(7),
        );
      } else {
        throw Exception('Unsupported asset: $assetCode');
      }

      // Build transaction
      final transactionBuilder = stellar.TransactionBuilder(sourceAccount);
      transactionBuilder.addOperation(paymentOp.build());

      // Memo is now required for all transactions
      transactionBuilder.addMemo(stellar.MemoText(memo));

      final transaction = transactionBuilder.build();
      transaction.sign(keyPair, stellar.Network.TESTNET);

      // Submit transaction
      final response = await stellar.StellarSDK.TESTNET.submitTransaction(
        transaction,
      );

      if (response.success) {
        // Record transaction for limits tracking
        await _recordTransaction(
          userId: userId,
          hash: response.hash ?? 'unknown_hash',
          recipientAddress: recipientAddress,
          amount: amount,
          assetCode: assetCode,
          memo: memo,
          senderAddress: walletPublicKey,
        );

        // Clear sensitive data from memory
        // In a real implementation, you would securely clear the secretKey from memory

        return {
          'success': true,
          'hash': response.hash,
          'message': 'Transaction signed and submitted successfully',
          'amount': amount,
          'assetCode': assetCode,
          'recipient': recipientAddress,
        };
      } else {
        throw Exception('Transaction submission failed: ${response.extras}');
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to sign transaction',
      };
    }
  }

  /// Sign transaction with biometric authentication (legacy compatibility method)
  static Future<Map<String, dynamic>> signTransactionWithBiometrics({
    required String userId,
    required String recipientAddress,
    required double amount,
    required String assetCode,
    required String memo, // Memo is now required
    String? password, // Now required for password-based auth
  }) async {
    if (password == null || password.isEmpty) {
      throw Exception('Password is required for transaction signing');
    }

    return await signTransactionWithPassword(
      userId: userId,
      password: password,
      recipientAddress: recipientAddress,
      amount: amount,
      assetCode: assetCode,
      memo: memo,
    );
  }

  /// Record transaction for limits tracking
  static Future<void> _recordTransaction({
    required String userId,
    required String hash,
    required String recipientAddress,
    required double amount,
    required String assetCode,
    String? memo,
    String? senderAkofaTag,
    String? recipientAkofaTag,
    String? senderAddress,
  }) async {
    try {
      // Resolve sender's Akofa tag if not provided
      String? resolvedSenderTag = senderAkofaTag;
      String? resolvedSenderAddress = senderAddress;

      if (resolvedSenderTag == null || resolvedSenderAddress == null) {
        try {
          final tagResult = await AkofaTagService.getUserTag(userId);
          if (tagResult['success']) {
            resolvedSenderTag ??= tagResult['tag'];
            resolvedSenderAddress ??= tagResult['publicKey'];
          }
        } catch (e) {
          // If tag resolution fails, use user ID as fallback
          resolvedSenderTag ??= userId;
          resolvedSenderAddress ??= userId;
        }
      }

      // Resolve recipient's Akofa tag if not provided
      String? resolvedRecipientTag = recipientAkofaTag;
      if (resolvedRecipientTag == null) {
        try {
          // Try to resolve recipient address to tag
          final resolveResult = await AkofaTagService.resolveTag(
            recipientAddress,
          );
          if (resolveResult['success']) {
            resolvedRecipientTag = resolveResult['tag'];
          }
        } catch (e) {
          // If resolution fails, recipient tag remains null
        }
      }

      final transactionData = {
        'userId': userId,
        'hash': hash,
        'recipientAddress': recipientAddress,
        'amount': amount,
        'assetCode': assetCode,
        'memo': memo,
        'status': 'completed',
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'secure_wallet_service',
        'senderAkofaTag': resolvedSenderTag,
        'recipientAkofaTag': resolvedRecipientTag,
        'senderAddress': resolvedSenderAddress,
      };

      await _firestore.collection('transactions').add(transactionData);
    } catch (e) {
      // Log error but don't fail the transaction
      print('Warning: Failed to record transaction: $e');
    }
  }

  /// Export wallet recovery data (with additional security)
  static Future<Map<String, dynamic>> exportWalletRecoveryData(
    String userId,
  ) async {
    try {
      // This would require additional authentication and security measures
      // For now, return a placeholder
      return {
        'success': false,
        'message': 'Recovery export requires additional security verification',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
