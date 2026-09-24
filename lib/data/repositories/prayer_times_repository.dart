import 'package:dio/dio.dart';

import '../../core/network/api_exception.dart';
import '../../core/utils/json_utils.dart';
import '../models/adhan_settings.dart';
import '../models/prayer_times.dart';

/// Prayer timetable from the public Aladhan API (https://aladhan.com).
///
/// Free, keyless, and not our backend, so this uses its own Dio instead
/// of [ApiClient] (which adds the Sanctum token and Laravel envelope).
class PrayerTimesRepository {
  final Dio _dio;

  PrayerTimesRepository([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.aladhan.com/v1',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
            ));

  /// All days of [year]/[month] for the location in [settings].
  Future<PrayerMonth> month(AdhanSettings settings, int year, int month) async {
    final byCity = settings.locationMode == AdhanLocationMode.city;
    final query = <String, dynamic>{
      'method': settings.method,
      'school': settings.school,
      'iso8601': 'true',
      if (byCity) ...{
        'city': settings.city?.trim(),
        'country': settings.country?.trim(),
      } else ...{
        'latitude': settings.latitude,
        'longitude': settings.longitude,
      },
    };

    try {
      final res = await _dio.get(
        byCity ? '/calendarByCity/$year/$month' : '/calendar/$year/$month',
        queryParameters: query,
      );
      final body = asMap(res.data) ?? const {};
      final data = body['data'];
      if (data is! List || data.isEmpty) {
        throw const ApiException(
          message: 'No prayer times found for this location.',
        );
      }
      final days = data
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(PrayerDay.fromApi)
          .whereType<PrayerDay>()
          .toList();
      final meta = asMap(asMap(data.first)?['meta']);
      return PrayerMonth(days: days, timezone: asStringOrNull(meta?['timezone']));
    } on DioException catch (e) {
      final body = asMap(e.response?.data);
      final isNetwork = e.response == null;
      throw ApiException(
        message: isNetwork
            ? 'Could not reach the prayer times service. Check your connection.'
            : (asStringOrNull(body?['data']) ??
                'Could not find prayer times for this location.'),
        statusCode: e.response?.statusCode,
        isNetworkError: isNetwork,
      );
    }
  }
}

class PrayerMonth {
  final List<PrayerDay> days;
  final String? timezone;

  const PrayerMonth({required this.days, this.timezone});
}
