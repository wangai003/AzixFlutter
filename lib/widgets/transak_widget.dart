import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';

// Web-only imports
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui;

/// Transak Onramp Widget - In-App Crypto Purchase
/// More reliable than ThirdWeb for iframe embedding
class TransakWidget extends StatefulWidget {
  final String walletAddress;
  final String network;
  final double? defaultAmount;
  final VoidCallback? onClose;

  const TransakWidget({
    super.key,
    required this.walletAddress,
    required this.network,
    this.defaultAmount,
    this.onClose,
  });

  @override
  State<TransakWidget> createState() => _TransakWidgetState();
}

class _TransakWidgetState extends State<TransakWidget> {
  WebViewController? _controller;
  html.IFrameElement? _iframeElement;
  bool _isLoading = true;
  String? _error;

  // Transak Configuration
  static const String _apiKey = 'YOUR_TRANSAK_API_KEY'; // TODO: Get from transak.com
  static const String _environment = 'STAGING'; // Use 'PRODUCTION' for live

  @override
  void initState() {
    super.initState();
    _initializeTransak();
  }

  @override
  void dispose() {
    if (kIsWeb && _iframeElement != null) {
      _iframeElement!.remove();
    }
    super.dispose();
  }

  void _initializeTransak() {
    try {
      // Map network to Transak format
      final transakNetwork = _getTransakNetwork(widget.network);
      
      // Build Transak URL
      final transakUrl = _buildTransakUrl(
        walletAddress: widget.walletAddress,
        network: transakNetwork,
        amount: widget.defaultAmount,
      );

      debugPrint('🌐 Loading Transak: $transakUrl');

      if (kIsWeb) {
        // Web: Use iframe (no data URL issues!)
        _iframeElement = html.IFrameElement()
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..src = transakUrl; // Direct URL - no data: prefix!

        const viewType = 'transak-iframe';
        // ignore: undefined_prefixed_name
        ui.platformViewRegistry.registerViewFactory(
          viewType,
          (int _) => _iframeElement!,
        );

        setState(() => _isLoading = false);
        debugPrint('✅ Transak loaded (Web)');
      } else {
        // Mobile: Use WebView
        _controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0xFF1A1A1A))
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (String url) {
                debugPrint('📄 Transak loading...');
              },
              onPageFinished: (String url) {
                debugPrint('✅ Transak loaded (Mobile)');
                setState(() => _isLoading = false);
              },
              onWebResourceError: (WebResourceError error) {
                debugPrint('❌ Transak error: ${error.description}');
                setState(() {
                  _error = 'Failed to load: ${error.description}';
                  _isLoading = false;
                });
              },
            ),
          )
          ..loadRequest(Uri.parse(transakUrl));
      }
    } catch (e) {
      debugPrint('❌ Error initializing Transak: $e');
      setState(() {
        _error = 'Failed to initialize: $e';
        _isLoading = false;
      });
    }
  }

  String _getTransakNetwork(String network) {
    // Transak network mapping
    if (network.contains('polygon') || network.contains('amoy')) {
      return 'polygon';
    }
    return 'polygon'; // Default to polygon
  }

  String _buildTransakUrl({
    required String walletAddress,
    required String network,
    double? amount,
  }) {
    final params = {
      'apiKey': _apiKey,
      'environment': widget.network.contains('amoy') ? 'STAGING' : _environment,
      'defaultCryptoCurrency': 'MATIC',
      'cryptoCurrencyList': 'MATIC',
      'defaultNetwork': network,
      'networks': network,
      'walletAddress': walletAddress,
      'themeColor': 'D4AF37', // Your gold color
      'hideMenu': 'true',
      'isFeeCalculationHidden': 'false',
      'disableWalletAddressForm': 'true',
    };

    if (amount != null) {
      params['defaultFiatAmount'] = amount.toStringAsFixed(2);
    }

    final uri = Uri.https('global.transak.com', '/', params);
    return uri.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.darkGrey,
        elevation: 0,
        title: const Text(
          'Buy Crypto',
          style: TextStyle(color: AppTheme.primaryGold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.grey),
          onPressed: () {
            widget.onClose?.call();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Stack(
        children: [
          // Transak Widget - Web
          if (kIsWeb && !_isLoading && _error == null)
            const SizedBox.expand(
              child: HtmlElementView(viewType: 'transak-iframe'),
            ),

          // Transak Widget - Mobile
          if (!kIsWeb && !_isLoading && _error == null && _controller != null)
            SizedBox.expand(
              child: WebViewWidget(controller: _controller!),
            ),

          // Loading indicator
          if (_isLoading)
            Container(
              color: AppTheme.darkGrey,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: AppTheme.primaryGold,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading payment gateway...',
                      style: TextStyle(
                        color: AppTheme.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Error display
          if (_error != null)
            Container(
              color: AppTheme.darkGrey,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red.shade400,
                        size: 64,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Error',
                        style: TextStyle(
                          color: AppTheme.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: AppTheme.grey,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _error = null;
                            _isLoading = true;
                          });
                          _initializeTransak();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold,
                          foregroundColor: AppTheme.darkGrey,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

