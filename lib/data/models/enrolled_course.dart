import '../../core/utils/json_utils.dart';
import 'student_user.dart';

/// One course from `GET /api/student/courses`.
///
/// The endpoint returns flat course objects with the student's batches for
/// that course nested inside:
/// `{id, name, image_url, primary_batch_id, duration, batches: [...]}`.
/// Course details and tabs are addressed by *batch* id, never course id.
class EnrolledCourse {
  final int id;
  final String name;
  final String? slug;
  final String? description;
  final String? imageUrl;
  final int? primaryBatchId;
  final String? enrolledDate;

  /// Pre-formatted by the server, e.g. "6 months".
  final String? duration;
  final int studentsCount;
  final List<CourseBatch> batches;

  const EnrolledCourse({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    this.imageUrl,
    this.primaryBatchId,
    this.enrolledDate,
    this.duration,
    this.studentsCount = 0,
    this.batches = const [],
  });

  factory EnrolledCourse.fromJson(Map<String, dynamic> json) {
    return EnrolledCourse(
      id: asInt(json['id']),
      name: asString(json['name'], fallback: 'Course'),
      slug: asStringOrNull(json['slug']),
      description: asStringOrNull(json['description']),
      imageUrl: asStringOrNull(json['image_url']),
      primaryBatchId: asIntOrNull(json['primary_batch_id']),
      enrolledDate: asStringOrNull(json['enrolled_date']),
      duration: asStringOrNull(json['duration']),
      studentsCount: asInt(json['students_count']),
      batches: asList(json['batches'], CourseBatch.fromJson),
    );
  }

  /// The batch the course card opens: the server's primary batch, else
  /// the first one listed.
  CourseBatch? get primaryBatch {
    for (final b in batches) {
      if (b.id == primaryBatchId) return b;
    }
    return batches.isEmpty ? null : batches.first;
  }

  /// Batch id for `/student/courses/{batchId}`, or null if the student
  /// has no batch in this course.
  int? get batchId => primaryBatchId ?? primaryBatch?.id;
}

/// A batch as it appears inside `/courses` (`time`), `/batches` and the
/// course-tab `selected_batch` (`formatted_time`, `days`).
class CourseBatch {
  final int id;
  final String? name;

  /// e.g. "06:00 PM - 07:30 PM".
  final String? time;
  final List<String> days;
  final NamedRef? teacher;

  const CourseBatch({
    required this.id,
    this.name,
    this.time,
    this.days = const [],
    this.teacher,
  });

  factory CourseBatch.fromJson(Map<String, dynamic> json) {
    final teacher = asMap(json['teacher']);
    final days = json['days'];
    return CourseBatch(
      id: asInt(json['id']),
      name: asStringOrNull(json['name']),
      time: asStringOrNull(json['time'] ?? json['formatted_time']),
      days: days is List
          ? days.map((d) => d.toString()).where((d) => d.isNotEmpty).toList()
          : const [],
      teacher: teacher == null ? null : NamedRef.fromJson(teacher),
    );
  }

  /// "Saturday, Monday, Wednesday · 06:00 PM - 07:30 PM", or whichever
  /// half is known; null when neither is.
  String? get schedule {
    final parts = [
      if (days.isNotEmpty) days.join(', '),
      ?time,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
