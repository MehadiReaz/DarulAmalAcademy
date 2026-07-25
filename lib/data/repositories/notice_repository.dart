import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/notice.dart';
import '../models/pagination.dart';

class NoticeRepository {
  final ApiClient _client;

  NoticeRepository(this._client);

  /// GET /student/notices  →  paginated notice list.
  ///
  /// The backend returns a Laravel paginator directly in `data`,
  /// so the items live under `data.data` and pagination fields
  /// (`current_page`, `last_page`, etc.) sit at the top level.
  Future<Paginated<Notice>> list({int page = 1}) async {
    final data = await _client.get(
      ApiEndpoints.notices,
      query: {'page': page},
    );

    final map = asMap(data) ?? {};

    // Laravel paginator: items are in `data` key, pagination at root.
    final items = asList(map['data'], Notice.fromJson);
    final pagination = Pagination.fromJson(map);

    return Paginated(items: items, pagination: pagination);
  }

  /// GET /student/notices/{id}  →  single notice detail.
  Future<Notice> detail(int id) async {
    final data = await _client.get(ApiEndpoints.noticeDetail(id));
    return Notice.fromJson(asMap(data) ?? {});
  }

  /// POST /student/notices/{id}/read  →  mark as read.
  Future<void> markRead(int id) async {
    await _client.post(ApiEndpoints.noticeRead(id));
  }
}
