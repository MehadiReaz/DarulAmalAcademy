import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/recording.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/recording_provider.dart';
import '../../widgets/state_views.dart';
import 'drive_player_screen.dart';
import 'widgets/recording_card.dart';
import 'youtube_player_screen.dart';

/// Class recordings, backed by `GET /student/recordings`.
///
/// Playback plays YouTube and Google Drive videos directly in the app.
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

  void _play(Recording r) {
    if (r.isYoutubePlayable) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => YoutubePlayerScreen(
            recording: r,
            videoId: r.youtubeId!,
          ),
        ),
      );
    } else if (r.isPlayable) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DrivePlayerScreen(
            recording: r,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video link is unavailable.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
            return RecordingCard(recording: r, onPlay: () => _play(r));
          },
        ),
      ),
    );
  }
}


