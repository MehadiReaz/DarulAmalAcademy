import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/quran_progress.dart';

class QuranRepository {
  final ApiClient _client;

  QuranRepository(this._client);

  /// GET /api/student/quran-progress
  /// Returns the student's Quran progress snapshot, history, and reference data.
  Future<QuranProgressBundle> progress({int page = 1, int perPage = 10}) async {
    final data = await _client.get(
      ApiEndpoints.studentQuranProgress,
      query: {'page': page, 'per_page': perPage},
    );
    return QuranProgressBundle.fromJson(asMap(data) ?? {});
  }

  /// GET /api/public/quran
  /// Returns published Quran surahs and topic groupings.
  Future<dynamic> publicQuranIndex() async {
    return await _client.get(ApiEndpoints.publicQuran);
  }

  /// GET /api/public/quran/surahs/{surah_number}
  /// Returns one published surah with ayahs, audio sources, tafsir, and navigation.
  Future<dynamic> publicQuranSurah(int surahNumber) async {
    return await _client.get(ApiEndpoints.publicQuranSurah(surahNumber));
  }
}
