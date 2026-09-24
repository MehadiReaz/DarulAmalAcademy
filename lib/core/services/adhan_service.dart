import 'dart:developer' as dev;
import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/adhan_settings.dart';
import '../../data/models/prayer_times.dart';
import '../utils/formatters.dart';

/// Schedules the adhan as OS-level notifications.
///
/// Every prayer is handed to the OS ahead of time (AlarmManager on
/// Android, UNUserNotificationCenter on iOS), so the adhan plays with the
/// app closed or killed. The adhan recording *is* the notification sound:
///  * Android plays the full recording from `res/raw`. A channel's sound is
///    fixed once created, so each [AdhanSound] gets its own channel.
///  * iOS plays at most 30 s of a notification sound, so the bundled
///    `.caf` files are 29.5 s clips that fade out.
class AdhanService {
  AdhanService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Adhan notifications use ids in [_idBase, _idBase + _idSpan) so they
  /// can be cancelled without touching FCM notifications.
  static const int _idBase = 7000000;
  static const int _idSpan = 100000;
  static const int _testId = _idBase + _idSpan - 1;

  /// Android has no small pending-alarm cap, so cover three weeks.
  static const int _androidDays = 21;

  /// iOS keeps at most 64 pending notifications per app.
  static const int _iosMaxPending = 60;

  static const _reminderChannel = AndroidNotificationChannel(
    'prayer_reminder_v1',
    'Prayer Reminders',
    description: 'A heads-up a few minutes before each prayer.',
    importance: Importance.high,
  );

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      // FcmService may already have initialised the plugin; calling it
      // again is harmless and keeps this service usable on its own.
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      final android = _android;
      if (android != null) {
        for (final s in AdhanSound.values) {
          await android.createNotificationChannel(_channelFor(s));
        }
        await android.createNotificationChannel(_reminderChannel);
      }
      _initialized = true;
    } catch (e, st) {
      dev.log('AdhanService init failed: $e', error: e, stackTrace: st);
    }
  }

  static AndroidNotificationChannel _channelFor(AdhanSound s) {
    return AndroidNotificationChannel(
      'adhan_${s.id}_v1',
      s == AdhanSound.silent ? 'Adhan (silent)' : 'Adhan – ${s.label}',
      description: 'Plays at each prayer time you have turned on.',
      importance: Importance.max,
      playSound: s != AdhanSound.silent,
      sound: s.isRecording ? RawResourceAndroidNotificationSound(s.id) : null,
    );
  }

  // ───────────────────────────────────────────── permissions

  /// Asks for notification (and, on Android, exact alarm) permission.
  /// Returns false when notifications were refused.
  static Future<bool> requestPermissions() async {
    await initialize();
    if (Platform.isAndroid) {
      final granted = await _android?.requestNotificationsPermission() ?? true;
      if (!await canScheduleExact()) {
        await _android?.requestExactAlarmsPermission();
      }
      return granted;
    }
    if (Platform.isIOS) {
      return await _ios?.requestPermissions(
            alert: true,
            sound: true,
            badge: false,
          ) ??
          true;
    }
    return true;
  }

  /// Android 12+ can deny exact alarms; without them the adhan may run a
  /// few minutes late while the phone is idle.
  static Future<bool> canScheduleExact() async {
    if (!Platform.isAndroid) return true;
    return await _android?.canScheduleExactNotifications() ?? true;
  }

  static Future<void> requestExactAlarms() async {
    await _android?.requestExactAlarmsPermission();
  }

  // ───────────────────────────────────────────── scheduling

  /// Cancels every adhan notification this service scheduled.
  static Future<void> cancelAll() async {
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    for (final p in pending) {
      if (p.id >= _idBase && p.id < _idBase + _idSpan) {
        await _plugin.cancel(id: p.id);
      }
    }
  }

  /// Replaces the scheduled adhans with ones built from [days].
  /// Returns the time of the last scheduled adhan, or null if none.
  static Future<DateTime?> schedule(
    AdhanSettings settings,
    List<PrayerDay> days,
  ) async {
    await initialize();
    await cancelAll();
    if (!settings.enabled) return null;

    final now = DateTime.now();
    final enabled = Prayer.values.where(settings.isOn).toList();
    if (enabled.isEmpty) return null;

    final perDay =
        enabled.length * (settings.reminderMinutes > 0 ? 2 : 1);
    final maxDays = Platform.isIOS
        ? (_iosMaxPending ~/ perDay).clamp(1, _androidDays)
        : _androidDays;

    final upcoming = days
        .where((d) => d.times[Prayer.isha]!.isAfter(now))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final mode = await canScheduleExact()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    DateTime? last;
    for (var dayIndex = 0;
        dayIndex < upcoming.length && dayIndex < maxDays;
        dayIndex++) {
      final day = upcoming[dayIndex];
      for (final prayer in enabled) {
        final at = day.times[prayer]!;
        final slot = _idBase + dayIndex * 20 + prayer.index * 2;

        if (at.isAfter(now)) {
          await _zoned(
            id: slot,
            at: at,
            title: '${prayer.label} · ${Fmt.clock(at)}',
            body: "It's time for ${prayer.label} prayer.",
            details: _adhanDetails(settings.soundFor(prayer)),
            mode: mode,
          );
          last = at;
        }

        final remindAt =
            at.subtract(Duration(minutes: settings.reminderMinutes));
        if (settings.reminderMinutes > 0 && remindAt.isAfter(now)) {
          await _zoned(
            id: slot + 1,
            at: remindAt,
            title: '${prayer.label} in ${settings.reminderMinutes} minutes',
            body: '${prayer.label} begins at ${Fmt.clock(at)}.',
            details: _reminderDetails(),
            mode: mode,
          );
        }
      }
    }
    return last;
  }

  /// Plays the chosen adhan right away so the student can hear it.
  static Future<void> playTest(AdhanSound sound) async {
    await initialize();
    await _plugin.cancel(id: _testId);
    await _plugin.show(
      id: _testId,
      title: 'Adhan preview',
      body: sound == AdhanSound.silent
          ? 'Silent mode shows the banner without sound.'
          : 'Playing: ${sound.label}. Dismiss to stop.',
      notificationDetails: _adhanDetails(sound),
    );
  }

  static Future<void> stopTest() => _plugin.cancel(id: _testId);

  static Future<void> _zoned({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required NotificationDetails details,
    required AndroidScheduleMode mode,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        // Times are absolute instants, so UTC is exact and immune to the
        // device changing timezone later.
        scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
        notificationDetails: details,
        androidScheduleMode: mode,
        title: title,
        body: body,
        payload: 'adhan',
      );
    } catch (e, st) {
      dev.log('Failed to schedule adhan $id: $e', error: e, stackTrace: st);
    }
  }

  static NotificationDetails _adhanDetails(AdhanSound sound) {
    final channel = _channelFor(sound);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.max,
        priority: Priority.max,
        playSound: channel.playSound,
        sound: channel.sound,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: sound != AdhanSound.silent,
        sound: sound.isRecording ? '${sound.id}.caf' : null,
      ),
    );
  }

  static NotificationDetails _reminderDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _reminderChannel.id,
        _reminderChannel.name,
        channelDescription: _reminderChannel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
      ),
    );
  }
}
