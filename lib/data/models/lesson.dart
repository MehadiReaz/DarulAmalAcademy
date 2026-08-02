import '../../core/utils/json_utils.dart';

/// A row from `GET /student/my-lessons` — the lesson plans / material a
/// teacher has published to the student's batch.
///
/// This mirrors the teacher-side `teacher/lessons` payload (title,
/// description, subject, class, date, attachment), read through the same
/// defensive helpers used everywhere else so a renamed key degrades to a
/// missing line rather than a crash.
class Lesson {
  final int id;
  final String title;
  final String? description;
  final String? subject;
  final String? className;
  final String? teacher;

  /// Free-form date string from the server (`lesson_date`, `date`, or
  /// `created_at`), already parsed where possible.
  final DateTime? date;

  /// Absolute URL to the attached file, when one exists.
  final String? attachment;

  /// Youtube/Drive/any link the teacher pinned to the lesson.
  final String? link;

  const Lesson({
    required this.id,
    required this.title,
    this.description,
    this.subject,
    this.className,
    this.teacher,
    this.date,
    this.attachment,
    this.link,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    // Relations may arrive nested (`subject: { name }`) or flattened
    // (`subject_name`), depending on whether the controller uses a
    // resource class.
    String? nested(String key, List<String> fields) {
      final map = asMap(json[key]);
      if (map == null) return null;
      for (final f in fields) {
        final v = asStringOrNull(map[f]);
        if (v != null) return v;
      }
      return null;
    }

    return Lesson(
      id: asInt(json['id']),
      title: asString(
        json['title'] ?? json['name'] ?? json['topic'],
        fallback: 'Lesson',
      ),
      description: asStringOrNull(json['description'] ?? json['details']),
      subject: asStringOrNull(json['subject_name']) ??
          nested('subject', ['name', 'title']),
      className: asStringOrNull(json['class_name'] ?? json['batch_name']) ??
          nested('course', ['name', 'title']) ??
          nested('batch', ['name', 'title']),
      teacher: asStringOrNull(json['teacher_name']) ??
          nested('teacher', ['name']),
      date: asDate(json['lesson_date'] ?? json['date'] ?? json['created_at']),
      attachment: asStringOrNull(
        json['attachment'] ?? json['file'] ?? json['file_url'],
      ),
      link: asStringOrNull(json['link'] ?? json['url'] ?? json['video_url']),
    );
  }

  bool get hasAttachment => (attachment ?? '').isNotEmpty;
  bool get hasLink => (link ?? '').isNotEmpty;
}
