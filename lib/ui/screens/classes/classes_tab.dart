import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/class_routine.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/class_provider.dart';
import '../../widgets/class_card.dart';
import '../../widgets/state_views.dart';

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
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<ClassProvider>();
      p.loadToday();
      p.loadUpcoming();
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
            emptySubtitle: 'Check the Upcoming tab for your next class.',
            onRefresh: () => provider.loadToday(force: true),
          ),
          _ClassList(
            state: provider.upcomingState,
            error: provider.upcomingError,
            items: provider.upcomingClasses,
            emptyTitle: 'Nothing scheduled',
            emptySubtitle: 'Upcoming classes will appear here.',
            onRefresh: () => provider.loadUpcoming(force: true),
          ),
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

  const _ClassList({
    required this.state,
    required this.error,
    required this.items,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onRefresh,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    if (state == LoadState.loading && items.isEmpty) {
      return const LoadingView();
    }

    if (state == LoadState.error && items.isEmpty) {
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
