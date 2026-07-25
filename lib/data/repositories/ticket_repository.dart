import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/pagination.dart';
import '../models/support_ticket.dart';

class TicketRepository {
  final ApiClient _client;

  TicketRepository(this._client);

  /// GET /tickets  ->  { tickets: [...], pagination: {...} }
  Future<Paginated<SupportTicket>> list({int page = 1}) async {
    final data = await _client.get(ApiEndpoints.tickets, query: {'page': page});
    final map = asMap(data) ?? {};

    return Paginated(
      items: asList(map['tickets'], SupportTicket.fromJson),
      pagination: Pagination.fromJson(asMap(map['pagination']) ?? {}),
    );
  }

  /// POST /tickets  { subject, message, priority?, category? }  ->  { ticket }
  ///
  /// `category` is sent even though `SupportTicketController@store` does
  /// not read it yet. The `support_tickets.category` column is NOT NULL
  /// with no default, so ticket creation currently fails server-side;
  /// sending the value here means the app needs no change once `store()`
  /// starts persisting it. Laravel ignores unvalidated keys, so it is
  /// harmless in the meantime.
  Future<SupportTicket> create({
    required String subject,
    required String message,
    String priority = 'medium',
    String category = 'other',
  }) async {
    final data = await _client.post(ApiEndpoints.tickets, body: {
      'subject': subject,
      'message': message,
      'priority': priority,
      'category': category,
    });

    final map = asMap(data) ?? {};
    return SupportTicket.fromJson(asMap(map['ticket']) ?? map);
  }

  /// GET /tickets/{id}  ->  { ticket, replies: [...] }
  Future<TicketDetail> show(int id) async {
    final data = await _client.get(ApiEndpoints.ticket(id));
    final map = asMap(data) ?? {};

    return TicketDetail(
      ticket: SupportTicket.fromJson(asMap(map['ticket']) ?? {}),
      replies: asList(map['replies'], TicketReply.fromJson),
    );
  }

  /// DELETE /tickets/{id}
  Future<void> delete(int id) async {
    await _client.delete(ApiEndpoints.ticket(id));
  }

  /// POST /tickets/{id}/reply
  ///
  /// NOTE: `SupportTicketController@reply` restricts replies to Admin
  /// users, so this returns 403 for a student. Kept here, and deliberately
  /// not surfaced in the UI, for when that opens up.
  Future<TicketReply> reply({required int id, required String message}) async {
    final data = await _client.post(
      ApiEndpoints.ticketReply(id),
      body: {'message': message},
    );
    final map = asMap(data) ?? {};
    return TicketReply.fromJson(asMap(map['reply']) ?? map);
  }
}
