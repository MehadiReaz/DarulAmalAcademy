import '../../core/utils/json_utils.dart';
import 'student_user.dart';

/// Matches an item in `StudentDashboardController@homeworkList`
/// or `assignments` endpoint.
class Homework {
  final int id;
  final String title;
  final String? description;
  final NamedRef? course;
  final NamedRef? batch;
  final NamedRef? subject;
  final NamedRef? teacher;
  final String? assignedDate;
  final String? dueDate;

  /// Raw server status e.g. "Due", "Expired", "Completed".
  final String status;

  /// "Ongoing Assignment" | "Completed Assignment"
  final String? assignmentStatus;

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
    this.course,
    this.batch,
    this.subject,
    this.teacher,
    this.assignedDate,
    this.dueDate,
    this.status = 'Due',
    this.assignmentStatus,
    this.submissionStatus = 'pending',
    this.submittedAt,
    this.marks,
    this.attachment,
    this.isOverdue = false,
  });

  factory Homework.fromJson(Map<String, dynamic> json) {
    final statusStr = asStringOrNull(json['status']) ??
        asStringOrNull(json['submission_status']) ??
        asStringOrNull(json['assignment_status']);

    final assignStatus = asStringOrNull(json['assignment_status']);

    final submittedDone = asBool(json['submitted_done']);
    final isSubmittedFlag = asBool(json['is_submitted']) ||
        (json['submitted'] is bool && json['submitted'] == true);
    final hasSubmittedContent = json['submitted_at'] != null ||
        json['submitted_text'] != null ||
        json['submitted_audio'] != null;
    final hasHistory = (json['submission_history'] is List && (json['submission_history'] as List).isNotEmpty) ||
        (json['history'] is List && (json['history'] as List).isNotEmpty) ||
        (json['submitted'] is List && (json['submitted'] as List).isNotEmpty);

    final totalMarkMap = asMap(json['total_mark']);
    final gainedMark = totalMarkMap != null ? asStringOrNull(totalMarkMap['gained_mark']) : null;
    final maxMark = asStringOrNull(json['mark']) ?? asStringOrNull(json['marks']);

    final isSub = submittedDone ||
        isSubmittedFlag ||
        hasSubmittedContent ||
        hasHistory ||
        totalMarkMap != null ||
        statusStr?.toLowerCase() == 'submitted' ||
        statusStr?.toLowerCase() == 'completed' ||
        statusStr?.toLowerCase() == 'completed assignment' ||
        statusStr?.toLowerCase() == 'submitted assignment';

    final String? markDisplay = (gainedMark != null && maxMark != null)
        ? '$gainedMark / $maxMark'
        : (gainedMark ?? maxMark);

    final remainingDays = asIntOrNull(json['remaining_days']);

    final NamedRef? parsedCourse = json['course'] != null
        ? NamedRef.fromJson(asMap(json['course']) ?? {})
        : (json['class'] != null
            ? NamedRef.fromJson(asMap(json['class']) ?? {})
            : (json['course_name'] != null
                ? NamedRef(id: asInt(json['course_id']), name: asString(json['course_name']))
                : null));

    final NamedRef? parsedBatch = json['batch'] != null
        ? NamedRef.fromJson(asMap(json['batch']) ?? {})
        : (json['batch_name'] != null
            ? NamedRef(id: asInt(json['batch_id']), name: asString(json['batch_name']))
            : null);

    final resolvedStatus = statusStr != null && statusStr.isNotEmpty
        ? statusStr
        : (isSub ? 'Completed' : 'Due');

    return Homework(
      id: asInt(json['id']),
      title: asString(json['title'], fallback: 'Homework'),
      description: asStringOrNull(json['description']),
      course: parsedCourse,
      batch: parsedBatch,
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
          asStringOrNull(json['deadline']) ??
          asStringOrNull(json['end_date']),
      status: resolvedStatus,
      assignmentStatus: assignStatus,
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

  String get courseDisplayName {
    if (course?.name != null && course!.name!.trim().isNotEmpty) {
      return course!.name!.trim();
    }
    if (subject?.name != null && subject!.name!.trim().isNotEmpty) {
      return subject!.name!.trim();
    }
    return 'Nurani';
  }

  String get batchDisplayName {
    if (batch?.name != null && batch!.name!.trim().isNotEmpty) {
      return batch!.name!.trim();
    }
    final cName = courseDisplayName;
    return '$cName - Evening Batch';
  }

  String get formattedDueDate {
    if (dueDate == null || dueDate!.trim().isEmpty) return '—';
    final trimmed = dueDate!.trim();
    if (RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(trimmed)) return trimmed;
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      final d = parsed.day.toString().padLeft(2, '0');
      final m = parsed.month.toString().padLeft(2, '0');
      final y = parsed.year.toString();
      return '$d-$m-$y';
    }
    return trimmed;
  }

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

  /// A homework is only truly overdue if it is still unsubmitted.
  bool get showAsOverdue => isPending && (isOverdue || (daysRemaining ?? 0) < 0);
}

/// A single past submission item, e.g. from `submitted` list or
/// `submission_history` in `StudentDashboardController@homeworkDetails`.
class HomeworkSubmission {
  final int? id;
  final String? studentName;
  final String? studentRoll;
  final String? studentPhoto;
  final String? fileUrl;
  final String? text;
  final String? mark;
  final String? status;
  final DateTime? submittedAt;

  const HomeworkSubmission({
    this.id,
    this.studentName,
    this.studentRoll,
    this.studentPhoto,
    this.fileUrl,
    this.text,
    this.mark,
    this.status,
    this.submittedAt,
  });

  /// Backward-compatible alias for existing audio/file consumers.
  String? get audioUrl => fileUrl;

  factory HomeworkSubmission.fromJson(Map<String, dynamic> json) {
    final userMap = asMap(json['student']) ?? asMap(json['user']);
    final file = asStringOrNull(json['assignment_url']) ??
        asStringOrNull(json['assignment']) ??
        asStringOrNull(json['file_url']) ??
        asStringOrNull(json['file']) ??
        asStringOrNull(json['submitted_audio']);

    final markVal = asStringOrNull(json['gained_mark']) ??
        asStringOrNull(json['mark']) ??
        asStringOrNull(json['marks']);

    final isCompleted = json['completed'] == '1' ||
        json['completed'] == 1 ||
        json['completed'] == true ||
        asStringOrNull(json['status'])?.toLowerCase() == 'completed';

    return HomeworkSubmission(
      id: asIntOrNull(json['id']),
      studentName: userMap != null
          ? asStringOrNull(userMap['name'])
          : asStringOrNull(json['student_name']),
      studentRoll: userMap != null
          ? (asStringOrNull(userMap['roll_no']) ??
              asStringOrNull(userMap['roll']) ??
              asStringOrNull(userMap['student_id']))
          : (asStringOrNull(json['roll_no']) ??
              asStringOrNull(json['roll']) ??
              asStringOrNull(json['student_id'])),
      studentPhoto: userMap != null
          ? asStringOrNull(userMap['profile_photo_url'])
          : asStringOrNull(json['profile_photo_url']),
      fileUrl: file,
      text: asStringOrNull(json['description']) ??
          asStringOrNull(json['submitted_text']) ??
          asStringOrNull(json['text']),
      mark: markVal,
      status: isCompleted ? 'Completed' : (asStringOrNull(json['status']) ?? 'Submitted'),
      submittedAt: asDate(json['submitted_at']) ?? asDate(json['created_at']),
    );
  }
}

/// Matches `StudentDashboardController@homeworkDetails`
/// (GET /student/homework/{id}).
class HomeworkDetail {
  final int id;
  final String title;
  final String? description;
  final String? instructions;
  final NamedRef? course;
  final NamedRef? batch;
  final NamedRef? subject;
  final NamedRef? teacher;
  final String? assignedDate;
  final String? dueDate;
  final String status;
  final String? assignmentStatus;
  final String submissionStatus;
  final String? submittedText;
  final String? submittedAudio;
  final String? marks;
  final String? teacherRemarks;
  final List<String> attachments;
  final List<HomeworkSubmission> history;
  final List<HomeworkSubmission> submissions;

  const HomeworkDetail({
    required this.id,
    required this.title,
    this.description,
    this.instructions,
    this.course,
    this.batch,
    this.subject,
    this.teacher,
    this.assignedDate,
    this.dueDate,
    this.status = 'Due',
    this.assignmentStatus,
    this.submissionStatus = 'pending',
    this.submittedText,
    this.submittedAudio,
    this.marks,
    this.teacherRemarks,
    this.attachments = const [],
    this.history = const [],
    this.submissions = const [],
  });

  factory HomeworkDetail.fromJson(Map<String, dynamic> json) {
    final statusStr = asStringOrNull(json['status']) ??
        asStringOrNull(json['submission_status']) ??
        asStringOrNull(json['assignment_status']);

    final assignStatus = asStringOrNull(json['assignment_status']);

    dynamic rawHistory = json['submission_history'] ??
        json['history'] ??
        (asMap(json['submissions_list'])?['data']) ??
        json['submissions_list'];
    final historyList = asList(rawHistory, HomeworkSubmission.fromJson);

    dynamic rawSubmitted = json['submitted'] ??
        (asMap(json['submissions_list'])?['data']) ??
        json['submissions_list'] ??
        rawHistory;
    final submittedList = asList(rawSubmitted, HomeworkSubmission.fromJson);

    final submittedDone = asBool(json['submitted_done']);
    final submissionsCount = asDouble(json['submissions']);
    final subAudio = asStringOrNull(json['submitted_audio']) ??
        asStringOrNull(json['assignment_url']) ??
        (historyList.isNotEmpty ? historyList.first.audioUrl : null);
    final hasSubmittedContent = json['submitted_text'] != null || subAudio != null;
    final isSubmittedFlag = asBool(json['is_submitted']) ||
        (json['submitted'] is bool && json['submitted'] == true);

    final isSub = submittedDone ||
        isSubmittedFlag ||
        submissionsCount > 0 ||
        hasSubmittedContent ||
        historyList.isNotEmpty ||
        submittedList.isNotEmpty ||
        statusStr?.toLowerCase() == 'submitted' ||
        statusStr?.toLowerCase() == 'completed' ||
        statusStr?.toLowerCase() == 'submitted assignment';

    final markVal = json['marks'] ?? json['mark'] ?? json['total_mark'];

    final NamedRef? parsedCourse = json['course'] != null
        ? NamedRef.fromJson(asMap(json['course']) ?? {})
        : (json['class'] != null
            ? NamedRef.fromJson(asMap(json['class']) ?? {})
            : (json['course_name'] != null
                ? NamedRef(id: asInt(json['course_id']), name: asString(json['course_name']))
                : null));

    final NamedRef? parsedBatch = json['batch'] != null
        ? NamedRef.fromJson(asMap(json['batch']) ?? {})
        : (json['batch_name'] != null
            ? NamedRef(id: asInt(json['batch_id']), name: asString(json['batch_name']))
            : null);

    final resolvedStatus = statusStr != null && statusStr.isNotEmpty
        ? statusStr
        : (isSub ? 'Completed' : 'Due');

    return HomeworkDetail(
      id: asInt(json['id']),
      title: asString(json['title'], fallback: 'Homework'),
      description: asStringOrNull(json['description']),
      instructions: asStringOrNull(json['instructions']),
      course: parsedCourse,
      batch: parsedBatch,
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
          asStringOrNull(json['deadline']) ??
          asStringOrNull(json['end_date']),
      status: resolvedStatus,
      assignmentStatus: assignStatus,
      submissionStatus: isSub ? 'submitted' : 'pending',
      submittedText: asStringOrNull(json['submitted_text']) ??
          (historyList.isNotEmpty ? historyList.first.text : null),
      submittedAudio: subAudio,
      marks: markVal?.toString(),
      teacherRemarks: asStringOrNull(json['teacher_remarks']),
      attachments: _parseAttachments(json['attachments']),
      history: historyList,
      submissions: submittedList.isNotEmpty ? submittedList : historyList,
    );
  }

  bool get isSubmitted => submissionStatus.toLowerCase() == 'submitted';
  bool get isPending => !isSubmitted;
  bool get hasMarks => marks != null && marks!.isNotEmpty;

  String get courseDisplayName {
    if (course?.name != null && course!.name!.trim().isNotEmpty) {
      return course!.name!.trim();
    }
    if (subject?.name != null && subject!.name!.trim().isNotEmpty) {
      return subject!.name!.trim();
    }
    return 'Nurani';
  }

  String get batchDisplayName {
    if (batch?.name != null && batch!.name!.trim().isNotEmpty) {
      return batch!.name!.trim();
    }
    final cName = courseDisplayName;
    return '$cName - Evening Batch';
  }

  String get formattedDueDate {
    if (dueDate == null || dueDate!.trim().isEmpty) return '—';
    final trimmed = dueDate!.trim();
    if (RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(trimmed)) return trimmed;
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      final d = parsed.day.toString().padLeft(2, '0');
      final m = parsed.month.toString().padLeft(2, '0');
      final y = parsed.year.toString();
      return '$d-$m-$y';
    }
    return trimmed;
  }

  /// Prefer description and fall back to instructions.
  String? get body =>
      (description != null && description!.isNotEmpty) ? description : instructions;

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
