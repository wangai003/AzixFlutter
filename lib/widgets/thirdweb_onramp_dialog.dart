import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/thirdweb_onramp_service.dart';
import '../theme/app_theme.dart';

/// ThirdWeb Onramp Dialog
/// Displays a WebView with ThirdWeb Pay for fiat-to-crypto onramping
class ThirdWebOnrampDialog extends StatefulWidget {
  final String walletAddress;
  final String network;
  final double? defaultAmount;

  const ThirdWebOnrampDialog({
    super.key,
    required this.walletAddress,
    this.network = 'polygon',
    this.defaultAmount,
  });

  @override
  State<ThirdWebOnrampDialog> createState() => _ThirdWebOnrampDialogState();
}

class _ThirdWebOnrampDialogState extends State<ThirdWebOnrampDialog> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() async {
    try {
      // Check if ThirdWeb is configured
      if (!ThirdWebOnrampService.isConfigured) {
        setState(() {
          _error = 'ThirdWeb client ID not configured';
          _isLoading = false;
        });
        return;
      }

      // Validate wallet address
      if (!ThirdWebOnrampService.isValidAddress(widget.walletAddress)) {
        setState(() {
          _error = 'Invalid wallet address';
          _isLoading = false;
        });
        return;
      }

      // Generate onramp URL
      final onrampUrl = ThirdWebOnrampService.generateSimpleOnrampUrl(
        walletAddress: widget.walletAddress,
        network: widget.network,
        amount: widget.defaultAmount,
      );

      print('🌐 Opening ThirdWeb onramp in external browser: $onrampUrl');

      // ThirdWeb blocks iframe embedding with X-Frame-Options: sameorigin
      // So we MUST open it in an external browser
      await _openInExternalBrowser(onrampUrl);
      
      // Close the dialog immediately as browser handles the flow
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('❌ Error opening ThirdWeb: $e');
      setState(() {
        _error = 'Failed to open payment gateway: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openInExternalBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Force external browser
        );
      } else {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      print('❌ Error launching URL: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: AppTheme.darkGrey,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.black.withOpacity(0.5),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: AppTheme.primaryGold,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Buy Crypto',
                          style: TextStyle(
                            color: AppTheme.primaryGold,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Powered by ThirdWeb',
                          style: TextStyle(
                            color: AppTheme.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.grey),
                    onPressed: () => Navigator.of(context).pop(false),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return _buildError();
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.open_in_browser,
            color: AppTheme.primaryGold,
            size: 64,
          ),
          const SizedBox(height: 24),
          Text(
            'Opening ThirdWeb Pay...',
            style: TextStyle(
              color: AppTheme.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Your browser will open to complete the purchase.\n\nReturn here when done.',
              style: TextStyle(
                color: AppTheme.grey,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(
            color: AppTheme.primaryGold,
          ),
        ],
      ),
    );
  }


  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Payment Gateway',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: TextStyle(
                color: AppTheme.grey,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _error = null;
                  _isLoading = true;
                });
                _initializeWebView();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

