/// Production Student API and Public API endpoints for Darul Amal Academy.
///
/// Strictly derived from the official Postman collection:
/// "Darul Amal Academy - Student API".
/// All other non-spec endpoints have been removed.
class ApiEndpoints {
  ApiEndpoints._();

  // ==========================================
  // 1. Authentication
  // ==========================================
  /// POST: Authenticates an active student with phone and password (form-data).
  static const String studentLogin = '/api/student/auth/password';

  /// POST: Deletes all API tokens belonging to the authenticated student.
  static const String studentLogout = '/api/student/auth/logout';

  // ==========================================
  // 2. Dashboard & Profile
  // ==========================================
  /// GET: Returns student summary, fee alert, classes, progress, enrollments, recent payments.
  static const String studentDashboard = '/api/student/dashboard';

  /// GET: Returns authenticated student profile.
  /// POST/PUT: Updates authenticated student profile (multipart/form-data).
  static const String studentProfile = '/api/student/profile';

  // ==========================================
  // 3. Courses & Course Tabs
  // ==========================================
  /// GET: Lists courses derived from active batch assignments.
  static const String studentCourses = '/api/student/courses';

  /// Canonical course tabs supported by the backend:
  /// `details`, `assignments`, `online-class`, `recordings`, `syllabus`, `attendance`.
  static String studentCourseTab(int batchId, [String tab = 'details']) =>
      '/api/student/courses/$batchId?tab=$tab';

  /// GET: Lists active batch assignments with course, teacher, and schedule information.
  static const String studentBatches = '/api/student/batches';

  // ==========================================
  // 4. Schedule & Live Classes
  // ==========================================
  /// GET: Returns recurring schedule entries only for active batches.
  static const String studentSchedule = '/api/student/schedule';

  /// GET: Returns active-batch schedule entries occurring today.
  static const String studentClassToday = '/api/student/class/today';

  /// GET: Returns active-batch schedule entries with next occurrence date.
  static const String studentClassUpcoming = '/api/student/class/upcoming';

  /// GET: Lists online classes belonging to active student batches.
  static const String studentLiveClasses = '/api/student/live-classes';

  // ==========================================
  // 5. Assignments
  // ==========================================
  /// GET: Lists assignments only from active student batches.
  static const String studentAssignments = '/api/student/assignments';

  /// GET: Returns assignment details including current student's submission state.
  static String studentAssignmentDetail(int id) =>
      '/api/student/assignments/$id';

  /// POST: Submits or replaces student's assignment file (multipart/form-data).
  static String studentAssignmentSubmit(int id) =>
      '/api/student/assignments/$id/submit';

  // ==========================================
  // 6. Recordings
  // ==========================================
  /// GET: Lists active recordings from active student batches.
  static const String studentRecordings = '/api/student/recordings';

  /// GET: Returns active recording details.
  static String studentRecordingDetail(int id) =>
      '/api/student/recordings/$id';

  // ==========================================
  // 7. Attendance & Quran Progress
  // ==========================================
  /// GET: Returns authenticated student's active-batch attendance.
  static const String studentAttendance = '/api/student/attendance';

  /// GET: Returns student's Quran progress snapshot, history, and curriculum reference.
  static const String studentQuranProgress = '/api/student/quran-progress';

  // ==========================================
  // 8. Fees & Payments
  // ==========================================
  /// GET: Returns transactions, totals, due values, chart, and filters.
  static const String studentTransactions = '/api/student/transactions';

  /// GET: Returns transaction details by ID or transaction number.
  static String studentTransactionDetail(String transactionNo) =>
      '/api/student/transactions/$transactionNo';

  /// GET: Returns unpaid and partially paid transactions.
  static const String studentFeeDues = '/api/student/fees/dues';

  /// GET: Returns paid transactions.
  static const String studentFeeHistory = '/api/student/fees/history';

  /// POST: Creates payment-gateway order data for owned transaction (form-data: id).
  static const String studentFeePayInitiate = '/api/student/fees/pay/initiate';

  /// GET: Returns temporary signed payment WebView URL.
  static const String studentFeePayWebviewUrl =
      '/api/student/fees/pay/webview-url';

  /// POST: Verifies a Razorpay payment (form-data: transaction_id, razorpay_payment_id, ...).
  static const String studentFeeRazorpayVerify =
      '/api/student/fees/pay/razorpay/verify';

  /// GET: Downloads PDF receipt for owned transaction.
  static String studentFeeReceipt(int transactionId) =>
      '/api/student/fees/receipt/$transactionId';

  // ==========================================
  // 9. Notices
  // ==========================================
  /// GET: Lists notices visible to the student.
  static const String studentNotices = '/api/student/notices';

  /// GET: Returns notice details.
  static String studentNoticeDetail(int id) => '/api/student/notices/$id';

  /// POST: Acknowledges notice visibility.
  static String studentNoticeRead(int id) => '/api/student/notices/$id/read';

  // ==========================================
  // 10. Notifications & Devices
  // ==========================================
  /// GET: Lists student notifications and unread count.
  static const String studentNotifications = '/api/student/notifications';

  /// POST: Marks a notification as read.
  static String studentNotificationRead(String id) =>
      '/api/student/notifications/$id/read';

  /// POST: Registers mobile FCM device token.
  static const String studentFcmToken = '/api/student/fcm-token';

  /// POST: Removes mobile FCM device token.
  static const String studentFcmTokenRemove = '/api/student/fcm-token/remove';

  // ==========================================
  // 11. Support
  // ==========================================
  /// GET: Returns Admin Support and Help Center WhatsApp contacts.
  static const String studentSupportContacts = '/api/student/support';

  // ==========================================
  // 12. Public Frontend / Guest APIs
  // ==========================================
  /// GET: Public site layout data (branding, contact, social links).
  static const String publicSite = '/api/public/site';

  /// GET: Homepage data (sliders, featured courses, reviews).
  static const String publicHome = '/api/public/home';

  /// GET: Public course listing.
  static const String publicCourses = '/api/public/courses';

  /// GET: Public course details by slug.
  static String publicCourseDetail(String slug) =>
      '/api/public/courses/$slug';

  /// GET: Published Quran surahs and topic groupings.
  static const String publicQuran = '/api/public/quran';

  /// GET: Published surah details by surah number.
  static String publicQuranSurah(int surahNumber) =>
      '/api/public/quran/surahs/$surahNumber';

  /// GET: About page CMS content.
  static const String publicAbout = '/api/public/about';

  /// GET: Reviews page content.
  static const String publicReviews = '/api/public/reviews';

  /// GET: Contact page details.
  /// POST: Submits guest contact form message (form-data).
  static const String publicContact = '/api/public/contact';

  /// GET: Enrollment checkout data for a course.
  static String publicEnrollmentCheckout([String? slug]) =>
      slug == null || slug.isEmpty
          ? '/api/public/enrollment/checkout'
          : '/api/public/enrollment/checkout/$slug';

  /// POST: Checks if entered phone belongs to an existing student.
  static const String publicEnrollmentCheckPhone =
      '/api/public/enrollment/check-phone';

  /// POST: Initiates enrollment payment with Razorpay order (form-data).
  static const String publicEnrollmentInitiate =
      '/api/public/enrollment/initiate';

  /// POST: Completes enrollment payment after Razorpay success (form-data).
  static const String publicEnrollmentComplete =
      '/api/public/enrollment/complete';
}
