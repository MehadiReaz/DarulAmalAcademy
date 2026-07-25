import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/homework.dart';
import '../../../data/repositories/homework_repository.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/homework_provider.dart';
import '../../widgets/state_views.dart';
import 'homework_detail_screen.dart';

/// Homework list, backed by `GET /student/homework`.
///
/// These endpoints have existed on the backend (and been declared in
/// `ApiEndpoints`) for a while with no app code behind them; this is that
/// missing surface.
class HomeworkTab extends StatefulWidget {
  const HomeworkTab({super.key});

  @override
  State<HomeworkTab> createState() => _HomeworkTabState();
}

class _HomeworkTabState extends State<HomeworkTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeworkProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeworkProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Homework')),
      body: Column(
        children: [
          _FilterBar(
            active: provider.filter,
            onChanged: (f) => provider.setFilter(f),
          ),
          Expanded(child: _buildBody(provider)),
        ],
      ),
    );
  }

  Widget _buildBody(HomeworkProvider provider) {
    if (provider.listState == LoadState.loading && provider.items.isEmpty) {
      return const LoadingView();
    }

    if (provider.listState == LoadState.error && provider.items.isEmpty) {
      return ErrorView(
        message: provider.listError ?? 'Could not load homework',
        onRetry: () => provider.load(force: true),
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () => provider.load(force: true),
      child: provider.items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.14),
                EmptyView(
                  icon: Icons.assignment_outlined,
                  title: provider.filter == HomeworkFilter.submitted
                      ? 'Nothing submitted yet'
                      : 'No homework right now',
                  subtitle: provider.filter == HomeworkFilter.all
                      ? 'Work set by your teachers will appear here.'
                      : 'Try a different filter.',
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
              itemCount: provider.items.length,
              itemBuilder: (context, i) =>
                  _HomeworkTile(homework: provider.items[i]),
            ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final HomeworkFilter active;
  final ValueChanged<HomeworkFilter> onChanged;

  const _FilterBar({required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
      child: Row(
        children: HomeworkFilter.values.map((f) {
          final selected = f == active;
          return Padding(
            padding: const EdgeInsets.only(right: 9),
            child: ChoiceChip(
              label: Text(f.label),
              selected: selected,
              onSelected: (_) => onChanged(f),
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.gold,
              side: const BorderSide(color: AppColors.line),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? const Color(0xFF231600) : AppColors.muted,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HomeworkTile extends StatelessWidget {
  final Homework homework;
  const _HomeworkTile({required this.homework});

  Color get _statusColor {
    if (homework.isSubmitted) return AppColors.success;
    if (homework.showAsOverdue) return AppColors.danger;
    return AppColors.goldLight;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HomeworkDetailScreen(homeworkId: homework.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: homework.showAsOverdue ? AppColors.danger : AppColors.line,
            width: homework.showAsOverdue ? 1.3 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    homework.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    homework.dueLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (homework.subject?.name != null ||
                homework.teacher?.name != null) ...[
              const SizedBox(height: 6),
              Text(
                [
                  if (homework.subject?.name != null) homework.subject!.name!,
                  if (homework.teacher?.name != null) homework.teacher!.name!,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11.5,
                ),
              ),
            ],
            if (homework.description != null &&
                homework.description!.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                homework.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 11),
            Row(
              children: [
                Icon(
                  homework.isSubmitted
                      ? Icons.check_circle_rounded
                      : Icons.schedule_rounded,
                  size: 13,
                  color: _statusColor,
                ),
                const SizedBox(width: 5),
                Text(
                  homework.dueDate ?? 'No due date',
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (homework.hasMarks)
                  Text(
                    'Marks: ${homework.marks}',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
