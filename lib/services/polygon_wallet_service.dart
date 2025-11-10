import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

/// Secure Polygon Wallet Service implementing password-based AES-GCM encryption
/// Similar to MetaMask, Phantom, and other popular wallet implementations
/// Supports Polygon (Matic) network operations
class PolygonWalletService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Polygon RPC endpoints
  static const String _polygonMainnetRpc = 'https://polygon-rpc.com/';
  static const String _polygonTestnetRpc =
      'https://rpc-amoy.polygon.technology/';

  // Use testnet for development
  static const String _currentRpcUrl = _polygonTestnetRpc;
  static const bool _isTestnet = true;

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

  /// Generate a new Polygon wallet (ECDSA keypair)
  Map<String, String> _generatePolygonWallet() {
    // Generate random 32-byte private key
    final privateKeyBytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      privateKeyBytes[i] = Random.secure().nextInt(256);
    }

    // Convert to hex string
    final privateKey =
        '0x${privateKeyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

    // Derive public key and address (simplified - in production use proper ECDSA)
    // For now, we'll use a placeholder address derivation
    final publicKeyHash = crypto.sha256.convert(privateKeyBytes).bytes;
    final address =
        '0x${publicKeyHash.sublist(0, 20).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

    return {'privateKey': privateKey, 'address': address};
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
        'network': _isTestnet ? 'polygon-testnet' : 'polygon-mainnet',
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
        'network': _isTestnet ? 'polygon-testnet' : 'polygon-mainnet',
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
  static Future<Map<String, dynamic>> authenticateAndDecryptPolygonWallet(
    String userId,
    String password,
  ) async {
    try {
      print('🔐 Starting Polygon wallet decryption for user: $userId');

      // Validate inputs
      if (userId.isEmpty) {
        throw Exception('Invalid user ID provided');
      }
      if (password.isEmpty) {
        throw Exception('Password is required');
      }

      // Get wallet data from Firestore
      final walletDoc = await _firestore
          .collection('polygon_wallets')
          .doc(userId)
          .get();

      if (!walletDoc.exists) {
        print('❌ Polygon wallet not found for user: $userId');
        throw Exception(
          'Polygon wallet not found. Please create a Polygon wallet first.',
        );
      }

      print('✅ Polygon wallet data found');

      final walletData = walletDoc.data()!;
      final encryptedPrivateKey =
          walletData['encryptedPrivateKey'] as Map<String, dynamic>;
      final address = walletData['address'] as String;

      // Create service instance for decryption
      final service = PolygonWalletService();

      // Convert to the expected type for decryption
      final encryptedData = Map<String, String>.from(encryptedPrivateKey);

      // Decrypt the private key using password
      print('🔓 Decrypting Polygon private key...');
      final privateKey = await service._decryptPrivateKey(
        password,
        encryptedData,
      );

      print('✅ Polygon private key decrypted successfully');

      // Verify the decrypted key is valid by checking if it produces the correct address
      try {
        // Simplified verification - in production, derive address from private key
        final derivedAddress = _deriveAddressFromPrivateKey(privateKey);
        if (derivedAddress != address) {
          throw Exception('Decrypted key verification failed');
        }

        print('✅ Decrypted Polygon key verification successful');
      } catch (e) {
        print('❌ Invalid decrypted Polygon key: $e');
        throw Exception('Invalid password or corrupted wallet data');
      }

      // Update last accessed timestamp
      await _firestore.collection('polygon_wallets').doc(userId).update({
        'lastAccessed': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'address': address,
        'privateKey': privateKey,
        'message': 'Polygon wallet decrypted successfully',
      };
    } catch (e) {
      print('❌ Polygon wallet decryption failed: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to authenticate and decrypt Polygon wallet',
      };
    }
  }

  /// Derive Polygon address from private key (simplified)
  static String _deriveAddressFromPrivateKey(String privateKey) {
    // Remove 0x prefix if present
    final cleanKey = privateKey.startsWith('0x')
        ? privateKey.substring(2)
        : privateKey;

    // Convert hex to bytes
    final privateKeyBytes = Uint8List.fromList(
      List.generate(
        cleanKey.length ~/ 2,
        (i) => int.parse(cleanKey.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );

    // Simple address derivation (in production, use proper ECDSA secp256k1)
    final hash = crypto.sha256.convert(privateKeyBytes).bytes;
    return '0x${hash.sublist(0, 20).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
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
  static const Map<String, Map<String, dynamic>> _polygonTokens = {
    'MATIC': {
      'address': '', // Native token, empty address
      'symbol': 'MATIC',
      'name': 'Polygon Matic',
      'decimals': 18,
      'isNative': true,
    },
    'USDT': {
      'address':
          '0xc2132D05D31c914a87C6611C10748AEb04B58e8F6', // USDT on Polygon Mumbai
      'symbol': 'USDT',
      'name': 'Tether USD',
      'decimals': 6,
      'isNative': false,
    },
    'USDC': {
      'address':
          '0x0FA8781a83E46826621b3BC094Ea2A0212e71B23', // USDC on Polygon Mumbai
      'symbol': 'USDC',
      'name': 'USD Coin',
      'decimals': 6,
      'isNative': false,
    },
    'DAI': {
      'address':
          '0x001B3B4d0F3714Ca98ba10F6042DaEbF0B1B7b6F', // DAI on Polygon Mumbai
      'symbol': 'DAI',
      'name': 'Dai Stablecoin',
      'decimals': 18,
      'isNative': false,
    },
    'WETH': {
      'address':
          '0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa', // WETH on Polygon Mumbai
      'symbol': 'WETH',
      'name': 'Wrapped Ether',
      'decimals': 18,
      'isNative': false,
    },
  };

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
          'network': _isTestnet ? 'polygon-testnet' : 'polygon-mainnet',
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

  /// Get all Polygon token balances for an address
  static Future<Map<String, dynamic>> getAllPolygonTokenBalances(
    String address,
  ) async {
    try {
      final tokenBalances = <String, Map<String, dynamic>>{};

      // Get native MATIC balance
      final maticBalance = await getPolygonBalance(address);
      if (maticBalance['success'] == true) {
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

      // Get ERC-20 token balances
      for (final entry in _polygonTokens.entries) {
        final token = entry.value;
        if (!token['isNative']) {
          final tokenBalance = await _getERC20TokenBalance(
            address,
            token['address'],
            token['decimals'],
          );

          if (tokenBalance['success'] == true &&
              (tokenBalance['balance'] as double) > 0) {
            tokenBalances[token['symbol']] = {
              'symbol': token['symbol'],
              'name': token['name'],
              'balance': tokenBalance['balance'],
              'formattedBalance': (tokenBalance['balance'] as double)
                  .toStringAsFixed(token['decimals'] == 6 ? 6 : 4),
              'decimals': token['decimals'],
              'contractAddress': token['address'],
              'isNative': false,
            };
          }
        }
      }

      return {
        'success': true,
        'address': address,
        'network': _isTestnet ? 'polygon-testnet' : 'polygon-mainnet',
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

  /// Get ERC-20 token balance
  static Future<Map<String, dynamic>> _getERC20TokenBalance(
    String walletAddress,
    String tokenAddress,
    int decimals,
  ) async {
    try {
      // ERC-20 balanceOf function signature
      final functionSignature = '0x70a08231'; // balanceOf(address)

      // Pad wallet address to 32 bytes
      final paddedAddress = walletAddress.startsWith('0x')
          ? walletAddress.substring(2).padLeft(64, '0')
          : walletAddress.padLeft(64, '0');

      final data = functionSignature + paddedAddress;

      final response = await http.post(
        Uri.parse(_currentRpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'method': 'eth_call',
          'params': [
            {'to': tokenAddress, 'data': data},
            'latest',
          ],
          'id': 1,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final result = responseData['result'] as String?;

        if (result != null && result != '0x') {
          // Remove 0x prefix and parse as BigInt
          final balanceHex = result.substring(2);
          final balanceBigInt = BigInt.parse(balanceHex, radix: 16);

          // Convert to double with proper decimals
          final divisor = BigInt.from(10).pow(decimals);
          final balance = balanceBigInt / divisor;

          return {
            'success': true,
            'balance': balance.toDouble(),
            'rawBalance': balanceBigInt.toString(),
            'decimals': decimals,
          };
        } else {
          return {
            'success': true,
            'balance': 0.0,
            'rawBalance': '0',
            'decimals': decimals,
          };
        }
      } else {
        throw Exception('RPC request failed: ${response.statusCode}');
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'balance': 0.0,
        'decimals': decimals,
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

      // Get current gas price if not provided
      final currentGasPrice = gasPrice ?? await _getGasPrice();
      final currentGasLimit = gasLimit ?? 21000; // Standard transfer gas limit

      // Get nonce
      final nonce = await _getTransactionCount(fromAddress);

      // Create transaction object (simplified - in production use web3dart library)
      final transaction = {
        'from': fromAddress,
        'to': toAddress,
        'value': '0x${amountWei.toRadixString(16)}',
        'gas': '0x${currentGasLimit.toRadixString(16)}',
        'gasPrice': '0x${currentGasPrice.toRadixString(16)}',
        'nonce': '0x${nonce.toRadixString(16)}',
        'chainId': _isTestnet ? 80002 : 137, // Amoy testnet : Mainnet
      };

      // Sign transaction (simplified - in production use proper ECDSA signing)
      final signedTransaction = await _signPolygonTransaction(
        transaction,
        privateKey,
      );

      // Send transaction
      final txHash = await _sendRawTransaction(signedTransaction);

      return {
        'success': true,
        'txHash': txHash,
        'from': fromAddress,
        'to': toAddress,
        'amount': amountMatic,
        'gasUsed': currentGasLimit,
        'message': 'MATIC transaction sent successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to send MATIC transaction',
      };
    }
  }

  /// Get current gas price
  static Future<int> _getGasPrice() async {
    try {
      final response = await http.post(
        Uri.parse(_currentRpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'method': 'eth_gasPrice',
          'params': [],
          'id': 1,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final gasPriceHex = data['result'] as String;
        return int.parse(gasPriceHex.substring(2), radix: 16);
      }
    } catch (e) {
      print('Error getting gas price: $e');
    }

    // Fallback gas price (20 gwei)
    return 20000000000;
  }

  /// Get transaction count (nonce)
  static Future<int> _getTransactionCount(String address) async {
    try {
      final response = await http.post(
        Uri.parse(_currentRpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'method': 'eth_getTransactionCount',
          'params': [address, 'pending'],
          'id': 1,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final nonceHex = data['result'] as String;
        return int.parse(nonceHex.substring(2), radix: 16);
      }
    } catch (e) {
      print('Error getting transaction count: $e');
    }

    return 0;
  }

  /// Sign Polygon transaction (simplified implementation)
  static Future<String> _signPolygonTransaction(
    Map<String, dynamic> transaction,
    String privateKey,
  ) async {
    // This is a simplified implementation
    // In production, you would use web3dart or similar library for proper ECDSA signing

    // Create transaction hash (simplified)
    final txData = json.encode(transaction);
    final txHash = crypto.sha256.convert(utf8.encode(txData)).bytes;

    // Sign with private key (simplified - not cryptographically secure)
    final signature = crypto.Hmac(
      crypto.sha256,
      utf8.encode(privateKey),
    ).convert(txHash).bytes;

    // Return "signed" transaction (placeholder)
    return '0x${signature.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  /// Send raw transaction
  static Future<String> _sendRawTransaction(String signedTransaction) async {
    try {
      final response = await http.post(
        Uri.parse(_currentRpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'method': 'eth_sendRawTransaction',
          'params': [signedTransaction],
          'id': 1,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['result'] != null) {
          return data['result'] as String;
        } else if (data['error'] != null) {
          throw Exception('RPC Error: ${data['error']['message']}');
        }
      }

      throw Exception('Failed to send transaction');
    } catch (e) {
      throw Exception('Transaction send failed: $e');
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

  /// Get transaction history for a Polygon address
  static Future<List<Map<String, dynamic>>> getPolygonTransactionHistory(
    String address, {
    int limit = 50,
  }) async {
    try {
      final transactions = <Map<String, dynamic>>[];

      // Get latest block number first
      final latestBlockResponse = await http.post(
        Uri.parse(_currentRpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'method': 'eth_blockNumber',
          'params': [],
          'id': 1,
        }),
      );

      if (latestBlockResponse.statusCode != 200) {
        return transactions;
      }

      final latestBlockData = json.decode(latestBlockResponse.body);
      final latestBlockHex = latestBlockData['result'] as String;
      final latestBlock = int.parse(latestBlockHex.substring(2), radix: 16);

      // Scan recent blocks for transactions involving this address
      // Note: This is a simplified approach. In production, you'd use a proper indexer
      const blocksToScan = 1000; // Scan last 1000 blocks
      final startBlock = latestBlock - blocksToScan;

      for (
        int blockNumber = latestBlock;
        blockNumber >= startBlock && transactions.length < limit;
        blockNumber--
      ) {
        final blockResponse = await http.post(
          Uri.parse(_currentRpcUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'jsonrpc': '2.0',
            'method': 'eth_getBlockByNumber',
            'params': ['0x${blockNumber.toRadixString(16)}', true],
            'id': 1,
          }),
        );

        if (blockResponse.statusCode == 200) {
          final blockData = json.decode(blockResponse.body);
          final block = blockData['result'];

          if (block != null && block['transactions'] != null) {
            final blockTransactions = block['transactions'] as List;

            for (final tx in blockTransactions) {
              final from = tx['from']?.toString().toLowerCase();
              final to = tx['to']?.toString().toLowerCase();
              final userAddress = address.toLowerCase();

              // Check if this address is involved in the transaction
              if (from == userAddress || to == userAddress) {
                final valueHex = tx['value'] as String? ?? '0x0';
                final value =
                    int.parse(valueHex.substring(2), radix: 16) /
                    1e18; // Convert wei to MATIC

                final gasPriceHex = tx['gasPrice'] as String? ?? '0x0';
                final gasPrice = int.parse(gasPriceHex.substring(2), radix: 16);

                final gasLimitHex = tx['gas'] as String? ?? '0x0';
                final gasLimit = int.parse(gasLimitHex.substring(2), radix: 16);

                // Determine transaction type
                final isIncoming = to == userAddress && from != userAddress;
                final isOutgoing = from == userAddress && to != userAddress;
                final isContractCreation = to == null;

                String type;
                if (isContractCreation) {
                  type = 'contract_creation';
                } else if (isIncoming) {
                  type = 'receive';
                } else if (isOutgoing) {
                  type = 'send';
                } else {
                  type = 'self'; // Same address transaction
                }

                // Get transaction receipt for status
                final receipt = await getTransactionReceipt(tx['hash']);
                final status = receipt['success'] == true
                    ? receipt['status']
                    : 'pending';

                transactions.add({
                  'hash': tx['hash'],
                  'blockNumber': blockNumber,
                  'timestamp': block['timestamp'] != null
                      ? DateTime.fromMillisecondsSinceEpoch(
                          int.parse(
                                block['timestamp'].substring(2),
                                radix: 16,
                              ) *
                              1000,
                        )
                      : DateTime.now(),
                  'from': tx['from'],
                  'to': tx['to'],
                  'value': value,
                  'gasPrice': gasPrice,
                  'gasLimit': gasLimit,
                  'gasUsed': receipt['success'] == true
                      ? receipt['gasUsed']
                      : gasLimit,
                  'type': type,
                  'status': status,
                  'asset': 'MATIC',
                  'network': _isTestnet ? 'polygon-testnet' : 'polygon-mainnet',
                  'isIncoming': isIncoming,
                  'isOutgoing': isOutgoing,
                  'confirmations': latestBlock - blockNumber,
                });

                // Break if we have enough transactions
                if (transactions.length >= limit) break;
              }
            }
          }
        }

        // Small delay to avoid overwhelming the RPC
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Sort by timestamp (newest first)
      transactions.sort(
        (a, b) =>
            (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
      );

      return transactions;
    } catch (e) {
      print('Error fetching Polygon transaction history: $e');
      return [];
    }
  }
}
