import '../data/models/attendance.dart';
import '../data/repositories/attendance_repository.dart';
import 'base_provider.dart';

class AttendanceProvider extends BaseProvider {
  final AttendanceRepository _repo;

  AttendanceProvider(this._repo);

  List<SubjectAttendanceGroup> _groups = [];
  LoadState _state = LoadState.idle;
  String? _error;

  List<SubjectAttendanceGroup> get groups => _groups;
  LoadState get state => _state;
  String? get error => _error;

  AttendanceSummary get summary => AttendanceSummary.from(_groups);

  /// Subjects the student is doing worst in, for the "needs attention"
  /// strip. Only subjects with at least two recorded classes count, so a
  /// single absence doesn't dominate.
  List<SubjectAttendanceGroup> get weakest {
    final eligible = _groups.where((g) => g.total >= 2).toList()
      ..sort((a, b) => a.fraction.compareTo(b.fraction));
    return eligible.where((g) => g.percentage < 75).take(3).toList();
  }

  Future<void> load({bool force = false}) async {
    if (_state == LoadState.loading) return;
    if (_state == LoadState.ready && !force) return;

    final result = await guard(
      () => _repo.myAttendances(),
      onState: (state, err) {
        _state = state;
        _error = err;
      },
    );
    if (result != null) _groups = result;
    safeNotify();
  }

  void reset() {
    _groups = [];
    _state = LoadState.idle;
    _error = null;
    safeNotify();
  }
}
