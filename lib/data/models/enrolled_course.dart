import '../../core/utils/json_utils.dart';
import 'student_user.dart';

/// Matches `StudentMyClassController@myCourses`.
///
/// The controller returns the *enrollment* records (`$user->courses()`), each
/// with the `course` relation loaded plus an appended `total_students`.
/// Field names on the pivot are not guaranteed, so everything is optional.
class EnrolledCourse {
  final int? id;
  final int? courseId;
  final int totalStudents;
  final CourseDetail? course;

  const EnrolledCourse({
    this.id,
    this.courseId,
    this.totalStudents = 0,
    this.course,
  });

  factory EnrolledCourse.fromJson(Map<String, dynamic> json) {
    return EnrolledCourse(
      id: asIntOrNull(json['id']),
      courseId: asIntOrNull(json['course_id']),
      totalStudents: asInt(json['total_students']),
      course: json['course'] == null
          ? null
          : CourseDetail.fromJson(asMap(json['course']) ?? {}),
    );
  }

  String get name => course?.name ?? 'Course';
  List<NamedRef> get subjects => course?.subjects ?? const [];
}

class CourseDetail {
  final int? id;
  final String? name;
  final String? description;
  final String? thumbnail;
  final String? feeType;
  final String? price;
  final String? duration;
  final String? durationType;
  final List<NamedRef> subjects;

  const CourseDetail({
    this.id,
    this.name,
    this.description,
    this.thumbnail,
    this.feeType,
    this.price,
    this.duration,
    this.durationType,
    this.subjects = const [],
  });

  factory CourseDetail.fromJson(Map<String, dynamic> json) => CourseDetail(
        id: asIntOrNull(json['id']),
        name: asStringOrNull(json['name']),
        description: asStringOrNull(json['description']),
        thumbnail: asStringOrNull(json['thumbnail']),
        feeType: asStringOrNull(json['fee_type']),
        price: asStringOrNull(json['price']),
        duration: asStringOrNull(json['duration']),
        durationType: asStringOrNull(json['duration_type']),
        subjects: asList(json['subjects'], NamedRef.fromJson),
      );
}
