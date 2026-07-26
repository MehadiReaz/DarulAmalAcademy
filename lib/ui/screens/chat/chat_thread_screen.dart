import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/chat.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../widgets/state_views.dart';

/// A single group thread: `GET/POST /group-chats/{id}/messages` plus
/// `GET /group-chats/{id}/search`.
///
/// There is no realtime channel on the backend, so new messages arrive on
/// pull-to-refresh rather than pushed.
class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({super.key});

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _input = TextEditingController();
  final _searchInput = TextEditingController();
  final _scroll = ScrollController();
  bool _searchMode = false;

  @override
  void dispose() {
    _input.dispose();
    _searchInput.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;

    final provider = context.read<ChatProvider>();
    final me = context.read<AuthProvider>().user;

    _input.clear();
    _scrollToBottom();

    final ok = await provider.send(
      text: text,
      myUserId: me?.id,
      myName: me?.name,
    );

    if (!mounted) return;
    if (!ok && provider.sendError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.sendError!),
          backgroundColor: AppColors.danger,
        ),
      );
    } else {
      _scrollToBottom();
    }
  }

  void _toggleSearch() {
    setState(() => _searchMode = !_searchMode);
    if (!_searchMode) {
      _searchInput.clear();
      context.read<ChatProvider>().clearSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final group = provider.activeGroup;
    final myId = context.select<AuthProvider, int?>((p) => p.user?.id);

    return Scaffold(
      appBar: AppBar(
        title: _searchMode
            ? TextField(
                controller: _searchInput,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: provider.search,
                decoration: const InputDecoration(
                  hintText: 'Search this group…',
                  border: InputBorder.none,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group?.name ?? 'Group'),
                  if (group?.contextLabel != null)
                    Text(
                      group!.contextLabel!,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_searchMode ? Icons.close_rounded : Icons.search_rounded),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _searchMode
                ? _searchResults(provider)
                : _messageList(provider, myId),
          ),
          if (!_searchMode) _composer(provider),
        ],
      ),
    );
  }

  Widget _messageList(ChatProvider provider, int? myId) {
    if (provider.messagesState == LoadState.loading &&
        provider.messages.isEmpty) {
      return const LoadingView();
    }
    if (provider.messagesState == LoadState.error &&
        provider.messages.isEmpty) {
      return ErrorView(
        message: provider.messagesError ?? 'Could not load messages',
        onRetry: () {
          final id = provider.activeGroup?.id;
          if (id != null) provider.loadMessages(id);
        },
      );
    }
    if (provider.messages.isEmpty) {
      return const EmptyView(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No messages yet',
        subtitle: 'Be the first to say salaam.',
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () async {
        final id = provider.activeGroup?.id;
        if (id != null) await provider.loadMessages(id);
      },
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        itemCount: provider.messages.length + (provider.hasOlder ? 1 : 0),
        itemBuilder: (context, i) {
          if (provider.hasOlder && i == 0) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextButton(
                  onPressed: provider.loadingOlder ? null : provider.loadOlder,
                  child: Text(
                    provider.loadingOlder ? 'Loading…' : 'Load earlier messages',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                ),
              ),
            );
          }
          final msg = provider.messages[provider.hasOlder ? i - 1 : i];
          return _Bubble(
            message: msg,
            mine: msg.isMine(myId),
            onDiscard: msg.failed
                ? () => provider.discardFailed(msg.id)
                : null,
          );
        },
      ),
    );
  }

  Widget _searchResults(ChatProvider provider) {
    if (provider.searching) return const LoadingView();
    if (provider.searchQuery.isEmpty) {
      return const EmptyView(
        icon: Icons.search_rounded,
        title: 'Search this group',
        subtitle: 'Type a word and press enter.',
      );
    }
    if (provider.searchHits.isEmpty) {
      return const EmptyView(
        icon: Icons.search_off_rounded,
        title: 'No matches',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      itemCount: provider.searchHits.length,
      itemBuilder: (context, i) {
        final hit = provider.searchHits[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    hit.senderName ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.goldLight,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    Fmt.ago(hit.createdAt),
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                hit.text ?? '',
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _composer(ChatProvider provider) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Message…',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 9),
            SizedBox(
              width: 44,
              height: 44,
              child: FilledButton(
                onPressed: provider.sending ? null : _send,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                child: provider.sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF231600),
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final VoidCallback? onDiscard;

  const _Bubble({
    required this.message,
    required this.mine,
    this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: const Text(
            'This message was deleted',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!mine && message.sender?.name != null)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 3),
              child: Text(
                message.sender!.name!,
                style: const TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.74,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: mine ? AppColors.gold : AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(15),
                topRight: const Radius.circular(15),
                bottomLeft: Radius.circular(mine ? 15 : 4),
                bottomRight: Radius.circular(mine ? 4 : 15),
              ),
              border: mine ? null : Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.hasAttachment)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.attach_file_rounded,
                            size: 13,
                            color: mine
                                ? const Color(0xFF231600)
                                : AppColors.muted),
                        const SizedBox(width: 5),
                        Text(
                          'Attachment',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: mine
                                ? const Color(0xFF231600)
                                : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (message.text != null && message.text!.isNotEmpty)
                  Text(
                    message.text!,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: mine ? const Color(0xFF231600) : AppColors.cream,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 6, right: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.pending)
                  const Text('Sending…',
                      style:
                          TextStyle(color: AppColors.muted, fontSize: 9.5))
                else if (message.failed) ...[
                  const Text('Not sent',
                      style:
                          TextStyle(color: AppColors.danger, fontSize: 9.5)),
                  if (onDiscard != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onDiscard,
                      child: const Text(
                        'Dismiss',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 9.5,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ] else
                  Text(
                    Fmt.ago(message.createdAt),
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 9.5),
                  ),
                if (message.isEdited) ...[
                  const SizedBox(width: 5),
                  const Text('· edited',
                      style:
                          TextStyle(color: AppColors.muted, fontSize: 9.5)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
