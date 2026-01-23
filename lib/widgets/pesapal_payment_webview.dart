import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';
import '../services/pesapal_service.dart';

// Web-only imports
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui;

/// PesaPal Payment WebView Widget
/// 
/// Displays the PesaPal payment page in an in-app webview/iframe
/// instead of redirecting to an external browser.
/// 
/// Features:
/// - Auto-polling: Automatically checks payment status every 8 seconds
/// - Easy cancel: Close button cancels immediately and returns to previous screen
/// - URL detection: Detects callback URLs for instant status updates
class PesapalPaymentWebView extends StatefulWidget {
  final String paymentUrl;
  final String orderTrackingId;
  final double amount;
  final double tokenAmount; // Token amount to receive
  final String tokenSymbol; // Token type (AKOFA, USDC, USDT)
  final String currency;
  final VoidCallback? onPaymentComplete;
  final VoidCallback? onPaymentCancelled;
  
  // Legacy field for backward compatibility
  double get akofaAmount => tokenSymbol == 'AKOFA' ? tokenAmount : 0.0;

  const PesapalPaymentWebView({
    super.key,
    required this.paymentUrl,
    required this.orderTrackingId,
    required this.amount,
    required this.tokenAmount,
    this.tokenSymbol = 'AKOFA',
    this.currency = 'KES',
    this.onPaymentComplete,
    this.onPaymentCancelled,
  });

  @override
  State<PesapalPaymentWebView> createState() => _PesapalPaymentWebViewState();
}

class _PesapalPaymentWebViewState extends State<PesapalPaymentWebView> {
  WebViewController? _controller;
  bool _isLoading = true;
  html.IFrameElement? _iframeElement;
  String _currentUrl = '';
  static int _viewIdCounter = 0;
  late String _viewType;
  
  String _paymentStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.paymentUrl;
    _viewType = 'pesapal-iframe-${_viewIdCounter++}';

    if (kIsWeb) {
      _setupWebIframe();
    } else {
      _setupMobileWebView();
    }
    
  }
  
  /// Handle successful payment - show success screen with transaction details
  void _handlePaymentCompleted({
    String? txHash,
    double? tokenAmount,
    String? tokenSymbol,
    String? explorerUrl,
  }) {
    _statusPollTimer?.cancel();
    setState(() => _paymentStatus = 'completed');
    
    final displayAmount = tokenAmount ?? widget.tokenAmount;
    final displaySymbol = tokenSymbol ?? widget.tokenSymbol;
    final decimals = displaySymbol == 'AKOFA' ? 2 : 6;
    
    debugPrint('✅ Payment completed! $displaySymbol: $displayAmount, TxHash: $txHash');
    
    // Show success dialog with transaction details
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
            // Token amount with symbol
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGold.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          displaySymbol,
                          style: TextStyle(
                            color: AppTheme.primaryGold,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        displayAmount.toStringAsFixed(decimals),
                        style: TextStyle(
                          color: AppTheme.primaryGold,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'credited to your wallet',
                    style: TextStyle(
                      color: AppTheme.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Transaction details with hash
            if (txHash != null && txHash.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long, color: AppTheme.grey, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Transaction Hash',
                          style: TextStyle(
                            color: AppTheme.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      txHash.length > 20 
                        ? '${txHash.substring(0, 10)}...${txHash.substring(txHash.length - 8)}'
                        : txHash,
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              widget.onPaymentComplete?.call();
              Navigator.pop(context, {
                'status': 'completed',
                'orderTrackingId': widget.orderTrackingId,
                'txHash': txHash,
                'tokenAmount': displayAmount,
                'tokenSymbol': displaySymbol,
                // Legacy field for backward compatibility
                'akofaAmount': displaySymbol == 'AKOFA' ? displayAmount : 0.0,
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
  
  /// Handle failed payment
  void _handlePaymentFailed({String? errorMessage}) {
    _statusPollTimer?.cancel();
    setState(() => _paymentStatus = 'failed');
    
    final message = errorMessage ?? 'Payment failed. Please try again.';
    debugPrint('❌ Payment failed: $message');
    
    // Show error dialog
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
                color: Colors.red.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Payment Failed',
              style: TextStyle(
                color: Colors.red,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
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
                'status': 'failed',
                'orderTrackingId': widget.orderTrackingId,
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
              // Reset and try again
              setState(() {
                _paymentStatus = 'pending';
                _pollCount = 0;
              });
              _refreshPage();
              _startStatusPolling();
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
    // Check if the URL is our callback URL
    return url.contains('/pesapal/callback') ||
           url.contains('status=completed') ||
           url.contains('status=cancelled') ||
           url.contains('status=failed') ||
           url.contains('OrderTrackingId');
  }

  Future<void> _handleCallbackUrl(String url) async {
    if (url.contains('status=completed') || 
        url.contains('pesapal/callback') && url.contains('OrderTrackingId')) {
      debugPrint('✅ Payment completed detected! Closing webview...');
      widget.onPaymentComplete?.call();
    } else if (url.contains('status=cancelled') || url.contains('status=failed')) {
      debugPrint('❌ Payment cancelled/failed detected');
      widget.onPaymentCancelled?.call();
    }
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
              'Complete Payment',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${widget.currency} ${widget.amount.toStringAsFixed(0)} → ${widget.akofaAmount.toStringAsFixed(2)} AKOFA',
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
                            'Loading PesaPal...',
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
                  'Payment status is confirmed by PesaPal IPN.',
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
                        'Secure payment via PesaPal',
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
    
    // Navigate back to the main navigation (wallet screen)
    // Pop all routes until we reach the first route (main navigation)
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _checkPaymentStatus() {
    // Navigate back with a flag to check status
    Navigator.pop(context, {'checkStatus': true, 'orderTrackingId': widget.orderTrackingId});
  }

  @override
  void dispose() {
    if (kIsWeb && _iframeElement != null) {
      _iframeElement!.remove();
    }
    super.dispose();
  }
}

/// Shows PesaPal payment in a fullscreen dialog/page
Future<Map<String, dynamic>?> showPesapalPaymentWebView({
  required BuildContext context,
  required String paymentUrl,
  required String orderTrackingId,
  required double amount,
  required double tokenAmount,
  String tokenSymbol = 'AKOFA',
  String currency = 'KES',
}) async {
  return await Navigator.of(context).push<Map<String, dynamic>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => PesapalPaymentWebView(
        paymentUrl: paymentUrl,
        orderTrackingId: orderTrackingId,
        amount: amount,
        tokenAmount: tokenAmount,
        tokenSymbol: tokenSymbol,
        currency: currency,
        onPaymentComplete: () {
          Navigator.pop(context, {
            'status': 'completed',
            'orderTrackingId': orderTrackingId,
          });
        },
        onPaymentCancelled: () {
          Navigator.pop(context, {
            'status': 'cancelled',
            'orderTrackingId': orderTrackingId,
          });
        },
      ),
    ),
  );
}

