import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/attendance.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/base_provider.dart';
import '../../widgets/state_views.dart';

/// Attendance, backed by `GET /student/my-attendances`.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: _body(provider),
    );
  }

  Widget _body(AttendanceProvider provider) {
    if (provider.state == LoadState.loading && provider.groups.isEmpty) {
      return const LoadingView();
    }
    if (provider.state == LoadState.error && provider.groups.isEmpty) {
      return ErrorView(
        message: provider.error ?? 'Could not load attendance',
        onRetry: () => provider.load(force: true),
      );
    }
    if (provider.groups.isEmpty) {
      return const EmptyView(
        icon: Icons.fact_check_outlined,
        title: 'No attendance recorded',
        subtitle: 'Records appear once your teachers start marking classes.',
      );
    }

    final summary = provider.summary;

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () => provider.load(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
        children: [
          _SummaryCard(summary: summary),
          const SizedBox(height: 20),
          const Text(
            'By subject',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...provider.groups.map((g) => _SubjectCard(group: g)),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final AttendanceSummary summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF24504A), Color(0xFF16332E)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Text(
            '${summary.percentage}%',
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'overall attendance · ${summary.total} classes',
            style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _stat('Present', summary.present, AppColors.success),
              _stat('Late', summary.late, AppColors.gold),
              _stat('Absent', summary.absent, AppColors.danger),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Late classes count separately and do not add to your present '
            'total — the same rule the madrasah uses.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 10, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final SubjectAttendanceGroup group;
  const _SubjectCard({required this.group});

  Color get _color {
    if (group.percentage >= 75) return AppColors.success;
    if (group.percentage >= 50) return AppColors.gold;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Theme(
        // Removes ExpansionTile's default divider lines, which clash with
        // the card border.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          iconColor: AppColors.muted,
          collapsedIconColor: AppColors.muted,
          title: Text(
            group.subjectName,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: group.fraction,
                    minHeight: 7,
                    backgroundColor: const Color(0xFF0E2622),
                    valueColor: AlwaysStoppedAnimation(_color),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${group.percentage}% · ${group.present} present · '
                  '${group.late} late · ${group.absent} absent',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          children: group.records.map(_recordRow).toList(),
        ),
      ),
    );
  }

  Widget _recordRow(AttendanceRecord r) {
    final color = r.isPresent
        ? AppColors.success
        : (r.isLate ? AppColors.gold : AppColors.danger);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(r.dateLabel ?? '—', style: const TextStyle(fontSize: 11.5)),
          const Spacer(),
          if (r.isLate && r.lateMinutes > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '${r.lateMinutes} min',
                style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
              ),
            ),
          Text(
            r.statusLabel,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
