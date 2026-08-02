import 'package:darul_amal/core/log/log_hadler.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/storage/token_storage.dart';
import '../data/models/student_user.dart';
import '../data/repositories/auth_repository.dart';
import 'base_provider.dart';

enum AuthStatus {
  /// App just launched — we don't know yet.
  unknown,
  unauthenticated,
  authenticated,
}

class AuthProvider extends BaseProvider {
  final AuthRepository _repo;
  final TokenStorage _storage;
  final ApiClient _client;

  AuthProvider(this._repo, this._storage, this._client) {
    // Sanctum tokens have no refresh flow: if the server ever answers 401,
    // the session is over and we drop straight to the login screen.
    _client.onUnauthorized = _handleUnauthorized;
  }

  AuthStatus _status = AuthStatus.unknown;
  StudentUser? _user;
  bool _busy = false;
  String? _error;

  // --- OTP flow state ---
  String? _pendingPhone;
  int _otpExpiresIn = 0;
  int _resendCooldown = 0;
  String? _devOtp;

  AuthStatus get status => _status;
  StudentUser? get user => _user;
  bool get busy => _busy;
  String? get error => _error;

  String? get pendingPhone => _pendingPhone;
  int get otpExpiresIn => _otpExpiresIn;
  int get resendCooldown => _resendCooldown;

  /// Only non-null while the backend SMS driver is in dev/log mode.
  String? get devOtp => _devOtp;

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

  /// Called once at app start. Restores the token, shows the cached profile
  /// immediately, then silently revalidates against the server.
  Future<void> bootstrap() async {
    final token = await _storage.readToken();

    if (token == null || token.isEmpty) {
      _status = AuthStatus.unauthenticated;
      safeNotify();
      return;
    }

    _client.setToken(token);

    // Show cached user right away so the app doesn't flash a spinner.
    final cached = await _storage.readUser();
    if (cached != null) {
      _user = StudentUser.fromJson(cached);
      _status = AuthStatus.authenticated;
      safeNotify();
    }

    // Revalidate. A 401 here triggers _handleUnauthorized via the interceptor.
    try {
      final fresh = await _repo.profile();
      // Merge rather than replace so a field the profile endpoint happens
      // not to return can never wipe a good cached value.
      _user = _user == null ? fresh : _user!.mergedWith(fresh);
      _status = AuthStatus.authenticated;
      await _storage.saveUser(_user!.toJson());
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _clearSession();
      } else if (_user == null) {
        // Offline with no cache — stay logged in optimistically only if we
        // have a token; otherwise fall back to login.
        _status = AuthStatus.unauthenticated;
      }
    }

    safeNotify();
  }

  // ------------------------------------------------------------- OTP login

  /// Step 1 — request an OTP.
  Future<bool> sendOtp(String phone) async {
    _setBusy(true);
    _error = null;

    try {
      final result = await _repo.sendOtp(phone);
      // Use the server-normalised phone for the verify call.
      _pendingPhone = result.phone.isNotEmpty ? result.phone : phone;
      logger.f("_pendingPhone: $_pendingPhone");
      _otpExpiresIn = result.expiresIn;
      _resendCooldown = result.cooldown;
      _devOtp = result.devOtp;
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  /// Step 2 — verify the code and open a session.
  Future<bool> verifyOtp(String otp) async {
    final phone = _pendingPhone;
    if (phone == null) {
      _error = 'Please request an OTP first.';
      safeNotify();
      return false;
    }

    _setBusy(true);
    _error = null;

    try {
      final session = await _repo.verifyOtp(phone: phone, otp: otp);

      _client.setToken(session.token);
      await _storage.saveToken(session.token);
      await _storage.saveUser(session.user.toJson());

      _user = session.user;
      _status = AuthStatus.authenticated;
      _pendingPhone = null;
      _devOtp = null;
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  // ---------------------------------------------------- password login

  /// Signs in with a phone number and password instead of an OTP.
  ///
  /// Opens exactly the same session as [verifyOtp] — token stored, user
  /// cached, status flipped — so the rest of the app is unaffected by
  /// which route the student used.
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
      _pendingPhone = null;
      _devOtp = null;
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  /// POST /auth/forgot-password — sends a reset link/code.
  Future<bool> forgotPassword(String emailOrPhone) async {
    _setBusy(true);
    _error = null;
    _pendingPhone = emailOrPhone;
    try {
      final devOtp = await _repo.forgotPassword(emailOrPhone);
      _devOtp = devOtp;
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  /// POST /auth/reset-password — resets password with OTP code.
  Future<bool> resetPassword({
    required String emailOrPhone,
    required String token,
    required String password,
    required String passwordConfirmation,
  }) async {
    _setBusy(true);
    _error = null;
    try {
      await _repo.resetPassword(
        emailOrPhone: emailOrPhone,
        token: token,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
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
    String? phone,
    String? address,
    String? dateOfBirth,
    String? gender,
    String? bloodGroup,
    String? photoPath,
  }) async {
    _setBusy(true);
    _error = null;

    try {
      final updated = await _repo.updateProfile(
        name: name,
        phone: phone,
        address: address,
        dateOfBirth: dateOfBirth,
        gender: gender,
        bloodGroup: bloodGroup,
        photoPath: photoPath,
      );

      // The update endpoint answers with the FLAT payload, which carries
      // no phone / address / gender / date_of_birth and no Qur'an data.
      // Applying it verbatim would blank fields the student can see, so
      // merge it over what we already hold instead of replacing.
      final merged = _user == null ? updated : _user!.mergedWith(updated);
      _user = merged;
      await _storage.saveUser(merged.toJson());
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
    // Fire-and-forget; the interceptor cannot await us.
    _clearSession();
  }

  Future<void> _clearSession() async {
    _client.clearToken();
    await _storage.clear();
    _user = null;
    _pendingPhone = null;
    _devOtp = null;
    _status = AuthStatus.unauthenticated;
    safeNotify();
  }
}
