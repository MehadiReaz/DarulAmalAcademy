import '../data/models/support_contact.dart';
import '../data/repositories/support_repository.dart';
import 'base_provider.dart';

/// Support contacts for the floating WhatsApp button. Fetched on first
/// tap and kept for the session.
class SupportProvider extends BaseProvider {
  final SupportRepository _repo;

  SupportProvider(this._repo);

  List<SupportContact> _contacts = const [];
  LoadState _state = LoadState.idle;
  String? _error;

  List<SupportContact> get contacts => _contacts;
  LoadState get state => _state;
  String? get error => _error;

  Future<void> load({bool force = false}) async {
    if (_state == LoadState.loading) return;
    if (_state == LoadState.ready && !force) return;

    final result = await guard(
      _repo.contacts,
      onState: (state, err) {
        _state = state;
        _error = err;
      },
    );
    if (result != null) _contacts = result;
    safeNotify();
  }

  void reset() {
    _contacts = const [];
    _state = LoadState.idle;
    _error = null;
    safeNotify();
  }
}
