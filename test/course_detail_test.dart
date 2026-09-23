import 'package:darul_amal/core/network/api_client.dart';
import 'package:darul_amal/data/repositories/class_repository.dart';
import 'package:darul_amal/providers/class_provider.dart';
import 'package:darul_amal/ui/screens/courses/course_detail_screen.dart';
import 'package:darul_amal/ui/screens/recordings/widgets/recording_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient() : super();

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    if (path.contains('tab=details')) {
      return {
        'batch': {
          'id': 1,
          'name': 'Nurani - Evening Batch',
          'schedule': 'Saturday, Monday, Wednesday · 06:00 PM - 07:30 PM',
          'teacher': {'name': 'Qari Mahmood Al-Hussary'},
          'duration': '6 months',
        },
        'course': {
          'id': 1,
          'name': 'Nurani',
        },
        'summary': {
          'pending_homework': '0',
          'upcoming_classes': '2',
          'recordings': '2',
          'attendance_percentage': '0%',
          'total_sessions': '0',
        },
      };
    }
    if (path.contains('tab=online-class')) {
      if (path.contains('/999')) {
        return {'data': []};
      }
      return {
        'classes': {
          'current_page': 1,
          'data': {
            'Upcoming Class': [
              {
                'id': 101,
                'topic': 'Tajweed Rules & Practice',
                'start_time': '2026-09-25 18:00:00',
                'start_date_format': '25-09-2026 at 06:00 PM',
                'password': 'secret_password_123',
                'status': 'Upcoming',
                'join_url': 'https://zoom.us/j/1234567890',
                'course': {'name': 'Nurani'},
                'teacher': {'name': 'Qari Mahmood Al-Hussary'},
                'description': 'Interactive recitation review and Tajweed rule clarification.'
              }
            ]
          }
        }
      };
    }
    if (path.contains('tab=assignments')) {
      return {
        'assignments': [
          {
            'id': 201,
            'title': 'সুরা আল-ফাতিহা মাশক ও মুখস্থ',
            'course': {'name': 'Nurani'},
            'batch': {'name': 'Nurani - Evening Batch'},
            'teacher': {'name': 'Qari Mahmood Al-Hussary'},
            'due_date': '28-09-2026',
            'status': 'Due',
            'assignment_status': 'Ongoing Assignment',
            'description': 'সুরা আল-ফাতিহার ১-৭ আয়াত স্পষ্ট মাখরাজসহ তেলাওয়াত করে জমা দিন।',
            'is_submitted': false,
          },
          {
            'id': 202,
            'title': 'হরকত ও তানভীন কায়দা অনুশীলন',
            'course': {'name': 'Nurani'},
            'batch': {'name': 'Nurani - Evening Batch'},
            'teacher': {'name': 'Qari Mahmood Al-Hussary'},
            'due_date': '20-09-2026',
            'status': 'Completed',
            'assignment_status': 'Completed Assignment',
            'description': 'কায়দার ৩য় পৃষ্ঠা সম্পূর্ণ অনুশীলন করে অডিও আপলোড করুন।',
            'is_submitted': true,
          }
        ]
      };
    }
    if (path.contains('tab=recordings')) {
      return {
        'recordings': {
          'current_page': 1,
          'data': [
            {
              'id': 301,
              'title': 'Nurani Qaida - Lesson 1: হরফ শিক্ষা',
              'description': 'Introduction to Arabic alphabets with proper pronunciation.',
              'video_type': 'youtube',
              'video_url': 'https://www.youtube.com/watch?v=X2YnP50cwNU',
              'embed_url': 'https://www.youtube.com/embed/X2YnP50cwNU',
              'thumbnail': 'https://img.youtube.com/vi/X2YnP50cwNU/hqdefault.jpg',
              'recorded_on': '2026-09-20',
              'course': {'id': 1, 'name': 'Nurani'},
              'batch': {'id': 1, 'name': 'Nurani - Evening Batch'},
            }
          ]
        }
      };
    }
    if (path.contains('live-classes')) {
      return {
        'classes': {
          'current_page': 1,
          'data': [
            {
              'id': 105,
              'topic': 'Fallback Live Session',
              'start_date_format': '27-09-2026 at 08:00 PM',
              'password': 'fallback_pass',
              'status': 'Live',
              'join_url': 'https://zoom.us/j/1122334455',
              'course': {'name': 'Nurani'},
              'teacher': {'name': 'Qari Mahmood Al-Hussary'},
            }
          ]
        }
      };
    }
    return {'data': []};
  }
}

void main() {
  testWidgets('CourseDetailScreen displays header banner, tabs, and study summary in English', (tester) async {
    final fakeClient = FakeApiClient();
    final repo = ClassRepository(fakeClient);
    final provider = ClassProvider(repo);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ClassProvider>.value(value: provider),
        ],
        child: const MaterialApp(
          home: CourseDetailScreen(
            batchId: 1,
            courseTitle: 'Nurani',
            batchName: 'Nurani - Evening Batch',
            schedule: 'Saturday, Monday, Wednesday · 06:00 PM - 07:30 PM',
            teacherName: 'Qari Mahmood Al-Hussary',
            duration: '6 months',
          ),
        ),
      ),
    );

    // Pump to settle async loadTab
    await tester.pumpAndSettle();

    // Verify Header Banner
    expect(find.text('My Course'), findsOneWidget);
    expect(find.text('Nurani'), findsWidgets);
    expect(find.textContaining('Nurani - Evening Batch · Saturday, Monday, Wednesday · 06:00 PM - 07:30 PM'), findsOneWidget);

    // Verify Canonical Tab Bar & Card Items
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Homework'), findsOneWidget);
    expect(find.text('Live Classes'), findsOneWidget);
    expect(find.text('Recordings'), findsNWidgets(2)); // Tab & Progress Card
    expect(find.text('Syllabus'), findsOneWidget);
    expect(find.text('Attendance'), findsNWidgets(2)); // Tab & Progress Card

    // Verify Card 1: Assigned Batch
    expect(find.text('Assigned Batch'), findsOneWidget);
    expect(find.text('Teacher'), findsOneWidget);
    expect(find.text('Qari Mahmood Al-Hussary'), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('6 months'), findsOneWidget);

    // Verify Card 2: Study Summary & 4 progress cards
    expect(find.text('Study Summary'), findsOneWidget);
    expect(find.text('Your Progress in this Batch'), findsOneWidget);
    expect(find.text('Pending Homework'), findsOneWidget);
    expect(find.text('Upcoming Classes'), findsOneWidget);
  });

  testWidgets('CourseDetailScreen displays Live Class tab with [ LV ] card, password copy, and join button', (tester) async {
    final fakeClient = FakeApiClient();
    final repo = ClassRepository(fakeClient);
    final provider = ClassProvider(repo);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ClassProvider>.value(value: provider),
        ],
        child: const MaterialApp(
          home: CourseDetailScreen(
            batchId: 1,
            courseTitle: 'Nurani',
            batchName: 'Nurani - Evening Batch',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap on Live Classes tab
    await tester.tap(find.text('Live Classes'));
    await tester.pumpAndSettle();

    // Verify live class card content
    expect(find.text('Tajweed Rules & Practice'), findsOneWidget);
    expect(find.text('LV'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('secret_password_123'), findsOneWidget);
    expect(find.text('Join Live Class'), findsOneWidget);
    expect(find.text('25-09-2026 at 06:00 PM'), findsOneWidget);
  });

  testWidgets('CourseDetailScreen displays Homework tab with matching HomeworkTab UI', (tester) async {
    final fakeClient = FakeApiClient();
    final repo = ClassRepository(fakeClient);
    final provider = ClassProvider(repo);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ClassProvider>.value(value: provider),
        ],
        child: const MaterialApp(
          home: CourseDetailScreen(
            batchId: 1,
            courseTitle: 'Nurani',
            batchName: 'Nurani - Evening Batch',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap on Homework tab
    await tester.tap(find.text('Homework'));
    await tester.pumpAndSettle();

    // Verify batch indicator
    expect(find.text('Nurani - Evening Batch'), findsWidgets);

    // Verify Ongoing & Completed sections
    expect(find.text('Ongoing Assignment'), findsOneWidget);
    expect(find.text('Completed Assignment', skipOffstage: false), findsOneWidget);

    // Verify HomeworkCard [ AS ] badge
    expect(find.text('AS', skipOffstage: false), findsNWidgets(2));

    // Verify cards content
    expect(find.text('সুরা আল-ফাতিহা মাশক ও মুখস্থ'), findsOneWidget);
    expect(find.text('হরকত ও তানভীন কায়দা অনুশীলন', skipOffstage: false), findsOneWidget);
    expect(find.text('Due'), findsWidgets);
    expect(find.text('Completed', skipOffstage: false), findsWidgets);
    expect(find.text('Submitted', skipOffstage: false), findsWidgets);
  });

  testWidgets('CourseDetailScreen displays Recordings tab with RecordingCard UI and in-app player', (tester) async {
    final fakeClient = FakeApiClient();
    final repo = ClassRepository(fakeClient);
    final provider = ClassProvider(repo);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ClassProvider>.value(value: provider),
        ],
        child: const MaterialApp(
          home: CourseDetailScreen(
            batchId: 1,
            courseTitle: 'Nurani',
            batchName: 'Nurani - Evening Batch',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap on Recordings tab
    await tester.tap(find.text('Recordings').first);
    await tester.pumpAndSettle();

    // Verify batch header
    expect(find.text('Nurani - Evening Batch'), findsWidgets);

    // Verify recording card details
    expect(find.byType(RecordingCard), findsOneWidget);
    expect(find.text('Nurani Qaida - Lesson 1: হরফ শিক্ষা'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
  });

  testWidgets('CourseDetailScreen falls back to ClassProvider.liveSessions if courseTab is empty', (tester) async {
    final fakeClient = FakeApiClient();
    final repo = ClassRepository(fakeClient);
    final provider = ClassProvider(repo);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ClassProvider>.value(value: provider),
        ],
        child: const MaterialApp(
          home: CourseDetailScreen(
            batchId: 999, // Unknown batch where courseTab returns empty
            courseTitle: 'Nurani',
            batchName: 'Nurani - Evening Batch',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap on Live Classes tab
    await tester.tap(find.text('Live Classes'));
    await tester.pumpAndSettle();

    // With batchId: 999, tab=online-class returns {'data': []},
    // and live-classes returns Fallback Live Session
    expect(find.text('Fallback Live Session'), findsOneWidget);
    expect(find.text('LV'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('fallback_pass'), findsOneWidget);
    expect(find.text('Join Live Class'), findsOneWidget);
  });
}
