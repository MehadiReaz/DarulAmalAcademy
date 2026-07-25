import '../core/network/api_exception.dart';
import '../data/models/pagination.dart';
import '../data/models/support_ticket.dart';
import '../data/repositories/ticket_repository.dart';
import 'base_provider.dart';

class TicketProvider extends BaseProvider {
  final TicketRepository _repo;

  TicketProvider(this._repo);

  List<SupportTicket> _tickets = [];
  Pagination _pagination = const Pagination();
  LoadState _listState = LoadState.idle;
  String? _listError;
  bool _loadingMore = false;

  TicketDetail? _detail;
  LoadState _detailState = LoadState.idle;
  String? _detailError;

  bool _submitting = false;
  String? _submitError;

  List<SupportTicket> get tickets => _tickets;
  LoadState get listState => _listState;
  String? get listError => _listError;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _pagination.hasMore;

  TicketDetail? get detail => _detail;
  LoadState get detailState => _detailState;
  String? get detailError => _detailError;

  bool get submitting => _submitting;
  String? get submitError => _submitError;

  Future<void> loadTickets({bool force = false}) async {
    if (_listState == LoadState.loading) return;
    if (_listState == LoadState.ready && !force) return;

    final result = await guard(
      () => _repo.list(page: 1),
      onState: (state, err) {
        _listState = state;
        _listError = err;
      },
    );

    if (result != null) {
      _tickets = result.items;
      _pagination = result.pagination;
    }
    safeNotify();
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_pagination.hasMore) return;

    _loadingMore = true;
    safeNotify();

    try {
      final result = await _repo.list(page: _pagination.nextPage);
      _tickets = [..._tickets, ...result.items];
      _pagination = result.pagination;
    } on ApiException catch (e) {
      _listError = e.message;
    } finally {
      _loadingMore = false;
      safeNotify();
    }
  }

  Future<void> loadDetail(int id) async {
    _detail = null;
    final result = await guard(
      () => _repo.show(id),
      onState: (state, err) {
        _detailState = state;
        _detailError = err;
      },
    );
    if (result != null) _detail = result;
    safeNotify();
  }

  /// Returns the created ticket, or null if it failed.
  Future<SupportTicket?> createTicket({
    required String subject,
    required String message,
    String priority = 'medium',
    String category = 'other',
  }) async {
    _submitting = true;
    _submitError = null;
    safeNotify();

    try {
      final ticket = await _repo.create(
        subject: subject,
        message: message,
        priority: priority,
        category: category,
      );
      // Put it at the top of the list without a full refetch.
      _tickets = [ticket, ..._tickets];
      return ticket;
    } on ApiException catch (e) {
      _submitError = e.message;
      return null;
    } finally {
      _submitting = false;
      safeNotify();
    }
  }

  Future<bool> deleteTicket(int id) async {
    try {
      await _repo.delete(id);
      _tickets = _tickets.where((t) => t.id != id).toList();
      safeNotify();
      return true;
    } on ApiException catch (e) {
      _listError = e.message;
      safeNotify();
      return false;
    }
  }

  void reset() {
    _tickets = [];
    _pagination = const Pagination();
    _listState = LoadState.idle;
    _listError = null;
    _detail = null;
    _detailState = LoadState.idle;
    _detailError = null;
    safeNotify();
  }
}
