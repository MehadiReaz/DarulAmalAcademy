import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/dashboard_data.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/notice_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/shell_provider.dart';
import '../attendance/attendance_screen.dart';
import '../batches/my_batches_screen.dart';
import '../courses/my_courses_screen.dart';
import '../homework/homework_tab.dart';
import '../lessons/lessons_screen.dart';
import '../notices/notice_tab.dart';
import '../notifications/notifications_screen.dart';
import '../payment/pay_fees_screen.dart';
import '../recordings/recordings_screen.dart';
import '../routine/routine_screen.dart';
import '../support/support_tab.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClassProvider>().loadToday();
      context.read<DashboardProvider>().load();
      context.read<NoticeProvider>().loadNotices();
      context.read<NotificationProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final dashboard = context.watch<DashboardProvider>();
    final classes = context.watch<ClassProvider>();
    final notices = context.watch<NoticeProvider>();
    final notifications = context.watch<NotificationProvider>();
    final user = auth.user;
    final dashData = dashboard.data;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            await Future.wait([
              classes.loadToday(force: true),
              dashboard.load(force: true),
              notifications.load(force: true),
              auth.reloadProfile(),
            ]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
            children: [
              // Header
              _Header(
                name: user?.name,
                unreadAlerts: notifications.unreadCount,
                profileImage: user?.profilePhotoUrl,
                onBellTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Student Meta Chips + Course Tags
              _MetaChips(
                studentId: user?.studentId,
                rollNo: user?.rollNo,
                className: user?.className,
                courseNames: dashData?.courseNames ?? [],
              ),
              const SizedBox(height: 18),

              // Academic Performance & Attendance Overview Card
              if (dashData != null) ...[
                _AcademicOverviewCard(data: dashData),
                const SizedBox(height: 18),
              ],

              // Live Class Card (if live/upcoming class exists)
              _LiveClassCard(dashboard: dashboard),

              // Upcoming Due Homework Section
              if (dashData != null && dashData.nextAssignments.isNotEmpty) ...[
                _SectionTitle(
                  'Upcoming Due Homework',
                  trailing: 'View All',
                  onTrailingTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HomeworkTab()),
                  ),
                ),
                const SizedBox(height: 10),
                _NextAssignmentsList(assignments: dashData.nextAssignments),
                const SizedBox(height: 18),
              ],

              // Madrasah Events Section
              if (dashData != null && dashData.upcomingEvents.isNotEmpty) ...[
                const _SectionTitle('Events & Activities'),
                const SizedBox(height: 10),
                _UpcomingEventsList(events: dashData.upcomingEvents),
                const SizedBox(height: 18),
              ],

              // Quick Actions Grid
              const _SectionTitle('Quick Actions'),
              const SizedBox(height: 12),
              _QuickActionsGrid(
                pendingHomework: dashboard.quickStats.pendingAssignments,
                unreadNotices: notices.unreadCount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────── Header
class _Header extends StatelessWidget {
  final String? name;
  final int unreadAlerts;
  final VoidCallback? onBellTap;
  final String? profileImage;

  const _Header({
    this.name,
    this.unreadAlerts = 0,
    this.onBellTap,
    this.profileImage,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = profileImage != null && profileImage!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Avatar with Ring
          Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF25524B), Color(0xFF163731)],
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: hasImage
                      ? Image.network(
                          profileImage!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _initialsWidget(),
                        )
                      : _initialsWidget(),
                ),
              ),
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Greeting & Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 13,
                      color: AppColors.gold,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Assalamu Alaikum',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.goldLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  name ?? 'Student',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.cream,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 1),
                const Text(
                  'Darul Amal Academy',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Notification Bell Button
          Material(
            color: const Color(0xFF183832),
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: onBellTap,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.25),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      size: 22,
                      color: AppColors.goldLight,
                    ),
                    if (unreadAlerts > 0)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.surface,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            unreadAlerts > 99 ? '99+' : '$unreadAlerts',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initialsWidget() {
    return Center(
      child: Text(
        Fmt.initials(name),
        style: const TextStyle(
          color: AppColors.gold,
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────── Meta Chips
class _MetaChips extends StatelessWidget {
  final String? studentId;
  final String? rollNo;
  final String? className;
  final List<String> courseNames;

  const _MetaChips({
    this.studentId,
    this.rollNo,
    this.className,
    this.courseNames = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (studentId != null) _chip('ID', studentId!),
        if (rollNo != null) _chip('Roll', rollNo!),
        if (className != null && className != '—') _chip('Class', className!),
        ...courseNames.map((c) => _courseChip(c)),
      ],
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                color: AppColors.cream,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _courseChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF193731),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        name,
        style: const TextStyle(
          color: AppColors.goldLight,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────── Academic Overview Card
class _AcademicOverviewCard extends StatelessWidget {
  final DashboardData data;
  const _AcademicOverviewCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final totalAtt = data.totalAttendanceRecords;
    final present = data.presentClasses;
    final lateCls = data.lateClasses;
    final absent = data.absentClasses;

    final presentPct = totalAtt > 0 ? (present / totalAtt * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.analytics_outlined,
                    color: AppColors.goldLight,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Academic Overview',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.cream,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '$presentPct% Attendance',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _statItem(
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF2ECC71),
                  label: 'Present',
                  value: '$present',
                ),
              ),
              Expanded(
                child: _statItem(
                  icon: Icons.access_time_rounded,
                  color: const Color(0xFFF39C12),
                  label: 'Late',
                  value: '$lateCls',
                ),
              ),
              Expanded(
                child: _statItem(
                  icon: Icons.cancel_outlined,
                  color: const Color(0xFFE74C3C),
                  label: 'Absent',
                  value: '$absent',
                ),
              ),
              Expanded(
                child: _statItem(
                  icon: Icons.assignment_turned_in_outlined,
                  color: AppColors.goldLight,
                  label: 'Submitted',
                  value:
                      '${data.totalSubmittedAssignments}/${data.totalAssignments}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.cream,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────── Next Assignments List
class _NextAssignmentsList extends StatelessWidget {
  final List<DashboardAssignment> assignments;
  const _NextAssignmentsList({required this.assignments});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 124,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: assignments.length,
        itemBuilder: (context, i) {
          final item = assignments[i];
          final remDays = item.remainingDays ?? 0;
          final daysText = remDays == 0
              ? 'Due Today'
              : (remDays == 1 ? 'Due Tomorrow' : 'Due in $remDays days');

          return Container(
            width: 240,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (item.studentClass?.name != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF24504A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.studentClass!.name!,
                          style: const TextStyle(
                            color: AppColors.goldLight,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: remDays <= 1
                            ? AppColors.danger.withValues(alpha: 0.2)
                            : AppColors.gold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        daysText,
                        style: TextStyle(
                          color: remDays <= 1
                              ? AppColors.danger
                              : AppColors.gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cream,
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 13,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.teacher?.name ?? 'Teacher',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────── Upcoming Events List
class _UpcomingEventsList extends StatelessWidget {
  final List<DashboardEvent> events;
  const _UpcomingEventsList({required this.events});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: events.map((evt) {
        final isRunning = evt.status?.toLowerCase() == 'running';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRunning
                  ? const Color(0xFF2ECC71).withValues(alpha: 0.5)
                  : AppColors.line,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isRunning
                      ? const Color(0xFF2ECC71).withValues(alpha: 0.15)
                      : AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.event_note_rounded,
                  color: isRunning ? const Color(0xFF2ECC71) : AppColors.gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      evt.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.cream,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (evt.start != null)
                      Text(
                        evt.end != null && evt.end != evt.start
                            ? '${evt.start} – ${evt.end}'
                            : evt.start!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              if (evt.status != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isRunning
                        ? const Color(0xFF2ECC71)
                        : AppColors.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    evt.status!,
                    style: TextStyle(
                      color: isRunning ? Colors.white : AppColors.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────── Live Class Card
class _LiveClassCard extends StatelessWidget {
  final DashboardProvider dashboard;
  const _LiveClassCard({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final live = dashboard.liveClass;
    final next = dashboard.nextClass;
    final featured = live ?? next;

    if (featured == null) return const SizedBox(height: 4);

    final isLive = live != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.gold, AppColors.goldDeep],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLive) ...[
                      const _PulsingDot(),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      isLive ? 'LIVE NOW' : 'UPCOMING CLASS',
                      style: const TextStyle(
                        color: Color(0xFF241700),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                featured.title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF241700),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${featured.startTime} – ${featured.endTime}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF241700).withValues(alpha: 0.85),
                ),
              ),
              if (isLive) ...[
                const SizedBox(height: 16),
                Material(
                  color: const Color(0xFF241700),
                  borderRadius: BorderRadius.circular(13),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening live class…')),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 16,
                            color: AppColors.goldLight,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Join Live Class',
                            style: TextStyle(
                              color: AppColors.goldLight,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_controller),
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: Color(0xFFC0392B),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────── Section Title
class _SectionTitle extends StatelessWidget {
  final String text;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  const _SectionTitle(this.text, {this.trailing, this.onTrailingTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailingTap,
              child: Text(
                trailing!,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────── Quick Actions Grid
class _QuickActionsGrid extends StatelessWidget {
  final int pendingHomework;
  final int unreadNotices;

  const _QuickActionsGrid({this.pendingHomework = 0, this.unreadNotices = 0});

  @override
  Widget build(BuildContext context) {
    void goToTab(int index) => context.read<ShellProvider>().goTo(index);

    void push(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 11,
      crossAxisSpacing: 11,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.86,
      children: [
        _ModuleItem(
          icon: Icons.school_rounded,
          label: 'My Courses',
          onTap: () => push(const MyCoursesScreen()),
        ),
        _ModuleItem(
          icon: Icons.groups_3_rounded,
          label: 'My Batches',
          onTap: () => push(const MyBatchesScreen()),
        ),
        _ModuleItem(
          icon: Icons.calendar_month_rounded,
          label: 'Routine',
          onTap: () => push(const RoutineScreen()),
        ),
        _ModuleItem(
          icon: Icons.assignment_rounded,
          label: 'Homework',
          badge: pendingHomework,
          onTap: () => push(const HomeworkTab()),
        ),
        _ModuleItem(
          icon: Icons.credit_card_rounded,
          label: 'Fees',
          onTap: () => push(const PayFeesScreen()),
        ),
        _ModuleItem(
          icon: Icons.campaign_rounded,
          label: 'Notice',
          badge: unreadNotices,
          onTap: () => push(const NoticeTab()),
        ),
        _ModuleItem(
          icon: Icons.menu_book_rounded,
          label: "Qur'an",
          onTap: () => goToTab(ShellTab.quran),
        ),
        _ModuleItem(
          icon: Icons.play_circle_outline_rounded,
          label: 'Recordings',
          onTap: () => push(const RecordingsScreen()),
        ),
        _ModuleItem(
          icon: Icons.auto_stories_outlined,
          label: 'Lessons',
          onTap: () => push(const LessonsScreen()),
        ),
        _ModuleItem(
          icon: Icons.fact_check_outlined,
          label: 'Attendance',
          onTap: () => push(const AttendanceScreen()),
        ),
        _ModuleItem(
          icon: Icons.forum_outlined,
          label: 'Group Chat',
          onTap: () => goToTab(ShellTab.chat),
        ),
        _ModuleItem(
          icon: Icons.support_agent_rounded,
          label: 'Support',
          onTap: () => push(const SupportTab()),
        ),
      ],
    );
  }
}

class _ModuleItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  const _ModuleItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF24504A), Color(0xFF173731)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 22, color: AppColors.goldLight),
                  ),
                  if (badge > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        constraints: const BoxConstraints(minWidth: 18),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: AppColors.surface,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.cream,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
