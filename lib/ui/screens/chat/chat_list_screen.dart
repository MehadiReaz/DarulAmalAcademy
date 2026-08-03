import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/chat.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../widgets/state_views.dart';
import 'chat_thread_screen.dart';

/// Group chats list with search filtering, unread badges, and rich card tiles.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadGroups();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _open(ChatGroup group) {
    final provider = context.read<ChatProvider>();
    provider.openGroup(group);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatThreadScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final totalUnread = provider.totalUnread;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Group Discussions'),
            if (totalUnread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalUnread',
                  style: const TextStyle(
                    color: Color(0xFF231600),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(ChatProvider provider) {
    if (provider.groupsState == LoadState.loading && provider.groups.isEmpty) {
      return const LoadingView(message: 'Loading group chats…');
    }

    if (provider.groupsState == LoadState.error && provider.groups.isEmpty) {
      return ErrorView(
        message: provider.groupsError ?? 'Could not load your groups',
        onRetry: () => provider.loadGroups(force: true),
      );
    }

    final filteredGroups = provider.groups.where((g) {
      if (_searchQuery.isEmpty) return true;
      final nameMatch = g.name.toLowerCase().contains(_searchQuery);
      final subjectMatch = (g.subject?.name ?? '').toLowerCase().contains(_searchQuery);
      final courseMatch = (g.course?.name ?? '').toLowerCase().contains(_searchQuery);
      final contextMatch = (g.contextLabel ?? '').toLowerCase().contains(_searchQuery);
      return nameMatch || subjectMatch || courseMatch || contextMatch;
    }).toList();

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () => provider.loadGroups(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // Search Field
          if (provider.groups.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 13.5, color: AppColors.cream),
                decoration: InputDecoration(
                  hintText: 'Search conversation list…',
                  hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.goldLight,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),

          if (provider.groups.isEmpty) ...[
            SizedBox(height: MediaQuery.of(context).size.height * 0.16),
            const EmptyView(
              icon: Icons.forum_outlined,
              title: 'No group chats yet',
              subtitle:
                  'You will be added to your subject groups by the madrasah.',
            ),
          ] else if (filteredGroups.isEmpty) ...[
            const SizedBox(height: 40),
            const EmptyView(
              icon: Icons.search_off_rounded,
              title: 'No matching groups',
              subtitle: 'Try searching with another keyword.',
            ),
          ] else ...[
            ...filteredGroups.map(
              (group) => _GroupTile(
                group: group,
                onTap: () => _open(group),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final ChatGroup group;
  final VoidCallback onTap;

  const _GroupTile({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasUnread = group.hasUnread;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasUnread
              ? AppColors.gold.withValues(alpha: 0.45)
              : AppColors.line,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Group Avatar / Icon
                Stack(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2B5B53), Color(0xFF193D37)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: group.image != null && group.image!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.network(
                                group.image!,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _avatarText(),
                              ),
                            )
                          : _avatarText(),
                    ),
                    if (hasUnread)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 13),

                // Content Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Group Name & Timestamp
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              group.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight:
                                    hasUnread ? FontWeight.w800 : FontWeight.w700,
                                fontSize: 13.5,
                                color: AppColors.cream,
                              ),
                            ),
                          ),
                          if (group.lastMessageTime != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              group.lastMessageTime!,
                              style: TextStyle(
                                color: hasUnread
                                    ? AppColors.goldLight
                                    : AppColors.muted,
                                fontSize: 10.5,
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Context Chip (Subject / Course)
                      if (group.contextLabel != null) ...[
                        Text(
                          group.contextLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.goldLight,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],

                      // Last Message & Unread Badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              group.lastMessage ?? 'No messages yet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: hasUnread
                                    ? AppColors.cream
                                    : AppColors.muted,
                                fontSize: 12,
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              constraints: const BoxConstraints(minWidth: 20),
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${group.unreadCount}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF231600),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarText() {
    final char = group.name.isEmpty ? 'G' : group.name[0].toUpperCase();
    return Text(
      char,
      style: const TextStyle(
        color: AppColors.goldLight,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
