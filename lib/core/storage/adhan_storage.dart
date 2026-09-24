import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/adhan_settings.dart';
import '../../data/models/prayer_times.dart';

/// Persists adhan settings and the last fetched timetable.
///
/// The timetable is cached so rescheduling on app start works offline;
/// it is tagged with [AdhanSettings.timetableKey] and ignored once the
/// location or calculation settings change.
class AdhanStorage {
  static const _kSettings = 'adhan_settings';
  static const _kTimetable = 'adhan_timetable';
  static const _kTimetableKey = 'adhan_timetable_key';

  Future<AdhanSettings> readSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSettings);
      if (raw == null) return const AdhanSettings();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const AdhanSettings();
      return AdhanSettings.fromJson(decoded);
    } catch (_) {
      return const AdhanSettings();
    }
  }

  Future<void> writeSettings(AdhanSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSettings, jsonEncode(settings.toJson()));
  }

  /// Cached days for [key], or an empty list when the cache belongs to
  /// different settings or is unreadable.
  Future<List<PrayerDay>> readTimetable(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_kTimetableKey) != key) return const [];
      final decoded = jsonDecode(prefs.getString(_kTimetable) ?? '[]');
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PrayerDay.fromJson)
          .whereType<PrayerDay>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> writeTimetable(String key, List<PrayerDay> days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kTimetable,
      jsonEncode(days.map((d) => d.toJson()).toList()),
    );
    await prefs.setString(_kTimetableKey, key);
  }
}
