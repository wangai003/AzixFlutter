import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';

// Web-only imports
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui;

/// MoonPay Payment WebView Widget
/// 
/// Displays the MoonPay checkout page in an in-app webview/iframe
/// instead of redirecting to an external browser.
/// 
/// Features:
/// - Platform-specific: Uses iframe on web, WebView on mobile
/// - URL detection: Detects return URLs for instant status updates
/// - Easy cancel: Close button cancels immediately and returns to previous screen
class MoonPayPaymentWebView extends StatefulWidget {
  final String paymentUrl;
  final String walletAddress;
  final double amountKES;
  final VoidCallback? onPaymentComplete;
  final VoidCallback? onPaymentCancelled;

  const MoonPayPaymentWebView({
    super.key,
    required this.paymentUrl,
    required this.walletAddress,
    this.amountKES = 1000,
    this.onPaymentComplete,
    this.onPaymentCancelled,
  });

  @override
  State<MoonPayPaymentWebView> createState() => _MoonPayPaymentWebViewState();
}

class _MoonPayPaymentWebViewState extends State<MoonPayPaymentWebView> {
  WebViewController? _controller;
  bool _isLoading = true;
  html.IFrameElement? _iframeElement;
  String _currentUrl = '';
  static int _viewIdCounter = 0;
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.paymentUrl;
    _viewType = 'moonpay-iframe-${_viewIdCounter++}';

    if (kIsWeb) {
      _setupWebIframe();
    } else {
      _setupMobileWebView();
    }
  }

  void _setupWebIframe() {
    _iframeElement = html.IFrameElement()
      ..src = widget.paymentUrl
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'payment'
      ..setAttribute('sandbox', 'allow-scripts allow-same-origin allow-forms allow-popups allow-top-navigation');

    // Register the view factory
    ui.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => _iframeElement!,
    );

    // Listen for messages from iframe (for callback detection)
    html.window.onMessage.listen((event) {
      debugPrint('📨 Message from iframe: ${event.data}');
      _handleCallbackUrl(event.data.toString());
    });

    setState(() => _isLoading = false);
  }

  void _setupMobileWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('📄 Page started: $url');
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (url) {
            debugPrint('✅ Page finished: $url');
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
            _handleCallbackUrl(url);
          },
          onWebResourceError: (error) {
            debugPrint('❌ WebView error: ${error.description}');
            setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            debugPrint('🔗 Navigation request: ${request.url}');
            // Check if this is a callback URL
            if (_isCallbackUrl(request.url)) {
              _handleCallbackUrl(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  bool _isCallbackUrl(String url) {
    // Check if the URL is our return URL
    return url.startsWith("myapp://moonpay-return") ||
           url.contains("moonpay-return") ||
           url.contains("moonpay.com/success") ||
           url.contains("moonpay.com/error");
  }

  Future<void> _handleCallbackUrl(String url) async {
    if (url.contains("moonpay.com/success") || 
        url.contains("moonpay-return") && !url.contains("error")) {
      debugPrint('✅ MoonPay payment completed detected!');
      _handlePaymentCompleted();
    } else if (url.contains("moonpay.com/error") || 
               url.contains("cancelled")) {
      debugPrint('❌ MoonPay payment cancelled/failed detected');
      _handlePaymentCancelled();
    }
  }

  /// Handle successful payment
  void _handlePaymentCompleted() {
    debugPrint('✅ MoonPay payment completed!');
    
    // Show success dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success animation
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 56,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Payment Successful!',
              style: TextStyle(
                color: AppTheme.primaryGold,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your USDT will be sent directly to your wallet.',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: AppTheme.grey, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Wallet Address',
                        style: TextStyle(
                          color: AppTheme.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.walletAddress.substring(0, 6)}...${widget.walletAddress.substring(widget.walletAddress.length - 4)}',
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tokens sent via Polygon network',
              style: TextStyle(
                color: AppTheme.primaryGold.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              widget.onPaymentComplete?.call();
              Navigator.pop(context, {
                'status': 'completed',
                'walletAddress': widget.walletAddress,
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  color: AppTheme.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Handle cancelled/failed payment
  void _handlePaymentCancelled() {
    debugPrint('❌ MoonPay payment cancelled');
    
    // Show cancellation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cancel_outlined,
                color: Colors.orange,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Payment Cancelled',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your payment was cancelled. No charges were made.',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, {
                'status': 'cancelled',
              });
            },
            child: Text(
              'Close',
              style: TextStyle(color: AppTheme.primaryGold),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Refresh page to try again
              _refreshPage();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  color: AppTheme.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.darkGrey,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.white),
          onPressed: _cancelPayment,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Buy Crypto',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'KES ${widget.amountKES.toStringAsFixed(0)} → USDT',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.primaryGold,
              ),
            ),
          ],
        ),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.white),
            onPressed: _refreshPage,
            tooltip: 'Refresh',
          ),
          // Security indicator
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Icon(Icons.lock, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Secure',
                  style: AppTheme.bodySmall.copyWith(color: Colors.green),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          if (_isLoading)
            LinearProgressIndicator(
              backgroundColor: AppTheme.darkGrey,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
            ),
          
          // WebView content
          Expanded(
            child: Stack(
              children: [
                // Web implementation (iframe)
                if (kIsWeb)
                  HtmlElementView(viewType: _viewType),

                // Mobile implementation (WebView)
                if (!kIsWeb && _controller != null)
                  WebViewWidget(controller: _controller!),

                // Loading overlay
                if (_isLoading)
                  Container(
                    color: AppTheme.black.withOpacity(0.7),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: AppTheme.primaryGold,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading payment...',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom info bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.darkGrey,
              border: Border(
                top: BorderSide(
                  color: AppTheme.primaryGold.withOpacity(0.3),
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tokens are sent directly to your wallet.',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.primaryGold.withOpacity(0.8),
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Info and cancel button row
                Row(
                  children: [
                    Icon(Icons.security, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Secure payment',
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                      ),
                    ),
                    // Cancel button (easy access)
                    TextButton.icon(
                      onPressed: _cancelPayment,
                      icon: const Icon(Icons.close, size: 16, color: Colors.red),
                      label: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _refreshPage() {
    if (kIsWeb && _iframeElement != null) {
      _iframeElement!.src = widget.paymentUrl;
    } else if (_controller != null) {
      _controller!.reload();
    }
    setState(() => _isLoading = true);
  }

  void _cancelPayment() {
    // Call the cancelled callback
    widget.onPaymentCancelled?.call();
    
    // Navigate back
    Navigator.of(context).pop({
      'status': 'cancelled',
    });
  }

  @override
  void dispose() {
    if (kIsWeb && _iframeElement != null) {
      _iframeElement!.remove();
    }
    super.dispose();
  }
}

/// Shows MoonPay payment in a fullscreen dialog/page
Future<Map<String, dynamic>?> showMoonPayPaymentWebView({
  required BuildContext context,
  required String paymentUrl,
  required String walletAddress,
  double amountKES = 1000,
}) async {
  return await Navigator.of(context).push<Map<String, dynamic>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => MoonPayPaymentWebView(
        paymentUrl: paymentUrl,
        walletAddress: walletAddress,
        amountKES: amountKES,
        onPaymentComplete: () {
          Navigator.pop(context, {
            'status': 'completed',
            'walletAddress': walletAddress,
          });
        },
        onPaymentCancelled: () {
          Navigator.pop(context, {
            'status': 'cancelled',
            'walletAddress': walletAddress,
          });
        },
      ),
    ),
  );
}

