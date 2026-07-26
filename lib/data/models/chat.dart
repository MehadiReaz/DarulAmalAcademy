import '../../core/utils/json_utils.dart';
import 'student_user.dart';

/// A chat group as it appears in `GET /group-chats`.
///
/// The list endpoint uses `group_id` / `group_name` while the detail
/// endpoint uses `id` / `name`, so both spellings are read.
class ChatGroup {
  final int id;
  final String name;
  final String? image;
  final String? lastMessage;

  /// Pre-formatted by the server, e.g. "17:19 PM" (sic).
  final String? lastMessageTime;
  final int unreadCount;
  final int memberCount;
  final NamedRef? subject;
  final NamedRef? course;

  const ChatGroup({
    required this.id,
    required this.name,
    this.image,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.memberCount = 0,
    this.subject,
    this.course,
  });

  factory ChatGroup.fromJson(Map<String, dynamic> json) => ChatGroup(
        id: asInt(json['group_id'] ?? json['id']),
        name: asString(json['group_name'] ?? json['name'], fallback: 'Group'),
        image: asStringOrNull(json['group_image'] ?? json['image']),
        lastMessage: asStringOrNull(json['last_message']),
        lastMessageTime: asStringOrNull(json['last_message_time']),
        unreadCount: asInt(json['unread_count']),
        memberCount: asInt(json['member_count']),
        subject: json['subject'] == null
            ? null
            : NamedRef.fromJson(asMap(json['subject']) ?? {}),
        course: json['course'] == null
            ? null
            : NamedRef.fromJson(asMap(json['course']) ?? {}),
      );

  bool get hasUnread => unreadCount > 0;

  /// Subject and course names, for the thread subtitle.
  String? get contextLabel {
    final parts = <String>[
      if (course?.name != null) course!.name!,
      if (subject?.name != null && subject!.name != course?.name)
        subject!.name!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  ChatGroup copyWith({int? unreadCount, String? lastMessage}) => ChatGroup(
        id: id,
        name: name,
        image: image,
        lastMessage: lastMessage ?? this.lastMessage,
        lastMessageTime: lastMessageTime,
        unreadCount: unreadCount ?? this.unreadCount,
        memberCount: memberCount,
        subject: subject,
        course: course,
      );
}

/// A message from `GET /group-chats/{id}/messages`, or the echo returned
/// by `POST /group-chats/{id}/messages`.
class ChatMessage {
  final int id;
  final NamedRef? sender;
  final String? text;
  final String? attachment;

  /// 'text' | 'image' | 'file' — as reported by the server.
  final String messageType;
  final DateTime? createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;

  /// Set locally for optimistic sends that haven't been confirmed yet.
  final bool pending;
  final bool failed;

  const ChatMessage({
    required this.id,
    this.sender,
    this.text,
    this.attachment,
    this.messageType = 'text',
    this.createdAt,
    this.editedAt,
    this.deletedAt,
    this.pending = false,
    this.failed = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: asInt(json['message_id'] ?? json['id']),
        sender: json['sender'] == null
            ? null
            : NamedRef.fromJson(asMap(json['sender']) ?? {}),
        text: asStringOrNull(json['message']),
        attachment: asStringOrNull(json['attachment']),
        messageType: asString(json['message_type'], fallback: 'text'),
        createdAt: asDate(json['created_at']),
        editedAt: asDate(json['edited_at']),
        deletedAt: asDate(json['deleted_at']),
      );

  bool get isDeleted => deletedAt != null;
  bool get hasAttachment => attachment != null && attachment!.isNotEmpty;

  /// The server records `edited_at` equal to `created_at` on insert, so a
  /// message only counts as edited when the two actually differ.
  bool get isEdited =>
      editedAt != null && createdAt != null && editedAt!.isAfter(createdAt!);

  bool isMine(int? myUserId) => myUserId != null && sender?.id == myUserId;

  ChatMessage copyWith({bool? pending, bool? failed}) => ChatMessage(
        id: id,
        sender: sender,
        text: text,
        attachment: attachment,
        messageType: messageType,
        createdAt: createdAt,
        editedAt: editedAt,
        deletedAt: deletedAt,
        pending: pending ?? this.pending,
        failed: failed ?? this.failed,
      );
}

/// A hit from `GET /group-chats/{id}/search?q=`.
///
/// Deliberately a separate type: the search endpoint returns a flattened
/// `sender_name` string rather than the nested sender object, so reusing
/// [ChatMessage] would silently produce messages with a null sender.
class ChatSearchHit {
  final int messageId;
  final String? senderName;
  final String? text;
  final DateTime? createdAt;

  const ChatSearchHit({
    required this.messageId,
    this.senderName,
    this.text,
    this.createdAt,
  });

  factory ChatSearchHit.fromJson(Map<String, dynamic> json) => ChatSearchHit(
        messageId: asInt(json['message_id'] ?? json['id']),
        senderName: asStringOrNull(json['sender_name']),
        text: asStringOrNull(json['message']),
        createdAt: asDate(json['created_at']),
      );
}
