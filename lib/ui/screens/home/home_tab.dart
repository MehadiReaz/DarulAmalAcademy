import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/class_provider.dart';
import '../../widgets/class_card.dart';
import '../../widgets/state_views.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  @override
  void initState() {
    super.initState();
    // Kick off loads after the first frame so context.read is safe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final classes = context.read<ClassProvider>();
      classes.loadToday();
      classes.loadCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final classes = context.watch<ClassProvider>();
    final user = auth.user;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            await Future.wait([
              classes.loadToday(force: true),
              classes.loadCourses(force: true),
              auth.reloadProfile(),
            ]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
            children: [
              _Header(name: user?.name, className: user?.className),
              const SizedBox(height: 20),
              _MetaChips(
                rollNo: user?.rollNo,
                studentId: user?.studentId,
                courseCount: user?.courses.length ?? 0,
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Today\'s Classes'),
              const SizedBox(height: 12),
              _TodaySection(provider: classes),
              const SizedBox(height: 24),
              const _SectionTitle('My Courses'),
              const SizedBox(height: 12),
              _CoursesSection(provider: classes),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String? name;
  final String? className;

  const _Header({this.name, this.className});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            Fmt.initials(name),
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assalamu Alaikum,',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name ?? 'Student',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaChips extends StatelessWidget {
  final String? rollNo;
  final String? studentId;
  final int courseCount;

  const _MetaChips({this.rollNo, this.studentId, this.courseCount = 0});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (studentId != null) _chip('ID', studentId!),
      if (rollNo != null) _chip('Roll', rollNo!),
      _chip('Courses', '$courseCount'),
    ];

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    );
  }
}

class _TodaySection extends StatelessWidget {
  final ClassProvider provider;
  const _TodaySection({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.todayState == LoadState.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: LoadingView(),
      );
    }

    if (provider.todayState == LoadState.error) {
      return _InlineError(
        message: provider.todayError ?? 'Could not load classes',
        onRetry: () => provider.loadToday(force: true),
      );
    }

    if (provider.todayClasses.isEmpty) {
      return _InlineEmpty(
        icon: Icons.event_available_rounded,
        title: 'No classes today',
        subtitle: 'Enjoy your day — check the Classes tab for what\'s next.',
      );
    }

    return Column(
      children: provider.todayClasses
          .map((r) => ClassCard(routine: r, highlight: true))
          .toList(),
    );
  }
}

class _CoursesSection extends StatelessWidget {
  final ClassProvider provider;
  const _CoursesSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.coursesState == LoadState.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: LoadingView(),
      );
    }

    if (provider.coursesState == LoadState.error) {
      return _InlineError(
        message: provider.coursesError ?? 'Could not load courses',
        onRetry: () => provider.loadCourses(force: true),
      );
    }

    if (provider.courses.isEmpty) {
      return _InlineEmpty(
        icon: Icons.school_rounded,
        title: 'No courses yet',
        subtitle: 'You have not been enrolled in a course.',
      );
    }

    return Column(
      children: provider.courses.map((c) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.menu_book_rounded,
                    color: AppColors.goldLight, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${c.subjects.length} subjects · ${c.totalStudents} students',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text('Try again',
                style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InlineEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.muted, size: 30),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.muted, fontSize: 11.5, height: 1.5),
          ),
        ],
      ),
    );
  }
}
