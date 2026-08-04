import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/live_session.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/class_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';

class LiveSessionsScreen extends StatefulWidget {
  const LiveSessionsScreen({super.key});

  @override
  State<LiveSessionsScreen> createState() => _LiveSessionsScreenState();
}

class _LiveSessionsScreenState extends State<LiveSessionsScreen> {
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClassProvider>().loadLiveSessions();
    });
  }

  Future<void> _launchZoomUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      AppToast.showError(context, 'Invalid meeting link format');
      return;
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Could not open meeting link: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClassProvider>();
    final bundle = provider.liveSessions;
    final state = provider.liveSessionsState;
    final error = provider.liveSessionsError;

    final categories = bundle?.sessionsByCategory.keys.toList() ?? [];
    if (_selectedCategory == null && categories.isNotEmpty) {
      _selectedCategory = categories.first;
    } else if (_selectedCategory != null &&
        categories.isNotEmpty &&
        !categories.contains(_selectedCategory)) {
      _selectedCategory = categories.first;
    }

    List<LiveSession> currentSessions = [];
    if (bundle != null) {
      if (_selectedCategory != null &&
          bundle.sessionsByCategory.containsKey(_selectedCategory)) {
        currentSessions = bundle.sessionsByCategory[_selectedCategory]!;
      } else {
        currentSessions = bundle.allSessions;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () =>
                context.read<ClassProvider>().loadLiveSessions(force: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            context.read<ClassProvider>().loadLiveSessions(force: true),
        color: AppColors.gold,
        backgroundColor: AppColors.surface,
        child: _buildBody(context, state, error, bundle, categories, currentSessions),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    LoadState state,
    String? error,
    LiveSessionBundle? bundle,
    List<String> categories,
    List<LiveSession> currentSessions,
  ) {
    if (state == LoadState.loading && (bundle == null || bundle.isEmpty)) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }

    if (state == LoadState.error && (bundle == null || bundle.isEmpty)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.danger,
              ),
              const SizedBox(height: 12),
              Text(
                error ?? 'Could not load live sessions.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Retry',
                onPressed: () => context
                    .read<ClassProvider>()
                    .loadLiveSessions(force: true),
              ),
            ],
          ),
        ),
      );
    }

    if (bundle == null || bundle.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: const [
          SizedBox(height: 60),
          Icon(
            Icons.video_camera_front_outlined,
            size: 64,
            color: AppColors.muted,
          ),
          SizedBox(height: 16),
          Text(
            'No Live Sessions Scheduled',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.cream,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Check back later for upcoming online classes and live streams.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // Category Selection Filter Chips
        if (categories.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSelected = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: AppColors.gold,
                    backgroundColor: AppColors.surface,
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF231600) : AppColors.cream,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected ? AppColors.gold : AppColors.line,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // List of Sessions
        if (currentSessions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text(
              'No classes in this section',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else
          ...currentSessions.map(
            (session) => _LiveSessionCard(
              session: session,
              onJoin: () {
                if (session.joinUrl != null && session.joinUrl!.isNotEmpty) {
                  _launchZoomUrl(session.joinUrl!);
                } else {
                  AppToast.showError(context, 'Meeting link unavailable');
                }
              },
            ),
          ),
      ],
    );
  }
}

class _LiveSessionCard extends StatelessWidget {
  final LiveSession session;
  final VoidCallback onJoin;

  const _LiveSessionCard({
    required this.session,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final isLive = session.isLive;
    final badgeColor = session.subject?.colorValue ?? AppColors.gold;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLive ? AppColors.gold.withValues(alpha: 0.6) : AppColors.line,
          width: isLive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status Pill & Subject Badge
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isLive
                      ? AppColors.danger.withValues(alpha: 0.2)
                      : AppColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isLive ? AppColors.danger : AppColors.gold,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLive) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      session.onlineClassStatus ??
                          (isLive ? 'LIVE NOW' : 'UPCOMING'),
                      style: TextStyle(
                        color: isLive ? AppColors.danger : AppColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (session.subjectName.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    session.subjectName,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Topic / Title
          Text(
            session.topic,
            style: const TextStyle(
              color: AppColors.cream,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              height: 1.3,
            ),
          ),

          if (session.description != null &&
              session.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              session.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),

          const Divider(color: AppColors.line, height: 1),
          const SizedBox(height: 12),

          // Info Rows: Teacher, Date, Password
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 15,
                color: AppColors.muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  session.teacherName,
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (session.displayDate.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 15,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    session.displayDate,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (session.password != null &&
              session.password!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.key_outlined,
                  size: 15,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  'Password: ${session.password}',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: session.password!),
                    );
                    AppToast.showInfo(context, 'Password copied to clipboard');
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Join Button
          AppButton(
            label: isLive ? 'Join Live Session' : 'Join Zoom Meeting',
            icon: Icons.video_call_rounded,
            onPressed: session.canJoin ? onJoin : null,
          ),
        ],
      ),
    );
  }
}
