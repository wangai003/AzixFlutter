import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/enhanced_wallet_provider.dart';
import '../../providers/auth_provider.dart' as local_auth;
import '../../services/akofa_tag_service.dart';
import '../../widgets/mpesa_sell_dialog.dart';
import '../../widgets/qr_code_display.dart';
import '../../theme/app_theme.dart';

// Web-only imports
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// Correct import for Flutter Web's platformViewRegistry
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui;

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  static const String marketplaceUrl =
      "https://buy-sell-marketplace-qigz.vercel.app";

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  WebViewController? _controller; // Used only on mobile
  bool _isLoading = true;
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
      _iframeElement = html.IFrameElement()
        ..src = WebViewPage.marketplaceUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';

      const viewType = 'iframeElement';
      ui.platformViewRegistry.registerViewFactory(
        viewType,
        (int _) => _iframeElement!,
      );

      _isLoading = false; // iframe loads independently
    } else {
      // Mobile WebView setup
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) => setState(() => _isLoading = true),
            onPageFinished: (_) => setState(() => _isLoading = false),
            onWebResourceError: (_) => setState(() => _isLoading = false),
          ),
        )
        ..loadRequest(Uri.parse(WebViewPage.marketplaceUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
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
                    child: const HtmlElementView(viewType: 'iframeElement'),
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
                  const Center(
                    child: CircularProgressIndicator(color: Colors.yellow),
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
          bottomNavigationBar: Consumer<EnhancedWalletProvider>(
            builder: (context, walletProvider, child) {
              if (!walletProvider.hasWallet) return const SizedBox.shrink();

              return Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.primaryGold.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBottomNavItem(
                      icon: Icons.payment,
                      label: 'Pay',
                      onTap: () => _showSendOptions(context, walletProvider),
                    ),
                    _buildBottomNavItem(
                      icon: Icons.qr_code_scanner,
                      label: 'Receive',
                      onTap: () => _showReceiveQR(context, walletProvider),
                    ),
                    _buildBottomNavItem(
                      icon: Icons.account_balance_wallet,
                      label: 'Balance',
                      onTap: () => _showQuickBalance(context, walletProvider),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    if (kIsWeb && _iframeElement != null) {
      // Remove the iframe element from the DOM when disposing
      _iframeElement!.remove();
    }
    super.dispose();
  }

  void _showSendOptions(
    BuildContext context,
    EnhancedWalletProvider walletProvider,
  ) {
    setState(() => _modalDepth++);
    _updateIframePointerEvents();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pay with Assets',
              style: AppTheme.headingMedium.copyWith(
                color: AppTheme.primaryGold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose an asset to pay with',
              style: TextStyle(color: AppTheme.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            // XLM Option
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                child: const Text(
                  'X',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                'Pay with XLM',
                style: TextStyle(color: AppTheme.white),
              ),
              subtitle: Text(
                'Native Stellar cryptocurrency',
                style: TextStyle(color: AppTheme.grey, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _showSendAssetDialog(
                  context,
                  walletProvider,
                  walletProvider.supportedAssets[0],
                  isMarketplacePayment: true,
                ); // XLM
              },
            ),
            // AKOFA Option
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange,
                child: const Text(
                  'A',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                'Pay with AKOFA',
                style: TextStyle(color: AppTheme.white),
              ),
              subtitle: Text(
                'AKOFA ecosystem token',
                style: TextStyle(color: AppTheme.grey, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _showSendAssetDialog(
                  context,
                  walletProvider,
                  walletProvider.supportedAssets[1],
                  isMarketplacePayment: true,
                ); // AKOFA
              },
            ),
            // Sell Tokens Option
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green,
                child: const Icon(Icons.sell, color: Colors.white, size: 20),
              ),
              title: Text(
                'Sell Tokens',
                style: TextStyle(color: AppTheme.white),
              ),
              subtitle: Text(
                'Convert tokens to cash',
                style: TextStyle(color: AppTheme.grey, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _showTokenSellDialog(context, walletProvider);
              },
            ),
            // Stablecoins
            ...walletProvider.stablecoins.map(
              (stablecoin) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Text(
                    stablecoin.symbol.substring(0, 1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  'Pay with ${stablecoin.symbol}',
                  style: TextStyle(color: AppTheme.white),
                ),
                subtitle: Text(
                  '${stablecoin.name} (${stablecoin.peggedCurrency ?? 'Stablecoin'})',
                  style: TextStyle(color: AppTheme.grey, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showSendAssetDialog(
                    context,
                    walletProvider,
                    stablecoin,
                    isMarketplacePayment: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      setState(() => _modalDepth--);
      _updateIframePointerEvents();
    });
  }

  void _showSendAssetDialog(
    BuildContext context,
    EnhancedWalletProvider walletProvider,
    dynamic asset, {
    bool isMarketplacePayment = false,
  }) {
    final recipientController = TextEditingController();
    final amountController = TextEditingController();
    final memoController = TextEditingController();
    String resolvedAddress = '';
    bool isResolvingTag = false;

    // Pre-fill recipient for marketplace payments
    if (isMarketplacePayment) {
      recipientController.text =
          'GDK37EBH66WPER5A7FXLG6TRWIRVQ5EQEPQQM43JK2VJM3JDSNWKIRY6';
    }

    setState(() => _modalDepth++);
    _updateIframePointerEvents();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.darkGrey,
          title: Text(
            'Pay with ${asset.symbol}',
            style: TextStyle(color: AppTheme.primaryGold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pay with ${asset.name} to another address or Akofa tag',
                  style: TextStyle(color: AppTheme.grey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: recipientController,
                  style: TextStyle(color: AppTheme.white),
                  onChanged: (value) async {
                    if (value.isNotEmpty) {
                      // Check if input looks like a tag
                      if (AkofaTagService.isValidTagFormat(value.trim())) {
                        setState(() => isResolvingTag = true);

                        try {
                          final tagResult = await AkofaTagService.resolveTag(
                            value.trim(),
                            blockchain: 'stellar',
                          );
                          if (tagResult['success']) {
                            setState(() {
                              resolvedAddress = tagResult['publicKey'];
                              isResolvingTag = false;
                            });
                          } else {
                            setState(() {
                              resolvedAddress = '';
                              isResolvingTag = false;
                            });
                          }
                        } catch (e) {
                          setState(() {
                            resolvedAddress = '';
                            isResolvingTag = false;
                          });
                        }
                      } else if (value.startsWith('G') && value.length == 56) {
                        // Valid Stellar address
                        setState(() => resolvedAddress = value);
                      } else {
                        setState(() => resolvedAddress = '');
                      }
                    } else {
                      setState(() {
                        resolvedAddress = '';
                        isResolvingTag = false;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Recipient Address or Akofa Tag',
                    labelStyle: TextStyle(color: AppTheme.primaryGold),
                    hintText: 'G... or john1234',
                    hintStyle: TextStyle(color: AppTheme.grey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryGold),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryGold),
                    ),
                    suffixIcon: isResolvingTag
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blue,
                            ),
                          )
                        : resolvedAddress.isNotEmpty
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          )
                        : null,
                  ),
                ),
                if (resolvedAddress.isNotEmpty && !isResolvingTag)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Resolved to: ${resolvedAddress.substring(0, 8)}...${resolvedAddress.substring(resolvedAddress.length - 8)}',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppTheme.white),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    labelStyle: TextStyle(color: AppTheme.primaryGold),
                    hintText: '0.00',
                    hintStyle: TextStyle(color: AppTheme.grey),
                    suffixText: asset.symbol,
                    suffixStyle: TextStyle(color: AppTheme.primaryGold),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryGold),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryGold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: memoController,
                  style: TextStyle(color: AppTheme.white),
                  maxLength: 28, // Stellar memo limit
                  decoration: InputDecoration(
                    labelText: 'Memo (Required)',
                    labelStyle: TextStyle(color: AppTheme.primaryGold),
                    hintText: 'Transaction description',
                    hintStyle: TextStyle(color: AppTheme.grey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryGold),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryGold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Available: ${walletProvider.getAssetBalance(asset.assetId)} ${asset.symbol}',
                  style: TextStyle(color: AppTheme.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: AppTheme.grey)),
            ),
            ElevatedButton(
              onPressed:
                  resolvedAddress.isEmpty ||
                      isResolvingTag ||
                      memoController.text.trim().isEmpty
                  ? null
                  : () async {
                      final amountText = amountController.text.trim();
                      final memoText = memoController.text.trim();

                      if (amountText.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter amount'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (memoText.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Memo is required for all transactions',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final amount = double.tryParse(amountText);
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid amount'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // Show password confirmation dialog
                      final password = await _showTransactionPasswordDialog(
                        context,
                        asset.symbol,
                        amount.toString(),
                        recipientController.text,
                      );
                      if (password == null || password.isEmpty) {
                        return; // User cancelled
                      }

                      // Verify password with Firebase Auth
                      final authProvider = Provider.of<local_auth.AuthProvider>(
                        context,
                        listen: false,
                      );
                      final currentUser = authProvider.user;
                      if (currentUser == null || currentUser.email == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Authentication required. Please log in again.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      try {
                        // Re-authenticate user with password
                        final credential = EmailAuthProvider.credential(
                          email: currentUser.email!,
                          password: password,
                        );
                        await currentUser.reauthenticateWithCredential(
                          credential,
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Invalid password. Please try again.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      Navigator.of(context).pop();

                      // Show loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Paying ${amount} ${asset.symbol}...'),
                          backgroundColor: Colors.blue,
                        ),
                      );

                      try {
                        final result = await walletProvider.sendAsset(
                          recipientAddress: resolvedAddress,
                          asset: asset,
                          amount: amount,
                          memo: memoText,
                        );

                        if (result['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Payment of ${asset.symbol} sent successfully!',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to send ${asset.symbol}: ${result['error']}',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error sending ${asset.symbol}: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.black,
              ),
              child: const Text('Pay Now'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      setState(() => _modalDepth--);
      _updateIframePointerEvents();
    });
  }

  void _showTokenSellDialog(
    BuildContext context,
    EnhancedWalletProvider walletProvider,
  ) {
    setState(() => _modalDepth++);
    _updateIframePointerEvents();

    showDialog(
      context: context,
      builder: (context) => MpesaSellDialog(walletProvider: walletProvider),
    ).whenComplete(() {
      setState(() => _modalDepth--);
      _updateIframePointerEvents();
    });
  }

  Future<String?> _showTransactionPasswordDialog(
    BuildContext context,
    String assetSymbol,
    String amount,
    String recipient,
  ) async {
    final controller = TextEditingController();

    setState(() => _modalDepth++);
    _updateIframePointerEvents();

    return await showDialog<String>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkGrey,
          title: Text(
            'Confirm Transaction',
            style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your password to sign and send $amount $assetSymbol to $recipient',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: AppTheme.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppTheme.grey.withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppTheme.grey.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.primaryGold),
                  ),
                ),
                style: const TextStyle(color: AppTheme.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('Cancel', style: TextStyle(color: AppTheme.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Confirm & Send'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.primaryGold, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.white,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiveQR(
    BuildContext context,
    EnhancedWalletProvider walletProvider,
  ) {
    if (walletProvider.publicKey != null) {
      setState(() => _modalDepth++);
      _updateIframePointerEvents();

      showDialog(
        context: context,
        builder: (context) => QRCodeDisplay(
          address: walletProvider.publicKey!,
          title: 'Receive Assets',
        ),
      ).whenComplete(() {
        setState(() => _modalDepth--);
        _updateIframePointerEvents();
      });
    }
  }

  void _showQuickBalance(
    BuildContext context,
    EnhancedWalletProvider walletProvider,
  ) {
    setState(() => _modalDepth++);
    _updateIframePointerEvents();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Balance',
              style: AppTheme.headingMedium.copyWith(
                color: AppTheme.primaryGold,
              ),
            ),
            const SizedBox(height: 16),
            // XLM Balance
            _buildBalanceRow(
              'XLM',
              'Stellar Lumens',
              double.tryParse(walletProvider.xlmBalance)?.toStringAsFixed(7) ??
                  '0.0000000',
              Icons.currency_exchange,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            // AKOFA Balance
            _buildBalanceRow(
              'AKOFA',
              'AKOFA Ecosystem Token',
              double.tryParse(
                    walletProvider.akofaBalance,
                  )?.toStringAsFixed(7) ??
                  '0.0000000',
              Icons.token,
              Colors.orange,
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text('Close'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: AppTheme.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceRow(
    String symbol,
    String name,
    String balance,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                symbol,
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                name,
                style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
              ),
            ],
          ),
        ),
        Text(
          balance,
          style: AppTheme.bodyLarge.copyWith(
            color: AppTheme.primaryGold,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
