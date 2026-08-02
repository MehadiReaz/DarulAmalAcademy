import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/notice_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/shell_provider.dart';
import '../attendance/attendance_screen.dart';
import '../homework/homework_tab.dart';
import '../lessons/lessons_screen.dart';
import '../notices/notice_tab.dart';
import '../notifications/notifications_screen.dart';
import '../payment/pay_fees_screen.dart';
import '../recordings/recordings_screen.dart';
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
      // Loads the unread count for the Notice quick action.
      context.read<NoticeProvider>().loadNotices();
      // Drives the dot on the header bell.
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
              _Header(
                name: user?.name,
                // The bell now opens the notification centre; notices keep
                // their own quick-action tile below.
                unreadAlerts: notifications.unreadCount,
                // Was `user!.profilePhotoUrl!` — a student with no photo,
                // or a cold start before the profile call returns, threw
                // on this line and blanked the whole Home tab.
                profileImage: user?.profilePhotoUrl,
                onBellTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
              ),
              const SizedBox(height: 14),
              _MetaChips(
                studentId: user?.studentId,
                rollNo: user?.rollNo,
                className: user?.className,
              ),
              const SizedBox(height: 20),
              _LiveClassCard(dashboard: dashboard),
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

  /// Unread notifications, not notices — the bell opens the notification
  /// centre now.
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
    return Row(
      children: [
        if (profileImage?.isNotEmpty ?? false) ...[
          Image.network(
            profileImage!,
            width: 46,
            height: 46,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF254C46), Color(0xFF173832)],
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                ),
                child: Text(
                  Fmt.initials(name),
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              );
            },
          ),
        ] else ...[
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF254C46), Color(0xFF173832)],
              ),
              borderRadius: BorderRadius.all(Radius.circular(15)),
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
        ],

        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assalamu Alaikum',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                name ?? 'Student',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                "Ready for today's lesson?",
                style: TextStyle(color: AppColors.muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Notification bell. The dot used to be permanently lit; it now
        // reflects real unread state and the bell jumps to the Notice tab.
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onBellTap,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_outlined,
                    size: 20,
                    color: AppColors.cream,
                  ),
                  if (unreadAlerts > 0)
                    Positioned(
                      top: 10,
                      right: 11,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 1.5,
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
    );
  }
}

// ─────────────────────────────────────────────── Meta Chips
class _MetaChips extends StatelessWidget {
  final String? studentId;
  final String? rollNo;
  final String? className;

  const _MetaChips({this.studentId, this.rollNo, this.className});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (studentId != null) _chip('ID', studentId!),
        if (rollNo != null) _chip('Roll', rollNo!),
        if (className != null && className != '—') _chip('Class', className!),
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
          // Decorative circle
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
              // Status label
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
                      isLive ? 'LIVE NOW' : 'UPCOMING',
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
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ─────────────────────────────────────────────── Quick Actions Grid
class _QuickActionsGrid extends StatelessWidget {
  /// Drives the badge on the Homework tile. Comes from the dashboard's
  /// `quick_stats.pending_assignments`, so it costs no extra request.
  final int pendingHomework;

  /// Badge on the Notice tile. The header bell now belongs to the
  /// notification centre, so unread notices surface here instead.
  final int unreadNotices;

  const _QuickActionsGrid({
    this.pendingHomework = 0,
    this.unreadNotices = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Every tile below now performs a real action. Five of the six used
    // to show a snackbar telling the student to tap a tab themselves —
    // switching tabs is possible from here since the selected index moved
    // into ShellProvider.
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
          icon: Icons.calendar_month_rounded,
          label: 'My Class',
          onTap: () => goToTab(ShellTab.classes),
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

  /// Shown as a small count bubble when greater than zero.
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
