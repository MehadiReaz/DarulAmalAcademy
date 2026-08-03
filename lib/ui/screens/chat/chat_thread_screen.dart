import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/chat.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../widgets/state_views.dart';

/// A single group thread: `GET/POST /group-chats/{id}/messages` plus
/// `GET /group-chats/{id}/search`.
///
/// Supports text, image, pdf, and WhatsApp-style voice note audio recording
/// and playback.
class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({super.key});

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _input = TextEditingController();
  final _searchInput = TextEditingController();
  final _scroll = ScrollController();
  bool _searchMode = false;
  String? _selectedFilePath;
  String? _selectedFileName;
  int? _selectedFileSize;

  int? _scrolledGroupId;
  bool _didInitialScroll = false;
  int _lastMessageCount = 0;

  // WhatsApp Voice Recording Handles & State
  late final AudioRecorder _audioRecorder;
  late final AudioPlayer _audioPlayer;
  StreamSubscription? _playerCompleteSub;
  StreamSubscription? _playerPositionSub;
  StreamSubscription? _playerDurationSub;

  bool _isRecordingVoice = false;
  bool _isReviewingVoice = false;
  Timer? _voiceRecordTimer;
  int _voiceRecordSeconds = 0;
  int _voicePlaybackSeconds = 0;
  bool _isPlayingVoicePreview = false;
  String? _voiceTempPath;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();

    _input.addListener(_onInputChanged);

    _playerCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingVoicePreview = false;
          _voicePlaybackSeconds = 0;
        });
      }
    });

    _playerPositionSub = _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted && _isReviewingVoice) {
        setState(() {
          _voicePlaybackSeconds = pos.inSeconds;
        });
      }
    });

    _playerDurationSub = _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted && dur.inSeconds > 0) {
        setState(() {
          _voiceRecordSeconds = dur.inSeconds;
        });
      }
    });
  }

  void _onInputChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _input.removeListener(_onInputChanged);
    _input.dispose();
    _searchInput.dispose();
    _scroll.dispose();
    _voiceRecordTimer?.cancel();
    _playerCompleteSub?.cancel();
    _playerPositionSub?.cancel();
    _playerDurationSub?.cancel();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  String _fmtSeconds(int totalSec) {
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startVoiceRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission required for voice notes.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      await _audioPlayer.stop();
      _voiceRecordTimer?.cancel();

      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      setState(() {
        _isRecordingVoice = true;
        _isReviewingVoice = false;
        _voiceRecordSeconds = 0;
        _voicePlaybackSeconds = 0;
        _isPlayingVoicePreview = false;
        _voiceTempPath = path;
      });

      _voiceRecordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _voiceRecordSeconds++);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start voice recording: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _cancelVoiceRecording() async {
    _voiceRecordTimer?.cancel();
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
      await _audioPlayer.stop();
    } catch (_) {}

    setState(() {
      _isRecordingVoice = false;
      _isReviewingVoice = false;
      _voiceRecordSeconds = 0;
      _voicePlaybackSeconds = 0;
      _isPlayingVoicePreview = false;
      _voiceTempPath = null;
    });
  }

  Future<void> _stopVoiceRecordingAndReview() async {
    _voiceRecordTimer?.cancel();
    String? path;
    try {
      path = await _audioRecorder.stop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error stopping recording: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final finalPath = path ?? _voiceTempPath;
    if (finalPath == null || !File(finalPath).existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recording failed. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
      _cancelVoiceRecording();
      return;
    }

    final sec = _voiceRecordSeconds == 0 ? 1 : _voiceRecordSeconds;

    setState(() {
      _voiceTempPath = finalPath;
      _voiceRecordSeconds = sec;
      _voicePlaybackSeconds = 0;
      _isPlayingVoicePreview = false;
      _isRecordingVoice = false;
      _isReviewingVoice = true;
    });
  }

  Future<void> _toggleVoicePreview() async {
    if (_isPlayingVoicePreview) {
      await _audioPlayer.pause();
      setState(() => _isPlayingVoicePreview = false);
    } else {
      if (_voiceTempPath != null && File(_voiceTempPath!).existsSync()) {
        if (_voicePlaybackSeconds >= _voiceRecordSeconds) {
          _voicePlaybackSeconds = 0;
        }
        await _audioPlayer.play(DeviceFileSource(_voiceTempPath!));
        setState(() => _isPlayingVoicePreview = true);
      }
    }
  }

  Future<void> _sendVoiceRecording() async {
    String? finalPath = _voiceTempPath;
    if (_isRecordingVoice) {
      _voiceRecordTimer?.cancel();
      try {
        finalPath = await _audioRecorder.stop() ?? _voiceTempPath;
      } catch (_) {}
    }

    if (finalPath == null || !File(finalPath).existsSync()) {
      _cancelVoiceRecording();
      return;
    }

    await _audioPlayer.stop();

    setState(() {
      _selectedFilePath = finalPath;
      _selectedFileName =
          'Voice_Note_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _selectedFileSize = File(finalPath!).lengthSync();
      _isRecordingVoice = false;
      _isReviewingVoice = false;
    });

    await _send();

    setState(() {
      _voiceTempPath = null;
    });
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _clearAttachment() {
    setState(() {
      _selectedFilePath = null;
      _selectedFileName = null;
      _selectedFileSize = null;
    });
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'png', 'jpg', 'jpeg', 'gif', 'webp', 'pdf', 'm4a', 'mp3', 'wav',
        ],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        if (file.path != null) {
          const maxBytes = 15 * 1024 * 1024; // 15 MB
          if (file.size > maxBytes) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('That file is over the 15 MB limit.'),
                backgroundColor: AppColors.danger,
              ),
            );
            return;
          }

          final ext = file.extension?.toLowerCase() ?? '';
          const allowed = {
            'png', 'jpg', 'jpeg', 'gif', 'webp', 'pdf', 'm4a', 'mp3', 'wav',
          };
          if (ext.isNotEmpty && !allowed.contains(ext)) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pick an image, PDF, or audio file.'),
                backgroundColor: AppColors.danger,
              ),
            );
            return;
          }

          setState(() {
            _selectedFilePath = file.path;
            _selectedFileName = file.name;
            _selectedFileSize = file.size;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open that file: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty && _selectedFilePath == null) return;

    final provider = context.read<ChatProvider>();
    final me = context.read<AuthProvider>().user;

    final filePath = _selectedFilePath;
    _input.clear();
    _clearAttachment();
    _scrollToBottom();

    final ok = await provider.send(
      text: text.isNotEmpty ? text : null,
      attachmentPath: filePath,
      myUserId: me?.id,
      myName: me?.name,
    );

    if (!mounted) return;
    if (!ok && provider.sendError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.sendError!),
          backgroundColor: AppColors.danger,
        ),
      );
    } else {
      _scrollToBottom();
    }
  }

  void _toggleSearch() {
    setState(() => _searchMode = !_searchMode);
    if (!_searchMode) {
      _searchInput.clear();
      context.read<ChatProvider>().clearSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final group = provider.activeGroup;
    final myId = context.select<AuthProvider, int?>((p) => p.user?.id);

    if (group?.id != _scrolledGroupId) {
      _scrolledGroupId = group?.id;
      _didInitialScroll = false;
      _lastMessageCount = 0;
    }

    if (!_didInitialScroll &&
        provider.messages.isNotEmpty &&
        provider.messagesState == LoadState.ready) {
      _didInitialScroll = true;
      _lastMessageCount = provider.messages.length;
      _jumpToBottom();
    } else if (_didInitialScroll && provider.messages.length != _lastMessageCount) {
      if (provider.messages.length > _lastMessageCount && !provider.loadingOlder) {
        _scrollToBottom();
      }
      _lastMessageCount = provider.messages.length;
    }

    return Scaffold(
      appBar: AppBar(
        title: _searchMode
            ? TextField(
                controller: _searchInput,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: provider.search,
                decoration: const InputDecoration(
                  hintText: 'Search this group…',
                  border: InputBorder.none,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group?.name ?? 'Group'),
                  if (group?.contextLabel != null)
                    Text(
                      group!.contextLabel!,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_searchMode ? Icons.close_rounded : Icons.search_rounded),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _searchMode
                ? _searchResults(provider)
                : _messageList(provider, myId),
          ),
          if (!_searchMode) _composer(provider),
        ],
      ),
    );
  }

  Widget _messageList(ChatProvider provider, int? myId) {
    if (provider.messagesState == LoadState.loading &&
        provider.messages.isEmpty) {
      return const LoadingView();
    }

    if (provider.messagesState == LoadState.error &&
        provider.messages.isEmpty) {
      return ErrorView(
        message: provider.messagesError ?? 'Could not load messages',
        onRetry: () {
          final id = provider.activeGroup?.id;
          if (id != null) provider.loadMessages(id);
        },
      );
    }

    if (provider.messages.isEmpty) {
      return const EmptyView(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No messages yet',
        subtitle: 'Start the conversation!',
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () async {
        final id = provider.activeGroup?.id;
        if (id != null) await provider.loadMessages(id);
      },
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        itemCount: provider.messages.length + (provider.hasOlder ? 1 : 0),
        itemBuilder: (context, i) {
          if (provider.hasOlder && i == 0) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextButton(
                  onPressed: provider.loadingOlder ? null : provider.loadOlder,
                  child: Text(
                    provider.loadingOlder ? 'Loading…' : 'Load earlier messages',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                ),
              ),
            );
          }
          final msg = provider.messages[provider.hasOlder ? i - 1 : i];
          return _MessageBubble(
            message: msg,
            mine: msg.isMine(myId),
            onDiscard: msg.failed
                ? () => provider.discardFailed(msg.id)
                : null,
          );
        },
      ),
    );
  }

  Widget _searchResults(ChatProvider provider) {
    if (provider.searching) return const LoadingView();
    if (provider.searchQuery.isEmpty) {
      return const EmptyView(
        icon: Icons.search_rounded,
        title: 'Search this group',
        subtitle: 'Type a word and press enter.',
      );
    }
    if (provider.searchHits.isEmpty) {
      return const EmptyView(
        icon: Icons.search_off_rounded,
        title: 'No matches',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      itemCount: provider.searchHits.length,
      itemBuilder: (context, i) {
        final hit = provider.searchHits[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    hit.senderName ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.goldLight,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    Fmt.ago(hit.createdAt),
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                hit.text ?? '',
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Composer
  // ---------------------------------------------------------------------------

  Widget _composer(ChatProvider provider) {
    if (_isRecordingVoice) {
      return _voiceRecordingComposer(provider);
    }

    if (_isReviewingVoice) {
      return _voiceReviewComposer(provider);
    }

    final path = _selectedFilePath;
    final hasInputText = _input.text.trim().isNotEmpty;
    final hasAttachment = path != null;
    final canSendTextOrFile = hasInputText || hasAttachment;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 10),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              alignment: Alignment.bottomLeft,
              child: path == null
                  ? const SizedBox(width: double.infinity, height: 0)
                  : _StagedAttachment(
                      path: path,
                      name: _selectedFileName,
                      sizeBytes: _selectedFileSize,
                      onRemove: _clearAttachment,
                      onTap: () {},
                    ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Attach file or image',
                  onPressed: provider.sending ? null : _pickAttachment,
                  icon: Icon(
                    Icons.attach_file_rounded,
                    color: path == null
                        ? AppColors.goldLight
                        : AppColors.gold,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Message…',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: FilledButton(
                    onPressed: provider.sending
                        ? null
                        : (canSendTextOrFile ? _send : _startVoiceRecording),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                      backgroundColor: canSendTextOrFile
                          ? AppColors.gold
                          : AppColors.gold.withValues(alpha: 0.85),
                    ),
                    child: provider.sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF231600),
                            ),
                          )
                        : Icon(
                            canSendTextOrFile
                                ? Icons.send_rounded
                                : Icons.mic_rounded,
                            size: 20,
                            color: const Color(0xFF231600),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _voiceRecordingComposer(ChatProvider provider) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Discard voice note',
              onPressed: _cancelVoiceRecording,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 22,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(width: 4),
            const _PulsingRedDot(),
            const SizedBox(width: 8),
            Text(
              _fmtSeconds(_voiceRecordSeconds),
              style: const TextStyle(
                color: AppColors.cream,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AudioWaveformAnimation(isRecording: true),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Pause & review',
              onPressed: _stopVoiceRecordingAndReview,
              icon: const Icon(
                Icons.pause_circle_outline_rounded,
                size: 24,
                color: AppColors.goldLight,
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 42,
              height: 42,
              child: FilledButton(
                onPressed: provider.sending ? null : _sendVoiceRecording,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                  backgroundColor: AppColors.gold,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  size: 18,
                  color: Color(0xFF231600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _voiceReviewComposer(ChatProvider provider) {
    final maxSec = _voiceRecordSeconds > 0 ? _voiceRecordSeconds : 1;
    final currentSec = _voicePlaybackSeconds.clamp(0, maxSec);
    final progress = currentSec / maxSec;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Discard recording',
              onPressed: _cancelVoiceRecording,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 22,
                color: AppColors.danger,
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _toggleVoicePreview,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlayingVoicePreview
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 22,
                  color: const Color(0xFF231600),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AudioWaveformAnimation(
                    isRecording: false,
                    isPlaying: _isPlayingVoicePreview,
                    progress: progress,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmtSeconds(currentSec),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        _fmtSeconds(maxSec),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 42,
              height: 42,
              child: FilledButton(
                onPressed: provider.sending ? null : _sendVoiceRecording,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                  backgroundColor: AppColors.gold,
                ),
                child: provider.sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF231600),
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        size: 18,
                        color: Color(0xFF231600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The chip shown above the input once a file is picked but not yet sent.
class _StagedAttachment extends StatelessWidget {
  final String path;
  final String? name;
  final int? sizeBytes;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _StagedAttachment({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final kind = attachmentKindOf(name ?? path);
    final isImage = kind == AttachmentKind.image;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: isImage
                  ? Image.file(
                      File(path),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    )
                  : const _KindTile(kind: AttachmentKind.file),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name ?? attachmentNameOf(path),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sizeBytes != null
                      ? '${(sizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB'
                      : (kind == AttachmentKind.pdf ? 'PDF' : 'File'),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            splashRadius: 16,
          ),
        ],
      ),
    );
  }
}

class _KindTile extends StatelessWidget {
  final AttachmentKind kind;
  const _KindTile({required this.kind});

  @override
  Widget build(BuildContext context) {
    final isPdf = kind == AttachmentKind.pdf;
    final isAudio = kind == AttachmentKind.audio;

    return Container(
      width: 44,
      height: 44,
      color: isPdf
          ? AppColors.danger.withValues(alpha: 0.15)
          : (isAudio
              ? AppColors.gold.withValues(alpha: 0.15)
              : AppColors.goldLight.withValues(alpha: 0.15)),
      child: Center(
        child: Icon(
          isPdf
              ? Icons.picture_as_pdf_rounded
              : (isAudio ? Icons.mic_rounded : Icons.insert_drive_file_rounded),
          color: isPdf
              ? AppColors.danger
              : (isAudio ? AppColors.gold : AppColors.goldLight),
          size: 22,
        ),
      ),
    );
  }
}

/// The bubble containing a message text, attachment, author header, and timestamp.
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final VoidCallback? onDiscard;

  const _MessageBubble({
    required this.message,
    required this.mine,
    this.onDiscard,
  });

  Color get _onBubble => mine ? const Color(0xFF231600) : AppColors.cream;
  Color get _bg => mine ? AppColors.gold : AppColors.surface;

  @override
  Widget build(BuildContext context) {
    final showSender = !mine && message.sender?.name != null;
    final hasText = message.text != null && message.text!.isNotEmpty;
    final showAttachment = message.showsAttachment;
    final kind = message.attachmentKind;
    final tightImage = showAttachment && !hasText && kind == AttachmentKind.image;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSender)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 3),
              child: Text(
                message.sender!.name!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.goldLight,
                ),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.76,
            ),
            padding: tightImage
                ? const EdgeInsets.all(3)
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(15),
                topRight: const Radius.circular(15),
                bottomLeft: Radius.circular(mine ? 15 : 4),
                bottomRight: Radius.circular(mine ? 4 : 15),
              ),
              border: mine ? null : Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showAttachment)
                  Padding(
                    padding: EdgeInsets.only(bottom: hasText ? 7 : 0),
                    child: _AttachmentPreview(
                      messageId: message.id.toString(),
                      localPath: message.localAttachmentPath,
                      remoteUrl: message.attachment,
                      name: message.attachmentName,
                      kind: kind,
                      mine: mine,
                      uploading: message.isUploading,
                      progress: message.uploadProgress,
                      failed: message.failed,
                    ),
                  ),
                if (hasText)
                  Text(
                    message.text!,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: _onBubble,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 6, right: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.pending)
                  const Text('Sending…',
                      style: TextStyle(color: AppColors.muted, fontSize: 9.5))
                else if (message.failed) ...[
                  const Text('Not sent',
                      style:
                          TextStyle(color: AppColors.danger, fontSize: 9.5)),
                  if (onDiscard != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onDiscard,
                      child: const Text('Dismiss',
                          style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 9.5,
                              decoration: TextDecoration.underline)),
                    ),
                  ],
                ] else
                  Text(Fmt.ago(message.createdAt),
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 9.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the attachment inside a bubble: a real thumbnail for images,
/// a compact card for PDFs, a voice player for audio, and an upload overlay while in flight.
class _AttachmentPreview extends StatelessWidget {
  final String messageId;
  final String? localPath;
  final String? remoteUrl;
  final String name;
  final AttachmentKind kind;
  final bool mine;
  final bool uploading;
  final double? progress;
  final bool failed;

  const _AttachmentPreview({
    required this.messageId,
    required this.localPath,
    required this.remoteUrl,
    required this.name,
    required this.kind,
    required this.mine,
    required this.uploading,
    required this.progress,
    required this.failed,
  });

  Color get _onBubble => mine ? const Color(0xFF231600) : AppColors.cream;
  String get _heroTag => 'attachment-$messageId';

  ImageProvider? get _imageProvider {
    if (localPath != null) return FileImage(File(localPath!));
    if (remoteUrl != null) {
      return NetworkImage('https://course.nexcoreit4u.com/$remoteUrl');
    }
    return null;
  }

  Future<void> _openExternally(BuildContext context) async {
    final url = 'https://course.nexcoreit4u.com/$remoteUrl';
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(name)),
          body: SafeArea(
            child: SfPdfViewer.network(
              url,
              enableDoubleTapZooming: true,
              enableTextSelection: true,
              onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to open PDF: ${details.error}'),
                    backgroundColor: AppColors.danger,
                  ),
                );
                Navigator.of(context).pop();
              },
            ),
          ),
        ),
      ),
    );
  }

  void _openImageViewer(BuildContext context) {
    final image = _imageProvider;
    if (image == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _ImageViewer(
          image: image,
          title: name,
          heroTag: _heroTag,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = kind == AttachmentKind.image
        ? _image(context)
        : (kind == AttachmentKind.audio
            ? _VoiceNoteBubblePlayer(
                localPath: localPath,
                remoteUrl: remoteUrl,
                name: name,
                mine: mine,
              )
            : _document(context));

    if (!uploading && !failed) return child;

    return Stack(
      children: [
        Opacity(opacity: failed ? 0.45 : 0.72, child: child),
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Container(
              color: Colors.black.withValues(alpha: 0.28),
              alignment: Alignment.center,
              child: failed
                  ? const Icon(Icons.error_outline_rounded,
                      size: 26, color: AppColors.danger)
                  : SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 2.4,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.goldLight,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _image(BuildContext context) {
    final image = _imageProvider;
    final maxW = MediaQuery.of(context).size.width * 0.66;
    return GestureDetector(
      onTap: uploading ? null : () => _openImageViewer(context),
      child: Hero(
        tag: _heroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxW,
              minWidth: 150,
              maxHeight: 280,
              minHeight: 90,
            ),
            child: Image(image: image!, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  Widget _document(BuildContext context) {
    final isPdf = kind == AttachmentKind.pdf;
    return GestureDetector(
      onTap: uploading ? null : () => _openExternally(context),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.56,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: mine
              ? Colors.black.withValues(alpha: 0.08)
              : AppColors.line.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isPdf
                    ? AppColors.danger.withValues(alpha: 0.15)
                    : AppColors.goldLight.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPdf
                    ? Icons.picture_as_pdf_rounded
                    : Icons.insert_drive_file_rounded,
                color: isPdf ? AppColors.danger : AppColors.goldLight,
                size: 18,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _onBubble,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    isPdf ? 'PDF document' : 'Attachment',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: _onBubble.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: _onBubble.withValues(alpha: 0.65),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────── In-Bubble Voice Note Player
class _VoiceNoteBubblePlayer extends StatefulWidget {
  final String? localPath;
  final String? remoteUrl;
  final String name;
  final bool mine;

  const _VoiceNoteBubblePlayer({
    required this.localPath,
    required this.remoteUrl,
    required this.name,
    required this.mine,
  });

  @override
  State<_VoiceNoteBubblePlayer> createState() => _VoiceNoteBubblePlayerState();
}

class _VoiceNoteBubblePlayerState extends State<_VoiceNoteBubblePlayer> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  bool _isLoading = false;
  int _positionSec = 0;
  int _durationSec = 0;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _completeSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    _posSub = _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _positionSec = pos.inSeconds);
    });

    _durSub = _player.onDurationChanged.listen((dur) {
      if (mounted && dur.inSeconds > 0) {
        setState(() => _durationSec = dur.inSeconds);
      }
    });

    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isLoading = false;
          _positionSec = 0;
        });
      }
    });

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        if (state == PlayerState.playing) {
          setState(() {
            _isPlaying = true;
            _isLoading = false;
          });
        } else if (state == PlayerState.paused) {
          setState(() {
            _isPlaying = false;
            _isLoading = false;
          });
        } else if (state == PlayerState.stopped || state == PlayerState.completed) {
          setState(() {
            _isPlaying = false;
            _isLoading = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _completeSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _fmt(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _toggle() async {
    if (_isLoading) return;

    try {
      if (_isPlaying) {
        await _player.pause();
        setState(() {
          _isPlaying = false;
          _isLoading = false;
        });
      } else {
        Source? src;
        if (widget.localPath != null && File(widget.localPath!).existsSync()) {
          src = DeviceFileSource(widget.localPath!);
        } else if (widget.remoteUrl != null) {
          final urlStr = widget.remoteUrl!.trim();
          final fullUrl = (urlStr.startsWith('http://') || urlStr.startsWith('https://'))
              ? urlStr
              : 'https://course.nexcoreit4u.com/${urlStr.startsWith('/') ? urlStr.substring(1) : urlStr}';
          src = UrlSource(fullUrl);
        }

        if (src != null) {
          setState(() => _isLoading = true);
          if (_positionSec >= _durationSec && _durationSec > 0) {
            _positionSec = 0;
            await _player.seek(Duration.zero);
          }
          await _player.play(src);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Audio file location is invalid.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not play audio: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxSec = _durationSec > 0 ? _durationSec : 1;
    final currentSec = _positionSec.clamp(0, maxSec);
    final onBubbleColor = widget.mine ? const Color(0xFF231600) : AppColors.cream;
    final btnBg = widget.mine ? const Color(0xFF231600) : AppColors.gold;
    final btnIconColor = widget.mine ? AppColors.gold : const Color(0xFF231600);

    return Container(
      width: MediaQuery.of(context).size.width * 0.62,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: widget.mine
            ? Colors.black.withValues(alpha: 0.08)
            : AppColors.line.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _toggle,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: btnBg,
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: btnIconColor,
                        ),
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 22,
                      color: btnIconColor,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: onBubbleColor,
                    inactiveTrackColor: onBubbleColor.withValues(alpha: 0.3),
                    thumbColor: onBubbleColor,
                  ),
                  child: Slider(
                    value: currentSec.toDouble(),
                    min: 0,
                    max: maxSec.toDouble(),
                    onChanged: (val) {
                      final s = val.toInt();
                      _player.seek(Duration(seconds: s));
                      setState(() => _positionSec = s);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmt(currentSec),
                        style: TextStyle(
                          fontSize: 10,
                          color: onBubbleColor.withValues(alpha: 0.75),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.mic_rounded,
                            size: 11,
                            color: onBubbleColor.withValues(alpha: 0.75),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _fmt(maxSec),
                            style: TextStyle(
                              fontSize: 10,
                              color: onBubbleColor.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────── Image Viewer
class _ImageViewer extends StatelessWidget {
  final ImageProvider image;
  final String title;
  final String heroTag;

  const _ImageViewer({
    required this.image,
    required this.title,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontSize: 14)),
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4.0,
            child: Image(
              image: image,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Text(
                'This image could not be loaded.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────── Pulsing Recording Dot
class _PulsingRedDot extends StatefulWidget {
  const _PulsingRedDot();

  @override
  State<_PulsingRedDot> createState() => _PulsingRedDotState();
}

class _PulsingRedDotState extends State<_PulsingRedDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_controller),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: AppColors.danger,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────── Audio Waveform Visualizer
class _AudioWaveformAnimation extends StatefulWidget {
  final bool isRecording;
  final bool isPlaying;
  final double progress;

  const _AudioWaveformAnimation({
    required this.isRecording,
    this.isPlaying = false,
    this.progress = 0.0,
  });

  @override
  State<_AudioWaveformAnimation> createState() =>
      _AudioWaveformAnimationState();
}

class _AudioWaveformAnimationState extends State<_AudioWaveformAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const List<double> _barPattern = [
    0.3, 0.5, 0.8, 0.4, 0.9, 0.6, 0.3, 0.7, 1.0, 0.5,
    0.8, 0.4, 0.6, 0.9, 0.7, 0.3, 0.8, 0.5, 1.0, 0.6,
    0.4, 0.7, 0.9, 0.5, 0.3, 0.8, 0.6, 0.4
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.isRecording || widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_AudioWaveformAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.isRecording || widget.isPlaying) && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isRecording && !widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final animVal = _controller.value;

        return SizedBox(
          height: 34,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_barPattern.length, (index) {
              final baseRatio = _barPattern[index];
              final activeIndex = (widget.progress * _barPattern.length).floor();
              final isPassed = index <= activeIndex;

              double phase = (index % 4) * 0.25;
              double bounce = widget.isRecording
                  ? (0.4 + 0.6 * ((animVal + phase) % 1.0))
                  : (widget.isPlaying
                      ? (0.6 + 0.4 * ((animVal + phase) % 1.0))
                      : 1.0);

              double barHeight = (baseRatio * bounce * 24).clamp(4.0, 26.0);

              Color barColor;
              if (widget.isRecording) {
                barColor = AppColors.gold;
              } else if (isPassed && widget.isPlaying) {
                barColor = AppColors.goldLight;
              } else {
                barColor = AppColors.line.withValues(alpha: 0.8);
              }

              return Container(
                width: 2.8,
                height: barHeight,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}