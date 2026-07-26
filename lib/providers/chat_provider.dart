import '../core/network/api_exception.dart';
import '../data/models/chat.dart';
import '../data/models/pagination.dart';
import '../data/models/student_user.dart';
import '../data/repositories/chat_repository.dart';
import 'base_provider.dart';

/// Backs the group-chat list and thread screens.
///
/// There is no realtime transport on the backend (no websocket or Pusher
/// endpoint in the collection), so the thread refreshes on open and on
/// pull-to-refresh only.
class ChatProvider extends BaseProvider {
  final ChatRepository _repo;

  ChatProvider(this._repo);

  List<ChatGroup> _groups = [];
  LoadState _groupsState = LoadState.idle;
  String? _groupsError;

  ChatGroup? _activeGroup;
  List<ChatMessage> _messages = [];
  Pagination _messagesPage = const Pagination();
  LoadState _messagesState = LoadState.idle;
  String? _messagesError;
  bool _loadingOlder = false;

  bool _sending = false;
  String? _sendError;

  List<ChatSearchHit> _searchHits = [];
  bool _searching = false;
  String _searchQuery = '';

  List<ChatGroup> get groups => _groups;
  LoadState get groupsState => _groupsState;
  String? get groupsError => _groupsError;
  int get totalUnread => _groups.fold(0, (s, g) => s + g.unreadCount);

  ChatGroup? get activeGroup => _activeGroup;
  List<ChatMessage> get messages => _messages;
  LoadState get messagesState => _messagesState;
  String? get messagesError => _messagesError;
  bool get loadingOlder => _loadingOlder;
  bool get hasOlder => _messagesPage.hasMore;

  bool get sending => _sending;
  String? get sendError => _sendError;

  List<ChatSearchHit> get searchHits => _searchHits;
  bool get searching => _searching;
  String get searchQuery => _searchQuery;

  Future<void> loadGroups({bool force = false}) async {
    if (_groupsState == LoadState.loading) return;
    if (_groupsState == LoadState.ready && !force) return;

    final result = await guard(
      () => _repo.groups(),
      onState: (state, err) {
        _groupsState = state;
        _groupsError = err;
      },
    );
    if (result != null) _groups = result;
    safeNotify();
  }

  /// Opens a thread. The group passed in comes from the list, so the
  /// header renders immediately while messages load.
  Future<void> openGroup(ChatGroup group) async {
    _activeGroup = group;
    _messages = [];
    _messagesPage = const Pagination();
    _sendError = null;
    clearSearch();
    safeNotify();
    await loadMessages(group.id);
    _markGroupRead(group.id);
  }

  Future<void> loadMessages(int groupId, {bool force = true}) async {
    if (_messagesState == LoadState.loading) return;
    if (_messagesState == LoadState.ready && !force) return;

    final result = await guard(
      () => _repo.messages(groupId, page: 1),
      onState: (state, err) {
        _messagesState = state;
        _messagesError = err;
      },
    );
    if (result != null) {
      _messages = _sorted(result.items);
      _messagesPage = result.pagination;
    }
    safeNotify();
  }

  /// Page 1 is the newest page; higher pages are older history, so they
  /// are prepended rather than appended.
  Future<void> loadOlder() async {
    final group = _activeGroup;
    if (group == null || _loadingOlder || !_messagesPage.hasMore) return;

    _loadingOlder = true;
    safeNotify();
    try {
      final result =
          await _repo.messages(group.id, page: _messagesPage.nextPage);
      _messages = _sorted([...result.items, ..._messages]);
      _messagesPage = result.pagination;
    } on ApiException catch (e) {
      _messagesError = e.message;
    } finally {
      _loadingOlder = false;
      safeNotify();
    }
  }

  /// Sends optimistically: the message appears immediately as pending,
  /// then is replaced by the server's copy or marked failed.
  Future<bool> send({String? text, String? attachmentPath, int? myUserId,
      String? myName}) async {
    final group = _activeGroup;
    if (group == null) return false;

    final temp = ChatMessage(
      id: -DateTime.now().millisecondsSinceEpoch,
      sender: NamedRefLite.of(myUserId, myName),
      text: text?.trim(),
      createdAt: DateTime.now(),
      pending: true,
    );
    _messages = [..._messages, temp];
    _sending = true;
    _sendError = null;
    safeNotify();

    try {
      final saved = await _repo.send(
        group.id,
        message: text,
        attachmentPath: attachmentPath,
      );
      _messages = [
        for (final m in _messages)
          if (m.id == temp.id) saved else m,
      ];
      _bumpGroupPreview(group.id, saved.text ?? text);
      return true;
    } on ArgumentError catch (e) {
      _messages = _messages.where((m) => m.id != temp.id).toList();
      _sendError = e.message?.toString() ?? 'Nothing to send.';
      return false;
    } on ApiException catch (e) {
      _messages = [
        for (final m in _messages)
          if (m.id == temp.id) m.copyWith(pending: false, failed: true) else m,
      ];
      _sendError = e.message;
      return false;
    } finally {
      _sending = false;
      safeNotify();
    }
  }

  /// Drops a message that failed to send, so the thread doesn't keep a
  /// permanent error bubble.
  void discardFailed(int messageId) {
    _messages = _messages.where((m) => m.id != messageId).toList();
    safeNotify();
  }

  Future<void> search(String query) async {
    final group = _activeGroup;
    final q = query.trim();
    _searchQuery = q;

    if (group == null || q.isEmpty) {
      clearSearch();
      return;
    }

    _searching = true;
    safeNotify();
    try {
      _searchHits = await _repo.search(group.id, q);
    } on ApiException catch (_) {
      _searchHits = [];
    } finally {
      _searching = false;
      safeNotify();
    }
  }

  void clearSearch() {
    _searchHits = [];
    _searchQuery = '';
    _searching = false;
    safeNotify();
  }

  void _markGroupRead(int groupId) {
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx < 0 || _groups[idx].unreadCount == 0) return;
    _groups = [..._groups];
    _groups[idx] = _groups[idx].copyWith(unreadCount: 0);
    safeNotify();
  }

  void _bumpGroupPreview(int groupId, String? preview) {
    if (preview == null || preview.isEmpty) return;
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx < 0) return;
    _groups = [..._groups];
    _groups[idx] = _groups[idx].copyWith(lastMessage: preview);
    safeNotify();
  }

  /// Oldest first, which is the order a chat thread renders in. Messages
  /// without a timestamp keep their relative position at the end.
  List<ChatMessage> _sorted(List<ChatMessage> input) {
    final list = [...input];
    list.sort((a, b) {
      final ad = a.createdAt, bd = b.createdAt;
      if (ad == null && bd == null) return a.id.compareTo(b.id);
      if (ad == null) return 1;
      if (bd == null) return -1;
      final c = ad.compareTo(bd);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    return list;
  }

  void reset() {
    _groups = [];
    _groupsState = LoadState.idle;
    _groupsError = null;
    _activeGroup = null;
    _messages = [];
    _messagesPage = const Pagination();
    _messagesState = LoadState.idle;
    _messagesError = null;
    _loadingOlder = false;
    _sending = false;
    _sendError = null;
    clearSearch();
    safeNotify();
  }
}

/// Builds the local sender stub for optimistic messages.
class NamedRefLite {
  NamedRefLite._();

  static NamedRef? of(int? id, String? name) {
    if (id == null && name == null) return null;
    return NamedRef(id: id, name: name);
  }
}
