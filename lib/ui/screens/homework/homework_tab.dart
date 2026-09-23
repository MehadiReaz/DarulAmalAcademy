import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/homework.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/homework_provider.dart';
import '../../widgets/state_views.dart';
import 'homework_detail_screen.dart';
import 'widgets/homework_card.dart';

/// Homework list screen styled with the app's signature deep-teal + gold theme.
class HomeworkTab extends StatefulWidget {
  const HomeworkTab({super.key});

  @override
  State<HomeworkTab> createState() => _HomeworkTabState();
}

class _HomeworkTabState extends State<HomeworkTab> {
  String _selectedCourse = 'All Courses';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeworkProvider>().load();
    });
  }

  void _openDetail(int id) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HomeworkDetailScreen(homeworkId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeworkProvider>();
    final allItems = provider.items;

    // Extract all unique course names
    final courseNames = <String>{};
    for (final hw in allItems) {
      courseNames.add(hw.courseDisplayName);
    }
    // Also include enrolled courses if present
    final user = context.watch<AuthProvider>().user;
    if (user != null) {
      for (final c in user.courses) {
        if (c.name != null && c.name!.trim().isNotEmpty) {
          courseNames.add(c.name!.trim());
        }
      }
    }
    final sortedCourses = courseNames.toList()..sort();

    // Filter items by selected course
    final filteredItems = _selectedCourse == 'All Courses'
        ? allItems
        : allItems.where((h) => h.courseDisplayName == _selectedCourse).toList();

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        title: const Text(
          'Homework',
          style: TextStyle(
            color: AppColors.cream,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.cream),
      ),
      body: Column(
        children: [
          // 1. Top Course Filter Bar
          _CourseFilterBar(
            courses: sortedCourses,
            selected: _selectedCourse,
            onSelected: (course) {
              setState(() {
                _selectedCourse = course;
              });
            },
          ),

          // 2. Main Content
          Expanded(
            child: _buildBody(provider, filteredItems),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(HomeworkProvider provider, List<Homework> items) {
    if (provider.listState == LoadState.loading && provider.items.isEmpty) {
      return const LoadingView();
    }

    if (provider.listState == LoadState.error && provider.items.isEmpty) {
      return ErrorView(
        message: provider.listError ?? 'Could not load homework',
        onRetry: () => provider.load(force: true),
      );
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.surface,
        onRefresh: () => provider.load(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.18),
            EmptyView(
              icon: Icons.assignment_outlined,
              title: _selectedCourse == 'All Courses'
                  ? 'No assignments available'
                  : 'No assignments for $_selectedCourse',
              subtitle: 'Assignments created by your teachers will appear here.',
            ),
          ],
        ),
      );
    }

    // Group items by course
    final grouped = <String, List<Homework>>{};
    for (final hw in items) {
      final cName = hw.courseDisplayName;
      grouped.putIfAbsent(cName, () => []).add(hw);
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () => provider.load(force: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        itemCount: grouped.keys.length,
        itemBuilder: (context, index) {
          final courseName = grouped.keys.elementAt(index);
          final courseItems = grouped[courseName]!;

          // Separate into Ongoing and Completed
          final ongoing = courseItems.where((h) {
            final isCompletedStatus = h.status.toLowerCase() == 'completed' ||
                h.status.toLowerCase() == 'expired';
            final isCompletedAssign =
                h.assignmentStatus?.toLowerCase() == 'completed assignment';
            return !h.isSubmitted && !isCompletedStatus && !isCompletedAssign;
          }).toList();

          final completed = courseItems.where((h) {
            final isCompletedStatus = h.status.toLowerCase() == 'completed' ||
                h.status.toLowerCase() == 'expired';
            final isCompletedAssign =
                h.assignmentStatus?.toLowerCase() == 'completed assignment';
            return h.isSubmitted || isCompletedStatus || isCompletedAssign;
          }).toList();

          final batchName = courseItems.isNotEmpty
              ? courseItems.first.batchDisplayName
              : '$courseName - Evening Batch';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course Title
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  courseName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.cream,
                    letterSpacing: -0.2,
                  ),
                ),
              ),

              // Batch Indicator with teal/gold dot
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      batchName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.goldLight,
                      ),
                    ),
                  ],
                ),
              ),

              // Ongoing Assignment Section
              if (ongoing.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text(
                    'Ongoing Assignment',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.cream,
                    ),
                  ),
                ),
                ...ongoing.map(
                  (hw) => HomeworkCard(
                    homework: hw,
                    onTap: () => _openDetail(hw.id),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Completed Assignment Section
              if (completed.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 14),
                  child: Text(
                    'Completed Assignment',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.cream,
                    ),
                  ),
                ),
                ...completed.map(
                  (hw) => HomeworkCard(
                    homework: hw,
                    onTap: () => _openDetail(hw.id),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────── Filter Bar
class _CourseFilterBar extends StatelessWidget {
  final List<String> courses;
  final String selected;
  final ValueChanged<String> onSelected;

  const _CourseFilterBar({
    required this.courses,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final allList = ['All Courses', ...courses];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: allList.map((course) {
            final isSelected = course == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelected(course),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.gold : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.goldLight
                          : AppColors.line,
                    ),
                  ),
                  child: Text(
                    course,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? const Color(0xFF231600)
                          : AppColors.muted,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

