import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/app_notification.dart';
import '../models/pagination.dart';

/// A page of notifications plus the server's own unread tally when it
/// sends one — the count can exceed `items.length` once the list is
/// paginated, so it is kept separate from the loaded rows.
class NotificationPage {
  final Paginated<AppNotification> page;
  final int? unreadCount;

  const NotificationPage({required this.page, this.unreadCount});
}

class NotificationRepository {
  final ApiClient _client;

  NotificationRepository(this._client);

  /// GET /student/notifications
  ///
  /// Accepts every envelope the endpoint might use: a raw Laravel
  /// paginator, `{ notifications: [...] }`, or a bare array.
  Future<NotificationPage> list({int page = 1}) async {
    final data = await _client.get(
      ApiEndpoints.notifications,
      query: {'page': page},
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

    // `{ notifications: { data: [...], current_page: 1 } }` — a paginator
    // nested one level down.
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

  /// POST /auth/notifications/{id}/read
  ///
  /// The ID is a String: Laravel's notifications table is UUID-keyed even
  /// though the Postman example happens to show a small integer.
  Future<void> markRead(String id) async {
    await _client.post(ApiEndpoints.notificationRead(id));
  }
}
