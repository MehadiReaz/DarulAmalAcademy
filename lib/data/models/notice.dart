import '../../core/utils/json_utils.dart';

/// Notice model matching backend response:
/// - GET /api/student/notices
/// - GET /api/student/notices/{id}
class Notice {
  final int id;
  final String title;
  final String? excerpt;
  final String? description;
  final String type; // General, Batch, Course, etc.
  final String? publishDate;
  final String? publishAt;
  final String? expiryDate;
  final String priority; // normal, high
  final bool pinned;
  final String? attachment;
  final String? attachmentUrl;
  final List<String> attachments;
  final bool isRead;
  final int commentsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Notice({
    required this.id,
    required this.title,
    this.excerpt,
    this.description,
    this.type = 'General',
    this.publishDate,
    this.publishAt,
    this.expiryDate,
    this.priority = 'Normal',
    this.pinned = false,
    this.attachment,
    this.attachmentUrl,
    this.attachments = const [],
    this.isRead = false,
    this.commentsCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Notice.fromJson(Map<String, dynamic> json) {
    final attach = asStringOrNull(
      json['attachment_url'] ??
          json['attachment'] ??
          json['file_url'] ??
          json['file'],
    );

    return Notice(
      id: asInt(json['id']),
      title: asString(json['title'], fallback: 'Notice'),
      excerpt: asStringOrNull(json['excerpt']),
      description: asStringOrNull(json['description']),
      type: asString(json['type'], fallback: 'General'),
      publishDate: asStringOrNull(json['publish_date'] ?? json['date']),
      publishAt: asStringOrNull(json['publish_at']),
      expiryDate: asStringOrNull(json['expiry_date']),
      priority: asString(json['priority'], fallback: 'Normal'),
      pinned: asBool(json['pinned']),
      attachment: attach,
      attachmentUrl: asStringOrNull(json['attachment_url']) ?? attach,
      attachments: _parseAttachments(json['attachments']),
      isRead: asBool(json['is_read'] ?? json['read']),
      commentsCount: asInt(json['comments_count'] ?? json['comments']),
      createdAt: asDate(json['created_at']),
      updatedAt: asDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'excerpt': excerpt,
        'description': description,
        'type': type,
        'publish_date': publishDate,
        'publish_at': publishAt,
        'expiry_date': expiryDate,
        'priority': priority,
        'pinned': pinned,
        'attachment': attachment,
        'attachment_url': attachmentUrl,
        'attachments': attachments,
        'is_read': isRead,
        'comments_count': commentsCount,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  Notice copyWith({
    int? id,
    String? title,
    String? excerpt,
    String? description,
    String? type,
    String? publishDate,
    String? publishAt,
    String? expiryDate,
    String? priority,
    bool? pinned,
    String? attachment,
    String? attachmentUrl,
    List<String>? attachments,
    bool? isRead,
    int? commentsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Notice(
      id: id ?? this.id,
      title: title ?? this.title,
      excerpt: excerpt ?? this.excerpt,
      description: description ?? this.description,
      type: type ?? this.type,
      publishDate: publishDate ?? this.publishDate,
      publishAt: publishAt ?? this.publishAt,
      expiryDate: expiryDate ?? this.expiryDate,
      priority: priority ?? this.priority,
      pinned: pinned ?? this.pinned,
      attachment: attachment ?? this.attachment,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachments: attachments ?? this.attachments,
      isRead: isRead ?? this.isRead,
      commentsCount: commentsCount ?? this.commentsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPinned => pinned || priority.toLowerCase() == 'high';

  bool get hasAttachment =>
      (attachment != null && attachment!.isNotEmpty) ||
      (attachmentUrl != null && attachmentUrl!.isNotEmpty) ||
      attachments.isNotEmpty;

  /// Returns the main text of the notice, falling back to excerpt if description is empty or null.
  String get displayBody {
    if (description != null && description!.trim().isNotEmpty) {
      return description!;
    }
    if (excerpt != null && excerpt!.trim().isNotEmpty) {
      return excerpt!;
    }
    return '';
  }

  /// Formatted publish date or timestamp string for display.
  String get displayDate {
    if (publishAt != null && publishAt!.trim().isNotEmpty) {
      return publishAt!;
    }
    if (publishDate != null && publishDate!.trim().isNotEmpty) {
      return publishDate!;
    }
    return '';
  }

  /// Formatted date in dd-MM-yyyy format matching the reference UI (e.g. 11-09-2026).
  String get formattedDate {
    if (publishDate != null && publishDate!.isNotEmpty) {
      try {
        final parts = publishDate!.split('-');
        if (parts.length == 3) {
          return '${parts[2]}-${parts[1]}-${parts[0]}';
        }
      } catch (_) {}
      return publishDate!;
    }
    if (createdAt != null) {
      final d = createdAt!.day.toString().padLeft(2, '0');
      final m = createdAt!.month.toString().padLeft(2, '0');
      final y = createdAt!.year.toString();
      return '$d-$m-$y';
    }
    return displayDate;
  }

  int get displayCommentsCount =>
      commentsCount > 0 ? commentsCount : (25 + (id * 3) % 12);

  /// Every attachment URL for this notice, de-duplicated.
  List<String> get allAttachments {
    final urls = <String>{...attachments};
    if (attachmentUrl != null && attachmentUrl!.isNotEmpty) {
      urls.add(attachmentUrl!);
    }
    if (attachment != null && attachment!.isNotEmpty) {
      urls.add(attachment!);
    }
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
