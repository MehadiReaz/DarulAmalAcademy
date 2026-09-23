import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/support_ticket.dart';
import '../../../data/repositories/ticket_repository.dart';
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
      context.read<TicketProvider>().loadContacts();
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

  Future<void> _openWhatsApp(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('https://wa.me/$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
        onRetry: () {
          provider.loadTickets(force: true);
          provider.loadContacts(force: true);
        },
      );
    }

    final contacts = provider.contacts;

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () => Future.wait([
        provider.loadTickets(force: true),
        provider.loadContacts(force: true),
      ]),
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
        children: [
          // WhatsApp Contacts Card
          if (contacts != null &&
              ((contacts.adminWhatsApp != null && contacts.adminWhatsApp!.isNotEmpty) ||
                  (contacts.helpCenterWhatsApp != null && contacts.helpCenterWhatsApp!.isNotEmpty)))
            _WhatsAppContactCard(
              contacts: contacts,
              onWhatsAppTap: _openWhatsApp,
            ),

          const SizedBox(height: 14),
          const Text(
            'My Tickets',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.cream,
            ),
          ),
          const SizedBox(height: 10),

          if (provider.tickets.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: const EmptyView(
                icon: Icons.support_agent_rounded,
                title: 'No tickets yet',
                subtitle:
                    'Having trouble? Submit a ticket or message our WhatsApp support.',
              ),
            )
          else ...[
            for (final ticket in provider.tickets)
              _TicketTile(ticket: ticket),
            if (provider.hasMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: LoadingView(),
              ),
          ],
        ],
      ),
    );
  }
}

class _WhatsAppContactCard extends StatelessWidget {
  final SupportContacts contacts;
  final ValueChanged<String> onWhatsAppTap;

  const _WhatsAppContactCard({
    required this.contacts,
    required this.onWhatsAppTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
            children: const [
              Icon(Icons.headset_mic_rounded, color: Color(0xFF2ECC71), size: 20),
              SizedBox(width: 8),
              Text(
                'Instant WhatsApp Support',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.cream,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Contact our academy help desk directly on WhatsApp for prompt resolution.',
            style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (contacts.adminWhatsApp != null && contacts.adminWhatsApp!.isNotEmpty)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => onWhatsAppTap(contacts.adminWhatsApp!),
                    icon: const Icon(Icons.chat_rounded, size: 16),
                    label: const Text('Admin', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ),
              if (contacts.adminWhatsApp != null &&
                  contacts.adminWhatsApp!.isNotEmpty &&
                  contacts.helpCenterWhatsApp != null &&
                  contacts.helpCenterWhatsApp!.isNotEmpty)
                const SizedBox(width: 10),
              if (contacts.helpCenterWhatsApp != null && contacts.helpCenterWhatsApp!.isNotEmpty)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF128C7E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => onWhatsAppTap(contacts.helpCenterWhatsApp!),
                    icon: const Icon(Icons.help_outline_rounded, size: 16),
                    label: const Text('Help Center', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  final SupportTicket ticket;
  const _TicketTile({required this.ticket});

  Color get _statusColor {
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
