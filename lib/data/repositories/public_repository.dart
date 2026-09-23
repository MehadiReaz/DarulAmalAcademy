import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';

/// Repository for the Public Frontend and Guest APIs.
class PublicRepository {
  final ApiClient _client;

  PublicRepository(this._client);

  /// GET /api/public/site
  /// Returns public branding, contact details, active social links, announcements.
  Future<dynamic> site() => _client.get(ApiEndpoints.publicSite);

  /// GET /api/public/home
  /// Returns homepage sliders, active courses, CMS sections, reviews.
  Future<dynamic> home() => _client.get(ApiEndpoints.publicHome);

  /// GET /api/public/courses
  /// Returns active public courses.
  Future<dynamic> courses() => _client.get(ApiEndpoints.publicCourses);

  /// GET /api/public/courses/{slug}
  /// Returns one active public course and demo videos.
  Future<dynamic> courseDetail(String slug) =>
      _client.get(ApiEndpoints.publicCourseDetail(slug));

  /// GET /api/public/quran
  /// Returns published Quran surahs and topic groupings.
  Future<dynamic> quranIndex() => _client.get(ApiEndpoints.publicQuran);

  /// GET /api/public/quran/surahs/{surahNumber}
  /// Returns one published surah by number.
  Future<dynamic> quranSurah(int surahNumber) =>
      _client.get(ApiEndpoints.publicQuranSurah(surahNumber));

  /// GET /api/public/about
  Future<dynamic> about() => _client.get(ApiEndpoints.publicAbout);

  /// GET /api/public/reviews
  Future<dynamic> reviews() => _client.get(ApiEndpoints.publicReviews);

  /// GET /api/public/contact
  Future<dynamic> contactDetails() => _client.get(ApiEndpoints.publicContact);

  /// POST /api/public/contact
  /// Sends guest contact form message (form-data: name, phone, message).
  Future<dynamic> submitContact({
    required String name,
    required String phone,
    required String message,
  }) {
    return _client.postForm(ApiEndpoints.publicContact, {
      'name': name,
      'phone': phone,
      'message': message,
    });
  }

  /// GET /api/public/enrollment/checkout/{slug}
  Future<dynamic> enrollmentCheckout([String? slug]) =>
      _client.get(ApiEndpoints.publicEnrollmentCheckout(slug));

  /// POST /api/public/enrollment/check-phone
  Future<dynamic> checkPhone(String phone) {
    return _client.postForm(ApiEndpoints.publicEnrollmentCheckPhone, {
      'phone': phone,
    });
  }

  /// POST /api/public/enrollment/initiate
  Future<dynamic> initiateEnrollment(Map<String, dynamic> fields) {
    return _client.postForm(ApiEndpoints.publicEnrollmentInitiate, fields);
  }

  /// POST /api/public/enrollment/complete
  Future<dynamic> completeEnrollment(Map<String, dynamic> fields) {
    return _client.postForm(ApiEndpoints.publicEnrollmentComplete, fields);
  }
}
