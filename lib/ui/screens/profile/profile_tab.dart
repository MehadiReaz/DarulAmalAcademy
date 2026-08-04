import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/student_user.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/fee_provider.dart';
import '../../../providers/homework_provider.dart';
import '../../../providers/lesson_provider.dart';
import '../../../providers/notice_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/quran_provider.dart';
import '../../../providers/recording_provider.dart';
import '../../../providers/shell_provider.dart';
import '../../../providers/ticket_provider.dart';
import '../attendance/attendance_screen.dart';
import '../courses/live_sessions_screen.dart';
import '../homework/homework_tab.dart';
import '../lessons/lessons_screen.dart';
import '../notifications/notifications_screen.dart';
import '../payment/pay_fees_screen.dart';
import '../recordings/recordings_screen.dart';
import '../routine/routine_screen.dart';
import '../support/support_tab.dart';
import '../../widgets/app_toast.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log out?'),
        content: const Text(
          'You will need your mobile number and an OTP to sign in again.',
          style: TextStyle(color: AppColors.muted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

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
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.gold),
            tooltip: 'Edit Profile',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 100),
        children: [
          // Header Hero Banner
          _ProfileHeroCard(user: user),
          const SizedBox(height: 20),

          // Quick Personal Details Grid
          const _SectionHeader(title: 'PERSONAL DETAILS'),
          const SizedBox(height: 10),
          _PersonalDetailsCard(user: user),
          const SizedBox(height: 24),

          // Academics Section
          const _SectionHeader(title: 'ACADEMIC & STUDIES'),
          const SizedBox(height: 10),
          _ActionCardGroup(
            children: [
              _ActionTile(
                icon: Icons.assignment_rounded,
                title: 'Homework',
                subtitle: 'View and submit assignments',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HomeworkTab()),
                ),
              ),
              _ActionTile(
                icon: Icons.fact_check_outlined,
                title: 'Attendance',
                subtitle: 'Subject-wise attendance log',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                ),
              ),
              _ActionTile(
                icon: Icons.calendar_month_rounded,
                title: 'Class Routine',
                subtitle: 'Weekly timetable & schedule',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RoutineScreen()),
                ),
              ),
              _ActionTile(
                icon: Icons.auto_stories_outlined,
                title: 'My Lessons',
                subtitle: 'Lesson plans and study materials',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LessonsScreen()),
                ),
              ),
              _ActionTile(
                icon: Icons.video_camera_front_outlined,
                title: 'Live Sessions',
                subtitle: 'Upcoming & active Zoom live classes',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LiveSessionsScreen()),
                ),
              ),
              _ActionTile(
                icon: Icons.play_circle_outline_rounded,
                title: 'Recordings',
                subtitle: 'Watch recorded live classes',
                isLast: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecordingsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Communication Section
          const _SectionHeader(title: 'COMMUNICATION'),
          const SizedBox(height: 10),
          _ActionCardGroup(
            children: [
              _ActionTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                subtitle: 'Madrasah announcements & alerts',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
              ),
              _ActionTile(
                icon: Icons.forum_outlined,
                title: 'Group Chat',
                subtitle: 'Connect with class peers & teachers',
                isLast: true,
                onTap: () => context.read<ShellProvider>().goTo(ShellTab.chat),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Finance & Support Section
          const _SectionHeader(title: 'FINANCE & SUPPORT'),
          const SizedBox(height: 10),
          _ActionCardGroup(
            children: [
              _ActionTile(
                icon: Icons.credit_card_rounded,
                title: 'Fees & Payments',
                subtitle: 'Fee dues, pay online & receipts',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PayFeesScreen()),
                ),
              ),
              _ActionTile(
                icon: Icons.support_agent_rounded,
                title: 'Help & Support',
                subtitle: 'Submit support tickets',
                isLast: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SupportTab()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Account Settings Section
          const _SectionHeader(title: 'ACCOUNT & SYSTEM'),
          const SizedBox(height: 10),
          _ActionCardGroup(
            children: [
              _ActionTile(
                icon: Icons.edit_outlined,
                title: 'Edit Profile',
                subtitle: 'Update your personal details',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                ),
              ),
              _ActionTile(
                icon: Icons.lock_outline_rounded,
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                ),
              ),
              _ActionTile(
                icon: Icons.refresh_rounded,
                title: 'Refresh Profile',
                subtitle: 'Sync latest info with server',
                onTap: () async {
                  await context.read<AuthProvider>().reloadProfile();
                  if (context.mounted) {
                    AppToast.showInfo(context, 'Profile refreshed');
                  }
                },
              ),
              _ActionTile(
                icon: Icons.logout_rounded,
                title: 'Log Out',
                subtitle: 'Sign out from this device',
                danger: true,
                isLast: true,
                onTap: () => _confirmLogout(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────── Hero Card
class _ProfileHeroCard extends StatelessWidget {
  final StudentUser? user;
  const _ProfileHeroCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final photoUrl = user?.profilePhotoUrl;
    final name = user?.name ?? 'Student';
    final studentId = user?.studentId;
    final rollNo = user?.rollNo;
    final className = user?.className;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceAlt,
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with glowing gradient border
          Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 42,
              backgroundColor: AppColors.bgDeep,
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                  ? NetworkImage(photoUrl)
                  : null,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? Text(
                      Fmt.initials(name),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          // Student Name
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.cream,
            ),
          ),
          const SizedBox(height: 6),
          // Student Badges / Meta Chips
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              if (studentId != null)
                _heroChip(Icons.badge_outlined, 'ID: $studentId'),
              if (rollNo != null)
                _heroChip(Icons.tag_rounded, 'Roll: $rollNo'),
              if (className != null && className != '—')
                _heroChip(Icons.school_outlined, className),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgDeep.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.goldLight),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.goldLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────── Personal Details Grid
class _PersonalDetailsCard extends StatelessWidget {
  final StudentUser? user;
  const _PersonalDetailsCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final email = user?.email;
    final phone = user?.phone;
    final address = user?.address;
    final bloodGroup = user?.bloodGroup;
    final session = user?.session;
    final dob = user?.dateOfBirth;

    final items = [
      if (phone != null && phone.isNotEmpty)
        _DetailGridItem(Icons.phone_outlined, 'Phone', phone),
      if (email != null && email.isNotEmpty)
        _DetailGridItem(Icons.email_outlined, 'Email', email),
      if (dob != null && dob.isNotEmpty)
        _DetailGridItem(Icons.cake_outlined, 'Date of Birth', dob),
      if (bloodGroup != null && bloodGroup.isNotEmpty)
        _DetailGridItem(Icons.bloodtype_outlined, 'Blood Group', bloodGroup),
      if (session != null && session.isNotEmpty)
        _DetailGridItem(Icons.event_note_outlined, 'Session', session),
      if (address != null && address.isNotEmpty)
        _DetailGridItem(Icons.home_outlined, 'Address', address, isFullWidth: true),
    ];

    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: const Text(
          'No additional details provided.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final halfWidth = (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((item) {
            final width = item.isFullWidth ? constraints.maxWidth : halfWidth;

            return Container(
              width: width,
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
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          item.icon,
                          size: 15,
                          color: AppColors.goldLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.value,
                    maxLines: item.isFullWidth ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.cream,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _DetailGridItem {
  final IconData icon;
  final String label;
  final String value;
  final bool isFullWidth;
  _DetailGridItem(this.icon, this.label, this.value, {this.isFullWidth = false});
}

// ─────────────────────────────────────────────── Section Header
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: AppColors.gold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────── Action Card Group
class _ActionCardGroup extends StatelessWidget {
  final List<Widget> children;
  const _ActionCardGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(children: children),
    );
  }
}

// ─────────────────────────────────────────────── Action Tile
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;
  final bool isLast;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = danger ? AppColors.danger : AppColors.goldLight;
    final iconBg = danger
        ? AppColors.danger.withValues(alpha: 0.12)
        : AppColors.gold.withValues(alpha: 0.12);

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 19, color: iconColor),
                  ),
                  const SizedBox(width: 14),
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
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: danger
                        ? AppColors.danger.withValues(alpha: 0.7)
                        : AppColors.muted.withValues(alpha: 0.7),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.line,
            indent: 64,
            endIndent: 16,
          ),
      ],
    );
  }
}

