import '../../core/utils/json_utils.dart';

/// Matches `SupportTicketController@formatTicket`.
class SupportTicket {
  final int id;
  final String subject;
  final String message;
  final String? priority; // low | medium | high | urgent
  final String? status;
  final bool isResolved;
  final TicketUser? user;
  final TicketUser? admin;
  final int repliesCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SupportTicket({
    required this.id,
    required this.subject,
    required this.message,
    this.priority,
    this.status,
    this.isResolved = false,
    this.user,
    this.admin,
    this.repliesCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: asInt(json['id']),
      subject: asString(json['subject'], fallback: 'Untitled'),
      message: asString(json['message']),
      priority: asStringOrNull(json['priority']),
      status: asStringOrNull(json['status']),
      isResolved: asBool(json['is_resolved']),
      user: json['user'] == null
          ? null
          : TicketUser.fromJson(asMap(json['user']) ?? {}),
      admin: json['admin'] == null
          ? null
          : TicketUser.fromJson(asMap(json['admin']) ?? {}),
      repliesCount: asInt(json['replies_count']),
      createdAt: asDate(json['created_at']),
      updatedAt: asDate(json['updated_at']),
    );
  }

  String get statusLabel {
    if (isResolved) return 'Resolved';
    if (status != null && status!.isNotEmpty) return status!;
    return repliesCount > 0 ? 'Answered' : 'Open';
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

  bool get fromAdmin => user?.isAdmin ?? false;
}

/// Bundle returned by `GET /tickets/{id}`.
class TicketDetail {
  final SupportTicket ticket;
  final List<TicketReply> replies;

  const TicketDetail({required this.ticket, this.replies = const []});
}
