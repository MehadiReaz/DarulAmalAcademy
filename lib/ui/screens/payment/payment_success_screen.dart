import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/fee.dart';
import '../../../providers/fee_provider.dart';
import 'receipt_viewer_screen.dart';

/// Screen displayed after a successful fee payment.
class PaymentSuccessScreen extends StatefulWidget {
  final FeeTransaction due;
  final PaymentInitiation? initiation;
  final FeeTransaction? verifiedTransaction;

  const PaymentSuccessScreen({
    super.key,
    required this.due,
    this.initiation,
    this.verifiedTransaction,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _downloadingReceipt = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _viewReceipt() async {
    final txnId = widget.verifiedTransaction?.id ?? widget.due.id;
    setState(() => _downloadingReceipt = true);

    final provider = context.read<FeeProvider>();
    final receipt = await provider.downloadReceipt(txnId);

    if (!mounted) return;
    setState(() => _downloadingReceipt = false);

    if (receipt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.receiptError ?? 'Could not generate receipt yet.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (!receipt.isPdf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The server returned an unexpected file format.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReceiptViewerScreen(
          receipt: receipt,
          title: widget.verifiedTransaction?.transactionNo ??
              widget.initiation?.transactionNo ??
              widget.due.transactionNo ??
              'Receipt',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txn = widget.verifiedTransaction ?? widget.due;
    final txnNo = widget.initiation?.transactionNo ??
        widget.verifiedTransaction?.transactionNo ??
        widget.due.transactionNo ??
        (widget.initiation?.transactionId != null
            ? '#${widget.initiation!.transactionId}'
            : null);

    final currency = widget.initiation?.currency ?? txn.currency;
    final amountVal = widget.initiation?.amount ?? txn.amount;
    final amountText = currency.isNotEmpty
        ? '$currency ${amountVal.toStringAsFixed(2)}'
        : amountVal.toStringAsFixed(2);

    final gateway = widget.initiation?.gateway ?? txn.method ?? 'Online Payment';

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.cream),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Animated Checkmark Icon Badge
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.success.withValues(alpha: 0.15),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.success.withValues(alpha: 0.25),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 56,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          const Text(
                            'Payment Successful!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.cream,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your fee payment has been successfully completed and recorded.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.muted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Summary Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Amount Paid',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.muted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.success
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'Paid',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  amountText,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.gold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Divider(color: AppColors.line, height: 1),
                                ),
                                _buildDetailRow(
                                  'Invoice / Fee',
                                  widget.due.title.isNotEmpty
                                      ? widget.due.title
                                      : 'Tuition Fee',
                                ),
                                if (txnNo != null && txnNo.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _buildDetailRow('Transaction Ref', txnNo),
                                ],
                                const SizedBox(height: 12),
                                _buildDetailRow('Payment Method', gateway),
                                const SizedBox(height: 12),
                                _buildDetailRow(
                                  'Date',
                                  DateTime.now().toString().split(' ').first,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _downloadingReceipt ? null : _viewReceipt,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.gold),
                        foregroundColor: AppColors.gold,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _downloadingReceipt
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.gold,
                              ),
                            )
                          : const Icon(Icons.receipt_long_rounded, size: 20),
                      label: Text(
                        _downloadingReceipt
                            ? 'Downloading Receipt...'
                            : 'View & Download Receipt',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop(true);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.bgDeep,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Back to Fees',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.muted,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.cream,
            ),
          ),
        ),
      ],
    );
  }
}
