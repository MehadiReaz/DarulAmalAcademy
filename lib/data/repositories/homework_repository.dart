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

  /// GET /student/homework  ->  bare array in `data` (no wrapper key).
  Future<List<Homework>> list({HomeworkFilter filter = HomeworkFilter.all}) async {
    final status = filter.value;
    final data = await _client.get(
      ApiEndpoints.homework,
      query: status == null ? null : {'status': status},
    );
    return asList(data, Homework.fromJson);
  }

  /// GET /student/homework/{id}
  Future<HomeworkDetail> detail(int id) async {
    final data = await _client.get(ApiEndpoints.homeworkDetail(id));
    return HomeworkDetail.fromJson(asMap(data) ?? {});
  }

  /// POST /student/homework/{id}/submit
  ///
  /// The backend accepts `text` (nullable string) and/or `audio` (an
  /// uploaded mp3/wav/m4a up to 10 MB) and rejects the request with 422
  /// if both are missing. It also refuses a second submission for the
  /// same assignment with a 400.
  ///
  /// [audioPath] is optional so a recorder/file-picker can be wired in
  /// later without touching this layer — when it is null the request is
  /// sent as plain JSON rather than multipart.
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
      throw ArgumentError('Provide either text or an audio recording.');
    }

    if (hasAudio) {
      final form = FormData.fromMap({
        if (hasText) 'text': trimmed,
        'audio': await MultipartFile.fromFile(audioPath),
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
