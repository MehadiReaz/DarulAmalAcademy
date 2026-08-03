import '../../core/utils/json_utils.dart';
import 'student_user.dart';

/// Matches `StudentLoginController@dashboard` (GET /student/dashboard).
///
/// The endpoint returns considerably more than the home screen used to
/// read — upcoming assignments, exams, events, a subject-by-subject
/// attendance breakdown and a 12-month fee chart were all being thrown
/// away. Everything is parsed here so screens can use it without another
/// round trip; unused fields cost nothing.
class DashboardData {
  final QuickStats quickStats;

  // Dues
  final bool isDue;
  final double dueAmount;
  final double totalAmount;
  final double totalDueAmount;
  final int pendingFeesCount;

  // Today
  final List<DashboardClass> todayClasses;

  // Assignments
  final int totalAssignments;
  final int totalSubmittedAssignments;
  final int totalRemainingAssignments;
  final int pendingAssignmentsCount;
  final List<DashboardAssignment> nextAssignments;

  // Attendance
  final int presentClasses;
  final int lateClasses;
  final int absentClasses;
  final List<SubjectAttendance> attendanceBySubject;

  // Calendar
  final List<DashboardExam> upcomingExams;
  final List<DashboardEvent> upcomingEvents;
  final int upcomingEventsCount;
  final int upcomingClassesCount;

  // Misc
  final List<String> courseNames;
  final int totalStudents;

  /// Month numbers ("01".."12") and the fee total charged in each.
  final List<String> chartLabels;
  final List<double> chartValues;

  const DashboardData({
    required this.quickStats,
    this.isDue = false,
    this.dueAmount = 0,
    this.totalAmount = 0,
    this.totalDueAmount = 0,
    this.pendingFeesCount = 0,
    this.todayClasses = const [],
    this.totalAssignments = 0,
    this.totalSubmittedAssignments = 0,
    this.totalRemainingAssignments = 0,
    this.pendingAssignmentsCount = 0,
    this.nextAssignments = const [],
    this.presentClasses = 0,
    this.lateClasses = 0,
    this.absentClasses = 0,
    this.attendanceBySubject = const [],
    this.upcomingExams = const [],
    this.upcomingEvents = const [],
    this.upcomingEventsCount = 0,
    this.upcomingClassesCount = 0,
    this.courseNames = const [],
    this.totalStudents = 0,
    this.chartLabels = const [],
    this.chartValues = const [],
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      quickStats: QuickStats.fromJson(asMap(json['quick_stats']) ?? {}),
      isDue: asBool(json['is_due']),
      dueAmount: asDouble(json['due_amount']),
      totalAmount: asDouble(json['total_amount']),
      totalDueAmount: asDouble(json['total_due_amount']),
      pendingFeesCount: asInt(json['pending_fees']),
      todayClasses: asList(json['today_classes'], DashboardClass.fromJson),
      totalAssignments: asInt(json['total_assignments']),
      totalSubmittedAssignments: asInt(json['total_submitted_assignments']),
      totalRemainingAssignments: asInt(json['total_remaining_assignments']),
      pendingAssignmentsCount: asInt(json['pending_assignments']),
      nextAssignments:
          asList(json['next_assignments'], DashboardAssignment.fromJson),
      presentClasses: asInt(json['present_classes']),
      lateClasses: asInt(json['late_classes']),
      absentClasses: asInt(json['absent_classes']),
      attendanceBySubject:
          asList(json['attendance_arr'], SubjectAttendance.fromJson),
      upcomingExams: asList(json['upcoming_exams'], DashboardExam.fromJson),
      upcomingEvents:
          asList(json['upcoming_events'], DashboardEvent.fromJson),
      upcomingEventsCount: asInt(json['upcoming_events_count']),
      upcomingClassesCount: asInt(json['upcoming_classes_count']),
      courseNames: _stringList(json['user_courses_name']),
      totalStudents: asInt(json['total_students']),
      chartLabels: _stringList(json['this_year_labels']),
      chartValues: _doubleList(json['this_year_values']),
    );
  }

  double get paidAmount {
    final paid = totalAmount - totalDueAmount;
    return paid < 0 ? 0 : paid;
  }

  int get totalAttendanceRecords =>
      presentClasses + lateClasses + absentClasses;

  static List<String> _stringList(dynamic v) {
    if (v is! List) return const [];
    return v
        .map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static List<double> _doubleList(dynamic v) {
    if (v is! List) return const [];
    return v.map(asDouble).toList();
  }
}

class QuickStats {
  final int totalCourses;
  final int todayClasses;
  final int attendancePercentage;
  final int pendingAssignments;

  const QuickStats({
    this.totalCourses = 0,
    this.todayClasses = 0,
    this.attendancePercentage = 0,
    this.pendingAssignments = 0,
  });

  factory QuickStats.fromJson(Map<String, dynamic> json) => QuickStats(
        totalCourses: asInt(json['total_courses']),
        todayClasses: asInt(json['today_classes']),
        attendancePercentage: asInt(json['attendance_percentage']),
        pendingAssignments: asInt(json['pending_assignments']),
      );
}

/// A class entry from the dashboard's `today_classes` array.
///
/// Times arrive pre-formatted ("9:00 AM"), unlike `/student/classes/today`
/// which sends raw "21:00:00" — so these are displayed as-is.
class DashboardClass {
  final int id;
  final String title;
  final String startTime;
  final String endTime;
  final String status; // 'upcoming', 'ongoing', 'completed'

  const DashboardClass({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  factory DashboardClass.fromJson(Map<String, dynamic> json) => DashboardClass(
        id: asInt(json['id']),
        title: asString(json['title'], fallback: 'Class'),
        startTime: asString(json['start_time']),
        endTime: asString(json['end_time']),
        status: asString(json['status'], fallback: 'upcoming'),
      );

  bool get isOngoing => status == 'ongoing';
  bool get isUpcoming => status == 'upcoming';
  bool get isCompleted => status == 'completed';
}

/// An entry from `next_assignments`.
class DashboardAssignment {
  final int id;
  final String title;
  final String? startDate;
  final String? endDate;
  final String? status;
  final int? remainingDays;
  final NamedRef? subject;
  final NamedRef? teacher;
  final NamedRef? studentClass;

  const DashboardAssignment({
    required this.id,
    required this.title,
    this.startDate,
    this.endDate,
    this.status,
    this.remainingDays,
    this.subject,
    this.teacher,
    this.studentClass,
  });

  factory DashboardAssignment.fromJson(Map<String, dynamic> json) =>
      DashboardAssignment(
        id: asInt(json['id']),
        title: asString(json['title'], fallback: 'Assignment'),
        startDate: asStringOrNull(json['start_date']),
        endDate: asStringOrNull(json['end_date']),
        status: asStringOrNull(json['status']),
        remainingDays: asIntOrNull(json['remaining_days']),
        subject: json['subject'] == null
            ? null
            : NamedRef.fromJson(asMap(json['subject']) ?? {}),
        teacher: json['teacher'] == null
            ? null
            : NamedRef.fromJson(asMap(json['teacher']) ?? {}),
        studentClass: json['class'] == null
            ? null
            : NamedRef.fromJson(asMap(json['class']) ?? {}),
      );
}

/// An entry from `upcoming_exams`.
class DashboardExam {
  final int id;
  final String title;
  final String? startDate;
  final String? endDate;
  final NamedRef? course;

  const DashboardExam({
    required this.id,
    required this.title,
    this.startDate,
    this.endDate,
    this.course,
  });

  factory DashboardExam.fromJson(Map<String, dynamic> json) => DashboardExam(
        id: asInt(json['id']),
        title: asString(json['title'], fallback: 'Exam'),
        startDate: asStringOrNull(json['start_date']),
        endDate: asStringOrNull(json['end_date']),
        course: json['course'] == null
            ? null
            : NamedRef.fromJson(asMap(json['course']) ?? {}),
      );

  DateTime? get startsAt => asDate(startDate);
}

/// An entry from `upcoming_events`.
class DashboardEvent {
  final int id;
  final String title;
  final String? start;
  final String? end;
  final String? location;
  final String? status;
  final int? remainingDays;

  const DashboardEvent({
    required this.id,
    required this.title,
    this.start,
    this.end,
    this.location,
    this.status,
    this.remainingDays,
  });

  factory DashboardEvent.fromJson(Map<String, dynamic> json) => DashboardEvent(
        id: asInt(json['id']),
        title: asString(json['title'], fallback: 'Event'),
        start: asStringOrNull(json['start']),
        end: asStringOrNull(json['end']),
        location: asStringOrNull(json['location']),
        status: asStringOrNull(json['status']),
        remainingDays: asIntOrNull(json['remaining_days']),
      );

  DateTime? get startsAt => asDate(start);
}

/// An entry from `attendance_arr` — one row per subject.
class SubjectAttendance {
  final int? subjectId;
  final String subjectName;
  final int totalClasses;
  final int presentClasses;

  /// Already a 0–100 percentage on the wire.
  final double presentScore;
  final String? teacherName;

  const SubjectAttendance({
    this.subjectId,
    this.subjectName = '',
    this.totalClasses = 0,
    this.presentClasses = 0,
    this.presentScore = 0,
    this.teacherName,
  });

  factory SubjectAttendance.fromJson(Map<String, dynamic> json) =>
      SubjectAttendance(
        subjectId: asIntOrNull(json['subject_id']),
        subjectName: asString(json['subject_name'], fallback: 'Subject'),
        totalClasses: asInt(json['total_classes']),
        presentClasses: asInt(json['total_present_classes']),
        presentScore: asDouble(json['present_score']),
        teacherName: asStringOrNull(json['teacher']),
      );

  /// Clamped 0.0–1.0 for LinearProgressIndicator.
  double get fraction {
    final v = presentScore / 100.0;
    if (v.isNaN) return 0;
    return v.clamp(0.0, 1.0);
  }
}
