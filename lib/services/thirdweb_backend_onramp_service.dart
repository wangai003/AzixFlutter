import 'dart:convert';
import 'package:http/http.dart' as http;

class ThirdwebBackendOnrampService {
  ThirdwebBackendOnrampService({String? backendBaseUrl})
      : _backendBaseUrl = backendBaseUrl ??
            const String.fromEnvironment(
              'AZIX_BACKEND_URL',
              defaultValue: 'https://azix-flutter.vercel.app',
            );

  final String _backendBaseUrl;

  static const String nativeTokenAddress =
      '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
  static const String polygonUsdcTokenAddress =
      '0x3c499c542cef5e3811e1192ce70d8cc03d5c3359';

  Future<OnrampSession> prepareOnramp({
    required String walletAddress,
    required String amount,
    required int chainId,
    String tokenAddress = polygonUsdcTokenAddress,
  }) async {
    final response = await http.post(
      Uri.parse('$_backendBaseUrl/api/onramp/prepare'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'walletAddress': walletAddress,
        'amount': amount,
        'chainId': chainId,
        'tokenAddress': tokenAddress,
      }),
    );

    final body = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractError(body) ?? 'Failed to prepare onramp session');
    }

    final link = _pickString([
      body['link'],
      body['checkoutLink'],
      body['url'],
      body['data'] is Map<String, dynamic> ? body['data']['link'] : null,
      body['result'] is Map<String, dynamic> ? body['result']['link'] : null,
    ]);
    final quoteId = _pickString([
      body['quoteId'],
      body['id'],
      body['data'] is Map<String, dynamic> ? body['data']['quoteId'] : null,
      body['data'] is Map<String, dynamic> ? body['data']['id'] : null,
      body['result'] is Map<String, dynamic> ? body['result']['quoteId'] : null,
      body['result'] is Map<String, dynamic> ? body['result']['id'] : null,
    ]);
    if (link == null || link.isEmpty || quoteId == null || quoteId.isEmpty) {
      throw Exception('Backend response missing checkout link or quoteId');
    }

    return OnrampSession(checkoutUrl: link, quoteId: quoteId);
  }

  Future<OnrampStatusResult> getStatus(String quoteId) async {
    final response = await http.get(
      Uri.parse('$_backendBaseUrl/api/onramp/status/$quoteId'),
    );

    final body = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractError(body) ?? 'Failed to fetch onramp status');
    }

    final status = (body['status'] as String? ?? 'PENDING').toUpperCase();
    return OnrampStatusResult(
      status: status,
      txHash: body['txHash'] as String?,
      rawStatus: body['rawStatus'] as String?,
    );
  }

  Map<String, dynamic> _decodeJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{};
  }

  String? _extractError(Map<String, dynamic> body) {
    final error = body['error'];
    if (error is String) return error;
    if (error is Map<String, dynamic>) {
      return error['message']?.toString() ?? error.toString();
    }
    return null;
  }

  String? _pickString(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }
}

class OnrampSession {
  OnrampSession({
    required this.checkoutUrl,
    required this.quoteId,
  });

  final String checkoutUrl;
  final String quoteId;
}

class OnrampStatusResult {
  OnrampStatusResult({
    required this.status,
    this.txHash,
    this.rawStatus,
  });

  final String status;
  final String? txHash;
  final String? rawStatus;

  bool get isSuccess => status == 'SUCCESS' || status == 'COMPLETED';
  bool get isFailed => status == 'FAILED';
}

