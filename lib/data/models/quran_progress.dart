import '../../core/utils/json_utils.dart';
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
