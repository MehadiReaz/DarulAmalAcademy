import 'package:darul_amal/data/models/adhan_settings.dart';
import 'package:darul_amal/data/models/prayer_times.dart';
import 'package:flutter_test/flutter_test.dart';

/// One day from `GET /v1/calendar/2026/9?...&iso8601=true` (Dhaka).
Map<String, dynamic> _aladhanDay() => {
      'timings': {
        'Fajr': '2026-09-24T04:32:00+06:00',
        'Sunrise': '2026-09-24T05:48:00+06:00',
        'Dhuhr': '2026-09-24T11:50:00+06:00',
        'Asr': '2026-09-24T16:12:00+06:00',
        'Sunset': '2026-09-24T17:53:00+06:00',
        'Maghrib': '2026-09-24T17:53:00+06:00',
        'Isha': '2026-09-24T19:08:00+06:00',
        'Imsak': '2026-09-24T04:22:00+06:00',
      },
      'date': {
        'gregorian': {'date': '24-09-2026'},
        'hijri': {
          'day': '13',
          'month': {'en': 'Rabīʿ al-thānī'},
          'year': '1448',
        },
      },
      'meta': {'timezone': 'Asia/Dhaka'},
    };

void main() {
  group('PrayerDay', () {
    test('parses iso8601 timings as exact instants', () {
      final day = PrayerDay.fromApi(_aladhanDay())!;

      expect(day.date, DateTime(2026, 9, 24));
      expect(day.times[Prayer.fajr], DateTime.utc(2026, 9, 23, 22, 32));
      expect(day.times[Prayer.isha], DateTime.utc(2026, 9, 24, 13, 8));
      expect(day.sunrise, DateTime.utc(2026, 9, 23, 23, 48));
      expect(day.hijri, '13 Rabīʿ al-thānī 1448 AH');
    });

    test('skips a day missing any of the five prayers', () {
      final json = _aladhanDay();
      (json['timings'] as Map).remove('Asr');
      expect(PrayerDay.fromApi(json), isNull);
    });

    test('survives the cache round trip', () {
      final day = PrayerDay.fromApi(_aladhanDay())!;
      final back = PrayerDay.fromJson(day.toJson())!;

      expect(back.date, day.date);
      for (final p in Prayer.values) {
        expect(back.times[p], day.times[p]);
      }
      expect(back.hijri, day.hijri);
    });
  });

  group('AdhanSettings', () {
    test('defaults are off with every prayer selected', () {
      const s = AdhanSettings();
      expect(s.enabled, isFalse);
      expect(Prayer.values.every(s.isOn), isTrue);
      expect(s.hasLocation, isFalse);
    });

    test('round-trips through json', () {
      const s = AdhanSettings(
        enabled: true,
        prayers: {Prayer.fajr: false, Prayer.isha: true},
        sound: AdhanSound.fakhri,
        fajrSound: AdhanSound.short,
        method: 3,
        school: 0,
        reminderMinutes: 10,
        locationMode: AdhanLocationMode.city,
        city: 'Dhaka',
        country: 'Bangladesh',
      );
      final back = AdhanSettings.fromJson(s.toJson());

      expect(back.enabled, isTrue);
      expect(back.isOn(Prayer.fajr), isFalse);
      expect(back.isOn(Prayer.dhuhr), isTrue);
      expect(back.sound, AdhanSound.fakhri);
      expect(back.soundFor(Prayer.fajr), AdhanSound.short);
      expect(back.soundFor(Prayer.asr), AdhanSound.fakhri);
      expect(back.method, 3);
      expect(back.school, 0);
      expect(back.reminderMinutes, 10);
      expect(back.hasLocation, isTrue);
      expect(back.timetableKey, s.timetableKey);
    });

    test('falls back to defaults on unknown values', () {
      final s = AdhanSettings.fromJson({
        'sound': 'nope',
        'method': 99,
        'reminder_minutes': 7,
      });
      expect(s.sound, AdhanSound.classic);
      expect(s.method, 1);
      expect(s.reminderMinutes, 0);
    });

    test('timetable key ignores sound but tracks location', () {
      const base = AdhanSettings(latitude: 23.81, longitude: 90.41);
      expect(
        base.copyWith(sound: AdhanSound.short).timetableKey,
        base.timetableKey,
      );
      expect(
        base.copyWith(latitude: 24.5).timetableKey,
        isNot(base.timetableKey),
      );
    });
  });
}
