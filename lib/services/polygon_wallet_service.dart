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

  /// Fee wallet address - receives USDT/USDC fees for MATIC top-ups
  /// If null, will use distributor wallet address (derived from distributor private key)
  /// Set this to a specific address if you want fees to go to a separate wallet
  static String? feeWalletAddress;

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

      // ===== POST-ENCRYPTION VERIFICATION =====
      print('═══════════════════════════════════════════════════════════════');
      print('🔍 [VERIFY] POST-ENCRYPTION VERIFICATION');
      print('═══════════════════════════════════════════════════════════════');
      
      // Verify we can decrypt and get the same private key back
      final decryptedPrivateKey = await service._decryptPrivateKey(
        password,
        encryptedPrivateKey,
      );
      
      if (decryptedPrivateKey != privateKey) {
        throw Exception('Encryption verification failed: Decrypted key does not match original');
      }
      print('✅ [VERIFY] Private key encryption/decryption verified');
      
      // Verify the decrypted private key derives to the same address
      String cleanKey = decryptedPrivateKey.trim();
      if (cleanKey.startsWith('0x') || cleanKey.startsWith('0X')) {
        cleanKey = cleanKey.substring(2);
      }
      final privateKeyBytes = web3crypto.hexToBytes(cleanKey);
      final credentials = web3dart.EthPrivateKey(privateKeyBytes);
      final derivedAddress = credentials.address.hex;
      
      if (derivedAddress.toLowerCase() != address.toLowerCase()) {
        throw Exception(
          'Address derivation verification failed!\n'
          'Generated address: $address\n'
          'Derived from encrypted key: $derivedAddress'
        );
      }
      print('✅ [VERIFY] Decrypted key derives to correct address: $derivedAddress');
      print('✅ [VERIFY] All verification checks passed!');
      print('═══════════════════════════════════════════════════════════════');

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
        'address': address, // This MUST match what private key derives to
        'encryptedPrivateKey': encryptedPrivateKey,
        'encryptedRecoveryPhrase': encryptedRecoveryPhrase,
        'createdAt': FieldValue.serverTimestamp(),
        'lastAccessed': FieldValue.serverTimestamp(),
        'version': '1.0',
        'network': _isTestnet ? 'polygon-amoy' : 'polygon-mainnet',
        'chainId': _chainId,
        'walletType': 'polygon',
        'setupComplete': true,
        'verified': true, // Indicates wallet passed post-encryption verification
        'verificationTimestamp': FieldValue.serverTimestamp(),
      };

      print('💾 [STORE] Storing wallet data to Firestore...');
      print('   Address: $address');
      print('   Network: ${_isTestnet ? 'Polygon Amoy' : 'Polygon Mainnet'}');
      print('   Chain ID: $_chainId');

      await _firestore
          .collection('polygon_wallets')
          .doc(userId)
          .set(walletData);

      print('✅ [STORE] Wallet data stored in polygon_wallets collection');

      // Update USER collection with Polygon wallet address
      await _firestore.collection('USER').doc(userId).update({
        'polygonAddress': address,
        'hasPolygonWallet': true,
        'polygonWalletCreated': true,
        'lastWalletUpdate': FieldValue.serverTimestamp(),
      });

      print('✅ [STORE] User document updated with Polygon address');
      print('═══════════════════════════════════════════════════════════════');
      print('✅ Secure Polygon wallet created and encrypted successfully');
      print('✅ All verification checks passed - wallet is CONSISTENT');
      print('═══════════════════════════════════════════════════════════════');

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

      // CRITICAL: Derive address from the decrypted key
      // The derived address is the AUTHORITATIVE source of truth
      print('═══════════════════════════════════════════════════════════════');
      print('🔍 [AUTH] DERIVING ADDRESS FROM DECRYPTED KEY (CRITICAL)');
      print('═══════════════════════════════════════════════════════════════');
      
      String derivedAddress;
      try {
        derivedAddress = _deriveAddressFromPrivateKey(privateKey);
        print('✅ [AUTH] Address derived from decrypted key: $derivedAddress');
        
        // Compare addresses (case-insensitive)
        final storedAddressLower = storedAddress.toLowerCase();
        final derivedAddressLower = derivedAddress.toLowerCase();
        
        print('🔍 [AUTH] Address comparison:');
        print('    Stored in DB:  $storedAddressLower');
        print('    Derived from key: $derivedAddressLower');
        
        if (derivedAddressLower != storedAddressLower) {
          print('⚠️⚠️⚠️ [AUTH] CRITICAL: Address mismatch detected!');
          print('    The stored address does not match the private key!');
          print('    This means the database has corrupted/incorrect data.');
          print('🔧 [AUTH] AUTO-FIXING: Updating database with correct address...');
          
          try {
            await _firestore.collection('polygon_wallets').doc(userId).update({
              'address': derivedAddress,
              'lastAccessed': FieldValue.serverTimestamp(),
              'addressCorrected': true,
              'previousAddress': storedAddress,
              'correctionTimestamp': FieldValue.serverTimestamp(),
            });
            
            await _firestore.collection('USER').doc(userId).update({
              'polygonAddress': derivedAddress,
              'lastWalletUpdate': FieldValue.serverTimestamp(),
            });
            
            print('✅ [AUTH] Database updated with correct address: $derivedAddress');
            
            // CRITICAL: Update AKOFA tag to point to the derived address
            try {
              print('🏷️ [AUTH] Updating AKOFA tag to point to corrected address...');
              
              // Get user's AKOFA tag
              final userDoc = await _firestore.collection('USER').doc(userId).get();
              final akofaTag = userDoc.data()?['akofaTag'] as String?;
              
              if (akofaTag != null && akofaTag.isNotEmpty) {
                // Update the tag to point to the derived address
                final tagDoc = await _firestore.collection('akofaTag').doc(akofaTag).get();
                if (tagDoc.exists) {
                  final tagData = tagDoc.data()!;
                  final addresses = Map<String, dynamic>.from(tagData['addresses'] ?? {});
                  
                  // Update Polygon address to the derived one
                  addresses['polygon'] = {
                    'address': derivedAddress,
                    'linkedAt': FieldValue.serverTimestamp(),
                    'isActive': true,
                    'corrected': true,
                    'previousAddress': storedAddress,
                  };
                  
                  await _firestore.collection('akofaTag').doc(akofaTag).update({
                    'addresses': addresses,
                    'lastUpdated': FieldValue.serverTimestamp(),
                  });
                  
                  print('✅ [AUTH] AKOFA tag "$akofaTag" updated to resolve to: $derivedAddress');
                  print('📋 [AUTH] Old address was: $storedAddress');
                } else {
                  print('⚠️ [AUTH] AKOFA tag document not found: $akofaTag');
                }
              } else {
                print('ℹ️ [AUTH] No AKOFA tag found for user');
              }
            } catch (tagError) {
              print('⚠️ [AUTH] Failed to update AKOFA tag (non-critical): $tagError');
            }
            
            print('⚠️ [AUTH] IMPORTANT: If you had tokens at $storedAddress,');
            print('    you need to transfer them to the new address: $derivedAddress');
          } catch (updateError) {
            print('❌ [AUTH] Failed to update database: $updateError');
          }
        } else {
          print('✅ [AUTH] Addresses match perfectly! Database is consistent.');
        }
        
      } catch (e) {
        print('❌ [AUTH] CRITICAL: Could not derive address from private key: $e');
        throw Exception('Failed to derive address from private key. Wallet may be corrupted.');
      }

      // Update last accessed timestamp
      print('📝 [AUTH] Updating last accessed timestamp...');
      await _firestore.collection('polygon_wallets').doc(userId).update({
        'lastAccessed': FieldValue.serverTimestamp(),
      });
      
      // Ensure AKOFA tag is linked to the correct address (periodic check)
      try {
        final userDoc = await _firestore.collection('USER').doc(userId).get();
        final akofaTag = userDoc.data()?['akofaTag'] as String?;
        
        if (akofaTag != null && akofaTag.isNotEmpty) {
          final tagDoc = await _firestore.collection('akofaTag').doc(akofaTag).get();
          if (tagDoc.exists) {
            final tagData = tagDoc.data()!;
            final addresses = Map<String, dynamic>.from(tagData['addresses'] ?? {});
            final polygonData = addresses['polygon'] as Map<String, dynamic>?;
            final linkedAddress = polygonData?['address'] as String?;
            
            // Check if tag is linked to the correct derived address
            if (linkedAddress == null || linkedAddress.toLowerCase() != derivedAddress.toLowerCase()) {
              print('🔧 [AUTH] AKOFA tag linked to wrong address, updating...');
              print('   Tag: $akofaTag');
              print('   Current linked: ${linkedAddress ?? "none"}');
              print('   Should be: $derivedAddress');
              
              addresses['polygon'] = {
                'address': derivedAddress,
                'linkedAt': FieldValue.serverTimestamp(),
                'isActive': true,
                'autoUpdated': true,
              };
              
              await _firestore.collection('akofaTag').doc(akofaTag).update({
                'addresses': addresses,
                'lastUpdated': FieldValue.serverTimestamp(),
              });
              
              print('✅ [AUTH] AKOFA tag auto-updated to correct address');
            } else {
              print('✅ [AUTH] AKOFA tag correctly linked to: $derivedAddress');
            }
          }
        }
      } catch (tagCheckError) {
        print('⚠️ [AUTH] AKOFA tag check failed (non-critical): $tagCheckError');
      }

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

      // ALWAYS return derived address as the authoritative address
      final addressToUse = derivedAddress;
      
      print('═══════════════════════════════════════════════════════════════');
      print('✅ [AUTH] WALLET DECRYPTION COMPLETED SUCCESSFULLY');
      print('═══════════════════════════════════════════════════════════════');
      print('📍 [AUTH] Returning decrypted credentials:');
      print('    ✅ Authoritative address (from key): $addressToUse');
      print('    🔑 Decrypted private key: ${privateKey.substring(0, 10)}...');
      print('    📝 Previously stored address: $storedAddress');
      print('    🔍 Addresses match: ${addressToUse.toLowerCase() == storedAddress.toLowerCase()}');
      print('═══════════════════════════════════════════════════════════════');
      
      return {
        'success': true,
        'address': addressToUse,  // ALWAYS use derived address (authoritative source of truth)
        'privateKey': privateKey,  // The decrypted private key
        'storedAddress': storedAddress,  // Previous stored address (for reference)
        'addressesMatch': addressToUse.toLowerCase() == storedAddress.toLowerCase(),
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

  /// Get the authoritative (derived) Polygon wallet address
  /// This verifies the address matches the private key and updates DB if needed
  /// Requires password for decryption but ensures correct address is returned
  static Future<String?> getDerivedWalletAddress({
    required String userId,
    required String password,
  }) async {
    try {
      print('🔍 [DERIVED] Getting derived wallet address for user: $userId');
      
      // Authenticate and get the derived address
      final result = await authenticateAndDecryptPolygonWallet(
        userId,
        password,
      );
      
      if (result['success'] == true) {
        final derivedAddress = result['address'] as String?;
        print('✅ [DERIVED] Derived address: $derivedAddress');
        return derivedAddress;
      } else {
        print('❌ [DERIVED] Failed to derive address: ${result['error']}');
        return null;
      }
    } catch (e) {
      print('❌ [DERIVED] Error getting derived address: $e');
      return null;
    }
  }

  /// Get the correct wallet address - first tries stored, then validates if needed
  /// This is a non-authenticated method that tries to use the stored address
  /// but falls back to the USER collection if needed
  static Future<String?> getCorrectWalletAddress(String userId) async {
    try {
      // First check polygon_wallets collection
      final walletDoc = await _firestore
          .collection('polygon_wallets')
          .doc(userId)
          .get();
      
      if (walletDoc.exists) {
        final data = walletDoc.data();
        final address = data?['address'] as String?;
        final addressCorrected = data?['addressCorrected'] == true;
        
        // If the address was previously corrected, it should be the derived one
        if (address != null && addressCorrected) {
          print('✅ [ADDRESS] Using corrected address from DB: $address');
          return address;
        }
        
        // If not corrected, still return it but log a warning
        if (address != null) {
          print('⚠️ [ADDRESS] Using uncorrected address from DB: $address');
          print('   This address will be verified/corrected on next transaction');
          return address;
        }
      }
      
      // Fallback to USER collection
      final userDoc = await _firestore.collection('USER').doc(userId).get();
      final address = userDoc.data()?['polygonAddress'] as String?;
      
      if (address != null) {
        print('ℹ️ [ADDRESS] Using address from USER collection: $address');
      }
      
      return address;
    } catch (e) {
      print('❌ [ADDRESS] Error getting wallet address: $e');
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
        '0xc2132D05D31c914a87C6611C10748AEb04B58e8F', // USDT
        '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359', // USDC (native)
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

      // Create web3dart client for gas estimation
      final client = web3dart.Web3Client(_currentRpcUrl, http.Client());
      
      try {
        // Get gas price and estimate gas fee
        final currentGasPrice = gasPrice != null
            ? web3dart.EtherAmount.fromBigInt(web3dart.EtherUnit.gwei, BigInt.from(gasPrice))
            : await client.getGasPrice();
        final currentGasLimit = gasLimit ?? 21000;
        
        // Calculate gas fee
        final gasFeeWei = currentGasPrice.getInWei * BigInt.from(currentGasLimit);
        final gasFeeMatic = gasFeeWei.toDouble() / 1e18;
        
        // Calculate total required (amount + gas)
        final totalRequired = amountMatic + gasFeeMatic;
        
        print('⛽ [MATIC TX] Estimated gas fee: $gasFeeMatic MATIC');
        print('💰 [MATIC TX] Total required: $totalRequired MATIC (amount: $amountMatic + gas: $gasFeeMatic)');
        
        // Check and ensure sufficient MATIC for gas (will charge fee if needed)
        final maticCheck = await ensureSufficientMaticForGas(
          userAddress: fromAddress,
          requiredGasFee: totalRequired,
          userId: userId,
          password: password,
        );
        
        if (!maticCheck['success']) {
          throw Exception('Failed to ensure sufficient MATIC: ${maticCheck['error']}');
        }
        
        if (maticCheck['toppedUp'] == true) {
          print('✅ [MATIC TX] MATIC topped up successfully, proceeding with transaction');
        }
        
        // Convert amount to wei
        final amountWei = BigInt.from(amountMatic * 1e18);
        
        // Create credentials from private key
        final privateKeyBytes = web3crypto.hexToBytes(
          privateKey.startsWith('0x') ? privateKey.substring(2) : privateKey,
        );
        final credentials = web3dart.EthPrivateKey(privateKeyBytes);
        
        // Get nonce (may have changed if we topped up)
        final nonce = await client.getTransactionCount(credentials.address);
        
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
          'maticToppedUp': maticCheck['toppedUp'] ?? false,
          'topUpTxHash': maticCheck['topUpTxHash'],
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
    String? toAddress,
    double? amount,
  }) async {
    try {
      final client = web3dart.Web3Client(_currentRpcUrl, http.Client());
      
      try {
        // Get current gas price
        final gasPrice = await client.getGasPrice();
        
        int gasLimit = 100000; // Default fallback
        
        // Try to estimate actual gas if we have transaction details
        if (toAddress != null && amount != null) {
          try {
            // Create a dummy transaction to estimate gas
            final contract = web3dart.DeployedContract(
              web3dart.ContractAbi.fromJson(json.encode([
                {
                  'constant': false,
                  'inputs': [
                    {'name': '_to', 'type': 'address'},
                    {'name': '_value', 'type': 'uint256'}
                  ],
                  'name': 'transfer',
                  'outputs': [
                    {'name': '', 'type': 'bool'}
                  ],
                  'type': 'function'
                },
                {
                  'constant': true,
                  'inputs': [],
                  'name': 'decimals',
                  'outputs': [
                    {'name': '', 'type': 'uint8'}
                  ],
                  'type': 'function'
                },
              ]), ''),
              web3dart.EthereumAddress.fromHex(tokenContractAddress),
            );
            
            // Get token decimals
            final decimalsFunction = contract.function('decimals');
            final decimalsResult = await client.call(
              contract: contract,
              function: decimalsFunction,
              params: [],
            );
            final decimals = (decimalsResult[0] as BigInt).toInt();
            
            // Encode transfer function
            final transferFunction = contract.function('transfer');
            final amountInUnits = BigInt.from(amount * pow(10, decimals));
            final data = transferFunction.encodeCall([
              web3dart.EthereumAddress.fromHex(toAddress),
              amountInUnits,
            ]);
            
            // Estimate gas
            final estimatedGas = await client.estimateGas(
              sender: web3dart.EthereumAddress.fromHex(fromAddress),
              to: web3dart.EthereumAddress.fromHex(tokenContractAddress),
              data: data,
            );
            
            // Add 20% buffer for safety
            gasLimit = (estimatedGas.toInt() * 1.2).round();
            print('⛽ [ERC20 GAS] Estimated gas: ${estimatedGas.toInt()}, using: $gasLimit (with 20% buffer)');
          } catch (e) {
            print('⚠️ [ERC20 GAS] Could not estimate gas, using default: $e');
            // Fall back to default gas limit
          }
        }
        
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

  /// Get USDT or USDC balance for a user address
  static Future<Map<String, dynamic>> getStablecoinBalance({
    required String userAddress,
    required String tokenSymbol, // 'USDT' or 'USDC'
  }) async {
    try {
      // Contract addresses for USDT and USDC on Polygon
      final contractAddresses = {
        'USDT': '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
        'USDC': '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359',
      };
      
      final decimals = {
        'USDT': 6,
        'USDC': 6,
      };
      
      final contractAddress = contractAddresses[tokenSymbol.toUpperCase()];
      if (contractAddress == null) {
        return {
          'success': false,
          'error': 'Unsupported token: $tokenSymbol',
          'balance': 0.0,
        };
      }
      
      final client = web3dart.Web3Client(_currentRpcUrl, http.Client());
      
      try {
        final contract = web3dart.DeployedContract(
          web3dart.ContractAbi.fromJson(_erc20ABI, 'ERC20'),
          web3dart.EthereumAddress.fromHex(contractAddress),
        );
        
        final balanceFn = contract.function('balanceOf');
        final userAddressEth = web3dart.EthereumAddress.fromHex(userAddress);
        
        final balanceResult = await client.call(
          contract: contract,
          function: balanceFn,
          params: [userAddressEth],
        );
        
        final balanceWei = balanceResult[0] as BigInt;
        final tokenDecimals = decimals[tokenSymbol.toUpperCase()] ?? 6;
        final divisor = BigInt.from(10).pow(tokenDecimals);
        final balance = balanceWei.toDouble() / divisor.toDouble();
        
        return {
          'success': true,
          'balance': balance,
          'symbol': tokenSymbol.toUpperCase(),
          'contractAddress': contractAddress,
        };
      } finally {
        await client.dispose();
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'balance': 0.0,
      };
    }
  }

  /// Calculate fee for MATIC top-up (10% more than MATIC value + gas cost in USDT/USDC)
  /// Includes the cost of sending MATIC to the user
  static double calculateMaticTopUpFee({
    required double maticAmount,
    required double gasCostForMaticTransfer, // Gas cost for sending MATIC to user
  }) {
    // Total cost = MATIC amount + gas cost for sending MATIC
    final totalCost = maticAmount + gasCostForMaticTransfer;
    // Fee is 10% more than total cost
    return totalCost * 1.1;
  }

  /// Charge fee from user's USDT or USDC balance
  /// Note: This function sends MATIC first to cover gas, then charges the fee
  static Future<Map<String, dynamic>> chargeMaticTopUpFee({
    required String userId,
    required String password,
    required String userAddress,
    required double feeAmount,
    required String feeTokenSymbol, // 'USDT' or 'USDC'
    required String distributorPrivateKey, // Need distributor key to send MATIC for gas
    String? feeWalletAddress,
  }) async {
    try {
      print('💳 [FEE] Charging fee for MATIC top-up...');
      print('💰 [FEE] Fee amount: $feeAmount $feeTokenSymbol');
      print('📍 [FEE] User address: $userAddress');

      // First, estimate gas for the fee transaction
      final contractAddresses = {
        'USDT': '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
        'USDC': '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359',
      };
      
      final contractAddress = contractAddresses[feeTokenSymbol.toUpperCase()];
      if (contractAddress == null) {
        throw Exception('Unsupported fee token: $feeTokenSymbol');
      }

      // Estimate gas for fee transaction
      final gasEstimate = await estimateERC20GasFee(
        fromAddress: userAddress,
        tokenContractAddress: contractAddress,
        toAddress: feeWalletAddress,
        amount: feeAmount,
      );

      if (gasEstimate['success'] != true) {
        throw Exception('Failed to estimate gas for fee transaction: ${gasEstimate['error']}');
      }

      final feeGasRequired = gasEstimate['gasFee'] as double;
      print('⛽ [FEE] Gas required for fee transaction: $feeGasRequired MATIC');

      // Check if user has MATIC for fee transaction gas
      final balanceResult = await getPolygonBalance(userAddress);
      final currentMaticBalance = balanceResult['balance'] as double? ?? 0.0;

      // If user doesn't have enough MATIC for the fee transaction, send it first
      if (currentMaticBalance < feeGasRequired) {
        final maticNeeded = feeGasRequired - currentMaticBalance;
        final maticToSend = maticNeeded * 1.1; // 10% buffer
        
        print('⚠️ [FEE] User needs MATIC for fee transaction. Sending $maticToSend MATIC...');
        
        final maticResult = await sendMaticFromDistributor(
          toAddress: userAddress,
          amountMatic: maticToSend,
          distributorPrivateKey: distributorPrivateKey,
        );

        if (maticResult['success'] != true) {
          throw Exception('Failed to send MATIC for fee transaction: ${maticResult['error']}');
        }

        // Wait for MATIC to be available
        await Future.delayed(const Duration(seconds: 2));
        print('✅ [FEE] MATIC sent for fee transaction gas');
      }

      // Determine fee wallet address
      // Priority: 1) Parameter feeWalletAddress, 2) Static feeWalletAddress, 3) Distributor wallet
      String feeWallet;
      
      if (feeWalletAddress != null && feeWalletAddress!.isNotEmpty) {
        // Use parameter fee wallet address (highest priority)
        feeWallet = feeWalletAddress!;
        print('📍 [FEE] Using parameter fee wallet: $feeWallet');
      } else if (PolygonWalletService.feeWalletAddress != null && 
                 PolygonWalletService.feeWalletAddress!.isNotEmpty) {
        // Use configured static fee wallet address
        feeWallet = PolygonWalletService.feeWalletAddress!;
        print('📍 [FEE] Using configured fee wallet: $feeWallet');
      } else {
        // Use distributor wallet as fee wallet (derive from private key)
        String cleanKey = distributorPrivateKey.trim();
        if (cleanKey.startsWith('0x') || cleanKey.startsWith('0X')) {
          cleanKey = cleanKey.substring(2);
        }
        final privateKeyBytes = web3crypto.hexToBytes(cleanKey);
        final credentials = web3dart.EthPrivateKey(privateKeyBytes);
        feeWallet = credentials.address.hex;
        print('📍 [FEE] Using distributor wallet as fee wallet: $feeWallet');
      }
      
      print('📍 [FEE] Fee wallet: $feeWallet');

      // Now transfer fee from user to fee wallet using sendERC20TokenWithAuth
      // This should work now since we've ensured user has MATIC for gas
      final feeResult = await sendERC20TokenWithAuth(
        userId: userId,
        password: password,
        tokenContractAddress: contractAddress,
        toAddress: feeWallet,
        amount: feeAmount,
      );

      if (feeResult['success'] == true) {
        print('✅ [FEE] Successfully charged fee: $feeAmount $feeTokenSymbol');
        print('📋 [FEE] Transaction hash: ${feeResult['txHash']}');
        
        return {
          'success': true,
          'feeAmount': feeAmount,
          'feeToken': feeTokenSymbol.toUpperCase(),
          'feeTxHash': feeResult['txHash'],
          'feeWallet': feeWallet,
          'message': 'Fee charged successfully',
        };
      } else {
        throw Exception('Failed to charge fee: ${feeResult['error']}');
      }
    } catch (e, stackTrace) {
      print('❌ [FEE] Error charging fee: $e');
      print('❌ [FEE] Stack trace: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to charge fee',
      };
    }
  }

  /// Check if user has enough MATIC for gas and top-up from distributor if needed
  /// Charges fee in USDT/USDC (10% more than MATIC value) before sending MATIC
  static Future<Map<String, dynamic>> ensureSufficientMaticForGas({
    required String userAddress,
    required double requiredGasFee,
    String? userId,
    String? password,
    String? distributorPrivateKey,
  }) async {
    try {
      print('🔍 [MATIC TOP-UP] Checking MATIC balance for gas fees...');
      print('📍 [MATIC TOP-UP] User address: $userAddress');
      print('⛽ [MATIC TOP-UP] Required gas fee: $requiredGasFee MATIC');

      // Get user's current MATIC balance
      final balanceResult = await getPolygonBalance(userAddress);
      final currentBalance = balanceResult['balance'] as double? ?? 0.0;
      
      print('💰 [MATIC TOP-UP] Current balance: $currentBalance MATIC');

      // Check if user has enough MATIC
      if (currentBalance >= requiredGasFee) {
        print('✅ [MATIC TOP-UP] User has sufficient MATIC for gas');
        return {
          'success': true,
          'toppedUp': false,
          'currentBalance': currentBalance,
          'requiredGasFee': requiredGasFee,
          'message': 'User has sufficient MATIC',
        };
      }

      // User doesn't have enough MATIC - need to top-up
      final insufficientAmount = requiredGasFee - currentBalance;
      // Add a small buffer (10% extra) to ensure transaction goes through
      final topUpAmount = insufficientAmount * 1.1;
      
      print('⚠️ [MATIC TOP-UP] Insufficient MATIC. Need to top-up: $topUpAmount MATIC');

      // Estimate gas cost for sending MATIC to user (simple MATIC transfer)
      final client = web3dart.Web3Client(_currentRpcUrl, http.Client());
      double gasCostForMaticTransfer = 0.0;
      try {
        final gasPrice = await client.getGasPrice();
        const gasLimit = 21000; // Standard for MATIC transfer
        final gasFeeWei = gasPrice.getInWei * BigInt.from(gasLimit);
        gasCostForMaticTransfer = gasFeeWei.toDouble() / 1e18;
        print('⛽ [MATIC TOP-UP] Gas cost for sending MATIC: $gasCostForMaticTransfer MATIC');
      } catch (e) {
        print('⚠️ [MATIC TOP-UP] Could not estimate gas, using default: $e');
        // Use a conservative estimate (0.01 MATIC)
        gasCostForMaticTransfer = 0.01;
      } finally {
        await client.dispose();
      }

      // Calculate fee (10% more than MATIC value + gas cost in USDT/USDC)
      final feeAmount = calculateMaticTopUpFee(
        maticAmount: topUpAmount,
        gasCostForMaticTransfer: gasCostForMaticTransfer,
      );
      print('💳 [MATIC TOP-UP] Fee required: $feeAmount USDT/USDC');
      print('   Breakdown: MATIC ($topUpAmount) + Gas ($gasCostForMaticTransfer) × 1.1 = $feeAmount');

      // Check if user has USDT or USDC to pay the fee
      if (userId == null || password == null) {
        return {
          'success': false,
          'toppedUp': false,
          'error': 'User credentials required to charge fee',
          'message': 'Cannot charge fee without user authentication',
          'requiredFee': feeAmount,
        };
      }

      // Check USDT balance first, then USDC
      String? feeTokenSymbol;
      double? feeTokenBalance;
      
      final usdtBalance = await getStablecoinBalance(
        userAddress: userAddress,
        tokenSymbol: 'USDT',
      );
      
      if (usdtBalance['success'] == true && (usdtBalance['balance'] as double) >= feeAmount) {
        feeTokenSymbol = 'USDT';
        feeTokenBalance = usdtBalance['balance'] as double;
        print('✅ [MATIC TOP-UP] User has sufficient USDT: $feeTokenBalance USDT');
      } else {
        final usdcBalance = await getStablecoinBalance(
          userAddress: userAddress,
          tokenSymbol: 'USDC',
        );
        
        if (usdcBalance['success'] == true && (usdcBalance['balance'] as double) >= feeAmount) {
          feeTokenSymbol = 'USDC';
          feeTokenBalance = usdcBalance['balance'] as double;
          print('✅ [MATIC TOP-UP] User has sufficient USDC: $feeTokenBalance USDC');
        } else {
          final usdtBal = usdtBalance['balance'] as double? ?? 0.0;
          final usdcBal = usdcBalance['balance'] as double? ?? 0.0;
          print('❌ [MATIC TOP-UP] Insufficient USDT/USDC for fee');
          print('   USDT balance: $usdtBal');
          print('   USDC balance: $usdcBal');
          print('   Required fee: $feeAmount');
          
          return {
            'success': false,
            'toppedUp': false,
            'error': 'Insufficient USDT/USDC balance to pay fee',
            'message': 'You need $feeAmount USDT or USDC to pay for MATIC top-up fee',
            'requiredFee': feeAmount,
            'usdtBalance': usdtBal,
            'usdcBalance': usdcBal,
          };
        }
      }

      // Use distributor private key from polygon_mining_service if not provided
      final distributorKey = distributorPrivateKey ??
          'af611eb882635606bdad6e91a011e2658d01378a56654d5b554f9f7cb170a863';

      // Derive distributor address for refund logic
      String cleanKey = distributorKey.trim();
      if (cleanKey.startsWith('0x') || cleanKey.startsWith('0X')) {
        cleanKey = cleanKey.substring(2);
      }
      final distributorAddress =
          web3dart.EthPrivateKey(web3crypto.hexToBytes(cleanKey)).address.hex;

      // Charge the fee before sending MATIC
      print('💳 [MATIC TOP-UP] Charging fee: $feeAmount $feeTokenSymbol');
      final feeResult = await chargeMaticTopUpFee(
        userId: userId,
        password: password,
        userAddress: userAddress,
        feeAmount: feeAmount,
        feeTokenSymbol: feeTokenSymbol!,
        distributorPrivateKey: distributorKey,
      );

      if (feeResult['success'] != true) {
        print('❌ [MATIC TOP-UP] Failed to charge fee: ${feeResult['error']}');
        return {
          'success': false,
          'toppedUp': false,
          'error': feeResult['error'] ?? 'Failed to charge fee',
          'message': 'Failed to charge fee for MATIC top-up',
        };
      }

      print('✅ [MATIC TOP-UP] Fee charged successfully');

      // Send MATIC from distributor wallet (for the actual transaction gas)
      print('🔄 [MATIC TOP-UP] Sending $topUpAmount MATIC from distributor wallet...');
      
      Map<String, dynamic> topUpResult = {};
      int topUpAttempts = 0;
      const maxTopUpAttempts = 2;

      while (topUpAttempts < maxTopUpAttempts) {
        topUpAttempts++;
        topUpResult = await sendMaticFromDistributor(
          toAddress: userAddress,
          amountMatic: topUpAmount,
          distributorPrivateKey: distributorKey,
        );
        if (topUpResult['success'] == true) {
          break;
        }
        await Future.delayed(const Duration(seconds: 2));
      }

      if (topUpResult['success'] == true) {
        print('✅ [MATIC TOP-UP] Successfully topped up $topUpAmount MATIC');
        print('📋 [MATIC TOP-UP] Transaction hash: ${topUpResult['txHash']}');
        
        // Wait a moment for the transaction to be mined
        await Future.delayed(const Duration(seconds: 2));
        
        // Verify the new balance
        final newBalanceResult = await getPolygonBalance(userAddress);
        final newBalance = newBalanceResult['balance'] as double? ?? 0.0;
        print('💰 [MATIC TOP-UP] New balance: $newBalance MATIC');
        
        final result = {
          'success': true,
          'toppedUp': true,
          'topUpAmount': topUpAmount,
          'topUpTxHash': topUpResult['txHash'],
          'previousBalance': currentBalance,
          'currentBalance': newBalance,
          'requiredGasFee': requiredGasFee,
          'feeCharged': feeAmount,
          'feeToken': feeTokenSymbol,
          'feeTxHash': feeResult['feeTxHash'],
          'message': 'Successfully topped up MATIC for gas fees',
          'topUpAttempts': topUpAttempts,
        };
        
        await _logGasSponsorEvent({
          'status': 'success',
          'userId': userId,
          'userAddress': userAddress,
          'requiredGasFee': requiredGasFee,
          'currentBalance': currentBalance,
          'topUpAmount': topUpAmount,
          'topUpTxHash': topUpResult['txHash'],
          'topUpAttempts': topUpAttempts,
          'feeAmount': feeAmount,
          'feeToken': feeTokenSymbol,
          'feeTxHash': feeResult['feeTxHash'],
        });

        return result;
      } else {
        print('❌ [MATIC TOP-UP] Failed to top-up MATIC: ${topUpResult['error']}');
        // Note: Fee was already charged, but MATIC top-up failed
        // Attempt refund when fee wallet is distributor wallet

        bool refundAttempted = false;
        bool refundSuccess = false;
        String? refundTxHash;
        String? refundError;

        final feeWallet = feeResult['feeWallet'] as String?;
        if (feeWallet != null &&
            feeWallet.toLowerCase() == distributorAddress.toLowerCase()) {
          refundAttempted = true;
          final refundTokenContracts = {
            'USDT': '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
            'USDC': '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359',
          };
          final refundContract =
              refundTokenContracts[feeTokenSymbol!.toUpperCase()];
          if (refundContract == null) {
            refundError = 'Unsupported refund token: $feeTokenSymbol';
          } else {
            final refundResult = await sendERC20Token(
              tokenContractAddress: refundContract,
              toAddress: userAddress,
              amount: feeAmount,
              distributorPrivateKey: distributorKey,
            );
            if (refundResult['success'] == true) {
              refundSuccess = true;
              refundTxHash = refundResult['txHash'] as String?;
              print('✅ [MATIC TOP-UP] Fee refunded: $refundTxHash');
            } else {
              refundError =
                  refundResult['error'] ?? refundResult['message'] ?? 'Refund failed';
              print('❌ [MATIC TOP-UP] Fee refund failed: $refundError');
            }
          }
        } else {
          refundAttempted = true;
          refundError =
              'Fee wallet does not match distributor wallet; manual refund required.';
          print('⚠️ [MATIC TOP-UP] $refundError');
        }

        final result = {
          'success': false,
          'toppedUp': false,
          'error': topUpResult['error'] ?? 'Failed to top-up MATIC',
          'message': 'Failed to top-up MATIC from distributor wallet (fee was charged)',
          'feeCharged': feeAmount,
          'feeToken': feeTokenSymbol,
          'feeTxHash': feeResult['feeTxHash'],
          'topUpAttempts': topUpAttempts,
          'refundAttempted': refundAttempted,
          'refundSuccess': refundSuccess,
          'refundTxHash': refundTxHash,
          'refundError': refundError,
        };
        
        await _logGasSponsorEvent({
          'status': 'failed',
          'userId': userId,
          'userAddress': userAddress,
          'requiredGasFee': requiredGasFee,
          'currentBalance': currentBalance,
          'topUpAmount': topUpAmount,
          'topUpAttempts': topUpAttempts,
          'feeAmount': feeAmount,
          'feeToken': feeTokenSymbol,
          'feeTxHash': feeResult['feeTxHash'],
          'topUpError': topUpResult['error'] ?? 'Failed to top-up MATIC',
          'refundAttempted': refundAttempted,
          'refundSuccess': refundSuccess,
          'refundTxHash': refundTxHash,
          'refundError': refundError,
        });

        return result;
      }
    } catch (e, stackTrace) {
      print('❌ [MATIC TOP-UP] Error ensuring sufficient MATIC: $e');
      print('❌ [MATIC TOP-UP] Stack trace: $stackTrace');
      
      await _logGasSponsorEvent({
        'status': 'error',
        'userId': userId,
        'userAddress': userAddress,
        'requiredGasFee': requiredGasFee,
        'error': e.toString(),
      });

      return {
        'success': false,
        'toppedUp': false,
        'error': e.toString(),
        'message': 'Error checking/topping up MATIC balance',
      };
    }
  }

  static Future<void> _logGasSponsorEvent(Map<String, dynamic> data) async {
    try {
      await _firestore.collection('polygon_gas_sponsor_events').add({
        ...data,
        'network': _isTestnet ? 'polygon-amoy' : 'polygon-mainnet',
        'chainId': _chainId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('⚠️ [MATIC TOP-UP] Failed to log gas sponsor event: $e');
    }
  }

  /// Send MATIC from distributor wallet to user wallet
  static Future<Map<String, dynamic>> sendMaticFromDistributor({
    required String toAddress,
    required double amountMatic,
    required String distributorPrivateKey,
  }) async {
    try {
      print('🔄 [DISTRIBUTOR] Sending MATIC from distributor wallet...');
      print('📍 [DISTRIBUTOR] To address: $toAddress');
      print('💰 [DISTRIBUTOR] Amount: $amountMatic MATIC');

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
        
        print('📍 [DISTRIBUTOR] From address (distributor): $fromAddress');

        // Convert amount to wei
        final amountWei = BigInt.from(amountMatic * 1e18);
        
        // Get nonce
        final nonce = await client.getTransactionCount(credentials.address);
        print('🔢 [DISTRIBUTOR] Nonce: $nonce');
        
        // Get gas price
        final gasPrice = await client.getGasPrice();
        const gasLimit = 21000; // Standard for MATIC transfer
        
        print('⛽ [DISTRIBUTOR] Gas price: ${gasPrice.getInWei}');
        print('⛽ [DISTRIBUTOR] Gas limit: $gasLimit');
        
        // Create transaction
        final transaction = web3dart.Transaction(
          to: web3dart.EthereumAddress.fromHex(toAddress),
          value: web3dart.EtherAmount.fromBigInt(web3dart.EtherUnit.wei, amountWei),
          gasPrice: gasPrice,
          maxGas: gasLimit,
          nonce: nonce,
        );
        
        print('📤 [DISTRIBUTOR] Signing and sending transaction...');
        
        // Sign and send transaction
        final txHash = await client.sendTransaction(
          credentials,
          transaction,
          chainId: _chainId,
        );
        
        await client.dispose();

        print('✅ [DISTRIBUTOR] MATIC transfer transaction sent!');
        print('📋 [DISTRIBUTOR] Transaction hash: $txHash');

        return {
          'success': true,
          'txHash': txHash,
          'from': fromAddress,
          'to': toAddress,
          'amount': amountMatic,
          'gasUsed': gasLimit,
          'message': 'MATIC top-up transaction sent successfully',
          'explorerUrl': _isTestnet
              ? 'https://amoy.polygonscan.com/tx/$txHash'
              : 'https://polygonscan.com/tx/$txHash',
        };
      } finally {
        await client.dispose();
      }
    } catch (e, stackTrace) {
      print('❌ [DISTRIBUTOR] Error sending MATIC from distributor: $e');
      print('❌ [DISTRIBUTOR] Stack trace: $stackTrace');
      
      String errorMessage = e.toString();
      
      // Parse common errors
      if (errorMessage.contains('insufficient funds') ||
          errorMessage.contains('INSUFFICIENT_BALANCE')) {
        errorMessage = 'Insufficient balance in distributor wallet. Please contact support.';
      } else if (errorMessage.contains('gas')) {
        errorMessage = 'Gas estimation failed. Please try again.';
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

  /// Check ERC-20 Token Balance for Distribution Account
  /// Used to verify sufficient balance before allowing purchases
  static Future<Map<String, dynamic>> checkDistributorTokenBalance({
    required String tokenContractAddress,
    required String distributorPrivateKey,
    required double requiredAmount,
    required int tokenDecimals,
  }) async {
    try {
      print('🔍 [BALANCE] Checking distributor token balance...');
      print('📋 [BALANCE] Token contract: $tokenContractAddress');
      print('📊 [BALANCE] Required amount: $requiredAmount');

      // Clean and prepare private key
      String cleanKey = distributorPrivateKey.trim();
      if (cleanKey.startsWith('0x') || cleanKey.startsWith('0X')) {
        cleanKey = cleanKey.substring(2);
      }
      
      // Derive address from private key
      final privateKeyBytes = web3crypto.hexToBytes(cleanKey);
      final credentials = web3dart.EthPrivateKey(privateKeyBytes);
      final distributorAddress = credentials.address.hex;
      
      print('📍 [BALANCE] Distributor address: $distributorAddress');

      // Use raw RPC call for more reliable balance checking
      // balanceOf(address) function signature: 0x70a08231
      final addressPadded = distributorAddress.replaceFirst('0x', '').toLowerCase().padLeft(64, '0');
      final data = '0x70a08231$addressPadded';
      
      final response = await http.post(
        Uri.parse(_currentRpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'method': 'eth_call',
          'params': [
            {
              'to': tokenContractAddress,
              'data': data,
            },
            'latest'
          ],
          'id': 1,
        }),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode != 200) {
        print('❌ [BALANCE] RPC error: ${response.statusCode}');
        return {
          'success': false,
          'hasBalance': false,
          'error': 'RPC error: ${response.statusCode}',
        };
      }
      
      final result = json.decode(response.body);
      
      if (result['error'] != null) {
        print('❌ [BALANCE] RPC returned error: ${result['error']}');
        return {
          'success': false,
          'hasBalance': false,
          'error': 'RPC error: ${result['error']['message'] ?? result['error']}',
        };
      }
      
      final balanceHex = result['result'] as String?;
      if (balanceHex == null || balanceHex == '0x' || balanceHex.isEmpty) {
        print('⚠️ [BALANCE] Empty balance response, assuming 0');
        return {
          'success': true,
          'hasBalance': false,
          'availableBalance': 0.0,
          'requiredAmount': requiredAmount,
          'distributorAddress': distributorAddress,
        };
      }
      
      // Parse hex balance
      final cleanHex = balanceHex.replaceFirst('0x', '');
      final balanceBigInt = cleanHex.isEmpty ? BigInt.zero : BigInt.parse(cleanHex, radix: 16);
      final divisor = BigInt.from(10).pow(tokenDecimals);
      final availableBalance = balanceBigInt.toDouble() / divisor.toDouble();
      
      print('💰 [BALANCE] Available: $availableBalance');
      print('📊 [BALANCE] Required: $requiredAmount');
      
      final hasBalance = availableBalance >= requiredAmount;
      
      return {
        'success': true,
        'hasBalance': hasBalance,
        'availableBalance': availableBalance,
        'requiredAmount': requiredAmount,
        'distributorAddress': distributorAddress,
      };
    } catch (e, stackTrace) {
      print('❌ [BALANCE] Error checking balance: $e');
      print('❌ [BALANCE] Stack trace: $stackTrace');
      return {
        'success': false,
        'hasBalance': false,
        'error': 'Failed to check balance: $e',
      };
    }
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
        
        // Convert amount to smallest unit using token decimals
        int decimals = 18;
        try {
          final contract = web3dart.DeployedContract(
            web3dart.ContractAbi.fromJson(_erc20ABI, 'ERC20'),
            web3dart.EthereumAddress.fromHex(tokenContractAddress),
          );
          final decimalsFn = contract.function('decimals');
          final decimalsResult = await client.call(
            contract: contract,
            function: decimalsFn,
            params: [],
          );
          if (decimalsResult.isNotEmpty) {
            decimals = (decimalsResult[0] as BigInt).toInt();
          }
        } catch (e) {
          print('⚠️ [ERC20] Failed to fetch token decimals, defaulting to 18: $e');
        }

        final amountInSmallestUnit = BigInt.from(
          (amount * pow(10, decimals)).round(),
        );
        
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

      // Estimate gas fee for ERC-20 transaction (with transaction details for accurate estimation)
      final gasEstimate = await estimateERC20GasFee(
        fromAddress: fromAddress,
        tokenContractAddress: tokenContractAddress,
        toAddress: toAddress,
        amount: amount,
      );

      if (gasEstimate['success'] != true) {
        throw Exception('Failed to estimate gas fee: ${gasEstimate['error']}');
      }

      final requiredGasFee = gasEstimate['gasFee'] as double;
      print('⛽ [ERC20] Estimated gas fee: $requiredGasFee MATIC');

      // Check if user has enough MATIC for gas
      final balanceResult = await getPolygonBalance(fromAddress);
      final currentMaticBalance = balanceResult['balance'] as double? ?? 0.0;
      final needsMaticTopUp = currentMaticBalance < requiredGasFee;

      // If sending USDT/USDC and MATIC is insufficient, check user has enough for amount + fee
      if (needsMaticTopUp) {
        final usdtContract = '0xc2132D05D31c914a87C6611C10748AEb04B58e8F';
        final usdcContract = '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359';
        final isSendingUSDT = tokenContractAddress.toLowerCase() == usdtContract.toLowerCase();
        final isSendingUSDC = tokenContractAddress.toLowerCase() == usdcContract.toLowerCase();

        if (isSendingUSDT || isSendingUSDC) {
          // Calculate fee (10% more than MATIC value + gas cost)
          final insufficientMatic = requiredGasFee - currentMaticBalance;
          final topUpAmount = insufficientMatic * 1.1;
          
          // Estimate gas cost for sending MATIC (simple MATIC transfer)
          final client = web3dart.Web3Client(_currentRpcUrl, http.Client());
          double gasCostForMaticTransfer = 0.0;
          try {
            final gasPrice = await client.getGasPrice();
            const gasLimit = 21000; // Standard for MATIC transfer
            final gasFeeWei = gasPrice.getInWei * BigInt.from(gasLimit);
            gasCostForMaticTransfer = gasFeeWei.toDouble() / 1e18;
          } catch (e) {
            // Use a conservative estimate (0.01 MATIC)
            gasCostForMaticTransfer = 0.01;
          } finally {
            await client.dispose();
          }
          
          final feeAmount = calculateMaticTopUpFee(
            maticAmount: topUpAmount,
            gasCostForMaticTransfer: gasCostForMaticTransfer,
          );
          
          print('💳 [ERC20] Sending ${isSendingUSDT ? 'USDT' : 'USDC'}, checking balance for amount + fee');
          print('💰 [ERC20] Amount to send: $amount');
          print('💳 [ERC20] Fee required: $feeAmount');
          print('💰 [ERC20] Total needed: ${amount + feeAmount}');

          // Check balance
          final tokenBalance = await getStablecoinBalance(
            userAddress: fromAddress,
            tokenSymbol: isSendingUSDT ? 'USDT' : 'USDC',
          );

          if (tokenBalance['success'] != true) {
            throw Exception('Failed to check ${isSendingUSDT ? 'USDT' : 'USDC'} balance: ${tokenBalance['error']}');
          }

          final availableBalance = tokenBalance['balance'] as double;
          final totalNeeded = amount + feeAmount;

          if (availableBalance < totalNeeded) {
            throw Exception(
              'Insufficient ${isSendingUSDT ? 'USDT' : 'USDC'} balance. '
              'You need $totalNeeded ${isSendingUSDT ? 'USDT' : 'USDC'} '
              '($amount to send + $feeAmount fee), but only have $availableBalance.'
            );
          }

          print('✅ [ERC20] User has sufficient ${isSendingUSDT ? 'USDT' : 'USDC'} for amount + fee');
        }
      }

      // Check and ensure sufficient MATIC for gas (will charge fee if needed)
      final maticCheck = await ensureSufficientMaticForGas(
        userAddress: fromAddress,
        requiredGasFee: requiredGasFee,
        userId: userId,
        password: password,
      );

      if (!maticCheck['success']) {
        throw Exception('Failed to ensure sufficient MATIC: ${maticCheck['error']}');
      }

      if (maticCheck['toppedUp'] == true) {
        print('✅ [ERC20] MATIC topped up successfully, proceeding with transaction');
      }

      // Use the main sendERC20Token method with user's private key
      final result = await sendERC20Token(
        tokenContractAddress: tokenContractAddress,
        toAddress: toAddress,
        amount: amount,
        distributorPrivateKey: privateKey,
        gasLimit: gasLimit,
        gasPrice: gasPrice,
      );

      // Add top-up info to result if applicable
      if (maticCheck['toppedUp'] == true) {
        result['maticToppedUp'] = true;
        result['topUpTxHash'] = maticCheck['topUpTxHash'];
        result['feeCharged'] = maticCheck['feeCharged'];
        result['feeToken'] = maticCheck['feeToken'];
        result['feeTxHash'] = maticCheck['feeTxHash'];
      }

      return result;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to send ERC-20 token',
      };
    }
  }

  /// Create a signed ERC-20 transaction without broadcasting
  /// User signs with their wallet, transaction can be relayed by backend
  static Future<Map<String, dynamic>> createSignedERC20Transaction({
    required String userId,
    required String password,
    required String tokenContractAddress,
    required String toAddress,
    required double amount,
  }) async {
    try {
      print('🔐 [ERC20] Creating signed transaction...');
      
      // Use the robust authenticateAndDecryptPolygonWallet method
      // This already handles all validation and decryption logic
      final authResult = await authenticateAndDecryptPolygonWallet(
        userId,
        password,
      );
      
      if (!authResult['success']) {
        throw Exception(authResult['error'] ?? 'Authentication failed');
      }
      
      final privateKey = authResult['privateKey'] as String;
      final walletAddress = authResult['address'] as String;
      
      print('✅ [ERC20] Wallet authenticated: ${walletAddress.substring(0, 10)}...');
      print('✅ [ERC20] Private key decrypted');

      // Create Web3 client
      final client = web3dart.Web3Client(_currentRpcUrl, http.Client());
      
      try {
        // Prepare credentials
        String cleanKey = privateKey.trim();
        if (cleanKey.startsWith('0x') || cleanKey.startsWith('0X')) {
          cleanKey = cleanKey.substring(2);
        }
        final privateKeyBytes = web3crypto.hexToBytes(cleanKey);
        final credentials = web3dart.EthPrivateKey(privateKeyBytes);
        final fromAddress = credentials.address;
        
        print('═══════════════════════════════════════════════════════════════');
        print('📍 [ERC20] WALLET ADDRESS CHECK');
        print('═══════════════════════════════════════════════════════════════');
        print('✅ [ERC20] From address: ${fromAddress.hex}');
        print('📊 [ERC20] Stored wallet address: $walletAddress');
        print('📊 [ERC20] Derived from key: ${fromAddress.hex}');
        print('📊 [ERC20] Token contract: $tokenContractAddress');
        print('📊 [ERC20] Network: ${_isTestnet ? 'Polygon Amoy Testnet' : 'Polygon Mainnet'}');
        print('📊 [ERC20] RPC URL: $_currentRpcUrl');
        print('═══════════════════════════════════════════════════════════════');
        
        // Fix database if addresses don't match
        if (walletAddress.toLowerCase() != fromAddress.hex.toLowerCase()) {
          print('⚠️⚠️⚠️ [ERC20] WARNING: Address mismatch detected!');
          print('   Stored in DB: $walletAddress');
          print('   Derived from private key: ${fromAddress.hex}');
          print('🔧 [ERC20] FIXING: Updating database to use correct address...');
          
          try {
            await _firestore.collection('polygon_wallets').doc(userId).update({
              'address': fromAddress.hex,
              'lastAccessed': FieldValue.serverTimestamp(),
              'addressCorrected': true,
              'previousAddress': walletAddress,
            });
            
            await _firestore.collection('USER').doc(userId).update({
              'polygonAddress': fromAddress.hex,
              'lastWalletUpdate': FieldValue.serverTimestamp(),
            });
            
            print('✅ [ERC20] Database updated with correct address: ${fromAddress.hex}');
            print('⚠️ [ERC20] IMPORTANT: Your tokens are still at the old address: $walletAddress');
            print('⚠️ [ERC20] You need to transfer them to the new address: ${fromAddress.hex}');
          } catch (e) {
            print('❌ [ERC20] Failed to update database: $e');
          }
        }

        // Get token contract
        final contract = web3dart.DeployedContract(
          web3dart.ContractAbi.fromJson(json.encode([
            {
              'constant': false,
              'inputs': [
                {'name': '_to', 'type': 'address'},
                {'name': '_value', 'type': 'uint256'}
              ],
              'name': 'transfer',
              'outputs': [
                {'name': '', 'type': 'bool'}
              ],
              'type': 'function'
            },
            {
              'constant': true,
              'inputs': [],
              'name': 'decimals',
              'outputs': [
                {'name': '', 'type': 'uint8'}
              ],
              'type': 'function'
            },
            {
              'constant': true,
              'inputs': [
                {'name': '_owner', 'type': 'address'}
              ],
              'name': 'balanceOf',
              'outputs': [
                {'name': 'balance', 'type': 'uint256'}
              ],
              'type': 'function'
            },
          ]), ''),
          web3dart.EthereumAddress.fromHex(tokenContractAddress),
        );

        // Get token decimals
        final decimalsFunction = contract.function('decimals');
        final decimalsResult = await client.call(
          contract: contract,
          function: decimalsFunction,
          params: [],
        );
        final decimals = (decimalsResult[0] as BigInt).toInt();
        print('📊 [ERC20] Token decimals: $decimals');
        
        // Get user's current balance to verify
        final balanceFunction = contract.function('balanceOf');
        final balanceResult = await client.call(
          contract: contract,
          function: balanceFunction,
          params: [fromAddress],
        );
        final currentBalance = balanceResult[0] as BigInt;
        final currentBalanceFormatted = currentBalance.toDouble() / pow(10, decimals);
        print('💰 [ERC20] Current balance: $currentBalanceFormatted tokens (raw: $currentBalance)');
        
        // Convert amount to token units
        final amountInUnits = BigInt.from(amount * pow(10, decimals));
        print('💸 [ERC20] Amount to send: $amount tokens');
        print('💸 [ERC20] Amount in units: $amountInUnits');
        
        // Check if sufficient balance
        if (amountInUnits > currentBalance) {
          throw Exception('Insufficient balance: trying to send $amount but only have $currentBalanceFormatted');
        }
        
        // Encode transfer function
        final transferFunction = contract.function('transfer');
        final data = transferFunction.encodeCall([
          web3dart.EthereumAddress.fromHex(toAddress),
          amountInUnits,
        ]);

        // Get nonce
        final nonce = await client.getTransactionCount(fromAddress);
        
        // Get gas price and estimate gas
        final gasPrice = await client.getGasPrice();
        final estimatedGas = await client.estimateGas(
          sender: fromAddress,
          to: web3dart.EthereumAddress.fromHex(tokenContractAddress),
          data: data,
        );

        print('⛽ [ERC20] Estimated gas: $estimatedGas');

        // Create transaction
        final transaction = web3dart.Transaction(
          to: web3dart.EthereumAddress.fromHex(tokenContractAddress),
          from: fromAddress,
          data: data,
          gasPrice: gasPrice,
          maxGas: estimatedGas.toInt(),
          nonce: nonce,
          value: web3dart.EtherAmount.zero(),
        );

        // Sign transaction
        final signedTx = await client.signTransaction(credentials, transaction, chainId: _chainId);
        
        print('✅ [ERC20] Transaction signed');
        print('📦 [ERC20] Signed tx length: ${signedTx.length}');

        await client.dispose();

        return {
          'success': true,
          'signedTransaction': web3crypto.bytesToHex(signedTx, include0x: true),
          'from': fromAddress.hex,
          'to': toAddress,
          'amount': amount,
          'tokenAddress': tokenContractAddress,
        };
      } finally {
        await client.dispose();
      }
    } catch (e, stackTrace) {
      print('❌ [ERC20] Error creating signed transaction: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
