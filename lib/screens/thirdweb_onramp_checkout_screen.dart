import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/thirdweb_backend_onramp_service.dart';
import '../theme/app_theme.dart';

// Web-only imports
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui;

class ThirdwebOnrampCheckoutScreen extends StatefulWidget {
  const ThirdwebOnrampCheckoutScreen({
    super.key,
    required this.checkoutUrl,
    required this.quoteId,
    this.pollInterval = const Duration(seconds: 10),
    this.timeout = const Duration(minutes: 15),
  });

  final String checkoutUrl;
  final String quoteId;
  final Duration pollInterval;
  final Duration timeout;

  @override
  State<ThirdwebOnrampCheckoutScreen> createState() =>
      _ThirdwebOnrampCheckoutScreenState();
}

class _ThirdwebOnrampCheckoutScreenState
    extends State<ThirdwebOnrampCheckoutScreen> {
  final ThirdwebBackendOnrampService _onrampService =
      ThirdwebBackendOnrampService();

  WebViewController? _webViewController;
  html.IFrameElement? _iframeElement;
  Timer? _pollTimer;
  DateTime? _pollStartedAt;
  bool _isLoading = true;
  bool _isCheckingStatus = false;
  String _status = 'PENDING';
  String? _txHash;
  String? _error;
  String _currentUrl = '';
  static int _viewIdCounter = 0;
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.checkoutUrl;
    _viewType = 'thirdweb-onramp-iframe-${_viewIdCounter++}';

    if (kIsWeb) {
      _setupWebIframe();
    } else {
      _setupMobileWebView();
    }

    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (kIsWeb && _iframeElement != null) {
      _iframeElement!.remove();
    }
    super.dispose();
  }

  void _startPolling() {
    _pollStartedAt = DateTime.now();
    _pollTimer = Timer.periodic(widget.pollInterval, (_) => _checkStatus());
  }

  void _setupWebIframe() {
    _iframeElement = html.IFrameElement()
      ..src = widget.checkoutUrl
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'payment'
      ..setAttribute(
        'sandbox',
        'allow-scripts allow-same-origin allow-forms allow-popups allow-top-navigation',
      );

    ui.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => _iframeElement!,
    );

    // Optional postMessage listener from provider callback pages.
    html.window.onMessage.listen((event) {
      final message = event.data?.toString();
      if (message == null || message.isEmpty) return;
      _currentUrl = message;
      if (message.contains('success') || message.contains('completed')) {
        _checkStatus();
      }
    });

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _setupMobileWebView() {
    try {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              if (!mounted) return;
              setState(() {
                _isLoading = true;
                _currentUrl = url;
              });
            },
            onPageFinished: (url) {
              if (!mounted) return;
              setState(() {
                _isLoading = false;
                _currentUrl = url;
              });
            },
            onWebResourceError: (error) {
              if (!mounted) return;
              setState(() {
                _isLoading = false;
                _error = 'Failed to load checkout: ${error.description}';
              });
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.checkoutUrl));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'In-app webview is not available on this platform: $e';
      });
    }
  }

  Future<void> _checkStatus() async {
    if (_isCheckingStatus || !mounted) return;

    final startedAt = _pollStartedAt;
    if (startedAt != null &&
        DateTime.now().difference(startedAt) >= widget.timeout) {
      _pollTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _error = 'Onramp status check timed out. You can retry from wallet top-up.';
      });
      return;
    }

    _isCheckingStatus = true;
    try {
      final statusResult = await _onrampService.getStatus(widget.quoteId);
      if (!mounted) return;

      setState(() {
        _status = statusResult.status;
        _txHash = statusResult.txHash;
        _error = null;
      });

      if (statusResult.isSuccess || statusResult.isFailed) {
        _pollTimer?.cancel();
        Navigator.of(context).pop({
          'status': statusResult.isSuccess ? 'completed' : 'failed',
          'quoteId': widget.quoteId,
          'txHash': statusResult.txHash,
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Status check failed: $e';
      });
    } finally {
      _isCheckingStatus = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        backgroundColor: AppTheme.darkGrey,
        actions: [
          IconButton(
            onPressed: _refreshCheckout,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Checkout',
          ),
          IconButton(
            onPressed: _checkStatus,
            icon: const Icon(Icons.refresh),
            tooltip: 'Check Status',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: _status == 'SUCCESS'
                ? Colors.green.withOpacity(0.15)
                : _status == 'FAILED'
                    ? Colors.red.withOpacity(0.15)
                    : Colors.orange.withOpacity(0.15),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Status: $_status',
                  style: TextStyle(
                    color: _status == 'SUCCESS'
                        ? Colors.green
                        : _status == 'FAILED'
                            ? Colors.red
                            : Colors.orange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_txHash != null && _txHash!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Tx Hash: $_txHash',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _error!,
                    style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                if (kIsWeb)
                  HtmlElementView(viewType: _viewType),
                if (!kIsWeb && _webViewController != null)
                  WebViewWidget(controller: _webViewController!),
                if (_isLoading)
                  Container(
                    color: AppTheme.black.withOpacity(0.6),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryGold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _refreshCheckout() {
    if (kIsWeb && _iframeElement != null) {
      _iframeElement!.src = widget.checkoutUrl;
      setState(() {
        _isLoading = false;
        _currentUrl = widget.checkoutUrl;
      });
      return;
    }

    _webViewController?.reload();
    setState(() => _isLoading = true);
  }
}

