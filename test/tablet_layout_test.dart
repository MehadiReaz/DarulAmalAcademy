import 'package:darul_amal/core/utils/responsive.dart';
import 'package:darul_amal/data/repositories/class_repository.dart';
import 'package:darul_amal/providers/class_provider.dart';
import 'package:darul_amal/ui/screens/courses/course_detail_screen.dart';
import 'package:darul_amal/ui/screens/courses/my_courses_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'course_detail_test.dart' show FakeApiClient;
import 'my_courses_test.dart' show FakeCoursesApiClient;

/// Portrait and landscape tablet windows, plus a phone for contrast.
const _sizes = {
  'phone': Size(390, 844),
  'tablet portrait': Size(820, 1180),
  'tablet landscape': Size(1180, 820),
};

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app(ClassProvider provider, Widget home) => MultiProvider(
      providers: [ChangeNotifierProvider<ClassProvider>.value(value: provider)],
      child: MaterialApp(home: home),
    );

void main() {
  group('Responsive', () {
    test('columns clamp to the requested range', () {
      expect(Responsive.columns(390, minItemWidth: 120, min: 3, max: 6), 3);
      expect(Responsive.columns(1180, minItemWidth: 120, min: 3, max: 6), 6);
      expect(Responsive.columns(390, minItemWidth: 340, max: 3), 1);
      expect(Responsive.columns(1180, minItemWidth: 340, max: 3), 3);
    });

    test('tablet detection uses the shorter side', () {
      expect(Responsive.isTabletDevice(const Size(390, 844)), isFalse);
      expect(Responsive.isTabletDevice(const Size(1180, 820)), isTrue);
    });
  });

  for (final MapEntry(key: name, value: size) in _sizes.entries) {
    testWidgets('My Courses lays out without overflow ($name)', (tester) async {
      _setSize(tester, size);
      final provider = ClassProvider(ClassRepository(FakeCoursesApiClient()));
      await tester.pumpWidget(_app(provider, const MyCoursesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Nurani'), findsOneWidget);
      // Content is capped, so cards never stretch past the grid width.
      final card = tester.getSize(find.text('Course Details').first);
      expect(card.width, lessThan(Responsive.gridMaxWidth));
    });

    testWidgets('Course detail lays out without overflow ($name)', (tester) async {
      _setSize(tester, size);
      final provider = ClassProvider(ClassRepository(FakeApiClient()));
      await tester.pumpWidget(
        _app(
          provider,
          const CourseDetailScreen(batchId: 1, courseTitle: 'Nurani'),
        ),
      );
      await tester.pumpAndSettle();

      final body = tester.getSize(find.byType(TabBarView));
      expect(body.width, lessThanOrEqualTo(Responsive.contentMaxWidth));

      for (final tab in ['Homework', 'Live Classes', 'Syllabus']) {
        await tester.tap(find.text(tab).first);
        await tester.pumpAndSettle();
      }
    });
  }
}
