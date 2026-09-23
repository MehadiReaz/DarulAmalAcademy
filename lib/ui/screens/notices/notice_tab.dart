import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/notice.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/notice_provider.dart';
import '../../widgets/state_views.dart';
import 'notice_detail_screen.dart';

class NoticeTab extends StatefulWidget {
  const NoticeTab({super.key});

  @override
  State<NoticeTab> createState() => _NoticeTabState();
}

class _NoticeTabState extends State<NoticeTab> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NoticeProvider>().loadNotices();
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<NoticeProvider>().loadMore();
      }
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Notice> _filterNotices(List<Notice> notices) {
    if (_searchQuery.isEmpty) return notices;
    return notices.where((n) {
      final title = n.title.toLowerCase();
      final body = n.displayBody.toLowerCase();
      final type = n.type.toLowerCase();
      return title.contains(_searchQuery) ||
          body.contains(_searchQuery) ||
          type.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NoticeProvider>();
    final filtered = _filterNotices(provider.notices);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        title: const Text('Notices'),
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        actions: [
          if (provider.notices.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.campaign_outlined,
                      size: 15, color: AppColors.goldLight),
                  const SizedBox(width: 5),
                  Text(
                    '${provider.notices.length} Notices',
                    style: const TextStyle(
                      color: AppColors.cream,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          if (provider.notices.isNotEmpty) _buildSearchBar(),

          // List or Grid
          Expanded(child: _buildBody(provider, filtered)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: AppColors.cream, fontSize: 13.5),
        decoration: InputDecoration(
          hintText: 'Search notices...',
          hintStyle: TextStyle(
            color: AppColors.muted.withValues(alpha: 0.8),
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.muted,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: AppColors.muted),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  Widget _buildBody(NoticeProvider provider, List<Notice> filtered) {
    if (provider.listState == LoadState.loading && provider.notices.isEmpty) {
      return const LoadingView();
    }

    if (provider.listState == LoadState.error && provider.notices.isEmpty) {
      return ErrorView(
        message: provider.listError ?? 'Could not load notices',
        onRetry: () => provider.loadNotices(force: true),
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () => provider.loadNotices(force: true),
      child: filtered.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                EmptyView(
                  icon: Icons.campaign_rounded,
                  title: _searchQuery.isEmpty
                      ? 'No notices yet'
                      : 'No notices found',
                  subtitle: _searchQuery.isEmpty
                      ? 'Announcements from your teachers will appear here.'
                      : 'Try different keywords to find what you are looking for.',
                ),
              ],
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 640;

                if (isTablet) {
                  return GridView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 390,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) =>
                        _NoticeCard(notice: filtered[i]),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: filtered.length + (provider.hasMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= filtered.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: LoadingView(),
                      );
                    }
                    return _NoticeCard(notice: filtered[i]);
                  },
                );
              },
            ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final Notice notice;
  const _NoticeCard({required this.notice});

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoticeDetailScreen(noticeId: notice.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage =
        notice.attachmentUrl != null && notice.attachmentUrl!.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notice.isPinned
              ? AppColors.gold.withValues(alpha: 0.7)
              : AppColors.line,
          width: notice.isPinned ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetail(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Top Image Banner
              _buildTopBanner(hasImage),

              // 2. Card Content
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date & Tags Row
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: Color(0xFF388BFD), // Light blue calendar icon
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            notice.formattedDate.isNotEmpty
                                ? '${notice.formattedDate} 06:00 ds'
                                : (notice.createdAt != null
                                    ? Fmt.date(notice.createdAt)
                                    : 'Notice'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF58A6FF),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        if (notice.isPinned) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.push_pin_rounded,
                                    size: 10, color: AppColors.gold),
                                SizedBox(width: 3),
                                Text(
                                  'PINNED',
                                  style: TextStyle(
                                    color: AppColors.gold,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (!notice.isRead) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D8CFF)
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Color(0xFF58A6FF),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Title
                    Text(
                      notice.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.cream,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Excerpt / Body
                    if (notice.displayBody.isNotEmpty)
                      Text(
                        notice.displayBody,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Divider
                    const Divider(
                      color: AppColors.line,
                      height: 1,
                      thickness: 0.8,
                    ),
                    const SizedBox(height: 10),

                    // Footer Row: "Read Full Notice »" and "Comments (x)"
                    Row(
                      children: [
                        // Left: Read Full Notice »
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Flexible(
                                child: Text(
                                  'Read Full Notice',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Color(0xFF388BFD),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              SizedBox(width: 3),
                              Text(
                                '»',
                                style: TextStyle(
                                  color: Color(0xFF388BFD),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Right: Comments counter
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 13,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Comments (${notice.displayCommentsCount})',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBanner(bool hasImage) {
    if (hasImage) {
      return SizedBox(
        height: 140,
        width: double.infinity,
        child: Image.network(
          notice.attachmentUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallbackBanner(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: const Color(0xFF142B27),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.gold,
                ),
              ),
            );
          },
        ),
      );
    }

    return _buildFallbackBanner();
  }

  Widget _buildFallbackBanner() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF24504A), Color(0xFF142B27)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.campaign_outlined,
          size: 44,
          color: AppColors.goldLight.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
