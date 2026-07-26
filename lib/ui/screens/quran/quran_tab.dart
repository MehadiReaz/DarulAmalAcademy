import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/quran_progress.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/quran_provider.dart';
import '../../widgets/state_views.dart';

/// Qur'an progress, driven by `GET /student/quran-progress`.
///
/// That dedicated endpoint supersedes the `quran_progress` block on the
/// profile payload: it paginates the teacher's notes and ships the
/// curriculum reference data (114 surahs, bilingual focus labels, lesson
/// and para totals), so progress renders against the madrasah's own
/// denominators instead of hardcoded ones.
///
/// The profile block is still used as a fallback — it is the same data,
/// and it means the screen has something to show if the dedicated call
/// fails.
class QuranTab extends StatefulWidget {
  const QuranTab({super.key});

  @override
  State<QuranTab> createState() => _QuranTabState();
}

class _QuranTabState extends State<QuranTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuranProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final quran = context.watch<QuranProvider>();
    final user = auth.user;

    final progress = quran.progress ?? user?.quranProgress;
    final logs = quran.logs.isNotEmpty
        ? quran.logs
        : (user?.quranProgressLogs ?? const <QuranProgressLog>[]);

    if (quran.state == LoadState.loading && progress == null && logs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Qur'an Progress")),
        body: const LoadingView(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Qur'an Progress")),
      body: RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          await Future.wait([
            quran.load(force: true),
            auth.reloadProfile(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
          children: [
            _BismillahHeader(
              name: user?.name,
              focusLabel: quran.focusLabel ?? progress?.readingFocusLabel,
            ),
            const SizedBox(height: 20),

            if (progress == null)
              const _NoProgressYet()
            else ...[
              _ProgressCard(
                title: 'Noorani Qaida',
                progress: progress.nooraniFraction,
                displayValue: _percentLabel(progress.nooraniQaidaPercentage),
                // Lesson total comes from reference_data, not a constant.
                detail: quran.lessonLabel.isNotEmpty
                    ? quran.lessonLabel
                    : (progress.nooraniQaidaLesson != null
                        ? 'Lesson ${progress.nooraniQaidaLesson}'
                        : null),
              ),
              _ProgressCard(
                title: "Qur'an Majeed",
                progress: progress.paraFraction,
                displayValue: _percentLabel(progress.paraPercentage),
                detail: progress.parasCompleted > 0 ? quran.paraLabel : null,
              ),
              _ProgressCard(
                title: 'Surah Memorization',
                progress: progress.surahFraction,
                displayValue: _percentLabel(progress.surahPercentage),
                detail: progress.surahsCompleted > 0
                    ? '${progress.surahsCompleted} of '
                        '${quran.reference.surahs.isEmpty ? 114 : quran.reference.surahs.length} '
                        'surah memorized'
                    : null,
              ),
              if (progress.assignedTeacher?.name != null) ...[
                const SizedBox(height: 4),
                _TeacherStrip(name: progress.assignedTeacher!.name!),
              ],
            ],

            if (logs.isNotEmpty) ...[
              const SizedBox(height: 22),
              const Text(
                'Recent Notes',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ...logs.take(8).map((log) => _LogCard(log: log)),
            ],

            const SizedBox(height: 20),
            const _FooterNote(),
          ],
        ),
      ),
    );
  }

  /// Renders 0 as "Not started" rather than a bare "0%", which reads as a
  /// failing score to a student rather than "we haven't begun yet".
  static String _percentLabel(double percent) {
    if (percent <= 0) return 'Not started';
    if (percent >= 100) return 'Complete';
    return '${percent.toStringAsFixed(percent % 1 == 0 ? 0 : 1)}%';
  }
}

class _BismillahHeader extends StatelessWidget {
  final String? name;
  final String? focusLabel;

  const _BismillahHeader({this.name, this.focusLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          const Text(
            'بِسْمِ اللَّهِ',
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 28,
              color: AppColors.goldLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Student: ${name ?? 'Student'}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          if (focusLabel != null && focusLabel!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Current focus: $focusLabel',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoProgressYet extends StatelessWidget {
  const _NoProgressYet();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: EmptyView(
        icon: Icons.menu_book_rounded,
        title: 'No progress recorded yet',
        subtitle:
            'Your teacher will start recording your Qur\'an progress after '
            'your first few classes. Pull down to refresh.',
      ),
    );
  }
}

class _TeacherStrip extends StatelessWidget {
  final String name;
  const _TeacherStrip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_rounded, size: 17, color: AppColors.gold),
          const SizedBox(width: 11),
          const Text(
            'Assigned teacher',
            style: TextStyle(color: AppColors.muted, fontSize: 11.5),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final QuranProgressLog log;
  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final note = log.note;
    if (note == null || note.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note_rounded,
                  size: 15, color: AppColors.goldLight),
              const SizedBox(width: 7),
              Text(
                log.loggedAt != null
                    ? Fmt.date(log.loggedAt)
                    : (log.loggedOn ?? ''),
                style:
                    const TextStyle(color: AppColors.muted, fontSize: 10.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: const TextStyle(fontSize: 12, height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: AppColors.muted),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your teacher updates your Qur\'an progress after each class. '
              'Pull down to refresh.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String title;
  final double progress; // 0.0 – 1.0
  final String displayValue;
  final String? detail;

  const _ProgressCard({
    required this.title,
    required this.progress,
    required this.displayValue,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                displayValue,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: const Color(0xFF0E2622),
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
            ),
          ),
          if (detail != null && detail!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              detail!,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
