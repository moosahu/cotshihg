import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum PaymobResult { success, failure, cancelled }

/// Opens Paymob Unified Checkout in a WebView.
/// Returns [PaymobResult] when payment completes or user cancels.
class PaymobPaymentPage extends StatefulWidget {
  final String clientSecret;
  final String publicKey;

  const PaymobPaymentPage({
    super.key,
    required this.clientSecret,
    required this.publicKey,
  });

  @override
  State<PaymobPaymentPage> createState() => _PaymobPaymentPageState();
}

class _PaymobPaymentPageState extends State<PaymobPaymentPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final url = Uri.https('ksa.paymob.com', '/unifiedcheckout/', {
      'publicKey': widget.publicKey,
      'clientSecret': widget.clientSecret,
    });

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        onNavigationRequest: (req) {
          // Detect Paymob redirect after payment completion.
          // Paymob appends ?success=true or ?success=false to the redirection_url.
          final uri = Uri.tryParse(req.url);
          if (uri != null) {
            final success = uri.queryParameters['success'];
            if (success != null) {
              final result = success == 'true'
                  ? PaymobResult.success
                  : PaymobResult.failure;
              Navigator.of(context).pop(result);
              return NavigationDecision.prevent;
            }
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إتمام الدفع'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(PaymobResult.cancelled),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
