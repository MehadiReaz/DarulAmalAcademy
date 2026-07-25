/// Every endpoint currently implemented on the Laravel backend.
///
/// Keep this file as the single source of truth — no raw path strings
/// anywhere else in the app.
class ApiEndpoints {
  ApiEndpoints._();

  // ---- Auth ----
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String logout = '/auth/logout';
  static const String refresh = '/auth/refresh';
  static const String studentProfile = '/auth/student/profile';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // ---- Student ----
  static const String myCourses = '/student/my-courses';
  static const String classesToday = '/student/classes/today';
  static const String classesUpcoming = '/student/classes/upcoming';

  // ---- Support tickets ----
  static const String tickets = '/tickets';
  static String ticket(int id) => '/tickets/$id';
  static String ticketReply(int id) => '/tickets/$id/reply';
}
