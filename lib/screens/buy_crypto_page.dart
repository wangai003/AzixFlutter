import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/polygon_wallet_service.dart';

// Web-only imports
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show IFrameElement;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui;

class BuyCryptoPage extends StatefulWidget {
  final String walletAddress;
  final int amountKES;

  const BuyCryptoPage({
    super.key,
    required this.walletAddress,
    this.amountKES = 1000,
  });

  @override
  State<BuyCryptoPage> createState() => _BuyCryptoPageState();
}

class _BuyCryptoPageState extends State<BuyCryptoPage> {
  String? checkoutUrl;
  bool isLoading = true;
  String? error;
  WebViewController? controller; // Nullable for web platform
  html.IFrameElement? iframeElement; // For web platform

  @override
  void initState() {
    super.initState();
    fetchCheckoutUrl();
  }

  void _initializeWebView(String url) {
    if (kIsWeb) {
      // Web platform: Use iframe
      iframeElement = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';

      // Register iframe with platform view registry
      ui.platformViewRegistry.registerViewFactory(
        'moonpay-checkout-iframe',
        (int viewId) => iframeElement!,
      );

      setState(() {
        isLoading = false;
      });
    } else {
      // Mobile platform: Use WebViewController
      controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              // Handle MoonPay return URL
              if (request.url.startsWith("myapp://moonpay-return") ||
                  request.url.contains("moonpay-return")) {
                Navigator.pop(context);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
            onPageStarted: (url) {
              setState(() {
                isLoading = true;
              });
            },
            onPageFinished: (url) {
              setState(() {
                isLoading = false;
              });
            },
          ),
        )
        ..loadRequest(Uri.parse(url));
    }
  }

  @override
  void dispose() {
    if (kIsWeb && iframeElement != null) {
      iframeElement!.remove();
    }
    super.dispose();
  }

  Future<void> fetchCheckoutUrl() async {
    try {
      // Get backend URL from environment or use default
      final backendUrl = const String.fromEnvironment(
        'AZIX_BACKEND_URL',
        defaultValue: 'https://azix-flutter.vercel.app',
      );

      // Step 1: Get message to sign from backend
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          error = "User not authenticated";
          isLoading = false;
        });
        return;
      }

      // Get sign message from backend
      final messageResponse = await http.get(
        Uri.parse("$backendUrl/api/auth/sign-message?walletAddress=${widget.walletAddress}"),
      );

      if (messageResponse.statusCode != 200) {
        setState(() {
          error = "Failed to get sign message from backend";
          isLoading = false;
        });
        return;
      }

      final messageData = jsonDecode(messageResponse.body);
      final messageToSign = messageData['message'] as String;

      // Step 2: Prompt user for password to sign message
      if (!mounted) return;
      final password = await _showPasswordDialog();
      
      if (password == null || password.isEmpty) {
        setState(() {
          error = "Authentication cancelled";
          isLoading = false;
        });
        return;
      }

      // Step 3: Sign the message
      final signResult = await PolygonWalletService.signMessage(
        userId: user.uid,
        password: password,
        message: messageToSign,
      );

      if (!signResult['success']) {
        setState(() {
          error = signResult['error'] ?? "Failed to sign message";
          isLoading = false;
        });
        return;
      }

      final signature = signResult['signature'] as String;

      // Step 4: Send request with signature
      final response = await http.post(
        Uri.parse("$backendUrl/api/get-moonpay-url"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userAddress": widget.walletAddress,
          "signature": signature,
          "message": messageToSign,
          "amountKES": widget.amountKES,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final url = data["url"] as String;
        setState(() {
          checkoutUrl = url;
          error = null;
        });
        // Initialize WebView/iframe with the URL
        if (checkoutUrl != null) {
          _initializeWebView(checkoutUrl!);
        }
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          error = errorData["error"] ?? "Failed to get payment URL";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = "Failed to connect to backend: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Buy Crypto"),
          backgroundColor: AppTheme.darkGrey,
          foregroundColor: AppTheme.primaryGold,
        ),
        backgroundColor: AppTheme.darkGrey,
        body: Center(
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
                "Error",
                style: TextStyle(
                  color: AppTheme.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.grey,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    error = null;
                    isLoading = true;
                  });
                  fetchCheckoutUrl();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: AppTheme.darkGrey,
                ),
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    if (checkoutUrl == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Buy Crypto"),
          backgroundColor: AppTheme.darkGrey,
          foregroundColor: AppTheme.primaryGold,
        ),
        backgroundColor: AppTheme.darkGrey,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
              ),
              const SizedBox(height: 16),
              Text(
                "Loading MoonPay checkout...",
                style: TextStyle(
                  color: AppTheme.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Buy Crypto"),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.primaryGold,
        actions: [
          if (isLoading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
                ),
              ),
            ),
        ],
      ),
      backgroundColor: AppTheme.darkGrey,
      body: Stack(
        children: [
          // Web implementation
          if (kIsWeb && checkoutUrl != null && !isLoading && error == null)
            HtmlElementView(viewType: 'moonpay-checkout-iframe'),

          // Mobile implementation
          if (!kIsWeb && controller != null && !isLoading && error == null)
            WebViewWidget(controller: controller!),

          // Loading indicator overlay
          if (isLoading)
            Container(
              color: AppTheme.darkGrey,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Loading checkout...",
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Show password dialog for message signing
  Future<String?> _showPasswordDialog() async {
    final passwordController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _PasswordDialog(
        passwordController: passwordController,
      ),
    );
  }
}

/// Password input dialog for message signing
class _PasswordDialog extends StatefulWidget {
  final TextEditingController passwordController;

  const _PasswordDialog({
    required this.passwordController,
  });

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  bool obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.darkGrey,
      title: Text(
        "Sign Message",
        style: TextStyle(color: AppTheme.primaryGold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Enter your wallet password to sign the authentication message",
            style: TextStyle(color: AppTheme.white, fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.passwordController,
            obscureText: obscurePassword,
            style: TextStyle(color: AppTheme.white),
            decoration: InputDecoration(
              labelText: "Password",
              labelStyle: TextStyle(color: AppTheme.grey),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppTheme.primaryGold),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: AppTheme.grey,
                ),
                onPressed: () {
                  setState(() {
                    obscurePassword = !obscurePassword;
                  });
                },
              ),
            ),
            onSubmitted: (value) {
              Navigator.of(context).pop(value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            "Cancel",
            style: TextStyle(color: AppTheme.grey),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(widget.passwordController.text);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGold,
            foregroundColor: AppTheme.darkGrey,
          ),
          child: const Text("Sign"),
        ),
      ],
    );
  }
}

