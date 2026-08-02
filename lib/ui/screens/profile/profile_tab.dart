import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/fee_provider.dart';
import '../../../providers/quran_provider.dart';
import '../../../providers/recording_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/homework_provider.dart';
import '../../../providers/lesson_provider.dart';
import '../../../providers/notice_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/shell_provider.dart';
import '../../../providers/ticket_provider.dart';
import '../attendance/attendance_screen.dart';
import '../homework/homework_tab.dart';
import '../lessons/lessons_screen.dart';
import '../notifications/notifications_screen.dart';
import '../payment/pay_fees_screen.dart';
import '../recordings/recordings_screen.dart';
import '../routine/routine_screen.dart';
import '../support/support_tab.dart';
import 'edit_profile_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log out?'),
        content: const Text(
          'You will need your mobile number and an OTP to sign in again.',
          style: TextStyle(color: AppColors.muted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Clear feature state so the next student starts clean. Missing one
    // here leaks the previous student's data into the next session.
    context.read<ClassProvider>().reset();
    context.read<TicketProvider>().reset();
    context.read<DashboardProvider>().reset();
    context.read<NoticeProvider>().reset();
    context.read<HomeworkProvider>().reset();
    context.read<FeeProvider>().reset();
    context.read<AttendanceProvider>().reset();
    context.read<RecordingProvider>().reset();
    context.read<ChatProvider>().reset();
    context.read<QuranProvider>().reset();
    context.read<NotificationProvider>().reset();
    context.read<LessonProvider>().reset();
    context.read<ShellProvider>().reset();
    await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(26),
                    image: user?.profilePhotoUrl != null
                        ? DecorationImage(
                            image: NetworkImage(user!.profilePhotoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: user?.profilePhotoUrl != null
                      ? null
                      : Text(
                          Fmt.initials(user?.name),
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF231600),
                          ),
                        ),
                ),
                const SizedBox(height: 14),
                Text(
                  user?.name ?? 'Student',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (user?.studentId != null) 'ID ${user!.studentId}',
                    if (user?.rollNo != null) 'Roll ${user!.rollNo}',
                    user?.className ?? '',
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          _infoRow(Icons.badge_outlined, 'Student ID',
              user?.studentId ?? 'Not set'),
          _infoRow(Icons.tag_rounded, 'Roll No', user?.rollNo ?? 'Not set'),
          _infoRow(Icons.class_outlined, 'Class', user?.className ?? '—'),
          _infoRow(Icons.email_outlined, 'Email', user?.email ?? 'Not set'),
          _infoRow(Icons.phone_outlined, 'Phone', user?.phone ?? 'Not set'),
          if (user?.address != null)
            _infoRow(Icons.home_outlined, 'Address', user!.address!),
          if (user?.bloodGroup != null)
            _infoRow(Icons.bloodtype_outlined, 'Blood Group',
                user!.bloodGroup!),
          if (user?.session != null)
            _infoRow(Icons.event_note_outlined, 'Session', user!.session!),
          const SizedBox(height: 18),
          _actionRow(
            context,
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            subtitle: 'Update your details',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
          ),
          _actionRow(
            context,
            icon: Icons.refresh_rounded,
            title: 'Refresh Profile',
            subtitle: 'Pull the latest info from the server',
            onTap: () async {
              await context.read<AuthProvider>().reloadProfile();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile refreshed')),
                );
              }
            },
          ),
          _actionRow(
            context,
            icon: Icons.assignment_rounded,
            title: 'Homework',
            subtitle: 'View and submit your assignments',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HomeworkTab()),
            ),
          ),
          _actionRow(
            context,
            icon: Icons.fact_check_outlined,
            title: 'Attendance',
            subtitle: 'Your record subject by subject',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AttendanceScreen()),
            ),
          ),
          _actionRow(
            context,
            icon: Icons.calendar_month_rounded,
            title: 'Class Routine',
            subtitle: 'Your weekly timetable',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RoutineScreen()),
            ),
          ),
          _actionRow(
            context,
            icon: Icons.auto_stories_outlined,
            title: 'My Lessons',
            subtitle: 'Lesson plans and material',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LessonsScreen()),
            ),
          ),
          _actionRow(
            context,
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            subtitle: 'Everything the madrasah has sent you',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          _actionRow(
            context,
            icon: Icons.play_circle_outline_rounded,
            title: 'Recordings',
            subtitle: 'Watch recorded lessons',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RecordingsScreen()),
            ),
          ),
          _actionRow(
            context,
            icon: Icons.forum_outlined,
            title: 'Group Chat',
            subtitle: 'Talk to your class groups',
            onTap: () => context.read<ShellProvider>().goTo(ShellTab.chat),
          ),
          _actionRow(
            context,
            icon: Icons.credit_card_rounded,
            title: 'Fees',
            subtitle: 'Dues, payment and receipts',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PayFeesScreen()),
            ),
          ),
          _actionRow(
            context,
            icon: Icons.support_agent_rounded,
            title: 'Support',
            subtitle: 'Submit a support ticket',
            // SupportTab builds its own Scaffold; the extra wrapper here
            // used to nest two, which broke its FAB placement.
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SupportTab()),
            ),
          ),
          _actionRow(
            context,
            icon: Icons.logout_rounded,
            title: 'Log out',
            subtitle: null,
            danger: true,
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.goldLight),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    bool danger = false,
    required VoidCallback onTap,
  }) {
    final color = danger ? AppColors.danger : AppColors.goldLight;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: danger ? AppColors.danger : AppColors.cream,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 11)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}
