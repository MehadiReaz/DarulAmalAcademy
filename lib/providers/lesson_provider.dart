import '../core/network/api_exception.dart';
import '../data/models/lesson.dart';
import '../data/models/pagination.dart';
import '../data/repositories/lesson_repository.dart';
import 'base_provider.dart';

/// Backs the Lessons screen (`GET /student/my-lessons`).
class LessonProvider extends BaseProvider {
  final LessonRepository _repo;

  LessonProvider(this._repo);

  List<Lesson> _items = [];
  Pagination _pagination = const Pagination();
  LoadState _state = LoadState.idle;
  String? _error;
  bool _loadingMore = false;

  List<Lesson> get items => _items;
  LoadState get state => _state;
  String? get error => _error;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _pagination.hasMore;

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
      _items = [..._items, ...result.items];
      _pagination = result.pagination;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loadingMore = false;
      safeNotify();
    }
  }

  void reset() {
    _items = [];
    _pagination = const Pagination();
    _state = LoadState.idle;
    _error = null;
    _loadingMore = false;
    safeNotify();
  }
}
