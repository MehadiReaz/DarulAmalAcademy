import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:darul_amal/core/network/api_client.dart';
import 'package:darul_amal/data/models/homework.dart';
import 'package:darul_amal/data/models/student_user.dart';
import 'package:darul_amal/data/repositories/homework_repository.dart';
import 'package:darul_amal/providers/auth_provider.dart';
import 'package:darul_amal/providers/homework_provider.dart';
import 'package:darul_amal/ui/screens/homework/homework_tab.dart';
import 'package:darul_amal/ui/screens/homework/homework_detail_screen.dart';

class FakeApiClient implements ApiClient {
  dynamic stubbedGetResult;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    return stubbedGetResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  final StudentUser? _mockUser;
  FakeAuthProvider([this._mockUser]);

  @override
  StudentUser? get user => _mockUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleStudent = StudentUser(
    id: 9,
    name: 'Hafiz Muhammad Zaid',
    rollNo: '1003',
    studentId: 'STD-1003',
    courses: const [
      NamedRef(id: 1, name: 'Nurani'),
      NamedRef(id: 4, name: 'Ibtidaiyyah'),
    ],
  );

  group('Homework Model Parsing', () {
    test('parses course, batch, status, and formattedDueDate accurately', () {
      final json = {
        "id": 35,
        "title": "ইলমুন নাহব: এ'রাব ও আমেল চেনার নিয়মাবলী",
        "description": "নির্ধারিত বিষয়ের ওপর বিস্তারিত উত্তর লিখে আগামী নির্ধারিত তা...",
        "start_date": "15-07-2026",
        "end_date": "11-08-2026",
        "deadline": "04-10-2026",
        "status": "Due",
        "assignment_status": "Ongoing Assignment",
        "course": {
          "id": 1,
          "name": "Nurani",
        },
        "batch": {
          "id": 2,
          "name": "Nurani - Evening Batch",
        },
        "teacher": {
          "id": 20,
          "name": "Qari Mahmood Al-Hussary",
        },
      };

      final hw = Homework.fromJson(json);

      expect(hw.id, 35);
      expect(hw.title, "ইলমুন নাহব: এ'রাব ও আমেল চেনার নিয়মাবলী");
      expect(hw.courseDisplayName, "Nurani");
      expect(hw.batchDisplayName, "Nurani - Evening Batch");
      expect(hw.teacher?.name, "Qari Mahmood Al-Hussary");
      expect(hw.formattedDueDate, "04-10-2026");
      expect(hw.status, "Due");
      expect(hw.isPending, isTrue);
    });

    test('HomeworkSubmission parses student info, download file, description, and marks', () {
      final json = {
        "id": 160,
        "student": {
          "name": "Hafiz Muhammad Zaid",
          "roll_no": "1003",
          "profile_photo_url": "https://example.com/photo.png",
        },
        "assignment_url": "https://example.com/files/sample.pdf",
        "description": "Seeded assignment answer text",
        "gained_mark": "68",
        "completed": "1",
        "created_at": "2026-08-12T07:48:42.000000Z",
      };

      final sub = HomeworkSubmission.fromJson(json);

      expect(sub.id, 160);
      expect(sub.studentName, "Hafiz Muhammad Zaid");
      expect(sub.studentRoll, "1003");
      expect(sub.fileUrl, "https://example.com/files/sample.pdf");
      expect(sub.audioUrl, "https://example.com/files/sample.pdf");
      expect(sub.mark, "68");
      expect(sub.status, "Completed");
      expect(sub.text, "Seeded assignment answer text");
    });

    test('HomeworkDetail parses submissions table and metadata', () {
      final json = {
        "id": 98,
        "title": "শারহে বেকায়া: কিতাবুত তাহারাত ও কিতাবুস্ সালাত",
        "description": "নির্ধারিত বিষয়ের ওপর বিস্তারিত উত্তর লিখে আগামী নির্ধারিত তা...",
        "course": {"id": 1, "name": "Nurani"},
        "batch": {"id": 2, "name": "Nurani - Evening Batch"},
        "teacher": {"id": 20, "name": "Qari Mahmood Al-Hussary"},
        "deadline": "05-09-2026",
        "status": "Expired",
        "submitted": [
          {
            "id": 160,
            "student_id": "82",
            "assignment_url": "https://example.com/files/sample.pdf",
            "description": "Seeded assignment submission",
            "gained_mark": "68",
            "completed": "1",
          }
        ]
      };

      final detail = HomeworkDetail.fromJson(json);

      expect(detail.id, 98);
      expect(detail.courseDisplayName, "Nurani");
      expect(detail.batchDisplayName, "Nurani - Evening Batch");
      expect(detail.formattedDueDate, "05-09-2026");
      expect(detail.status, "Expired");
      expect(detail.submissions.length, 1);
      expect(detail.submissions.first.fileUrl, "https://example.com/files/sample.pdf");
      expect(detail.submissions.first.mark, "68");
    });
  });

  group('HomeworkTab Widget', () {
    testWidgets('renders filter chips, batch bullet, sections, and AS cards matching reference UI', (tester) async {
      final fakeClient = FakeApiClient();
      fakeClient.stubbedGetResult = {
        "assignments": {
          "current_page": 1,
          "data": {
            "Ongoing Assignment": [
              {
                "id": 35,
                "title": "ইলমুন নাহব: এ'রাব ও আমেল চেনার নিয়মাবলী",
                "description": "নির্ধারিত বিষয়ের ওপর বিস্তারিত উত্তর লিখে আগামী নির্ধারিত তা...",
                "deadline": "04-10-2026",
                "status": "Due",
                "course": {"id": 1, "name": "Nurani"},
                "batch": {"id": 2, "name": "Nurani - Evening Batch"},
                "teacher": {"id": 20, "name": "Qari Mahmood Al-Hussary"},
              }
            ],
            "Completed Assignment": [
              {
                "id": 43,
                "title": "শারহে বেকায়া: কিতাবুত তাহারাত ও কিতাবুস্ সালাত",
                "description": "বিস্তারিত উত্তর...",
                "deadline": "01-08-2026",
                "status": "Expired",
                "assignment_status": "Completed Assignment",
                "course": {"id": 1, "name": "Nurani"},
                "batch": {"id": 2, "name": "Nurani - Evening Batch"},
                "teacher": {"id": 33, "name": "Brandy Osinski PhD"},
              }
            ]
          }
        }
      };

      final hwProvider = HomeworkProvider(HomeworkRepository(fakeClient));
      await hwProvider.load();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<HomeworkProvider>.value(value: hwProvider),
              ChangeNotifierProvider<AuthProvider>.value(
                value: FakeAuthProvider(sampleStudent),
              ),
            ],
            child: const HomeworkTab(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Top Filter bar
      expect(find.text('All Courses'), findsOneWidget);
      expect(find.text('Nurani'), findsWidgets);

      // Batch indicator
      expect(find.text('Nurani - Evening Batch'), findsWidgets);

      // Section titles
      expect(find.text('Ongoing Assignment'), findsOneWidget);
      expect(find.text('Completed Assignment'), findsOneWidget);

      // AS badge
      expect(find.text('AS'), findsWidgets);

      // Bengali titles
      expect(find.text("ইলমুন নাহব: এ'রাব ও আমেল চেনার নিয়মাবলী"), findsOneWidget);
      expect(find.text("শারহে বেকায়া: কিতাবুত তাহারাত ও কিতাবুস্ সালাত"), findsOneWidget);

      // Metadata icons and items
      expect(find.text('Due Date: '), findsWidgets);
      expect(find.text('04-10-2026'), findsOneWidget);
      expect(find.text('Due'), findsWidgets);
      expect(find.text('Expired'), findsWidgets);
    });
  });

  group('HomeworkDetailScreen Widget', () {
    testWidgets('renders Homework Information, Submission List, and Submit Your Homework options', (tester) async {
      final fakeClient = FakeApiClient();
      fakeClient.stubbedGetResult = {
        "assignment": {
          "id": 35,
          "title": "ইলমুন নাহব: এ'রাব ও আমেল চেনার নিয়মাবলী",
          "description": "নির্ধারিত বিষয়ের ওপর বিস্তারিত উত্তর লিখে আগামী নির্ধারিত তা...",
          "deadline": "05-09-2026",
          "status": "Expired",
          "course": {"id": 1, "name": "Nurani"},
          "batch": {"id": 2, "name": "Nurani - Evening Batch"},
          "teacher": {"id": 20, "name": "Qari Mahmood Al-Hussary"},
          "submitted": [
            {
              "id": 160,
              "student_id": "82",
              "assignment_url": "https://example.com/files/sample.pdf",
              "description": "Seeded assignme see more...",
              "gained_mark": "68",
              "completed": "1",
            }
          ]
        }
      };

      final hwProvider = HomeworkProvider(HomeworkRepository(fakeClient));

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<HomeworkProvider>.value(value: hwProvider),
              ChangeNotifierProvider<AuthProvider>.value(
                value: FakeAuthProvider(sampleStudent),
              ),
            ],
            child: const HomeworkDetailScreen(homeworkId: 35),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Homework Information Card
      expect(find.text('Homework Information'), findsOneWidget);
      expect(find.text('Course: '), findsOneWidget);
      expect(find.text('Batch: '), findsOneWidget);
      expect(find.text('Teacher: '), findsOneWidget);
      expect(find.text('Due Date: '), findsOneWidget);
      expect(find.text('05-09-2026'), findsOneWidget);

      // Submission List Table
      expect(find.text('Submission List'), findsOneWidget);
      expect(find.text('Student'), findsOneWidget);
      expect(find.text('File'), findsOneWidget);
      expect(find.text('Mark'), findsOneWidget);
      expect(find.text('Download File'), findsOneWidget);

      // Submit Your Homework Card
      expect(find.text('Submit Your Homework'), findsOneWidget);
      expect(find.text('Option 1: Upload a File'), findsOneWidget);
      expect(find.text('Click to select a file'), findsOneWidget);
      expect(find.text('OR'), findsOneWidget);
      expect(find.text('Option 2: Record Audio'), findsOneWidget);
      expect(find.text('Start Recording'), findsOneWidget);
      expect(find.text('Description'), findsWidgets);
    });
  });
}
