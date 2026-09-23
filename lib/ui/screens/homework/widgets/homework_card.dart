import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/homework.dart';

/// Reusable Homework Card matching the design system with
/// gold accent strip, `[ AS ]` badge, status pill, outline metadata rows,
/// and responsive action footer.
class HomeworkCard extends StatelessWidget {
  final Homework homework;
  final VoidCallback onTap;

  const HomeworkCard({
    super.key,
    required this.homework,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = homework.status.isNotEmpty
        ? homework.status
        : (homework.isSubmitted ? 'Completed' : 'Due');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top decorative accent strip
            Container(
              height: 3.5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.gold, AppColors.goldLight],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row: [ AS ] Badge on left, Status Pill on right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.35),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'AS',
                          style: TextStyle(
                            color: AppColors.goldLight,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      StatusPill(status: status),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Assignment Title
                  Text(
                    homework.title,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.cream,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Metadata list with outline icons
                  MetadataRow(
                    icon: Icons.menu_book_outlined,
                    label: 'Course',
                    value: homework.courseDisplayName,
                  ),
                  const SizedBox(height: 9),
                  MetadataRow(
                    icon: Icons.groups_outlined,
                    label: 'Batch',
                    value: homework.batchDisplayName,
                  ),
                  const SizedBox(height: 9),
                  MetadataRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Teacher',
                    value: homework.teacher?.name ?? 'Qari Mahmood Al-Hussary',
                  ),
                  const SizedBox(height: 9),
                  MetadataRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Due Date',
                    value: homework.formattedDueDate,
                  ),
                  const SizedBox(height: 9),
                  StatusMetadataRow(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Status',
                    status: status,
                  ),
                  if (homework.description != null &&
                      homework.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 9),
                    DescriptionMetadataRow(
                      icon: Icons.folder_open_outlined,
                      label: 'Description',
                      text: homework.description!.trim(),
                    ),
                  ],

                  const SizedBox(height: 15),
                  const Divider(height: 1, color: AppColors.line),
                  const SizedBox(height: 13),

                  // Footer: Action Button on left, Submitted text on right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Text(
                          homework.isSubmitted ? 'Completed' : 'Completed',
                          style: const TextStyle(
                            color: AppColors.cream,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        homework.isSubmitted ? 'Submitted' : 'Submitted',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
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

// ─────────────────────────────────────────────── Status Pill
class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final lower = status.toLowerCase();
    Color bgColor;
    Color borderColor;
    Color textColor;

    if (lower == 'expired' || lower == 'overdue') {
      bgColor = AppColors.danger.withValues(alpha: 0.15);
      borderColor = AppColors.danger.withValues(alpha: 0.35);
      textColor = AppColors.danger;
    } else if (lower == 'completed' || lower == 'submitted' || lower == 'live') {
      bgColor = AppColors.success.withValues(alpha: 0.15);
      borderColor = AppColors.success.withValues(alpha: 0.35);
      textColor = AppColors.success;
    } else {
      // Due / Pending / Upcoming
      bgColor = AppColors.gold.withValues(alpha: 0.15);
      borderColor = AppColors.gold.withValues(alpha: 0.35);
      textColor = AppColors.goldLight;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────── Metadata Row Helper
class MetadataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const MetadataRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppColors.goldLight),
        const SizedBox(width: 9),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.cream,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class StatusMetadataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String status;

  const StatusMetadataRow({
    super.key,
    required this.icon,
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppColors.goldLight),
        const SizedBox(width: 9),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        StatusPill(status: status),
      ],
    );
  }
}

class DescriptionMetadataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;

  const DescriptionMetadataRow({
    super.key,
    required this.icon,
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.goldLight),
            const SizedBox(width: 9),
            Text(
              '$label:',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 25),
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.cream.withValues(alpha: 0.85),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
