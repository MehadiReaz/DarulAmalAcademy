import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local persistence for "I have seen this" state.
///
/// The backend does not store notice read-state: `studentNoticeRead`
/// returns success without writing anything, and both the list and detail
/// endpoints hardcode `is_read: false`. Until a `notice_reads` table
/// exists server-side, tracking it locally is the only way unread badges
/// survive a cold start.
///
/// Uses the same secure-storage backend as the auth token rather than
/// pulling in a second persistence dependency.
class ReadStateStorage {
  static const _kReadNotices = 'read_notice_ids';

  /// Ceiling on how many IDs are retained. Notices are read newest-first
  /// and old ones fall out of the paginated list anyway, so an unbounded
  /// set would only ever grow.
  static const _maxTracked = 500;

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<Set<int>> readNoticeIds() async {
    try {
      final raw = await _storage.read(key: _kReadNotices);
      if (raw == null || raw.isEmpty) return <int>{};
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <int>{};
      return decoded
          .map((e) => e is int ? e : int.tryParse(e.toString()))
          .whereType<int>()
          .toSet();
    } catch (_) {
      // A corrupt or unreadable entry should never block the notice list.
      return <int>{};
    }
  }

  Future<void> markNoticeRead(int id) async {
    try {
      final current = await readNoticeIds();
      if (current.contains(id)) return;

      // Newest last, so trimming from the front drops the oldest.
      final updated = [...current, id];
      final trimmed = updated.length > _maxTracked
          ? updated.sublist(updated.length - _maxTracked)
          : updated;

      await _storage.write(key: _kReadNotices, value: jsonEncode(trimmed));
    } catch (_) {
      // Best-effort: failing to persist read state is not worth an error
      // surface in the UI.
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _kReadNotices);
    } catch (_) {
      // Ignore.
    }
  }
}
