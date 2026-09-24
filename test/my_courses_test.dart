import 'package:darul_amal/core/network/api_client.dart';
import 'package:darul_amal/data/models/enrolled_course.dart';
import 'package:darul_amal/data/repositories/class_repository.dart';
import 'package:darul_amal/providers/class_provider.dart';
import 'package:darul_amal/ui/screens/courses/my_courses_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class FakeCoursesApiClient extends ApiClient {
  FakeCoursesApiClient() : super();

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    if (path.contains('/courses')) {
      // Shape of `GET /api/student/courses` (Sep 2026): flat courses with
      // the student's batches nested. Batch id deliberately differs from
      // the course id, which is what the card must open.
      return [
        {
          'id': 4,
          'name': 'Nurani',
          'slug': 'nurani',
          'image_url': null,
          'primary_batch_id': 8,
          'duration': '6 months',
          'students_count': 25,
          'batches': [
            {
              'id': 8,
              'name': 'Nurani - Evening Batch',
              'time': '06:00 PM - 07:30 PM',
              'teacher': {'id': 2, 'name': 'Qari Mahmood Al-Hussary'},
            },
          ],
        },
      ];
    }
    return {'data': []};
  }
}

void main() {
  testWidgets('MyCoursesScreen renders course card matching the reference UI', (tester) async {
    final fakeClient = FakeCoursesApiClient();
    final repo = ClassRepository(fakeClient);
    final provider = ClassProvider(repo);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ClassProvider>.value(value: provider),
        ],
        child: const MaterialApp(
          home: MyCoursesScreen(),
        ),
      ),
    );

    // Initial pump & settle
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify App Bar
    expect(find.text('My Enrolled Courses'), findsOneWidget);

    // Verify ENROLLED Badge
    expect(find.text('ENROLLED'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

    // Verify Course Title
    expect(find.text('Nurani'), findsOneWidget);

    // Verify Duration Box
    expect(find.text('6 months'), findsOneWidget);
    expect(find.text('DURATION'), findsOneWidget);
    expect(find.byIcon(Icons.access_time_rounded), findsOneWidget);

    // Verify Batch & Time Pill Tag
    expect(find.textContaining('Nurani - Evening Batch · 06:00 PM - 07:30 PM'), findsOneWidget);

    // Verify Course Details Action Button
    expect(find.text('Course Details'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  group('EnrolledCourse', () {
    test('opens the primary batch, not the course id', () {
      final c = EnrolledCourse.fromJson({
        'id': 4,
        'name': 'Ibtidaiyyah',
        'primary_batch_id': 8,
        'batches': [
          {'id': 3, 'name': 'Morning'},
          {'id': 8, 'name': 'Noon', 'time': '12:00 PM - 01:00 PM'},
        ],
      });
      expect(c.batchId, 8);
      expect(c.primaryBatch?.name, 'Noon');
      expect(c.primaryBatch?.schedule, '12:00 PM - 01:00 PM');
    });

    test('has no batch id when the student has no batch', () {
      final c = EnrolledCourse.fromJson({'id': 4, 'name': 'X'});
      expect(c.batchId, isNull);
      expect(c.duration, isNull);
    });

    test('batch schedule combines days and time', () {
      final b = CourseBatch.fromJson({
        'id': 1,
        'days': ['Saturday', 'Monday'],
        'formatted_time': '06:00 PM - 07:30 PM',
      });
      expect(b.schedule, 'Saturday, Monday · 06:00 PM - 07:30 PM');
    });
  });
}
