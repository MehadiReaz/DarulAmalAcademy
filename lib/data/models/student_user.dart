import '../../core/utils/json_utils.dart';

/// Matches `formatStudentData()` / `formatUserData()` in
/// ApiStudentOtpController + StudentLoginController.
///
/// {
///   "id": 12, "name": "...", "email": "...", "role": "Student",
///   "profile_photo_url": "...", "student_id": "...", "roll_no": "...",
///   "class": { "id": 1, "name": "..." },
///   "courses": [ { "id": 3, "name": "..." } ]
/// }
class StudentUser {
  final int id;
  final String name;
  final String? email;
  final String? role;
  final String? profilePhotoUrl;
  final String? studentId;
  final String? rollNo;
  final NamedRef? studentClass;
  final List<NamedRef> courses;

  const StudentUser({
    required this.id,
    required this.name,
    this.email,
    this.role,
    this.profilePhotoUrl,
    this.studentId,
    this.rollNo,
    this.studentClass,
    this.courses = const [],
  });

  factory StudentUser.fromJson(Map<String, dynamic> json) {
    return StudentUser(
      id: asInt(json['id']),
      name: asString(json['name'], fallback: 'Student'),
      email: asStringOrNull(json['email']),
      role: asStringOrNull(json['role']),
      profilePhotoUrl: asStringOrNull(json['profile_photo_url']),
      studentId: asStringOrNull(json['student_id']),
      rollNo: asStringOrNull(json['roll_no']),
      studentClass: json['class'] == null
          ? null
          : NamedRef.fromJson(asMap(json['class']) ?? {}),
      courses: asList(json['courses'], NamedRef.fromJson),
    );
  }

  /// Used to cache the profile locally.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'profile_photo_url': profilePhotoUrl,
        'student_id': studentId,
        'roll_no': rollNo,
        'class': studentClass?.toJson(),
        'courses': courses.map((c) => c.toJson()).toList(),
      };

  bool get isStudent => role?.toLowerCase() == 'student';

  String get className => studentClass?.name ?? '—';
}

/// Reusable { id, name } shape used all over the API.
class NamedRef {
  final int? id;
  final String? name;

  const NamedRef({this.id, this.name});

  factory NamedRef.fromJson(Map<String, dynamic> json) => NamedRef(
        id: asIntOrNull(json['id']),
        name: asStringOrNull(json['name']),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  String get display => name ?? '—';
}
