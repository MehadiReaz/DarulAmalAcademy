import 'package:flutter/painting.dart' show Color;

import '../../core/utils/json_utils.dart';
import 'pagination.dart';
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

  /// [color] parsed into a usable value, or null when the backend sent
  /// nothing or something unparseable. Accepts "#RRGGBB", "RRGGBB" and
  /// "#AARRGGBB" — the seeded data uses the first form.
  Color? get colorValue {
    var hex = color?.trim().replaceFirst('#', '');
    if (hex == null || hex.isEmpty) return null;
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final value = int.tryParse(hex, radix: 16);
    return value == null ? null : Color(value);
  }
}

/// Bundle returned by `GET /student/my-class-routine`.
///
/// `routines` is a raw Laravel paginator, while `schedules` and
/// `teachers` are plain arrays alongside it.
class ClassRoutineBundle {
  final List<ClassRoutine> routines;
  final Pagination pagination;
  final List<ScheduleEntry> schedules;
  final List<NamedRef> teachers;

  const ClassRoutineBundle({
    this.routines = const [],
    this.pagination = const Pagination(),
    this.schedules = const [],
    this.teachers = const [],
  });

  factory ClassRoutineBundle.fromJson(Map<String, dynamic> json) {
    final routinesBlock = asMap(json['routines']) ?? const {};
    return ClassRoutineBundle(
      routines: asList(routinesBlock['data'], ClassRoutine.fromJson),
      pagination: Pagination.fromJson(routinesBlock),
      schedules: asList(json['schedules'], ScheduleEntry.fromJson),
      teachers: asList(json['teachers'], NamedRef.fromJson),
    );
  }

  bool get isEmpty => routines.isEmpty && schedules.isEmpty;

  /// Routines bucketed by ISO weekday (1 = Monday … 7 = Sunday), which is
  /// how `ClassRoutine::WEEK_DAYS` is keyed server-side.
  Map<int, List<ClassRoutine>> get byWeekday {
    final map = <int, List<ClassRoutine>>{};
    for (final r in routines) {
      final day = r.weekday;
      if (day == null) continue;
      map.putIfAbsent(day, () => []).add(r);
    }
    for (final list in map.values) {
      list.sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? ''));
    }
    return map;
  }
}

/// An entry in the `schedules` array — a one-off dated session, as
/// opposed to a weekly recurring routine.
class ScheduleEntry {
  final int id;
  final String title;
  final String? start;
  final String? end;

  const ScheduleEntry({
    required this.id,
    required this.title,
    this.start,
    this.end,
  });

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) => ScheduleEntry(
        id: asInt(json['id']),
        title: asString(json['title'], fallback: 'Session'),
        start: asStringOrNull(json['start']),
        end: asStringOrNull(json['end']),
      );

  DateTime? get startsAt => asDate(start);
  DateTime? get endsAt => asDate(end);
}

/// Payload from `GET /student/classes/{id}/join`.
///
/// This endpoint returned 403 ("You are not enrolled in this class") for
/// every class in the test run, including ones `GET /student/my-classes`
/// listed for the same student — so the success shape is inferred. Keys
/// are read under several plausible names and [raw] preserves the body.
class ClassJoinInfo {
  final String? joinUrl;
  final String? meetingId;
  final String? password;
  final String? provider;
  final Map<String, dynamic> raw;

  const ClassJoinInfo({
    this.joinUrl,
    this.meetingId,
    this.password,
    this.provider,
    this.raw = const {},
  });

  factory ClassJoinInfo.fromJson(Map<String, dynamic> json) => ClassJoinInfo(
        joinUrl: asStringOrNull(json['join_url']) ??
            asStringOrNull(json['zoom_link']) ??
            asStringOrNull(json['url']) ??
            asStringOrNull(json['link']) ??
            asStringOrNull(json['meeting_url']),
        meetingId: asStringOrNull(json['meeting_id']) ??
            asStringOrNull(json['zoom_meeting_id']),
        password: asStringOrNull(json['password']) ??
            asStringOrNull(json['meeting_password']),
        provider: asStringOrNull(json['provider']),
        raw: json,
      );

  bool get canJoin => joinUrl != null && joinUrl!.isNotEmpty;
}
