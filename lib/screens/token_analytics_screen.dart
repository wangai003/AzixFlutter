// token_analytics_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import '../models/asset_config.dart';
import '../theme/app_theme.dart';

/// ========== CONFIG ==========
final String _alchemyRpc = "https://polygon-amoy.g.alchemy.com/v2/${ApiConfig.alchemyApiKey}";
final String _alchemyWss = "wss://polygon-amoy.g.alchemy.com/v2/${ApiConfig.alchemyApiKey}";
final String _tokenAddress = (AssetConfigs.akofa.contractAddress ?? "").toLowerCase();

/// The "burn" address commonly used
const String _burnAddress = "0x000000000000000000000000000000000000dead";

/// ========== Helpers ==========
BigInt _hexToBigInt(String? hex) {
  if (hex == null || hex.isEmpty) return BigInt.zero;
  final clean = hex.startsWith("0x") ? hex.substring(2) : hex;
  if (clean.isEmpty) return BigInt.zero;
  try {
    return BigInt.parse(clean, radix: 16);
  } catch (e) {
    return BigInt.zero;
  }
}

double _bigIntToDoubleWithDecimals(BigInt value, int decimals) {
  if (decimals == 0) return value.toDouble();
  final denom = pow(10, decimals);
  return value.toDouble() / denom;
}

/// ERC20 selectors
const String _selectorTotalSupply = "0x18160ddd";
const String _selectorDecimals = "0x313ce567";
const String _selectorName = "0x06fdde03";
const String _selectorSymbol = "0x95d89b41";

/// Transfer event topic
const String _transferTopic =
    "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef";

/// ========== TokenService (Alchemy-only) ==========
class TokenService {
  final String rpcUrl;
  final String wssUrl;
  TokenService({required this.rpcUrl, required this.wssUrl});

  /// Generic eth_call
  Future<String?> _ethCall(String to, String data) async {
    final payload = {
      "jsonrpc": "2.0",
      "id": 1,
      "method": "eth_call",
      "params": [
        {"to": to, "data": data},
        "latest"
      ]
    };

    final res = await http.post(Uri.parse(rpcUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload));

    if (res.statusCode != 200) {
      throw Exception("eth_call failed: ${res.statusCode} ${res.body}");
    }

    final body = jsonDecode(res.body);
    return body["result"] as String?;
  }

  Future<BigInt> getTotalSupply() async {
    final r = await _ethCall(_tokenAddress, _selectorTotalSupply);
    return _hexToBigInt(r);
  }

  Future<int> getDecimals() async {
    final r = await _ethCall(_tokenAddress, _selectorDecimals);
    final bi = _hexToBigInt(r);
    return bi.toInt();
  }

  Future<String> getName() async {
    final r = await _ethCall(_tokenAddress, _selectorName);
    if (r == null || r == "0x") return "";
    try {
      final clean = r.replaceFirst("0x", "");
      final lenHex = clean.substring(64, 128);
      final len = int.parse(lenHex, radix: 16);
      final dataHex = clean.substring(128, 128 + ((len + 31) ~/ 32) * 64);
      final chars = <int>[];
      for (var i = 0; i < len; i++) {
        final byteHex = dataHex.substring(i * 2, i * 2 + 2);
        chars.add(int.parse(byteHex, radix: 16));
      }
      return String.fromCharCodes(chars);
    } catch (e) {
      return AssetConfigs.akofa.name;
    }
  }

  Future<String> getSymbol() async {
    final r = await _ethCall(_tokenAddress, _selectorSymbol);
    if (r == null || r == "0x") return "";
    try {
      final clean = r.replaceFirst("0x", "");
      final lenHex = clean.substring(64, 128);
      final len = int.parse(lenHex, radix: 16);
      final dataHex = clean.substring(128, 128 + ((len + 31) ~/ 32) * 64);
      final chars = <int>[];
      for (var i = 0; i < len; i++) {
        final byteHex = dataHex.substring(i * 2, i * 2 + 2);
        chars.add(int.parse(byteHex, radix: 16));
      }
      return String.fromCharCodes(chars);
    } catch (e) {
      return AssetConfigs.akofa.symbol;
    }
  }

  /// Fetch transfers using alchemy_getAssetTransfers (single page)
  Future<List<dynamic>> getAllTransfers({String fromBlock = "0x0", String toBlock = "latest"}) async {
    final payload = {
      "jsonrpc": "2.0",
      "id": 1,
      "method": "alchemy_getAssetTransfers",
      "params": [
        {
          "fromBlock": fromBlock,
          "toBlock": toBlock,
          "contractAddresses": [_tokenAddress],
          "category": ["erc20"],
          "maxCount": "0x3e8" // 1000 hex
        }
      ]
    };

    final res = await http.post(Uri.parse(rpcUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload));

    if (res.statusCode != 200) {
      throw Exception("alchemy_getAssetTransfers failed: ${res.statusCode}");
    }

    final body = jsonDecode(res.body);
    final result = body["result"];
    if (result == null) return [];
    return (result["transfers"] as List<dynamic>?) ?? [];
  }

  /// Get balanceOf an address (ERC20)
  Future<BigInt> getBalanceOf(String owner) async {
    final addr = owner.toLowerCase().replaceFirst("0x", "").padLeft(64, '0');
    final data = "0x70a08231$addr";
    final r = await _ethCall(_tokenAddress, data);
    return _hexToBigInt(r);
  }

  /// Subscribe to Transfer logs via WebSocket
  WebSocketChannel subscribeToTransferLogs(void Function(Map<String, dynamic>) onEvent) {
    final channel = WebSocketChannel.connect(Uri.parse(wssUrl));

    Timer(const Duration(milliseconds: 200), () {
      final payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "eth_subscribe",
        "params": [
          "logs",
          {
            "address": _tokenAddress,
            "topics": [_transferTopic]
          }
        ]
      };
      channel.sink.add(jsonEncode(payload));
    });

    channel.stream.listen((message) {
      try {
        final m = jsonDecode(message);
        if (m is Map && m.containsKey("params") && m["params"]["result"] != null) {
          final result = m["params"]["result"] as Map<String, dynamic>;
          onEvent(result);
        }
      } catch (e) {
        // ignore parse errors
      }
    }, onError: (err) {
      // handle ws error externally if needed
    });

    return channel;
  }
}

/// ========== Controller (ChangeNotifier) ==========
class TokenAnalyticsController extends ChangeNotifier {
  final TokenService service;

  // state
  String name = "";
  String symbol = "";
  int decimals = 18;
  BigInt totalSupply = BigInt.zero;
  double totalSupplyReadable = 0.0;
  double circulatingSupplyReadable = 0.0;
  int transferCount = 0;
  int holderCount = 0;
  List<Map<String, dynamic>> recentTransfers = [];
  List<Map<String, dynamic>> topHolders = [];
  WebSocketChannel? _ws;
  bool loading = true;
  String error = "";

  TokenAnalyticsController({required this.service});

  Future<void> initialize() async {
    try {
      loading = true;
      error = "";
      notifyListeners();

      // fetch basic metadata
      final futures = await Future.wait([
        service.getName(),
        service.getSymbol(),
        service.getDecimals(),
        service.getTotalSupply(),
      ]);

      name = futures[0] as String;
      symbol = futures[1] as String;
      decimals = futures[2] as int;
      totalSupply = futures[3] as BigInt;
      totalSupplyReadable = _bigIntToDoubleWithDecimals(totalSupply, decimals);

      // compute burn balance and circulating
      final burnBal = await service.getBalanceOf(_burnAddress);
      final burnReadable = _bigIntToDoubleWithDecimals(burnBal, decimals);
      circulatingSupplyReadable = totalSupplyReadable - burnReadable;

      // get transfers and compute transfer count and holders
      final transfers = await service.getAllTransfers();
      transferCount = transfers.length;

      // build set of holders
      final holdersSet = <String>{};
      for (var t in transfers) {
        final from = (t["from"] ?? "").toString().toLowerCase();
        final to = (t["to"] ?? "").toString().toLowerCase();
        if (from.isNotEmpty) holdersSet.add(from);
        if (to.isNotEmpty) holdersSet.add(to);
      }
      holdersSet.remove("0x0000000000000000000000000000000000000000");
      holdersSet.remove(_burnAddress.toLowerCase());
      holderCount = holdersSet.length;

      // build recentTransfers
      recentTransfers = transfers.map<Map<String, dynamic>>((t) {
        final value = t["value"] ?? 0.0;
        final readable = value is num ? value.toDouble() : 0.0;
        return {
          "hash": t["hash"] ?? "",
          "from": t["from"] ?? "",
          "to": t["to"] ?? "",
          "value": readable,
          "raw": t,
          "timestamp": t["metadata"] != null ? t["metadata"]["blockTimestamp"] : null,
        };
      }).take(20).toList();

      // compute top holders
      final holdersList = holdersSet.toList();
      final balances = <Map<String, dynamic>>[];
      final limit = min(200, holdersList.length);
      for (var i = 0; i < limit; i++) {
        final addr = holdersList[i];
        try {
          final bal = await service.getBalanceOf(addr);
          final readable = _bigIntToDoubleWithDecimals(bal, decimals);
          if (readable > 0) {
            balances.add({"address": addr, "balance": readable});
          }
        } catch (e) {
          // ignore individual failures
        }
      }
      balances.sort((a, b) => (b["balance"] as double).compareTo(a["balance"] as double));
      topHolders = balances.take(10).toList();

      // setup websocket subscription for realtime transfer events
      _ws = service.subscribeToTransferLogs((result) async {
        try {
          final data = result;
          final txHash = data["transactionHash"] as String?;
          final topics = (data["topics"] as List<dynamic>?) ?? [];
          String from = "";
          String to = "";
          if (topics.length >= 3) {
            from = "0x${topics[1].toString().substring(26)}";
            to = "0x${topics[2].toString().substring(26)}";
          }
          final amountHex = (data["data"] ?? "0x0") as String;
          final amount = _hexToBigInt(amountHex);
          final valueReadable = _bigIntToDoubleWithDecimals(amount, decimals);

          recentTransfers.insert(0, {
            "hash": txHash ?? "",
            "from": from,
            "to": to,
            "value": valueReadable,
            "raw": data,
            "timestamp": DateTime.now().toIso8601String(),
          });
          if (recentTransfers.length > 50) recentTransfers.removeLast();
          transferCount += 1;
          notifyListeners();
        } catch (e) {
          // ignore
        }
      });

      loading = false;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    try {
      _ws?.sink.close();
    } catch (e) {}
    super.dispose();
  }
}

/// ========== UI Screen ==========
class TokenAnalyticsScreen extends StatelessWidget {
  const TokenAnalyticsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TokenAnalyticsController>(
      create: (_) => TokenAnalyticsController(
        service: TokenService(rpcUrl: _alchemyRpc, wssUrl: _alchemyWss),
      )..initialize(),
      child: Scaffold(
        backgroundColor: AppTheme.black,
        appBar: AppBar(
          title: const Text("Token Analytics", style: TextStyle(color: AppTheme.primaryGold)),
          backgroundColor: AppTheme.darkGrey,
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppTheme.primaryGold),
        ),
        body: const Padding(
          padding: EdgeInsets.all(16.0),
          child: _TokenAnalyticsBody(),
        ),
      ),
    );
  }
}

class _TokenAnalyticsBody extends StatelessWidget {
  const _TokenAnalyticsBody({Key? key}) : super(key: key);

  Widget _card(String title, Widget child) {
    return Card(
      elevation: 4,
      color: AppTheme.darkGrey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryGold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value) {
    return Expanded(
      child: Card(
        elevation: 4,
        color: AppTheme.darkGrey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAddress(String value) {
    if (value.length <= 20) return value;
    return "${value.substring(0, 10)}...${value.substring(value.length - 8)}";
  }

  double _safePercent(double value, double total) {
    if (total <= 0) return 0;
    return (value / total).clamp(0.0, 1.0);
  }

  Widget _legendItem(Color color, String label, String value) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.grey, fontSize: 12),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSupplyVisual(TokenAnalyticsController ctrl) {
    final total = ctrl.totalSupplyReadable;
    final circulating = ctrl.circulatingSupplyReadable.clamp(0, total).toDouble();
    final burned = max(total - circulating, 0).toDouble();
    final slices = [
      _DonutSlice(value: circulating, color: AppTheme.primaryGold),
      _DonutSlice(value: burned, color: AppTheme.red.withOpacity(0.8)),
    ];

    return _card(
      "Supply Composition",
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(140, 140),
                  painter: _DonutChartPainter(
                    backgroundColor: AppTheme.black,
                    slices: slices,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Supply",
                      style: TextStyle(color: AppTheme.grey, fontSize: 11),
                    ),
                    Text(
                      "${(_safePercent(circulating, total) * 100).toStringAsFixed(1)}%",
                      style: const TextStyle(
                        color: AppTheme.primaryGold,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      "circulating",
                      style: TextStyle(color: AppTheme.grey, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                _legendItem(
                  AppTheme.primaryGold,
                  "Circulating",
                  "${circulating.toStringAsFixed(0)} ${ctrl.symbol}",
                ),
                const SizedBox(height: 10),
                _legendItem(
                  AppTheme.red.withOpacity(0.8),
                  "Burned / Locked",
                  "${burned.toStringAsFixed(0)} ${ctrl.symbol}",
                ),
                const SizedBox(height: 10),
                _legendItem(
                  AppTheme.grey,
                  "Total",
                  "${total.toStringAsFixed(0)} ${ctrl.symbol}",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHolderBars(TokenAnalyticsController ctrl) {
    final holders = ctrl.topHolders.take(5).toList();
    final total = ctrl.totalSupplyReadable;

    return _card(
      "Top Holder Distribution",
      holders.isEmpty
          ? const Text("No holder data", style: TextStyle(color: AppTheme.grey))
          : Column(
              children: holders.map((h) {
                final balance = (h['balance'] as double?) ?? 0;
                final widthFactor = _safePercent(balance, total);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatAddress("${h['address']}"),
                              style: const TextStyle(
                                color: AppTheme.white,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          Text(
                            "${(widthFactor * 100).toStringAsFixed(2)}%",
                            style: const TextStyle(
                              color: AppTheme.primaryGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: widthFactor,
                          backgroundColor: AppTheme.black,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildTransferVolumeBars(TokenAnalyticsController ctrl) {
    final bars = ctrl.recentTransfers.take(8).toList().reversed.toList();
    final values = bars.map((e) => (e['value'] as double?) ?? 0).toList();
    final maxValue = values.isEmpty ? 1.0 : max(1.0, values.reduce(max));

    return _card(
      "Recent Transfer Volumes",
      bars.isEmpty
          ? const Text("No transfer data", style: TextStyle(color: AppTheme.grey))
          : SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(bars.length, (index) {
                  final v = values[index];
                  final normalized = (v / maxValue).clamp(0.0, 1.0);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            v.toStringAsFixed(0),
                            style: const TextStyle(color: AppTheme.grey, fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 100 * normalized + 8,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.primaryGold, AppTheme.orange],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "${index + 1}",
                            style: const TextStyle(color: AppTheme.grey, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<TokenAnalyticsController>(context);

    if (ctrl.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGold),
      );
    }

    if (ctrl.error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.red, size: 48),
            const SizedBox(height: 16),
            Text(
              "Error loading analytics",
              style: const TextStyle(color: AppTheme.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              ctrl.error,
              style: const TextStyle(color: AppTheme.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ctrl.initialize(),
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.black,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.analytics, color: AppTheme.primaryGold, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${ctrl.name} (${ctrl.symbol})",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.white,
                      ),
                    ),
                    Text(
                      "Decimals: ${ctrl.decimals}",
                      style: const TextStyle(color: AppTheme.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Top metrics - Supply
          Row(
            children: [
              _metricCard(
                "Total Supply",
                "${ctrl.totalSupplyReadable.toStringAsFixed(0)} ${ctrl.symbol}",
              ),
              const SizedBox(width: 12),
              _metricCard(
                "Circulating",
                "${ctrl.circulatingSupplyReadable.toStringAsFixed(0)} ${ctrl.symbol}",
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Top metrics - Activity
          Row(
            children: [
              _metricCard("Total Transfers", "${ctrl.transferCount}"),
              const SizedBox(width: 12),
              _metricCard("Holders", "${ctrl.holderCount}"),
            ],
          ),
          const SizedBox(height: 24),

          _buildSupplyVisual(ctrl),
          const SizedBox(height: 16),

          _buildTopHolderBars(ctrl),
          const SizedBox(height: 16),

          _buildTransferVolumeBars(ctrl),
          const SizedBox(height: 24),

          // Top Holders
          _card(
            "Top Holders",
            ctrl.topHolders.isEmpty
                ? const Text("No data", style: TextStyle(color: AppTheme.grey))
                : Column(
                    children: ctrl.topHolders.asMap().entries.map((entry) {
                      final index = entry.key;
                      final h = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGold,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  "${index + 1}",
                                  style: const TextStyle(
                                    color: AppTheme.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _formatAddress("${h['address']}"),
                                style: const TextStyle(
                                  color: AppTheme.white,
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            Text(
                              "${(h['balance'] as double).toStringAsFixed(2)} ${ctrl.symbol}",
                              style: const TextStyle(
                                color: AppTheme.primaryGold,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),

          // Recent transfers
          _card(
            "Recent Transfers",
            ctrl.recentTransfers.isEmpty
                ? const Text("No transfers", style: TextStyle(color: AppTheme.grey))
                : Column(
                    children: ctrl.recentTransfers.map((t) {
                      final hash = t['hash'] as String;
                      final shortHash = hash.length > 10
                          ? "${hash.substring(0, 6)}...${hash.substring(hash.length - 4)}"
                          : hash;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.black,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.grey.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.swap_horiz, color: AppTheme.primaryGold, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      shortHash,
                                      style: const TextStyle(
                                        color: AppTheme.primaryGold,
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "${(t['value'] as double).toStringAsFixed(4)} ${ctrl.symbol}",
                                    style: const TextStyle(
                                      color: AppTheme.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text("From:", style: TextStyle(color: AppTheme.grey, fontSize: 11)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      "${t['from']}".substring(0, min(10, "${t['from']}".length)) + "...",
                                      style: const TextStyle(color: AppTheme.white, fontSize: 11, fontFamily: 'monospace'),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Text("To:", style: TextStyle(color: AppTheme.grey, fontSize: 11)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      "${t['to']}".substring(0, min(10, "${t['to']}".length)) + "...",
                                      style: const TextStyle(color: AppTheme.white, fontSize: 11, fontFamily: 'monospace'),
                                    ),
                                  ),
                                ],
                              ),
                              if (t['timestamp'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  "${t['timestamp']}",
                                  style: const TextStyle(color: AppTheme.grey, fontSize: 10),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),

          // Refresh button
          Center(
            child: ElevatedButton.icon(
              onPressed: () async {
                await ctrl.initialize();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Analytics refreshed"),
                    backgroundColor: AppTheme.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text("Refresh Data"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Info notes
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkGrey.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.info_outline, color: AppTheme.primaryGold, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Analytics Notes",
                      style: TextStyle(
                        color: AppTheme.primaryGold,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  "• Live transfer feed via WebSocket for real-time updates",
                  style: TextStyle(color: AppTheme.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                const Text(
                  "• Top holders computed from on-chain balances",
                  style: TextStyle(color: AppTheme.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                const Text(
                  "• Circulating supply excludes burn address holdings",
                  style: TextStyle(color: AppTheme.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                const Text(
                  "• Data sourced from Alchemy on Polygon Amoy testnet",
                  style: TextStyle(color: AppTheme.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _DonutSlice {
  final double value;
  final Color color;
  const _DonutSlice({required this.value, required this.color});
}

class _DonutChartPainter extends CustomPainter {
  final Color backgroundColor;
  final List<_DonutSlice> slices;

  const _DonutChartPainter({
    required this.backgroundColor,
    required this.slices,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.18;
    final rect = Rect.fromCircle(center: center, radius: (size.width / 2) - strokeWidth / 2);
    final total = slices.fold<double>(0, (sum, slice) => sum + max(0, slice.value));

    final basePaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 0, pi * 2, false, basePaint);

    if (total <= 0) return;

    var start = -pi / 2;
    for (final slice in slices) {
      final value = max(0, slice.value);
      if (value <= 0) continue;
      final sweep = (value / total) * pi * 2;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    if (backgroundColor != oldDelegate.backgroundColor) return true;
    if (slices.length != oldDelegate.slices.length) return true;
    for (var i = 0; i < slices.length; i++) {
      if (slices[i].value != oldDelegate.slices[i].value ||
          slices[i].color != oldDelegate.slices[i].color) {
        return true;
      }
    }
    return false;
  }
}

