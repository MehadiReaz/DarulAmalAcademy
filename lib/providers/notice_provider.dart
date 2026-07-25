import '../core/network/api_exception.dart';
import '../core/storage/read_state_storage.dart';
import '../data/models/notice.dart';
import '../data/models/pagination.dart';
import '../data/repositories/notice_repository.dart';
import 'base_provider.dart';

/// Manages the notice list (paginated) and single-notice detail.
///
/// Read state is maintained locally: the backend's `is_read` is always
/// false and `POST /student/notices/{id}/read` does not persist anything,
/// so every notice coming off the wire is overlaid with the locally
/// stored set of IDs the student has already opened.
class NoticeProvider extends BaseProvider {
  final NoticeRepository _repo;
  final ReadStateStorage _readState;

  NoticeProvider(this._repo, this._readState);

  List<Notice> _notices = [];
  Pagination _pagination = const Pagination();
  LoadState _listState = LoadState.idle;
  String? _listError;
  bool _loadingMore = false;

  /// Cached in memory so list rendering never has to await storage.
  Set<int> _readIds = <int>{};
  bool _readIdsLoaded = false;

  Notice? _detail;
  LoadState _detailState = LoadState.idle;
  String? _detailError;

  List<Notice> get notices => _notices;
  LoadState get listState => _listState;
  String? get listError => _listError;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _pagination.hasMore;

  Notice? get detail => _detail;
  LoadState get detailState => _detailState;
  String? get detailError => _detailError;

  /// Drives the unread badge on the Notice tab.
  int get unreadCount => _notices.where((n) => !n.isRead).length;

  Future<void> _ensureReadIds() async {
    if (_readIdsLoaded) return;
    _readIds = await _readState.readNoticeIds();
    _readIdsLoaded = true;
  }

  List<Notice> _applyReadState(List<Notice> items) {
    if (_readIds.isEmpty) return items;
    return items
        .map((n) => _readIds.contains(n.id) ? n.copyWith(isRead: true) : n)
        .toList();
  }

  Future<void> loadNotices({bool force = false}) async {
    if (_listState == LoadState.loading) return;
    if (_listState == LoadState.ready && !force) return;

    await _ensureReadIds();

    final result = await guard(
      () => _repo.list(page: 1),
      onState: (state, err) {
        _listState = state;
        _listError = err;
      },
    );

    if (result != null) {
      _notices = _applyReadState(result.items);
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
      _notices = [..._notices, ..._applyReadState(result.items)];
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
      () => _repo.detail(id),
      onState: (state, err) {
        _detailState = state;
        _detailError = err;
      },
    );
    if (result != null) {
      // The detail payload omits `excerpt`, so carry the list copy's one
      // over — otherwise going back to the list shows an empty preview
      // for any notice that has been opened.
      Notice? existing;
      for (final n in _notices) {
        if (n.id == id) {
          existing = n;
          break;
        }
      }
      _detail = result.copyWith(
        excerpt: result.excerpt ?? existing?.excerpt,
        isRead: true,
      );
    }
    safeNotify();
  }

  /// Marks a notice read locally and tells the server (which currently
  /// ignores it). Local state is updated first so the UI is correct even
  /// if the request fails or the device is offline.
  Future<void> markRead(int id) async {
    await _ensureReadIds();

    if (!_readIds.contains(id)) {
      _readIds = {..._readIds, id};
      await _readState.markNoticeRead(id);
    }

    final idx = _notices.indexWhere((n) => n.id == id);
    if (idx >= 0 && !_notices[idx].isRead) {
      _notices = [..._notices];
      _notices[idx] = _notices[idx].copyWith(isRead: true);
      safeNotify();
    }

    try {
      await _repo.markRead(id);
    } on ApiException catch (_) {
      // Non-fatal — the local record is what the UI reads from.
    }
  }

  void reset() {
    _notices = [];
    _pagination = const Pagination();
    _listState = LoadState.idle;
    _listError = null;
    _detail = null;
    _detailState = LoadState.idle;
    _detailError = null;
    _readIds = <int>{};
    _readIdsLoaded = false;
    // Fire-and-forget: the next student on this device must not inherit
    // the previous one's read markers.
    _readState.clear();
    safeNotify();
  }
}
