import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:darul_amal/core/network/api_client.dart';
import 'package:darul_amal/data/models/attendance.dart';
import 'package:darul_amal/data/models/class_routine.dart';
import 'package:darul_amal/data/models/dashboard_data.dart';
import 'package:darul_amal/data/models/fee.dart';
import 'package:darul_amal/data/models/homework.dart';
import 'package:darul_amal/data/models/notice.dart';
import 'package:darul_amal/data/models/pagination.dart';
import 'package:darul_amal/data/models/quran_progress.dart';
import 'package:darul_amal/data/models/recording.dart';
import 'package:darul_amal/data/models/student_user.dart';
import 'package:darul_amal/data/models/support_ticket.dart';
import 'package:darul_amal/data/repositories/homework_repository.dart';

/// Parses the real captured API responses through every model.
///
/// These are the actual bodies from the 26 Jul 2026 Postman run against
/// course.nexcoreit4u.com, not hand-written fixtures — so a shape change
/// on the backend shows up here rather than as a null on a screen.
void main() {
  late Map<String, Map<String, dynamic>> responses;

  setUpAll(() {
    final raw = File('test/fixtures/raw-responses.json').readAsStringSync();
    final list = jsonDecode(raw) as List;
    responses = {
      for (final e in list.cast<Map<String, dynamic>>())
        '${e['method']} ${(e['url'] as String).split('/api/').last}': e,
    };
  });

  /// The `data` payload of a successful response.
  dynamic payload(String key) {
    final entry = responses[key];
    expect(entry, isNotNull, reason: 'missing capture for $key');
    expect(entry!['status'], anyOf(200, 201), reason: '$key was not a success');
    return (entry['json'] as Map<String, dynamic>)['data'];
  }

  Map<String, dynamic> mapPayload(String key) =>
      payload(key) as Map<String, dynamic>;

  group('auth', () {
    test('verify-otp parses the FLAT user shape', () {
      final data = mapPayload('POST auth/verify-otp');
      final user = StudentUser.fromJson(
        data['user'] as Map<String, dynamic>,
      );

      expect(user.id, 9);
      expect(user.name, 'Mehadi Hasan');
      expect(user.studentId, 'STD-00001');
      expect(user.rollNo, '111E');
      expect(user.courses.single.name, 'Dawra-e-Hadith');
    });

    test('GET profile parses the NESTED shape and keeps identity fields', () {
      final data = mapPayload('GET auth/student/profile');
      final user = StudentUser.fromJson(
        data['user'] as Map<String, dynamic>,
      );

      // The regression this model exists to prevent: these live under
      // `profile` on this endpoint but at the root on every other one.
      expect(user.studentId, 'STD-00001');
      expect(user.rollNo, '111E');
      expect(user.session, '2023-2023');
      expect(user.bloodGroup, 'O+');

      // Only the nested payload carries these — they drive Edit Profile.
      expect(user.phone, '8801644339012');
      expect(user.address, 'Dhaka');
      expect(user.gender, 'male');
      expect(user.dateOfBirth, '2014-01-31');
    });

    test('cache round-trip is lossless', () {
      final data = mapPayload('GET auth/student/profile');
      final user = StudentUser.fromJson(data['user'] as Map<String, dynamic>);
      final restored = StudentUser.fromJson(user.toJson());

      expect(restored.studentId, user.studentId);
      expect(restored.rollNo, user.rollNo);
      expect(restored.phone, user.phone);
      expect(restored.bloodGroup, user.bloodGroup);
      expect(restored.dateOfBirth, user.dateOfBirth);
      expect(restored.courses.length, user.courses.length);
    });

    test('flat PUT response does not blank nested-only fields', () {
      final full = StudentUser.fromJson(
        mapPayload('GET auth/student/profile')['user'] as Map<String, dynamic>,
      );
      final afterUpdate = StudentUser.fromJson(
        mapPayload('PUT auth/student/profile')['user'] as Map<String, dynamic>,
      );

      // Applied verbatim the update response would wipe these.
      expect(afterUpdate.phone, isNull);

      final merged = full.mergedWith(afterUpdate);
      expect(merged.phone, '8801644339012');
      expect(merged.address, 'Dhaka');
      expect(merged.studentId, 'STD-00001');
    });
  });

  group('dashboard', () {
    test('parses every section including the previously dropped ones', () {
      final d = DashboardData.fromJson(mapPayload('GET student/dashboard'));

      expect(d.quickStats.totalCourses, 1);
      expect(d.quickStats.attendancePercentage, 33);
      expect(d.isDue, isTrue);
      expect(d.dueAmount, 638);

      // `total_amount` arrives as the string "1364.00".
      expect(d.totalAmount, 1364);
      expect(d.totalDueAmount, 1364);

      expect(d.presentClasses, 33);
      expect(d.lateClasses, 29);
      expect(d.absentClasses, 38);

      expect(d.upcomingEvents.length, 5);
      expect(d.upcomingEvents.first.title, contains('মাহফিল'));

      expect(d.attendanceBySubject, isNotEmpty);
      final nurani = d.attendanceBySubject.first;
      expect(nurani.subjectName, 'Nurani Qaida');
      expect(nurani.presentScore, closeTo(66.67, 0.01));
      expect(nurani.fraction, inInclusiveRange(0.0, 1.0));
    });
  });

  group('fees', () {
    test('dues parse, including string amounts and mixed currencies', () {
      final map = mapPayload('GET student/fees/dues');
      final page = Paginated(
        items: (map['data'] as List)
            .cast<Map<String, dynamic>>()
            .map(FeeTransaction.fromJson)
            .toList(),
        pagination: Pagination.fromEnvelope(map),
      );

      expect(page.pagination.total, 1);
      final due = page.items.single;
      expect(due.id, 59);
      expect(due.transactionNo, 'TRN_2607250519086A64F00C6B27D');
      expect(due.amount, 638.0);
      expect(due.currency, 'GBP');
      expect(due.isPaid, isFalse);
      expect(due.invoiceId, 59);
      expect(due.outstanding, 638.0);
      expect(due.amountLabel, 'GBP 638.00');
      expect(due.dueDateLabel, 'Jul 27, 2026');
    });

    test('history rows come back marked paid', () {
      final map = mapPayload('GET student/fees/history');
      final txn = FeeTransaction.fromJson(
        (map['data'] as List).first as Map<String, dynamic>,
      );
      expect(txn.isPaid, isTrue);
      expect(txn.statusLabel, 'Paid');
      expect(txn.currency, 'EUR');
    });
  });

  group('attendance', () {
    test('subject-keyed map flattens into sorted groups', () {
      final groups =
          SubjectAttendanceGroup.parseAll(payload('GET student/my-attendances'));

      expect(groups, isNotEmpty);

      // Names come off the records, not the map key.
      expect(
        groups.map((g) => g.subjectName),
        everyElement(isNot(startsWith('Subject '))),
      );

      // Sorted alphabetically.
      final names = groups.map((g) => g.subjectName).toList();
      expect(names, orderedEquals([...names]..sort()));

      final nurani = groups.firstWhere((g) => g.subjectName == 'Nurani Qaida');
      expect(nurani.total, 3);
      expect(nurani.present, 2);
      expect(nurani.late, 1);
      // Late must not count as present.
      expect(nurani.percentage, 67);

      final summary = AttendanceSummary.from(groups);
      expect(summary.total, greaterThan(0));
      expect(summary.percentage, inInclusiveRange(0, 100));
    });
  });

  group('recordings', () {
    test('paginated list parses both video types', () {
      final map = mapPayload('GET student/recordings');
      final items = (map['data'] as List)
          .cast<Map<String, dynamic>>()
          .map(Recording.fromJson)
          .toList();

      expect(Pagination.fromEnvelope(map).total, 8);
      expect(items.length, 8);

      final drive = items.firstWhere((r) => r.isDrive);
      expect(drive.title, 'Hifz Revision Session');
      expect(drive.sourceLabel, 'Google Drive');
      expect(drive.isPlayable, isTrue);
      expect(drive.embedUrl, contains('/preview'));

      final yt = items.firstWhere((r) => r.isYoutube);
      expect(yt.sourceLabel, 'YouTube');
      expect(yt.embedUrl, contains('/embed/'));
    });

    test('detail parses', () {
      final r = Recording.fromJson(mapPayload('GET student/recordings/1'));
      expect(r.id, 1);
      expect(r.teacher?.name, 'Olin Wintheiser');
      expect(r.subject?.name, 'Aqidah');
      expect(r.batch?.name, 'Nazera Quran Evening Batch B');
    });

    test('parses backend recordings payload with thumbnail_url, sources, and course/batch', () {
      final json = <String, dynamic>{
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
      };

      final r = Recording.fromJson(json);
      expect(r.id, 19);
      expect(r.title, contains('Nurani Qaida'));
      expect(r.isYoutube, isTrue);
      expect(r.isYoutubePlayable, isTrue);
      expect(r.youtubeId, 'X2YnP50cwNU');
      expect(r.thumbnailUrl, 'https://img.youtube.com/vi/X2YnP50cwNU/hqdefault.jpg');
      expect(r.displayThumbnail, 'https://img.youtube.com/vi/X2YnP50cwNU/hqdefault.jpg');
      expect(r.course?.name, 'Ibtidaiyyah');
      expect(r.batch?.name, 'Ibtidaiyyah - Noon Batch');
      expect(r.teacher?.name, 'Ustadha Zainab Chowdhury');
      expect(r.subtitleInfo, contains('Ibtidaiyyah'));
      expect(r.sources.length, 1);
      expect(r.sources.first.type, 'youtube');
      expect(r.recordedAt, isNotNull);
    });
  });

  group('quran', () {
    test('bundle tolerates a null progress and reads reference data', () {
      final bundle =
          QuranProgressBundle.fromJson(mapPayload('GET student/quran-progress'));

      // No progress recorded for this student yet — must not throw.
      expect(bundle.progress, isNull);
      expect(bundle.hasProgress, isFalse);
      expect(bundle.logs, isEmpty);

      expect(bundle.reference.surahs.length, 114);
      expect(bundle.reference.surahs.first.nameEn, 'Al-Fatihah');
      expect(bundle.reference.totalParas, 30);
      expect(bundle.reference.totalLessons, 27);
      expect(
        bundle.reference.focusLabel('pronunciation'),
        contains('উচ্চারণ'),
      );
      expect(bundle.reference.surahName(1), 'Al-Fatihah');
    });
  });

  group('notices', () {
    test('list paginator parses with Bangla content', () {
      final map = mapPayload('GET student/notices');
      final notices = (map['data'] as List)
          .cast<Map<String, dynamic>>()
          .map(Notice.fromJson)
          .toList();

      expect(notices, isNotEmpty);
      expect(notices.first.title, contains('রমজান'));
      expect(notices.first.hasAttachment, isTrue);
      expect(notices.first.allAttachments, hasLength(1));
      // Server always reports false; the app overlays local read state.
      expect(notices.first.isRead, isFalse);
    });

    test('detail merges attachment shapes and copyWith preserves fields', () {
      final n = Notice.fromJson(mapPayload('GET student/notices/4'));
      expect(n.id, 4);
      expect(n.type, 'Students');
      expect(n.allAttachments, hasLength(1));

      final read = n.copyWith(isRead: true);
      expect(read.isRead, isTrue);
      expect(read.title, n.title);
      expect(read.allAttachments, n.allAttachments);
    });

    test('backend student notices payload parses correctly with null description and attachment_url', () {
      final json = <String, dynamic>{
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
      };

      final notice = Notice.fromJson(json);
      expect(notice.id, 5);
      expect(notice.title, 'অভিভাবক সমাবেশ');
      expect(notice.description, isNull);
      expect(notice.excerpt, startsWith('ছাত্রদের'));
      expect(notice.displayBody, startsWith('ছাত্রদের'));
      expect(notice.publishDate, '2026-09-11');
      expect(notice.publishAt, 'Sep 11, 2026 at 12:00 AM');
      expect(notice.displayDate, 'Sep 11, 2026 at 12:00 AM');
      expect(notice.priority, 'normal');
      expect(notice.pinned, isFalse);
      expect(notice.isPinned, isFalse);
      expect(notice.attachmentUrl, contains('teacher-demo.png'));
      expect(notice.hasAttachment, isTrue);
      expect(notice.allAttachments, contains('https://darulamal.nexcoreit4u.com/images/teacher-demo.png'));
      expect(notice.isRead, isFalse);
    });
  });

  group('homework', () {
    test('list parses and derives due labels', () {
      final items = (payload('GET student/homework') as List)
          .cast<Map<String, dynamic>>()
          .map(Homework.fromJson)
          .toList();

      expect(items, isNotEmpty);
      final first = items.first;
      expect(first.id, 48);
      expect(first.subject?.name, 'Arabic Nahw');
      expect(first.isSubmitted, isFalse);
      expect(first.isOverdue, isFalse);
      expect(first.dueLabel, isNotEmpty);
    });

    test('parses nested category-keyed assignments payload', () {
      final sampleBackendPayload = {
        'assignments': {
          'current_page': 1,
          'data': {
            'Ongoing Assignment': [
              {
                'id': 35,
                'user_id': 20,
                'subject_id': 41,
                'title': 'Dexter Becker',
                'start_date': '15-07-2026',
                'end_date': '11-08-2026',
                'mark': 143,
                'description': 'Lorem ipsum',
                'submitted_done': false,
                'status': 'Due',
                'remaining_days': 9,
                'issue': 'Jul 15 , 2026',
                'deadline': '11-08-2026',
                'submissions': '0.00',
                'assignment_status': 'Ongoing Assignment',
                'subject': {
                  'id': 41,
                  'name': 'Fiqh',
                  'color': '#FF00FF',
                },
              }
            ]
          }
        }
      };

      final items = HomeworkRepository.extractHomeworkMaps(sampleBackendPayload)
          .map(Homework.fromJson)
          .toList();

      expect(items, hasLength(1));
      final hw = items.first;
      expect(hw.id, 35);
      expect(hw.title, 'Dexter Becker');
      expect(hw.subject?.name, 'Fiqh');
      expect(hw.assignedDate, '15-07-2026');
      expect(hw.dueDate, '11-08-2026');
      expect(hw.marks, '143');
      expect(hw.isPending, isTrue);
      expect(hw.isSubmitted, isFalse);
    });

    test('submit requires either text or file attachment', () {
      final repo = HomeworkRepository(ApiClient());
      expect(
        () => repo.submit(id: 1, text: null, audioPath: null),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repo.submit(id: 1, text: '   ', audioPath: ''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('tickets', () {
    test('create response parses from the root, not a ticket wrapper', () {
      final t = SupportTicket.fromJson(mapPayload('POST student/tickets'));

      expect(t.id, 13);
      expect(t.ticketNo, 'TKT-GWY9WQEO');
      expect(t.category, 'class_time_change');
      expect(t.priority, 'high');
      expect(t.priorityLabel, 'High');
      expect(t.isHighPriority, isTrue);

      // Derived from `status`, since `is_resolved` is not a column.
      expect(t.status, 'open');
      expect(t.isResolved, isFalse);
      expect(t.statusLabel, 'Open');
    });

    test('list parses as a raw Laravel paginator', () {
      final map = mapPayload('GET student/tickets');
      final page = Paginated(
        items: (map['data'] as List)
            .cast<Map<String, dynamic>>()
            .map(SupportTicket.fromJson)
            .toList(),
        pagination: Pagination.fromEnvelope(map),
      );

      expect(page.items, isEmpty);
      expect(page.pagination.total, 0);
      expect(page.pagination.perPage, 15);
      expect(page.pagination.hasMore, isFalse);
    });
  });

  group('classes', () {
    test('my-classes parses the renamed endpoint', () {
      final list = payload('GET student/my-classes') as List;
      expect(list, hasLength(1));
      final course = (list.first as Map<String, dynamic>)['course']
          as Map<String, dynamic>;
      expect(course['name'], 'Dawra-e-Hadith');
    });

    test('routine bundle tolerates empty routines', () {
      final b = ClassRoutineBundle.fromJson(
        mapPayload('GET student/my-class-routine'),
      );

      expect(b.routines, isEmpty);
      expect(b.schedules, isEmpty);
      expect(b.teachers, hasLength(25));
      expect(b.isEmpty, isTrue);
      expect(b.byWeekday, isEmpty);
      expect(b.teachers.first.display, 'Teacher');
    });
  });

  group('failure modes are non-fatal', () {
    test('models survive empty and malformed input', () {
      expect(() => StudentUser.fromJson({}), returnsNormally);
      expect(() => FeeTransaction.fromJson({}), returnsNormally);
      expect(() => Recording.fromJson({}), returnsNormally);
      expect(() => Homework.fromJson({}), returnsNormally);
      expect(() => SupportTicket.fromJson({}), returnsNormally);
      expect(() => QuranProgressBundle.fromJson({}), returnsNormally);
      expect(() => ClassRoutineBundle.fromJson({}), returnsNormally);
      expect(() => DashboardData.fromJson({}), returnsNormally);

      // Attendance receives a list where a map is expected.
      expect(SubjectAttendanceGroup.parseAll([1, 2, 3]), isEmpty);
      expect(SubjectAttendanceGroup.parseAll(null), isEmpty);

      // HomeworkDetail.attachments arrives as a map, a list, or null.
      expect(HomeworkDetail.fromJson({'attachments': null}).attachments,
          isEmpty);
      expect(
        HomeworkDetail.fromJson({
          'attachments': {'assignment_url': 'https://x/y.pdf'},
        }).attachments,
        ['https://x/y.pdf'],
      );
      expect(
        HomeworkDetail.fromJson({
          'attachments': ['https://x/a.pdf', 'https://x/b.pdf'],
        }).attachments,
        hasLength(2),
      );
    });

    test('subject colour parses hex or degrades to null', () {
      expect(const SubjectRef(color: '#808080').colorValue, isNotNull);
      expect(const SubjectRef(color: '808080').colorValue, isNotNull);
      expect(const SubjectRef(color: 'not-a-colour').colorValue, isNull);
      expect(const SubjectRef().colorValue, isNull);
    });
  });
}
