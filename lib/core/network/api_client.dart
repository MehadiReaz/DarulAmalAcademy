// import 'dart:developer' as dev;

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../log/log_hadler.dart';
import 'api_exception.dart';

/// Thin wrapper around Dio that:
///  - attaches the Sanctum bearer token
///  - unwraps the Laravel ApiResponse envelope  { success, message, data }
///  - converts every failure into an [ApiException]
///  - notifies the app when the token is rejected (401)
class ApiClient {
  late final Dio _dio;
  String? _token;

  /// Called when the server rejects our token. AuthProvider hooks into this
  /// to force a logout. Sanctum tokens do not auto-refresh, so a 401 means
  /// the session is genuinely over.
  void Function()? onUnauthorized;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        // We handle all non-2xx ourselves in _toApiException.
        validateStatus: (status) => status != null && status < 400,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          if (AppConfig.enableLogging) {
            logger.i('[API] → ${options.method} ${options.uri}');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (AppConfig.enableLogging) {
            logger.i(
              '[API] ← ${response.statusCode} ${response.requestOptions.uri}',
            );
          }
          handler.next(response);
        },
        onError: (error, handler) {
          if (AppConfig.enableLogging) {
            logger.e('[API] Response Data: ${error.response?.data}');
            logger.e(
              '[API] × ${error.response?.statusCode} ${error.requestOptions.uri} :: ${error.message}',
            );
          }
          if (error.response?.statusCode == 401) {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  void setToken(String? token) => _token = token;
  String? get token => _token;
  void clearToken() => _token = null;

  // ---------------------------------------------------------------- verbs

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get(path, queryParameters: query);
      logger.i('[API] Response: ${res.data}');
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<dynamic> post(String path, {Object? body}) async {
    try {
      logger.i('[API] POST Body: $path: $body');
      final res = await _dio.post(path, data: body);
      logger.i('[API] Response: ${res.data}');
      return _unwrap(res.data);
    } on DioException catch (e) {
      logger.e('[API] Error: ${e.message}');
      throw _toApiException(e);
    }
  }

  Future<dynamic> put(String path, {Object? body}) async {
    try {
      final res = await _dio.put(path, data: body);
      logger.i('[API] Response: ${res.data}');
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<dynamic> delete(String path, {Object? body}) async {
    try {
      final res = await _dio.delete(path, data: body);
      logger.i('[API] Response: ${res.data}');
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  /// Multipart upload. Laravel cannot read multipart on a real PUT request,
  /// so callers POST with `_method: PUT` — Laravel's method spoofing routes
  /// it to the PUT route correctly.
  ///
  /// The content type is set explicitly: BaseOptions declares
  /// `application/json` for every other verb, and relying on Dio to notice
  /// the FormData and override it leaves the boundary parameter up to
  /// chance. Stating it here means PHP always populates `$_FILES`.
  Future<dynamic> postMultipart(String path, FormData form) async {
    try {
      final res = await _dio.post(
        path,
        data: form,
        options: Options(contentType: Headers.multipartFormDataContentType),
      );
      logger.i('[API] Response: ${res.data}');
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  // ------------------------------------------------------------- internals

  /// The backend's ApiResponse trait wraps payloads as
  /// `{ success, message, data }`. We return `data` when present, otherwise
  /// the raw body — so this keeps working if an endpoint skips the envelope.
  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }

  ApiException _toApiException(DioException e) {
    // No connection / timeout
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const ApiException(
        message:
            'Cannot reach the server. Please check your internet connection.',
        isNetworkError: true,
      );
    }

    final status = e.response?.statusCode;
    final body = e.response?.data;

    String message = 'Something went wrong. Please try again.';
    final Map<String, List<String>> fieldErrors = {};

    if (body is Map) {
      // Laravel validation: { message, errors: { field: [msg, ...] } }
      final errors = body['errors'];
      if (errors is Map) {
        errors.forEach((key, value) {
          if (value is List) {
            fieldErrors[key.toString()] = value
                .map((v) => v.toString())
                .toList();
          } else if (value != null) {
            fieldErrors[key.toString()] = [value.toString()];
          }
        });
      }

      final raw = body['message'] ?? body['error'];
      if (raw is String && raw.trim().isNotEmpty) {
        message = raw;
      } else if (raw is Map && raw['message'] is String) {
        message = raw['message'] as String;
      } else if (fieldErrors.isNotEmpty) {
        message = fieldErrors.values.first.first;
      }
    }

    if (status == 401) {
      message = 'Your session has expired. Please log in again.';
    }

    return ApiException(
      message: message,
      statusCode: status,
      fieldErrors: fieldErrors,
    );
  }
}
