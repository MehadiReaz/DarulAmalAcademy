import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/recording.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/recording_provider.dart';
import '../../widgets/state_views.dart';

/// Class recordings, backed by `GET /student/recordings`.
///
/// Playback opens the video externally — the project has no webview
/// dependency, and `embed_url` is already parsed on [Recording] for when
/// an in-app player is added.
class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecordingProvider>().load();
    });
  }

  Future<void> _play(Recording r) async {
    final url = r.playableUrl;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This recording has no video link yet.')),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordingProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Recordings')),
      body: _body(provider),
    );
  }

  Widget _body(RecordingProvider provider) {
    if (provider.state == LoadState.loading && provider.items.isEmpty) {
      return const LoadingView();
    }
    if (provider.state == LoadState.error && provider.items.isEmpty) {
      return ErrorView(
        message: provider.error ?? 'Could not load recordings',
        onRetry: () => provider.load(force: true),
      );
    }
    if (provider.items.isEmpty) {
      return const EmptyView(
        icon: Icons.play_circle_outline_rounded,
        title: 'No recordings yet',
        subtitle: 'Recorded lessons your teachers upload will appear here.',
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              );
            }
            final r = provider.items[i];
            return _RecordingCard(recording: r, onPlay: () => _play(r));
          },
        ),
      ),
    );
  }
}

class _RecordingCard extends StatelessWidget {
  final Recording recording;
  final VoidCallback onPlay;

  const _RecordingCard({required this.recording, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onPlay,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF24504A), Color(0xFF173731)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                recording.isYoutube
                    ? Icons.smart_display_rounded
                    : Icons.play_circle_fill_rounded,
                size: 24,
                color: AppColors.goldLight,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recording.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    [
                      if (recording.subject?.name != null)
                        recording.subject!.name!,
                      if (recording.teacher?.name != null)
                        recording.teacher!.name!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.goldLight.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          recording.sourceLabel,
                          style: const TextStyle(
                            color: AppColors.goldLight,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (recording.recordedAt != null)
                        Text(
                          Fmt.date(recording.recordedAt),
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
            const Icon(Icons.open_in_new_rounded,
                size: 15, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
