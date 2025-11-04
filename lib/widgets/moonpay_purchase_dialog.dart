import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/moonpay_service.dart';
import '../theme/ultra_modern_theme.dart';
import '../widgets/ultra_modern_widgets.dart';
import '../widgets/moonpay_button.dart';
import '../providers/enhanced_wallet_provider.dart';

class MoonPayPurchaseDialog extends StatefulWidget {
  final EnhancedWalletProvider walletProvider;

  const MoonPayPurchaseDialog({super.key, required this.walletProvider});

  @override
  State<MoonPayPurchaseDialog> createState() => _MoonPayPurchaseDialogState();
}

class _MoonPayPurchaseDialogState extends State<MoonPayPurchaseDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _walletController = TextEditingController();
  bool _isProcessing = false;
  String? _error;
  bool _termsAccepted = false;
  bool _walletExists = false;
  bool _networkAvailable = false;
  WebViewController? _webViewController;
  bool _showWebView = false;

  @override
  void initState() {
    super.initState();
    _initializeWalletAddress();
    _checkNetworkStatus();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _walletController.dispose();
    super.dispose();
  }

  Future<void> _initializeWalletAddress() async {
    final publicKey = widget.walletProvider.publicKey;
    if (publicKey != null) {
      setState(() {
        _walletController.text = publicKey;
        _walletExists = true;
      });
    }
  }

  Future<void> _checkNetworkStatus() async {
    // Basic network check - in production, use connectivity_plus
    setState(() {
      _networkAvailable = true; // Assume available for demo
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: _showWebView ? _buildWebViewDialog() : _buildPurchaseDialog(),
    );
  }

  Widget _buildPurchaseDialog() {
    return UltraModernWidgets.glassContainer(
      borderRadius: UltraModernTheme.radiusXl,
      padding: const EdgeInsets.all(UltraModernTheme.spacingLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),

            const SizedBox(height: UltraModernTheme.spacingLg),

            // Pre-flight checks
            _buildPreFlightChecks(),

            const SizedBox(height: UltraModernTheme.spacingLg),

            // Amount input
            _buildAmountInput(),

            const SizedBox(height: UltraModernTheme.spacingMd),

            // Wallet address confirmation
            _buildWalletConfirmation(),

            const SizedBox(height: UltraModernTheme.spacingLg),

            // Terms and fees
            _buildTermsAndFees(),

            const SizedBox(height: UltraModernTheme.spacingLg),

            // Error display
            if (_error != null) _buildErrorDisplay(),

            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(UltraModernTheme.spacingSm),
          decoration: BoxDecoration(
            color: UltraModernTheme.primaryGold.withOpacity(0.1),
            borderRadius: BorderRadius.circular(UltraModernTheme.radiusMd),
          ),
          child: Icon(
            Icons.account_balance_wallet,
            color: UltraModernTheme.primaryGold,
            size: 24,
          ),
        ),
        const SizedBox(width: UltraModernTheme.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Buy Stellar Lumens (XLM)', style: UltraModernTheme.title2),
              Text(
                'Purchase XLM instantly with MoonPay',
                style: UltraModernTheme.subheadline.copyWith(
                  color: UltraModernTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: UltraModernTheme.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildPreFlightChecks() {
    return Container(
      padding: const EdgeInsets.all(UltraModernTheme.spacingMd),
      decoration: BoxDecoration(
        color: UltraModernTheme.glassBlack,
        borderRadius: BorderRadius.circular(UltraModernTheme.radiusMd),
        border: Border.all(
          color: UltraModernTheme.textTertiary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pre-flight Checks',
            style: UltraModernTheme.callout.copyWith(
              color: UltraModernTheme.primaryGold,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: UltraModernTheme.spacingSm),
          _buildCheckItem(
            'Wallet Connected',
            _walletExists,
            _walletExists ? 'Ready' : 'No wallet found',
          ),
          _buildCheckItem(
            'Network Available',
            _networkAvailable,
            _networkAvailable ? 'Online' : 'Offline',
          ),
          _buildCheckItem(
            'MoonPay Service',
            true, // Assume available
            'Available',
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String label, bool status, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: UltraModernTheme.spacingXs),
      child: Row(
        children: [
          Icon(
            status ? Icons.check_circle : Icons.error,
            color: status
                ? UltraModernTheme.successGreen
                : UltraModernTheme.errorRed,
            size: 16,
          ),
          const SizedBox(width: UltraModernTheme.spacingSm),
          Expanded(
            child: Text(
              label,
              style: UltraModernTheme.body.copyWith(
                color: UltraModernTheme.textSecondary,
              ),
            ),
          ),
          Text(
            detail,
            style: UltraModernTheme.caption1.copyWith(
              color: status
                  ? UltraModernTheme.successGreen
                  : UltraModernTheme.errorRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Purchase Amount',
          style: UltraModernTheme.callout.copyWith(
            color: UltraModernTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: UltraModernTheme.spacingXs),
        UltraModernWidgets.modernTextField(
          controller: _amountController,
          label: 'Amount in USD',
          hint: 'Enter amount (min. \$10)',
          prefixIcon: Icons.attach_money,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          validator: _validateAmount,
        ),
        const SizedBox(height: UltraModernTheme.spacingXs),
        Text(
          'Minimum purchase: \$10 | Maximum: \$10,000',
          style: UltraModernTheme.caption1.copyWith(
            color: UltraModernTheme.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildWalletConfirmation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Wallet Address',
          style: UltraModernTheme.callout.copyWith(
            color: UltraModernTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: UltraModernTheme.spacingXs),
        Container(
          padding: const EdgeInsets.all(UltraModernTheme.spacingMd),
          decoration: BoxDecoration(
            color: UltraModernTheme.glassBlack,
            borderRadius: BorderRadius.circular(UltraModernTheme.radiusMd),
            border: Border.all(
              color: UltraModernTheme.primaryGold.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _walletController.text.isEmpty
                      ? 'No wallet address available'
                      : '${_walletController.text.substring(0, 8)}...${_walletController.text.substring(_walletController.text.length - 8)}',
                  style: UltraModernTheme.monoBody.copyWith(
                    color: _walletController.text.isEmpty
                        ? UltraModernTheme.textTertiary
                        : UltraModernTheme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.copy,
                  color: UltraModernTheme.primaryGold,
                  size: 20,
                ),
                onPressed: _walletController.text.isEmpty
                    ? null
                    : () {
                        Clipboard.setData(
                          ClipboardData(text: _walletController.text),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Wallet address copied'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTermsAndFees() {
    return Container(
      padding: const EdgeInsets.all(UltraModernTheme.spacingMd),
      decoration: BoxDecoration(
        color: UltraModernTheme.warningAmber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(UltraModernTheme.radiusMd),
        border: Border.all(
          color: UltraModernTheme.warningAmber.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: UltraModernTheme.warningAmber,
                size: 20,
              ),
              const SizedBox(width: UltraModernTheme.spacingSm),
              Text(
                'Terms & Fees',
                style: UltraModernTheme.callout.copyWith(
                  color: UltraModernTheme.warningAmber,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: UltraModernTheme.spacingSm),
          Text(
            '• MoonPay processing fee: 4.5% + \$0.99',
            style: UltraModernTheme.body.copyWith(
              color: UltraModernTheme.textSecondary,
            ),
          ),
          Text(
            '• Payment methods: Credit/Debit cards, Apple Pay, Google Pay',
            style: UltraModernTheme.body.copyWith(
              color: UltraModernTheme.textSecondary,
            ),
          ),
          Text(
            '• XLM will be delivered to your wallet within minutes',
            style: UltraModernTheme.body.copyWith(
              color: UltraModernTheme.textSecondary,
            ),
          ),
          const SizedBox(height: UltraModernTheme.spacingSm),
          Row(
            children: [
              Checkbox(
                value: _termsAccepted,
                onChanged: (value) {
                  setState(() => _termsAccepted = value ?? false);
                },
                activeColor: UltraModernTheme.primaryGold,
              ),
              Expanded(
                child: Text(
                  'I accept MoonPay\'s terms of service and privacy policy',
                  style: UltraModernTheme.body.copyWith(
                    color: UltraModernTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorDisplay() {
    return Container(
      padding: const EdgeInsets.all(UltraModernTheme.spacingMd),
      decoration: BoxDecoration(
        color: UltraModernTheme.errorRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(UltraModernTheme.radiusMd),
        border: Border.all(color: UltraModernTheme.errorRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: UltraModernTheme.errorRed, size: 20),
          const SizedBox(width: UltraModernTheme.spacingSm),
          Expanded(
            child: Text(
              _error!,
              style: UltraModernTheme.body.copyWith(
                color: UltraModernTheme.errorRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _isProcessing ? null : () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: UltraModernTheme.spacingMd,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UltraModernTheme.radiusMd),
              ),
            ),
            child: Text(
              'Cancel',
              style: UltraModernTheme.callout.copyWith(
                color: UltraModernTheme.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(width: UltraModernTheme.spacingMd),
        Expanded(
          child: MoonPayButton(
            onPressed: (_validateForm() && !_isProcessing)
                ? _initiatePurchase
                : null,
            isLoading: _isProcessing,
            disabled: !_validateForm(),
          ),
        ),
      ],
    );
  }

  Widget _buildWebViewDialog() {
    return Container(
      width: double.maxFinite,
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: UltraModernTheme.deepSpace,
        borderRadius: BorderRadius.circular(UltraModernTheme.radiusXl),
      ),
      child: Column(
        children: [
          // WebView header
          Container(
            padding: const EdgeInsets.all(UltraModernTheme.spacingMd),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: UltraModernTheme.textTertiary.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: UltraModernTheme.primaryGold,
                ),
                const SizedBox(width: UltraModernTheme.spacingSm),
                Expanded(
                  child: Text(
                    'MoonPay Checkout',
                    style: UltraModernTheme.headline,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: UltraModernTheme.textSecondary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // WebView
          Expanded(child: WebViewWidget(controller: _webViewController!)),
        ],
      ),
    );
  }

  String? _validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an amount';
    }

    final amount = double.tryParse(value);
    if (amount == null) {
      return 'Please enter a valid number';
    }

    if (amount < 10) {
      return 'Minimum purchase amount is \$10';
    }

    if (amount > 10000) {
      return 'Maximum purchase amount is \$10,000';
    }

    return null;
  }

  bool _validateForm() {
    if (!_walletExists) return false;
    if (!_networkAvailable) return false;
    if (!_termsAccepted) return false;

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount < 10 || amount > 10000) return false;

    return MoonPayService.isValidStellarAddress(_walletController.text);
  }

  Future<void> _initiatePurchase() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final amount = double.parse(_amountController.text);
      final walletAddress = _walletController.text;

      // Generate MoonPay widget URL
      final widgetUrl = MoonPayService.generateEnhancedWidgetUrl(
        walletAddress: walletAddress,
        currencyCode: 'xlm',
        baseCurrencyAmount: amount,
        baseCurrencyCode: 'USD',
        theme: 'dark',
        language: 'en',
      );

      // Initialize WebView
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(UltraModernTheme.deepSpace)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              // Handle loading progress if needed
            },
            onPageStarted: (String url) {
              // Handle page start
            },
            onPageFinished: (String url) {
              // Handle page finish
            },
            onWebResourceError: (WebResourceError error) {
              setState(() {
                _error = 'Failed to load MoonPay: ${error.description}';
                _isProcessing = false;
              });
            },
            onNavigationRequest: (NavigationRequest request) {
              // Handle navigation requests
              if (request.url.startsWith('azix://')) {
                // Handle app redirect
                Navigator.pop(context);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(widgetUrl));

      setState(() {
        _showWebView = true;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to initiate purchase: $e';
        _isProcessing = false;
      });
    }
  }
}
