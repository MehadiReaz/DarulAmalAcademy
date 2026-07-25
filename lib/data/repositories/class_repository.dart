import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/class_routine.dart';
import '../models/enrolled_course.dart';

class ClassRepository {
  final ApiClient _client;

  ClassRepository(this._client);

  /// GET /student/my-courses  ->  { courses: [ ... ] }
  Future<List<EnrolledCourse>> myCourses() async {
    final data = await _client.get(ApiEndpoints.myCourses);
    final map = asMap(data);
    final raw = map == null ? data : map['courses'];
    return asList(raw, EnrolledCourse.fromJson);
  }

  /// GET /student/classes/today  ->  [ ... ]  (bare array, no wrapper key)
  Future<List<ClassRoutine>> today() async {
    final data = await _client.get(ApiEndpoints.classesToday);
    return asList(data, ClassRoutine.fromJson);
  }

  /// GET /student/classes/upcoming  ->  [ ... ]
  Future<List<ClassRoutine>> upcoming() async {
    final data = await _client.get(ApiEndpoints.classesUpcoming);
    return asList(data, ClassRoutine.fromJson);
  }
}
