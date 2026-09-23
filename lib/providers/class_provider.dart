import '../data/models/class_routine.dart';
import '../data/models/enrolled_course.dart';
import '../data/models/live_session.dart';
import '../data/repositories/class_repository.dart';
import 'base_provider.dart';

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

  LiveSessionBundle? _liveSessions;
  LoadState _liveSessionsState = LoadState.idle;
  String? _liveSessionsError;

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

  LiveSessionBundle? get liveSessions => _liveSessions;
  LoadState get liveSessionsState => _liveSessionsState;
  String? get liveSessionsError => _liveSessionsError;

  bool get hasClassToday => _today.isNotEmpty;

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
      () => _repo.myCourses(),
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
      () => _repo.schedule(),
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

  Future<void> loadLiveSessions({
    bool force = false,
    String? keyword,
    String? status,
    int? page,
  }) async {
    if (_liveSessionsState == LoadState.loading) return;
    if (_liveSessionsState == LoadState.ready && !force) return;

    final result = await guard(
      () => _repo.liveClasses(keyword: keyword, status: status, page: page),
      onState: (state, err) {
        _liveSessionsState = state;
        _liveSessionsError = err;
      },
    );
    if (result != null) _liveSessions = result;
    safeNotify();
  }

  /// Loads canonical course tab: details, assignments, online-class, recordings, syllabus, attendance.
  Future<dynamic> loadCourseTab(
    int batchId,
    String tab, {
    int? page,
    int? perPage,
    String? status,
  }) {
    return _repo.courseTab(
      batchId,
      tab,
      page: page,
      perPage: perPage,
      status: status,
    );
  }

  Future<void> refreshAll() async {
    await Future.wait([
      loadToday(force: true),
      loadUpcoming(force: true),
      loadCourses(force: true),
      loadRoutine(force: true),
      loadLiveSessions(force: true),
      loadBatches(force: true),
    ]);
  }

  void reset() {
    _today = [];
    _upcoming = [];
    _courses = [];
    _batches = [];
    _routine = null;
    _liveSessions = null;
    _todayState = LoadState.idle;
    _upcomingState = LoadState.idle;
    _coursesState = LoadState.idle;
    _routineState = LoadState.idle;
    _batchesState = LoadState.idle;
    _liveSessionsState = LoadState.idle;
    _routineError = null;
    _todayError = null;
    _upcomingError = null;
    _coursesError = null;
    _batchesError = null;
    _liveSessionsError = null;
    safeNotify();
  }
}
