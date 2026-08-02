import '../core/network/api_exception.dart';
import '../data/models/app_notification.dart';
import '../data/models/pagination.dart';
import '../data/repositories/notification_repository.dart';
import 'base_provider.dart';

/// Backs the notification centre and the unread dot on the home header.
///
/// Unlike notices, read state here is server-side: `POST
/// /auth/notifications/{id}/read` persists, so nothing is mirrored into
/// local storage. The row is flipped optimistically and rolled back if
/// the request fails.
class NotificationProvider extends BaseProvider {
  final NotificationRepository _repo;

  NotificationProvider(this._repo);

  List<AppNotification> _items = [];
  Pagination _pagination = const Pagination();
  LoadState _state = LoadState.idle;
  String? _error;
  bool _loadingMore = false;
  int? _serverUnread;

  List<AppNotification> get items => _items;
  LoadState get state => _state;
  String? get error => _error;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _pagination.hasMore;

  /// Prefers the server's tally — with pagination the loaded rows are
  /// only ever a lower bound.
  int get unreadCount =>
      _serverUnread ?? _items.where((n) => !n.isRead).length;

  Future<void> load({bool force = false}) async {
    if (_state == LoadState.loading) return;
    if (_state == LoadState.ready && !force) return;

    final result = await guard(
      () => _repo.list(page: 1),
      onState: (state, err) {
        _state = state;
        _error = err;
      },
    );

    if (result != null) {
      _items = result.page.items;
      _pagination = result.page.pagination;
      _serverUnread = result.unreadCount;
    }
    safeNotify();
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_pagination.hasMore) return;

    _loadingMore = true;
    safeNotify();

    try {
      final result = await _repo.list(page: _pagination.nextPage);
      _items = [..._items, ...result.page.items];
      _pagination = result.page.pagination;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loadingMore = false;
      safeNotify();
    }
  }

  /// Flips the row locally first so the list responds instantly, then
  /// tells the server. A failure puts the row back rather than leaving
  /// the badge lying about what has been read.
  Future<bool> markRead(String id) async {
    final index = _items.indexWhere((n) => n.id == id);
    if (index < 0 || _items[index].isRead) return true;

    _items = [..._items];
    _items[index] = _items[index].copyWith(isRead: true);
    if (_serverUnread != null && _serverUnread! > 0) _serverUnread = _serverUnread! - 1;
    safeNotify();

    try {
      await _repo.markRead(id);
      return true;
    } on ApiException catch (e) {
      _items = [..._items];
      _items[index] = _items[index].copyWith(isRead: false);
      if (_serverUnread != null) _serverUnread = _serverUnread! + 1;
      _error = e.message;
      safeNotify();
      return false;
    }
  }

  /// Marks every loaded unread row. There is no bulk endpoint, so this is
  /// one request per row — fired sequentially to avoid opening a dozen
  /// connections at once.
  Future<void> markAllRead() async {
    final unread = _items.where((n) => !n.isRead).map((n) => n.id).toList();
    for (final id in unread) {
      await markRead(id);
    }
  }

  void reset() {
    _items = [];
    _pagination = const Pagination();
    _state = LoadState.idle;
    _error = null;
    _loadingMore = false;
    _serverUnread = null;
    safeNotify();
  }
}
