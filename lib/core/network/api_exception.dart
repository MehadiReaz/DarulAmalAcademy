/// A single, predictable error type for the whole app.
///
/// Every Dio failure is converted into this before it reaches a
/// repository, provider, or widget.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// Laravel 422 validation errors: { "phone": ["The phone field is required."] }
  final Map<String, List<String>> fieldErrors;

  /// True when the device could not reach the server at all.
  final bool isNetworkError;

  const ApiException({
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
    this.isNetworkError = false,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isValidation => statusCode == 422 || fieldErrors.isNotEmpty;

  /// First validation message for a given field, if any.
  String? errorFor(String field) {
    final list = fieldErrors[field];
    if (list == null || list.isEmpty) return null;
    return list.first;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
