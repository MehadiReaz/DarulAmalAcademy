import '../core/network/api_exception.dart';
import '../data/models/class_routine.dart';
import '../data/models/enrolled_course.dart';
import '../data/repositories/class_repository.dart';
import 'base_provider.dart';

/// Holds the three class-related lists. Each section tracks its own
/// state so one failing request doesn't blank the whole screen.
class ClassProvider extends BaseProvider {
  final ClassRepository _repo;

  ClassProvider(this._repo);

  List<ClassRoutine> _today = [];
  LoadState _todayState = LoadState.idle;
  String? _todayError;

  List<ClassRoutine> _upcoming = [];
  LoadState _upcomingState = LoadState.idle;
  String? _upcomingError;

  List<EnrolledCourse> _courses = [];
  LoadState _coursesState = LoadState.idle;
  String? _coursesError;

  ClassRoutineBundle? _routine;
  LoadState _routineState = LoadState.idle;
  String? _routineError;

  List<Map<String, dynamic>> _batches = [];
  LoadState _batchesState = LoadState.idle;
  String? _batchesError;

  List<ClassRoutine> get todayClasses => _today;
  LoadState get todayState => _todayState;
  String? get todayError => _todayError;

  List<ClassRoutine> get upcomingClasses => _upcoming;
  LoadState get upcomingState => _upcomingState;
  String? get upcomingError => _upcomingError;

  List<EnrolledCourse> get courses => _courses;
  LoadState get coursesState => _coursesState;
  String? get coursesError => _coursesError;

  ClassRoutineBundle? get routine => _routine;
  LoadState get routineState => _routineState;
  String? get routineError => _routineError;

  List<Map<String, dynamic>> get batches => _batches;
  LoadState get batchesState => _batchesState;
  String? get batchesError => _batchesError;

  bool get hasClassToday => _today.isNotEmpty;

  /// True when today/upcoming failed but the routine endpoint works.
  ///
  /// The 403s that used to make this permanently true came from calling
  /// `/student/classes/today` — a path that does not exist. The correct
  /// singular paths are now used, so this should only fire on a real
  /// server fault. The Classes tab still falls back to the weekly
  /// routine when it does, rather than showing an error the student can
  /// do nothing about.
  bool get liveEndpointsBlocked =>
      _todayState == LoadState.error && _upcomingState == LoadState.error;

  Future<void> loadToday({bool force = false}) async {
    if (_todayState == LoadState.loading) return;
    if (_todayState == LoadState.ready && !force) return;

    final result = await guard(
      () => _repo.today(),
      onState: (state, err) {
        _todayState = state;
        _todayError = err;
      },
    );
    if (result != null) _today = result;
    safeNotify();
  }

  Future<void> loadUpcoming({bool force = false}) async {
    if (_upcomingState == LoadState.loading) return;
    if (_upcomingState == LoadState.ready && !force) return;

    final result = await guard(
      () => _repo.upcoming(),
      onState: (state, err) {
        _upcomingState = state;
        _upcomingError = err;
      },
    );
    if (result != null) _upcoming = result;
    safeNotify();
  }

  Future<void> loadCourses({bool force = false}) async {
    if (_coursesState == LoadState.loading) return;
    if (_coursesState == LoadState.ready && !force) return;

    final result = await guard(
      () => _repo.myClasses(),
      onState: (state, err) {
        _coursesState = state;
        _coursesError = err;
      },
    );
    if (result != null) _courses = result;
    safeNotify();
  }

  Future<void> loadRoutine({bool force = false}) async {
    if (_routineState == LoadState.loading) return;
    if (_routineState == LoadState.ready && !force) return;

    final result = await guard(
      () => _repo.routine(),
      onState: (state, err) {
        _routineState = state;
        _routineError = err;
      },
    );
    if (result != null) _routine = result;
    safeNotify();
  }

  Future<void> loadBatches({bool force = false}) async {
    if (_batchesState == LoadState.loading) return;
    if (_batchesState == LoadState.ready && !force) return;

    final result = await guard(
      () => _repo.myBatches(),
      onState: (state, err) {
        _batchesState = state;
        _batchesError = err;
      },
    );
    if (result != null) _batches = result;
    safeNotify();
  }

  /// Fetches the meeting link for a class. Returns null (and sets no
  /// error state) when the server refuses — the caller surfaces it.
  Future<ClassJoinInfo?> joinInfo(int classId) async {
    try {
      return await _repo.join(classId);
    } on ApiException catch (_) {
      return null;
    }
  }

  /// Pull-to-refresh on the home screen.
  Future<void> refreshAll() async {
    await Future.wait([
      loadToday(force: true),
      loadUpcoming(force: true),
      loadCourses(force: true),
      loadRoutine(force: true),
    ]);
  }

  /// Wipe state on logout so the next student doesn't see stale data.
  void reset() {
    _today = [];
    _upcoming = [];
    _courses = [];
    _routine = null;
    _todayState = LoadState.idle;
    _upcomingState = LoadState.idle;
    _coursesState = LoadState.idle;
    _routineState = LoadState.idle;
    _routineError = null;
    _todayError = null;
    _upcomingError = null;
    _coursesError = null;
    safeNotify();
  }
}
