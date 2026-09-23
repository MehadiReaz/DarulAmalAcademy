import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/recording.dart';

/// Reusable card displaying class recording thumbnail, title,
/// course/batch subtitle info, source label, and recording date.
class RecordingCard extends StatelessWidget {
  final Recording recording;
  final VoidCallback onPlay;

  const RecordingCard({
    super.key,
    required this.recording,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final isPlayable = recording.isPlayable;
    final thumb = recording.displayThumbnail;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onPlay,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 80,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF142B27),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumb != null && thumb.isNotEmpty)
                      Image.network(
                        thumb,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _fallbackThumb(isPlayable),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: const Color(0xFF173731),
                            child: const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.gold,
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    else
                      _fallbackThumb(isPlayable),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 16,
                          color: isPlayable ? AppColors.gold : AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 13),

            // Video Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recording.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.35,
                      color: isPlayable ? AppColors.cream : AppColors.muted,
                    ),
                  ),
                  if (recording.subtitleInfo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      recording.subtitleInfo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isPlayable
                              ? AppColors.goldLight.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isPlayable
                              ? recording.sourceLabel
                              : '${recording.sourceLabel} (Not supported)',
                          style: TextStyle(
                            color: isPlayable
                                ? AppColors.goldLight
                                : AppColors.muted,
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
          ],
        ),
      ),
    );
  }

  Widget _fallbackThumb(bool isPlayable) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPlayable
              ? const [Color(0xFF24504A), Color(0xFF173731)]
              : const [Color(0xFF2A2A2A), Color(0xFF1F1F1F)],
        ),
      ),
      child: Icon(
        recording.isYoutube
            ? Icons.smart_display_rounded
            : (recording.isDrive
                ? Icons.cloud_done_rounded
                : Icons.play_circle_fill_rounded),
        size: 24,
        color: isPlayable ? AppColors.goldLight : AppColors.muted,
      ),
    );
  }
}
