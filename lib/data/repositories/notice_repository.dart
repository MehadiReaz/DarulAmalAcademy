import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/notice.dart';
import '../models/pagination.dart';

class NoticeRepository {
  final ApiClient _client;

  NoticeRepository(this._client);

  /// GET /api/student/notices
  Future<Paginated<Notice>> list({
    int page = 1,
    int? perPage,
    String? keyword,
  }) async {
    final query = <String, dynamic>{'page': page};
    if (perPage != null) query['per_page'] = perPage;
    if (keyword != null && keyword.isNotEmpty) query['keyword'] = keyword;

    final data = await _client.get(
      ApiEndpoints.studentNotices,
      query: query,
    );

    dynamic rawList;
    Map<String, dynamic> paginationMap = {};

    if (data is List) {
      rawList = data;
    } else if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map['notices'] is Map) {
        final noticesMap = Map<String, dynamic>.from(map['notices'] as Map);
        paginationMap = noticesMap;
        rawList = noticesMap['data'] ?? noticesMap['items'];
      } else if (map['notices'] is List) {
        rawList = map['notices'];
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

    final items = asList(rawList, Notice.fromJson);
    final pagination = Pagination.fromJson(paginationMap);

    return Paginated(items: items, pagination: pagination);
  }

  /// GET /api/student/notices/{id}
  Future<Notice> detail(int id) async {
    final data = await _client.get(ApiEndpoints.studentNoticeDetail(id));
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final noticeObj = map['notice'] ?? map['data'] ?? map;
      if (noticeObj is Map) {
        return Notice.fromJson(Map<String, dynamic>.from(noticeObj));
      }
    }
    return Notice.fromJson(asMap(data) ?? {});
  }

  /// POST /api/student/notices/{id}/read
  Future<void> markRead(int id) async {
    await _client.postForm(ApiEndpoints.studentNoticeRead(id), {});
  }
}
