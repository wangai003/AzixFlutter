import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
import '../services/thirdweb_onramp_service.dart';
import '../theme/app_theme.dart';

// Web-only imports
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui;

/// ThirdWeb Bridge Widget - In-App Onramp
/// Uses ThirdWeb's BridgeWidget Script for seamless in-app crypto purchases
class ThirdWebBridgeWidget extends StatefulWidget {
  final String walletAddress;
  final String network;
  final double? defaultAmount;
  final VoidCallback? onClose;

  const ThirdWebBridgeWidget({
    super.key,
    required this.walletAddress,
    required this.network,
    this.defaultAmount,
    this.onClose,
  });

  @override
  State<ThirdWebBridgeWidget> createState() => _ThirdWebBridgeWidgetState();
}

class _ThirdWebBridgeWidgetState extends State<ThirdWebBridgeWidget> {
  WebViewController? _controller; // Nullable for web
  html.IFrameElement? _iframeElement; // For web platform
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeBridgeWidget();
  }

  @override
  void dispose() {
    // Clean up iframe on web
    if (kIsWeb && _iframeElement != null) {
      _iframeElement!.remove();
    }
    super.dispose();
  }

  void _initializeBridgeWidget() {
    try {
      // Get network configuration
      final networkConfig = ThirdWebOnrampService.supportedNetworks[widget.network];
      if (networkConfig == null) {
        setState(() {
          _error = 'Unsupported network: ${widget.network}';
          _isLoading = false;
        });
        return;
      }

      final clientId = ThirdWebOnrampService.clientId;
      final chainId = networkConfig['chainId']!;
      final tokenSymbol = networkConfig['symbol']!;

      // Create HTML with ThirdWeb BridgeWidget Script
      final htmlContent = _buildBridgeWidgetHtml(
        clientId: clientId,
        walletAddress: widget.walletAddress,
        chainId: chainId,
        tokenSymbol: tokenSymbol,
        amount: widget.defaultAmount,
      );

      if (kIsWeb) {
        // Web platform: Use iframe with data URL
        _iframeElement = html.IFrameElement()
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..src = 'data:text/html;charset=utf-8,${Uri.encodeComponent(htmlContent)}';

        // Register the iframe view
        const viewType = 'thirdweb-bridge-iframe';
        // ignore: undefined_prefixed_name
        ui.platformViewRegistry.registerViewFactory(
          viewType,
          (int _) => _iframeElement!,
        );

        setState(() => _isLoading = false);
        debugPrint('✅ ThirdWeb Bridge Widget loaded (Web)');
      } else {
        // Mobile platform: Use WebViewController
        _controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0xFF1A1A1A))
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (String url) {
                debugPrint('📄 ThirdWeb Bridge Widget loading...');
              },
              onPageFinished: (String url) {
                debugPrint('✅ ThirdWeb Bridge Widget loaded (Mobile)');
                setState(() => _isLoading = false);
              },
              onWebResourceError: (WebResourceError error) {
                debugPrint('❌ ThirdWeb Bridge Widget error: ${error.description}');
                setState(() {
                  _error = 'Failed to load: ${error.description}';
                  _isLoading = false;
                });
              },
            ),
          )
          ..loadHtmlString(htmlContent);
      }
    } catch (e) {
      debugPrint('❌ Error initializing ThirdWeb Bridge Widget: $e');
      setState(() {
        _error = 'Failed to initialize: $e';
        _isLoading = false;
      });
    }
  }

  String _buildBridgeWidgetHtml({
    required String clientId,
    required String walletAddress,
    required String chainId,
    required String tokenSymbol,
    double? amount,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>ThirdWeb Pay</title>
  
  <!-- ThirdWeb BridgeWidget Script -->
  <script src="https://unpkg.com/thirdweb/dist/scripts/bridge-widget.js"></script>
  
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
      background-color: #1A1A1A;
      color: #FFFFFF;
      overflow: hidden;
      width: 100vw;
      height: 100vh;
    }
    
    #bridge-widget-container {
      width: 100%;
      height: 100%;
      display: flex;
      justify-content: center;
      align-items: center;
    }
    
    #loading {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      text-align: center;
    }
    
    .spinner {
      border: 3px solid #333;
      border-top: 3px solid #D4AF37;
      border-radius: 50%;
      width: 40px;
      height: 40px;
      animation: spin 1s linear infinite;
      margin: 0 auto 16px;
    }
    
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
  </style>
</head>
<body>
  <div id="loading">
    <div class="spinner"></div>
    <p>Loading ThirdWeb Pay...</p>
  </div>
  
  <div id="bridge-widget-container"></div>
  
  <script>
    try {
      const container = document.querySelector('#bridge-widget-container');
      const loading = document.querySelector('#loading');
      
      // Initialize ThirdWeb BridgeWidget
      BridgeWidget.render(container, {
        clientId: "$clientId",
        theme: "dark",
        
        // Prefill destination wallet
        toAddress: "$walletAddress",
        
        // Prefill chain
        toChain: $chainId,
        
        // Prefill token
        toToken: "$tokenSymbol",
        
        ${amount != null ? '// Prefill amount\n        toAmount: "$amount",' : ''}
        
        // Event callbacks
        onSuccess: (data) => {
          console.log('✅ Purchase successful:', data);
          // Send message to Flutter (if needed)
          if (window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('onSuccess', data);
          }
        },
        
        onError: (error) => {
          console.error('❌ Purchase error:', error);
          if (window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('onError', error);
          }
        },
        
        onCancel: () => {
          console.log('⚠️ Purchase cancelled');
          if (window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('onCancel');
          }
        },
      });
      
      // Hide loading spinner
      setTimeout(() => {
        loading.style.display = 'none';
      }, 2000);
      
      console.log('🌐 ThirdWeb BridgeWidget initialized');
      
    } catch (error) {
      console.error('❌ Error initializing BridgeWidget:', error);
      document.getElementById('loading').innerHTML = 
        '<p style="color: #ff4444;">Error loading payment widget</p>' +
        '<p style="font-size: 12px; margin-top: 8px;">' + error.message + '</p>';
    }
  </script>
</body>
</html>
    ''';
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
          // ThirdWeb BridgeWidget - Web
          if (kIsWeb && !_isLoading && _error == null)
            const SizedBox.expand(
              child: HtmlElementView(viewType: 'thirdweb-bridge-iframe'),
            ),

          // ThirdWeb BridgeWidget - Mobile
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
                          _initializeBridgeWidget();
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

