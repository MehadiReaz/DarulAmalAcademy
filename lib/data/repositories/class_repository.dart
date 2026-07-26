import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/class_routine.dart';
import '../models/enrolled_course.dart';

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

  /// GET /student/classes/today  ->  [ ... ]  (bare array, no wrapper key)
  ///
  /// NOTE: returned 403 "You are not authorized to access this class" for
  /// an enrolled student in the 26 Jul run — a server-side authorisation
  /// fault, not a client one.
  Future<List<ClassRoutine>> today() async {
    final data = await _client.get(ApiEndpoints.classesToday);
    return asList(data, ClassRoutine.fromJson);
  }

  /// GET /student/classes/upcoming  ->  [ ... ]
  ///
  /// Same 403 as [today].
  Future<List<ClassRoutine>> upcoming() async {
    final data = await _client.get(ApiEndpoints.classesUpcoming);
    return asList(data, ClassRoutine.fromJson);
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
}
