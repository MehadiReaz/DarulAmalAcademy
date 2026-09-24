import 'package:geolocator/geolocator.dart';

import '../core/network/api_exception.dart';
import '../core/services/adhan_service.dart';
import '../core/storage/adhan_storage.dart';
import '../data/models/adhan_settings.dart';
import '../data/models/prayer_times.dart';
import '../data/repositories/prayer_times_repository.dart';
import 'base_provider.dart';

/// Owns the adhan settings and keeps the OS schedule in sync with them.
///
/// Created eagerly at app start: [load] reschedules from the cached
/// timetable (fetching more when it runs short), which keeps the
/// three-week Android / ~week-long iOS window rolling forward each time
/// the app is opened.
class AdhanProvider extends BaseProvider {
  final PrayerTimesRepository _repo;
  final AdhanStorage _storage;

  AdhanProvider(this._repo, this._storage);

  /// How far ahead the cached timetable should reach.
  static const _horizon = Duration(days: 22);

  AdhanSettings _settings = const AdhanSettings();
  List<PrayerDay> _days = const [];
  LoadState _state = LoadState.idle;
  String? _error;
  bool _busy = false;
  bool _exactAllowed = true;
  DateTime? _scheduledUntil;
  Future<void> _queue = Future.value();

  AdhanSettings get settings => _settings;
  LoadState get state => _state;
  String? get error => _error;

  /// True while a location lookup or reschedule is running.
  bool get busy => _busy;

  /// False on Android 12+ when exact alarms were denied.
  bool get exactAllowed => _exactAllowed;

  /// When the last scheduled adhan fires; the app must be opened before
  /// then to schedule more.
  DateTime? get scheduledUntil => _scheduledUntil;

  PrayerDay? get today => _dayFor(DateTime.now());
  PrayerDay? get tomorrow =>
      _dayFor(DateTime.now().add(const Duration(days: 1)));

  /// The prayer whose time has begun today and is still the latest one,
  /// e.g. Asr between Asr and Maghrib. Null before today's Fajr.
  Prayer? get currentPrayer {
    final day = today;
    if (day == null) return null;
    final now = DateTime.now();
    Prayer? current;
    for (final p in Prayer.values) {
      if (!day.times[p]!.isAfter(now)) current = p;
    }
    return current;
  }

  /// The next prayer still to come, looking into tomorrow after Isha.
  (Prayer, DateTime)? get nextPrayer {
    final now = DateTime.now();
    for (final day in [today, tomorrow]) {
      if (day == null) continue;
      for (final p in Prayer.values) {
        final t = day.times[p]!;
        if (t.isAfter(now)) return (p, t);
      }
    }
    return null;
  }

  PrayerDay? _dayFor(DateTime d) {
    for (final day in _days) {
      if (day.date.year == d.year &&
          day.date.month == d.month &&
          day.date.day == d.day) {
        return day;
      }
    }
    return null;
  }

  Future<void> load() async {
    await AdhanService.initialize();
    _settings = await _storage.readSettings();
    _days = await _storage.readTimetable(_settings.timetableKey);
    _exactAllowed = await AdhanService.canScheduleExact();
    safeNotify();
    await refresh();
  }

  /// Makes sure the timetable reaches [_horizon] ahead, then reschedules.
  /// Runs one at a time so rapid toggles can't interleave schedules.
  Future<void> refresh({bool force = false}) {
    return _queue = _queue.then((_) => _refresh(force: force));
  }

  Future<void> _refresh({bool force = false}) async {
    if (!_settings.hasLocation) {
      await AdhanService.cancelAll();
      _scheduledUntil = null;
      safeNotify();
      return;
    }

    if (force || !_covers(DateTime.now().add(_horizon))) {
      await guard(
        _fetch,
        onState: (s, e) {
          _state = s;
          _error = e;
        },
      );
    } else {
      _state = LoadState.ready;
    }

    _exactAllowed = await AdhanService.canScheduleExact();
    _scheduledUntil = await AdhanService.schedule(_settings, _days);
    safeNotify();
  }

  bool _covers(DateTime until) {
    final today = DateTime.now();
    return _dayFor(today) != null && _dayFor(until) != null;
  }

  Future<void> _fetch() async {
    final now = DateTime.now();
    final end = now.add(_horizon);
    final months = <(int, int)>{
      (now.year, now.month),
      (end.year, end.month),
    };

    final days = <PrayerDay>[];
    String? timezone;
    for (final (y, m) in months) {
      final month = await _repo.month(_settings, y, m);
      days.addAll(month.days);
      timezone ??= month.timezone;
    }

    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    _days = days.where((d) => !d.date.isBefore(start)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    await _storage.writeTimetable(_settings.timetableKey, _days);

    if (_settings.locationMode == AdhanLocationMode.device &&
        timezone != null) {
      final city = timezone.split('/').last.replaceAll('_', ' ');
      await _save(_settings.copyWith(locationLabel: 'Near $city'));
    }
  }

  Future<void> _save(AdhanSettings next) async {
    final timetableChanged = next.timetableKey != _settings.timetableKey;
    _settings = next;
    if (timetableChanged) _days = const [];
    safeNotify();
    await _storage.writeSettings(next);
  }

  /// Applies a settings change and reschedules.
  Future<void> update(AdhanSettings next) async {
    final timetableChanged = next.timetableKey != _settings.timetableKey;
    await _save(next);
    await _withBusy(() => refresh(force: timetableChanged));
  }

  /// Turns the adhan on or off. Turning it on asks for notification
  /// permission and, without a saved location, the device's location.
  /// Returns an error message when it could not be enabled.
  Future<String?> setEnabled(bool on) async {
    if (!on) {
      await update(_settings.copyWith(enabled: false));
      return null;
    }

    final allowed = await AdhanService.requestPermissions();
    if (!allowed) {
      return 'Notifications are blocked. Allow them in system settings '
          'to hear the adhan.';
    }

    if (!_settings.hasLocation) {
      final err = await useDeviceLocation(enable: true);
      if (err != null) return err;
      return null;
    }
    await update(_settings.copyWith(enabled: true));
    return _error;
  }

  /// Switches to the device's current location. Coarse accuracy is plenty:
  /// prayer times barely move within a few kilometres.
  Future<String?> useDeviceLocation({bool enable = false}) async {
    _busy = true;
    safeNotify();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return 'Location services are turned off. Turn them on, or set '
            'your city manually.';
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return 'Location permission was denied. Set your city manually '
            'instead.';
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );
      await _save(_settings.copyWith(
        enabled: enable ? true : null,
        locationMode: AdhanLocationMode.device,
        latitude: pos.latitude,
        longitude: pos.longitude,
        locationLabel: 'Current location',
      ));
      await refresh(force: true);
      return _error;
    } catch (e) {
      return 'Could not get your location. Try again or set your city '
          'manually.';
    } finally {
      _busy = false;
      safeNotify();
    }
  }

  /// Validates [city]/[country] against Aladhan before saving them.
  Future<String?> useCity(String city, String country) async {
    final candidate = _settings.copyWith(
      locationMode: AdhanLocationMode.city,
      city: city.trim(),
      country: country.trim(),
      locationLabel: '${city.trim()}, ${country.trim()}',
    );

    _busy = true;
    safeNotify();
    try {
      final now = DateTime.now();
      await _repo.month(candidate, now.year, now.month);
    } on ApiException catch (e) {
      return e.message;
    } finally {
      _busy = false;
      safeNotify();
    }
    await update(candidate);
    return _error;
  }

  Future<void> _withBusy(Future<void> Function() action) async {
    _busy = true;
    safeNotify();
    try {
      await action();
    } finally {
      _busy = false;
      safeNotify();
    }
  }
}
