import 'package:darul_amal/data/models/dashboard_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DashboardClass', () {
    // Shape of a `today_classes` entry (Sep 2026).
    Map<String, dynamic> entry({
      bool live = false,
      bool past = false,
      bool future = true,
    }) =>
        {
          'id': 'batch-8',
          'topic': 'Hidayatun Nahw',
          'start_time': '2026-09-24T11:30:00+00:00',
          'end_time': '2026-09-24T13:00:00+00:00',
          'is_live_now': live,
          'is_past': past,
          'is_future': future,
          'course': {'id': 4, 'name': 'Ibtidaiyyah'},
        };

    test('shows the scheduled wall-clock time, not a timezone shift', () {
      final c = DashboardClass.fromJson(entry());

      expect(c.startTime, '11:30 AM');
      expect(c.endTime, '1:00 PM');
      expect(c.timeRange, '11:30 AM – 1:00 PM');
      expect(c.date, DateTime(2026, 9, 24));
    });

    test('reads the topic as the title', () {
      expect(DashboardClass.fromJson(entry()).title, 'Hidayatun Nahw');
      expect(
        DashboardClass.fromJson({...entry(), 'topic': null}).title,
        'Ibtidaiyyah',
      );
    });

    test('status comes from the is_* flags', () {
      expect(DashboardClass.fromJson(entry()).isUpcoming, isTrue);
      expect(
        DashboardClass.fromJson(entry(live: true, future: false)).isOngoing,
        isTrue,
      );
      expect(
        DashboardClass.fromJson(entry(past: true, future: false)).isCompleted,
        isTrue,
      );
    });

    test('still handles plain and pre-formatted times', () {
      final plain = DashboardClass.fromJson({
        'start_time': '18:00:00',
        'end_time': '19:30:00',
      });
      expect(plain.timeRange, '6:00 PM – 7:30 PM');
      expect(plain.date, isNull);

      final formatted = DashboardClass.fromJson({'start_time': '9:00 AM'});
      expect(formatted.timeRange, '9:00 AM');
    });
  });
}
