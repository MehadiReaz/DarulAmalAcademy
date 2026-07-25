import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/notice.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/notice_provider.dart';
import '../../widgets/state_views.dart';

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
      appBar: AppBar(title: const Text('Notice')),
      body: _buildBody(provider),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type + Priority
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3520),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  notice.type,
                  style: const TextStyle(
                    color: AppColors.goldLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (notice.isPinned)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.push_pin_rounded,
                          size: 12, color: AppColors.gold),
                      const SizedBox(width: 4),
                      const Text(
                        'Pinned',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Text(
                notice.createdAt != null ? Fmt.date(notice.createdAt) : '',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            notice.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 18),

          // Description
          if (notice.description != null && notice.description!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                notice.description!,
                style: const TextStyle(
                  color: AppColors.cream,
                  fontSize: 13.5,
                  height: 1.65,
                ),
              ),
            ),

          // Attachments
          if (notice.allAttachments.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Attachments',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 10),
            ..._buildAttachments(notice),
          ],
        ],
      ),
    );
  }

  /// Typed rather than `dynamic` — the previous signature meant a typo in
  /// a field name would have failed at runtime instead of compile time.
  List<Widget> _buildAttachments(Notice notice) {
    return notice.allAttachments.map((url) {
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final uri = Uri.tryParse(url);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF24504A),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.file_present_rounded,
                    size: 20, color: AppColors.goldLight),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _fileName(url),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.open_in_new_rounded,
                  size: 16, color: AppColors.muted),
            ],
          ),
        ),
      );
    }).toList();
  }

  String _fileName(String url) {
    final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
    if (segments.isEmpty) return 'Attachment';
    final last = segments[segments.length - 1];
    return last.isEmpty ? 'Attachment' : last;
  }
}
