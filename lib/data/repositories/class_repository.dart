import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/class_routine.dart';
import '../models/enrolled_course.dart';
import '../models/live_session.dart';

class ClassRepository {
  final ApiClient _client;

  ClassRepository(this._client);

  /// GET /api/student/courses
  /// Lists courses derived from active batch assignments.
  Future<List<EnrolledCourse>> myCourses() async {
    final data = await _client.get(ApiEndpoints.studentCourses);
    final map = asMap(data);
    final raw = map == null ? data : (map['courses'] ?? map['data'] ?? data);
    return asList(raw, EnrolledCourse.fromJson);
  }

  /// GET /api/student/courses/{batchId}?tab={tab}
  /// Canonical tabs: details, assignments, online-class, recordings, syllabus, attendance.
  Future<dynamic> courseTab(
    int batchId,
    String tab, {
    int? page,
    int? perPage,
    String? status,
  }) async {
    final query = <String, dynamic>{'tab': tab};
    if (page != null) query['page'] = page;
    if (perPage != null) query['per_page'] = perPage;
    if (status != null) query['status'] = status;

    return await _client.get(
      ApiEndpoints.studentCourseTab(batchId, tab),
      query: query,
    );
  }

  /// GET /api/student/batches
  /// Lists active batch assignments with course, teacher, and schedule info.
  Future<List<Map<String, dynamic>>> myBatches() async {
    final data = await _client.get(ApiEndpoints.studentBatches);
    if (data is! List) return const [];
    return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  /// GET /api/student/schedule
  /// Returns recurring schedule entries only for active batches.
  Future<ClassRoutineBundle> schedule({int page = 1}) async {
    final data = await _client.get(
      ApiEndpoints.studentSchedule,
      query: {'page': page},
    );
    return ClassRoutineBundle.fromJson(asMap(data) ?? {});
  }

  /// GET /api/student/class/today
  /// Returns active-batch schedule entries occurring today.
  Future<List<ClassRoutine>> today() async {
    final data = await _client.get(ApiEndpoints.studentClassToday);
    return _routines(data);
  }

  /// GET /api/student/class/upcoming
  /// Returns active-batch schedule entries with next occurrence date.
  Future<List<ClassRoutine>> upcoming() async {
    final data = await _client.get(ApiEndpoints.studentClassUpcoming);
    return _routines(data);
  }

  List<ClassRoutine> _routines(dynamic data) {
    final map = asMap(data);
    final raw = map == null
        ? data
        : (map['classes'] ?? map['courses'] ?? map['data'] ?? data);
    return asList(raw, ClassRoutine.fromJson);
  }

  /// GET /api/student/live-classes
  /// Lists online classes belonging to active student batches.
  Future<LiveSessionBundle> liveClasses({
    String? keyword,
    String? status,
    int? perPage,
    int? page,
  }) async {
    final query = <String, dynamic>{};
    if (keyword != null && keyword.isNotEmpty) query['keyword'] = keyword;
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (perPage != null) query['per_page'] = perPage;
    if (page != null) query['page'] = page;

    final data = await _client.get(
      ApiEndpoints.studentLiveClasses,
      query: query.isEmpty ? null : query,
    );
    return LiveSessionBundle.fromJson(asMap(data) ?? {});
  }
}
