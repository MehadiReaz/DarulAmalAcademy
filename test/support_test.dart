import 'package:darul_amal/data/models/support_contact.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupportContact', () {
    test('parses GET /api/student/support in server order', () {
      final contacts = SupportContact.listFrom({
        'admin_support': {
          'label': 'Admin Support',
          'channel': 'whatsapp',
          'phone': '910000000001',
          'url': 'https://wa.me/910000000001',
        },
        'help_center': {
          'label': 'Help Center',
          'channel': 'whatsapp',
          'phone': '910000000002',
          'url': 'https://wa.me/910000000002',
        },
      });

      expect(contacts.map((c) => c.label), ['Admin Support', 'Help Center']);
      expect(contacts.first.isWhatsApp, isTrue);
      expect(
        contacts.first.launchUri.toString(),
        'https://wa.me/910000000001',
      );
    });

    test('builds a wa.me link from the phone when url is missing', () {
      final c = SupportContact.fromJson('help_center', {
        'phone': '+91 00000-00002',
      });
      expect(c.label, 'Help Center');
      expect(c.launchUri.toString(), 'https://wa.me/910000000002');
    });

    test('drops entries with neither url nor phone, and junk data', () {
      expect(
        SupportContact.listFrom({
          'admin_support': {'label': 'Admin Support'},
          'note': 'not a contact',
        }),
        isEmpty,
      );
      expect(SupportContact.listFrom(null), isEmpty);
      expect(SupportContact.listFrom([1, 2]), isEmpty);
    });
  });
}
