// lib/screens/chapa_webview_page.dart

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ChapaWebViewPage extends StatefulWidget {
  final String url;
  const ChapaWebViewPage({super.key, required this.url});

  @override
  State<ChapaWebViewPage> createState() => _ChapaWebViewPageState();
}

class _ChapaWebViewPageState extends State<ChapaWebViewPage> {
  late final WebViewController _controller;
  var loadingPercentage = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => setState(() => loadingPercentage = 0),
          onProgress: (progress) => setState(() => loadingPercentage = progress),
          onPageFinished: (url) => setState(() => loadingPercentage = 100),
          onNavigationRequest: (request) {
            // This is the success URL you configured in the backend PaymentController
            if (request.url.contains('basirahtv.com/payment-success')) {
              print('Chapa payment successful, redirect detected.');
              Navigator.of(context).pop(true); // Pop with a success result
              return NavigationDecision.prevent; // Stop the redirect
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Payment')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (loadingPercentage < 100)
            LinearProgressIndicator(
              value: loadingPercentage / 100.0,
            ),
        ],
      ),
    );
  }
}