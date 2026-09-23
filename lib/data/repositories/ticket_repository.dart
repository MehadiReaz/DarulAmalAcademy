import 'package:dio/dio.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/pagination.dart';
import '../models/support_ticket.dart';

class SupportContacts {
  final String? adminPhone;
  final String? helpCenterPhone;
  final String? adminWhatsApp;
  final String? helpCenterWhatsApp;
  final String? email;
  final Map<String, dynamic> raw;

  const SupportContacts({
    this.adminPhone,
    this.helpCenterPhone,
    this.adminWhatsApp,
    this.helpCenterWhatsApp,
    this.email,
    this.raw = const {},
  });

  factory SupportContacts.fromJson(Map<String, dynamic> json) {
    return SupportContacts(
      adminPhone: asStringOrNull(json['admin_phone'] ?? json['phone']),
      helpCenterPhone: asStringOrNull(json['help_center_phone'] ?? json['support_phone']),
      adminWhatsApp: asStringOrNull(json['admin_whatsapp'] ?? json['whatsapp']),
      helpCenterWhatsApp: asStringOrNull(json['help_center_whatsapp']),
      email: asStringOrNull(json['email']),
      raw: json,
    );
  }
}

class TicketRepository {
  final ApiClient _client;

  TicketRepository(this._client);

  /// GET /api/student/support
  /// Returns Admin Support and Help Center WhatsApp contacts.
  Future<SupportContacts> contacts() async {
    final data = await _client.get(ApiEndpoints.studentSupportContacts);
    final map = asMap(data) ?? {};
    return SupportContacts.fromJson(map);
  }

  /// GET /api/student/tickets
  Future<Paginated<SupportTicket>> list({
    int page = 1,
    int? perPage,
    String? status,
    String? category,
    String? keyword,
  }) async {
    final query = <String, dynamic>{'page': page};
    if (perPage != null) query['per_page'] = perPage;
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (category != null && category.isNotEmpty) query['category'] = category;
    if (keyword != null && keyword.isNotEmpty) query['keyword'] = keyword;

    final data = await _client.get(
      ApiEndpoints.studentTickets,
      query: query,
    );
    final map = asMap(data) ?? {};

    return Paginated(
      items: asList(map['data'] ?? map['tickets'], SupportTicket.fromJson),
      pagination: Pagination.fromEnvelope(map),
    );
  }

  /// POST /api/student/tickets
  Future<SupportTicket> create({
    required String subject,
    required String message,
    String priority = 'medium',
    String category = 'other',
    String? attachmentPath,
  }) async {
    final formMap = <String, dynamic>{
      'subject': subject,
      'message': message,
      'priority': priority,
      'category': category,
    };

    if (attachmentPath != null && attachmentPath.isNotEmpty) {
      formMap['attachment'] = await MultipartFile.fromFile(attachmentPath);
    }

    final form = FormData.fromMap(formMap);
    final data = await _client.postMultipart(ApiEndpoints.studentTickets, form);
    final map = asMap(data) ?? {};
    return SupportTicket.fromJson(asMap(map['ticket']) ?? map);
  }

  /// GET /api/student/tickets/{id}
  Future<TicketDetail> show(int id) async {
    final data = await _client.get(ApiEndpoints.studentTicketDetail(id));
    final map = asMap(data) ?? {};

    final ticketMap = asMap(map['ticket']) ?? map;
    final repliesRaw = map['replies'] ?? ticketMap['replies'];

    return TicketDetail(
      ticket: SupportTicket.fromJson(ticketMap),
      replies: asList(repliesRaw, TicketReply.fromJson),
    );
  }

  /// POST /api/student/tickets/{id}/reply
  Future<TicketReply> reply({
    required int id,
    required String message,
    String? attachmentPath,
  }) async {
    final formMap = <String, dynamic>{'message': message};

    if (attachmentPath != null && attachmentPath.isNotEmpty) {
      formMap['attachment'] = await MultipartFile.fromFile(attachmentPath);
    }

    final form = FormData.fromMap(formMap);
    final data = await _client.postMultipart(ApiEndpoints.studentTicketReply(id), form);
    final map = asMap(data) ?? {};
    return TicketReply.fromJson(asMap(map['reply']) ?? map);
  }
}
