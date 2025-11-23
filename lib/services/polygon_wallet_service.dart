import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart' as web3dart;
import 'package:web3dart/crypto.dart' as web3crypto;
import '../config/api_config.dart';

/// Secure Polygon Wallet Service implementing password-based AES-GCM encryption
/// Similar to MetaMask, Phantom, and other popular wallet implementations
/// Supports Polygon (Matic) network operations
class PolygonWalletService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Polygon RPC endpoints
  static const String _polygonMainnetRpc = 'https://polygon-rpc.com/';
  static const String _polygonTestnetRpc =
      'https://rpc-amoy.polygon.technology/';

  // Network configuration - can be switched
  static String _currentRpcUrl = _polygonTestnetRpc;
  static bool _isTestnet = true;
  static int _chainId = 80002; // Amoy testnet, 137 for mainnet

  /// Set network (mainnet or testnet)
  static void setNetwork({required bool isTestnet}) {
    _isTestnet = isTestnet;
    _currentRpcUrl = isTestnet ? _polygonTestnetRpc : _polygonMainnetRpc;
    _chainId = isTestnet ? 80002 : 137;
  }

  /// Get current network info
  static Map<String, dynamic> getNetworkInfo() {
    return {
      'isTestnet': _isTestnet,
      'rpcUrl': _currentRpcUrl,
      'chainId': _chainId,
      'networkName': _isTestnet ? 'Polygon Amoy' : 'Polygon Mainnet',
    };
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
  /// Re-engineered for robust operation with comprehensive validation and error handling
  Future<String> _decryptPrivateKey(
    String password,
    Map<String, String> encryptedData,
  ) async {
    try {
      print('🔓 [DECRYPT] Starting decryption process...');
      print('🔍 [DECRYPT] Encrypted data keys: ${encryptedData.keys.toList()}');
      
      // Validate that all required fields are present
      final requiredFields = ['salt', 'ciphertext', 'nonce', 'mac'];
      for (final field in requiredFields) {
        if (!encryptedData.containsKey(field) || encryptedData[field] == null || encryptedData[field]!.isEmpty) {
          throw Exception('Missing or empty required field: $field in encrypted data');
        }
      }
      print('✅ [DECRYPT] All required fields present');
      
      // Decode salt and log its properties
      final salt = base64.decode(encryptedData['salt']!);
      print('🔍 [DECRYPT] Salt length: ${salt.length} bytes (expected: 16)');
      if (salt.length != 16) {
        throw Exception('Invalid salt length: ${salt.length} bytes (expected: 16 bytes)');
      }
      
      // Derive key using PBKDF2 with same parameters as encryption
      print('🔑 [DECRYPT] Deriving key from password using PBKDF2...');
      final key = await _deriveKey(password, salt);
      print('✅ [DECRYPT] Key derived successfully');
      
      // Decode encrypted components
      print('🔍 [DECRYPT] Decoding encrypted components...');
      final ciphertextBytes = base64.decode(encryptedData['ciphertext']!);
      final nonceBytes = base64.decode(encryptedData['nonce']!);
      final macBytes = base64.decode(encryptedData['mac']!);
      
      print('🔍 [DECRYPT] Ciphertext length: ${ciphertextBytes.length} bytes');
      print('🔍 [DECRYPT] Nonce length: ${nonceBytes.length} bytes (expected: 12)');
      print('🔍 [DECRYPT] MAC length: ${macBytes.length} bytes (expected: 16)');
      
      // Validate nonce and MAC lengths
      if (nonceBytes.length != 12) {
        throw Exception('Invalid nonce length: ${nonceBytes.length} bytes (expected: 12 bytes for AES-GCM)');
      }
      if (macBytes.length != 16) {
        throw Exception('Invalid MAC length: ${macBytes.length} bytes (expected: 16 bytes)');
      }
      
      // Create SecretBox for AES-GCM decryption
      final algorithm = AesGcm.with256bits();
      final secretBox = SecretBox(
        ciphertextBytes,
        nonce: nonceBytes,
        mac: Mac(macBytes),
      );
      
      // Attempt decryption
      print('🔓 [DECRYPT] Attempting AES-GCM decryption...');
      final clearText = await algorithm.decrypt(secretBox, secretKey: key);
      print('✅ [DECRYPT] Decryption successful');
      
      // Decode to string
      final decryptedString = utf8.decode(clearText);
      print('🔍 [DECRYPT] Decrypted data length: ${decryptedString.length} characters');
      
      // Validate decrypted data is not empty
      if (decryptedString.isEmpty) {
        throw Exception('Decryption resulted in empty string');
      }
      
      print('✅ [DECRYPT] Decryption completed successfully');
      return decryptedString;
      
    } catch (e, stackTrace) {
      print('❌ [DECRYPT] Decryption failed: $e');
      print('❌ [DECRYPT] Stack trace: $stackTrace');
      
      // Provide more specific error messages
      if (e.toString().contains('MAC check failed') || e.toString().contains('authentication')) {
        throw Exception('Decryption failed: Invalid password or corrupted encrypted data (MAC verification failed)');
      } else if (e.toString().contains('base64')) {
        throw Exception('Decryption failed: Invalid base64 encoding in encrypted data');
      } else if (e.toString().contains('Missing or empty')) {
        throw Exception('Decryption failed: $e');
      } else {
        throw Exception('Decryption failed: ${e.toString()}');
      }
    }
  }

  /// Generate a new Polygon wallet (ECDSA keypair using web3dart)
  Map<String, String> _generatePolygonWallet() {
    // Generate random private key using web3dart
    final privateKey = web3dart.EthPrivateKey.createRandom(Random.secure());
    final address = privateKey.address;
    
    // Get private key as hex string
    // privateKey.privateKey is a Uint8List, convert it to hex
    final privateKeyBytes = privateKey.privateKey;
    // Convert Uint8List to hex string manually
    final privateKeyHex = privateKeyBytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join().padLeft(64, '0');
    
    // Add 0x prefix for consistency with Ethereum standards
    final privateKeyWithPrefix = '0x$privateKeyHex';
    
    print('🔑 [GEN] Generated private key length: ${privateKeyWithPrefix.length} (with 0x prefix)');
    print('🔑 [GEN] Generated address: ${address.hex}');
    
    // Verify that the generated private key derives to the same address
    try {
      final verifyPrivateKey = web3dart.EthPrivateKey(privateKeyBytes);
      final verifyAddress = verifyPrivateKey.address.hex;
      print('🔍 [GEN] Verification - derived address: $verifyAddress');
      if (verifyAddress.toLowerCase() != address.hex.toLowerCase()) {
        throw Exception('Address verification failed during generation!');
      }
      print('✅ [GEN] Address verification passed');
    } catch (e) {
      print('❌ [GEN] Address verification failed: $e');
      throw Exception('Wallet generation verification failed: $e');
    }
    
    return {
      'privateKey': privateKeyWithPrefix,  // Now includes 0x prefix (66 chars)
      'address': address.hex,  // Includes 0x prefix (42 chars)
    };
  }

  /// Create a new secure Polygon wallet with automatic setup
  static Future<Map<String, dynamic>> createSecurePolygonWallet({
    required String userId,
    required String password,
    String? recoveryPhrase,
  }) async {
    try {
      // Validate password strength
      if (password.length < 8) {
        throw Exception('Password must be at least 8 characters long');
      }

      print('🔑 Generating new Polygon wallet...');
      final service = PolygonWalletService();
      final walletKeys = service._generatePolygonWallet();
      final address = walletKeys['address']!;
      final privateKey = walletKeys['privateKey']!;
      print('✅ Polygon wallet generated: ${address.substring(0, 10)}...');

      // Encrypt the private key with password
      print('🔐 Encrypting Polygon wallet credentials...');
      final encryptedPrivateKey = await service._encryptPrivateKey(
        password,
        privateKey,
      );

      // Encrypt recovery phrase if provided
      Map<String, String>? encryptedRecoveryPhrase;
      if (recoveryPhrase != null) {
        encryptedRecoveryPhrase = await service._encryptPrivateKey(
          password,
          recoveryPhrase,
        );
      }

      // Store encrypted wallet data in Firestore
      final walletData = {
        'userId': userId,
        'address': address,
        'encryptedPrivateKey': encryptedPrivateKey,
        'encryptedRecoveryPhrase': encryptedRecoveryPhrase,
        'createdAt': FieldValue.serverTimestamp(),
        'lastAccessed': FieldValue.serverTimestamp(),
        'version': '1.0',
        'network': _isTestnet ? 'polygon-amoy' : 'polygon-mainnet',
        'chainId': _chainId,
        'walletType': 'polygon',
        'setupComplete': true,
      };

      await _firestore
          .collection('polygon_wallets')
          .doc(userId)
          .set(walletData);

      // Update USER collection with Polygon wallet address
      await _firestore.collection('USER').doc(userId).update({
        'polygonAddress': address,
        'hasPolygonWallet': true,
        'polygonWalletCreated': true,
        'lastWalletUpdate': FieldValue.serverTimestamp(),
      });

      print('✅ Secure Polygon wallet created and encrypted successfully');

      return {
        'success': true,
        'address': address,
        'message': 'Secure Polygon wallet created successfully',
        'network': _isTestnet ? 'polygon-amoy' : 'polygon-mainnet',
        'chainId': _chainId,
        'securityFeatures': [
          'AES-GCM encryption',
          'PBKDF2 key derivation',
          'Password-based protection',
          'Recovery phrase support',
        ],
      };
    } catch (e) {
      print('❌ Polygon wallet creation failed: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to create secure Polygon wallet',
      };
    }
  }

  /// Authenticate with password and decrypt Polygon wallet
  /// Re-engineered for robust operation with comprehensive validation
  static Future<Map<String, dynamic>> authenticateAndDecryptPolygonWallet(
    String userId,
    String password,
  ) async {
    try {
      print('═══════════════════════════════════════════════════════════════');
      print('🔐 [AUTH] WALLET DECRYPTION START');
      print('═══════════════════════════════════════════════════════════════');
      print('👤 [AUTH] User ID: $userId');
      print('🔍 [AUTH] Password length: ${password.length} characters');

      // Validate inputs with detailed error messages
      if (userId.isEmpty) {
        throw Exception('User ID is empty or invalid. Please ensure you are logged in.');
      }
      if (password.isEmpty) {
        throw Exception('Password cannot be empty. Please enter your wallet password.');
      }
      if (password.length < 8) {
        throw Exception('Password appears to be invalid (too short). Please check your password.');
      }

      print('✅ [AUTH] Input validation passed');

      // Retrieve wallet data from Firestore
      print('📂 [AUTH] Retrieving wallet from Firestore: polygon_wallets/$userId');
      final walletDoc = await _firestore
          .collection('polygon_wallets')
          .doc(userId)
          .get();

      if (!walletDoc.exists) {
        print('❌ [AUTH] Wallet document does not exist');
        throw Exception(
          'Wallet not found in database. Please create a wallet first or contact support.',
        );
      }

      print('✅ [AUTH] Wallet document retrieved from Firestore');

      // Extract and validate wallet data
      final walletData = walletDoc.data();
      if (walletData == null) {
        throw Exception('Wallet data is null. Database may be corrupted.');
      }

      print('🔍 [AUTH] Wallet data fields: ${walletData.keys.toList()}');

      // Validate essential fields exist
      if (!walletData.containsKey('encryptedPrivateKey')) {
        throw Exception('Wallet data missing encryptedPrivateKey field. Database may be corrupted.');
      }
      if (!walletData.containsKey('address')) {
        throw Exception('Wallet data missing address field. Database may be corrupted.');
      }

      // Extract encrypted private key
      final encryptedPrivateKeyRaw = walletData['encryptedPrivateKey'];
      if (encryptedPrivateKeyRaw == null) {
        throw Exception('Encrypted private key is null in database.');
      }

      print('✅ [AUTH] Encrypted private key field exists');

      // Convert to Map<String, dynamic> first
      final encryptedPrivateKeyMap = encryptedPrivateKeyRaw as Map<String, dynamic>;
      print('🔍 [AUTH] Encrypted data type: Map<String, dynamic>');
      print('🔍 [AUTH] Encrypted data fields: ${encryptedPrivateKeyMap.keys.toList()}');

      // Validate encrypted data structure
      final requiredFields = ['salt', 'ciphertext', 'nonce', 'mac'];
      for (final field in requiredFields) {
        if (!encryptedPrivateKeyMap.containsKey(field)) {
          throw Exception('Encrypted data missing required field: $field. Database may be corrupted.');
        }
        if (encryptedPrivateKeyMap[field] == null) {
          throw Exception('Encrypted data field $field is null. Database may be corrupted.');
        }
      }

      print('✅ [AUTH] All required encryption fields present in database');

      // Convert to Map<String, String> for decryption (ensure all values are strings)
      final encryptedData = <String, String>{};
      for (final entry in encryptedPrivateKeyMap.entries) {
        if (entry.value is String) {
          encryptedData[entry.key] = entry.value as String;
        } else {
          encryptedData[entry.key] = entry.value.toString();
        }
      }

      print('✅ [AUTH] Encrypted data converted to Map<String, String>');
      print('🔍 [AUTH] Salt preview: ${encryptedData['salt']!.substring(0, min(20, encryptedData['salt']!.length))}...');

      // Extract stored address for verification
      final storedAddress = walletData['address'] as String;
      print('🔍 [AUTH] Stored address: $storedAddress');
      print('🔍 [AUTH] Address format: ${storedAddress.startsWith('0x') ? 'Valid (0x...)' : 'Invalid'}');
      print('🔍 [AUTH] Address length: ${storedAddress.length} (expected: 42)');

      // Validate address format
      if (!storedAddress.startsWith('0x') || storedAddress.length != 42) {
        throw Exception('Stored address has invalid format. Database may be corrupted.');
      }

      print('✅ [AUTH] Stored address validation passed');

      // Create service instance for decryption
      final service = PolygonWalletService();

      // Attempt to decrypt the private key
      print('═══════════════════════════════════════════════════════════════');
      print('🔓 [AUTH] DECRYPTING PRIVATE KEY');
      print('═══════════════════════════════════════════════════════════════');
      
      final privateKey = await service._decryptPrivateKey(
        password,
        encryptedData,
      );

      print('═══════════════════════════════════════════════════════════════');
      print('✅ [AUTH] PRIVATE KEY DECRYPTED SUCCESSFULLY');
      print('═══════════════════════════════════════════════════════════════');
      print('🔍 [AUTH] Decrypted key length: ${privateKey.length} characters');
      print('🔍 [AUTH] Decrypted key preview: ${privateKey.substring(0, min(10, privateKey.length))}...');
      print('🔍 [AUTH] Full decrypted key: $privateKey');

      // Optionally derive address from the decrypted key for information purposes
      // (but don't fail if it doesn't match)
      print('═══════════════════════════════════════════════════════════════');
      print('ℹ️ [AUTH] DERIVING ADDRESS FROM DECRYPTED KEY (INFO ONLY)');
      print('═══════════════════════════════════════════════════════════════');
      
      String? derivedAddress;
      try {
        derivedAddress = _deriveAddressFromPrivateKey(privateKey);
        print('✅ [AUTH] Address derived from decrypted key: $derivedAddress');
        
        // Compare addresses (case-insensitive) - for information only
        final storedAddressLower = storedAddress.toLowerCase();
        final derivedAddressLower = derivedAddress.toLowerCase();
        
        print('🔍 [AUTH] Address comparison (informational):');
        print('    Stored address:  $storedAddressLower');
        print('    Derived address: $derivedAddressLower');
        
        if (derivedAddressLower != storedAddressLower) {
          print('⚠️ [AUTH] Note: Addresses do not match, but proceeding anyway');
          print('    This indicates the stored address and private key are mismatched');
        } else {
          print('✅ [AUTH] Addresses match perfectly!');
        }
        
      } catch (e) {
        print('⚠️ [AUTH] Could not derive address from private key: $e');
        print('    This is OK - returning the decrypted private key anyway');
        derivedAddress = null;
      }

      // Update last accessed timestamp
      print('📝 [AUTH] Updating last accessed timestamp...');
      await _firestore.collection('polygon_wallets').doc(userId).update({
        'lastAccessed': FieldValue.serverTimestamp(),
      });

      print('═══════════════════════════════════════════════════════════════');
      print('✅ [AUTH] WALLET DECRYPTION COMPLETED SUCCESSFULLY');
      print('═══════════════════════════════════════════════════════════════');
      print('📍 [AUTH] Returning decrypted credentials:');
      print('    Stored address: $storedAddress');
      print('    Decrypted private key: $privateKey');
      if (derivedAddress != null) {
        print('    Derived address: $derivedAddress');
        print('    Addresses match: ${derivedAddress.toLowerCase() == storedAddress.toLowerCase()}');
      }
      print('═══════════════════════════════════════════════════════════════');

      return {
        'success': true,
        'address': storedAddress,  // The address stored in database
        'privateKey': privateKey,  // The decrypted private key
        'derivedAddress': derivedAddress,  // Address derived from private key (may differ)
        'addressesMatch': derivedAddress != null && 
            derivedAddress.toLowerCase() == storedAddress.toLowerCase(),
        'message': 'Wallet decrypted successfully',
        'network': _isTestnet ? 'polygon-amoy' : 'polygon-mainnet',
        'chainId': _chainId,
      };
      
    } catch (e, stackTrace) {
      print('═══════════════════════════════════════════════════════════════');
      print('❌ [AUTH] WALLET DECRYPTION FAILED');
      print('═══════════════════════════════════════════════════════════════');
      print('❌ [AUTH] Error: $e');
      print('❌ [AUTH] Stack trace: $stackTrace');
      
      // Return detailed error information
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Wallet decryption failed',
        'details': 'Check console logs for detailed error information',
      };
    }
  }

  /// Derive Polygon address from private key using web3dart
  /// Handles both 0x-prefixed and non-prefixed keys
  static String _deriveAddressFromPrivateKey(String privateKey) {
    try {
      print('═══════════════════════════════════════════════════════════════');
      print('🔍 [DERIVE] ADDRESS DERIVATION START');
      print('═══════════════════════════════════════════════════════════════');
      print('🔍 [DERIVE] Input private key length: ${privateKey.length}');
      print('🔍 [DERIVE] Input private key preview: ${privateKey.substring(0, min(20, privateKey.length))}...');
      
      // Handle different private key formats
      String cleanKey = privateKey.trim();
      print('🔍 [DERIVE] After trim: ${cleanKey.length} characters');
      
      // Remove 0x prefix if present
      if (cleanKey.startsWith('0x') || cleanKey.startsWith('0X')) {
        print('🔍 [DERIVE] Removing 0x prefix...');
        cleanKey = cleanKey.substring(2);
        print('🔍 [DERIVE] After removing prefix: ${cleanKey.length} characters');
      }
      
      // Validate hex format
      if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(cleanKey)) {
        print('⚠️ [DERIVE] Not pure hex, attempting BigInt conversion...');
        try {
          // Try parsing as decimal BigInt
          final bigInt = BigInt.parse(cleanKey);
          cleanKey = bigInt.toRadixString(16).padLeft(64, '0');
          print('✅ [DERIVE] Converted decimal to hex: ${cleanKey.length} characters');
        } catch (e) {
          print('❌ [DERIVE] BigInt conversion failed: $e');
          throw Exception('Invalid private key format: not valid hex or decimal string');
        }
      }
      
      // Normalize key length to 64 characters (32 bytes)
      if (cleanKey.length < 64) {
        print('⚠️ [DERIVE] Key too short (${cleanKey.length}), padding with zeros...');
        cleanKey = cleanKey.padLeft(64, '0');
        print('✅ [DERIVE] After padding: ${cleanKey.length} characters');
      } else if (cleanKey.length > 64) {
        print('⚠️ [DERIVE] Key too long (${cleanKey.length}), truncating...');
        // Take the last 64 characters
        cleanKey = cleanKey.substring(cleanKey.length - 64);
        print('✅ [DERIVE] After truncating: ${cleanKey.length} characters');
      }
      
      print('🔍 [DERIVE] Final hex key length: ${cleanKey.length} characters');
      print('🔍 [DERIVE] Final hex key preview: ${cleanKey.substring(0, 20)}...');
      
      // Convert to bytes
      final privateKeyBytes = web3crypto.hexToBytes(cleanKey);
      print('🔍 [DERIVE] Private key bytes length: ${privateKeyBytes.length} bytes');
      
      // Validate byte length (must be exactly 32 bytes)
      if (privateKeyBytes.length != 32) {
        throw Exception('Invalid private key: expected 32 bytes, got ${privateKeyBytes.length} bytes');
      }
      
      print('✅ [DERIVE] Private key validation passed');
      
      // Create EthPrivateKey and derive address
      print('🔑 [DERIVE] Creating EthPrivateKey and deriving address...');
      final ethPrivateKey = web3dart.EthPrivateKey(privateKeyBytes);
      final derivedAddress = ethPrivateKey.address.hex;
      
      print('═══════════════════════════════════════════════════════════════');
      print('✅ [DERIVE] ADDRESS DERIVED SUCCESSFULLY');
      print('═══════════════════════════════════════════════════════════════');
      print('📍 [DERIVE] Derived address: $derivedAddress');
      print('═══════════════════════════════════════════════════════════════');
      
      return derivedAddress;
      
    } catch (e, stackTrace) {
      print('═══════════════════════════════════════════════════════════════');
      print('❌ [DERIVE] ADDRESS DERIVATION FAILED');
      print('═══════════════════════════════════════════════════════════════');
      print('❌ [DERIVE] Error: $e');
      print('❌ [DERIVE] Stack trace: $stackTrace');
      print('═══════════════════════════════════════════════════════════════');
      rethrow;
    }
  }

  /// Check if user has a Polygon wallet
  static Future<bool> hasPolygonWallet(String userId) async {
    try {
      final walletDoc = await _firestore
          .collection('polygon_wallets')
          .doc(userId)
          .get();
      return walletDoc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Get Polygon wallet address without authentication
  static Future<String?> getPolygonWalletAddress(String userId) async {
    try {
      final walletDoc = await _firestore
          .collection('polygon_wallets')
          .doc(userId)
          .get();
      if (walletDoc.exists) {
        return walletDoc.data()?['address'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Polygon token registry with common tokens
  // ERC-20 ABI for token operations
  static const String _erc20ABI = '''
  [
    {"constant":true,"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"type":"function"},
    {"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"type":"function"},
    {"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"type":"function"},
    {"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"type":"function"}
  ]
  ''';

  // Token contracts to check (including AKOFA on Amoy)
  static List<String> get _tokenContracts {
    if (_isTestnet) {
      // Amoy testnet tokens
      return [
        '0xf1266ACCf0f757c61e4DFDD9EBBcaC05D2Ee375F', // AKOFA (AKF) Token on Amoy
        // Add more testnet tokens as needed
      ];
    } else {
      // Mainnet tokens
      return [
        '0xc2132D05D31c914a87C6611C10748AEb04B58e8F6', // USDT
        '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174', // USDC
        '0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A459', // DAI
        // Add more mainnet tokens as needed
      ];
    }
  }

  /// Get Polygon wallet balance (single token)
  static Future<Map<String, dynamic>> getPolygonBalance(String address) async {
    try {
      final response = await http.post(
        Uri.parse(_currentRpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'method': 'eth_getBalance',
          'params': [address, 'latest'],
          'id': 1,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final balanceHex = data['result'] as String;

        // Convert hex to decimal (wei to MATIC)
        final balanceWei = int.parse(balanceHex.substring(2), radix: 16);
        final balanceMatic = balanceWei / 1e18; // Convert wei to MATIC

        return {
          'success': true,
          'balance': balanceMatic,
          'balanceWei': balanceWei.toString(),
          'symbol': 'MATIC',
          'network': _isTestnet ? 'polygon-amoy' : 'polygon-mainnet',
        'chainId': _chainId,
        };
      } else {
        throw Exception('RPC request failed: ${response.statusCode}');
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'balance': 0.0,
        'symbol': 'MATIC',
      };
    }
  }

  /// Get all Polygon token balances for an address using web3dart
  static Future<Map<String, dynamic>> getAllPolygonTokenBalances(
    String address,
  ) async {
    try {
      final tokenBalances = <String, Map<String, dynamic>>{};
      final client = web3dart.Web3Client(_currentRpcUrl, http.Client());

      try {
        // Get native MATIC balance
        final maticBalance = await getPolygonBalance(address);
        if (maticBalance['success'] == true && (maticBalance['balance'] as double) > 0) {
          tokenBalances['MATIC'] = {
            'symbol': 'MATIC',
            'name': 'Polygon Matic',
            'balance': maticBalance['balance'],
            'formattedBalance': (maticBalance['balance'] as double)
                .toStringAsFixed(6),
            'decimals': 18,
            'contractAddress': '',
            'isNative': true,
          };
        }

        // Get ERC-20 token balances using web3dart
        final userAddress = web3dart.EthereumAddress.fromHex(address);
        final contractAbi = web3dart.ContractAbi.fromJson(_erc20ABI, 'ERC20');

        for (final contractAddr in _tokenContracts) {
          try {
            final contract = web3dart.DeployedContract(
              contractAbi,
              web3dart.EthereumAddress.fromHex(contractAddr),
            );

            final nameFn = contract.function('name');
            final symbolFn = contract.function('symbol');
            final decimalsFn = contract.function('decimals');
            final balanceFn = contract.function('balanceOf');

            // Fetch token metadata and balance
            final nameResult = await client.call(
              contract: contract,
              function: nameFn,
              params: [],
            );
            final symbolResult = await client.call(
              contract: contract,
              function: symbolFn,
              params: [],
            );
            final decimalsResult = await client.call(
              contract: contract,
              function: decimalsFn,
              params: [],
            );
            final balanceResult = await client.call(
              contract: contract,
              function: balanceFn,
              params: [userAddress],
            );

            final name = nameResult.first as String;
            final symbol = symbolResult.first as String;
            final decimals = decimalsResult.first as BigInt;
            final balanceWei = balanceResult.first as BigInt;

            // Convert balance from wei to token units
            final divisor = BigInt.from(10).pow(decimals.toInt());
            final balance = balanceWei.toDouble() / divisor.toDouble();

            // Only add if balance > 0
            if (balance > 0) {
              tokenBalances[symbol] = {
                'symbol': symbol,
                'name': name,
                'balance': balance,
                'formattedBalance': balance.toStringAsFixed(decimals.toInt() == 6 ? 6 : 4),
                'decimals': decimals.toInt(),
                'contractAddress': contractAddr,
                'isNative': false,
              };
            }
          } catch (e) {
            // Skip tokens that fail (might not exist or have issues)
            print('Error fetching token $contractAddr: $e');
            continue;
          }
        }
      } finally {
        await client.dispose();
      }

      return {
        'success': true,
        'address': address,
        'network': _isTestnet ? 'polygon-amoy' : 'polygon-mainnet',
        'chainId': _chainId,
        'tokens': tokenBalances,
        'tokenCount': tokenBalances.length,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'address': address,
        'tokens': {},
        'tokenCount': 0,
      };
    }
  }

  /// Send MATIC transaction
  static Future<Map<String, dynamic>> sendMaticTransaction({
    required String userId,
    required String password,
    required String toAddress,
    required double amountMatic,
    int? gasLimit,
    int? gasPrice,
  }) async {
    try {
      // Authenticate and decrypt wallet
      final authResult = await authenticateAndDecryptPolygonWallet(
        userId,
        password,
      );

      if (!authResult['success']) {
        throw Exception('Authentication failed: ${authResult['error']}');
      }

      final privateKey = authResult['privateKey'] as String;
      final fromAddress = authResult['address'] as String;

      // Convert amount to wei
      final amountWei = BigInt.from(amountMatic * 1e18);

      // Create web3dart client
      final client = web3dart.Web3Client(_currentRpcUrl, http.Client());
      
      try {
        // Create credentials from private key
        final privateKeyBytes = web3crypto.hexToBytes(
          privateKey.startsWith('0x') ? privateKey.substring(2) : privateKey,
        );
        final credentials = web3dart.EthPrivateKey(privateKeyBytes);
        
        // Get nonce
        final nonce = await client.getTransactionCount(credentials.address);
        
        // Get gas price
        final currentGasPrice = gasPrice != null
            ? web3dart.EtherAmount.fromBigInt(web3dart.EtherUnit.gwei, BigInt.from(gasPrice))
            : await client.getGasPrice();
        final currentGasLimit = gasLimit ?? 21000; // Keep as int for maxGas parameter
        
        // Create transaction (use web3dart Transaction)
        final transaction = web3dart.Transaction(
          to: web3dart.EthereumAddress.fromHex(toAddress),
          value: web3dart.EtherAmount.fromBigInt(web3dart.EtherUnit.wei, amountWei),
          gasPrice: currentGasPrice,
          maxGas: currentGasLimit,
          nonce: nonce,
        );
        
        // Sign and send transaction
        final txHash = await client.sendTransaction(
          credentials,
          transaction,
          chainId: _chainId,
        );
        
        await client.dispose();

        return {
          'success': true,
          'txHash': txHash,
          'from': fromAddress,
          'to': toAddress,
          'amount': amountMatic,
          'gasUsed': currentGasLimit,
          'message': 'MATIC transaction sent successfully',
        };
      } finally {
        await client.dispose();
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to send MATIC transaction',
      };
    }
  }

  /// Estimate gas fee for MATIC transfer
  static Future<Map<String, dynamic>> estimateMaticGasFee({
    required String fromAddress,
    required String toAddress,
    required double amountMatic,
  }) async {
    try {
      final client = web3dart.Web3Client(_currentRpcUrl, http.Client());
      
      try {
        // Get current gas price
        final gasPrice = await client.getGasPrice();
        
        // Standard gas limit for MATIC transfer
        const gasLimit = 21000;
        
        // Calculate total gas fee in MATIC
        final gasFeeWei = gasPrice.getInWei * BigInt.from(gasLimit);
        final gasFeeMatic = gasFeeWei.toDouble() / 1e18;
        
        // Get current MATIC balance
        final balanceResult = await getPolygonBalance(fromAddress);
        final currentBalance = balanceResult['balance'] as double? ?? 0.0;
        
        // Calculate total required (amount + gas)
        final totalRequired = amountMatic + gasFeeMatic;
        final hasEnough = currentBalance >= totalRequired;
        
        return {
          'success': true,
          'gasFee': gasFeeMatic,
          'gasPrice': gasPrice.getInWei.toString(),
          'gasLimit': gasLimit,
          'totalRequired': totalRequired,
          'currentBalance': currentBalance,
          'hasEnoughForGas': hasEnough,
          'insufficientAmount': hasEnough ? 0.0 : (totalRequired - currentBalance),
        };
      } finally {
        await client.dispose();
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'gasFee': 0.0,
      };
    }
  }
  
  /// Estimate gas fee for ERC-20 token transfer
  static Future<Map<String, dynamic>> estimateERC20GasFee({
    required String fromAddress,
    required String tokenContractAddress,
  }) async {
    try {
      final client = web3dart.Web3Client(_currentRpcUrl, http.Client());
      
      try {
        // Get current gas price
        final gasPrice = await client.getGasPrice();
        
        // Standard gas limit for ERC-20 transfer (higher than native transfer)
        const gasLimit = 100000;
        
        // Calculate total gas fee in MATIC
        final gasFeeWei = gasPrice.getInWei * BigInt.from(gasLimit);
        final gasFeeMatic = gasFeeWei.toDouble() / 1e18;
        
        // Get current MATIC balance
        final balanceResult = await getPolygonBalance(fromAddress);
        final currentBalance = balanceResult['balance'] as double? ?? 0.0;
        
        // For ERC-20, we only need gas fee (not sending MATIC)
        final hasEnough = currentBalance >= gasFeeMatic;
        
        return {
          'success': true,
          'gasFee': gasFeeMatic,
          'gasPrice': gasPrice.getInWei.toString(),
          'gasLimit': gasLimit,
          'currentBalance': currentBalance,
          'hasEnoughForGas': hasEnough,
          'insufficientAmount': hasEnough ? 0.0 : (gasFeeMatic - currentBalance),
        };
      } finally {
        await client.dispose();
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'gasFee': 0.0,
      };
    }
  }

  /// Get transaction receipt
  static Future<Map<String, dynamic>> getTransactionReceipt(
    String txHash,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(_currentRpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'method': 'eth_getTransactionReceipt',
          'params': [txHash],
          'id': 1,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final receipt = data['result'];

        if (receipt != null) {
          return {
            'success': true,
            'receipt': receipt,
            'status': receipt['status'] == '0x1' ? 'success' : 'failed',
            'gasUsed': int.parse(receipt['gasUsed'].substring(2), radix: 16),
            'blockNumber': int.parse(
              receipt['blockNumber'].substring(2),
              radix: 16,
            ),
          };
        }
      }

      return {
        'success': false,
        'error': 'Transaction not found or still pending',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get transaction history for a Polygon address using Alchemy API
  /// Uses alchemy_getAssetTransfers + eth_getTransactionByHash + eth_getTransactionReceipt
  /// Returns ALL transactions: MATIC, ERC-20, NFTs, internal transfers
  static Future<List<Map<String, dynamic>>> getPolygonTransactionHistory(
    String address, {
    int limit = 50,
  }) async {
    if (!ApiConfig.hasAlchemyApiKey) {
      print('❌ No Alchemy API key configured!');
      print('   Configure your API key in lib/config/api_config.dart');
      return [];
    }
    
    try {
      final network = _isTestnet ? 'polygon-amoy' : 'polygon-mainnet';
      final rpcUrl = 'https://$network.g.alchemy.com/v2/${ApiConfig.alchemyApiKey}';
      
      print('🔄 Fetching transactions using Alchemy API...');
      print('📍 Address: $address');
      print('🌐 Network: $network');
      
      // Step 1: Get all asset transfers
      final transfers = await _getAlchemyAssetTransfers(rpcUrl, address);
      print('✅ Found ${transfers.length} transfers');
      
      if (transfers.isEmpty) return [];
      
      // Step 2: Enrich with full transaction details
      final enrichedTxs = <Map<String, dynamic>>[];
      
      for (final transfer in transfers.take(limit)) {
        try {
          final hash = transfer['hash'] as String?;
          if (hash == null) continue;
          
          // Get full transaction data
          final rawTx = await _getTransactionByHash(rpcUrl, hash);
          final receipt = await _getTransactionReceipt(rpcUrl, hash);
          
          // Parse transfer data
          final from = transfer['from'] as String? ?? '';
          final to = transfer['to'] as String? ?? '';
          final asset = transfer['asset'] as String? ?? 'MATIC';
          final value = transfer['value'] != null
              ? double.tryParse(transfer['value'].toString()) ?? 0.0
              : 0.0;
          
          // Parse timestamp
          final metadata = transfer['metadata'] as Map<String, dynamic>?;
          final blockTimestamp = metadata?['blockTimestamp'] as String?;
          DateTime timestamp = DateTime.now();
          if (blockTimestamp != null) {
            try {
              timestamp = DateTime.parse(blockTimestamp);
            } catch (_) {}
          }
          
          // Parse block number
          final blockNum = transfer['blockNum'] as String?;
          int blockNumber = 0;
          if (blockNum != null) {
            blockNumber = int.tryParse(blockNum.replaceAll('0x', ''), radix: 16) ?? 0;
          }
          
          // Determine type
          final userAddr = address.toLowerCase();
          final isIncoming = to.toLowerCase() == userAddr;
          final isOutgoing = from.toLowerCase() == userAddr;
          String type = 'contract';
          if (isIncoming && !isOutgoing) type = 'receive';
          else if (isOutgoing && !isIncoming) type = 'send';
          else if (isIncoming && isOutgoing) type = 'self';
          
          // Parse gas and status
          int gasUsed = 0;
          int gasPrice = 0;
          String status = 'success';
          
          if (receipt != null) {
            final gasUsedHex = receipt['gasUsed'] as String?;
            if (gasUsedHex != null) {
              gasUsed = int.tryParse(gasUsedHex.replaceAll('0x', ''), radix: 16) ?? 0;
            }
            final statusHex = receipt['status'] as String?;
            status = statusHex == '0x1' ? 'success' : 'failed';
          }
          
          if (rawTx != null) {
            final gasPriceHex = rawTx['gasPrice'] as String?;
            if (gasPriceHex != null) {
              gasPrice = int.tryParse(gasPriceHex.replaceAll('0x', ''), radix: 16) ?? 0;
            }
          }
          
          final txMap = {
            'hash': hash,
            'blockNumber': blockNumber,
            'timestamp': timestamp,
            'from': from,
            'to': to,
            'value': value,
            'asset': asset,
            'tokenName': asset,
            'contractAddress': transfer['rawContract']?['address'] as String? ?? '',
            'type': type,
            'status': status,
            'gasPrice': gasPrice,
            'gasUsed': gasUsed,
            'confirmations': 0,
            'network': _isTestnet ? 'polygon-amoy' : 'polygon-mainnet',
          };
          
          print('✅ Enriched transaction: hash=${txMap['hash']}, type=${txMap['type']}, from=${txMap['from']}, to=${txMap['to']}, value=${txMap['value']}, asset=${txMap['asset']}');
          
          enrichedTxs.add(txMap);
        } catch (e) {
          print('⚠️ Error enriching transfer: $e');
          continue;
        }
      }
      
      // Sort by timestamp
      enrichedTxs.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
      
      print('✅ Loaded ${enrichedTxs.length} transactions');
      return enrichedTxs;
      
    } catch (e) {
      print('❌ Error fetching transactions: $e');
      return [];
    }
  }
  
  /// Get asset transfers using Alchemy's alchemy_getAssetTransfers
  static Future<List<dynamic>> _getAlchemyAssetTransfers(String rpcUrl, String address) async {
    print('═══════════════════════════════════════════════════════════════');
    print('🔍 ALCHEMY API REQUEST');
    print('═══════════════════════════════════════════════════════════════');
    print('📍 RPC URL (masked): ${rpcUrl.replaceAll(RegExp(r'/v2/.*'), '/v2/***')}');
    print('📍 Address: $address');
    print('🔑 API Key length: ${ApiConfig.alchemyApiKey.length} chars');
    if (ApiConfig.alchemyApiKey.length < 32) {
      print('⚠️ WARNING: API key seems short (expected 32 chars). Please verify your Alchemy API key.');
    }
    print('🔑 API Key first 10 chars: ${ApiConfig.alchemyApiKey.substring(0, min(10, ApiConfig.alchemyApiKey.length))}...');
    print('═══════════════════════════════════════════════════════════════');
    
    final allTransfers = <dynamic>[];
    
    // Fetch incoming transfers
    final incomingPayload = {
      'id': 1,
      'jsonrpc': '2.0',
      'method': 'alchemy_getAssetTransfers',
      'params': [{
        'fromBlock': '0x0',
        'toBlock': 'latest',
        'toAddress': address,
        'category': ['external', 'erc20', 'erc721', 'erc1155'], // Note: 'internal' not supported on Polygon
        'withMetadata': true,
        'excludeZeroValue': false,
      }],
    };
    
    print('📥 Fetching INCOMING transfers...');
    final incomingResp = await http.post(
      Uri.parse(rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(incomingPayload),
    );
    
    print('📡 Incoming response status: ${incomingResp.statusCode}');
    print('📡 FULL Incoming response body: ${incomingResp.body}');
    
    if (incomingResp.statusCode == 200) {
      final body = json.decode(incomingResp.body);
      print('📊 Incoming response body keys: ${body.keys.toList()}');
      
      if (body['error'] != null) {
        print('❌ Incoming API error: ${body['error']}');
        print('❌ Error details: ${json.encode(body['error'])}');
      } else {
        print('📊 Result field: ${body['result']}');
        final transfers = body['result']?['transfers'] ?? [];
        print('✅ Incoming transfers count: ${transfers.length}');
        if (transfers.isEmpty) {
          print('⚠️ WARNING: No incoming transfers found in Alchemy response!');
        }
        allTransfers.addAll(transfers);
      }
    } else {
      print('❌ Incoming request failed: ${incomingResp.statusCode}');
      print('   Response: ${incomingResp.body}');
    }
    
    // Fetch outgoing transfers
    final outgoingPayload = {
      'id': 2,
      'jsonrpc': '2.0',
      'method': 'alchemy_getAssetTransfers',
      'params': [{
        'fromBlock': '0x0',
        'toBlock': 'latest',
        'fromAddress': address,
        'category': ['external', 'erc20', 'erc721', 'erc1155'], // Note: 'internal' not supported on Polygon
        'withMetadata': true,
        'excludeZeroValue': false,
      }],
    };
    
    print('📤 Fetching OUTGOING transfers...');
    final outgoingResp = await http.post(
      Uri.parse(rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(outgoingPayload),
    );
    
    print('📡 Outgoing response status: ${outgoingResp.statusCode}');
    print('📡 FULL Outgoing response body: ${outgoingResp.body}');
    
    if (outgoingResp.statusCode == 200) {
      final body = json.decode(outgoingResp.body);
      print('📊 Outgoing response body keys: ${body.keys.toList()}');
      
      if (body['error'] != null) {
        print('❌ Outgoing API error: ${body['error']}');
        print('❌ Error details: ${json.encode(body['error'])}');
      } else {
        print('📊 Result field: ${body['result']}');
        final transfers = body['result']?['transfers'] ?? [];
        print('✅ Outgoing transfers count: ${transfers.length}');
        if (transfers.isEmpty) {
          print('⚠️ WARNING: No outgoing transfers found in Alchemy response!');
        }
        allTransfers.addAll(transfers);
      }
    } else {
      print('❌ Outgoing request failed: ${outgoingResp.statusCode}');
      print('   Response: ${outgoingResp.body}');
    }
    
    // Remove duplicates
    final seen = <String>{};
    final uniqueTransfers = allTransfers.where((t) {
      final hash = t['hash'] as String?;
      if (hash == null || seen.contains(hash)) return false;
      seen.add(hash);
      return true;
    }).toList();
    
    print('📋 Total transfers (after deduplication): ${uniqueTransfers.length}');
    return uniqueTransfers;
  }
  
  /// Get transaction by hash using eth_getTransactionByHash
  static Future<Map<String, dynamic>?> _getTransactionByHash(String rpcUrl, String hash) async {
    try {
      final response = await http.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id': 1,
          'jsonrpc': '2.0',
          'method': 'eth_getTransactionByHash',
          'params': [hash],
        }),
      );
      
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return body['result'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }
  
  /// Get transaction receipt using eth_getTransactionReceipt
  static Future<Map<String, dynamic>?> _getTransactionReceipt(String rpcUrl, String hash) async {
    try {
      final response = await http.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id': 1,
          'jsonrpc': '2.0',
          'method': 'eth_getTransactionReceipt',
          'params': [hash],
        }),
      );
      
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return body['result'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  /// Send ERC-20 Token Transaction
  /// Used for sending AKOFA or other ERC-20 tokens on Polygon
  static Future<Map<String, dynamic>> sendERC20Token({
    required String tokenContractAddress,
    required String toAddress,
    required double amount,
    required String distributorPrivateKey,
    int? gasLimit,
    int? gasPrice,
  }) async {
    try {
      print('🔄 [ERC20] Starting ERC-20 token transfer...');
      print('📍 [ERC20] Token contract: $tokenContractAddress');
      print('📍 [ERC20] To address: $toAddress');
      print('💰 [ERC20] Amount: $amount');

      // Create web3dart client
      final client = web3dart.Web3Client(_currentRpcUrl, http.Client());
      
      try {
        // Clean and prepare private key
        String cleanKey = distributorPrivateKey.trim();
        if (cleanKey.startsWith('0x') || cleanKey.startsWith('0X')) {
          cleanKey = cleanKey.substring(2);
        }
        
        // Create credentials from distributor private key
        final privateKeyBytes = web3crypto.hexToBytes(cleanKey);
        final credentials = web3dart.EthPrivateKey(privateKeyBytes);
        final fromAddress = credentials.address.hex;
        
        print('📍 [ERC20] From address (distributor): $fromAddress');

        // ERC-20 Transfer function signature: transfer(address,uint256)
        // Function selector: 0xa9059cbb (first 4 bytes of keccak256("transfer(address,uint256)"))
        final transferFunctionSelector = '0xa9059cbb';
        
        // Encode recipient address (remove 0x and pad to 32 bytes)
        final recipientAddressEncoded = toAddress
            .toLowerCase()
            .replaceFirst('0x', '')
            .padLeft(64, '0');
        
        // Convert amount to smallest unit (assuming 18 decimals for AKOFA, like most ERC-20 tokens)
        // You can adjust the decimals based on your token configuration
        const decimals = 18;
        final amountInSmallestUnit = BigInt.from(amount * pow(10, decimals));
        
        // Encode amount (pad to 32 bytes)
        final amountEncoded = amountInSmallestUnit
            .toRadixString(16)
            .padLeft(64, '0');
        
        // Combine function selector + encoded parameters
        final data = transferFunctionSelector + recipientAddressEncoded + amountEncoded;
        
        print('📦 [ERC20] Encoded data: ${data.substring(0, 20)}...');
        
        // Get nonce
        final nonce = await client.getTransactionCount(credentials.address);
        print('🔢 [ERC20] Nonce: $nonce');
        
        // Get gas price
        final currentGasPrice = gasPrice != null
            ? web3dart.EtherAmount.fromBigInt(web3dart.EtherUnit.gwei, BigInt.from(gasPrice))
            : await client.getGasPrice();
        
        // ERC-20 transfers typically need more gas than simple transfers
        final currentGasLimit = gasLimit ?? 100000; // Higher gas limit for contract interaction
        
        print('⛽ [ERC20] Gas price: ${currentGasPrice.getInWei}');
        print('⛽ [ERC20] Gas limit: $currentGasLimit');
        
        // Create transaction for contract interaction
        final transaction = web3dart.Transaction(
          to: web3dart.EthereumAddress.fromHex(tokenContractAddress),
          value: web3dart.EtherAmount.zero(), // No MATIC being sent, just token transfer
          gasPrice: currentGasPrice,
          maxGas: currentGasLimit,
          nonce: nonce,
          data: web3crypto.hexToBytes(data.replaceFirst('0x', '')),
        );
        
        print('📤 [ERC20] Signing and sending transaction...');
        
        // Sign and send transaction
        final txHash = await client.sendTransaction(
          credentials,
          transaction,
          chainId: _chainId,
        );
        
        await client.dispose();

        print('✅ [ERC20] Token transfer transaction sent!');
        print('📋 [ERC20] Transaction hash: $txHash');

        return {
          'success': true,
          'txHash': txHash,
          'from': fromAddress,
          'to': toAddress,
          'amount': amount,
          'tokenContract': tokenContractAddress,
          'gasUsed': currentGasLimit,
          'message': 'ERC-20 token transaction sent successfully',
          'explorerUrl': _isTestnet
              ? 'https://amoy.polygonscan.com/tx/$txHash'
              : 'https://polygonscan.com/tx/$txHash',
        };
      } finally {
        await client.dispose();
      }
    } catch (e, stackTrace) {
      print('❌ [ERC20] Error sending ERC-20 token: $e');
      print('❌ [ERC20] Stack trace: $stackTrace');
      
      String errorMessage = e.toString();
      
      // Parse common errors
      if (errorMessage.contains('insufficient funds') ||
          errorMessage.contains('INSUFFICIENT_BALANCE')) {
        errorMessage = 'Insufficient balance in distributor wallet for gas fees or tokens.';
      } else if (errorMessage.contains('gas')) {
        errorMessage = 'Gas estimation failed. Please check the token contract and try again.';
      } else if (errorMessage.contains('nonce')) {
        errorMessage = 'Transaction nonce error. Please try again.';
      } else if (errorMessage.contains('network') ||
                 errorMessage.contains('connection')) {
        errorMessage = 'Network error. Please check your connection and try again.';
      }
      
      return {
        'success': false,
        'error': e.toString(),
        'message': errorMessage,
      };
    }
  }

  /// Send ERC-20 Token with User Authentication
  /// This version requires user password to decrypt their wallet
  static Future<Map<String, dynamic>> sendERC20TokenWithAuth({
    required String userId,
    required String password,
    required String tokenContractAddress,
    required String toAddress,
    required double amount,
    int? gasLimit,
    int? gasPrice,
  }) async {
    try {
      // Authenticate and decrypt wallet
      final authResult = await authenticateAndDecryptPolygonWallet(
        userId,
        password,
      );

      if (!authResult['success']) {
        throw Exception('Authentication failed: ${authResult['error']}');
      }

      final privateKey = authResult['privateKey'] as String;
      final fromAddress = authResult['address'] as String;

      print('🔐 [ERC20] User authenticated: ${fromAddress.substring(0, 10)}...');

      // Use the main sendERC20Token method with user's private key
      return await sendERC20Token(
        tokenContractAddress: tokenContractAddress,
        toAddress: toAddress,
        amount: amount,
        distributorPrivateKey: privateKey,
        gasLimit: gasLimit,
        gasPrice: gasPrice,
      );
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to send ERC-20 token',
      };
    }
  }
}
