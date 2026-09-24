import '../../core/utils/json_utils.dart';
import 'student_user.dart';

/// A single attendance record from `GET /api/student/attendance`.
class AttendanceRecord {
  final int id;

  /// 'present' | 'late' | 'absent' (anything else is shown as-is).
  final String status;
  final String? rawDate;

  /// Pre-formatted by the server as "20/09/2026".
  final String? dateLabel;

  /// What the class covered, e.g. the live session topic.
  final String? className;

  /// Where the record came from, e.g. `live_class`.
  final String? source;

  /// Minutes late, when the server sends it.
  final int lateMinutes;

  final NamedRef? course;
  final NamedRef? batch;
  final NamedRef? teacher;

  const AttendanceRecord({
    required this.id,
    this.status = 'absent',
    this.rawDate,
    this.dateLabel,
    this.className,
    this.source,
    this.lateMinutes = 0,
    this.course,
    this.batch,
    this.teacher,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    NamedRef? ref(dynamic v) {
      final m = asMap(v);
      return m == null ? null : NamedRef.fromJson(m);
    }

    return AttendanceRecord(
      id: asInt(json['id']),
      status: asString(json['status'], fallback: 'absent').toLowerCase(),
      rawDate: asStringOrNull(json['date']),
      dateLabel: asStringOrNull(json['date_formatted'] ?? json['date_time']),
      className: asStringOrNull(
        json['class_name'] ?? asMap(json['session'])?['topic'],
      ),
      source: asStringOrNull(json['source']),
      lateMinutes: asInt(json['late_amount']),
      course: ref(json['course']),
      batch: ref(json['batch']),
      teacher: ref(json['teacher']),
    );
  }

  bool get isPresent => status == 'present';
  bool get isLate => status == 'late';
  bool get isAbsent => !isPresent && !isLate;

  DateTime? get date => asDate(rawDate);

  String get statusLabel {
    if (isPresent) return 'Present';
    if (isLate) return 'Late';
    if (status == 'absent' || status.isEmpty) return 'Absent';
    return status[0].toUpperCase() + status.substring(1);
  }

  /// Parses the list out of any of the shapes the endpoint has used:
  /// `{attendances: <paginator>}`, a bare paginator, or a plain list.
  static List<AttendanceRecord> listFrom(dynamic data) {
    dynamic items = data;
    final map = asMap(data);
    if (map != null) {
      items = map['attendances'] ?? map;
      final inner = asMap(items);
      if (inner != null) items = inner['data'];
    }
    if (items is! List) return const [];
    return asList(items, AttendanceRecord.fromJson);
  }
}

/// One course's worth of attendance.
///
/// Records carry a course and batch but no subject, so the screen groups
/// by course (falling back to the batch name).
class AttendanceGroup {
  final String title;
  final String? subtitle;
  final List<AttendanceRecord> records;

  const AttendanceGroup({
    required this.title,
    this.subtitle,
    this.records = const [],
  });

  int get present => records.where((r) => r.isPresent).length;
  int get late => records.where((r) => r.isLate).length;
  int get absent => records.where((r) => r.isAbsent).length;
  int get total => records.length;

  /// Late is deliberately NOT counted as present — that mirrors the
  /// dashboard's own `present_score`, where a 'late' record contributes
  /// `present_days: 0`.
  double get fraction => total == 0 ? 0 : (present / total).clamp(0.0, 1.0);

  int get percentage => (fraction * 100).round();

  /// Groups [records] by course, newest record first, groups sorted by
  /// title.
  static List<AttendanceGroup> group(List<AttendanceRecord> records) {
    final byKey = <String, List<AttendanceRecord>>{};
    for (final r in records) {
      final key = r.course != null
          ? 'c${r.course!.id}'
          : (r.batch != null ? 'b${r.batch!.id}' : 'other');
      byKey.putIfAbsent(key, () => []).add(r);
    }

    final groups = byKey.values.map((list) {
      list.sort((a, b) {
        final ad = a.date, bd = b.date;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });
      final first = list.first;
      final batches = list
          .map((r) => r.batch?.name)
          .whereType<String>()
          .where((n) => n.isNotEmpty)
          .toSet();
      return AttendanceGroup(
        title: first.course?.name ?? first.batch?.name ?? 'Other classes',
        subtitle: first.course != null && batches.length == 1
            ? batches.first
            : null,
        records: list,
      );
    }).toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    return groups;
  }
}

/// Roll-up across every course, for the summary header.
class AttendanceSummary {
  final int present;
  final int late;
  final int absent;

  const AttendanceSummary({
    this.present = 0,
    this.late = 0,
    this.absent = 0,
  });

  factory AttendanceSummary.from(List<AttendanceGroup> groups) {
    var p = 0, l = 0, a = 0;
    for (final g in groups) {
      p += g.present;
      l += g.late;
      a += g.absent;
    }
    return AttendanceSummary(present: p, late: l, absent: a);
  }

  int get total => present + late + absent;
  double get fraction => total == 0 ? 0 : (present / total).clamp(0.0, 1.0);
  int get percentage => (fraction * 100).round();
}
