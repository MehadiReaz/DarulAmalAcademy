import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/class_routine.dart';

class ClassCard extends StatelessWidget {
  final ClassRoutine routine;

  /// Highlights the card in gold (used for today's classes).
  final bool highlight;

  const ClassCard({super.key, required this.routine, this.highlight = false});

  Color get _accent {
    final hex = routine.subject?.color;
    if (hex == null) return AppColors.gold;
    final cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length != 6) return AppColors.gold;
    final value = int.tryParse('FF$cleaned', radix: 16);
    return value == null ? AppColors.gold : Color(value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight ? AppColors.gold : AppColors.line,
          width: highlight ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 46,
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routine.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${routine.courseName} · ${routine.teacherName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 13, color: AppColors.gold),
                    const SizedBox(width: 5),
                    Text(
                      Fmt.timeRange(routine.startTime, routine.endTime),
                      style: const TextStyle(
                        color: AppColors.cream,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (routine.weekdayName != null ||
                        routine.weekday != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        routine.weekdayName ?? Fmt.weekday(routine.weekday),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
