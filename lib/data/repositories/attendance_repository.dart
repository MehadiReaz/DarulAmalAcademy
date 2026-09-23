import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/attendance.dart';

class AttendanceRepository {
  final ApiClient _client;

  AttendanceRepository(this._client);

  /// GET /api/student/attendance
  Future<List<SubjectAttendanceGroup>> myAttendances({
    String? keyword,
    int? courseId,
    int? teacherId,
    int? page,
    int? perPage,
  }) async {
    final query = <String, dynamic>{};
    if (keyword != null && keyword.isNotEmpty) query['keyword'] = keyword;
    if (courseId != null) query['course_id'] = courseId;
    if (teacherId != null) query['teacher_id'] = teacherId;
    if (page != null) query['page'] = page;
    if (perPage != null) query['per_page'] = perPage;

    final data = await _client.get(
      ApiEndpoints.studentAttendance,
      query: query.isEmpty ? null : query,
    );
    return SubjectAttendanceGroup.parseAll(data);
  }
}
