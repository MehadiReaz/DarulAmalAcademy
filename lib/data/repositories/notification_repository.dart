import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/app_notification.dart';
import '../models/pagination.dart';

class NotificationPage {
  final Paginated<AppNotification> page;
  final int? unreadCount;

  const NotificationPage({required this.page, this.unreadCount});
}

class NotificationRepository {
  final ApiClient _client;

  NotificationRepository(this._client);

  /// GET /api/student/notifications
  Future<NotificationPage> list({int page = 1, int? perPage}) async {
    final query = <String, dynamic>{'page': page};
    if (perPage != null) query['per_page'] = perPage;

    final data = await _client.get(
      ApiEndpoints.studentNotifications,
      query: query,
    );

    if (data is List) {
      return NotificationPage(
        page: Paginated(
          items: asList(data, AppNotification.fromJson),
          pagination: const Pagination(),
        ),
      );
    }

    final map = asMap(data) ?? {};
    final raw = map['data'] ?? map['notifications'] ?? map['items'];

    final nested = asMap(raw);
    final items = nested != null
        ? asList(nested['data'], AppNotification.fromJson)
        : asList(raw, AppNotification.fromJson);

    return NotificationPage(
      page: Paginated(
        items: items,
        pagination: Pagination.fromEnvelope(nested ?? map),
      ),
      unreadCount: asIntOrNull(map['unread_count'] ?? map['unread']),
    );
  }

  /// POST /api/student/notifications/{id}/read
  Future<void> markRead(String id) async {
    await _client.postForm(ApiEndpoints.studentNotificationRead(id), {});
  }

  /// POST /api/student/fcm-token
  Future<void> registerFcmToken(String token, {String? deviceType}) async {
    final form = <String, dynamic>{
      'token': token,
      if (deviceType != null && deviceType.isNotEmpty) 'device_type': deviceType,
    };
    await _client.postForm(ApiEndpoints.studentFcmToken, form);
  }

  /// POST /api/student/fcm-token/remove
  Future<void> removeFcmToken(String token) async {
    await _client.postForm(ApiEndpoints.studentFcmTokenRemove, {'token': token});
  }
}
