import '../../core/utils/json_utils.dart';
import 'student_user.dart';

/// Matches an item in `StudentDashboardController@homeworkList`
/// (GET /student/homework).
///
/// {
///   "id": 7, "title": "...", "subject": {...}, "teacher": {...},
///   "description": "...", "assigned_date": "2026-07-01",
///   "due_date": "2026-07-10", "submission_status": "pending",
///   "submitted_at": null, "marks": null, "attachment": null,
///   "is_overdue": false
/// }
class Homework {
  final int id;
  final String title;
  final String? description;
  final NamedRef? subject;
  final NamedRef? teacher;
  final String? assignedDate;
  final String? dueDate;

  /// 'pending' | 'submitted' — as reported by the server.
  final String submissionStatus;
  final DateTime? submittedAt;
  final String? marks;
  final String? attachment;
  final bool isOverdue;

  const Homework({
    required this.id,
    required this.title,
    this.description,
    this.subject,
    this.teacher,
    this.assignedDate,
    this.dueDate,
    this.submissionStatus = 'pending',
    this.submittedAt,
    this.marks,
    this.attachment,
    this.isOverdue = false,
  });

  factory Homework.fromJson(Map<String, dynamic> json) {
    final statusStr = asStringOrNull(json['submission_status']) ??
        asStringOrNull(json['status']) ??
        asStringOrNull(json['assignment_status']);

    final submittedDone = asBool(json['submitted_done']);

    final totalMarkMap = asMap(json['total_mark']);
    final gainedMark = totalMarkMap != null ? asStringOrNull(totalMarkMap['gained_mark']) : null;
    final maxMark = asStringOrNull(json['mark']) ?? asStringOrNull(json['marks']);

    final isSub = submittedDone ||
        totalMarkMap != null ||
        statusStr?.toLowerCase() == 'submitted' ||
        statusStr?.toLowerCase() == 'completed' ||
        statusStr?.toLowerCase() == 'completed assignment' ||
        statusStr?.toLowerCase() == 'submitted assignment';

    final String? markDisplay = (gainedMark != null && maxMark != null)
        ? '$gainedMark / $maxMark'
        : (gainedMark ?? maxMark);

    final remainingDays = asIntOrNull(json['remaining_days']);

    return Homework(
      id: asInt(json['id']),
      title: asString(json['title'], fallback: 'Homework'),
      description: asStringOrNull(json['description']),
      subject: json['subject'] == null
          ? null
          : NamedRef.fromJson(asMap(json['subject']) ?? {}),
      teacher: json['teacher'] == null
          ? null
          : NamedRef.fromJson(asMap(json['teacher']) ?? {}),
      assignedDate: asStringOrNull(json['assigned_date']) ??
          asStringOrNull(json['start_date']) ??
          asStringOrNull(json['issue']),
      dueDate: asStringOrNull(json['due_date']) ??
          asStringOrNull(json['end_date']) ??
          asStringOrNull(json['deadline']),
      submissionStatus: isSub ? 'submitted' : 'pending',
      submittedAt: asDate(json['submitted_at']),
      marks: markDisplay,
      attachment: asStringOrNull(json['attachment']),
      isOverdue: asBool(json['is_overdue']) ||
          (statusStr?.toLowerCase() == 'expired') ||
          (statusStr?.toLowerCase() == 'overdue') ||
          (!isSub && remainingDays != null && remainingDays <= 0),
    );
  }

  bool get isSubmitted => submissionStatus.toLowerCase() == 'submitted';
  bool get isPending => !isSubmitted;
  bool get hasMarks => marks != null && marks!.isNotEmpty;

  DateTime? get dueAt => asDate(dueDate);

  /// Whole days until the due date. Negative when overdue, null when the
  /// backend did not supply a parseable due date.
  int? get daysRemaining {
    final due = dueAt;
    if (due == null) return null;
    final today = DateTime.now();
    final dueDay = DateTime(due.year, due.month, due.day);
    final nowDay = DateTime(today.year, today.month, today.day);
    return dueDay.difference(nowDay).inDays;
  }

  /// Short label for the list tile, e.g. "Due in 3 days" / "Overdue".
  String get dueLabel {
    if (isSubmitted) return 'Submitted';
    final days = daysRemaining;
    if (days == null) return 'No due date';
    if (days < 0) return 'Overdue';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'Due in $days days';
  }

  /// A homework is only truly overdue if it is still unsubmitted. The
  /// backend already applies that rule, but recompute defensively so a
  /// stale `is_overdue` can't mislabel a submitted item.
  bool get showAsOverdue => isPending && (isOverdue || (daysRemaining ?? 0) < 0);
}

/// A single past submission, from `submission_history` in
/// `StudentDashboardController@homeworkDetails`.
class HomeworkSubmission {
  final DateTime? submittedAt;
  final String? text;
  final String? audioUrl;

  const HomeworkSubmission({this.submittedAt, this.text, this.audioUrl});

  factory HomeworkSubmission.fromJson(Map<String, dynamic> json) =>
      HomeworkSubmission(
        submittedAt: asDate(json['submitted_at']),
        text: asStringOrNull(json['submitted_text']),
        audioUrl: asStringOrNull(json['submitted_audio']),
      );
}

/// Matches `StudentDashboardController@homeworkDetails`
/// (GET /student/homework/{id}).
class HomeworkDetail {
  final int id;
  final String title;
  final String? description;
  final String? instructions;
  final NamedRef? subject;
  final NamedRef? teacher;
  final String? assignedDate;
  final String? dueDate;
  final String submissionStatus;
  final String? submittedText;
  final String? submittedAudio;
  final String? marks;
  final String? teacherRemarks;
  final List<String> attachments;
  final List<HomeworkSubmission> history;

  const HomeworkDetail({
    required this.id,
    required this.title,
    this.description,
    this.instructions,
    this.subject,
    this.teacher,
    this.assignedDate,
    this.dueDate,
    this.submissionStatus = 'pending',
    this.submittedText,
    this.submittedAudio,
    this.marks,
    this.teacherRemarks,
    this.attachments = const [],
    this.history = const [],
  });

  factory HomeworkDetail.fromJson(Map<String, dynamic> json) {
    final statusStr = asStringOrNull(json['submission_status']) ??
        asStringOrNull(json['status']) ??
        asStringOrNull(json['assignment_status']);

    final submittedDone = asBool(json['submitted_done']);
    final submissions = asDouble(json['submissions']);
    final isSub = submittedDone ||
        submissions > 0 ||
        statusStr?.toLowerCase() == 'submitted' ||
        statusStr?.toLowerCase() == 'completed' ||
        statusStr?.toLowerCase() == 'submitted assignment';

    final markVal = json['marks'] ?? json['mark'] ?? json['total_mark'];

    return HomeworkDetail(
      id: asInt(json['id']),
      title: asString(json['title'], fallback: 'Homework'),
      description: asStringOrNull(json['description']),
      instructions: asStringOrNull(json['instructions']),
      subject: json['subject'] == null
          ? null
          : NamedRef.fromJson(asMap(json['subject']) ?? {}),
      teacher: json['teacher'] == null
          ? null
          : NamedRef.fromJson(asMap(json['teacher']) ?? {}),
      assignedDate: asStringOrNull(json['assigned_date']) ??
          asStringOrNull(json['start_date']) ??
          asStringOrNull(json['issue']),
      dueDate: asStringOrNull(json['due_date']) ??
          asStringOrNull(json['end_date']) ??
          asStringOrNull(json['deadline']),
      submissionStatus: isSub ? 'submitted' : 'pending',
      submittedText: asStringOrNull(json['submitted_text']),
      submittedAudio: asStringOrNull(json['submitted_audio']),
      marks: markVal?.toString(),
      teacherRemarks: asStringOrNull(json['teacher_remarks']),
      attachments: _parseAttachments(json['attachments']),
      history: asList(json['submission_history'], HomeworkSubmission.fromJson),
    );
  }

  bool get isSubmitted => submissionStatus.toLowerCase() == 'submitted';
  bool get isPending => !isSubmitted;
  bool get hasMarks => marks != null && marks!.isNotEmpty;

  /// The body text to show. `instructions` is currently just a copy of
  /// `description` on the backend, so prefer description and only fall
  /// back to instructions if description is missing.
  String? get body =>
      (description != null && description!.isNotEmpty) ? description : instructions;

  /// The detail endpoint returns `attachments` as a **map**
  /// (`{"assignment_url": "..."}`) rather than the list the list-endpoint
  /// implies, and as `null` when nothing was submitted. Handle all three.
  static List<String> _parseAttachments(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (raw is Map) {
      return raw.values
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
