import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/app_notification.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../widgets/state_views.dart';
import '../homework/homework_detail_screen.dart';
import '../notices/notice_detail_screen.dart';
import '../payment/pay_fees_screen.dart';
import '../support/support_tab.dart';

/// Notification centre, backed by `GET /student/notifications` and
/// `POST /auth/notifications/{id}/read`.
///
/// Tapping a row marks it read and, when the payload names a target,
/// opens the screen it refers to.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().load();
    });
  }

  void _open(AppNotification n) {
    context.read<NotificationProvider>().markRead(n.id);

    final id = n.targetId;
    Widget? destination;

    switch (n.category) {
      case 'homework':
        if (id != null) destination = HomeworkDetailScreen(homeworkId: id);
        break;
      case 'notice':
        if (id != null) destination = NoticeDetailScreen(noticeId: id);
        break;
      case 'fee':
        destination = const PayFeesScreen();
        break;
      case 'ticket':
        destination = const SupportTab();
        break;
    }

    final target = destination;
    if (target != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => target));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: provider.markAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(color: AppColors.gold, fontSize: 12.5),
              ),
            ),
        ],
      ),
      body: _body(provider),
    );
  }

  Widget _body(NotificationProvider provider) {
    if (provider.state == LoadState.loading && provider.items.isEmpty) {
      return const LoadingView();
    }
    if (provider.state == LoadState.error && provider.items.isEmpty) {
      return ErrorView(
        message: provider.error ?? 'Could not load notifications',
        onRetry: () => provider.load(force: true),
      );
    }
    if (provider.items.isEmpty) {
      return const EmptyView(
        icon: Icons.notifications_none_rounded,
        title: 'Nothing new',
        subtitle:
            'Alerts about homework, notices and fees will show up here.',
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () => provider.load(force: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 300) {
            provider.loadMore();
          }
          return false;
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
          itemCount: provider.items.length + (provider.hasMore ? 1 : 0),
          itemBuilder: (context, i) {
            if (i >= provider.items.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final item = provider.items[i];
            return _NotificationCard(
              item: item,
              onTap: () => _open(item),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification item;
  final VoidCallback onTap;

  const _NotificationCard({required this.item, required this.onTap});

  static const _icons = <String, IconData>{
    'homework': Icons.assignment_rounded,
    'notice': Icons.campaign_rounded,
    'fee': Icons.credit_card_rounded,
    'class': Icons.calendar_month_rounded,
    'ticket': Icons.support_agent_rounded,
    'attendance': Icons.fact_check_outlined,
    'exam': Icons.workspace_premium_outlined,
    'quran': Icons.menu_book_rounded,
    'general': Icons.notifications_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: unread ? AppColors.surfaceAlt : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unread ? AppColors.gold.withValues(alpha: 0.35) : AppColors.line,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.bgTeal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _icons[item.category] ?? Icons.notifications_outlined,
                    size: 18,
                    color: AppColors.goldLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight:
                                    unread ? FontWeight.w700 : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (unread) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.gold,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (item.message != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.message!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ],
                      if (item.createdAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          Fmt.ago(item.createdAt),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
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
