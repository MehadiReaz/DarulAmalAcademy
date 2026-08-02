import 'package:dio/dio.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/homework.dart';

/// Filters accepted by `GET /student/homework?status=`.
///
/// The backend understands `pending`, `submitted`, `overdue` and
/// `completed` — but `overdue` and `completed` are implemented with the
/// same query as `submitted`, so only the two meaningful filters are
/// exposed here.
enum HomeworkFilter { all, pending, submitted }

extension HomeworkFilterQuery on HomeworkFilter {
  String? get value {
    switch (this) {
      case HomeworkFilter.all:
        return null;
      case HomeworkFilter.pending:
        return 'pending';
      case HomeworkFilter.submitted:
        return 'submitted';
    }
  }

  String get label {
    switch (this) {
      case HomeworkFilter.all:
        return 'All';
      case HomeworkFilter.pending:
        return 'Pending';
      case HomeworkFilter.submitted:
        return 'Submitted';
    }
  }
}

class HomeworkRepository {
  final ApiClient _client;

  HomeworkRepository(this._client);

  /// GET /student/homework
  Future<List<Homework>> list({HomeworkFilter filter = HomeworkFilter.all}) async {
    final status = filter.value;
    final data = await _client.get(
      ApiEndpoints.homework,
      query: status == null ? null : {'status': status},
    );
    final rawMaps = extractHomeworkMaps(data);
    return rawMaps.map(Homework.fromJson).toList();
  }

  /// Recursively extracts homework item maps from raw response data.
  /// Handles bare lists, paginator envelopes ({assignments: {data: ...}}),
  /// and category-keyed maps ({"Ongoing Assignment": [...]}).
  static List<Map<String, dynamic>> extractHomeworkMaps(dynamic raw) {
    final result = <Map<String, dynamic>>[];
    if (raw == null) return result;

    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          result.add(Map<String, dynamic>.from(item));
        }
      }
      return result;
    }

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);

      // Check if wrapped in `assignments`
      if (map.containsKey('assignments')) {
        return extractHomeworkMaps(map['assignments']);
      }

      // Check if wrapped in `data` (paginator)
      if (map.containsKey('data')) {
        return extractHomeworkMaps(map['data']);
      }

      // Iterate through keys which may represent status/category buckets
      for (final entry in map.entries) {
        if (entry.value is List) {
          for (final item in (entry.value as List)) {
            if (item is Map) {
              result.add(Map<String, dynamic>.from(item));
            }
          }
        } else if (entry.value is Map) {
          final subMap = Map<String, dynamic>.from(entry.value as Map);
          if (subMap.containsKey('id') && subMap.containsKey('title')) {
            result.add(subMap);
          } else {
            result.addAll(extractHomeworkMaps(subMap));
          }
        }
      }
    }

    return result;
  }

  /// GET /student/homework/{id}
  Future<HomeworkDetail> detail(int id) async {
    final data = await _client.get(ApiEndpoints.homeworkDetail(id));
    final map = asMap(data) ?? {};
    final unwrapped = asMap(map['assignment']) ??
        asMap(map['homework']) ??
        asMap(map['data']) ??
        map;
    return HomeworkDetail.fromJson(unwrapped);
  }

  /// POST /student/homework/{id}/submit
  ///
  /// The backend accepts `text` (nullable string) and/or `audio` (file
  /// attachment: png, jpg, jpeg, pdf, zip, doc, docx) and rejects the
  /// request with 422 if both are missing.
  Future<void> submit({
    required int id,
    String? text,
    String? audioPath,
  }) async {
    final trimmed = text?.trim();
    final hasText = trimmed != null && trimmed.isNotEmpty;
    final hasAudio = audioPath != null && audioPath.isNotEmpty;

    // Fail fast locally rather than burning a round trip on a request the
    // server is guaranteed to reject.
    if (!hasText && !hasAudio) {
      throw ArgumentError('Provide either text answer or a file attachment.');
    }

    if (hasAudio) {
      final form = FormData.fromMap({
        if (hasText) 'text': trimmed,
        'attachment': await MultipartFile.fromFile(audioPath),
      });
      await _client.postMultipart(ApiEndpoints.homeworkSubmit(id), form);
      return;
    }

    await _client.post(
      ApiEndpoints.homeworkSubmit(id),
      body: {'text': trimmed},
    );
  }
}
