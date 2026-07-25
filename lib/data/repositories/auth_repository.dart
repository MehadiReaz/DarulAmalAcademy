import 'package:dio/dio.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/student_user.dart';

/// Result of POST /auth/send-otp
class OtpSendResult {
  /// The server-normalised phone number — use THIS when verifying,
  /// not the raw text the user typed.
  final String phone;
  final int expiresIn;
  final int cooldown;
  final String? driver;

  /// Only present while the backend runs in dev/log driver mode.
  final String? devOtp;

  const OtpSendResult({
    required this.phone,
    this.expiresIn = 0,
    this.cooldown = 0,
    this.driver,
    this.devOtp,
  });

  factory OtpSendResult.fromJson(Map<String, dynamic> json) => OtpSendResult(
        phone: asString(json['phone']),
        expiresIn: asInt(json['expires_in']),
        cooldown: asInt(json['cooldown']),
        driver: asStringOrNull(json['driver']),
        devOtp: asStringOrNull(json['otp']),
      );
}

/// Result of POST /auth/verify-otp
class AuthSession {
  final StudentUser user;
  final String token;

  const AuthSession({required this.user, required this.token});
}

class AuthRepository {
  final ApiClient _client;

  AuthRepository(this._client);

  /// POST /auth/send-otp  { phone }
  Future<OtpSendResult> sendOtp(String phone) async {
    final data = await _client.post(
      ApiEndpoints.sendOtp,
      body: {'phone': phone},
    );
    return OtpSendResult.fromJson(asMap(data) ?? {});
  }

  /// POST /auth/verify-otp  { phone, otp }  ->  { user, token }
  Future<AuthSession> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final data = await _client.post(
      ApiEndpoints.verifyOtp,
      body: {'phone': phone, 'otp': otp},
    );

    final map = asMap(data) ?? {};
    return AuthSession(
      user: StudentUser.fromJson(asMap(map['user']) ?? {}),
      token: asString(map['token']),
    );
  }

  /// GET /auth/student/profile  ->  { user }
  Future<StudentUser> profile() async {
    final data = await _client.get(ApiEndpoints.studentProfile);
    final map = asMap(data) ?? {};
    return StudentUser.fromJson(asMap(map['user']) ?? map);
  }

  /// PUT /auth/student/profile  ->  { user }
  ///
  /// When [photoPath] is given we must POST with `_method: PUT`, because
  /// PHP does not populate multipart bodies on real PUT requests.
  Future<StudentUser> updateProfile({
    String? name,
    String? phone,
    String? address,
    String? dateOfBirth,
    String? gender,
    String? bloodGroup,
    String? photoPath,
  }) async {
    final fields = <String, dynamic>{};
    void put(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) fields[key] = value.trim();
    }

    put('name', name);
    put('phone', phone);
    put('address', address);
    put('date_of_birth', dateOfBirth);
    put('gender', gender);
    put('blood_group', bloodGroup);

    dynamic data;

    if (photoPath != null && photoPath.isNotEmpty) {
      final form = FormData.fromMap({
        ...fields,
        '_method': 'PUT',
        'photo': await MultipartFile.fromFile(photoPath),
      });
      data = await _client.postMultipart(ApiEndpoints.studentProfile, form);
    } else {
      data = await _client.put(ApiEndpoints.studentProfile, body: fields);
    }

    final map = asMap(data) ?? {};
    return StudentUser.fromJson(asMap(map['user']) ?? map);
  }

  /// POST /auth/refresh -> issues a NEW Sanctum token (requires a valid one).
  /// This cannot rescue an expired session — see notes in AuthProvider.
  Future<AuthSession> refresh() async {
    final data = await _client.post(ApiEndpoints.refresh);
    final map = asMap(data) ?? {};
    return AuthSession(
      user: StudentUser.fromJson(asMap(map['user']) ?? {}),
      token: asString(map['token']),
    );
  }

  /// POST /auth/logout — revokes all tokens for the user.
  Future<void> logout() async {
    await _client.post(ApiEndpoints.logout);
  }

  /// POST /auth/forgot-password { email_or_phone }
  Future<void> forgotPassword(String emailOrPhone) async {
    await _client.post(
      ApiEndpoints.forgotPassword,
      body: {'email_or_phone': emailOrPhone},
    );
  }

  /// POST /auth/reset-password { email_or_phone, token, password, ... }
  Future<void> resetPassword({
    required String emailOrPhone,
    required String token,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _client.post(ApiEndpoints.resetPassword, body: {
      'email_or_phone': emailOrPhone,
      'token': token,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
  }
}
