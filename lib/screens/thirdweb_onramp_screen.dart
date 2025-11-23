import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/thirdweb_onramp_service.dart';

// Web-only imports
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui;

/// Screen for thirdweb on-ramp integration
/// Allows users to buy crypto directly to their Polygon wallet
class ThirdwebOnRampScreen extends StatefulWidget {
  final String walletAddress; // User's Polygon wallet address (0x...)
  final String? tokenAddress; // Optional token contract address (null for MATIC)
  final String? amount; // Optional pre-filled amount
  final int chainId; // Polygon chain ID (137 for mainnet, 80002 for Amoy)

  const ThirdwebOnRampScreen({
    Key? key,
    required this.walletAddress,
    this.tokenAddress,
    this.amount,
    this.chainId = 137, // Default to Polygon mainnet
  }) : super(key: key);

  @override
  State<ThirdwebOnRampScreen> createState() => _ThirdwebOnRampScreenState();
}

class _ThirdwebOnRampScreenState extends State<ThirdwebOnRampScreen> {
  WebViewController? _controller; // Used only on mobile
  bool _isLoading = true;
  String? _errorMessage;
  html.IFrameElement? _iframeElement;

  @override
  void initState() {
    super.initState();

    // Validate wallet address
    if (!ThirdwebOnRampService.isValidPolygonAddress(widget.walletAddress)) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid Polygon wallet address';
      });
      return;
    }

    // Check if thirdweb is configured
    if (!ThirdwebOnRampService.isConfigured()) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Thirdweb client ID not configured. Please set it in thirdweb_onramp_service.dart';
      });
      return;
    }

    if (kIsWeb) {
      _initializeWebView();
    } else {
      _initializeMobileWebView();
    }
  }

  void _initializeWebView() {
    try {
      // Generate thirdweb on-ramp URL
      final String url = widget.tokenAddress != null
          ? ThirdwebOnRampService.generateTokenOnRampUrl(
              walletAddress: widget.walletAddress,
              tokenAddress: widget.tokenAddress!,
              chainId: widget.chainId,
              amount: widget.amount,
              theme: 'dark',
            )
          : ThirdwebOnRampService.generateOnRampUrl(
              walletAddress: widget.walletAddress,
              chainId: widget.chainId,
              amount: widget.amount,
              theme: 'dark',
            );

      _iframeElement = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';

      const viewType = 'thirdweb-onramp-iframe';
      ui.platformViewRegistry.registerViewFactory(
        viewType,
        (int _) => _iframeElement!,
      );

      _isLoading = false; // iframe loads independently
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize thirdweb on-ramp: $e';
      });
    }
  }

  void _initializeMobileWebView() {
    try {
      // Generate thirdweb on-ramp URL
      final String url = widget.tokenAddress != null
          ? ThirdwebOnRampService.generateTokenOnRampUrl(
              walletAddress: widget.walletAddress,
              tokenAddress: widget.tokenAddress!,
              chainId: widget.chainId,
              amount: widget.amount,
              theme: 'dark',
            )
          : ThirdwebOnRampService.generateOnRampUrl(
              walletAddress: widget.walletAddress,
              chainId: widget.chainId,
              amount: widget.amount,
              theme: 'dark',
            );

      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) => setState(() => _isLoading = true),
            onPageFinished: (_) => setState(() => _isLoading = false),
            onWebResourceError: (error) {
              setState(() {
                _isLoading = false;
                _errorMessage =
                    'Failed to load thirdweb on-ramp: ${error.description}';
              });
            },
            onNavigationRequest: (NavigationRequest request) {
              // Allow navigation within thirdweb domain
              if (request.url.contains('thirdweb.com') ||
                  request.url.contains('pay.thirdweb.com')) {
                return NavigationDecision.navigate;
              }
              // Allow navigation for payment providers
              if (request.url.contains('moonpay.com') ||
                  request.url.contains('transak.com') ||
                  request.url.contains('stripe.com')) {
                return NavigationDecision.navigate;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(url));
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize thirdweb on-ramp: $e';
      });
    }
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (kIsWeb) {
      if (_iframeElement != null) {
        _iframeElement!.remove();
      }
      _initializeWebView();
    } else {
      _initializeMobileWebView();
    }
  }

  @override
  void dispose() {
    if (kIsWeb && _iframeElement != null) {
      _iframeElement!.remove();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buy Crypto'),
        backgroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: [
                // Web implementation
                if (kIsWeb && _iframeElement != null)
                  SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: const HtmlElementView(viewType: 'thirdweb-onramp-iframe'),
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
                            'Loading thirdweb on-ramp...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Error message
                if (_errorMessage != null && !_isLoading)
                  Container(
                    color: Colors.black,
                    child: Center(
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _retry,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
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
        },
      ),
    );
  }
}

