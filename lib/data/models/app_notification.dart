import '../../core/utils/json_utils.dart';

/// A single row from `GET /student/notifications`.
///
/// The shape is read defensively because two layouts are plausible and
/// only the backend knows which one ships:
///
///  1. Laravel's `DatabaseNotification` —
///     `{ id: "<uuid>", type: "App\\Notifications\\HomeworkAssigned",
///        data: { title, message, ... }, read_at: null, created_at }`
///  2. A hand-rolled resource —
///     `{ id: 1, title, message, is_read, created_at }`
///
/// Everything is looked up at the root first and then inside `data`, so
/// both parse without a code change. [id] is a String because Laravel's
/// notifications table uses UUID primary keys.
class AppNotification {
  final String id;
  final String title;
  final String? message;

  /// Raw type string. For Laravel notifications this is the class name,
  /// e.g. `App\Notifications\HomeworkAssigned`.
  final String? type;

  /// What the notification points at, when the payload says so. Used to
  /// deep-link into the right screen.
  final String? targetType; // homework | notice | fee | class | ticket ...
  final int? targetId;

  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    this.message,
    this.type,
    this.targetType,
    this.targetId,
    this.isRead = false,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final data = asMap(json['data']) ?? const <String, dynamic>{};

    dynamic pick(List<String> keys) {
      for (final k in keys) {
        if (json[k] != null) return json[k];
        if (data[k] != null) return data[k];
      }
      return null;
    }

    // Laravel marks a notification read by stamping `read_at`; a custom
    // resource is more likely to send a boolean.
    final readAt = pick(['read_at']);
    final readFlag = pick(['is_read', 'read']);

    return AppNotification(
      id: asString(json['id']),
      title: asString(
        pick(['title', 'subject', 'heading']),
        fallback: 'Notification',
      ),
      message: asStringOrNull(pick(['message', 'body', 'description', 'text'])),
      type: asStringOrNull(pick(['type', 'notification_type'])),
      targetType: asStringOrNull(pick(['target_type', 'model', 'module'])),
      targetId: asIntOrNull(
        pick(['target_id', 'reference_id', 'model_id', 'related_id']),
      ),
      isRead: readAt != null || asBool(readFlag),
      createdAt: asDate(pick(['created_at', 'date', 'sent_at'])),
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        message: message,
        type: type,
        targetType: targetType,
        targetId: targetId,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );

  /// Coarse category derived from whatever the server labelled it, used
  /// only to pick an icon. Unknown values fall back to a generic bell.
  String get category {
    final raw = '${type ?? ''} ${targetType ?? ''}'.toLowerCase();
    if (raw.contains('homework') || raw.contains('assignment')) {
      return 'homework';
    }
    if (raw.contains('notice') || raw.contains('announce')) return 'notice';
    if (raw.contains('fee') || raw.contains('payment') || raw.contains('invoice')) {
      return 'fee';
    }
    if (raw.contains('class') || raw.contains('lesson')) return 'class';
    if (raw.contains('ticket') || raw.contains('support')) return 'ticket';
    if (raw.contains('attendance')) return 'attendance';
    if (raw.contains('exam') || raw.contains('result')) return 'exam';
    if (raw.contains('quran')) return 'quran';
    return 'general';
  }
}
