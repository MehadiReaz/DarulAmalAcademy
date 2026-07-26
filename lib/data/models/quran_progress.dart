import '../../core/utils/json_utils.dart';
import 'pagination.dart';
import 'student_user.dart';

/// Matches the `quran_progress` block returned by
/// `StudentLoginController@profile` (GET /auth/student/profile).
///
/// {
///   "id": 4,
///   "noorani_qaida_lesson": "12",
///   "noorani_qaida_percentage": 100,
///   "paras_completed": 3,
///   "para_percentage": 10,
///   "surahs_completed": 5,
///   "surah_percentage": 4.4,
///   "quran_reading_focus": "nazira",
///   "reading_focus_label": "Nazira",
///   "assigned_teacher": { "id": 9, "name": "Ustadh ..." }
/// }
///
/// Percentages arrive as 0–100 numbers (sometimes as strings), so every
/// reader below is defensive and every `*Fraction` getter is clamped to
/// 0.0–1.0 for use with LinearProgressIndicator.
class QuranProgress {
  final int? id;
  final String? nooraniQaidaLesson;
  final double nooraniQaidaPercentage;
  final int parasCompleted;
  final double paraPercentage;
  final int surahsCompleted;
  final double surahPercentage;
  final String? readingFocus;
  final String? readingFocusLabel;
  final NamedRef? assignedTeacher;
  final DateTime? updatedAt;

  const QuranProgress({
    this.id,
    this.nooraniQaidaLesson,
    this.nooraniQaidaPercentage = 0,
    this.parasCompleted = 0,
    this.paraPercentage = 0,
    this.surahsCompleted = 0,
    this.surahPercentage = 0,
    this.readingFocus,
    this.readingFocusLabel,
    this.assignedTeacher,
    this.updatedAt,
  });

  factory QuranProgress.fromJson(Map<String, dynamic> json) => QuranProgress(
        id: asIntOrNull(json['id']),
        nooraniQaidaLesson: asStringOrNull(json['noorani_qaida_lesson']),
        nooraniQaidaPercentage: asDouble(json['noorani_qaida_percentage']),
        parasCompleted: asInt(json['paras_completed']),
        paraPercentage: asDouble(json['para_percentage']),
        surahsCompleted: asInt(json['surahs_completed']),
        surahPercentage: asDouble(json['surah_percentage']),
        readingFocus: asStringOrNull(json['quran_reading_focus']),
        readingFocusLabel: asStringOrNull(json['reading_focus_label']),
        assignedTeacher: json['assigned_teacher'] == null
            ? null
            : NamedRef.fromJson(asMap(json['assigned_teacher']) ?? {}),
        updatedAt: asDate(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'noorani_qaida_lesson': nooraniQaidaLesson,
        'noorani_qaida_percentage': nooraniQaidaPercentage,
        'paras_completed': parasCompleted,
        'para_percentage': paraPercentage,
        'surahs_completed': surahsCompleted,
        'surah_percentage': surahPercentage,
        'quran_reading_focus': readingFocus,
        'reading_focus_label': readingFocusLabel,
        'assigned_teacher': assignedTeacher?.toJson(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  static double _fraction(double percent) {
    final v = percent / 100.0;
    if (v.isNaN) return 0;
    return v.clamp(0.0, 1.0);
  }

  double get nooraniFraction => _fraction(nooraniQaidaPercentage);
  double get paraFraction => _fraction(paraPercentage);
  double get surahFraction => _fraction(surahPercentage);

  /// True when the backend has nothing meaningful recorded yet, so the
  /// UI can show an honest "not started" state instead of empty bars.
  bool get isEmpty =>
      nooraniQaidaPercentage == 0 &&
      paraPercentage == 0 &&
      surahPercentage == 0 &&
      parasCompleted == 0 &&
      surahsCompleted == 0;

  String get teacherName => assignedTeacher?.name ?? 'Your teacher';
}

/// Matches an entry in `quran_progress_logs`.
///
/// `progress_data` is free-form JSON on the backend, so it is kept as a
/// raw map rather than being forced into a schema.
class QuranProgressLog {
  final int id;
  final String? loggedOn;
  final String? note;
  final Map<String, dynamic> progressData;

  const QuranProgressLog({
    required this.id,
    this.loggedOn,
    this.note,
    this.progressData = const {},
  });

  factory QuranProgressLog.fromJson(Map<String, dynamic> json) =>
      QuranProgressLog(
        id: asInt(json['id']),
        loggedOn: asStringOrNull(json['logged_on']),
        note: asStringOrNull(json['note']),
        progressData: asMap(json['progress_data']) ?? const {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'logged_on': loggedOn,
        'note': note,
        'progress_data': progressData,
      };

  DateTime? get loggedAt => asDate(loggedOn);
}

/// One of the 114 surahs, from `reference_data.surahs`.
class SurahRef {
  final int number;
  final String nameAr;
  final String nameEn;

  const SurahRef({
    required this.number,
    this.nameAr = '',
    this.nameEn = '',
  });

  factory SurahRef.fromJson(Map<String, dynamic> json) => SurahRef(
        number: asInt(json['number']),
        nameAr: asString(json['name_ar']),
        nameEn: asString(json['name_en']),
      );

  String get display => nameEn.isEmpty ? nameAr : nameEn;
}

/// The `reference_data` block on `GET /student/quran-progress` — the
/// curriculum's fixed denominators and label lookups.
///
/// Reading totals from here rather than hardcoding 30 paras / 27 lessons
/// means the app follows the madrasah's own configuration.
class QuranReferenceData {
  final List<SurahRef> surahs;

  /// Machine key → display label, e.g. `pronunciation` →
  /// "Pronunciation (উচ্চারণ)".
  final Map<String, String> readingFocus;

  final int totalLessons;
  final int totalParas;
  final int tajweedScale;

  const QuranReferenceData({
    this.surahs = const [],
    this.readingFocus = const {},
    this.totalLessons = 27,
    this.totalParas = 30,
    this.tajweedScale = 5,
  });

  factory QuranReferenceData.fromJson(Map<String, dynamic> json) {
    final focusRaw = asMap(json['reading_focus']) ?? const {};
    return QuranReferenceData(
      surahs: asList(json['surahs'], SurahRef.fromJson),
      readingFocus: focusRaw.map(
        (k, v) => MapEntry(k.toString(), v?.toString() ?? k.toString()),
      ),
      totalLessons: asInt(json['total_lessons'], fallback: 27),
      totalParas: asInt(json['total_paras'], fallback: 30),
      tajweedScale: asInt(json['tajweed_scale'], fallback: 5),
    );
  }

  /// Resolves a focus key to its bilingual label, falling back to the key
  /// itself so an unknown value still renders as something.
  String focusLabel(String? key) {
    if (key == null || key.isEmpty) return '';
    return readingFocus[key] ?? key;
  }

  String surahName(int number) {
    for (final s in surahs) {
      if (s.number == number) return s.display;
    }
    return 'Surah $number';
  }
}

/// Everything `GET /student/quran-progress` returns.
///
/// This supersedes the `quran_progress` block on the profile endpoint:
/// it carries paginated logs and the reference data, and it is the
/// endpoint the madrasah will keep current.
class QuranProgressBundle {
  final QuranProgress? progress;
  final List<QuranProgressLog> logs;
  final Pagination logsPagination;
  final QuranReferenceData reference;

  const QuranProgressBundle({
    this.progress,
    this.logs = const [],
    this.logsPagination = const Pagination(),
    this.reference = const QuranReferenceData(),
  });

  factory QuranProgressBundle.fromJson(Map<String, dynamic> json) {
    final rawProgress = asMap(json['progress']);
    final logsBlock = asMap(json['logs']) ?? const {};

    return QuranProgressBundle(
      // `progress` is null until a teacher records the first entry.
      progress:
          rawProgress == null ? null : QuranProgress.fromJson(rawProgress),
      logs: asList(logsBlock['data'], QuranProgressLog.fromJson),
      logsPagination: Pagination.fromJson(logsBlock),
      reference:
          QuranReferenceData.fromJson(asMap(json['reference_data']) ?? {}),
    );
  }

  bool get hasProgress => progress != null && !progress!.isEmpty;
}
