import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/json_utils.dart';
import '../../../data/models/attendance.dart';
import '../../../data/models/enrolled_course.dart';
import '../../../data/models/homework.dart';
import '../../../data/models/live_session.dart';
import '../../../data/models/recording.dart';
import '../../../providers/class_provider.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/state_views.dart';
import '../homework/homework_detail_screen.dart';
import '../homework/widgets/homework_card.dart';
import '../recordings/drive_player_screen.dart';
import '../recordings/widgets/recording_card.dart';
import '../recordings/youtube_player_screen.dart';
import '../../../core/utils/responsive.dart';

class CourseDetailScreen extends StatefulWidget {
  final int batchId;
  final String courseTitle;
  final String? batchName;
  final String? schedule;
  final String? teacherName;
  final String? duration;

  const CourseDetailScreen({
    super.key,
    required this.batchId,
    required this.courseTitle,
    this.batchName,
    this.schedule,
    this.teacherName,
    this.duration,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _canonicalTabs = [
    {'key': 'details', 'label': 'Overview'},
    {'key': 'assignments', 'label': 'Homework'},
    {'key': 'online-class', 'label': 'Live Classes'},
    {'key': 'recordings', 'label': 'Recordings'},
    {'key': 'syllabus', 'label': 'Syllabus'},
    {'key': 'attendance', 'label': 'Attendance'},
  ];

  final Map<String, dynamic> _tabData = {};
  final Map<String, bool> _tabLoading = {};
  final Map<String, String?> _tabError = {};

  String? _batchName;
  String? _schedule;
  String? _teacherName;
  String? _duration;

  @override
  void initState() {
    super.initState();
    _batchName = widget.batchName;
    _schedule = widget.schedule;
    _teacherName = widget.teacherName;
    _duration = widget.duration;

    _tabController = TabController(length: _canonicalTabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadTab(_canonicalTabs[_tabController.index]['key']!);
      }
      setState(() {});
    });

    // Load initial tab
    _loadTab('details');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTab(String tabKey, {bool force = false}) async {
    if (!force && (_tabData.containsKey(tabKey) || _tabLoading[tabKey] == true)) {
      return;
    }

    setState(() {
      _tabLoading[tabKey] = true;
      _tabError[tabKey] = null;
    });

    try {
      final res = await context.read<ClassProvider>().loadCourseTab(
        widget.batchId,
        tabKey,
      );

      if (mounted) {
        setState(() {
          _tabData[tabKey] = res;
          _tabLoading[tabKey] = false;

          _extractDetails(res);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tabError[tabKey] = e.toString();
          _tabLoading[tabKey] = false;
        });
      }
    }
  }

  /// Pulls the header info out of any tab response: every tab repeats
  /// `course` and `selected_batch`.
  void _extractDetails(dynamic data) {
    final map = asMap(data) ?? {};
    final batchMap = asMap(map['selected_batch']) ?? asMap(map['batch']);
    if (batchMap != null) {
      final batch = CourseBatch.fromJson(batchMap);
      if (batch.name?.isNotEmpty ?? false) _batchName = batch.name;
      if (batch.schedule != null) _schedule = batch.schedule;
      final teacher = batch.teacher?.name;
      if (teacher?.isNotEmpty ?? false) _teacherName = teacher;
    }

    final course = asMap(map['course']);
    final duration = asStringOrNull(course?['duration']);
    if (duration != null && duration.isNotEmpty) {
      final unit = asStringOrNull(course?['duration_type']) ?? '';
      _duration = '$duration $unit'.trim();
    }
  }

  void _playRecording(Recording r) {
    if (r.isYoutubePlayable) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => YoutubePlayerScreen(
            recording: r,
            videoId: r.youtubeId!,
          ),
        ),
      );
    } else if (r.isPlayable) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DrivePlayerScreen(
            recording: r,
          ),
        ),
      );
    } else {
      AppToast.showInfo(context, 'Video link is unavailable.');
    }
  }

  Future<void> _launchExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        AppToast.showError(context, 'Could not open link: $url');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayBatchName = _batchName ?? widget.courseTitle;
    final displaySchedule = _schedule ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        title: Text(widget.courseTitle),
        backgroundColor: const Color(0xFF07261F),
        elevation: 0,
      ),
      body: ResponsiveBody(child: Column(
        children: [
          // 1. Header Banner matching reference design
          _buildHeaderBanner(displayBatchName, displaySchedule),

          // 2. Horizontal Pill Tab Bar
          _buildPillTabBar(),

          // 3. Tab Bar Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _canonicalTabs.map((tab) {
                final key = tab['key']!;
                return _buildTabView(key);
              }).toList(),
            ),
          ),
        ],
      )),
    );
  }

  Widget _buildHeaderBanner(String batchName, String schedule) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF06231C),
            Color(0xFF0F3E33),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Background subtle motif
          Positioned(
            right: -20,
            bottom: -20,
            child: Opacity(
              opacity: 0.08,
              child: Image.asset(
                'assets/darulamal-1.png',
                width: 170,
                height: 170,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.menu_book_rounded,
                  size: 150,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tag "My Course"
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C7753),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'My Course',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Course Name (Large bold)
                Text(
                  widget.courseTitle,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),

                // Batch & Schedule Subtitle
                Text(
                  schedule.isEmpty ? batchName : '$batchName · $schedule',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillTabBar() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0F2E28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(_canonicalTabs.length, (index) {
            final isSelected = _tabController.index == index;
            final label = _canonicalTabs[index]['label']!;

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _tabController.animateTo(index);
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0C7753)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF0C7753)
                            : Colors.white.withValues(alpha: 0.12),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.cream,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTabView(String key) {
    final isLoading = _tabLoading[key] ?? false;
    final error = _tabError[key];
    final data = _tabData[key];

    if (isLoading && data == null) {
      return const LoadingView(message: 'Loading details…');
    }

    if (error != null && data == null) {
      return ErrorView(
        message: error,
        onRetry: () => _loadTab(key, force: true),
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () => _loadTab(key, force: true),
      child: _buildTabContent(key, data),
    );
  }

  Widget _buildTabContent(String key, dynamic data) {
    switch (key) {
      case 'details':
        return _buildOverview(data);
      case 'assignments':
        return _buildAssignmentsList(data);
      case 'online-class':
        return _buildLiveClassesList(data);
      case 'recordings':
        return _buildRecordingsList(data);
      case 'syllabus':
        return _buildSyllabusList(data);
      case 'attendance':
        return _buildAttendanceList(data);
      default:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text('$data', style: const TextStyle(color: AppColors.cream)),
        );
    }
  }

  // ===========================================================================
  // TAB 1: Overview (Details & Study Summary)
  // ===========================================================================
  Widget _buildOverview(dynamic data) {
    final map = asMap(data) ?? {};
    final summary = asMap(map['summary']) ?? {};

    final batchName = _batchName ?? '—';
    final schedule = _schedule ?? '—';
    final teacher = _teacherName ?? '—';
    final duration = _duration ?? '—';

    final pendingHomework = asInt(summary['pending_homework']).toString();
    final upcomingClasses = asInt(summary['upcoming_classes']).toString();
    final recordingsCount = asInt(summary['recordings']).toString();
    final attendanceRate = '${asDouble(summary['attendance_rate']).round()}%';
    final sessionsCount = asInt(summary['attendance_total']).toString();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Card: Assigned Batch
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assigned Batch',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4FB286),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                batchName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.cream,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(color: AppColors.line, height: 1),
              const SizedBox(height: 12),
              _buildMetaRow('Batch', batchName),
              _buildMetaRow('Schedule', schedule),
              _buildMetaRow('Teacher', teacher),
              _buildMetaRow('Duration', duration),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Card: Study Summary
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Study Summary',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4FB286),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your Progress in this Batch',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.cream,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'All summaries are calculated specifically for this batch and your student account.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),

              // 4 Progress Stat Cards
              Row(
                children: [
                  Expanded(
                    child: _buildProgressCard(
                      icon: Icons.assignment_outlined,
                      iconColor: const Color(0xFF10B981),
                      cardBg: const Color(0xFF0E2E28),
                      borderColor: const Color(0xFF1B4D42),
                      value: pendingHomework,
                      title: 'Pending Homework',
                      subtitle: 'Not submitted yet',
                      onTap: () => _tabController.animateTo(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildProgressCard(
                      icon: Icons.videocam_outlined,
                      iconColor: const Color(0xFF3B82F6),
                      cardBg: const Color(0xFF0E2938),
                      borderColor: const Color(0xFF1B4254),
                      value: upcomingClasses,
                      title: 'Upcoming Classes',
                      subtitle: 'Scheduled from now',
                      onTap: () => _tabController.animateTo(2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildProgressCard(
                      icon: Icons.video_library_outlined,
                      iconColor: const Color(0xFF8B5CF6),
                      cardBg: const Color(0xFF231838),
                      borderColor: const Color(0xFF3E285C),
                      value: recordingsCount,
                      title: 'Recordings',
                      subtitle: 'Available to watch',
                      onTap: () => _tabController.animateTo(3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildProgressCard(
                      icon: Icons.fact_check_outlined,
                      iconColor: const Color(0xFFF59E0B),
                      cardBg: const Color(0xFF2E2413),
                      borderColor: const Color(0xFF4D3B1C),
                      value: attendanceRate,
                      title: 'Attendance',
                      subtitle: '$sessionsCount sessions recorded',
                      onTap: () => _tabController.animateTo(5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.cream,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard({
    required IconData icon,
    required Color iconColor,
    required Color cardBg,
    required Color borderColor,
    required String value,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: iconColor),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Flexible(
                  child: Text(
                    'View Details',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: iconColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 12, color: iconColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 2: Homework (Assignments)
  // ===========================================================================
  Widget _buildAssignmentsList(dynamic data) {
    final list = _extractList(data, 'assignments');
    final homeworkList = <Homework>[];

    for (final item in list) {
      if (item is Homework) {
        homeworkList.add(item);
      } else if (item is Map) {
        homeworkList.add(Homework.fromJson(item.cast<String, dynamic>()));
      }
    }

    if (homeworkList.isEmpty) {
      return const EmptyView(
        icon: Icons.assignment_outlined,
        title: 'No homework found',
        subtitle: 'Assignments for this batch will appear here.',
      );
    }

    final ongoing = homeworkList.where((h) {
      final isCompletedStatus = h.status.toLowerCase() == 'completed' ||
          h.status.toLowerCase() == 'expired';
      final isCompletedAssign =
          h.assignmentStatus?.toLowerCase() == 'completed assignment';
      return !h.isSubmitted && !isCompletedStatus && !isCompletedAssign;
    }).toList();

    final completed = homeworkList.where((h) {
      final isCompletedStatus = h.status.toLowerCase() == 'completed' ||
          h.status.toLowerCase() == 'expired';
      final isCompletedAssign =
          h.assignmentStatus?.toLowerCase() == 'completed assignment';
      return h.isSubmitted || isCompletedStatus || isCompletedAssign;
    }).toList();

    final displayBatchName = _batchName ?? homeworkList.first.batchDisplayName;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // Batch Indicator with gold dot (matching HomeworkTab design)
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
              Expanded(
                child: Text(
                  displayBatchName,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldLight,
                  ),
                  overflow: TextOverflow.ellipsis,
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
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HomeworkDetailScreen(homeworkId: hw.id),
                  ),
                );
              },
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
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HomeworkDetailScreen(homeworkId: hw.id),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  // ===========================================================================
  // TAB 3: Live Classes
  // ===========================================================================
  Widget _buildLiveClassesList(dynamic data) {
    final list = _extractList(data, 'classes')
        .map((e) => e is LiveSession
            ? e
            : LiveSession.fromJson(asMap(e) ?? const {}))
        .toList();

    if (list.isEmpty) {
      return const EmptyView(
        icon: Icons.video_camera_front_outlined,
        title: 'No live classes scheduled',
        subtitle: 'Upcoming online classes will appear here.',
      );
    }

    final displayBatchName = _batchName ?? widget.courseTitle;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // Batch Indicator with gold dot
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
              Expanded(
                child: Text(
                  displayBatchName,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        ...list.map((item) => _buildLiveClassCard(item)),
      ],
    );
  }

  Widget _buildLiveClassCard(LiveSession item) {
    final topic = item.topic;
    final course = item.course?.name ?? widget.courseTitle;
    final batch = item.batch?.name ?? _batchName ?? widget.courseTitle;
    final teacher = item.teacher?.name ?? _teacherName ?? '—';
    final startTime = item.displayDate;
    final password = item.password;
    final description = item.description ?? '';
    final joinUrl = item.joinUrl;
    final isLive = item.isLive;
    final status = isLive
        ? 'Live'
        : (item.onlineClassStatus ?? item.status ?? 'Upcoming');

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
                // Top Row: [ LV ] Badge on left, Status Pill on right
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
                        'LV',
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

                // Title
                Text(
                  topic,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.cream,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),

                // Detail rows with outline icons
                MetadataRow(
                  icon: Icons.menu_book_outlined,
                  label: 'Course',
                  value: course,
                ),
                const SizedBox(height: 9),
                MetadataRow(
                  icon: Icons.groups_outlined,
                  label: 'Batch',
                  value: batch,
                ),
                const SizedBox(height: 9),
                MetadataRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Teacher',
                  value: teacher,
                ),
                const SizedBox(height: 9),
                MetadataRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Start Time',
                  value: startTime,
                ),
                if (password != null && password.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  _buildLivePasswordRow(password),
                ],

                if (description.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  DescriptionMetadataRow(
                    icon: Icons.folder_open_outlined,
                    label: 'Description',
                    text: description,
                  ),
                ],

                const SizedBox(height: 15),
                const Divider(height: 1, color: AppColors.line),
                const SizedBox(height: 13),

                // Button
                if (joinUrl != null && joinUrl.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: const Color(0xFF231600),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => _launchExternalUrl(joinUrl),
                      icon: const Icon(Icons.videocam_rounded, size: 20),
                      label: const Text(
                        'Join Live Class',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.schedule_rounded, size: 16, color: AppColors.muted),
                        SizedBox(width: 8),
                        Text(
                          'Class has not started yet',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePasswordRow(String password) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.vpn_key_outlined, size: 16, color: AppColors.goldLight),
        const SizedBox(width: 9),
        const Text(
          'Password: ',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          password,
          style: const TextStyle(
            color: AppColors.cream,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: password));
            AppToast.showSuccess(context, 'Password copied to clipboard');
          },
          borderRadius: BorderRadius.circular(4),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.copy_rounded, size: 15, color: AppColors.goldLight),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 4: Recordings
  // ===========================================================================
  Widget _buildRecordingsList(dynamic data) {
    final list = _extractList(data, 'recordings');
    final recordingList = <Recording>[];

    for (final item in list) {
      if (item is Recording) {
        recordingList.add(item);
      } else if (item is Map) {
        recordingList.add(Recording.fromJson(item.cast<String, dynamic>()));
      }
    }

    if (recordingList.isEmpty) {
      return const EmptyView(
        icon: Icons.play_circle_outline_rounded,
        title: 'No recordings available',
        subtitle: 'Recorded lessons will appear here once available.',
      );
    }

    final displayBatchName =
        _batchName ?? recordingList.first.batch?.name ?? widget.courseTitle;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // Batch Indicator with gold dot
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
              Expanded(
                child: Text(
                  displayBatchName,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        ...recordingList.map(
          (recording) => RecordingCard(
            recording: recording,
            onPlay: () => _playRecording(recording),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 5: Syllabus
  // ===========================================================================
  Widget _buildSyllabusList(dynamic data) {
    final list = _extractList(data, 'syllabus');
    if (list.isEmpty) {
      return const EmptyView(
        icon: Icons.menu_book_outlined,
        title: 'No syllabus yet',
        subtitle: 'The syllabus for this course will appear here once added.',
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final item = asMap(list[i]) ?? {};
        final title = asString(item['title'] ?? item['name'], fallback: 'Lesson ${i + 1}');
        final subtitle = asString(item['subtitle'] ?? item['description']);

        return _buildSyllabusItem(
          number: '${i + 1}',
          title: title,
          subtitle: subtitle,
        );
      },
    );
  }

  Widget _buildSyllabusItem({
    required String number,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number circle
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFD1F2E8),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0C7753),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.cream,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 6: Attendance
  // ===========================================================================
  Widget _buildAttendanceList(dynamic data) {
    final list = _extractList(data, 'attendance')
        .map((e) => AttendanceRecord.fromJson(asMap(e) ?? const {}))
        .toList();

    // Same rule as the Attendance screen: late is not counted as present.
    final present = list.where((r) => r.isPresent).length;
    final absent = list.length - present;
    final total = list.length;
    final rate = total > 0 ? '${((present / total) * 100).toStringAsFixed(0)}%' : '0%';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Attendance Statistics',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4FB286),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAttendanceStat('Total Classes', '$total', AppColors.cream),
                  _buildAttendanceStat('Present', '$present', const Color(0xFF10B981)),
                  _buildAttendanceStat('Absent', '$absent', const Color(0xFFEF4444)),
                  _buildAttendanceStat('Attendance Rate', rate, AppColors.goldLight),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: EmptyView(
              icon: Icons.fact_check_outlined,
              title: 'No attendance records found',
              subtitle: 'Your attendance records will appear here as classes take place.',
            ),
          )
        else
          ...list.map((r) {
            final date = r.dateLabel ?? r.rawDate ?? '—';
            final isPresent = r.isPresent;
            final badgeColor = isPresent
                ? const Color(0xFF10B981)
                : (r.isLate ? AppColors.gold : const Color(0xFFEF4444));

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.gold),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      date,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.cream,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      r.statusLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildAttendanceStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }


  List<dynamic> _extractList(dynamic data, String preferredKey) {
    if (data == null) return const [];
    if (data is List) return data;

    if (data is Map) {
      final aliases = <String, List<String>>{
        'classes': [
          'classes',
          'online_classes',
          'online-classes',
          'live_classes',
          'live_sessions',
          'sessions',
          'online-class',
          'live-classes',
        ],
        'assignments': [
          'assignments',
          'homework',
          'homeworks',
          'tasks',
        ],
        'recordings': [
          'recordings',
          'videos',
          'recorded_classes',
        ],
        'syllabus': [
          'syllabuses',
          'syllabus',
          'lessons',
          'chapters',
          'topics',
        ],
        'attendance': [
          'attendances',
          'attendance',
          'records',
          'logs',
        ],
      };

      final candidateKeys = aliases[preferredKey] ?? [preferredKey];

      List<dynamic>? resolveBlock(dynamic block) {
        if (block == null) return null;
        if (block is List) return block;
        if (block is Map) {
          if (block['data'] is List) return block['data'] as List;
          if (block['data'] is Map) {
            final flattened = <dynamic>[];
            (block['data'] as Map).forEach((k, v) {
              if (v is List) flattened.addAll(v);
            });
            if (flattened.isNotEmpty) return flattened;
          }
          final flattened = <dynamic>[];
          block.forEach((k, v) {
            if (v is List) flattened.addAll(v);
          });
          if (flattened.isNotEmpty) return flattened;
        }
        return null;
      }

      // 1. Direct candidate keys in root
      for (final key in candidateKeys) {
        final res = resolveBlock(data[key]);
        if (res != null && res.isNotEmpty) return res;
      }

      // 2. data['data']
      final resRootData = resolveBlock(data['data']);
      if (resRootData != null && resRootData.isNotEmpty) {
        return resRootData;
      }

      // 3. Inspect candidate keys within data['data']
      if (data['data'] is Map) {
        final innerMap = data['data'] as Map;
        for (final key in candidateKeys) {
          final res = resolveBlock(innerMap[key]);
          if (res != null && res.isNotEmpty) return res;
        }
      }
    }

    return const [];
  }
}
