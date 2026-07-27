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

/// What an attachment can be rendered as.
///
/// The server's `message_type` is the first authority; when it is missing or
/// just says `file`, the extension decides. Shared by the model and the chat
/// UI so a "this is an image" decision is made in exactly one place.
enum AttachmentKind { none, image, pdf, file }

const _imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'heic'};

/// Classifies a local file path, a remote URL, or a bare file name.
AttachmentKind attachmentKindOf(String? pathOrUrl) {
  if (pathOrUrl == null || pathOrUrl.isEmpty) return AttachmentKind.none;

  var path = pathOrUrl;
  final uri = Uri.tryParse(pathOrUrl);
  if (uri != null && uri.hasScheme) path = uri.path;

  final dot = path.lastIndexOf('.');
  if (dot == -1 || dot == path.length - 1) return AttachmentKind.file;

  final ext = path.substring(dot + 1).toLowerCase();
  if (ext == 'pdf') return AttachmentKind.pdf;
  if (_imageExtensions.contains(ext)) return AttachmentKind.image;
  return AttachmentKind.file;
}

/// The display name for a local path or a remote URL.
String attachmentNameOf(String? pathOrUrl, {String fallback = 'File'}) {
  if (pathOrUrl == null || pathOrUrl.isEmpty) return fallback;

  var path = pathOrUrl;
  final uri = Uri.tryParse(pathOrUrl);
  if (uri != null && uri.hasScheme) path = uri.path;

  final slash = path.lastIndexOf('/');
  final name = slash == -1 ? path : path.substring(slash + 1);
  if (name.isEmpty) return fallback;

  try {
    return Uri.decodeComponent(name);
  } catch (_) {
    return name;
  }
}

/// Sentinel so [ChatMessage.copyWith] can tell "leave this alone" apart from
/// "set this to null" — needed to clear the local path once the upload lands.
const Object _unset = Object();

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

  /// Path to the file on this device, kept only while the message is in
  /// flight so the bubble can show the picked image before the upload
  /// finishes. Cleared once the server echo arrives with a real URL.
  final String? localAttachmentPath;

  /// Upload progress, 0.0–1.0. Null means "in flight, but no byte counts" —
  /// the UI shows an indeterminate spinner for that case.
  final double? uploadProgress;

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
    this.localAttachmentPath,
    this.uploadProgress,
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

  /// The bubble to insert the moment the user hits send, before the request
  /// completes. [tempId] should be negative so it can't collide with a real
  /// server id.
  factory ChatMessage.optimistic({
    required int tempId,
    NamedRef? sender,
    String? text,
    String? attachmentPath,
    DateTime? createdAt,
  }) {
    final kind = attachmentKindOf(attachmentPath);
    return ChatMessage(
      id: tempId,
      sender: sender,
      text: text,
      messageType: switch (kind) {
        AttachmentKind.image => 'image',
        AttachmentKind.pdf || AttachmentKind.file => 'file',
        AttachmentKind.none => 'text',
      },
      createdAt: createdAt ?? DateTime.now(),
      pending: true,
      localAttachmentPath: attachmentPath,
      uploadProgress: attachmentPath == null ? null : 0,
    );
  }

  bool get isDeleted => deletedAt != null;
  bool get hasAttachment => attachment != null && attachment!.isNotEmpty;

  /// True while the file itself is still going up, as opposed to a plain
  /// text message waiting on the response.
  bool get isUploading => pending && localAttachmentPath != null;

  /// Whatever the UI should render right now: the on-device file while the
  /// upload is running, the remote URL once it lands.
  String? get attachmentSource => localAttachmentPath ?? attachment;

  /// True if there is anything to draw in the bubble — including a local
  /// file that has no server URL yet.
  bool get showsAttachment => attachmentSource != null;

  AttachmentKind get attachmentKind {
    final source = attachmentSource;
    if (source == null) return AttachmentKind.none;
    if (messageType == 'image') return AttachmentKind.image;
    return attachmentKindOf(source);
  }

  String get attachmentName => attachmentNameOf(attachmentSource);

  /// The server records `edited_at` equal to `created_at` on insert, so a
  /// message only counts as edited when the two actually differ.
  bool get isEdited =>
      editedAt != null && createdAt != null && editedAt!.isAfter(createdAt!);

  bool isMine(int? myUserId) => myUserId != null && sender?.id == myUserId;

  ChatMessage copyWith({
    bool? pending,
    bool? failed,
    Object? localAttachmentPath = _unset,
    Object? uploadProgress = _unset,
  }) =>
      ChatMessage(
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
        localAttachmentPath: identical(localAttachmentPath, _unset)
            ? this.localAttachmentPath
            : localAttachmentPath as String?,
        uploadProgress: identical(uploadProgress, _unset)
            ? this.uploadProgress
            : uploadProgress as double?,
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