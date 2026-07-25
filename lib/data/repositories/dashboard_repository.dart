import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/dashboard_data.dart';

class DashboardRepository {
  final ApiClient _client;

  DashboardRepository(this._client);

  /// GET /student/dashboard  →  full dashboard payload.
  Future<DashboardData> fetch() async {
    final data = await _client.get(ApiEndpoints.dashboard);
    return DashboardData.fromJson(asMap(data) ?? {});
  }
}
