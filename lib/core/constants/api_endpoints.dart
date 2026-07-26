/// Every endpoint currently implemented on the Laravel backend.
///
/// Keep this file as the single source of truth — no raw path strings
/// anywhere else in the app.
///
/// Verified against the 26 Jul 2026 Postman run against
/// `https://course.nexcoreit4u.com/api/`. Endpoints that returned a
/// server-side error in that run are marked so the app knows what to
/// expect.
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

  // ---- Classes / courses ----
  /// RENAMED: was `/student/my-courses`.
  static const String myClasses = '/student/my-classes';
  static String classDetail(int id) => '/student/classes/$id';

  /// Returns the live-class join payload (Zoom/meeting link).
  static String classJoin(int id) => '/student/classes/$id/join';
  static const String classesToday = '/student/classes/today';
  static const String classesUpcoming = '/student/classes/upcoming';
  static const String classRoutine = '/student/my-class-routine';
  static const String myBatches = '/student/my-batches';

  /// NOTE: returned 500 in the 26 Jul run.
  static const String myLessons = '/student/my-lessons';

  static const String dashboard = '/student/dashboard';

  // ---- Attendance ----
  static const String myAttendances = '/student/my-attendances';

  // ---- Notices ----
  static const String notices = '/student/notices';
  static String noticeDetail(int id) => '/student/notices/$id';
  static String noticeRead(int id) => '/student/notices/$id/read';

  // ---- Homework ----
  static const String homework = '/student/homework';
  static String homeworkDetail(int id) => '/student/homework/$id';
  static String homeworkSubmit(int id) => '/student/homework/$id/submit';

  // ---- Qur'an ----
  static const String quranProgress = '/student/quran-progress';

  // ---- Recordings ----
  static const String recordings = '/student/recordings';
  static String recordingDetail(int id) => '/student/recordings/$id';

  // ---- Fees ----
  static const String feeDues = '/student/fees/dues';
  static const String feeHistory = '/student/fees/history';
  static const String feePayInitiate = '/student/fees/pay/initiate';
  static const String feePayVerify = '/student/fees/pay/verify';
  static String feeReceipt(int transactionId) =>
      '/student/fees/receipt/$transactionId';

  // ---- Support tickets ----
  /// MOVED: these were `/tickets/...` and are now namespaced under
  /// `/student`. The old paths 404.
  static const String tickets = '/student/tickets';
  static String ticket(int id) => '/student/tickets/$id';
  static String ticketReply(int id) => '/student/tickets/$id/reply';

  // ---- Group chat ----
  static const String groupChats = '/group-chats';
  static String groupChat(int id) => '/group-chats/$id';
  static String groupChatMessages(int id) => '/group-chats/$id/messages';
  static String groupChatSearch(int id) => '/group-chats/$id/search';
}
