import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/json_utils.dart';
import '../models/class_routine.dart';
import '../models/enrolled_course.dart';
import '../models/live_session.dart';

class ClassRepository {
  final ApiClient _client;

  ClassRepository(this._client);

  /// GET /student/my-classes  ->  bare array in `data`.
  ///
  /// RENAMED: this endpoint was `/student/my-courses`. The response is
  /// the raw `UserCourse` models with `course` eager-loaded, so items sit
  /// directly in `data` rather than under a `courses` key — both are read
  /// so a rollback wouldn't break it.
  Future<List<EnrolledCourse>> myClasses() async {
    final data = await _client.get(ApiEndpoints.myClasses);
    final map = asMap(data);
    final raw = map == null ? data : (map['courses'] ?? map['data'] ?? data);
    return asList(raw, EnrolledCourse.fromJson);
  }

  /// GET /student/class/today  ->  [ ... ]
  ///
  /// This used to call `/student/my-classes` instead, because the path
  /// being requested (`/student/classes/today`) does not exist — the
  /// segment is singular. With the correct path the real endpoint is
  /// used, and the enrolled-course list stays as a fallback so a server
  /// fault degrades to "today's classes look like your class list"
  /// rather than an empty screen.
  Future<List<ClassRoutine>> today() async {
    try {
      final data = await _client.get(ApiEndpoints.classesToday);
      return _routines(data);
    } on ApiException catch (_) {
      final data = await _client.get(ApiEndpoints.myClasses);
      return _routines(data);
    }
  }

  /// GET /student/class/upcoming  ->  [ ... ]
  Future<List<ClassRoutine>> upcoming() async {
    final data = await _client.get(ApiEndpoints.classesUpcoming);
    return _routines(data);
  }

  /// Both endpoints may answer with a bare array or wrap it in
  /// `classes` / `courses` / `data`.
  List<ClassRoutine> _routines(dynamic data) {
    final map = asMap(data);
    final raw = map == null
        ? data
        : (map['classes'] ?? map['courses'] ?? map['data'] ?? data);
    return asList(raw, ClassRoutine.fromJson);
  }

  /// GET /student/my-class-routine
  ///
  /// The full weekly routine plus one-off schedules and the teacher
  /// roster. Unlike [today] / [upcoming] this one is not gated by the
  /// broken class-authorisation check, so it is the reliable source for
  /// timetable data right now.
  Future<ClassRoutineBundle> routine({int page = 1}) async {
    final data = await _client.get(
      ApiEndpoints.classRoutine,
      query: {'page': page},
    );
    return ClassRoutineBundle.fromJson(asMap(data) ?? {});
  }

  /// GET /student/classes/{id}/join  ->  meeting link payload.
  Future<ClassJoinInfo> join(int classId) async {
    final data = await _client.get(ApiEndpoints.classJoin(classId));
    return ClassJoinInfo.fromJson(asMap(data) ?? {});
  }

  /// GET /student/my-batches  ->  bare array.
  Future<List<Map<String, dynamic>>> myBatches() async {
    final data = await _client.get(ApiEndpoints.myBatches);
    if (data is! List) return const [];
    return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  /// GET /student/live-sessions
  Future<LiveSessionBundle> liveSessions({int page = 1}) async {
    final data = await _client.get(
      ApiEndpoints.liveSessions,
      query: {'page': page},
    );
    return LiveSessionBundle.fromJson(asMap(data) ?? {});
  }
}
