import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Web-only imports
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// Correct import for Flutter Web's platformViewRegistry
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui;

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  static const String marketplaceUrl = "https://azixfusion.pages.dev";

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  WebViewController? _controller; // Used only on mobile
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      // Register the iframe view for web
      const viewType = 'iframeElement';
      ui.platformViewRegistry.registerViewFactory(
        viewType,
        (int _) => html.IFrameElement()
          ..src = WebViewPage.marketplaceUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%',
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
        return SizedBox(
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
            ],
          ),
        );
      },
    );
  }
}
