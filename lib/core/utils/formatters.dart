/// Small display helpers (no intl dependency needed).
class Fmt {
  Fmt._();

  static const List<String> _weekdays = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday', // index 7 — backend also uses 7 for Sunday
  ];

  /// "21:00:00" -> "9:00 PM"
  static String time(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '--';
    final parts = raw.trim().split(':');
    if (parts.length < 2) return raw;

    final h = int.tryParse(parts[0]);
    if (h == null) return raw;

    final minute = parts[1].padLeft(2, '0');
    final suffix = h >= 12 ? 'PM' : 'AM';
    var hour12 = h % 12;
    if (hour12 == 0) hour12 = 12;

    return '$hour12:$minute $suffix';
  }

  /// "21:00:00" + "22:00:00" -> "9:00 PM – 10:00 PM"
  static String timeRange(String? start, String? end) {
    if (end == null || end.trim().isEmpty) return time(start);
    return '${time(start)} – ${time(end)}';
  }

  static String weekday(int? index) {
    if (index == null || index < 0 || index >= _weekdays.length) return '';
    return _weekdays[index];
  }

  /// "2025-03-24 12:00:00" -> "24 Mar 2025"
  static String date(DateTime? d) {
    if (d == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  /// Relative-ish label for ticket lists.
  static String ago(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(d);
  }

  static String initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return _head(parts.first).toUpperCase();
    }
    return (_head(parts[0]) + _head(parts[1])).toUpperCase();
  }
}

String _head(String s) => s.isEmpty ? '' : s.substring(0, 1);
