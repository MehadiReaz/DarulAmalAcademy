import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/adhan_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/adhan_settings.dart';
import '../../../data/models/prayer_times.dart';
import '../../../providers/adhan_provider.dart';
import '../../../providers/base_provider.dart';
import '../../widgets/app_toast.dart';
import '../../../core/utils/responsive.dart';

/// Today's prayer times plus every adhan setting.
class AdhanSettingsScreen extends StatefulWidget {
  const AdhanSettingsScreen({super.key});

  @override
  State<AdhanSettingsScreen> createState() => _AdhanSettingsScreenState();
}

class _AdhanSettingsScreenState extends State<AdhanSettingsScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Keeps the "next prayer in …" countdown current.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _report(String? error) {
    if (error != null && mounted) AppToast.showError(context, error);
  }

  Future<void> _toggleEnabled(bool on) async {
    final provider = context.read<AdhanProvider>();
    final error = await provider.setEnabled(on);
    if (!mounted) return;
    if (error != null) {
      _report(error);
      if (on && !provider.settings.hasLocation) await _editCity();
    } else if (on) {
      AppToast.showSuccess(context, 'Adhan is on');
    }
  }

  Future<void> _editCity() async {
    final provider = context.read<AdhanProvider>();
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CitySheet(
        city: provider.settings.city,
        country: provider.settings.country,
      ),
    );
    if (result == null || !mounted) return;
    final error = await provider.useCity(result.$1, result.$2);
    _report(error);
  }

  Future<void> _pickMethod() async {
    final provider = context.read<AdhanProvider>();
    final picked = await _pickFromList<int>(
      title: 'Calculation method',
      options: kCalculationMethods.entries
          .map((e) => (e.key, e.value))
          .toList(),
      selected: provider.settings.method,
    );
    if (picked != null) {
      await provider.update(provider.settings.copyWith(method: picked));
      _report(provider.error);
    }
  }

  Future<void> _pickSound({required bool fajr}) async {
    final provider = context.read<AdhanProvider>();
    final s = provider.settings;
    final picked = await _pickFromList<AdhanSound>(
      title: fajr ? 'Fajr adhan sound' : 'Adhan sound',
      options: AdhanSound.values.map((v) => (v, v.label)).toList(),
      selected: fajr ? s.fajrSound : s.sound,
      onPreview: AdhanService.playTest,
    );
    await AdhanService.stopTest();
    if (picked != null) {
      await provider.update(
        fajr ? s.copyWith(fajrSound: picked) : s.copyWith(sound: picked),
      );
    }
  }

  Future<T?> _pickFromList<T>({
    required String title,
    required List<(T, String)> options,
    required T selected,
    void Function(T)? onPreview,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.75,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.cream,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final (value, label) in options)
                      ListTile(
                        onTap: () => Navigator.pop(ctx, value),
                        leading: Icon(
                          value == selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: value == selected
                              ? AppColors.gold
                              : AppColors.muted,
                        ),
                        title: Text(
                          label,
                          style: const TextStyle(
                            color: AppColors.cream,
                            fontSize: 14,
                          ),
                        ),
                        trailing: onPreview == null
                            ? null
                            : IconButton(
                                tooltip: 'Preview',
                                icon: const Icon(
                                  Icons.play_circle_outline_rounded,
                                  color: AppColors.goldLight,
                                ),
                                onPressed: () => onPreview(value),
                              ),
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdhanProvider>();
    final s = provider.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Times & Adhan'),
        actions: [
          if (s.hasLocation)
            IconButton(
              tooltip: 'Refresh times',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: provider.busy
                  ? null
                  : () async {
                      await provider.refresh(force: true);
                      _report(provider.error);
                    },
            ),
        ],
      ),
      body: ResponsiveBody(child: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () => provider.refresh(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (provider.busy)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.gold,
                  backgroundColor: AppColors.line,
                ),
              ),
            _TodayCard(provider: provider, onSetLocation: _editCity),
            const SizedBox(height: 16),
            _Card(
              children: [
                SwitchListTile(
                  value: s.enabled,
                  onChanged: provider.busy ? null : _toggleEnabled,
                  activeThumbColor: AppColors.gold,
                  secondary: const _TileIcon(Icons.volume_up_rounded),
                  title: const _TileTitle('Play Adhan'),
                  subtitle: const _TileSubtitle(
                    'At each prayer time, even when the app is closed',
                  ),
                ),
              ],
            ),
            ..._warnings(provider),
            const SizedBox(height: 20),
            const _SectionHeader('PRAYERS'),
            _Card(
              children: [
                for (final p in Prayer.values)
                  SwitchListTile(
                    dense: true,
                    value: s.isOn(p),
                    onChanged: !s.enabled
                        ? null
                        : (on) => provider.update(
                              s.copyWith(prayers: {...s.prayers, p: on}),
                            ),
                    activeThumbColor: AppColors.gold,
                    title: _TileTitle(p.label),
                    subtitle: _TileSubtitle(
                      Fmt.clock(provider.today?.times[p]),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const _SectionHeader('SOUND'),
            _Card(
              children: [
                _NavTile(
                  icon: Icons.music_note_rounded,
                  title: 'Adhan sound',
                  value: s.sound.label,
                  onTap: () => _pickSound(fajr: false),
                ),
                _NavTile(
                  icon: Icons.wb_twilight_rounded,
                  title: 'Fajr adhan sound',
                  value: s.fajrSound.label,
                  onTap: () => _pickSound(fajr: true),
                ),
                _NavTile(
                  icon: Icons.play_circle_outline_rounded,
                  title: 'Test adhan',
                  value: 'Plays the adhan now. Dismiss the notification '
                      'to stop it.',
                  onTap: () => AdhanService.playTest(s.sound),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SectionHeader('REMINDER BEFORE PRAYER'),
            _Card(
              padding: const EdgeInsets.all(14),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in kReminderOptions)
                      ChoiceChip(
                        label: Text(m == 0 ? 'Off' : '$m min'),
                        selected: s.reminderMinutes == m,
                        onSelected: (_) =>
                            provider.update(s.copyWith(reminderMinutes: m)),
                        selectedColor: AppColors.gold,
                        backgroundColor: AppColors.bgDeep,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: s.reminderMinutes == m
                              ? AppColors.bgDeep
                              : AppColors.cream,
                        ),
                        side: const BorderSide(color: AppColors.line),
                        showCheckmark: false,
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SectionHeader('CALCULATION'),
            _Card(
              children: [
                _NavTile(
                  icon: Icons.calculate_outlined,
                  title: 'Method',
                  value: kCalculationMethods[s.method] ?? 'Method ${s.method}',
                  onTap: _pickMethod,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _TileTitle('Asr time'),
                      const SizedBox(height: 8),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 0, label: Text('Standard')),
                          ButtonSegment(value: 1, label: Text('Hanafi')),
                        ],
                        selected: {s.school},
                        onSelectionChanged: (v) =>
                            provider.update(s.copyWith(school: v.first)),
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: AppColors.gold,
                          selectedForegroundColor: AppColors.bgDeep,
                          foregroundColor: AppColors.cream,
                          side: const BorderSide(color: AppColors.line),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SectionHeader('LOCATION'),
            _Card(
              children: [
                _NavTile(
                  icon: Icons.my_location_rounded,
                  title: 'Use my current location',
                  value: s.locationMode == AdhanLocationMode.device &&
                          s.hasLocation
                      ? (s.locationLabel ?? 'In use')
                      : 'Detect automatically',
                  selected: s.locationMode == AdhanLocationMode.device &&
                      s.hasLocation,
                  onTap: () async {
                    _report(await provider.useDeviceLocation());
                  },
                ),
                _NavTile(
                  icon: Icons.location_city_rounded,
                  title: 'Set city manually',
                  value: s.city?.isNotEmpty ?? false
                      ? '${s.city}, ${s.country}'
                      : 'Enter city and country',
                  selected: s.locationMode == AdhanLocationMode.city &&
                      s.hasLocation,
                  onTap: _editCity,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Prayer times from the Aladhan API (aladhan.com).',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
      )),
    );
  }

  List<Widget> _warnings(AdhanProvider provider) {
    if (!provider.settings.enabled) return const [];
    final items = <Widget>[];

    if (!provider.exactAllowed) {
      items.add(_Notice(
        text: 'Exact alarms are off, so the adhan may be a few minutes '
            'late when your phone is idle.',
        action: 'Allow',
        onAction: () async {
          await AdhanService.requestExactAlarms();
          await provider.refresh();
        },
      ));
    }

    if (provider.state == LoadState.error && provider.error != null) {
      items.add(_Notice(
        text: provider.error!,
        action: 'Retry',
        onAction: () => provider.refresh(force: true),
      ));
    }

    final until = provider.scheduledUntil;
    if (until != null) {
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
        child: Text(
          Platform.isIOS
              ? 'Scheduled until ${Fmt.date(until.toLocal())}. iOS allows only '
                  'a few days at a time, so open the app at least once a week.'
              : 'Scheduled until ${Fmt.date(until.toLocal())}. Opening the app '
                  'extends this automatically.',
          style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
        ),
      ));
    }
    return items;
  }
}

// ─────────────────────────────────────────────── Today card
class _TodayCard extends StatelessWidget {
  final AdhanProvider provider;
  final VoidCallback onSetLocation;

  const _TodayCard({required this.provider, required this.onSetLocation});

  @override
  Widget build(BuildContext context) {
    final s = provider.settings;
    final today = provider.today;
    final next = provider.nextPrayer;
    final current = provider.currentPrayer;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceAlt, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: !s.hasLocation
          ? Column(
              children: [
                const Icon(Icons.mosque_outlined,
                    color: AppColors.gold, size: 36),
                const SizedBox(height: 10),
                const Text(
                  'Set your location to see prayer times',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.cream,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: provider.busy
                      ? null
                      : () async {
                          final err = await provider.useDeviceLocation();
                          if (err != null) onSetLocation();
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.gold),
                  ),
                  child: const Text('Use my location'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 14, color: AppColors.goldLight),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        s.locationLabel ?? 'Your location',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.goldLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (today?.hijri != null)
                      Text(
                        today!.hijri!,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (next != null) ...[
                  Text(
                    'Next: ${next.$1.label}',
                    style: const TextStyle(
                      color: AppColors.cream,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${Fmt.clock(next.$2)} · in ${_countdown(next.$2)}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 14),
                ],
                if (today == null)
                  Text(
                    provider.state == LoadState.loading
                        ? 'Loading prayer times…'
                        : "Today's times are not available yet.",
                    style: const TextStyle(color: AppColors.muted),
                  )
                else
                  Row(
                    children: [
                      for (final p in Prayer.values)
                        Expanded(
                          child: _TimeCell(
                            prayer: p,
                            time: today.times[p]!,
                            highlighted: current == p,
                            muted: !s.enabled || !s.isOn(p),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
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

class _TimeCell extends StatelessWidget {
  final Prayer prayer;
  final DateTime time;
  final bool highlighted;
  final bool muted;

  const _TimeCell({
    required this.prayer,
    required this.time,
    required this.highlighted,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final clock = Fmt.clock(time).split(' ');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.gold.withValues(alpha: 0.16)
            : AppColors.bgDeep.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted ? AppColors.gold : AppColors.line,
        ),
      ),
      child: Column(
        children: [
          Icon(
            muted
                ? Icons.notifications_off_outlined
                : Icons.notifications_active_outlined,
            size: 14,
            color: muted ? AppColors.muted : AppColors.goldLight,
          ),
          const SizedBox(height: 4),
          Text(
            prayer.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: highlighted ? AppColors.goldLight : AppColors.cream,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            clock.first,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.cream,
            ),
          ),
          if (clock.length > 1)
            Text(
              clock.last,
              style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────── City sheet
class _CitySheet extends StatefulWidget {
  final String? city;
  final String? country;

  const _CitySheet({this.city, this.country});

  @override
  State<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<_CitySheet> {
  late final _city = TextEditingController(text: widget.city ?? '');
  late final _country = TextEditingController(text: widget.country ?? '');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _city.dispose();
    _country.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Set your city',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.cream,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _city,
              validator: _required,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'City',
                hintText: 'e.g. Dhaka',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _country,
              validator: _required,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Country',
                hintText: 'e.g. Bangladesh',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                Navigator.pop(context, (_city.text, _country.text));
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.bgDeep,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────── Small pieces
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: AppColors.gold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const _Card({
    required this.children,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final bool selected;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: _TileIcon(icon),
      title: _TileTitle(title),
      subtitle: _TileSubtitle(value),
      trailing: Icon(
        selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
        color: selected ? AppColors.gold : AppColors.muted,
        size: 20,
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  final IconData icon;
  const _TileIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 19, color: AppColors.goldLight),
    );
  }
}

class _TileTitle extends StatelessWidget {
  final String text;
  const _TileTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: AppColors.cream,
      ),
    );
  }
}

class _TileSubtitle extends StatelessWidget {
  final String text;
  const _TileSubtitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  final String action;
  final VoidCallback onAction;

  const _Notice({
    required this.text,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.cream, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: onAction,
            child: Text(
              action,
              style: const TextStyle(color: AppColors.goldLight),
            ),
          ),
        ],
      ),
    );
  }
}
