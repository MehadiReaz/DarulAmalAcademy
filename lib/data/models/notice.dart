import '../../core/utils/json_utils.dart';

/// Matches `NoticeBoardController@studentNoticeList` and
/// `@studentNoticeDetails`.
///
/// {
///   "id": 1, "title": "...", "excerpt": "...", "type": "General",
///   "publish_date": "2026-03-24", "priority": "Normal",
///   "attachment": "...", "is_read": false, "created_at": "..."
/// }
///
/// NOTE: the backend always sends `is_read: false` — there is no
/// `notice_reads` table yet — so the app tracks read state locally and
/// overlays it via [copyWith]. See `ReadStateStorage`.
class Notice {
  final int id;
  final String title;
  final String? excerpt;
  final String? description;
  final String type; // General, Batch, Course, etc.
  final String? publishDate;
  final String? expiryDate;
  final String priority; // High, Normal
  final String? attachment;
  final List<String> attachments;
  final bool isRead;
  final DateTime? createdAt;

  const Notice({
    required this.id,
    required this.title,
    this.excerpt,
    this.description,
    this.type = 'General',
    this.publishDate,
    this.expiryDate,
    this.priority = 'Normal',
    this.attachment,
    this.attachments = const [],
    this.isRead = false,
    this.createdAt,
  });

  factory Notice.fromJson(Map<String, dynamic> json) => Notice(
        id: asInt(json['id']),
        title: asString(json['title'], fallback: 'Notice'),
        excerpt: asStringOrNull(json['excerpt']),
        description: asStringOrNull(json['description']),
        type: asString(json['type'], fallback: 'General'),
        publishDate: asStringOrNull(json['publish_date']),
        expiryDate: asStringOrNull(json['expiry_date']),
        priority: asString(json['priority'], fallback: 'Normal'),
        attachment: asStringOrNull(json['attachment']),
        attachments: _parseAttachments(json['attachments']),
        isRead: asBool(json['is_read']),
        createdAt: asDate(json['created_at']),
      );

  /// Replaces the hand-rolled field-by-field rebuild that used to live in
  /// `NoticeProvider.markRead`, where adding a field to this model meant
  /// silently dropping it during a read-state update.
  Notice copyWith({
    String? title,
    String? excerpt,
    String? description,
    String? type,
    String? publishDate,
    String? expiryDate,
    String? priority,
    String? attachment,
    List<String>? attachments,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return Notice(
      id: id,
      title: title ?? this.title,
      excerpt: excerpt ?? this.excerpt,
      description: description ?? this.description,
      type: type ?? this.type,
      publishDate: publishDate ?? this.publishDate,
      expiryDate: expiryDate ?? this.expiryDate,
      priority: priority ?? this.priority,
      attachment: attachment ?? this.attachment,
      attachments: attachments ?? this.attachments,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isPinned => priority == 'High';
  bool get hasAttachment => attachment != null && attachment!.isNotEmpty;

  /// Every attachment URL for this notice, de-duplicated.
  ///
  /// The list endpoint returns a single `attachment` string while the
  /// detail endpoint returns an `attachments` array, so both are merged.
  List<String> get allAttachments {
    final urls = <String>{...attachments};
    if (hasAttachment) urls.add(attachment!);
    return urls.toList();
  }

  static List<String> _parseAttachments(dynamic v) {
    if (v is List) {
      return v
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
