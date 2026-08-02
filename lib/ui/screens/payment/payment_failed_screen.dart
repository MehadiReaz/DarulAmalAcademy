import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/fee.dart';
import '../support/create_ticket_screen.dart';

/// Screen displayed when payment fails or is cancelled.
class PaymentFailedScreen extends StatelessWidget {
  final FeeTransaction due;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const PaymentFailedScreen({
    super.key,
    required this.due,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final title = due.title.isNotEmpty ? due.title : 'Tuition Fee';
    final amountText = due.amountLabel;

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
              Navigator.of(context).pop(false);
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
                    const SizedBox(height: 20),
                    // Warning / Error Circle Icon
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.danger.withValues(alpha: 0.15),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.danger.withValues(alpha: 0.2),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.cancel_rounded,
                          size: 56,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Payment Unsuccessful',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.cream,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorMessage ??
                          'The transaction was cancelled or could not be completed by the payment gateway.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Details Container
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
                          _buildDetailRow('Invoice / Fee', title),
                          const SizedBox(height: 12),
                          _buildDetailRow('Amount Due', amountText),
                          const SizedBox(height: 12),
                          _buildDetailRow('Status', 'Unpaid', valueColor: AppColors.danger),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Troubleshooting box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.line.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: AppColors.gold,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Please check your network connection or card details and try again. No money was deducted.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.muted,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                        if (onRetry != null) {
                          onRetry!();
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.bgDeep,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text(
                        'Try Payment Again',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CreateTicketScreen(
                                  initialCategory: 'payment_issue',
                                  initialSubject:
                                      'Payment issue for $title ($amountText)',
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.line),
                            foregroundColor: AppColors.cream,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Contact Support'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop(false);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.line),
                            foregroundColor: AppColors.muted,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Back to Dues'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
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
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.cream,
          ),
        ),
      ],
    );
  }
}
