import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/support_ticket.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/ticket_provider.dart';
import '../../widgets/state_views.dart';
import 'create_ticket_screen.dart';
import 'ticket_detail_screen.dart';

class SupportTab extends StatefulWidget {
  const SupportTab({super.key});

  @override
  State<SupportTab> createState() => _SupportTabState();
}

class _SupportTabState extends State<SupportTab> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TicketProvider>().loadTickets();
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<TicketProvider>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TicketProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 78),
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.gold,
          foregroundColor: const Color(0xFF231600),
          onPressed: () async {
            final created = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const CreateTicketScreen()),
            );
            if (created == true && context.mounted) {
              context.read<TicketProvider>().loadTickets(force: true);
            }
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Ticket',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(TicketProvider provider) {
    if (provider.listState == LoadState.loading && provider.tickets.isEmpty) {
      return const LoadingView();
    }

    if (provider.listState == LoadState.error && provider.tickets.isEmpty) {
      return ErrorView(
        message: provider.listError ?? 'Could not load tickets',
        onRetry: () => provider.loadTickets(force: true),
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () => provider.loadTickets(force: true),
      child: provider.tickets.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                const EmptyView(
                  icon: Icons.support_agent_rounded,
                  title: 'No tickets yet',
                  subtitle:
                      'Having trouble? Submit a ticket and the office will get back to you.',
                ),
              ],
            )
          : ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
              itemCount: provider.tickets.length + (provider.hasMore ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= provider.tickets.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: LoadingView(),
                  );
                }
                return _TicketTile(ticket: provider.tickets[i]);
              },
            ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  final SupportTicket ticket;
  const _TicketTile({required this.ticket});

  Color get _statusColor {
    // `isResolved` now derives from the `status` column rather than the
    // `is_resolved` key, which does not exist on the tickets table and so
    // was always null — meaning nothing ever showed as resolved.
    if (ticket.isResolved) return AppColors.success;
    if (ticket.isAnswered) return AppColors.goldLight;
    return AppColors.muted;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TicketDetailScreen(ticketId: ticket.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ticket.statusLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              ticket.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded,
                    size: 12, color: AppColors.muted),
                const SizedBox(width: 5),
                Text(
                  '${ticket.repliesCount} replies',
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 10.5),
                ),
                const Spacer(),
                Text(
                  Fmt.ago(ticket.createdAt),
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 10.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
