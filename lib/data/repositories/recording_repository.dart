import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/pagination.dart';
import '../models/recording.dart';

class RecordingRepository {
  final ApiClient _client;

  RecordingRepository(this._client);

  /// GET /api/student/recordings
  Future<Paginated<Recording>> list({
    int page = 1,
    int perPage = 12,
    String? keyword,
    int? courseId,
    int? batchId,
    int? subjectId,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (keyword != null && keyword.isNotEmpty) query['keyword'] = keyword;
    if (courseId != null) query['course_id'] = courseId;
    if (batchId != null) query['batch_id'] = batchId;
    if (subjectId != null) query['subject_id'] = subjectId;

    final data = await _client.get(
      ApiEndpoints.studentRecordings,
      query: query,
    );

    dynamic rawList;
    Map<String, dynamic> paginationMap = {};

    if (data is List) {
      rawList = data;
    } else if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map['recordings'] is Map) {
        final recMap = Map<String, dynamic>.from(map['recordings'] as Map);
        paginationMap = recMap;
        rawList = recMap['data'] ?? recMap['items'];
      } else if (map['recordings'] is List) {
        rawList = map['recordings'];
        paginationMap = map;
      } else if (map['data'] is List) {
        rawList = map['data'];
        paginationMap = map;
      } else if (map['data'] is Map) {
        final nested = Map<String, dynamic>.from(map['data'] as Map);
        paginationMap = nested;
        rawList = nested['data'] ?? nested['items'];
      } else {
        rawList = map['items'];
        paginationMap = map;
      }
    }

    final items = asList(rawList, Recording.fromJson);
    final pagination = Pagination.fromJson(paginationMap);

    return Paginated(items: items, pagination: pagination);
  }

  /// GET /api/student/recordings/{id}
  Future<Recording> detail(int id) async {
    final data = await _client.get(ApiEndpoints.studentRecordingDetail(id));
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final recObj = map['recording'] ?? map['data'] ?? map;
      if (recObj is Map) {
        return Recording.fromJson(Map<String, dynamic>.from(recObj));
      }
    }
    return Recording.fromJson(asMap(data) ?? {});
  }
}
