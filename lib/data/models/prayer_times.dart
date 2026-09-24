import '../../core/utils/json_utils.dart';

/// The five daily prayers the adhan is played for, in order.
enum Prayer {
  fajr('Fajr'),
  dhuhr('Dhuhr'),
  asr('Asr'),
  maghrib('Maghrib'),
  isha('Isha');

  final String label;
  const Prayer(this.label);
}

/// One day of prayer times from the Aladhan calendar endpoints.
///
/// Requested with `iso8601=true`, so every timing carries its UTC offset
/// (`2026-09-24T04:32:00+06:00`) and parses to an exact instant, no matter
/// which timezone the device is in.
class PrayerDay {
  final DateTime date;
  final Map<Prayer, DateTime> times;
  final DateTime? sunrise;
  final String? hijri;

  const PrayerDay({
    required this.date,
    required this.times,
    this.sunrise,
    this.hijri,
  });

  /// Parses one element of `data[]` from `/v1/calendar` or
  /// `/v1/calendarByCity`. Returns null when any of the five prayers is
  /// missing, so a malformed day is skipped rather than half-scheduled.
  static PrayerDay? fromApi(Map<String, dynamic> json) {
    final timings = asMap(json['timings']) ?? const {};
    final times = <Prayer, DateTime>{};
    for (final p in Prayer.values) {
      final t = _parseTiming(timings[p.label]);
      if (t == null) return null;
      times[p] = t;
    }

    final date = asMap(json['date']);
    final gregorian = asMap(date?['gregorian']);
    final hijri = asMap(date?['hijri']);
    final hijriMonth = asMap(hijri?['month']);

    final day = times[Prayer.fajr]!.toLocal();
    return PrayerDay(
      date: _parseDmy(asStringOrNull(gregorian?['date'])) ??
          DateTime(day.year, day.month, day.day),
      times: times,
      sunrise: _parseTiming(timings['Sunrise']),
      hijri: hijri == null
          ? null
          : '${hijri['day']} ${hijriMonth?['en'] ?? ''} ${hijri['year']} AH'
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim(),
    );
  }

  /// `DD-MM-YYYY`, as Aladhan formats `date.gregorian.date`.
  static DateTime? _parseDmy(String? raw) {
    final parts = raw?.split('-');
    if (parts == null || parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  static DateTime? _parseTiming(dynamic raw) {
    final s = asStringOrNull(raw);
    if (s == null) return null;
    // Defensive: strip a trailing " (+06)" in case iso8601 was ignored.
    return DateTime.tryParse(s.split(' ').first);
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'times': {
          for (final e in times.entries)
            e.key.name: e.value.toUtc().toIso8601String(),
        },
        'sunrise': sunrise?.toUtc().toIso8601String(),
        'hijri': hijri,
      };

  static PrayerDay? fromJson(Map<String, dynamic> json) {
    final raw = asMap(json['times']) ?? const {};
    final times = <Prayer, DateTime>{};
    for (final p in Prayer.values) {
      final t = DateTime.tryParse(asStringOrNull(raw[p.name]) ?? '');
      if (t == null) return null;
      times[p] = t;
    }
    final date = DateTime.tryParse(asStringOrNull(json['date']) ?? '');
    if (date == null) return null;
    return PrayerDay(
      date: date,
      times: times,
      sunrise: DateTime.tryParse(asStringOrNull(json['sunrise']) ?? ''),
      hijri: asStringOrNull(json['hijri']),
    );
  }
}
