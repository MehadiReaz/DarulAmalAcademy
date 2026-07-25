import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the Sanctum token and a cached copy of the student profile,
/// so the app can open instantly (and offline) on relaunch.
class TokenStorage {
  static const _kToken = 'auth_token';
  static const _kUser = 'auth_user';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> readToken() => _storage.read(key: _kToken);

  Future<void> saveToken(String token) =>
      _storage.write(key: _kToken, value: token);

  Future<Map<String, dynamic>?> readUser() async {
    final raw = await _storage.read(key: _kUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(Map<String, dynamic> user) =>
      _storage.write(key: _kUser, value: jsonEncode(user));

  Future<void> clear() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kUser);
  }
}
