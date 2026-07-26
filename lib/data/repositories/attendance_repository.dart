import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/attendance.dart';

class AttendanceRepository {
  final ApiClient _client;

  AttendanceRepository(this._client);

  /// GET /student/my-attendances
  ///
  /// Returns a map keyed by subject id rather than a list, so the parsing
  /// lives in [SubjectAttendanceGroup.parseAll].
  Future<List<SubjectAttendanceGroup>> myAttendances() async {
    final data = await _client.get(ApiEndpoints.myAttendances);
    return SubjectAttendanceGroup.parseAll(data);
  }
}
