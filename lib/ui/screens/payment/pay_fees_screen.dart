import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/fee.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/fee_provider.dart';
import '../../widgets/state_views.dart';
import 'payment_webview_screen.dart';
import 'receipt_viewer_screen.dart';

/// Fees, backed by `/student/fees/dues`, `/history`, `/pay/initiate`,
/// `/pay/verify` and `/receipt/{id}`.
class PayFeesScreen extends StatefulWidget {
  const PayFeesScreen({super.key});

  @override
  State<PayFeesScreen> createState() => _PayFeesScreenState();
}

class _PayFeesScreenState extends State<PayFeesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FeeProvider>();
      provider.loadDues();
      provider.loadHistory();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _pay(FeeTransaction due) async {
    final provider = context.read<FeeProvider>();
    final invoiceId = due.invoiceId;

    if (invoiceId == null) {
      _toast(
        'This fee has no invoice attached — contact the office.',
        error: true,
      );
      return;
    }

    final initiation = await provider.initiate(invoiceId);
    if (!mounted) return;

    if (initiation == null) {
      _toast(provider.payError ?? 'Could not start the payment.', error: true);
      return;
    }

    // The gateways wired on the backend (PayPal / Stripe / Razorpay /
    // Flutterwave / Midtrans) are opened in an in-app WebView.
    var checkoutUrl = initiation.paymentUrl;

    // Razorpay in particular answers `/pay/initiate` with a transaction
    // but no link — its hosted page comes from
    // `/student/fees/pay/webview-url`, so that is tried before giving up.
    if ((checkoutUrl == null || checkoutUrl.isEmpty) &&
        initiation.transactionId != null) {
      checkoutUrl = await provider.checkoutUrl(initiation.transactionId!);
      if (!mounted) return;
    }

    if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentWebViewScreen(
            checkoutUrl: checkoutUrl!,
            initiation: initiation,
            due: due,
          ),
        ),
      );

      if (!mounted) return;
      provider.refreshAll();
      return;
    }

    _toast(
      provider.payError ??
          'Payment started, but the gateway sent no checkout link. '
              'Please contact the office.',
      error: true,
    );
  }

  /// Downloads the receipt PDF and opens it in-app.
  ///
  /// `GET /student/fees/receipt/{id}` streams the PDF itself from behind
  /// `auth:sanctum`, so it cannot be handed to `url_launcher` — without
  /// the bearer token the browser gets a 302 to the login page. The bytes
  /// come through the authenticated client and render from memory.
  Future<void> _openReceipt(FeeTransaction txn) async {
    final provider = context.read<FeeProvider>();
    final receipt = await provider.downloadReceipt(txn.id);

    if (!mounted) return;

    if (receipt == null) {
      _toast(
        provider.receiptError ?? 'Could not open the receipt.',
        error: true,
      );
      return;
    }

    if (!receipt.isPdf) {
      _toast('The server returned an unexpected file type.', error: true);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReceiptViewerScreen(
          receipt: receipt,
          title: txn.transactionNo ?? 'Receipt',
        ),
      ),
    );
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FeeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fees'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.muted,
          labelStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
          tabs: [
            Tab(text: 'Due (${provider.dues.length})'),
            const Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_duesTab(provider), _historyTab(provider)],
      ),
    );
  }

  Widget _duesTab(FeeProvider provider) {
    if (provider.duesState == LoadState.loading && provider.dues.isEmpty) {
      return const LoadingView();
    }
    if (provider.duesState == LoadState.error && provider.dues.isEmpty) {
      return ErrorView(
        message: provider.duesError ?? 'Could not load your dues',
        onRetry: () => provider.loadDues(force: true),
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () => provider.loadDues(force: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 300) {
            provider.loadMoreDues();
          }
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
          children: [
            _OutstandingCard(provider: provider),
            const SizedBox(height: 18),
            if (provider.dues.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: EmptyView(
                  icon: Icons.verified_rounded,
                  title: 'Nothing outstanding',
                  subtitle: 'All your fees are settled. Jazak Allahu khayran.',
                ),
              )
            else
              ...provider.dues.map(
                (due) => _FeeCard(
                  fee: due,
                  busy: provider.initiating,
                  onPay: () => _pay(due),
                ),
              ),
            if (provider.loadingMoreDues)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _historyTab(FeeProvider provider) {
    if (provider.historyState == LoadState.loading &&
        provider.history.isEmpty) {
      return const LoadingView();
    }
    if (provider.historyState == LoadState.error && provider.history.isEmpty) {
      return ErrorView(
        message: provider.historyError ?? 'Could not load payment history',
        onRetry: () => provider.loadHistory(force: true),
      );
    }
    if (provider.history.isEmpty) {
      return const EmptyView(
        icon: Icons.receipt_long_rounded,
        title: 'No payments yet',
        subtitle: 'Your payment history will appear here.',
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () => provider.loadHistory(force: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 300) {
            provider.loadMoreHistory();
          }
          return false;
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
          itemCount:
              provider.history.length + (provider.hasMoreHistory ? 1 : 0),
          itemBuilder: (context, i) {
            if (i >= provider.history.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              );
            }
            final txn = provider.history[i];
            return _FeeCard(
              fee: txn,
              busy: provider.isDownloadingReceipt(txn.id),
              onReceipt: () => _openReceipt(txn),
            );
          },
        ),
      ),
    );
  }
}

class _OutstandingCard extends StatelessWidget {
  final FeeProvider provider;
  const _OutstandingCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final currency = provider.duesCurrency;
    final total = provider.totalOutstanding.toStringAsFixed(2);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF24504A), Color(0xFF16332E)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total outstanding',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            currency == null ? total : '$currency $total',
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (currency == null && provider.dues.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'Fees are recorded in more than one currency — see each item.',
              style: TextStyle(color: AppColors.muted, fontSize: 10.5),
            ),
          ],
          if (provider.overdueCount > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 15,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 7),
                Text(
                  '${provider.overdueCount} overdue',
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FeeCard extends StatelessWidget {
  final FeeTransaction fee;
  final bool busy;
  final VoidCallback? onPay;
  final VoidCallback? onReceipt;

  const _FeeCard({
    required this.fee,
    this.busy = false,
    this.onPay,
    this.onReceipt,
  });

  Color get _statusColor {
    if (fee.isPaid) return AppColors.success;
    if (fee.isOverdue) return AppColors.danger;
    return AppColors.gold;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: fee.isOverdue ? AppColors.danger : AppColors.line,
          width: fee.isOverdue ? 1.3 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  fee.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  fee.statusLabel,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                fee.amountLabel,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (fee.dueDateLabel != null)
                Text(
                  fee.isPaid
                      ? (fee.dateLabel ?? '')
                      : 'Due ${fee.dueDateLabel}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
            ],
          ),
          if (fee.transactionNo != null) ...[
            const SizedBox(height: 8),
            Text(
              fee.transactionNo!,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                letterSpacing: 0.3,
              ),
            ),
          ],
          if (onPay != null || onReceipt != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: onPay != null
                  ? FilledButton.icon(
                      onPressed: busy ? null : onPay,
                      icon: busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF231600),
                              ),
                            )
                          : const Icon(Icons.credit_card_rounded, size: 17),
                      label: Text(busy ? 'Starting…' : 'Pay now'),
                    )
                  : OutlinedButton.icon(
                      onPressed: busy ? null : onReceipt,
                      icon: busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.gold,
                              ),
                            )
                          : const Icon(Icons.receipt_long_rounded, size: 16),
                      label: Text(busy ? 'Opening…' : 'View receipt'),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
