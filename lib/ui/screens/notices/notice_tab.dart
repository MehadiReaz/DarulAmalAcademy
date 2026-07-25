import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/notice.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/notice_provider.dart';
import '../../widgets/state_views.dart';
import 'notice_detail_screen.dart';

class NoticeTab extends StatefulWidget {
  const NoticeTab({super.key});

  @override
  State<NoticeTab> createState() => _NoticeTabState();
}

class _NoticeTabState extends State<NoticeTab> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NoticeProvider>().loadNotices();
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<NoticeProvider>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NoticeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Notices')),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(NoticeProvider provider) {
    if (provider.listState == LoadState.loading && provider.notices.isEmpty) {
      return const LoadingView();
    }

    if (provider.listState == LoadState.error && provider.notices.isEmpty) {
      return ErrorView(
        message: provider.listError ?? 'Could not load notices',
        onRetry: () => provider.loadNotices(force: true),
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () => provider.loadNotices(force: true),
      child: provider.notices.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                const EmptyView(
                  icon: Icons.campaign_rounded,
                  title: 'No notices yet',
                  subtitle: 'Announcements from your teachers will appear here.',
                ),
              ],
            )
          : ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
              itemCount: provider.notices.length + (provider.hasMore ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= provider.notices.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: LoadingView(),
                  );
                }
                return _NoticeTile(notice: provider.notices[i]);
              },
            ),
    );
  }
}

class _NoticeTile extends StatelessWidget {
  final Notice notice;
  const _NoticeTile({required this.notice});

  IconData get _icon {
    switch (notice.type.toLowerCase()) {
      case 'batch':
        return Icons.groups_rounded;
      case 'course':
        return Icons.school_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  Color get _tagColor {
    if (notice.hasAttachment) return const Color(0xFFEE8888);
    return AppColors.goldLight;
  }

  Color get _tagBg {
    if (notice.hasAttachment) return const Color(0xFF3A2020);
    return const Color(0xFF3A3520);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NoticeDetailScreen(noticeId: notice.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: notice.isPinned ? AppColors.gold : AppColors.line,
            width: notice.isPinned ? 1.3 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF24504A), Color(0xFF173731)],
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(_icon, size: 21, color: AppColors.goldLight),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Unread marker. Read state is tracked on-device —
                      // the backend always reports is_read: false.
                      if (!notice.isRead) ...[
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 7, top: 1),
                          decoration: const BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          notice.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight:
                                notice.isRead ? FontWeight.w600 : FontWeight.w700,
                            fontSize: 13.5,
                            color: notice.isRead
                                ? AppColors.cream.withValues(alpha: 0.72)
                                : AppColors.cream,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _tagBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          notice.type,
                          style: TextStyle(
                            color: _tagColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    notice.excerpt ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (notice.isPinned) ...[
                        const Icon(Icons.push_pin_rounded,
                            size: 11, color: AppColors.gold),
                        const SizedBox(width: 4),
                        const Text(
                          'Pinned',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (notice.hasAttachment) ...[
                        const Icon(Icons.attach_file_rounded,
                            size: 11, color: AppColors.muted),
                        const SizedBox(width: 3),
                      ],
                      const Spacer(),
                      Text(
                        notice.createdAt != null
                            ? Fmt.ago(notice.createdAt)
                            : '',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10.5,
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
}
