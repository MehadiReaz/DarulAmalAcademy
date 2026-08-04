import '../../core/utils/json_utils.dart';
import 'class_routine.dart';
import 'pagination.dart';
import 'student_user.dart';

class LiveSession {
  final int id;
  final String? classId;
  final String? classUuid;
  final String? hostId;
  final String? hostEmail;
  final String topic;
  final String? description;
  final String? type;
  final String? status;
  final String? startTime;
  final String? timezone;
  final String? startUrl;
  final String? joinUrl;
  final String? password;
  final String? encryptedPassword;
  final dynamic subjectId;
  final dynamic teacherId;
  final dynamic courseId;
  final String? createdAt;
  final String? updatedAt;
  final String? startDateFormat;
  final String? onlineClassStatus;
  final SubjectRef? subject;
  final NamedRef? teacher;
  final NamedRef? course;

  const LiveSession({
    required this.id,
    required this.topic,
    this.classId,
    this.classUuid,
    this.hostId,
    this.hostEmail,
    this.description,
    this.type,
    this.status,
    this.startTime,
    this.timezone,
    this.startUrl,
    this.joinUrl,
    this.password,
    this.encryptedPassword,
    this.subjectId,
    this.teacherId,
    this.courseId,
    this.createdAt,
    this.updatedAt,
    this.startDateFormat,
    this.onlineClassStatus,
    this.subject,
    this.teacher,
    this.course,
  });

  factory LiveSession.fromJson(Map<String, dynamic> json) {
    return LiveSession(
      id: asInt(json['id']),
      topic: asString(json['topic'], fallback: 'Live Class'),
      classId: asStringOrNull(json['class_id']),
      classUuid: asStringOrNull(json['class_uuid']),
      hostId: asStringOrNull(json['host_id']),
      hostEmail: asStringOrNull(json['host_email']),
      description: asStringOrNull(json['description']),
      type: asStringOrNull(json['type']),
      status: asStringOrNull(json['status']),
      startTime: asStringOrNull(json['start_time']),
      timezone: asStringOrNull(json['timezone']),
      startUrl: asStringOrNull(json['start_url']),
      joinUrl: asStringOrNull(json['join_url']),
      password: asStringOrNull(json['password']),
      encryptedPassword: asStringOrNull(json['encrypted_password']),
      subjectId: json['subject_id'],
      teacherId: json['teacher_id'],
      courseId: json['course_id'],
      createdAt: asStringOrNull(json['created_at']),
      updatedAt: asStringOrNull(json['updated_at']),
      startDateFormat: asStringOrNull(json['start_date_format']),
      onlineClassStatus: asStringOrNull(json['online_class_status']),
      subject: json['subject'] == null
          ? null
          : SubjectRef.fromJson(asMap(json['subject']) ?? {}),
      teacher: json['teacher'] == null
          ? null
          : NamedRef.fromJson(asMap(json['teacher']) ?? {}),
      course: json['course'] == null
          ? null
          : NamedRef.fromJson(asMap(json['course']) ?? {}),
    );
  }

  String get subjectName => subject?.name ?? course?.name ?? 'General';
  String get teacherName => teacher?.name ?? 'Instructor';
  String get displayDate => startDateFormat ?? startTime ?? '';
  bool get canJoin => joinUrl != null && joinUrl!.isNotEmpty;
  bool get isLive => (onlineClassStatus?.toLowerCase().contains('live') ?? false) ||
      (status?.toLowerCase() == 'live');
}

class LiveSessionBundle {
  final Map<String, List<LiveSession>> sessionsByCategory;
  final List<LiveSession> allSessions;
  final Pagination pagination;

  const LiveSessionBundle({
    this.sessionsByCategory = const {},
    this.allSessions = const [],
    this.pagination = const Pagination(),
  });

  factory LiveSessionBundle.fromJson(Map<String, dynamic> json) {
    // Response envelope: data -> classes -> { current_page, data: { "Upcoming Class": [...] } }
    final classesBlock = asMap(json['classes']) ?? asMap(json['data']) ?? json;
    final pagination = Pagination.fromJson(classesBlock);
    
    final dataBlock = classesBlock['data'];
    final sessionsByCategory = <String, List<LiveSession>>{};
    final allSessions = <LiveSession>[];

    if (dataBlock is Map) {
      dataBlock.forEach((categoryKey, value) {
        final categoryName = categoryKey.toString();
        final list = asList(value, LiveSession.fromJson);
        sessionsByCategory[categoryName] = list;
        allSessions.addAll(list);
      });
    } else if (dataBlock is List) {
      final list = asList(dataBlock, LiveSession.fromJson);
      allSessions.addAll(list);
      for (final item in list) {
        final cat = item.onlineClassStatus ?? item.status ?? 'All Classes';
        sessionsByCategory.putIfAbsent(cat, () => []).add(item);
      }
    }

    return LiveSessionBundle(
      sessionsByCategory: sessionsByCategory,
      allSessions: allSessions,
      pagination: pagination,
    );
  }

  bool get isEmpty => allSessions.isEmpty;
}
