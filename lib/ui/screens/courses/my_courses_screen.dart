import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/json_utils.dart';
import '../../../data/models/enrolled_course.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/class_provider.dart';
import '../../widgets/state_views.dart';

import 'course_detail_screen.dart';

class MyCoursesScreen extends StatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  State<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends State<MyCoursesScreen> {
  static const _fallbackImages = [
    'https://images.unsplash.com/photo-1609599006353-e629aaabfeae?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1584286595398-a59f21d313f5?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1542810634-71277d95dcbb?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1564769625905-50e93615e769?auto=format&fit=crop&w=800&q=80',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClassProvider>().loadCourses();
      context.read<ClassProvider>().loadBatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClassProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        title: const Text('My Enrolled Courses'),
        backgroundColor: const Color(0xFF07261F),
        elevation: 0,
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(ClassProvider provider) {
    if (provider.coursesState == LoadState.loading && provider.courses.isEmpty) {
      return const LoadingView(message: 'Loading your enrolled courses…');
    }

    if (provider.coursesState == LoadState.error && provider.courses.isEmpty) {
      return ErrorView(
        message: provider.coursesError ?? 'Could not load your courses',
        onRetry: () {
          provider.loadCourses(force: true);
          provider.loadBatches(force: true);
        },
      );
    }

    if (provider.courses.isEmpty) {
      return RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          await Future.wait([
            provider.loadCourses(force: true),
            provider.loadBatches(force: true),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.18),
            const EmptyView(
              icon: Icons.school_outlined,
              title: 'No enrolled courses',
              subtitle: 'Courses assigned to you by the madrasah will appear here.',
            ),
          ],
        ),
      );
    }

    final isWide = MediaQuery.of(context).size.width >= 650;

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () async {
        await Future.wait([
          provider.loadCourses(force: true),
          provider.loadBatches(force: true),
        ]);
      },
      child: isWide
          ? GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 415,
              ),
              itemCount: provider.courses.length,
              itemBuilder: (context, index) => _buildCard(context, provider, index),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              itemCount: provider.courses.length,
              itemBuilder: (context, index) => _buildCard(context, provider, index),
            ),
    );
  }

  Widget _buildCard(BuildContext context, ClassProvider provider, int index) {
    final courseItem = provider.courses[index];
    final matchingBatch = provider.batches.cast<Map<String, dynamic>?>().firstWhere(
      (b) => b != null && (
        asIntOrNull(b['course_id']) == courseItem.courseId ||
        asIntOrNull(asMap(b['course'])?['id']) == courseItem.courseId ||
        asIntOrNull(b['id']) == courseItem.id
      ),
      orElse: () => null,
    );

    return _CourseCard(
      item: courseItem,
      matchingBatch: matchingBatch,
      fallbackImage: _fallbackImages[index % _fallbackImages.length],
    );
  }
}

class _CourseCard extends StatelessWidget {
  final EnrolledCourse item;
  final Map<String, dynamic>? matchingBatch;
  final String fallbackImage;

  const _CourseCard({
    required this.item,
    this.matchingBatch,
    required this.fallbackImage,
  });

  @override
  Widget build(BuildContext context) {
    final course = item.course;
    final title = item.name;
    final batch = matchingBatch ?? {};
    final batchId = asIntOrNull(batch['id']) ?? item.id ?? 0;
    final batchName = asStringOrNull(batch['name'] ?? batch['batch_name']) ?? '$title - Evening Batch';
    final schedule = asStringOrNull(batch['schedule'] ?? batch['routine']) ?? '06:00 PM - 07:30 PM';
    final teacher = asMap(batch['teacher']);
    final teacherName = asStringOrNull(teacher?['name'] ?? batch['teacher_name']) ?? 'Qari Mahmood Al-Hussary';
    final duration = asStringOrNull(batch['duration'] ?? course?.duration) ?? '6 months';

    final effectiveImage = (course?.thumbnail != null && course!.thumbnail!.startsWith('http'))
        ? course.thumbnail!
        : fallbackImage;

    final batchTagText = schedule.isNotEmpty ? '$batchName · $schedule' : batchName;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Image Banner with Overlay Badge and Title
            Stack(
              children: [
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Image.network(
                    effectiveImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.25),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),

                // Top-Left: ✨ ENROLLED Pill Badge
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C7753),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: Colors.white,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'ENROLLED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom-Left: Course Title
                Positioned(
                  bottom: 14,
                  left: 16,
                  right: 16,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),

            // 2. Card Content Area
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Duration Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF112E27),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 20,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              duration,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.cream,
                              ),
                            ),
                            const SizedBox(height: 1),
                            const Text(
                              'DURATION',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.muted,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Batch & Schedule Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C7753).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      batchTagText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4FB286),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Bottom Action Button: Course Details
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0C7753),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CourseDetailScreen(
                              batchId: batchId,
                              courseTitle: title,
                              batchName: batchName,
                              schedule: schedule,
                              teacherName: teacherName,
                              duration: duration,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.visibility_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Course Details',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF13362E), Color(0xFF071E19)],
        ),
      ),
      child: Center(
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF0C7753).withValues(alpha: 0.8),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.menu_book_rounded, size: 26, color: Colors.white),
        ),
      ),
    );
  }
}
