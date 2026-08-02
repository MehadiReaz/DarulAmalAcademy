import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/lesson.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/lesson_provider.dart';
import '../../widgets/state_views.dart';

/// Lesson material published to the student, backed by
/// `GET /student/my-lessons`.
class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LessonProvider>().load();
    });
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await canLaunchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That link could not be opened.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LessonProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('My Lessons')),
      body: _body(provider),
    );
  }

  Widget _body(LessonProvider provider) {
    if (provider.state == LoadState.loading && provider.items.isEmpty) {
      return const LoadingView();
    }
    if (provider.state == LoadState.error && provider.items.isEmpty) {
      return ErrorView(
        message: provider.error ?? 'Could not load lessons',
        onRetry: () => provider.load(force: true),
      );
    }
    if (provider.items.isEmpty) {
      return const EmptyView(
        icon: Icons.auto_stories_outlined,
        title: 'No lessons yet',
        subtitle: 'Lesson plans your teachers publish will appear here.',
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
            return _LessonCard(
              lesson: provider.items[i],
              onOpenLink: _openLink,
            );
          },
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  final Lesson lesson;
  final Future<void> Function(String url) onOpenLink;

  const _LessonCard({required this.lesson, required this.onOpenLink});

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (lesson.subject != null) lesson.subject!,
      if (lesson.className != null) lesson.className!,
      if (lesson.teacher != null) lesson.teacher!,
    ].join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  lesson.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (lesson.date != null)
                Text(
                  Fmt.date(lesson.date),
                  style: const TextStyle(
                    color: AppColors.goldLight,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              meta,
              style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
            ),
          ],
          if (lesson.description != null) ...[
            const SizedBox(height: 10),
            Text(
              lesson.description!,
              style: const TextStyle(
                color: AppColors.cream,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ],
          if (lesson.hasAttachment || lesson.hasLink) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (lesson.hasLink)
                  _linkChip(
                    icon: Icons.link_rounded,
                    label: 'Open link',
                    onTap: () => onOpenLink(lesson.link!),
                  ),
                if (lesson.hasAttachment)
                  _linkChip(
                    icon: Icons.attach_file_rounded,
                    label: 'Attachment',
                    onTap: () => onOpenLink(lesson.attachment!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _linkChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.bgTeal,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.goldLight),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
