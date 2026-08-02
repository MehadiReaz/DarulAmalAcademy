import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/lesson.dart';
import '../models/pagination.dart';

class LessonRepository {
  final ApiClient _client;

  LessonRepository(this._client);

  /// GET /student/my-lessons
  ///
  /// Handles a bare array, a raw Laravel paginator, and a
  /// `{ lessons: [...] }` wrapper. This endpoint was returning 500 the
  /// last time it was exercised, so its final shape is unconfirmed and
  /// all three are read rather than guessed at.
  Future<Paginated<Lesson>> list({int page = 1}) async {
    final data = await _client.get(
      ApiEndpoints.myLessons,
      query: {'page': page},
    );

    if (data is List) {
      return Paginated(
        items: asList(data, Lesson.fromJson),
        pagination: const Pagination(),
      );
    }

    final map = asMap(data) ?? {};
    final raw = map['data'] ?? map['lessons'] ?? map['items'];
    final nested = asMap(raw);

    return Paginated(
      items: nested != null
          ? asList(nested['data'], Lesson.fromJson)
          : asList(raw, Lesson.fromJson),
      pagination: Pagination.fromEnvelope(nested ?? map),
    );
  }
}
