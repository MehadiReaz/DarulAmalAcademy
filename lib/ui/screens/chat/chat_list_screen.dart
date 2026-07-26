import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/chat.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../widgets/state_views.dart';
import 'chat_thread_screen.dart';

/// Group chats, backed by `GET /group-chats`.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadGroups();
    });
  }

  Future<void> _open(ChatGroup group) async {
    final provider = context.read<ChatProvider>();
    await provider.openGroup(group);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatThreadScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Group Chat')),
      body: _body(provider),
    );
  }

  Widget _body(ChatProvider provider) {
    if (provider.groupsState == LoadState.loading && provider.groups.isEmpty) {
      return const LoadingView();
    }
    if (provider.groupsState == LoadState.error && provider.groups.isEmpty) {
      return ErrorView(
        message: provider.groupsError ?? 'Could not load your groups',
        onRetry: () => provider.loadGroups(force: true),
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () => provider.loadGroups(force: true),
      child: provider.groups.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.16),
                const EmptyView(
                  icon: Icons.forum_outlined,
                  title: 'No group chats yet',
                  subtitle:
                      'You will be added to your subject groups by the madrasah.',
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
              itemCount: provider.groups.length,
              itemBuilder: (context, i) {
                final group = provider.groups[i];
                return _GroupTile(group: group, onTap: () => _open(group));
              },
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
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF24504A), Color(0xFF173731)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                group.name.isEmpty ? '?' : group.name[0].toUpperCase(),
                style: const TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: group.hasUnread
                                ? FontWeight.w800
                                : FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (group.lastMessageTime != null)
                        Text(
                          group.lastMessageTime!,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.lastMessage ?? 'No messages yet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: group.hasUnread
                                ? AppColors.cream
                                : AppColors.muted,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      if (group.hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          constraints: const BoxConstraints(minWidth: 18),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            '${group.unreadCount}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF231600),
                              fontSize: 9,
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
    );
  }
}
