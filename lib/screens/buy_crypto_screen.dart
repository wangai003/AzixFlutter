import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Web-only imports
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// Correct import for Flutter Web's platformViewRegistry
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui;

class BuyCryptoScreen extends StatefulWidget {
  final String walletAddress; // user's Stellar/USDC wallet

  const BuyCryptoScreen({Key? key, required this.walletAddress})
    : super(key: key);

  @override
  State<BuyCryptoScreen> createState() => _BuyCryptoScreenState();
}

class _BuyCryptoScreenState extends State<BuyCryptoScreen> {
  WebViewController? _controller; // Used only on mobile
  bool _isLoading = true;
  String? _errorMessage;
  html.IFrameElement? _iframeElement;
  int _modalDepth = 0;

  void _updateIframePointerEvents() {
    if (kIsWeb && _iframeElement != null) {
      _iframeElement!.style.pointerEvents = _modalDepth > 0 ? 'none' : 'auto';
    }
  }

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      // Create and register the iframe view for web
      // MoonPay public API key
      const String apiKey = "pk_test_8n0yHcXcuwicKpL379JJzKDULiHx5nZw";

      // Example: allow user to buy 50 USD worth of USDC
      final String url = Uri.https('buy.moonpay.com', '', {
        'apiKey': apiKey,
        'currencyCode': 'usdc', // the crypto asset
        'baseCurrencyCode': 'usd',
        'baseCurrencyAmount': '50',
        'walletAddress': widget.walletAddress,
        'redirectURL': 'https://yourapp.com/payment-success', // optional
      }).toString();

      _iframeElement = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';

      const viewType = 'moonpay-iframe';
      ui.platformViewRegistry.registerViewFactory(
        viewType,
        (int _) => _iframeElement!,
      );

      _isLoading = false; // iframe loads independently
    } else {
      // Mobile WebView setup
      _initializeWebView();
    }
  }

  void _initializeWebView() {
    // MoonPay public API key
    const String apiKey = "pk_test_8n0yHcXcuwicKpL379JJzKDULiHx5nZw";

    // Example: allow user to buy 50 USD worth of USDC
    final String url = Uri.https('buy.moonpay.com', '', {
      'apiKey': apiKey,
      'currencyCode': 'usdc', // the crypto asset
      'baseCurrencyCode': 'usd',
      'baseCurrencyAmount': '50',
      'walletAddress': widget.walletAddress,
      'redirectURL': 'https://yourapp.com/payment-success', // optional
    }).toString();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (error) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Failed to load MoonPay: ${error.description}';
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  void dispose() {
    if (kIsWeb && _iframeElement != null) {
      // Remove the iframe element from the DOM when disposing
      _iframeElement!.remove();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Buy Crypto'),
            backgroundColor: Colors.black87,
          ),
          body: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: [
                // Web implementation
                if (kIsWeb)
                  SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: const HtmlElementView(viewType: 'moonpay-iframe'),
                  ),

                // Mobile implementation
                if (!kIsWeb && _controller != null)
                  SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: WebViewWidget(controller: _controller!),
                  ),

                // Loading indicator
                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.8),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Loading MoonPay...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Error message
                if (_errorMessage != null && !_isLoading)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _errorMessage = null;
                              });
                              if (kIsWeb) {
                                // For web, we need to recreate the iframe
                                if (_iframeElement != null) {
                                  _iframeElement!.remove();
                                }
                                initState();
                              } else {
                                _initializeWebView();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Overlay to prevent interaction with web content when modals are shown
                if (kIsWeb && _modalDepth > 0)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap:
                          () {}, // Absorb taps to prevent interaction with iframe
                      behavior: HitTestBehavior.opaque,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
