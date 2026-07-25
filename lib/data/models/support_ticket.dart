import '../../core/utils/json_utils.dart';

/// Matches `SupportTicketController@formatTicket`.
///
/// Two quirks in that formatter are worked around here:
///
///  * `is_resolved` is not a column on `support_tickets` (the table has
///    `status`), so the key is always null. Resolution is therefore
///    derived from `status` first and only falls back to the flag.
///  * `admin` is read off a relation that does not exist — the model
///    defines `assignedAdmin()`, not `admin()` — so it is always null.
///    `assigned_admin` is accepted as an alternative key so this keeps
///    working once the backend is corrected.
class SupportTicket {
  final int id;
  final String? ticketNo;
  final String subject;
  final String message;
  final String? priority; // low | medium | high | urgent
  final String? category;

  /// Server-side lifecycle: open | answered | resolved | closed.
  final String? status;
  final bool isResolvedFlag;
  final TicketUser? user;
  final TicketUser? admin;
  final int repliesCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SupportTicket({
    required this.id,
    this.ticketNo,
    required this.subject,
    required this.message,
    this.priority,
    this.category,
    this.status,
    this.isResolvedFlag = false,
    this.user,
    this.admin,
    this.repliesCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final rawAdmin = asMap(json['admin']) ?? asMap(json['assigned_admin']);

    return SupportTicket(
      id: asInt(json['id']),
      ticketNo: asStringOrNull(json['ticket_no']),
      subject: asString(json['subject'], fallback: 'Untitled'),
      message: asString(json['message']),
      priority: asStringOrNull(json['priority']),
      category: asStringOrNull(json['category']),
      status: asStringOrNull(json['status']),
      isResolvedFlag: asBool(json['is_resolved']),
      user: json['user'] == null
          ? null
          : TicketUser.fromJson(asMap(json['user']) ?? {}),
      admin: rawAdmin == null ? null : TicketUser.fromJson(rawAdmin),
      repliesCount: asInt(json['replies_count']),
      createdAt: asDate(json['created_at']),
      updatedAt: asDate(json['updated_at']),
    );
  }

  String get _normalisedStatus => (status ?? '').trim().toLowerCase();

  bool get isResolved =>
      isResolvedFlag ||
      _normalisedStatus == 'resolved' ||
      _normalisedStatus == 'closed';

  bool get isAnswered =>
      !isResolved && (_normalisedStatus == 'answered' || repliesCount > 0);

  /// Human label shown on the tile and detail header.
  String get statusLabel {
    if (isResolved) {
      return _normalisedStatus == 'closed' ? 'Closed' : 'Resolved';
    }
    if (isAnswered) return 'Answered';
    if (_normalisedStatus.isNotEmpty) {
      return _normalisedStatus[0].toUpperCase() + _normalisedStatus.substring(1);
    }
    return 'Open';
  }

  /// Title-cased priority for display, e.g. "High". Null when unset.
  String? get priorityLabel {
    final p = priority?.trim();
    if (p == null || p.isEmpty) return null;
    return p[0].toUpperCase() + p.substring(1).toLowerCase();
  }

  bool get isHighPriority {
    final p = priority?.toLowerCase();
    return p == 'high' || p == 'urgent';
  }
}

class TicketUser {
  final int? id;
  final String? name;
  final String? email;
  final String? role;

  const TicketUser({this.id, this.name, this.email, this.role});

  factory TicketUser.fromJson(Map<String, dynamic> json) => TicketUser(
        id: asIntOrNull(json['id']),
        name: asStringOrNull(json['name']),
        email: asStringOrNull(json['email']),
        role: asStringOrNull(json['role']),
      );

  bool get isAdmin => role?.toLowerCase() == 'admin';
}

/// Matches `SupportTicketController@formatReply`.
class TicketReply {
  final int id;
  final String message;
  final TicketUser? user;
  final DateTime? createdAt;

  const TicketReply({
    required this.id,
    required this.message,
    this.user,
    this.createdAt,
  });

  factory TicketReply.fromJson(Map<String, dynamic> json) => TicketReply(
        id: asInt(json['id']),
        message: asString(json['message']),
        user: json['user'] == null
            ? null
            : TicketUser.fromJson(asMap(json['user']) ?? {}),
        createdAt: asDate(json['created_at']),
      );

  /// Replies can currently only be authored by admins, but the `role` on
  /// the payload is the source of truth rather than that assumption.
  bool get fromAdmin => user?.isAdmin ?? false;
}

/// Bundle returned by `GET /tickets/{id}`.
class TicketDetail {
  final SupportTicket ticket;
  final List<TicketReply> replies;

  const TicketDetail({required this.ticket, this.replies = const []});
}
