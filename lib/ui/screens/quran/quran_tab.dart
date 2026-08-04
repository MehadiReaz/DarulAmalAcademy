import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/quran_progress.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/quran_provider.dart';
import '../../widgets/state_views.dart';

/// Qur'an progress dashboard driven by `GET /student/quran-progress`.
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // Top Bismillah & Student Header
            _BismillahHeader(
              name: quran.student?.name ?? user?.name,
              focusLabel: quran.focusLabel ?? progress?.readingFocusLabel,
            ),
            const SizedBox(height: 16),

            if (progress == null)
              _NoProgressYet(reference: quran.reference)
            else ...[
              // 4 Stat Cards (Responsive Wrap/Grid)
              _TopStatCardsGrid(progress: progress, quran: quran),
              const SizedBox(height: 16),

              // Para Juz Grid & Completed Surahs Row
              _ParaCompletionCard(progress: progress, reference: quran.reference),
              const SizedBox(height: 16),

              _CompletedSurahsCard(progress: progress, reference: quran.reference),
              const SizedBox(height: 16),

              // Weak Areas Section
              if (progress.weakAreas != null &&
                  progress.weakAreas!.trim().isNotEmpty) ...[
                _WeakAreasCard(weakAreas: progress.weakAreas!),
                const SizedBox(height: 16),
              ],
            ],

            // Teacher Feedback & History Timeline
            if (logs.isNotEmpty) ...[
              _FeedbackHistoryCard(logs: logs),
              const SizedBox(height: 16),
            ],

            const _FooterNote(),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────── Header Banner
class _BismillahHeader extends StatelessWidget {
  final String? name;
  final String? focusLabel;

  const _BismillahHeader({this.name, this.focusLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
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
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Student: ${name ?? 'Student'}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          if (focusLabel != null && focusLabel!.isNotEmpty) ...[
            const SizedBox(height: 8),
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

// ────────────────────────────────────────────── Top 4 Summary Cards
class _TopStatCardsGrid extends StatelessWidget {
  final QuranProgress progress;
  final QuranProvider quran;

  const _TopStatCardsGrid({required this.progress, required this.quran});

  @override
  Widget build(BuildContext context) {
    final totalParas = quran.reference.totalParas;
    final totalSurahs = quran.reference.surahs.isEmpty ? 114 : quran.reference.surahs.length;

    final nooraniText = quran.lessonLabel.isNotEmpty
        ? quran.lessonLabel
        : (progress.nooraniQaidaLesson != null
            ? 'Lesson ${progress.nooraniQaidaLesson}'
            : 'Lesson 1');

    final focusText = quran.focusLabel ?? progress.readingFocusLabel ?? 'Pronunciation';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                category: 'NOORANI QAIDA',
                title: nooraniText,
                progressFraction: progress.nooraniFraction,
                percentLabel: '${progress.nooraniQaidaPercentage.toStringAsFixed(0)}%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                category: 'READING FOCUS',
                title: focusText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                category: 'PARA COMPLETED',
                title: '${progress.parasCompleted}/$totalParas',
                progressFraction: progress.paraFraction,
                percentLabel: '${progress.paraPercentage.toStringAsFixed(0)}%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                category: 'SURAH COMPLETED',
                title: '${progress.surahsCompleted}/$totalSurahs',
                progressFraction: progress.surahFraction,
                percentLabel: '${progress.surahPercentage.toStringAsFixed(0)}%',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String category;
  final String title;
  final double? progressFraction;
  final String? percentLabel;

  const _MetricCard({
    required this.category,
    required this.title,
    this.progressFraction,
    this.percentLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.cream,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (progressFraction != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressFraction,
                      minHeight: 6,
                      backgroundColor: const Color(0xFF0E2622),
                      valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                    ),
                  ),
                ),
                if (percentLabel != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    percentLabel!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────── Para Completion Grid Card
class _ParaCompletionCard extends StatelessWidget {
  final QuranProgress progress;
  final QuranReferenceData reference;

  const _ParaCompletionCard({
    required this.progress,
    required this.reference,
  });

  @override
  Widget build(BuildContext context) {
    final totalParas = reference.totalParas;
    final completedSet = progress.parasCompletedList.toSet();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Para (Juz) Completion',
            style: TextStyle(
              color: AppColors.cream,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalParas,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 10,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              final paraNum = index + 1;
              final isDone = completedSet.contains(paraNum) ||
                  (completedSet.isEmpty && paraNum <= progress.parasCompleted);

              return Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDone
                      ? const Color(0xFF1E6B4B)
                      : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDone ? AppColors.success : AppColors.line,
                  ),
                ),
                child: Text(
                  '$paraNum',
                  style: TextStyle(
                    color: isDone ? Colors.white : AppColors.muted,
                    fontSize: 11,
                    fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────── Completed Surahs Card
class _CompletedSurahsCard extends StatelessWidget {
  final QuranProgress progress;
  final QuranReferenceData reference;

  const _CompletedSurahsCard({
    required this.progress,
    required this.reference,
  });

  @override
  Widget build(BuildContext context) {
    final surahNums = progress.surahsCompletedList.isNotEmpty
        ? progress.surahsCompletedList
        : (progress.surahsCompleted > 0
            ? List.generate(progress.surahsCompleted, (i) => i + 1)
            : const <int>[]);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Completed Surahs',
            style: TextStyle(
              color: AppColors.cream,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          if (surahNums.isEmpty)
            const Text(
              'No surahs completed yet.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: surahNums.map((surahNum) {
                final surahName = reference.surahName(surahNum);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E6B4B).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success),
                  ),
                  child: Text(
                    '$surahNum. $surahName',
                    style: const TextStyle(
                      color: AppColors.cream,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────── Weak Areas Card
class _WeakAreasCard extends StatelessWidget {
  final String weakAreas;

  const _WeakAreasCard({required this.weakAreas});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppColors.gold, size: 18),
              SizedBox(width: 8),
              Text(
                'Areas to Improve',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            weakAreas,
            style: const TextStyle(
              color: AppColors.cream,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────── Feedback & History Card
class _FeedbackHistoryCard extends StatelessWidget {
  final List<QuranProgressLog> logs;

  const _FeedbackHistoryCard({required this.logs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, color: AppColors.gold, size: 18),
              SizedBox(width: 8),
              Text(
                'Teacher Feedback & History',
                style: TextStyle(
                  color: AppColors.cream,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...logs.map((log) => _LogItemTile(log: log)),
        ],
      ),
    );
  }
}

class _LogItemTile extends StatelessWidget {
  final QuranProgressLog log;

  const _LogItemTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final dateStr = log.loggedAt != null
        ? Fmt.date(log.loggedAt)
        : (log.loggedOn ?? '');
    final remark = log.teacherRemark ?? log.note;
    final teacherName = log.teacher?.name ?? 'Teacher';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateStr,
                style: const TextStyle(
                  color: AppColors.cream,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                teacherName,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (log.tajweedRating != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gold),
                  ),
                  child: Text(
                    'Tajweed: ${log.tajweedRating}/5',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (log.readingFocusLabel != null &&
                  log.readingFocusLabel!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Text(
                    log.readingFocusLabel!,
                    style: TextStyle(
                      color: Colors.blue.shade200,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (remark != null && remark.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '"$remark"',
              style: const TextStyle(
                color: AppColors.cream,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────── Empty Fallback View
class _NoProgressYet extends StatelessWidget {
  final QuranReferenceData reference;

  const _NoProgressYet({required this.reference});

  @override
  Widget build(BuildContext context) {
    final focusList = reference.readingFocus.values.toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.menu_book_rounded, color: AppColors.gold, size: 22),
              SizedBox(width: 10),
              Text(
                'Qur\'an Study Curriculum',
                style: TextStyle(
                  color: AppColors.cream,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Your teacher will record your evaluations, lessons, and progress here after your live classes.',
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              _StatTile(
                label: 'Total Surahs',
                value: '${reference.surahs.isEmpty ? 114 : reference.surahs.length}',
              ),
              const SizedBox(width: 10),
              _StatTile(
                label: 'Total Paras',
                value: '${reference.totalParas}',
              ),
              const SizedBox(width: 10),
              _StatTile(
                label: 'Qaida Lessons',
                value: '${reference.totalLessons}',
              ),
            ],
          ),

          if (focusList.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'Reading Focus Modes',
              style: TextStyle(
                color: AppColors.cream,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: focusList.map((focus) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    focus,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
              ),
            ),
          ],
        ),
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
