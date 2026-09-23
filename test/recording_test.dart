import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:darul_amal/core/network/api_client.dart';
import 'package:darul_amal/data/repositories/recording_repository.dart';
import 'package:darul_amal/providers/recording_provider.dart';
import 'package:darul_amal/ui/screens/recordings/recordings_screen.dart';

class FakeApiClient implements ApiClient {
  dynamic stubbedGetResult;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    return stubbedGetResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('RecordingRepository', () {
    late FakeApiClient fakeClient;
    late RecordingRepository repository;

    setUp(() {
      fakeClient = FakeApiClient();
      repository = RecordingRepository(fakeClient);
    });

    test('list() correctly parses nested recordings structure returned by student API', () async {
      fakeClient.stubbedGetResult = {
        "recordings": {
          "current_page": 1,
          "data": [
            {
              "id": 19,
              "title": "Nurani Qaida - Lesson 7: সুরা আল-ফাতিহা সহিহ তিলাওয়াত",
              "description": "A word-by-word explanation...",
              "video_type": "youtube",
              "video_url": "https://www.youtube.com/watch?v=X2YnP50cwNU",
              "sources": [
                {
                  "type": "youtube",
                  "url": "https://www.youtube.com/watch?v=X2YnP50cwNU"
                }
              ],
              "embed_url": "https://www.youtube.com/embed/X2YnP50cwNU",
              "thumbnail_url": "https://img.youtube.com/vi/X2YnP50cwNU/hqdefault.jpg",
              "course": {
                "id": 4,
                "name": "Ibtidaiyyah"
              },
              "batch": {
                "id": 8,
                "name": "Ibtidaiyyah - Noon Batch"
              },
              "subject": null,
              "teacher": {
                "id": 15,
                "name": "Ustadha Zainab Chowdhury"
              },
              "created_at": "2026-09-22 17:57:17"
            }
          ],
          "per_page": 12,
          "total": 6,
          "last_page": 1
        },
        "batches": [],
        "courses": [],
        "filters": []
      };

      final result = await repository.list();

      expect(result.items.length, 1);
      final recording = result.items.first;
      expect(recording.id, 19);
      expect(recording.title, contains('Nurani Qaida'));
      expect(recording.isYoutube, isTrue);
      expect(recording.thumbnailUrl, contains('hqdefault.jpg'));
      expect(recording.displayThumbnail, contains('hqdefault.jpg'));
      expect(recording.course?.name, 'Ibtidaiyyah');
      expect(recording.batch?.name, 'Ibtidaiyyah - Noon Batch');
      expect(recording.teacher?.name, 'Ustadha Zainab Chowdhury');
      expect(result.pagination.total, 6);
      expect(result.pagination.currentPage, 1);
      expect(result.pagination.lastPage, 1);
    });

    test('detail() unwraps nested recording object', () async {
      fakeClient.stubbedGetResult = {
        "recording": {
          "id": 19,
          "title": "Nurani Qaida - Lesson 7",
          "video_type": "youtube",
          "video_url": "https://www.youtube.com/watch?v=X2YnP50cwNU"
        }
      };

      final recording = await repository.detail(19);
      expect(recording.id, 19);
      expect(recording.title, "Nurani Qaida - Lesson 7");
    });
  });

  group('RecordingsScreen Widget', () {
    testWidgets('renders recording cards with thumbnails and batch/course info', (tester) async {
      final fakeClient = FakeApiClient();
      fakeClient.stubbedGetResult = {
        "recordings": {
          "current_page": 1,
          "data": [
            {
              "id": 19,
              "title": "Nurani Qaida - Lesson 7",
              "video_type": "youtube",
              "video_url": "https://www.youtube.com/watch?v=X2YnP50cwNU",
              "thumbnail_url": "https://img.youtube.com/vi/X2YnP50cwNU/hqdefault.jpg",
              "course": {
                "id": 4,
                "name": "Ibtidaiyyah"
              },
              "batch": {
                "id": 8,
                "name": "Ibtidaiyyah - Noon Batch"
              },
              "teacher": {
                "id": 15,
                "name": "Ustadha Zainab Chowdhury"
              },
              "created_at": "2026-09-22 17:57:17"
            }
          ],
          "per_page": 12,
          "total": 1,
          "last_page": 1
        },
        "batches": [],
        "courses": [],
        "filters": []
      };

      final provider = RecordingProvider(RecordingRepository(fakeClient));
      await provider.load();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<RecordingProvider>.value(
            value: provider,
            child: const RecordingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Recordings'), findsOneWidget);
      expect(find.text('Nurani Qaida - Lesson 7'), findsOneWidget);
      expect(find.textContaining('Ibtidaiyyah'), findsOneWidget);
    });
  });
}
