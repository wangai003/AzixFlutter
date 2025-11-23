import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';

// Web-only imports
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui;

/// ThirdWeb BridgeWidget Integration
/// Uses ThirdWeb's official BridgeWidget Script
class CustomThirdWebOnramp extends StatefulWidget {
  final String walletAddress;
  final String network;
  final VoidCallback? onClose;

  const CustomThirdWebOnramp({
    super.key,
    required this.walletAddress,
    required this.network,
    this.onClose,
  });

  @override
  State<CustomThirdWebOnramp> createState() => _CustomThirdWebOnrampState();
}

class _CustomThirdWebOnrampState extends State<CustomThirdWebOnramp> {
  WebViewController? _controller;
  html.IFrameElement? _iframeElement;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeBridgeWidget();
  }

  @override
  void dispose() {
    if (kIsWeb && _iframeElement != null) {
      _iframeElement!.remove();
    }
    super.dispose();
  }

  void _initializeBridgeWidget() {
    try {
      // Get chain ID
      final chainId = widget.network.contains('amoy') ? 80002 : 137;
      
      // Create HTML with ThirdWeb BridgeWidget Script (exactly as documented)
      final htmlContent = _buildBridgeWidgetHTML(chainId);
      
      if (kIsWeb) {
        // Web: Create standalone HTML page
        final blob = html.Blob([htmlContent], 'text/html');
        final url = html.Url.createObjectUrlFromBlob(blob);
        
        _iframeElement = html.IFrameElement()
          ..src = url
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';
        
        const viewType = 'thirdweb-bridge-widget';
        // ignore: undefined_prefixed_name
        ui.platformViewRegistry.registerViewFactory(
          viewType,
          (int _) => _iframeElement!,
        );
        
        setState(() => _isLoading = false);
        debugPrint('✅ ThirdWeb BridgeWidget loaded (Web)');
      } else {
        // Mobile: Use WebView
        _controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0xFF1A1A1A))
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (_) {
                setState(() => _isLoading = false);
                debugPrint('✅ ThirdWeb BridgeWidget loaded (Mobile)');
              },
              onWebResourceError: (error) {
                debugPrint('❌ Error: ${error.description}');
                setState(() {
                  _error = 'Failed to load widget';
                  _isLoading = false;
                });
              },
            ),
          )
          ..loadHtmlString(htmlContent);
      }
    } catch (e) {
      debugPrint('❌ Error initializing: $e');
      setState(() {
        _error = 'Failed to initialize: $e';
        _isLoading = false;
      });
    }
  }
  
  String _buildBridgeWidgetHTML(int chainId) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>ThirdWeb Pay</title>
  
  <!-- ThirdWeb BridgeWidget Script (Official) -->
  <script src="https://unpkg.com/thirdweb/dist/scripts/bridge-widget.js"></script>
  
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      background-color: #1A1A1A;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      overflow: hidden;
    }
    #bridge-widget-container {
      width: 100vw;
      height: 100vh;
    }
    #loading {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      text-align: center;
      color: #D4AF37;
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
    <p>Loading ThirdWeb...</p>
  </div>
  
  <!-- Container for BridgeWidget -->
  <div id="bridge-widget-container"></div>
  
  <!-- Initialize BridgeWidget (Official Documentation) -->
  <script>
    try {
      const container = document.querySelector('#bridge-widget-container');
      const loading = document.querySelector('#loading');
      
      // Initialize exactly as documented
      BridgeWidget.render(container, {
        clientId: "33d89c360e1ec70249ee4f1e09f8ee2c",
        theme: "dark",
        
        // Configure the "Buy" tab
        buy: {
          chainId: $chainId,
          tokenAddress: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", // Native MATIC
          onSuccess: (quote) => {
            console.log('✅ Purchase successful:', quote);
          },
          onError: (error, quote) => {
            console.error('❌ Purchase error:', error);
          },
          onCancel: (quote) => {
            console.log('⚠️ Purchase cancelled');
          },
        },
        
        // Hide ThirdWeb branding (optional)
        showThirdwebBranding: false,
      });
      
      // Hide loading
      setTimeout(() => {
        if (loading) loading.style.display = 'none';
      }, 2000);
      
      console.log('🌐 ThirdWeb BridgeWidget initialized');
    } catch (error) {
      console.error('❌ BridgeWidget error:', error);
      document.getElementById('loading').innerHTML = 
        '<p style="color: #ff4444;">Error loading widget</p>' +
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
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          // ThirdWeb BridgeWidget - Web
          if (kIsWeb && !_isLoading && _error == null)
            const SizedBox.expand(
              child: HtmlElementView(viewType: 'thirdweb-bridge-widget'),
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
                      'Loading ThirdWeb Pay...',
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

