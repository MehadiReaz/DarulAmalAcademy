import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/prayer_times.dart';
import '../../../../providers/adhan_provider.dart';
import '../../../../providers/base_provider.dart';
import '../../adhan/adhan_settings_screen.dart';

/// Home banner: next prayer with a countdown and today's five times.
/// Tapping it opens the Prayer Times & Adhan screen.
class PrayerTimesBanner extends StatefulWidget {
  const PrayerTimesBanner({super.key});

  @override
  State<PrayerTimesBanner> createState() => _PrayerTimesBannerState();
}

class _PrayerTimesBannerState extends State<PrayerTimesBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Keeps the countdown and the highlighted prayer current.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _open() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdhanSettingsScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdhanProvider>();
    final settings = provider.settings;
    final today = provider.today;
    final next = provider.nextPrayer;
    final current = provider.currentPrayer;
    final ready = settings.hasLocation && today != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.surfaceAlt, AppColors.bgTeal],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          ),
          child: ready
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Headline(
                      next: next,
                      location: settings.locationLabel,
                      hijri: today.hijri,
                      adhanOn: settings.enabled,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        for (final p in Prayer.values)
                          Expanded(
                            child: _TimeChip(
                              label: p.label,
                              time: today.times[p]!,
                              highlighted: current == p,
                            ),
                          ),
                      ],
                    ),
                  ],
                )
              : _SetupPrompt(
                  hasLocation: settings.hasLocation,
                  loading: provider.busy ||
                      provider.state == LoadState.loading ||
                      provider.state == LoadState.idle,
                ),
        ),
      ),
    );
  }

}

class _Headline extends StatelessWidget {
  final (Prayer, DateTime)? next;
  final String? location;
  final String? hijri;
  final bool adhanOn;

  const _Headline({
    required this.next,
    required this.location,
    required this.hijri,
    required this.adhanOn,
  });

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (location != null && location!.isNotEmpty) location!,
      ?hijri,
    ].join(' · ');

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.mosque_rounded,
              color: AppColors.bgDeep, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                next == null
                    ? 'Prayer Times'
                    : 'Next: ${next!.$1.label} · ${Fmt.clock(next!.$2)}',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.cream,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                next == null ? meta : 'in ${_countdown(next!.$2)}'
                    '${meta.isEmpty ? '' : ' · $meta'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: adhanOn ? 'Adhan on' : 'Adhan off',
          child: Icon(
            adhanOn
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_outlined,
            size: 20,
            color: adhanOn ? AppColors.gold : AppColors.muted,
          ),
        ),
      ],
    );
  }

  static String _countdown(DateTime at) {
    final diff = at.difference(DateTime.now());
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${diff.inMinutes < 1 ? 1 : diff.inMinutes}m';
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final DateTime time;
  final bool highlighted;

  const _TimeChip({
    required this.label,
    required this.time,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final parts = Fmt.clock(time).split(' ');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2.5),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.gold.withValues(alpha: 0.16)
            : AppColors.bgDeep.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted ? AppColors.gold : AppColors.line,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: highlighted ? AppColors.goldLight : AppColors.muted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            parts.first,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.cream,
            ),
          ),
          if (parts.length > 1)
            Text(
              parts.last,
              style: const TextStyle(fontSize: 9, color: AppColors.muted),
            ),
        ],
      ),
    );
  }
}

class _SetupPrompt extends StatelessWidget {
  final bool hasLocation;
  final bool loading;
  const _SetupPrompt({required this.hasLocation, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.mosque_rounded,
              color: AppColors.bgDeep, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                !hasLocation
                    ? 'Prayer Times & Adhan'
                    : loading
                        ? 'Loading prayer times…'
                        : 'Prayer times unavailable',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.cream,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                !hasLocation
                    ? 'Set your location to see prayer times and hear the adhan'
                    : loading
                        ? "Fetching today's times for your location"
                        : 'Tap to retry or change your location',
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.gold),
      ],
    );
  }
}
