import 'package:dio/dio.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/chat.dart';
import '../models/pagination.dart';

class ChatRepository {
  final ApiClient _client;

  ChatRepository(this._client);

  /// GET /group-chats  ->  bare array in `data`.
  Future<List<ChatGroup>> groups() async {
    final data = await _client.get(ApiEndpoints.groupChats);
    return asList(data, ChatGroup.fromJson);
  }

  /// GET /group-chats/{id}
  Future<ChatGroup> group(int id) async {
    final data = await _client.get(ApiEndpoints.groupChat(id));
    return ChatGroup.fromJson(asMap(data) ?? {});
  }

  /// GET /group-chats/{id}/messages
  ///
  /// Page metadata is nested under `pagination` here, unlike the raw
  /// paginators used elsewhere.
  Future<Paginated<ChatMessage>> messages(int groupId, {int page = 1}) async {
    final data = await _client.get(
      ApiEndpoints.groupChatMessages(groupId),
      query: {'page': page},
    );
    final map = asMap(data) ?? {};
    return Paginated(
      items: asList(map['messages'], ChatMessage.fromJson),
      pagination: Pagination.fromEnvelope(map),
    );
  }

  /// POST /group-chats/{id}/messages  { message, attachment? }
  ///
  /// Sent as multipart whenever a file is attached, plain JSON otherwise.
  Future<ChatMessage> send(
    int groupId, {
    String? message,
    String? attachmentPath,
  }) async {
    final text = message?.trim();
    final hasText = text != null && text.isNotEmpty;
    final hasFile = attachmentPath != null && attachmentPath.isNotEmpty;

    if (!hasText && !hasFile) {
      throw ArgumentError('Type a message or attach a file.');
    }

    dynamic data;
    if (hasFile) {
      final form = FormData.fromMap({
        if (hasText) 'message': text,
        'attachment': await MultipartFile.fromFile(attachmentPath),
      });
      data = await _client.postMultipart(
        ApiEndpoints.groupChatMessages(groupId),
        form,
      );
    } else {
      data = await _client.post(
        ApiEndpoints.groupChatMessages(groupId),
        body: {'message': text},
      );
    }

    return ChatMessage.fromJson(asMap(data) ?? {});
  }

  /// GET /group-chats/{id}/search?q=
  Future<List<ChatSearchHit>> search(int groupId, String query) async {
    final data = await _client.get(
      ApiEndpoints.groupChatSearch(groupId),
      query: {'q': query},
    );
    return asList(data, ChatSearchHit.fromJson);
  }
}
