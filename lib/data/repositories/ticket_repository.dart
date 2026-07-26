import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/pagination.dart';
import '../models/support_ticket.dart';

class TicketRepository {
  final ApiClient _client;

  TicketRepository(this._client);

  /// GET /student/tickets  ->  raw Laravel paginator in `data`.
  ///
  /// CHANGED: this used to be `GET /tickets` returning a custom
  /// `{ tickets: [...], pagination: {...} }` envelope. The route moved
  /// under `/student` and now returns a standard paginator, so items come
  /// from `data.data` and page info from the root.
  Future<Paginated<SupportTicket>> list({int page = 1}) async {
    final data = await _client.get(ApiEndpoints.tickets, query: {'page': page});
    final map = asMap(data) ?? {};

    return Paginated(
      // `tickets` is still read as a fallback so a rollback of the
      // backend change doesn't break the list.
      items: asList(map['data'] ?? map['tickets'], SupportTicket.fromJson),
      pagination: Pagination.fromEnvelope(map),
    );
  }

  /// POST /student/tickets  { category, priority, subject, message }
  ///
  /// Confirmed working (201) as of the 26 Jul run — `category` is now
  /// required and persisted, and the response is the created ticket at
  /// the root of `data` rather than wrapped in a `ticket` key.
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

  /// GET /student/tickets/{id}
  ///
  /// Handles both envelopes: the older `{ ticket, replies: [...] }` and
  /// the flat ticket-with-nested-replies that `POST /student/tickets` now
  /// returns. The detail endpoint 500'd during the 26 Jul run, so which
  /// one it settles on is unconfirmed.
  Future<TicketDetail> show(int id) async {
    final data = await _client.get(ApiEndpoints.ticket(id));
    final map = asMap(data) ?? {};

    final ticketMap = asMap(map['ticket']) ?? map;
    final repliesRaw = map['replies'] ?? ticketMap['replies'];

    return TicketDetail(
      ticket: SupportTicket.fromJson(ticketMap),
      replies: asList(repliesRaw, TicketReply.fromJson),
    );
  }

  /// DELETE /student/tickets/{id}
  Future<void> delete(int id) async {
    await _client.delete(ApiEndpoints.ticket(id));
  }

  /// POST /student/tickets/{id}/reply  { message, attachment? }
  ///
  /// This is now a student-facing route (it sits under `/student` in the
  /// collection), so the app exposes a reply box. It returned 500 in the
  /// 26 Jul run — the same backend fault as the detail endpoint — so the
  /// UI surfaces the failure rather than assuming success.
  Future<TicketReply> reply({required int id, required String message}) async {
    final data = await _client.post(
      ApiEndpoints.ticketReply(id),
      body: {'message': message},
    );
    final map = asMap(data) ?? {};
    return TicketReply.fromJson(asMap(map['reply']) ?? map);
  }
}
