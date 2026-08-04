import '../data/models/quran_progress.dart';
import '../data/models/student_user.dart';
import '../data/repositories/quran_repository.dart';
import 'base_provider.dart';

/// Backs the Qur'an tab from the dedicated `/student/quran-progress`
/// endpoint, which supersedes the block embedded in the profile payload.
class QuranProvider extends BaseProvider {
  final QuranRepository _repo;

  QuranProvider(this._repo);

  QuranProgressBundle? _bundle;
  LoadState _state = LoadState.idle;
  String? _error;

  QuranProgressBundle? get bundle => _bundle;
  LoadState get state => _state;
  String? get error => _error;

  StudentUser? get student => _bundle?.student;
  QuranProgress? get progress => _bundle?.progress;
  List<QuranProgressLog> get logs => _bundle?.logs ?? const [];
  QuranReferenceData get reference =>
      _bundle?.reference ?? const QuranReferenceData();

  bool get hasProgress => _bundle?.hasProgress ?? false;

  /// Paras completed out of the curriculum's own total, rather than a
  /// hardcoded 30.
  String get paraLabel {
    final done = progress?.parasCompleted ?? 0;
    return '$done of ${reference.totalParas} para complete';
  }

  String get lessonLabel {
    final lesson = progress?.nooraniQaidaLesson;
    if (lesson == null || lesson.isEmpty) return '';
    return 'Lesson $lesson of ${reference.totalLessons}';
  }

  /// Bilingual focus label resolved through the reference table, falling
  /// back to whatever the progress row carried.
  String? get focusLabel {
    final key = progress?.readingFocus;
    if (key != null && key.isNotEmpty) {
      final resolved = reference.focusLabel(key);
      if (resolved.isNotEmpty) return resolved;
    }
    return progress?.readingFocusLabel;
  }

  Future<void> load({bool force = false}) async {
    if (_state == LoadState.loading) return;
    if (_state == LoadState.ready && !force) return;

    final result = await guard(
      () => _repo.progress(),
      onState: (state, err) {
        _state = state;
        _error = err;
      },
    );
    if (result != null) _bundle = result;
    safeNotify();
  }

  void reset() {
    _bundle = null;
    _state = LoadState.idle;
    _error = null;
    safeNotify();
  }
}
