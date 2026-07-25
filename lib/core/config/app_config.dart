/// App-wide configuration.
///
/// Override the base URL at build time without touching code:
///   flutter run --dart-define=API_BASE_URL=https://api.darulamal.com/api
class AppConfig {
  AppConfig._();

  /// Defaults:
  ///  - Android emulator reaches your host machine at 10.0.2.2
  ///  - iOS simulator / desktop can use 127.0.0.1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://course.nexcoreit4u.com/api',
  );

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Prints request/response logs in debug builds.
  static const bool enableLogging = true;
}
