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

  List<ClassRoutine> get todayClasses => _today;
  LoadState get todayState => _todayState;
  String? get todayError => _todayError;

  List<ClassRoutine> get upcomingClasses => _upcoming;
  LoadState get upcomingState => _upcomingState;
  String? get upcomingError => _upcomingError;

  List<EnrolledCourse> get courses => _courses;
  LoadState get coursesState => _coursesState;
  String? get coursesError => _coursesError;

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

  /// Pull-to-refresh on the home screen.
  Future<void> refreshAll() async {
    await Future.wait([
      loadToday(force: true),
      loadUpcoming(force: true),
      loadCourses(force: true),
    ]);
  }

  /// Wipe state on logout so the next student doesn't see stale data.
  void reset() {
    _today = [];
    _upcoming = [];
    _courses = [];
    _todayState = LoadState.idle;
    _upcomingState = LoadState.idle;
    _coursesState = LoadState.idle;
    _todayError = null;
    _upcomingError = null;
    _coursesError = null;
    safeNotify();
  }
}
