import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/class_routine.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/class_provider.dart';
import '../../widgets/state_views.dart';

/// ISO weekday numbers, matching `ClassRoutine::WEEK_DAYS` server-side
/// (1 = Monday … 7 = Sunday). File-level so both the standalone screen
/// and the embedded tab share one definition.
const Map<int, String> _dayNames = {
  1: 'Monday',
  2: 'Tuesday',
  3: 'Wednesday',
  4: 'Thursday',
  5: 'Friday',
  6: 'Saturday',
  7: 'Sunday',
};

/// The weekly routine, backed by `GET /student/my-class-routine`.
///
/// This endpoint is not gated by the authorisation check that makes
/// `/student/classes/today` and `/upcoming` return 403, so it is the
/// dependable source for timetable data.
class RoutineScreen extends StatelessWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Class Routine')),
      body: const RoutineBody(),
    );
  }
}

/// The same content without a Scaffold, for embedding as a tab inside
/// the Classes screen.
class RoutineTabView extends StatelessWidget {
  const RoutineTabView({super.key});

  @override
  Widget build(BuildContext context) => const RoutineBody();
}

/// The routine list itself. Extracted so both the standalone screen and
/// the Classes-tab embed render identical content.
class RoutineBody extends StatefulWidget {
  const RoutineBody({super.key});

  @override
  State<RoutineBody> createState() => _RoutineBodyState();
}

class _RoutineBodyState extends State<RoutineBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClassProvider>().loadRoutine();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClassProvider>();
    return _body(provider);
  }

  Widget _body(ClassProvider provider) {
    final bundle = provider.routine;

    if (provider.routineState == LoadState.loading && bundle == null) {
      return const LoadingView();
    }
    if (provider.routineState == LoadState.error && bundle == null) {
      return ErrorView(
        message: provider.routineError ?? 'Could not load your routine',
        onRetry: () => provider.loadRoutine(force: true),
      );
    }
    if (bundle == null || bundle.isEmpty) {
      return RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.surface,
        onRefresh: () => provider.loadRoutine(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.16),
            const EmptyView(
              icon: Icons.calendar_month_outlined,
              title: 'No routine published',
              subtitle:
                  'Your weekly timetable will appear here once the madrasah '
                  'publishes it.',
            ),
          ],
        ),
      );
    }

    final byDay = bundle.byWeekday;
    // Start from today so the most relevant day is first.
    final todayIso = DateTime.now().weekday;
    final ordered = [
      for (var i = 0; i < 7; i++) ((todayIso - 1 + i) % 7) + 1,
    ];

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () => provider.loadRoutine(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
        children: [
          for (final day in ordered)
            if ((byDay[day] ?? const []).isNotEmpty)
              _DaySection(
                title: _dayNames[day] ?? 'Day $day',
                isToday: day == todayIso,
                routines: byDay[day]!,
              ),
          if (bundle.schedules.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'One-off sessions',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...bundle.schedules.map(_scheduleTile),
          ],
          if (bundle.teachers.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text(
              'Teachers (${bundle.teachers.length})',
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: bundle.teachers
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Text(
                        t.display,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _scheduleTile(ScheduleEntry s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_rounded, size: 16, color: AppColors.goldLight),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              s.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          if (s.startsAt != null)
            Text(
              Fmt.date(s.startsAt),
              style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
            ),
        ],
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  final String title;
  final bool isToday;
  final List<ClassRoutine> routines;

  const _DaySection({
    required this.title,
    required this.isToday,
    required this.routines,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Text(
                    'TODAY',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        ...routines.map(
          (r) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 34,
                  decoration: BoxDecoration(
                    color: r.subject?.colorValue ?? AppColors.goldLight,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        r.teacherName,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  Fmt.timeRange(r.startTime, r.endTime),
                  style: const TextStyle(
                    color: AppColors.goldLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
