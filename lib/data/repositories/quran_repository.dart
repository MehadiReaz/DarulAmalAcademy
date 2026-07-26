import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/quran_progress.dart';

class QuranRepository {
  final ApiClient _client;

  QuranRepository(this._client);

  /// GET /student/quran-progress
  ///
  /// Preferred over the `quran_progress` block on the profile endpoint:
  /// it paginates the teacher's notes and ships the curriculum reference
  /// data (114 surahs, focus labels, lesson/para totals) the UI needs to
  /// render progress against real denominators.
  Future<QuranProgressBundle> progress({int page = 1}) async {
    final data = await _client.get(
      ApiEndpoints.quranProgress,
      query: {'page': page},
    );
    return QuranProgressBundle.fromJson(asMap(data) ?? {});
  }
}
