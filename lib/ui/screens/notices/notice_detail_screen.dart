import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/notice_provider.dart';
import '../../widgets/state_views.dart';
import '../../../core/utils/responsive.dart';

class NoticeDetailScreen extends StatefulWidget {
  final int noticeId;
  const NoticeDetailScreen({super.key, required this.noticeId});

  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<NoticeProvider>();
      p.loadDetail(widget.noticeId);
      p.markRead(widget.noticeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NoticeProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        title: const Text('Notice Details'),
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
      ),
      body: ResponsiveBody(child: _buildBody(provider)),
    );
  }

  Widget _buildBody(NoticeProvider provider) {
    if (provider.detailState == LoadState.loading) {
      return const LoadingView();
    }

    if (provider.detailState == LoadState.error) {
      return ErrorView(
        message: provider.detailError ?? 'Could not load notice',
        onRetry: () => provider.loadDetail(widget.noticeId),
      );
    }

    final notice = provider.detail;
    if (notice == null) return const SizedBox.shrink();

    final hasImage =
        notice.attachmentUrl != null && notice.attachmentUrl!.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Image Banner (if available)
          if (hasImage) ...[
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                notice.attachmentUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: AppColors.surface,
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.gold,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 2. Date & Meta Badges Row
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: Color(0xFF388BFD),
              ),
              const SizedBox(width: 6),
              Text(
                notice.formattedDate.isNotEmpty
                    ? '${notice.formattedDate} 06:00 ds'
                    : (notice.createdAt != null
                        ? Fmt.date(notice.createdAt)
                        : ''),
                style: const TextStyle(
                  color: Color(0xFF58A6FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (notice.isPinned) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.push_pin_rounded,
                          size: 11, color: AppColors.gold),
                      SizedBox(width: 4),
                      Text(
                        'PINNED',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  notice.type,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Notice Title
          Text(
            notice.title,
            style: const TextStyle(
              color: AppColors.cream,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),

          // 4. Description Content Card
          if (notice.displayBody.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                notice.displayBody,
                style: const TextStyle(
                  color: AppColors.cream,
                  fontSize: 14,
                  height: 1.65,
                ),
              ),
            ),

          const SizedBox(height: 24),

          // 5. Attachments Gallery
          if (notice.allAttachments.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.attach_file_rounded,
                    size: 16, color: AppColors.gold),
                SizedBox(width: 6),
                Text(
                  'Attachments',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cream,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...notice.allAttachments.map(
              (url) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 140,
                      color: AppColors.surface,
                      child: const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.gold),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      color: AppColors.surface,
                      child: const Row(
                        children: [
                          Icon(Icons.insert_drive_file_outlined,
                              color: AppColors.muted),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'View Attachment File',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
