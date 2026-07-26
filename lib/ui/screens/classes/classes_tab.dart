import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/class_routine.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/class_provider.dart';
import '../../widgets/class_card.dart';
import '../../widgets/state_views.dart';
import '../routine/routine_screen.dart';

class ClassesTab extends StatefulWidget {
  const ClassesTab({super.key});

  @override
  State<ClassesTab> createState() => _ClassesTabState();
}

class _ClassesTabState extends State<ClassesTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<ClassProvider>();
      p.loadToday();
      p.loadUpcoming();
      // The routine is loaded unconditionally: it is the fallback when
      // today/upcoming 403, and the Routine tab needs it anyway.
      p.loadRoutine();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClassProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Classes'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.muted,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Routine'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ClassList(
            state: provider.todayState,
            error: provider.todayError,
            items: provider.todayClasses,
            highlight: true,
            emptyTitle: 'No classes today',
            emptySubtitle: 'Check the Routine tab for your weekly timetable.',
            onRefresh: () => provider.loadToday(force: true),
            // `/student/classes/today` currently returns 403 for enrolled
            // students. Rather than show an error they can do nothing
            // about, point them at the routine, which does work.
            fallbackToRoutine: provider.liveEndpointsBlocked,
            onFallback: () => _tabController.animateTo(2),
          ),
          _ClassList(
            state: provider.upcomingState,
            error: provider.upcomingError,
            items: provider.upcomingClasses,
            emptyTitle: 'Nothing scheduled',
            emptySubtitle: 'Upcoming classes will appear here.',
            onRefresh: () => provider.loadUpcoming(force: true),
            fallbackToRoutine: provider.liveEndpointsBlocked,
            onFallback: () => _tabController.animateTo(2),
          ),
          const RoutineTabView(),
        ],
      ),
    );
  }
}

class _ClassList extends StatelessWidget {
  final LoadState state;
  final String? error;
  final List<ClassRoutine> items;
  final bool highlight;
  final String emptyTitle;
  final String emptySubtitle;
  final Future<void> Function() onRefresh;

  /// Set when the live-class endpoints are refusing the request, so the
  /// error state offers the Routine tab instead of a bare retry.
  final bool fallbackToRoutine;
  final VoidCallback? onFallback;

  const _ClassList({
    required this.state,
    required this.error,
    required this.items,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onRefresh,
    this.highlight = false,
    this.fallbackToRoutine = false,
    this.onFallback,
  });

  @override
  Widget build(BuildContext context) {
    if (state == LoadState.loading && items.isEmpty) {
      return const LoadingView();
    }

    if (state == LoadState.error && items.isEmpty) {
      if (fallbackToRoutine) {
        return _BlockedView(onOpenRoutine: onFallback, onRetry: onRefresh);
      }
      return ErrorView(
        message: error ?? 'Could not load classes',
        onRetry: onRefresh,
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: onRefresh,
      child: items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                EmptyView(
                  icon: Icons.event_busy_rounded,
                  title: emptyTitle,
                  subtitle: emptySubtitle,
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
              itemCount: items.length,
              itemBuilder: (_, i) => ClassCard(
                routine: items[i],
                highlight: highlight,
              ),
            ),
    );
  }
}

/// Shown when `/student/classes/today` and `/upcoming` both refuse the
/// request. That is a server-side authorisation fault — the student is
/// enrolled and `/student/my-classes` lists the class — so this explains
/// the situation and routes them to the timetable that does load, rather
/// than showing a raw error.
class _BlockedView extends StatelessWidget {
  final VoidCallback? onOpenRoutine;
  final Future<void> Function() onRetry;

  const _BlockedView({this.onOpenRoutine, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_clock_outlined,
                size: 40, color: AppColors.muted),
            const SizedBox(height: 16),
            const Text(
              'Live class list unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              "This is a problem on the madrasah's server, not your account. "
              'Your weekly routine still works.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            if (onOpenRoutine != null)
              FilledButton.icon(
                onPressed: onOpenRoutine,
                icon: const Icon(Icons.calendar_month_rounded, size: 17),
                label: const Text('Open routine'),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
