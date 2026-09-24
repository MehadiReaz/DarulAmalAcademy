import '../../core/utils/json_utils.dart';

/// One entry from `GET /api/student/support`, e.g.
/// `admin_support: {label, channel: whatsapp, phone, url}`.
class SupportContact {
  final String key;
  final String label;
  final String channel;
  final String? phone;
  final String? url;

  const SupportContact({
    required this.key,
    required this.label,
    this.channel = 'whatsapp',
    this.phone,
    this.url,
  });

  factory SupportContact.fromJson(String key, Map<String, dynamic> json) {
    return SupportContact(
      key: key,
      label: asString(json['label'], fallback: _titleCase(key)),
      channel: asString(json['channel'], fallback: 'whatsapp').toLowerCase(),
      phone: asStringOrNull(json['phone']),
      url: asStringOrNull(json['url']),
    );
  }

  /// The link to open: the server's `url`, else a wa.me link built from
  /// the phone number. Null when neither is usable.
  Uri? get launchUri {
    final u = url == null ? null : Uri.tryParse(url!);
    if (u != null && u.hasScheme) return u;
    final digits = phone?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (digits.isEmpty) return null;
    return channel == 'whatsapp'
        ? Uri.parse('https://wa.me/$digits')
        : Uri(scheme: 'tel', path: '+$digits');
  }

  bool get isWhatsApp => channel == 'whatsapp';

  /// `data` is a map keyed by contact type; keeps only usable entries,
  /// in the order the server sent them.
  static List<SupportContact> listFrom(dynamic data) {
    final map = asMap(data);
    if (map == null) return const [];
    final contacts = <SupportContact>[];
    map.forEach((key, value) {
      final m = asMap(value);
      if (m == null) return;
      final c = SupportContact.fromJson(key.toString(), m);
      if (c.launchUri != null) contacts.add(c);
    });
    return contacts;
  }

  static String _titleCase(String key) => key
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}
