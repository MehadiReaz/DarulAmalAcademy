import 'package:darul_amal/core/network/api_client.dart';
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
    if (path.contains('/batches')) {
      return [
        {
          'id': 1,
          'name': 'Nurani - Evening Batch',
          'course_id': 1,
          'schedule': '06:00 PM - 07:30 PM',
          'teacher': {'name': 'Qari Mahmood Al-Hussary'},
          'duration': '6 months',
        },
      ];
    }
    if (path.contains('/courses')) {
      return {
        'courses': [
          {
            'id': 1,
            'course_id': 1,
            'total_students': 25,
            'course': {
              'id': 1,
              'name': 'Nurani',
              'duration': '6 months',
            },
          },
        ],
      };
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
}
