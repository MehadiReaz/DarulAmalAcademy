import '../data/models/dashboard_data.dart';
import '../data/repositories/dashboard_repository.dart';
import 'base_provider.dart';

/// Holds the dashboard data used by the home tab (live card, quick stats, dues).
class DashboardProvider extends BaseProvider {
  final DashboardRepository _repo;

  DashboardProvider(this._repo);

  DashboardData? _data;
  LoadState _state = LoadState.idle;
  String? _error;

  DashboardData? get data => _data;
  LoadState get state => _state;
  String? get error => _error;

  // Convenience accessors
  QuickStats get quickStats => _data?.quickStats ?? const QuickStats();
  bool get isDue => _data?.isDue ?? false;
  double get dueAmount => _data?.dueAmount ?? 0;
  double get totalAmount => _data?.totalAmount ?? 0;
  double get totalDueAmount => _data?.totalDueAmount ?? 0;
  double get paidAmount => _data?.paidAmount ?? 0;
  List<DashboardClass> get todayClasses => _data?.todayClasses ?? [];

  // Newly parsed sections of the dashboard payload. The endpoint has
  // always returned these; the model just wasn't reading them.
  List<DashboardAssignment> get nextAssignments =>
      _data?.nextAssignments ?? const [];
  List<DashboardExam> get upcomingExams => _data?.upcomingExams ?? const [];
  List<DashboardEvent> get upcomingEvents => _data?.upcomingEvents ?? const [];
  List<SubjectAttendance> get attendanceBySubject =>
      _data?.attendanceBySubject ?? const [];
  int get presentClasses => _data?.presentClasses ?? 0;
  int get lateClasses => _data?.lateClasses ?? 0;
  int get absentClasses => _data?.absentClasses ?? 0;

  /// The first ongoing class, if any.
  DashboardClass? get liveClass {
    try {
      return todayClasses.firstWhere((c) => c.isOngoing);
    } catch (_) {
      return null;
    }
  }

  /// The next upcoming class, if any.
  DashboardClass? get nextClass {
    try {
      return todayClasses.firstWhere((c) => c.isUpcoming);
    } catch (_) {
      return null;
    }
  }

  Future<void> load({bool force = false}) async {
    if (_state == LoadState.loading) return;
    if (_state == LoadState.ready && !force) return;

    final result = await guard(
      () => _repo.fetch(),
      onState: (state, err) {
        _state = state;
        _error = err;
      },
    );
    if (result != null) _data = result;
    safeNotify();
  }

  void reset() {
    _data = null;
    _state = LoadState.idle;
    _error = null;
    safeNotify();
  }
}
