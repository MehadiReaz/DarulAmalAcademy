import '../../core/utils/json_utils.dart';
import 'student_user.dart';

/// Matches `StudentMyClassController@today` and `@upcoming`.
///
/// Note: `today` does NOT include `weekday_name`, `upcoming` does — so the
/// field is nullable and we fall back to formatting the numeric weekday.
class ClassRoutine {
  final int id;
  final int? weekday;
  final String? weekdayName;
  final String? startTime; // "21:00:00"
  final String? endTime;
  final bool isRecurring;
  final NamedRef? course;
  final NamedRef? teacher;
  final SubjectRef? subject;

  const ClassRoutine({
    required this.id,
    this.weekday,
    this.weekdayName,
    this.startTime,
    this.endTime,
    this.isRecurring = false,
    this.course,
    this.teacher,
    this.subject,
  });

  factory ClassRoutine.fromJson(Map<String, dynamic> json) {
    return ClassRoutine(
      id: asInt(json['id']),
      weekday: asIntOrNull(json['weekday']),
      weekdayName: asStringOrNull(json['weekday_name']),
      startTime: asStringOrNull(json['start_time']),
      endTime: asStringOrNull(json['end_time']),
      isRecurring: asBool(json['is_recurring']),
      course: json['course'] == null
          ? null
          : NamedRef.fromJson(asMap(json['course']) ?? {}),
      teacher: json['teacher'] == null
          ? null
          : NamedRef.fromJson(asMap(json['teacher']) ?? {}),
      subject: json['subject'] == null
          ? null
          : SubjectRef.fromJson(asMap(json['subject']) ?? {}),
    );
  }

  String get title => subject?.name ?? course?.name ?? 'Class';
  String get teacherName => teacher?.name ?? '—';
  String get courseName => course?.name ?? '—';
}

class SubjectRef {
  final int? id;
  final String? name;

  /// Hex string from the backend, e.g. "#EFA836". May be null.
  final String? color;

  const SubjectRef({this.id, this.name, this.color});

  factory SubjectRef.fromJson(Map<String, dynamic> json) => SubjectRef(
        id: asIntOrNull(json['id']),
        name: asStringOrNull(json['name']),
        color: asStringOrNull(json['color']),
      );
}
