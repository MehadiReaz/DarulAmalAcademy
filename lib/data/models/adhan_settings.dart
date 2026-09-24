import '../../core/utils/json_utils.dart';
import 'prayer_times.dart';

/// Which recording plays when the adhan notification fires.
///
/// Each value maps to a bundled file: `res/raw/<id>.mp3` on Android (full
/// length) and `Runner/<id>.caf` on iOS (29.5 s, since iOS caps
/// notification sounds at 30 s).
enum AdhanSound {
  classic('adhan_classic', 'Classic Adhan'),
  fakhri('adhan_fakhri', 'Sabah Fakhri'),
  short('adhan_short', 'Short Adhan'),
  tone('tone', 'Notification tone only'),
  silent('silent', 'Silent (banner only)');

  final String id;
  final String label;
  const AdhanSound(this.id, this.label);

  bool get isRecording =>
      this == classic || this == fakhri || this == short;

  static AdhanSound byName(String? name, AdhanSound fallback) =>
      values.where((v) => v.name == name).firstOrNull ?? fallback;
}

/// How the location is supplied to Aladhan.
enum AdhanLocationMode { device, city }

/// Aladhan calculation method ids (`method=`).
/// https://aladhan.com/calculation-methods
const Map<int, String> kCalculationMethods = {
  1: 'University of Islamic Sciences, Karachi',
  2: 'Islamic Society of North America (ISNA)',
  3: 'Muslim World League',
  4: 'Umm Al-Qura, Makkah',
  5: 'Egyptian General Authority of Survey',
  8: 'Gulf Region',
  9: 'Kuwait',
  10: 'Qatar',
  11: 'Majlis Ugama Islam Singapura',
  12: 'Union Organization Islamic de France',
  13: 'Diyanet İşleri Başkanlığı, Turkey',
  14: 'Spiritual Administration of Muslims of Russia',
  15: 'Moonsighting Committee Worldwide',
  16: 'Dubai',
  17: 'JAKIM, Malaysia',
  18: 'Tunisia',
  19: 'Algeria',
  20: 'KEMENAG, Indonesia',
  21: 'Morocco',
  22: 'Comunidade Islamica de Lisboa',
  23: 'Ministry of Awqaf, Jordan',
  0: 'Shia Ithna-Ashari (Jafari)',
  7: 'Institute of Geophysics, University of Tehran',
};

/// Reminder lead times offered in settings, in minutes. 0 = off.
const List<int> kReminderOptions = [0, 5, 10, 15, 20, 30];

/// Everything the student can customise about the adhan.
class AdhanSettings {
  final bool enabled;
  final Map<Prayer, bool> prayers;
  final AdhanSound sound;
  final AdhanSound fajrSound;
  final int method;

  /// Aladhan `school`: 0 = Standard (Shafi'i, Maliki, Hanbali), 1 = Hanafi.
  final int school;
  final int reminderMinutes;

  final AdhanLocationMode locationMode;
  final double? latitude;
  final double? longitude;
  final String? city;
  final String? country;

  /// Human-readable name of the resolved location (for the header).
  final String? locationLabel;

  const AdhanSettings({
    this.enabled = false,
    this.prayers = const {
      Prayer.fajr: true,
      Prayer.dhuhr: true,
      Prayer.asr: true,
      Prayer.maghrib: true,
      Prayer.isha: true,
    },
    this.sound = AdhanSound.classic,
    this.fajrSound = AdhanSound.classic,
    this.method = 1,
    this.school = 1,
    this.reminderMinutes = 0,
    this.locationMode = AdhanLocationMode.device,
    this.latitude,
    this.longitude,
    this.city,
    this.country,
    this.locationLabel,
  });

  bool get hasLocation => locationMode == AdhanLocationMode.device
      ? latitude != null && longitude != null
      : (city?.isNotEmpty ?? false) && (country?.isNotEmpty ?? false);

  bool isOn(Prayer p) => prayers[p] ?? true;

  AdhanSound soundFor(Prayer p) => p == Prayer.fajr ? fajrSound : sound;

  /// Identifies the inputs that change the timetable itself. Cached
  /// timings are only reused while this stays the same.
  String get timetableKey => [
        method,
        school,
        locationMode.name,
        if (locationMode == AdhanLocationMode.device) ...[
          latitude?.toStringAsFixed(3),
          longitude?.toStringAsFixed(3),
        ] else ...[
          city?.trim().toLowerCase(),
          country?.trim().toLowerCase(),
        ],
      ].join('|');

  AdhanSettings copyWith({
    bool? enabled,
    Map<Prayer, bool>? prayers,
    AdhanSound? sound,
    AdhanSound? fajrSound,
    int? method,
    int? school,
    int? reminderMinutes,
    AdhanLocationMode? locationMode,
    double? latitude,
    double? longitude,
    String? city,
    String? country,
    String? locationLabel,
  }) {
    return AdhanSettings(
      enabled: enabled ?? this.enabled,
      prayers: prayers ?? this.prayers,
      sound: sound ?? this.sound,
      fajrSound: fajrSound ?? this.fajrSound,
      method: method ?? this.method,
      school: school ?? this.school,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      locationMode: locationMode ?? this.locationMode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      city: city ?? this.city,
      country: country ?? this.country,
      locationLabel: locationLabel ?? this.locationLabel,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'prayers': {for (final e in prayers.entries) e.key.name: e.value},
        'sound': sound.name,
        'fajr_sound': fajrSound.name,
        'method': method,
        'school': school,
        'reminder_minutes': reminderMinutes,
        'location_mode': locationMode.name,
        'latitude': latitude,
        'longitude': longitude,
        'city': city,
        'country': country,
        'location_label': locationLabel,
      };

  factory AdhanSettings.fromJson(Map<String, dynamic> json) {
    const d = AdhanSettings();
    final rawPrayers = asMap(json['prayers']) ?? const {};
    final method = asIntOrNull(json['method']);
    final reminder = asIntOrNull(json['reminder_minutes']);
    final lat = json['latitude'];
    final lng = json['longitude'];
    return AdhanSettings(
      enabled: asBool(json['enabled']),
      prayers: {
        for (final p in Prayer.values)
          p: rawPrayers.containsKey(p.name) ? asBool(rawPrayers[p.name]) : true,
      },
      sound: AdhanSound.byName(asStringOrNull(json['sound']), d.sound),
      fajrSound:
          AdhanSound.byName(asStringOrNull(json['fajr_sound']), d.fajrSound),
      method: kCalculationMethods.containsKey(method) ? method! : d.method,
      school: asIntOrNull(json['school']) == 0 ? 0 : 1,
      reminderMinutes:
          kReminderOptions.contains(reminder) ? reminder! : d.reminderMinutes,
      locationMode: asStringOrNull(json['location_mode']) == 'city'
          ? AdhanLocationMode.city
          : AdhanLocationMode.device,
      latitude: lat is num ? lat.toDouble() : null,
      longitude: lng is num ? lng.toDouble() : null,
      city: asStringOrNull(json['city']),
      country: asStringOrNull(json['country']),
      locationLabel: asStringOrNull(json['location_label']),
    );
  }
}
