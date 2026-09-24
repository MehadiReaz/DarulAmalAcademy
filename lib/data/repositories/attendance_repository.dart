import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/attendance.dart';
import '../models/pagination.dart';

class AttendanceRepository {
  final ApiClient _client;

  AttendanceRepository(this._client);

  /// Safety cap so a misbehaving paginator can't loop forever.
  static const _maxPages = 20;

  /// GET /api/student/attendance
  ///
  /// Returns `{attendances: <paginator>, courses, filters}`. The summary
  /// needs every record, so this walks all pages.
  Future<List<AttendanceRecord>> all({int? courseId}) async {
    final records = <AttendanceRecord>[];
    var page = 1;
    while (true) {
      final data = await _client.get(
        ApiEndpoints.studentAttendance,
        query: {
          'page': page,
          'per_page': 100,
          'course_id': ?courseId,
        },
      );
      records.addAll(AttendanceRecord.listFrom(data));

      final paginator = asMap(asMap(data)?['attendances']);
      final pagination =
          paginator == null ? null : Pagination.fromJson(paginator);
      if (pagination == null || !pagination.hasMore || page >= _maxPages) {
        return records;
      }
      page = pagination.nextPage;
    }
  }
}
