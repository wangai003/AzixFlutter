import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import 'package:web3dart/web3dart.dart' as web3;
import 'package:web3dart/crypto.dart' as web3crypto;
import 'package:http/http.dart' as http;

import 'polygon_wallet_service.dart';

/// WalletConnect v2 (wallet side) service.
/// - Supports Polygon (Amoy/mainnet) chains.
/// - Handles connect/proposals/requests.
/// - Signs & broadcasts transactions via existing wallet + RPC.
class WalletConnectService {
  WalletConnectService._internal();
  static final WalletConnectService instance = WalletConnectService._internal();

  static const List<String> supportedChains = [
    'eip155:80002', // Polygon Amoy testnet
    'eip155:137', // Polygon mainnet (future)
  ];

  static const List<String> supportedMethods = [
    'eth_sendTransaction',
    'eth_sign',
    'personal_sign',
    'eth_signTypedData',
    'eth_signTypedData_v4',
  ];

  SignClient? _client;

  final ValueNotifier<List<SessionData>> sessions =
      ValueNotifier<List<SessionData>>([]);

  final ValueNotifier<List<SessionProposalEvent>> proposals =
      ValueNotifier<List<SessionProposalEvent>>([]);

  final ValueNotifier<List<SessionRequestEvent>> pendingRequests =
      ValueNotifier<List<SessionRequestEvent>>([]);

  bool get isInitialized => _client != null;

  /// Initialize WalletConnect SignClient
  Future<void> init() async {
    if (_client != null) return;

    final projectId = dotenv.env['WALLETCONNECT_PROJECT_ID'];
    if (projectId == null || projectId.isEmpty) {
      throw Exception(
        'WALLETCONNECT_PROJECT_ID missing in .env. '
        'Create one at https://cloud.walletconnect.com and set it in backend/.env & app .env',
      );
    }

    _client = await SignClient.createInstance(
      projectId: projectId,
      relayUrl: 'wss://relay.walletconnect.com',
      metadata: const PairingMetadata(
        name: 'Azix Enhanced Wallet',
        description: 'Azix wallet with gasless relay on Polygon',
        url: 'https://azix.app',
        icons: ['https://walletconnect.com/walletconnect-logo.png'],
      ),
    );

    _client!.onSessionProposal.subscribe(_onSessionProposal);
    _client!.onSessionRequest.subscribe(_onSessionRequest);
    _client!.onSessionDelete.subscribe((_) => _refreshSessions());

    await _refreshSessions();
  }

  /// Connect from a WC URI (e.g., pasted from checkout QR)
  Future<ConnectResponse> connect(String wcUri) async {
    if (!isInitialized) {
      await init();
    }
    final pairing = await _client!.pair(uri: Uri.parse(wcUri));
    final requiredNamespaces = {
      'eip155': RequiredNamespace(
        chains: supportedChains,
        methods: supportedMethods,
        events: [],
      ),
    };

    return _client!.connect(
      requiredNamespaces: requiredNamespaces,
      pairingTopic: pairing.topic,
    );
  }

  /// Approve a pending session proposal.
  Future<void> approveSession({
    required String id,
    required String address,
  }) async {
    if (!isInitialized) return;
    final namespaces = {
      'eip155': Namespace(
        accounts: supportedChains.map((c) => '$c:$address').toList(),
        methods: supportedMethods,
        events: [],
      ),
    };
    await _client!.approve(
      id: int.parse(id),
      namespaces: namespaces,
    );
    _removeProposal(id);
    await _refreshSessions();
  }

  /// Reject a session proposal or request.
  Future<void> reject({
    required String id,
    String reason = 'User rejected',
  }) async {
    if (!isInitialized) return;
    await _client!.reject(
      id: int.parse(id),
      reason: Errors.getSdkError(Errors.USER_REJECTED_SIGN),
    );
    _removeProposal(id);
  }

  /// Disconnect a session.
  Future<void> disconnect(String topic) async {
    if (!isInitialized) return;
    await _client!.disconnect(
      topic: topic,
      reason: Errors.getSdkError(Errors.USER_DISCONNECTED),
    );
    await _refreshSessions();
  }

  /// Approve a request. For tx signing, provide password to decrypt wallet.
  Future<void> approveRequest({
    required SessionRequestEvent request,
    required String password,
  }) async {
    if (!isInitialized) return;

    final method = request.params.request.method;
    final topic = request.topic;
    final id = request.id;

    try {
      switch (method) {
        case 'eth_sendTransaction':
          final params = request.params.request.params;
          if (params == null || params.isEmpty) {
            throw Exception('Missing transaction params');
          }
          final txParams = Map<String, dynamic>.from(params.first as Map);
          final txHash = await _signAndSendTransaction(txParams, password);
          await _client!.respond(
            topic: topic,
            response: JsonRpcResponse<String>(id: id, result: txHash),
          );
          break;

        case 'personal_sign':
        case 'eth_sign':
          final params = request.params.request.params;
          if (params == null || params.length < 1) {
            throw Exception('Missing sign params');
          }
          final message = params[0] as String;
          final signature = await _signMessage(message, password);
          await _client!.respond(
            topic: topic,
            response: JsonRpcResponse<String>(id: id, result: signature),
          );
          break;

        default:
          throw Exception('Unsupported method: $method');
      }
    } catch (e) {
      await _client!.respond(
        topic: topic,
        response: JsonRpcResponse<String>(
          id: id,
          error: JsonRpcError(
            code: 5000,
            message: e.toString(),
          ),
        ),
      );
    } finally {
      _removePending(id);
    }
  }

  Future<void> rejectRequest(SessionRequestEvent request,
      {String reason = 'User rejected'}) async {
    if (!isInitialized) return;
    final sdkError = Errors.getSdkError(Errors.USER_REJECTED_SIGN);
    await _client!.respond(
      topic: request.topic,
      response: JsonRpcResponse(
        id: request.id,
        error: JsonRpcError(
          code: sdkError.code,
          message: sdkError.message,
        ),
      ),
    );
    _removePending(request.id);
  }

  // ------------------- Internal handlers -------------------

  void _onSessionProposal(SessionProposalEvent? event) {
    if (event == null) return;
    proposals.value = [...proposals.value, event];
  }

  void _onSessionRequest(SessionRequestEvent? event) {
    if (event == null) return;
    pendingRequests.value = [...pendingRequests.value, event];
  }

  Future<void> _refreshSessions() async {
    if (!isInitialized) return;
    sessions.value = _client!.getActiveSessions().values.toList();
  }

  void _removePending(int id) {
    pendingRequests.value =
        pendingRequests.value.where((e) => e.id != id).toList();
  }

  void _removeProposal(String id) {
    proposals.value =
        proposals.value.where((p) => p.id.toString() != id).toList();
  }

  // ------------------- Signing helpers -------------------

  Future<String> _signMessage(String message, String password) async {
    final wallet = await _getWallet(password);
    final privateKey = wallet['privateKey']!;
    final key = web3.EthPrivateKey.fromHex(privateKey);

    // personal_sign expects prefixed message
    final msgBytes = _decodeMessage(message);
    final sig = await key.signPersonalMessage(Uint8List.fromList(msgBytes));
    return '0x${web3crypto.bytesToHex(sig, include0x: false)}';
  }

  Future<String> _signAndSendTransaction(
    Map<String, dynamic> tx,
    String password,
  ) async {
    final wallet = await _getWallet(password);
    final privateKey = wallet['privateKey']!;
    final address = wallet['address']!;

    final network = PolygonWalletService.getNetworkInfo();
    final rpcUrl = network['rpcUrl'] as String;
    final chainId = network['chainId'] as int;

    final client = web3.Web3Client(rpcUrl, http.Client());
    try {
      final key = web3.EthPrivateKey.fromHex(privateKey);

      final to = tx['to'] as String?;
      final dataHex = tx['data'] as String?;
      final valueRaw = tx['value'];
      final gasRaw = tx['gas'] ?? tx['gasLimit'];
      final gasPriceRaw = tx['gasPrice'];
      final nonceRaw = tx['nonce'];
      final chainParam = tx['chainId'];

      // Enforce chain
      if (chainParam != null) {
        final parsedChain = _parseIntLike(chainParam);
        if (parsedChain != chainId) {
          throw Exception(
            'Wrong chainId. Expected $chainId, got $parsedChain. Please switch to Polygon (${network['networkName']}).',
          );
        }
      }

      final value = valueRaw == null
          ? web3.EtherAmount.zero()
          : web3.EtherAmount.fromBigInt(
              web3.EtherUnit.wei,
              _parseBigInt(valueRaw),
            );

      final gasPrice = gasPriceRaw == null
          ? await client.getGasPrice()
          : web3.EtherAmount.fromBigInt(
              web3.EtherUnit.wei,
              _parseBigInt(gasPriceRaw),
            );

      final nonce = nonceRaw == null
          ? await client.getTransactionCount(web3.EthereumAddress.fromHex(address))
          : _parseIntLike(nonceRaw);

      final maxGas = gasRaw == null ? null : _parseIntLike(gasRaw);

      final txData = dataHex == null
          ? null
          : web3crypto.hexToBytes(dataHex.replaceFirst('0x', ''));

      final transaction = web3.Transaction(
        to: to != null ? web3.EthereumAddress.fromHex(to) : null,
        from: web3.EthereumAddress.fromHex(address),
        value: value,
        gasPrice: gasPrice,
        maxGas: maxGas,
        nonce: nonce,
        data: txData,
      );

      final txHash = await client.sendTransaction(
        key,
        transaction,
        chainId: chainId,
      );
      return txHash;
    } finally {
      client.dispose();
    }
  }

  // ------------------- Helpers -------------------

  List<int> _decodeMessage(String message) {
    if (message.startsWith('0x')) {
      return web3crypto.hexToBytes(message);
    }
    return utf8.encode(message);
  }

  BigInt _parseBigInt(dynamic v) {
    if (v is String) {
      final clean = v.startsWith('0x') ? v.substring(2) : v;
      return BigInt.parse(clean, radix: v.startsWith('0x') ? 16 : 10);
    }
    if (v is int) return BigInt.from(v);
    if (v is BigInt) return v;
    throw Exception('Unsupported numeric type: $v');
  }

  int _parseIntLike(dynamic v) {
    if (v is int) return v;
    if (v is BigInt) return v.toInt();
    if (v is String) {
      final clean = v.startsWith('0x') ? v.substring(2) : v;
      return int.parse(clean, radix: v.startsWith('0x') ? 16 : 10);
    }
    throw Exception('Unsupported int type: $v');
  }

  Future<Map<String, String>> _getWallet(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final authResult =
        await PolygonWalletService.authenticateAndDecryptPolygonWallet(
      user.uid,
      password,
    );

    if (authResult['success'] != true) {
      throw Exception(authResult['error'] ?? 'Failed to decrypt wallet');
    }

    final privateKey = authResult['privateKey'] as String?;
    final address = authResult['address'] as String?;

    if (privateKey == null || address == null) {
      throw Exception('Wallet credentials missing');
    }

    return {
      'privateKey': privateKey,
      'address': address,
    };
  }
}
