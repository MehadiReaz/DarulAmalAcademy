import 'package:dio/dio.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/homework.dart';

/// Filters accepted by `GET /api/student/assignments?status=`.
enum HomeworkFilter { all, pending, submitted, expired }

extension HomeworkFilterQuery on HomeworkFilter {
  String? get value {
    switch (this) {
      case HomeworkFilter.all:
        return null;
      case HomeworkFilter.pending:
        return 'unsubmitted';
      case HomeworkFilter.submitted:
        return 'submitted';
      case HomeworkFilter.expired:
        return 'Expired';
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
      case HomeworkFilter.expired:
        return 'Expired';
    }
  }
}

class HomeworkRepository {
  final ApiClient _client;

  HomeworkRepository(this._client);

  /// GET /api/student/assignments
  Future<List<Homework>> list({
    HomeworkFilter filter = HomeworkFilter.all,
    String? keyword,
    int? courseId,
    String? rawStatus,
    int? page,
    int? perPage,
  }) async {
    final status = rawStatus ?? filter.value;
    final query = <String, dynamic>{};
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (keyword != null && keyword.isNotEmpty) query['keyword'] = keyword;
    if (courseId != null) query['course_id'] = courseId;
    if (page != null) query['page'] = page;
    if (perPage != null) query['per_page'] = perPage;

    final data = await _client.get(
      ApiEndpoints.studentAssignments,
      query: query.isEmpty ? null : query,
    );
    final rawMaps = extractHomeworkMaps(data);
    return rawMaps.map(Homework.fromJson).toList();
  }

  /// Recursively extracts homework/assignment item maps from raw response data.
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

  /// GET /api/student/assignments/{id}
  Future<HomeworkDetail> detail(int id) async {
    final data = await _client.get(ApiEndpoints.studentAssignmentDetail(id));
    final map = asMap(data) ?? {};
    final assignmentMap = asMap(map['assignment']) ?? asMap(map['homework']) ?? {};
    final merged = Map<String, dynamic>.from(
      assignmentMap.isNotEmpty ? assignmentMap : (asMap(map['data']) ?? map),
    );

    if (map.containsKey('submissions_list')) {
      merged['submissions_list'] = map['submissions_list'];
    }
    if (map.containsKey('submissions')) {
      merged['submissions'] = map['submissions'];
    }
    return HomeworkDetail.fromJson(merged);
  }

  /// POST /api/student/assignments/{id}/submit
  /// Submits student's assignment file (required) with optional description.
  Future<void> submit({
    required int id,
    String? text,
    String? filePath,
    String? audioPath,
    String? description,
  }) async {
    final uploadFile = filePath ?? audioPath;
    final desc = description ?? text?.trim();

    if (uploadFile == null || uploadFile.isEmpty) {
      throw ArgumentError('A file attachment is required for assignment submission.');
    }

    final formMap = <String, dynamic>{
      'file': await MultipartFile.fromFile(uploadFile),
      if (desc != null && desc.isNotEmpty) 'description': desc,
    };

    final form = FormData.fromMap(formMap);
    await _client.postMultipart(ApiEndpoints.studentAssignmentSubmit(id), form);
  }
}
