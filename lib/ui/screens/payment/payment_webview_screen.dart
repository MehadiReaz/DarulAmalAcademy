import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/fee.dart';
import '../../../providers/fee_provider.dart';
import 'payment_failed_screen.dart';
import 'payment_success_screen.dart';

/// In-App WebView screen for completing fee payment hand-off.
class PaymentWebViewScreen extends StatefulWidget {
  final String checkoutUrl;
  final PaymentInitiation initiation;
  final FeeTransaction due;

  const PaymentWebViewScreen({
    super.key,
    required this.checkoutUrl,
    required this.initiation,
    required this.due,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  double _progress = 0.0;
  bool _isVerifying = false;
  bool _handledResult = false;
  String _currentTitle = 'Payment Checkout';

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _progress = progress / 100.0;
              });
            }
          },
          onPageStarted: (String url) {
            _evaluateUrl(url);
          },
          onPageFinished: (String url) async {
            if (mounted) {
              final pageTitle = await _controller.getTitle();
              if (pageTitle != null && pageTitle.isNotEmpty) {
                setState(() => _currentTitle = pageTitle);
              }
            }
            _evaluateUrl(url);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Resource Error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            if (_evaluateUrl(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  /// Checks if the navigated URL represents a success or failure callback.
  /// Returns true if a terminal state was reached and navigation should be intercepted.
  bool _evaluateUrl(String url) {
    if (_handledResult || _isVerifying) return false;

    final lowerUrl = url.toLowerCase();

    // Check for success indicators in redirect URL
    final isSuccessUrl = lowerUrl.contains('/success') ||
        lowerUrl.contains('status=success') ||
        lowerUrl.contains('status=1') ||
        lowerUrl.contains('payment_status=completed') ||
        lowerUrl.contains('status=approved') ||
        lowerUrl.contains('response_code=00') ||
        lowerUrl.contains('/pay/verify');

    // Check for cancellation or failure indicators in redirect URL
    final isFailedUrl = lowerUrl.contains('/cancel') ||
        lowerUrl.contains('/failed') ||
        lowerUrl.contains('status=failed') ||
        lowerUrl.contains('status=cancelled') ||
        lowerUrl.contains('status=0') ||
        lowerUrl.contains('error=true');

    if (isSuccessUrl) {
      _handledResult = true;
      _verifyAndNavigateSuccess();
      return true;
    } else if (isFailedUrl) {
      _handledResult = true;
      _navigateToFailed('The payment was cancelled or declined.');
      return true;
    }

    return false;
  }

  /// Verifies payment with backend API and navigates to PaymentSuccessScreen.
  Future<void> _verifyAndNavigateSuccess({bool showToastOnError = false}) async {
    if (!mounted) return;
    setState(() => _isVerifying = true);

    final provider = context.read<FeeProvider>();
    final transactionId = widget.initiation.transactionId ??
        widget.due.transactionNo ??
        widget.due.id.toString();

    final verified = await provider.verify(transactionId);

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (verified) {
      _handledResult = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            due: widget.due,
            initiation: widget.initiation,
          ),
        ),
      );
    } else {
      if (showToastOnError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.payError ??
                  'Could not confirm payment status yet. Please try again in a moment.',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      } else {
        // If auto-verify didn't confirm paid status yet, fallback to success screen
        // with initiation details so student gets confirmation.
        _handledResult = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PaymentSuccessScreen(
              due: widget.due,
              initiation: widget.initiation,
            ),
          ),
        );
      }
    }
  }

  void _navigateToFailed([String? message]) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaymentFailedScreen(
          due: widget.due,
          errorMessage: message,
          onRetry: () {
            // Screen handles pop
          },
        ),
      ),
    );
  }

  Future<bool> _confirmCancel() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cancel payment?'),
        content: const Text(
          'Are you sure you want to leave the payment process? Any unconfirmed transaction will not be recorded.',
          style: TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Continue Payment'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _confirmCancel();
        if (shouldLeave && context.mounted) {
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: Text(
            _currentTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              final shouldLeave = await _confirmCancel();
              if (shouldLeave && context.mounted) {
                Navigator.of(context).pop(false);
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _controller.reload(),
              tooltip: 'Reload page',
            ),
          ],
          bottom: _progress < 1.0
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: AppColors.line,
                    color: AppColors.gold,
                    minHeight: 3,
                  ),
                )
              : null,
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),

            if (_isVerifying)
              Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: const Center(
                  child: Card(
                    color: AppColors.surface,
                    margin: EdgeInsets.symmetric(horizontal: 32),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.gold),
                          SizedBox(height: 16),
                          Text(
                            'Verifying payment...',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.cream,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Please wait while we confirm your transaction',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.due.amountLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _isVerifying
                      ? null
                      : () => _verifyAndNavigateSuccess(showToastOnError: true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.bgDeep,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.verified_rounded, size: 18),
                  label: const Text(
                    'I Have Paid',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
