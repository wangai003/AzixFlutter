import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';

import '../services/moonpay_service.dart';
import '../providers/stellar_provider.dart';
import '../theme/app_theme.dart';

class BuyCryptoScreen extends StatefulWidget {
  const BuyCryptoScreen({Key? key}) : super(key: key);

  @override
  State<BuyCryptoScreen> createState() => _BuyCryptoScreenState();
}

class _BuyCryptoScreenState extends State<BuyCryptoScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Initialize WebView controller
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (error) {
            setState(() {
              _isLoading = false;
              _errorMessage =
                  'Failed to load MoonPay widget: ${error.description}';
            });
          },
        ),
      );

    // Load MoonPay widget URL
    _loadMoonPayWidget();
  }

  void _loadMoonPayWidget() async {
    try {
      final stellarProvider = Provider.of<StellarProvider>(
        context,
        listen: false,
      );

      if (stellarProvider.publicKey == null) {
        setState(() {
          _errorMessage =
              'No wallet address available. Please create a wallet first.';
          _isLoading = false;
        });
        return;
      }

      // Generate MoonPay widget URL using the service
      final url = MoonPayService.generateEnhancedWidgetUrl(
        walletAddress: stellarProvider.publicKey!,
        currencyCode: 'usdc', // Default to USDC
        baseCurrencyCode: 'usd',
        baseCurrencyAmount: 50.0, // Default amount
        theme: 'dark',
        language: 'en',
        redirectURL: 'azix://wallet', // Custom URL scheme for app redirect
      );

      await _controller.loadRequest(Uri.parse(url));
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize MoonPay: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buy Crypto'),
        backgroundColor: AppTheme.black,
        foregroundColor: AppTheme.primaryGold,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              _loadMoonPayWidget();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_errorMessage != null)
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
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _errorMessage = null;
                        });
                        _loadMoonPayWidget();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGold,
                        foregroundColor: AppTheme.black,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else
            WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: AppTheme.black.withOpacity(0.8),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryGold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading MoonPay...',
                      style: TextStyle(color: AppTheme.primaryGold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
