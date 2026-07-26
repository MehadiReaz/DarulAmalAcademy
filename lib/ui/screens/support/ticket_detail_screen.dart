import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/support_ticket.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/ticket_provider.dart';
import '../../widgets/state_views.dart';

class TicketDetailScreen extends StatefulWidget {
  final int ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TicketProvider>().loadDetail(widget.ticketId);
    });
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();
    final provider = context.read<TicketProvider>();
    final ok = await provider.sendReply(widget.ticketId, text);

    if (!mounted) return;
    if (ok) {
      _replyController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.submitError ?? 'Could not send your reply'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TicketProvider>();
    final ticket = provider.detail?.ticket;

    // A closed or resolved ticket is read-only.
    final canReply = ticket != null && !ticket.isResolved;

    return Scaffold(
      appBar: AppBar(title: const Text('Ticket')),
      body: Column(
        children: [
          Expanded(child: _buildBody(provider)),
          if (canReply) _composer(provider),
        ],
      ),
    );
  }

  /// Students can now reply — `/student/tickets/{id}/reply` is a
  /// student-facing route in the current API. It returned 500 in the
  /// 26 Jul test run, so failures surface as a snackbar rather than being
  /// silently swallowed.
  Widget _composer(TicketProvider provider) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _replyController,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Write a reply…',
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
                onPressed: provider.submitting ? null : _sendReply,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                child: provider.submitting
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

  Widget _buildBody(TicketProvider provider) {
    if (provider.detailState == LoadState.loading) {
      return const LoadingView();
    }

    if (provider.detailState == LoadState.error) {
      return ErrorView(
        message: provider.detailError ?? 'Could not load this ticket',
        onRetry: () => provider.loadDetail(widget.ticketId),
      );
    }

    final detail = provider.detail;
    if (detail == null) {
      return const EmptyView(title: 'Ticket not found');
    }

    final ticket = detail.ticket;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ticket.subject,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _pill(ticket.statusLabel,
                      ticket.isResolved ? AppColors.success : AppColors.gold),
                  if (ticket.priorityLabel != null) ...[
                    const SizedBox(width: 8),
                    _pill(
                      ticket.priorityLabel!,
                      ticket.isHighPriority
                          ? AppColors.danger
                          : AppColors.muted,
                    ),
                  ],
                  if (ticket.ticketNo != null) ...[
                    const SizedBox(width: 8),
                    _pill(ticket.ticketNo!, AppColors.muted),
                  ],
                  const Spacer(),
                  Text(
                    Fmt.ago(ticket.createdAt),
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 10.5),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                ticket.message,
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Replies (${detail.replies.length})',
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (detail.replies.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: const Column(
              children: [
                Icon(Icons.hourglass_empty_rounded,
                    color: AppColors.muted, size: 26),
                SizedBox(height: 10),
                Text(
                  'Waiting for a reply from the office',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          )
        else
          ...detail.replies.map(_replyCard),
      ],
    );
  }

  Widget _replyCard(TicketReply reply) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: reply.fromAdmin ? AppColors.surfaceAlt : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: reply.fromAdmin ? AppColors.gold : AppColors.line,
          width: reply.fromAdmin ? 1.2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                reply.user?.name ?? 'Support',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: reply.fromAdmin ? AppColors.gold : AppColors.cream,
                ),
              ),
              const Spacer(),
              Text(
                Fmt.ago(reply.createdAt),
                style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reply.message,
            style: const TextStyle(fontSize: 12.5, height: 1.55),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
