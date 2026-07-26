import '../../core/utils/json_utils.dart';
import 'student_user.dart';

/// A single attendance record from `GET /student/my-attendances`.
class AttendanceRecord {
  final int id;
  final int? subjectId;

  /// 'present' | 'late' | 'absent'
  final String status;
  final String? rawDate;

  /// Pre-formatted by the server as "04/07/2026".
  final String? dateLabel;

  /// Minutes late, sent as a string.
  final int lateMinutes;

  final NamedRef? subject;
  final NamedRef? teacher;

  const AttendanceRecord({
    required this.id,
    this.subjectId,
    this.status = 'absent',
    this.rawDate,
    this.dateLabel,
    this.lateMinutes = 0,
    this.subject,
    this.teacher,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        id: asInt(json['id']),
        subjectId: asIntOrNull(json['subject_id']),
        status: asString(json['status'], fallback: 'absent').toLowerCase(),
        rawDate: asStringOrNull(json['date']),
        dateLabel: asStringOrNull(json['date_time']),
        lateMinutes: asInt(json['late_amount']),
        subject: json['subject'] == null
            ? null
            : NamedRef.fromJson(asMap(json['subject']) ?? {}),
        teacher: json['teacher'] == null
            ? null
            : NamedRef.fromJson(asMap(json['teacher']) ?? {}),
      );

  bool get isPresent => status == 'present';
  bool get isLate => status == 'late';
  bool get isAbsent => status == 'absent';

  DateTime? get date => asDate(rawDate);

  String get statusLabel {
    if (isPresent) return 'Present';
    if (isLate) return 'Late';
    return 'Absent';
  }
}

/// One subject's worth of attendance.
///
/// `GET /student/my-attendances` returns a **map keyed by subject id**
/// (`{"1": [...], "8": [...]}`), not a list — so this flattens it into
/// something sortable and renderable.
class SubjectAttendanceGroup {
  final int subjectId;
  final String subjectName;
  final List<AttendanceRecord> records;

  const SubjectAttendanceGroup({
    required this.subjectId,
    required this.subjectName,
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

  /// Parses the whole `data` map into a list sorted by subject name.
  static List<SubjectAttendanceGroup> parseAll(dynamic data) {
    final map = asMap(data);
    if (map == null) return const [];

    final groups = <SubjectAttendanceGroup>[];

    map.forEach((key, value) {
      if (value is! List) return;
      final records = asList(value, AttendanceRecord.fromJson);
      if (records.isEmpty) return;

      // The subject name lives on the records, not the map key.
      final name = records
              .map((r) => r.subject?.name)
              .firstWhere((n) => n != null && n.isNotEmpty, orElse: () => null) ??
          'Subject $key';

      // Newest first.
      records.sort((a, b) {
        final ad = a.date, bd = b.date;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });

      groups.add(SubjectAttendanceGroup(
        subjectId: int.tryParse(key.toString()) ?? records.first.subjectId ?? 0,
        subjectName: name,
        records: records,
      ));
    });

    groups.sort((a, b) => a.subjectName.compareTo(b.subjectName));
    return groups;
  }
}

/// Roll-up across every subject, for the summary header.
class AttendanceSummary {
  final int present;
  final int late;
  final int absent;

  const AttendanceSummary({
    this.present = 0,
    this.late = 0,
    this.absent = 0,
  });

  factory AttendanceSummary.from(List<SubjectAttendanceGroup> groups) {
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
