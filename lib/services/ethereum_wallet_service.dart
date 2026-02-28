import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:math' show max;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart' as web3dart;
import 'package:web3dart/crypto.dart' as web3crypto;
import 'package:bip39/bip39.dart' as bip39;
import 'polygon_wallet_service.dart'; // Reuse address derivation logic
import '../config/api_config.dart';

/// Ethereum Wallet Service
/// Since Polygon and Ethereum are EVM-compatible, they share the same address
/// This service provides Ethereum mainnet-specific operations
class EthereumWalletService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Ethereum RPC endpoints
  static const String _ethereumMainnetRpc = 'https://eth.llamarpc.com'; // Public RPC
  static const String _ethereumSepoliaRpc = 'https://rpc.sepolia.org'; // Testnet

  // Network configuration
  static String _currentRpcUrl = _ethereumMainnetRpc;
  static bool _isTestnet = false;
  static int _chainId = 1; // Ethereum mainnet: 1, Sepolia: 11155111

  /// Set network (mainnet or testnet)
  static void setNetwork({required bool isTestnet}) {
    _isTestnet = isTestnet;
    _currentRpcUrl = isTestnet ? _ethereumSepoliaRpc : _ethereumMainnetRpc;
    _chainId = isTestnet ? 11155111 : 1;
  }

  /// Get current network info
  static Map<String, dynamic> getNetworkInfo() {
    return {
      'isTestnet': _isTestnet,
      'rpcUrl': _currentRpcUrl,
      'chainId': _chainId,
      'networkName': _isTestnet ? 'Ethereum Sepolia' : 'Ethereum Mainnet',
    };
  }

  /// Get Ethereum wallet address (same as Polygon since they share the same private key)
  /// This reuses the Polygon wallet address since they're derived from the same seed phrase
  static Future<String?> getEthereumWalletAddress(String userId) async {
    // Since Polygon and Ethereum share the same address (EVM-compatible),
    // we can reuse the Polygon wallet address
    return await PolygonWalletService.getCorrectWalletAddress(userId);
  }

  /// Check if user has an Ethereum wallet (same as Polygon wallet)
  static Future<bool> hasEthereumWallet(String userId) async {
    return await PolygonWalletService.hasPolygonWallet(userId);
  }

  /// Get ETH balance for an address
  static Future<Map<String, dynamic>> getEthBalance(String address) async {
    try {
      final client = web3dart.Web3Client(_currentRpcUrl, http.Client());
      
      try {
        final balance = await client.getBalance(
          web3dart.EthereumAddress.fromHex(address),
        );
        
        final balanceEth = balance.getInEther;
        
        return {
          'success': true,
          'balance': balanceEth,
          'balanceWei': balance.getInWei.toString(),
          'symbol': 'ETH',
        };
      } finally {
        client.dispose();
      }
    } catch (e) {
      print('❌ [ETH] Error getting ETH balance: $e');
      return {
        'success': false,
        'error': e.toString(),
        'balance': 0.0,
      };
    }
  }

  /// Get ERC-20 token balance
  static Future<Map<String, dynamic>> getERC20TokenBalance({
    required String address,
    required String tokenContractAddress,
  }) async {
    try {
      final client = web3dart.Web3Client(_currentRpcUrl, http.Client());
      
      try {
        // ERC-20 balanceOf ABI
        const balanceOfABI = '''
        [{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"type":"function"}]
        ''';
        
        final contract = web3dart.DeployedContract(
          web3dart.ContractAbi.fromJson(balanceOfABI, 'ERC20'),
          web3dart.EthereumAddress.fromHex(tokenContractAddress),
        );
        
        final balanceOfFunction = contract.function('balanceOf');
        final result = await client.call(
          contract: contract,
          function: balanceOfFunction,
          params: [web3dart.EthereumAddress.fromHex(address)],
        );
        
        final balanceWei = result[0] as BigInt;
        final balance = balanceWei.toDouble() / 1e18; // Assuming 18 decimals
        
        return {
          'success': true,
          'balance': balance,
          'balanceWei': balanceWei.toString(),
        };
      } finally {
        client.dispose();
      }
    } catch (e) {
      print('❌ [ETH] Error getting ERC-20 balance: $e');
      return {
        'success': false,
        'error': e.toString(),
        'balance': 0.0,
      };
    }
  }

  /// Get all token balances for an address (ETH + common ERC-20 tokens)
  static Future<Map<String, dynamic>> getAllEthereumTokenBalances(String address) async {
    try {
      final tokens = <String, Map<String, dynamic>>{};
      
      // Get ETH balance
      final ethBalance = await getEthBalance(address);
      if (ethBalance['success'] == true) {
        tokens['ETH'] = {
          'balance': ethBalance['balance'],
          'balanceWei': ethBalance['balanceWei'],
          'symbol': 'ETH',
          'name': 'Ethereum',
          'decimals': 18,
          'contractAddress': null, // Native token
        };
      }
      
      // Common ERC-20 tokens on Ethereum mainnet
      final commonTokens = {
        'USDC': '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
        'USDT': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
        'DAI': '0x6B175474E89094C44Da98b954EedeAC495271d0F',
        'WETH': '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
      };
      
      // Get balances for common tokens
      for (final entry in commonTokens.entries) {
        final tokenBalance = await getERC20TokenBalance(
          address: address,
          tokenContractAddress: entry.value,
        );
        
        if (tokenBalance['success'] == true && (tokenBalance['balance'] as double) > 0) {
          tokens[entry.key] = {
            'balance': tokenBalance['balance'],
            'balanceWei': tokenBalance['balanceWei'],
            'symbol': entry.key,
            'name': entry.key,
            'decimals': 18,
            'contractAddress': entry.value,
          };
        }
      }
      
      return {
        'success': true,
        'tokens': tokens,
        'address': address,
        'network': _isTestnet ? 'ethereum-sepolia' : 'ethereum-mainnet',
      };
    } catch (e) {
      print('❌ [ETH] Error getting all token balances: $e');
      return {
        'success': false,
        'error': e.toString(),
        'tokens': <String, Map<String, dynamic>>{},
      };
    }
  }

  /// Send ETH transaction with seed phrase authentication
  static Future<Map<String, dynamic>> sendEthTransactionWithSeedPhrase({
    required String userId,
    required String seedPhrase,
    required String toAddress,
    required double amountEth,
    int? gasLimit,
    int? gasPrice,
  }) async {
    try {
      // Verify seed phrase and derive wallet
      final verifyResult = await PolygonWalletService.verifySeedPhrase(
        userId: userId,
        seedPhrase: seedPhrase,
      );

      if (!verifyResult['success']) {
        throw Exception('Seed phrase verification failed: ${verifyResult['error']}');
      }

      // Derive private key from seed phrase (same as Polygon)
      final seedPhraseTrimmed = seedPhrase.trim();
      final seed = bip39.mnemonicToSeed(seedPhraseTrimmed);
      final privateKeyBytes = seed.sublist(0, 32);
      final ethPrivateKey = web3dart.EthPrivateKey(privateKeyBytes);
      final fromAddress = ethPrivateKey.address.hex;
      final privateKeyHex = '0x${web3crypto.bytesToHex(privateKeyBytes, include0x: false)}';

      // Verify derived address matches stored address
      final walletDoc = await _firestore
          .collection('polygon_wallets')
          .doc(userId)
          .get();

      if (!walletDoc.exists) {
        throw Exception('Wallet not found');
      }

      final walletData = walletDoc.data()!;
      final storedAddress = walletData['address'] as String?;

      if (storedAddress != null && 
          fromAddress.toLowerCase() != storedAddress.toLowerCase()) {
        throw Exception(
          'This wallet was not created from a seed phrase. Please recreate your wallet with a seed phrase.'
        );
      }

      final client = web3dart.Web3Client(_currentRpcUrl, http.Client());
      
      try {
        // Get gas price and estimate gas fee
        final currentGasPrice = gasPrice != null
            ? web3dart.EtherAmount.fromBigInt(web3dart.EtherUnit.gwei, BigInt.from(gasPrice))
            : await client.getGasPrice();
        final currentGasLimit = gasLimit ?? 21000;
        
        // Calculate gas fee
        final gasFeeWei = currentGasPrice.getInWei * BigInt.from(currentGasLimit);
        final gasFeeEth = gasFeeWei.toDouble() / 1e18;
        
        // Calculate total required (amount + gas)
        final totalRequiredEth = amountEth + gasFeeEth;
        
        // Check balance
        final balance = await client.getBalance(web3dart.EthereumAddress.fromHex(fromAddress));
        // Convert from wei to ETH (double)
        final balanceEth = balance.getInWei.toDouble() / 1e18;
        
        if (balanceEth < totalRequiredEth) {
          throw Exception(
            'Insufficient ETH balance. Required: ${totalRequiredEth.toStringAsFixed(6)} ETH, '
            'Available: ${balanceEth.toStringAsFixed(6)} ETH'
          );
        }
        
        // Convert amount to wei
        final amountWei = BigInt.from((amountEth * 1e18).toInt());
        
        // Create credentials from private key
        final privateKeyBytes = web3crypto.hexToBytes(
          privateKeyHex.startsWith('0x') ? privateKeyHex.substring(2) : privateKeyHex,
        );
        final credentials = web3dart.EthPrivateKey(privateKeyBytes);
        
        // Get nonce
        final nonce = await client.getTransactionCount(credentials.address);
        
        // Create transaction (use maxGas instead of gasLimit)
        final transaction = web3dart.Transaction(
          to: web3dart.EthereumAddress.fromHex(toAddress),
          value: web3dart.EtherAmount.fromBigInt(web3dart.EtherUnit.wei, amountWei),
          gasPrice: currentGasPrice,
          maxGas: currentGasLimit, // maxGas expects int, not BigInt
          nonce: nonce,
        );
        
        // Sign and send transaction using client.sendTransaction
        final txHash = await client.sendTransaction(
          credentials,
          transaction,
          chainId: _chainId,
        );
        
        print('✅ [ETH] Transaction sent: $txHash');
        
        return {
          'success': true,
          'txHash': txHash,
          'from': fromAddress,
          'to': toAddress,
          'amount': amountEth,
          'gasFee': gasFeeEth,
          'network': _isTestnet ? 'ethereum-sepolia' : 'ethereum-mainnet',
        };
      } finally {
        client.dispose();
      }
    } catch (e) {
      print('❌ [ETH] Error sending ETH transaction: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Send ERC-20 token transaction with seed phrase authentication
  static Future<Map<String, dynamic>> sendERC20TokenWithSeedPhrase({
    required String userId,
    required String seedPhrase,
    required String tokenContractAddress,
    required String toAddress,
    required double amount,
    int? gasLimit,
    int? gasPrice,
  }) async {
    try {
      // Verify seed phrase and derive wallet (same as Polygon)
      final verifyResult = await PolygonWalletService.verifySeedPhrase(
        userId: userId,
        seedPhrase: seedPhrase,
      );

      if (!verifyResult['success']) {
        throw Exception('Seed phrase verification failed: ${verifyResult['error']}');
      }

      // Derive private key from seed phrase
      final seedPhraseTrimmed = seedPhrase.trim();
      final seed = bip39.mnemonicToSeed(seedPhraseTrimmed);
      final privateKeyBytes = seed.sublist(0, 32);
      final ethPrivateKey = web3dart.EthPrivateKey(privateKeyBytes);
      final fromAddress = ethPrivateKey.address.hex;
      final privateKeyHex = '0x${web3crypto.bytesToHex(privateKeyBytes, include0x: false)}';

      // Verify derived address matches stored address
      final walletDoc = await _firestore
          .collection('polygon_wallets')
          .doc(userId)
          .get();

      if (!walletDoc.exists) {
        throw Exception('Wallet not found');
      }

      final walletData = walletDoc.data()!;
      final storedAddress = walletData['address'] as String?;

      if (storedAddress != null && 
          fromAddress.toLowerCase() != storedAddress.toLowerCase()) {
        throw Exception(
          'This wallet was not created from a seed phrase. Please recreate your wallet with a seed phrase.'
        );
      }

      // Use Polygon service's ERC-20 sending logic but with Ethereum RPC
      // The ERC-20 transfer logic is the same for both networks
      final client = web3dart.Web3Client(_currentRpcUrl, http.Client());
      
      try {
        // ERC-20 transfer ABI
        final erc20ABI = json.encode([
          {
            'constant': false,
            'inputs': [
              {'name': '_to', 'type': 'address'},
              {'name': '_value', 'type': 'uint256'}
            ],
            'name': 'transfer',
            'outputs': [{'name': '', 'type': 'bool'}],
            'type': 'function'
          },
          {
            'constant': true,
            'inputs': [],
            'name': 'decimals',
            'outputs': [{'name': '', 'type': 'uint8'}],
            'type': 'function'
          },
        ]);
        
        final contract = web3dart.DeployedContract(
          web3dart.ContractAbi.fromJson(erc20ABI, 'ERC20'),
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
        final amountInUnits = BigInt.from((amount * math.pow(10, decimals)).toInt());
        final data = transferFunction.encodeCall([
          web3dart.EthereumAddress.fromHex(toAddress),
          amountInUnits,
        ]);
        
        // Create credentials
        final privateKeyBytes = web3crypto.hexToBytes(
          privateKeyHex.startsWith('0x') ? privateKeyHex.substring(2) : privateKeyHex,
        );
        final credentials = web3dart.EthPrivateKey(privateKeyBytes);
        final fromAddressEth = credentials.address;
        
        // Get nonce
        final nonce = await client.getTransactionCount(fromAddressEth);
        
        // Get gas price and estimate gas
        final currentGasPrice = gasPrice != null
            ? web3dart.EtherAmount.fromBigInt(web3dart.EtherUnit.gwei, BigInt.from(gasPrice))
            : await client.getGasPrice();
        final estimatedGasBigInt = gasLimit != null
            ? BigInt.from(gasLimit)
            : await client.estimateGas(
                sender: fromAddressEth,
                to: web3dart.EthereumAddress.fromHex(tokenContractAddress),
                data: data,
              );
        final estimatedGas = estimatedGasBigInt.toInt();
        
        print('⛽ [ETH ERC20] Estimated gas: $estimatedGas');
        
        // Create transaction
        final transaction = web3dart.Transaction(
          to: web3dart.EthereumAddress.fromHex(tokenContractAddress),
          from: fromAddressEth,
          data: data,
          gasPrice: currentGasPrice,
          maxGas: estimatedGas, // maxGas expects int
          nonce: nonce,
          value: web3dart.EtherAmount.zero(),
        );
        
        // Sign and send transaction
        final txHash = await client.sendTransaction(
          credentials,
          transaction,
          chainId: _chainId,
        );
        
        print('✅ [ETH] ERC-20 transaction sent: $txHash');
        
        return {
          'success': true,
          'txHash': txHash,
          'from': fromAddress,
          'to': toAddress,
          'amount': amount,
          'tokenContract': tokenContractAddress,
          'network': _isTestnet ? 'ethereum-sepolia' : 'ethereum-mainnet',
        };
      } finally {
        client.dispose();
      }
    } catch (e) {
      print('❌ [ETH] Error sending ERC-20 transaction: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get transaction history for an Ethereum address
  /// Tries direct RPC first, then falls back to Alchemy (if configured).
  static Future<List<Map<String, dynamic>>> getEthereumTransactionHistory(
    String address, {
    int limit = 50,
  }) async {
    try {
      print('🔄 [ETH] Fetching transactions using direct RPC...');
      print('📍 Address: $address');
      print('🌐 RPC: $_currentRpcUrl');
      
      // Try direct RPC method first (no API key needed)
      final transactions = await _getTransactionsFromRPC(address, limit);
      
      if (transactions.isNotEmpty) {
        print('✅ [ETH] Found ${transactions.length} transactions via direct RPC');
        return transactions;
      }
      
      // Fallback to Alchemy if available and direct RPC returns nothing
      if (ApiConfig.hasAlchemyApiKey) {
        print('⚠️ [ETH] Direct RPC returned no results, trying Alchemy API...');
        return await _getTransactionsFromAlchemy(address, limit);
      }
      
      return [];
      
    } catch (e) {
      print('❌ [ETH] Error fetching transactions: $e');
      return [];
    }
  }

  /// Direct-RPC transaction fetch (native ETH transfers) by scanning recent blocks.
  static Future<List<Map<String, dynamic>>> _getTransactionsFromRPC(
    String address,
    int limit,
  ) async {
    try {
      final normalizedAddress = address.toLowerCase();
      final txs = <Map<String, dynamic>>[];

      int parseHexInt(String? hexValue) {
        if (hexValue == null || hexValue.isEmpty) return 0;
        final clean = hexValue.startsWith('0x') ? hexValue.substring(2) : hexValue;
        if (clean.isEmpty) return 0;
        return int.tryParse(clean, radix: 16) ?? 0;
      }

      BigInt parseHexBigInt(String? hexValue) {
        if (hexValue == null || hexValue.isEmpty) return BigInt.zero;
        final clean = hexValue.startsWith('0x') ? hexValue.substring(2) : hexValue;
        if (clean.isEmpty) return BigInt.zero;
        return BigInt.tryParse(clean, radix: 16) ?? BigInt.zero;
      }

      final latestBlockResp = await http.post(
        Uri.parse(_currentRpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id': 1,
          'jsonrpc': '2.0',
          'method': 'eth_blockNumber',
          'params': [],
        }),
      ).timeout(const Duration(seconds: 20));

      if (latestBlockResp.statusCode != 200) return [];
      final latestBody = json.decode(latestBlockResp.body);
      final latestBlock = parseHexInt(latestBody['result'] as String?);
      if (latestBlock <= 0) return [];

      // Keep scan window bounded for performance on public RPC endpoints.
      const maxBlocksToScan = 400;
      final startBlock = max(0, latestBlock - maxBlocksToScan);

      for (int block = latestBlock; block >= startBlock; block--) {
        if (txs.length >= limit) break;

        final blockResp = await http.post(
          Uri.parse(_currentRpcUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'id': 1,
            'jsonrpc': '2.0',
            'method': 'eth_getBlockByNumber',
            'params': ['0x${block.toRadixString(16)}', true],
          }),
        ).timeout(const Duration(seconds: 20));

        if (blockResp.statusCode != 200) continue;
        final blockBody = json.decode(blockResp.body);
        final blockData = blockBody['result'];
        if (blockData is! Map<String, dynamic>) continue;

        final blockTs = DateTime.fromMillisecondsSinceEpoch(
          parseHexInt(blockData['timestamp'] as String?) * 1000,
        );
        final transactions = blockData['transactions'];
        if (transactions is! List) continue;

        for (final dynamic tx in transactions) {
          if (txs.length >= limit) break;
          if (tx is! Map<String, dynamic>) continue;

          final from = (tx['from'] as String? ?? '').toLowerCase();
          final to = (tx['to'] as String? ?? '').toLowerCase();
          if (from != normalizedAddress && to != normalizedAddress) continue;

          final hash = tx['hash'] as String?;
          if (hash == null || hash.isEmpty) continue;

          final valueWei = parseHexBigInt(tx['value'] as String?);
          final valueEth = valueWei.toDouble() / 1e18;
          final gasPrice = parseHexInt(tx['gasPrice'] as String?);

          final receipt = await _getTransactionReceipt(_currentRpcUrl, hash);
          final gasUsed = parseHexInt(receipt?['gasUsed'] as String?);
          final statusHex = receipt?['status'] as String?;
          final status = statusHex == null || statusHex == '0x1' ? 'success' : 'failed';

          String type = 'contract';
          final isIncoming = to == normalizedAddress;
          final isOutgoing = from == normalizedAddress;
          if (isIncoming && !isOutgoing) type = 'receive';
          else if (isOutgoing && !isIncoming) type = 'send';
          else if (isIncoming && isOutgoing) type = 'self';

          txs.add({
            'hash': hash,
            'blockNumber': parseHexInt(tx['blockNumber'] as String?),
            'timestamp': blockTs,
            'from': tx['from'] as String? ?? '',
            'to': tx['to'] as String? ?? '',
            'value': valueEth,
            'asset': 'ETH',
            'tokenName': 'Ethereum',
            'contractAddress': '',
            'type': type,
            'status': status,
            'gasPrice': gasPrice,
            'gasUsed': gasUsed,
            'confirmations': 0,
            'network': _isTestnet ? 'ethereum-sepolia' : 'ethereum-mainnet',
          });
        }
      }

      txs.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
      return txs;
    } catch (e) {
      print('⚠️ [ETH] Direct RPC transaction fetch failed: $e');
      return [];
    }
  }

  /// Alchemy-based transaction fetch (ETH + token transfers).
  static Future<List<Map<String, dynamic>>> _getTransactionsFromAlchemy(
    String address,
    int limit,
  ) async {
    if (!ApiConfig.hasAlchemyApiKey) return [];

    try {
      final network = _isTestnet ? 'eth-sepolia' : 'eth-mainnet';
      final rpcUrl = 'https://$network.g.alchemy.com/v2/${ApiConfig.alchemyApiKey}';
      final transfers = await _getAlchemyAssetTransfers(rpcUrl, address);
      if (transfers.isEmpty) return [];

      final enrichedTxs = <Map<String, dynamic>>[];
      final userAddr = address.toLowerCase();

      for (final transfer in transfers.take(limit)) {
        try {
          if (transfer is! Map<String, dynamic>) continue;
          final hash = transfer['hash'] as String?;
          if (hash == null || hash.isEmpty) continue;

          final rawTx = await _getTransactionByHash(rpcUrl, hash);
          final receipt = await _getTransactionReceipt(rpcUrl, hash);

          final from = transfer['from'] as String? ?? '';
          final to = transfer['to'] as String? ?? '';
          final asset = transfer['asset'] as String? ?? 'ETH';
          final value = transfer['value'] != null
              ? double.tryParse(transfer['value'].toString()) ?? 0.0
              : 0.0;

          final metadata = transfer['metadata'];
          final blockTimestamp = metadata is Map<String, dynamic>
              ? metadata['blockTimestamp'] as String?
              : null;
          DateTime timestamp = DateTime.now();
          if (blockTimestamp != null) {
            try {
              timestamp = DateTime.parse(blockTimestamp);
            } catch (_) {}
          }

          final blockNum = transfer['blockNum'] as String?;
          final blockNumber = blockNum == null
              ? 0
              : int.tryParse(blockNum.replaceAll('0x', ''), radix: 16) ?? 0;

          final isIncoming = to.toLowerCase() == userAddr;
          final isOutgoing = from.toLowerCase() == userAddr;
          String type = 'contract';
          if (isIncoming && !isOutgoing) type = 'receive';
          else if (isOutgoing && !isIncoming) type = 'send';
          else if (isIncoming && isOutgoing) type = 'self';

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

          final rawContract = transfer['rawContract'];
          final contractAddress = rawContract is Map<String, dynamic>
              ? rawContract['address'] as String? ?? ''
              : '';

          enrichedTxs.add({
            'hash': hash,
            'blockNumber': blockNumber,
            'timestamp': timestamp,
            'from': from,
            'to': to,
            'value': value,
            'asset': asset,
            'tokenName': asset,
            'contractAddress': contractAddress,
            'type': type,
            'status': status,
            'gasPrice': gasPrice,
            'gasUsed': gasUsed,
            'confirmations': 0,
            'network': _isTestnet ? 'ethereum-sepolia' : 'ethereum-mainnet',
          });
        } catch (e) {
          print('⚠️ [ETH] Error enriching Alchemy transfer: $e');
        }
      }

      enrichedTxs.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
      return enrichedTxs;
    } catch (e) {
      print('⚠️ [ETH] Alchemy transaction fetch failed: $e');
      return [];
    }
  }

  /// Get asset transfers using Alchemy's alchemy_getAssetTransfers
  static Future<List<dynamic>> _getAlchemyAssetTransfers(String rpcUrl, String address) async {
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
        'category': ['external', 'erc20', 'erc721', 'erc1155'],
        'withMetadata': true,
        'excludeZeroValue': false,
      }],
    };
    
    print('📥 [ETH] Fetching INCOMING transfers...');
    try {
      final incomingResp = await http.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(incomingPayload),
      ).timeout(const Duration(seconds: 30));
      
      if (incomingResp.statusCode == 200) {
        final body = json.decode(incomingResp.body);
        if (body['error'] == null) {
          final transfers = body['result']?['transfers'] ?? [];
          print('✅ [ETH] Incoming transfers count: ${transfers.length}');
          allTransfers.addAll(transfers);
        } else {
          print('⚠️ [ETH] Alchemy API error (incoming): ${body['error']}');
        }
      } else {
        print('⚠️ [ETH] HTTP error (incoming): ${incomingResp.statusCode}');
      }
    } catch (e) {
      print('⚠️ [ETH] Network error fetching incoming transfers: $e');
      // Continue with outgoing transfers even if incoming fails
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
        'category': ['external', 'erc20', 'erc721', 'erc1155'],
        'withMetadata': true,
        'excludeZeroValue': false,
      }],
    };
    
    print('📤 [ETH] Fetching OUTGOING transfers...');
    try {
      final outgoingResp = await http.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(outgoingPayload),
      ).timeout(const Duration(seconds: 30));
      
      if (outgoingResp.statusCode == 200) {
        final body = json.decode(outgoingResp.body);
        if (body['error'] == null) {
          final transfers = body['result']?['transfers'] ?? [];
          print('✅ [ETH] Outgoing transfers count: ${transfers.length}');
          allTransfers.addAll(transfers);
        } else {
          print('⚠️ [ETH] Alchemy API error (outgoing): ${body['error']}');
        }
      } else {
        print('⚠️ [ETH] HTTP error (outgoing): ${outgoingResp.statusCode}');
      }
    } catch (e) {
      print('⚠️ [ETH] Network error fetching outgoing transfers: $e');
      // Return whatever transfers we have so far
    }
    
    // Remove duplicates
    final seen = <String>{};
    final uniqueTransfers = allTransfers.where((t) {
      final hash = t['hash'] as String?;
      if (hash == null || seen.contains(hash)) return false;
      seen.add(hash);
      return true;
    }).toList();
    
    print('📋 [ETH] Total transfers (after deduplication): ${uniqueTransfers.length}');
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
}

