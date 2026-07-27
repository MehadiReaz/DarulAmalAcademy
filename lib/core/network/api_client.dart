// import 'dart:developer' as dev;

import 'dart:typed_data';

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

  /// Downloads a binary body (PDF, image, export) from an **authenticated**
  /// endpoint.
  ///
  /// This exists because some endpoints return a file rather than JSON —
  /// `GET /student/fees/receipt/{id}` responds with
  /// `content-type: application/pdf` and a `content-disposition` filename.
  ///
  /// Such a URL CANNOT be handed to `url_launcher`: the browser has no
  /// bearer token, so the server answers 302 and redirects to the web
  /// login page. The file has to be fetched through this client, which
  /// already attaches the token, and rendered from memory.
  Future<BinaryResponse> getBytes(
    String path, {
    Map<String, dynamic>? query,
    String accept = '*/*',
  }) async {
    try {
      final res = await _dio.get<List<int>>(
        path,
        queryParameters: query,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': accept},
        ),
      );

      final contentType = res.headers.value(Headers.contentTypeHeader);

      // Dio follows redirects, so an expired session surfaces as a 200
      // full of login-page HTML rather than a 401. Without this guard the
      // bytes would reach a PDF renderer and fail as "corrupt file".
      if (contentType != null && contentType.contains('text/html')) {
        throw const ApiException(
          message: 'Your session has expired. Please sign in again.',
          statusCode: 401,
        );
      }

      final bytes = Uint8List.fromList(res.data ?? const []);
      if (bytes.isEmpty) {
        throw const ApiException(message: 'The server returned an empty file.');
      }

      logger.i('[API] Downloaded ${bytes.length} bytes from $path');

      return BinaryResponse(
        bytes: bytes,
        contentType: contentType,
        filename: _filenameFrom(res.headers.value('content-disposition')),
      );
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  String? _filenameFrom(String? disposition) {
    if (disposition == null || disposition.isEmpty) return null;

    final extended = RegExp(
      r"filename\*=(?:UTF-8'')?([^;]+)",
      caseSensitive: false,
    ).firstMatch(disposition);
    if (extended != null) {
      final raw = extended.group(1)!.trim().replaceAll('"', '');
      try {
        return Uri.decodeComponent(raw);
      } catch (_) {
        return raw;
      }
    }

    final plain = RegExp(
      r'filename="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(disposition);
    return plain?.group(1)?.trim();
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

class BinaryResponse {
  final Uint8List bytes;
  final String? filename;
  final String? contentType;

  const BinaryResponse({required this.bytes, this.filename, this.contentType});

  bool get isPdf {
    if (bytes.length >= 4 &&
        bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46) { // F
      return true;
    }
    return (contentType ?? '').contains('application/pdf') ||
        (filename ?? '').toLowerCase().endsWith('.pdf');
  }

  int get sizeInKb => (bytes.length / 1024).ceil();

  /// A filename safe to write to disk on every platform. The server sends
  /// names containing spaces and apostrophes
  /// ("Mehadi Hasan's_..._report.pdf"), which Android and iOS tolerate but
  /// Windows does not.
  String safeFilename({String fallback = 'document.pdf'}) {
    final name = filename;
    if (name == null || name.trim().isEmpty) return fallback;
    return name
        .replaceAll(RegExp(r'''[\\/:*?"<>|']'''), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }
}
