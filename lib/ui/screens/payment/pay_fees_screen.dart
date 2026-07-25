import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/base_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/state_views.dart';

/// Pay Fees sub-screen matching the prototype.
///
/// Uses dashboard data (`due_amount`, `is_due`, `total_amount`, etc.)
/// to show fee breakdown and total due.
class PayFeesScreen extends StatefulWidget {
  const PayFeesScreen({super.key});

  @override
  State<PayFeesScreen> createState() => _PayFeesScreenState();
}

class _PayFeesScreenState extends State<PayFeesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay Fees'),
        leading: const BackButton(),
      ),
      body: _buildBody(dashboard),
    );
  }

  Widget _buildBody(DashboardProvider dashboard) {
    if (dashboard.state == LoadState.loading && dashboard.data == null) {
      return const LoadingView();
    }

    if (dashboard.state == LoadState.error && dashboard.data == null) {
      return ErrorView(
        message: dashboard.error ?? 'Could not load fee info',
        onRetry: () => dashboard.load(force: true),
      );
    }

    final due = dashboard.dueAmount;
    final totalAmount = dashboard.data?.totalAmount ?? 0;
    final totalDue = dashboard.data?.totalDueAmount ?? 0;
    final paid = totalAmount - totalDue;

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () => dashboard.load(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
        children: [
          // Due card
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.surfaceAlt, AppColors.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                const Text(
                  'Total Due',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '৳${due.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dashboard.isDue ? 'Payment pending' : 'All clear!',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Fee breakdown
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                _PayLine(label: 'Total Fees', value: '৳${totalAmount.toStringAsFixed(0)}'),
                _PayLine(label: 'Total Paid', value: '৳${paid.toStringAsFixed(0)}'),
                _PayLine(
                  label: 'Outstanding',
                  value: '৳${totalDue.toStringAsFixed(0)}',
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Pay button
          if (dashboard.isDue)
            AppButton(
              label: 'Pay ৳${due.toStringAsFixed(0)} securely',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Payment gateway integration coming soon. Contact the office for now.'),
                  ),
                );
              },
            ),

          if (dashboard.isDue)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Text(
                'Payment gateway · Receipt auto-downloads',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),

          if (!dashboard.isDue) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 40, color: AppColors.success),
                  const SizedBox(height: 12),
                  const Text(
                    'No pending dues',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'All your fees are paid. JazakAllahu Khairan!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PayLine extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _PayLine({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
