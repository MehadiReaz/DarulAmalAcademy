import '../../core/utils/json_utils.dart';
import 'quran_progress.dart';

/// The student profile, parsed from **either** of the two shapes the
/// backend returns.
///
/// The API is not consistent here, and this model absorbs the difference:
///
///  * FLAT — `POST /auth/verify-otp`, `POST /auth/refresh`,
///    `PUT /auth/student/profile` (`formatUserData` / the OTP controller's
///    own `formatStudentData`). `student_id`, `roll_no` and `class` sit at
///    the root of the object.
///
///  * NESTED — `GET /auth/student/profile`
///    (`StudentLoginController@formatStudentData`). The same three fields
///    live under a `profile` object, and the payload additionally carries
///    `phone`, `address`, `gender`, `date_of_birth`, `quran_progress` and
///    `quran_progress_logs`.
///
/// Reading only the flat shape (the previous behaviour) meant every call
/// to `GET /auth/student/profile` silently parsed student ID, roll number
/// and class as null — and `AuthProvider.bootstrap()` then overwrote the
/// good cached copy with the stripped one, so those fields vanished on
/// every app relaunch. Each field below therefore falls back from the
/// root to the nested `profile` block.
class StudentUser {
  final int id;
  final String name;
  final String? email;
  final String? role;
  final String? profilePhotoUrl;

  // Editable account fields — only present in the NESTED shape, which is
  // what makes pre-filling the Edit Profile form possible.
  final String? phone;
  final String? address;
  final String? gender;
  final String? dateOfBirth; // "YYYY-MM-DD"

  // Academic identity — present in both shapes, at different depths.
  final String? studentId;
  final String? rollNo;
  final String? session;
  final String? bloodGroup;
  final NamedRef? studentClass;
  final List<NamedRef> courses;

  // Qur'an — NESTED shape only.
  final QuranProgress? quranProgress;
  final List<QuranProgressLog> quranProgressLogs;

  const StudentUser({
    required this.id,
    required this.name,
    this.email,
    this.role,
    this.profilePhotoUrl,
    this.phone,
    this.address,
    this.gender,
    this.dateOfBirth,
    this.studentId,
    this.rollNo,
    this.session,
    this.bloodGroup,
    this.studentClass,
    this.courses = const [],
    this.quranProgress,
    this.quranProgressLogs = const [],
  });

  factory StudentUser.fromJson(Map<String, dynamic> json) {
    // `profile` is only present in the comprehensive payload. Falling back
    // to an empty map keeps every lookup below safe for the flat shape.
    final profile = asMap(json['profile']) ?? const <String, dynamic>{};

    // Root value wins; the nested profile block is the fallback.
    dynamic pick(String key) => json[key] ?? profile[key];

    final rawClass = asMap(json['class']) ?? asMap(profile['class']);
    final rawQuran = asMap(json['quran_progress']);

    return StudentUser(
      id: asInt(json['id']),
      name: asString(json['name'], fallback: 'Student'),
      email: asStringOrNull(json['email']),
      role: asStringOrNull(json['role']),
      profilePhotoUrl: asStringOrNull(json['profile_photo_url']),
      phone: asStringOrNull(json['phone']),
      address: asStringOrNull(json['address']),
      gender: asStringOrNull(json['gender']),
      dateOfBirth: asStringOrNull(json['date_of_birth']),
      studentId: asStringOrNull(pick('student_id')),
      rollNo: asStringOrNull(pick('roll_no')),
      session: asStringOrNull(pick('session')),
      bloodGroup: asStringOrNull(pick('blood_group')),
      studentClass: rawClass == null ? null : NamedRef.fromJson(rawClass),
      courses: asList(json['courses'], NamedRef.fromJson),
      quranProgress:
          rawQuran == null ? null : QuranProgress.fromJson(rawQuran),
      quranProgressLogs:
          asList(json['quran_progress_logs'], QuranProgressLog.fromJson),
    );
  }

  /// Written to secure storage so the app can render instantly (and
  /// offline) on relaunch.
  ///
  /// This deliberately emits the FLAT shape — the same one `fromJson`
  /// reads first — so a cache round-trip is lossless. Every field the
  /// model holds is written; dropping one here would reintroduce the
  /// original disappearing-profile bug by a different route.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'profile_photo_url': profilePhotoUrl,
        'phone': phone,
        'address': address,
        'gender': gender,
        'date_of_birth': dateOfBirth,
        'student_id': studentId,
        'roll_no': rollNo,
        'session': session,
        'blood_group': bloodGroup,
        'class': studentClass?.toJson(),
        'courses': courses.map((c) => c.toJson()).toList(),
        'quran_progress': quranProgress?.toJson(),
        'quran_progress_logs':
            quranProgressLogs.map((l) => l.toJson()).toList(),
      };

  /// Merges a freshly-fetched profile over the current one, keeping any
  /// field the new payload did not carry.
  ///
  /// `PUT /auth/student/profile` responds with the FLAT shape, which has
  /// no `phone`, `address`, `gender`, `date_of_birth` or Qur'an data — so
  /// applying that response verbatim would blank fields the user can see.
  /// This keeps the old values for anything the server left out.
  StudentUser mergedWith(StudentUser fresh) {
    return StudentUser(
      id: fresh.id != 0 ? fresh.id : id,
      name: fresh.name.isNotEmpty ? fresh.name : name,
      email: fresh.email ?? email,
      role: fresh.role ?? role,
      profilePhotoUrl: fresh.profilePhotoUrl ?? profilePhotoUrl,
      phone: fresh.phone ?? phone,
      address: fresh.address ?? address,
      gender: fresh.gender ?? gender,
      dateOfBirth: fresh.dateOfBirth ?? dateOfBirth,
      studentId: fresh.studentId ?? studentId,
      rollNo: fresh.rollNo ?? rollNo,
      session: fresh.session ?? session,
      bloodGroup: fresh.bloodGroup ?? bloodGroup,
      studentClass: fresh.studentClass ?? studentClass,
      courses: fresh.courses.isNotEmpty ? fresh.courses : courses,
      quranProgress: fresh.quranProgress ?? quranProgress,
      quranProgressLogs: fresh.quranProgressLogs.isNotEmpty
          ? fresh.quranProgressLogs
          : quranProgressLogs,
    );
  }

  bool get isStudent => role?.toLowerCase() == 'student';

  String get className => studentClass?.name ?? '—';

  bool get hasQuranProgress =>
      quranProgress != null && !quranProgress!.isEmpty;
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
