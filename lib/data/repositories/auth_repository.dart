import 'package:dio/dio.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/student_user.dart';

/// Result of student login.
class AuthSession {
  final StudentUser user;
  final String token;

  const AuthSession({required this.user, required this.token});
}

class AuthRepository {
  final ApiClient _client;

  AuthRepository(this._client);

  /// POST /api/student/auth/password
  /// Authenticates an active student with phone and password (form-data).
  Future<AuthSession> loginWithPassword({
    required String phone,
    required String password,
  }) async {
    final data = await _client.postForm(
      ApiEndpoints.studentLogin,
      {'phone': phone, 'password': password},
    );

    final map = asMap(data) ?? {};
    final token = asString(map['token']);

    // Set token temporarily so profile can be fetched if user payload is omitted.
    if (token.isNotEmpty) {
      _client.setToken(token);
    }

    StudentUser user;
    if (map.containsKey('user') && asMap(map['user']) != null) {
      user = StudentUser.fromJson(asMap(map['user'])!);
    } else {
      try {
        user = await profile();
      } catch (_) {
        user = StudentUser.fromJson(map);
      }
    }

    return AuthSession(user: user, token: token);
  }

  /// GET /api/student/profile
  /// Returns the authenticated student profile.
  Future<StudentUser> profile() async {
    final data = await _client.get(ApiEndpoints.studentProfile);
    final map = asMap(data) ?? {};
    return StudentUser.fromJson(asMap(map['user']) ?? map);
  }

  /// POST /api/student/profile
  /// Updates the authenticated student profile with multipart/form-data.
  Future<StudentUser> updateProfile({
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
    final formMap = <String, dynamic>{};
    void put(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) formMap[key] = value.trim();
    }

    put('name', name);
    put('email', email);
    put('phone', phone);
    put('address', address);
    put('date_of_birth', dateOfBirth);
    put('gender', gender);
    put('blood_group', bloodGroup);
    put('note', note);

    if (photoPath != null && photoPath.isNotEmpty) {
      formMap['avatar'] = await MultipartFile.fromFile(photoPath);
    }

    final form = FormData.fromMap(formMap);
    final data = await _client.postMultipart(ApiEndpoints.studentProfile, form);

    final map = asMap(data) ?? {};
    return StudentUser.fromJson(asMap(map['user']) ?? map);
  }

  /// POST /api/student/auth/logout
  /// Deletes all API tokens belonging to the authenticated student.
  Future<void> logout() async {
    await _client.postForm(ApiEndpoints.studentLogout, {});
    _client.clearToken();
  }
}
