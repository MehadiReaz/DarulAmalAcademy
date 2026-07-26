import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/pagination.dart';
import '../models/recording.dart';

class RecordingRepository {
  final ApiClient _client;

  RecordingRepository(this._client);

  /// GET /student/recordings  ->  raw Laravel paginator (12 per page).
  Future<Paginated<Recording>> list({int page = 1}) async {
    final data = await _client.get(
      ApiEndpoints.recordings,
      query: {'page': page},
    );
    final map = asMap(data) ?? {};
    return Paginated(
      items: asList(map['data'], Recording.fromJson),
      pagination: Pagination.fromEnvelope(map),
    );
  }

  /// GET /student/recordings/{id}
  Future<Recording> detail(int id) async {
    final data = await _client.get(ApiEndpoints.recordingDetail(id));
    return Recording.fromJson(asMap(data) ?? {});
  }
}
