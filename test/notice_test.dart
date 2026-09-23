import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:darul_amal/core/network/api_client.dart';
import 'package:darul_amal/core/storage/read_state_storage.dart';
import 'package:darul_amal/data/repositories/notice_repository.dart';
import 'package:darul_amal/providers/notice_provider.dart';
import 'package:darul_amal/ui/screens/notices/notice_tab.dart';

class FakeApiClient implements ApiClient {
  dynamic stubbedGetResult;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    return stubbedGetResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeReadStateStorage extends ReadStateStorage {
  @override
  Future<Set<int>> readNoticeIds() async => <int>{};

  @override
  Future<void> markNoticeRead(int id) async {}

  @override
  Future<void> clear() async {}
}

void main() {
  group('NoticeRepository', () {
    late FakeApiClient fakeClient;
    late NoticeRepository repository;

    setUp(() {
      fakeClient = FakeApiClient();
      repository = NoticeRepository(fakeClient);
    });

    test('list() correctly parses nested notices structure returned by student API', () async {
      fakeClient.stubbedGetResult = {
        "notices": {
          "current_page": 1,
          "data": [
            {
              "id": 5,
              "title": "অভিভাবক সমাবেশ",
              "description": null,
              "excerpt": "ছাত্রদের পড়াশোনা, আখলাক ও সার্বিক অগ্রগতি নিয়ে আলোচনার লক্ষ্যে...",
              "publish_date": "2026-09-11",
              "publish_at": "Sep 11, 2026 at 12:00 AM",
              "priority": "normal",
              "pinned": false,
              "attachment_url": "https://darulamal.nexcoreit4u.com/images/teacher-demo.png",
              "is_read": false,
              "created_at": "2026-09-11 00:00:00",
              "updated_at": "2026-10-01 00:00:00"
            }
          ],
          "per_page": 10,
          "total": 1,
          "last_page": 1
        },
        "filters": []
      };

      final result = await repository.list();

      expect(result.items.length, 1);
      final notice = result.items.first;
      expect(notice.id, 5);
      expect(notice.title, "অভিভাবক সমাবেশ");
      expect(notice.displayBody, "ছাত্রদের পড়াশোনা, আখলাক ও সার্বিক অগ্রগতি নিয়ে আলোচনার লক্ষ্যে...");
      expect(notice.displayDate, "Sep 11, 2026 at 12:00 AM");
      expect(notice.formattedDate, "11-09-2026");
      expect(notice.attachmentUrl, "https://darulamal.nexcoreit4u.com/images/teacher-demo.png");
      expect(notice.hasAttachment, isTrue);
      expect(result.pagination.total, 1);
      expect(result.pagination.currentPage, 1);
      expect(result.pagination.lastPage, 1);
    });

    test('list() also supports raw list or direct data paginator', () async {
      fakeClient.stubbedGetResult = [
        {
          "id": 8,
          "title": "Raw List Notice",
          "description": "Notice details",
          "is_read": false
        }
      ];

      final result = await repository.list();
      expect(result.items.length, 1);
      expect(result.items.first.title, "Raw List Notice");
    });

    test('detail() extracts nested notice payload', () async {
      fakeClient.stubbedGetResult = {
        "notice": {
          "id": 5,
          "title": "অভিভাবক সমাবেশ",
          "description": "বিস্তারিত বিবরণ",
          "publish_date": "2026-09-11",
          "attachment_url": "https://darulamal.nexcoreit4u.com/images/teacher-demo.png",
          "is_read": false
        }
      };

      final detail = await repository.detail(5);
      expect(detail.id, 5);
      expect(detail.title, "অভিভাবক সমাবেশ");
      expect(detail.description, "বিস্তারিত বিবরণ");
      expect(detail.hasAttachment, isTrue);
    });
  });

  group('NoticeTab Widget', () {
    testWidgets('renders redesigned notice cards with banner, date, title, and action footer', (tester) async {
      final fakeClient = FakeApiClient();
      fakeClient.stubbedGetResult = {
        "notices": {
          "current_page": 1,
          "data": [
            {
              "id": 5,
              "title": "অভিভাবক সমাবেশ",
              "description": null,
              "excerpt": "ছাত্রদের পড়াশোনা, আখলাক ও সার্বিক অগ্রগতি নিয়ে আলোচনার লক্ষ্যে আগামী শুক্রবার বাদ জুমা একটি অভিভাবক সমাবেশ অনুষ্ঠিত হবে।",
              "publish_date": "2026-09-11",
              "publish_at": "Sep 11, 2026 at 12:00 AM",
              "priority": "normal",
              "pinned": false,
              "attachment_url": "https://darulamal.nexcoreit4u.com/images/teacher-demo.png",
              "is_read": false,
              "created_at": "2026-09-11 00:00:00",
              "updated_at": "2026-10-01 00:00:00"
            }
          ],
          "per_page": 10,
          "total": 1,
          "last_page": 1
        },
        "filters": []
      };

      final provider = NoticeProvider(NoticeRepository(fakeClient), FakeReadStateStorage());
      await provider.loadNotices();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<NoticeProvider>.value(
            value: provider,
            child: const NoticeTab(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notices'), findsOneWidget);
      expect(find.text('অভিভাবক সমাবেশ'), findsOneWidget);
      expect(find.text('Read Full Notice'), findsOneWidget);
      expect(find.textContaining('11-09-2026'), findsOneWidget);
      expect(find.textContaining('Comments'), findsOneWidget);
    });
  });
}
