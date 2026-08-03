import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/fee.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/fee_provider.dart';
import '../../widgets/state_views.dart';
import 'payment_success_screen.dart';
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
  late final Razorpay _razorpay;

  PaymentInitiation? _activeInitiation;
  FeeTransaction? _activeDue;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleRazorpaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleRazorpayError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleRazorpayExternalWallet);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FeeProvider>();
      provider.loadDues();
      provider.loadHistory();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _handleRazorpaySuccess(PaymentSuccessResponse response) async {
    final initiation = _activeInitiation;
    final due = _activeDue;
    _activeInitiation = null;
    _activeDue = null;

    if (initiation == null || due == null || !mounted) return;

    final provider = context.read<FeeProvider>();
    final transactionId =
        initiation.transactionId ?? due.transactionNo ?? due.id.toString();

    final verified = await provider.verify(
      transactionId,
      paymentId: response.paymentId,
      signature: response.signature,
    );

    if (!mounted) return;

    if (verified) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              PaymentSuccessScreen(due: due, initiation: initiation),
        ),
      );
    } else {
      _toast(
        provider.payError ?? 'Payment completed, but verification failed.',
        error: true,
      );
    }
  }

  void _handleRazorpayError(PaymentFailureResponse response) {
    _activeInitiation = null;
    _activeDue = null;

    if (!mounted) return;

    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      _toast('Payment cancelled.', error: false);
      return;
    }

    _toast(
      response.message ?? 'Payment failed. Please try again.',
      error: true,
    );
  }

  void _handleRazorpayExternalWallet(ExternalWalletResponse response) {
    _toast('Redirecting to wallet: ${response.walletName}');
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

    // Razorpay Native Checkout
    if (initiation.isRazorpayNative) {
      _activeInitiation = initiation;
      _activeDue = due;

      final user = context.read<AuthProvider>().user;
      final double amt = initiation.amount ?? due.amount;
      final amountInPaise = initiation.razorAmount ?? (amt * 100).toInt();

      final prefill = <String, String>{};
      final phone = user?.phone;
      final email = user?.email;
      if (phone != null && phone.isNotEmpty) prefill['contact'] = phone;
      if (email != null && email.isNotEmpty) prefill['email'] = email;

      final options = <String, dynamic>{
        'key': initiation.razorpayKey,
        'amount': amountInPaise,
        'name': 'Darul Amal Academy',
        'description': due.title,
        'currency': initiation.currency ?? 'INR',
        if (prefill.isNotEmpty) 'prefill': prefill,
        'notes': {
          'transaction_id': initiation.transactionId ?? '',
          'invoice_id': invoiceId,
        },
      };

      try {
        _razorpay.open(options);
      } catch (e) {
        _toast('Could not launch Razorpay payment gateway.', error: true);
      }
      return;
    }

    // Fallback in-app WebView
    var checkoutUrl = initiation.paymentUrl;

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
        title: const Text('Fees & Payments'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: TabBar(
              controller: _tabs,
              indicator: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(11),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: const Color(0xFF241700),
              unselectedLabelColor: AppColors.muted,
              labelStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                Tab(text: 'Due (${provider.dues.length})'),
                const Tab(text: 'Payment History'),
              ],
            ),
          ),
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
      return const LoadingView(message: 'Loading fee dues…');
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
      return const LoadingView(message: 'Loading payment history…');
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
    final count = provider.dues.length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B5B53), Color(0xFF143029)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          color: AppColors.goldLight,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Total Outstanding',
                          style: TextStyle(
                            color: AppColors.goldLight,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (count > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          '$count Pending',
                          style: const TextStyle(
                            color: AppColors.cream,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  currency == null ? total : '$currency $total',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                if (currency == null && provider.dues.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Fees are recorded in more than one currency — see each item below.',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
                if (provider.overdueCount > 0) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 15,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          '${provider.overdueCount} Payment Overdue — Action Required',
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
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
    if (fee.isPaid) return const Color(0xFF2ECC71);
    if (fee.isOverdue) return AppColors.danger;
    return AppColors.gold;
  }

  IconData get _cardIcon {
    if (fee.isPaid) return Icons.verified_rounded;
    if (fee.isOverdue) return Icons.warning_amber_rounded;
    return Icons.receipt_long_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isOverdue = fee.isOverdue;
    final isPaid = fee.isPaid;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOverdue
              ? AppColors.danger.withValues(alpha: 0.6)
              : AppColors.line,
          width: isOverdue ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: _statusColor.withValues(alpha: 0.3)),
                ),
                alignment: Alignment.center,
                child: Icon(_cardIcon, color: _statusColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fee.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.cream,
                        height: 1.3,
                      ),
                    ),
                    if (fee.transactionNo != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Invoice #${fee.transactionNo!}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: _statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  fee.statusLabel,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.line, height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Amount',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fee.amountLabel,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              if (fee.dueDateLabel != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isPaid
                          ? 'Payment Date'
                          : (isOverdue ? 'Overdue Since' : 'Due Date'),
                      style: TextStyle(
                        color: isOverdue ? AppColors.danger : AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPaid ? (fee.dateLabel ?? 'Paid') : fee.dueDateLabel!,
                      style: TextStyle(
                        color: isOverdue ? AppColors.danger : AppColors.cream,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (onPay != null || onReceipt != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: onPay != null
                  ? Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.gold, AppColors.goldDeep],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: busy ? null : onPay,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF241700),
                                ),
                              )
                            : const Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                                color: Color(0xFF241700),
                              ),
                        label: Text(
                          busy ? 'Starting Payment…' : 'Pay Now Securely',
                          style: const TextStyle(
                            color: Color(0xFF241700),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: busy ? null : onReceipt,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.goldLight,
                        side: BorderSide(
                          color: AppColors.gold.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.gold,
                              ),
                            )
                          : const Icon(
                              Icons.receipt_long_rounded,
                              size: 18,
                              color: AppColors.gold,
                            ),
                      label: Text(
                        busy ? 'Downloading Receipt…' : 'Download Receipt PDF',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.cream,
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
