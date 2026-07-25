/// Defensive JSON readers.
///
/// The API is still evolving, so never assume a key exists or has the
/// expected type — a null here should not crash a screen.
int? asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v.toString());
}

int asInt(dynamic v, {int fallback = 0}) => asIntOrNull(v) ?? fallback;

double asDouble(dynamic v, {double fallback = 0}) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

String? asStringOrNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

String asString(dynamic v, {String fallback = ''}) =>
    asStringOrNull(v) ?? fallback;

bool asBool(dynamic v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return fallback;
}

/// Laravel returns timestamps as "2025-03-24 21:00:00" (space, not T).
DateTime? asDate(dynamic v) {
  final s = asStringOrNull(v);
  if (s == null) return null;
  return DateTime.tryParse(s.replaceFirst(' ', 'T'));
}

Map<String, dynamic>? asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

/// Safely maps a JSON list into models.
List<T> asList<T>(dynamic v, T Function(Map<String, dynamic>) builder) {
  if (v is! List) return <T>[];
  return v
      .whereType<Map>()
      .map((e) => builder(Map<String, dynamic>.from(e)))
      .toList();
}
