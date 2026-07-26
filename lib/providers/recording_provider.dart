import '../core/network/api_exception.dart';
import '../data/models/pagination.dart';
import '../data/models/recording.dart';
import '../data/repositories/recording_repository.dart';
import 'base_provider.dart';

class RecordingProvider extends BaseProvider {
  final RecordingRepository _repo;

  RecordingProvider(this._repo);

  List<Recording> _items = [];
  Pagination _page = const Pagination();
  LoadState _state = LoadState.idle;
  String? _error;
  bool _loadingMore = false;

  List<Recording> get items => _items;
  LoadState get state => _state;
  String? get error => _error;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _page.hasMore;

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
      _items = result.items;
      _page = result.pagination;
    }
    safeNotify();
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_page.hasMore) return;
    _loadingMore = true;
    safeNotify();
    try {
      final result = await _repo.list(page: _page.nextPage);
      _items = [..._items, ...result.items];
      _page = result.pagination;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loadingMore = false;
      safeNotify();
    }
  }

  void reset() {
    _items = [];
    _page = const Pagination();
    _state = LoadState.idle;
    _error = null;
    _loadingMore = false;
    safeNotify();
  }
}
