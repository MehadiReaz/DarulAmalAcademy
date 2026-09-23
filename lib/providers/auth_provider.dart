import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/storage/token_storage.dart';
import '../data/models/student_user.dart';
import '../data/repositories/auth_repository.dart';
import 'base_provider.dart';

enum AuthStatus {
  unknown,
  unauthenticated,
  authenticated,
}

class AuthProvider extends BaseProvider {
  final AuthRepository _repo;
  final TokenStorage _storage;
  final ApiClient _client;

  AuthProvider(this._repo, this._storage, this._client) {
    _client.onUnauthorized = _handleUnauthorized;
  }

  AuthStatus _status = AuthStatus.unknown;
  StudentUser? _user;
  bool _busy = false;
  String? _error;

  AuthStatus get status => _status;
  StudentUser? get user => _user;
  bool get busy => _busy;
  String? get error => _error;

  bool get isAuthenticated => _status == AuthStatus.authenticated;

  void clearError() {
    _error = null;
    safeNotify();
  }

  void _setBusy(bool value) {
    _busy = value;
    safeNotify();
  }

  // ------------------------------------------------------------- bootstrap

  Future<void> bootstrap() async {
    final splashTimer = Future.delayed(const Duration(seconds: 2));

    final token = await _storage.readToken();

    if (token == null || token.isEmpty) {
      await splashTimer;
      _status = AuthStatus.unauthenticated;
      safeNotify();
      return;
    }

    _client.setToken(token);

    final cached = await _storage.readUser();
    if (cached != null) {
      _user = StudentUser.fromJson(cached);
    }

    await splashTimer;
    _status = AuthStatus.authenticated;
    safeNotify();

    try {
      final fresh = await _repo.profile();
      _user = _user == null ? fresh : _user!.mergedWith(fresh);
      _status = AuthStatus.authenticated;
      await _storage.saveUser(_user!.toJson());
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _clearSession();
      } else if (_user == null) {
        _status = AuthStatus.unauthenticated;
      }
    }

    safeNotify();
  }

  // ---------------------------------------------------- password login

  Future<bool> loginWithPassword({
    required String phone,
    required String password,
  }) async {
    _setBusy(true);
    _error = null;

    try {
      final session = await _repo.loginWithPassword(
        phone: phone,
        password: password,
      );

      _client.setToken(session.token);
      await _storage.saveToken(session.token);
      await _storage.saveUser(session.user.toJson());

      _user = session.user;
      _status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  // --------------------------------------------------------------- profile

  Future<void> reloadProfile() async {
    try {
      final fresh = await _repo.profile();
      _user = _user == null ? fresh : _user!.mergedWith(fresh);
      await _storage.saveUser(_user!.toJson());
      safeNotify();
    } on ApiException catch (_) {
      // Non-fatal: keep showing whatever we already had.
    }
  }

  Future<bool> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? address,
    String? dateOfBirth,
    String? gender,
    String? bloodGroup,
    String? note,
    String? photoPath,
  }) async {
    _setBusy(true);
    _error = null;

    final targetEmail = (email != null && email.trim().isNotEmpty)
        ? email.trim()
        : _user?.email;

    try {
      await _repo.updateProfile(
        name: name,
        email: targetEmail,
        phone: phone,
        address: address,
        dateOfBirth: dateOfBirth,
        gender: gender,
        bloodGroup: bloodGroup,
        note: note,
        photoPath: photoPath,
      );

      await reloadProfile();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  // ---------------------------------------------------------------- logout

  Future<void> logout() async {
    _setBusy(true);
    try {
      await _repo.logout();
    } on ApiException catch (_) {
      // Even if the call fails we still drop the local session.
    } finally {
      await _clearSession();
      _setBusy(false);
    }
  }

  void _handleUnauthorized() {
    _clearSession();
  }

  Future<void> _clearSession() async {
    _client.clearToken();
    await _storage.clear();
    _user = null;
    _status = AuthStatus.unauthenticated;
    safeNotify();
  }
}
