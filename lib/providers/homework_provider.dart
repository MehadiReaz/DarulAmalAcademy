import '../core/network/api_exception.dart';
import '../data/models/homework.dart';
import '../data/repositories/homework_repository.dart';
import 'base_provider.dart';

/// Backs the homework list and detail screens.
///
/// The list endpoint is not paginated, so this holds a single list and
/// re-fetches when the filter changes.
class HomeworkProvider extends BaseProvider {
  final HomeworkRepository _repo;

  HomeworkProvider(this._repo);

  List<Homework> _items = [];
  LoadState _listState = LoadState.idle;
  String? _listError;
  HomeworkFilter _filter = HomeworkFilter.all;

  HomeworkDetail? _detail;
  LoadState _detailState = LoadState.idle;
  String? _detailError;

  bool _submitting = false;
  String? _submitError;

  List<Homework> get items => _items;
  LoadState get listState => _listState;
  String? get listError => _listError;
  HomeworkFilter get filter => _filter;

  HomeworkDetail? get detail => _detail;
  LoadState get detailState => _detailState;
  String? get detailError => _detailError;

  bool get submitting => _submitting;
  String? get submitError => _submitError;

  int get pendingCount => _items.where((h) => h.isPending).length;
  int get overdueCount => _items.where((h) => h.showAsOverdue).length;

  Future<void> load({bool force = false}) async {
    if (_listState == LoadState.loading) return;
    if (_listState == LoadState.ready && !force) return;

    final result = await guard(
      () => _repo.list(filter: _filter),
      onState: (state, err) {
        _listState = state;
        _listError = err;
      },
    );
    if (result != null) _items = result;
    safeNotify();
  }

  /// Switching filter always refetches — the server does the filtering.
  Future<void> setFilter(HomeworkFilter filter) async {
    if (_filter == filter) return;
    _filter = filter;
    _listState = LoadState.idle;
    safeNotify();
    await load(force: true);
  }

  Future<void> loadDetail(int id) async {
    _detail = null;
    _submitError = null;
    final result = await guard(
      () => _repo.detail(id),
      onState: (state, err) {
        _detailState = state;
        _detailError = err;
      },
    );
    if (result != null) _detail = result;
    safeNotify();
  }

  /// Returns true on success. On success the detail is refetched so the
  /// screen shows the server's view of the submission, and the matching
  /// list row is flipped to `submitted` without a full list reload.
  Future<bool> submit({
    required int id,
    String? text,
    String? audioPath,
  }) async {
    _submitting = true;
    _submitError = null;
    safeNotify();

    try {
      await _repo.submit(id: id, text: text, audioPath: audioPath);

      final idx = _items.indexWhere((h) => h.id == id);
      if (idx >= 0) {
        final old = _items[idx];
        _items = [..._items];
        _items[idx] = Homework(
          id: old.id,
          title: old.title,
          description: old.description,
          subject: old.subject,
          teacher: old.teacher,
          assignedDate: old.assignedDate,
          dueDate: old.dueDate,
          submissionStatus: 'submitted',
          submittedAt: DateTime.now(),
          marks: old.marks,
          attachment: old.attachment,
          isOverdue: false,
        );
      }

      await loadDetail(id);
      return true;
    } on ArgumentError catch (e) {
      _submitError = e.message?.toString() ?? 'Nothing to submit.';
      return false;
    } on ApiException catch (e) {
      _submitError = e.message;
      return false;
    } finally {
      _submitting = false;
      safeNotify();
    }
  }

  void reset() {
    _items = [];
    _listState = LoadState.idle;
    _listError = null;
    _filter = HomeworkFilter.all;
    _detail = null;
    _detailState = LoadState.idle;
    _detailError = null;
    _submitting = false;
    _submitError = null;
    safeNotify();
  }
}
