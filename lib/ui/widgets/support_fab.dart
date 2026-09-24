import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/support_contact.dart';
import '../../providers/base_provider.dart';
import '../../providers/support_provider.dart';
import 'app_toast.dart';

const _whatsAppGreen = Color(0xFF25D366);

/// Floating "Support" button. Opens WhatsApp with the madrasah's support
/// contact; when there are several, lets the student pick one first.
class SupportFab extends StatefulWidget {
  const SupportFab({super.key});

  @override
  State<SupportFab> createState() => _SupportFabState();
}

class _SupportFabState extends State<SupportFab> {
  bool _opening = false;

  Future<void> _onTap() async {
    if (_opening) return;
    setState(() => _opening = true);
    final provider = context.read<SupportProvider>();
    try {
      await provider.load();
      if (!mounted) return;

      final contacts = provider.contacts;
      if (contacts.isEmpty) {
        AppToast.showError(
          context,
          provider.state == LoadState.error
              ? (provider.error ?? 'Could not load support contacts.')
              : 'Support contacts are not available right now.',
        );
        // Let the next tap try again.
        if (provider.state == LoadState.error) provider.reset();
        return;
      }

      final contact = contacts.length == 1
          ? contacts.single
          : await _pick(contacts);
      if (contact != null && mounted) await _launch(contact);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<SupportContact?> _pick(List<SupportContact> contacts) {
    return showModalBottomSheet<SupportContact>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Need help?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.cream,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Chat with us on WhatsApp.',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              for (final c in contacts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: AppColors.bgDeep.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.pop(ctx, c),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: (c.isWhatsApp
                                        ? _whatsAppGreen
                                        : AppColors.gold)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                c.isWhatsApp
                                    ? Icons.chat_rounded
                                    : Icons.call_rounded,
                                color: c.isWhatsApp
                                    ? _whatsAppGreen
                                    : AppColors.gold,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.cream,
                                    ),
                                  ),
                                  if (c.phone != null)
                                    Text(
                                      '+${c.phone}',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.open_in_new_rounded,
                              color: AppColors.muted,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launch(SupportContact contact) async {
    final uri = contact.launchUri;
    var opened = false;
    if (uri != null) {
      try {
        // wa.me is an app link: it opens WhatsApp when installed and the
        // browser otherwise.
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
    }
    if (!opened && mounted) {
      AppToast.showError(context, 'Could not open WhatsApp.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'support_fab',
      tooltip: 'Support',
      onPressed: _onTap,
      backgroundColor: _whatsAppGreen,
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
      child: _opening
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.support_agent_rounded, size: 28),
    );
  }
}
