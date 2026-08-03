import 'package:darul_amal/core/log/log_hadler.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/student_user.dart';

/// Result of POST /auth/send-otp
class OtpSendResult {
  /// The phone number echoed back by the server.
  ///
  /// NOTE: despite the name this is the RAW string that was sent, not a
  /// normalised form — `ApiStudentOtpController@send` returns
  /// `$request->phone` and discards the normalised value that `OtpService`
  /// produced. Verification normalises again server-side, so either works;
  /// using this one just keeps client and server talking about the same
  /// input.
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

  /// POST /auth/login-with-password  { phone, password }  ->  { user, token }
  ///
  /// Same session payload as [verifyOtp], so the caller cannot tell which
  /// route opened the session.
  Future<AuthSession> loginWithPassword({
    required String phone,
    required String password,
  }) async {
    final data = await _client.post(
      ApiEndpoints.loginWithPassword,
      body: {'phone': phone, 'password': password},
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

  /// POST /auth/student/profile  ->  { user }
  ///
  /// The photo goes in `files[]` and nowhere else. A MultipartFile wraps a
  /// single-subscription stream, so putting one instance under several keys
  /// throws "already finalized" partway through the upload.
  Future<StudentUser> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? address,
    String? dateOfBirth,
    String? gender,
    String? bloodGroup,
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

    if (photoPath != null && photoPath.isNotEmpty) {
      formMap['avatar'] = await MultipartFile.fromFile(
        photoPath,
        contentType: _imageMediaType(photoPath),
      );
    }

    final form = FormData.fromMap(formMap);

    // Postman's form-data key was `files`; FormData.fromMap may encode a
    // list value as `files[]`, and PHP treats those as different keys.
    // If this logs `files[]` and the upload is ignored, assign the
    // MultipartFile directly instead of wrapping it in a list above.
    logger.i(
      '[API] multipart fields=${form.fields.map((e) => e.key).toList()} '
      'files=${form.files.map((e) => e.key).toList()}',
    );

    final data = await _client.postMultipart(ApiEndpoints.studentProfile, form);

    final map = asMap(data) ?? {};
    return StudentUser.fromJson(asMap(map['user']) ?? map);
  }

  /// `fromFile` labels every part `application/octet-stream`. Postman sends
  /// the real image type, so a backend reading `getClientMimeType()` would
  /// see a mismatch between the two. Returns null for unknown extensions,
  /// which restores Dio's default.
  MediaType? _imageMediaType(String path) {
    final name = path.split(RegExp(r'[\\/]')).last;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;

    const known = {
      'jpg': 'jpeg',
      'jpeg': 'jpeg',
      'png': 'png',
      'gif': 'gif',
      'webp': 'webp',
      'bmp': 'bmp',
      'heic': 'heic',
    };
    final sub = known[name.substring(dot + 1).toLowerCase()];
    return sub == null ? null : MediaType('image', sub);
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
  Future<String?> forgotPassword(String emailOrPhone) async {
    final data = await _client.post(
      ApiEndpoints.forgotPassword,
      body: {'email_or_phone': emailOrPhone, 'phone': emailOrPhone},
    );
    final map = asMap(data);
    return asStringOrNull(map?['otp']) ?? asStringOrNull(map?['code']);
  }

  /// POST /auth/reset-password { email_or_phone, token, password, ... }
  Future<void> resetPassword({
    required String emailOrPhone,
    required String token,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _client.post(
      ApiEndpoints.resetPassword,
      body: {
        'email_or_phone': emailOrPhone,
        'phone': emailOrPhone,
        'token': token,
        'otp': token,
        'code': token,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
  }
}
