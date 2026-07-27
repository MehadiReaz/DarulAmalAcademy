import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
/// Supports text and image/pdf attachments (max 15MB), with inline previews
/// and an upload overlay driven by `ChatMessage.uploadProgress`.
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

  @override
  void dispose() {
    _input.dispose();
    _searchInput.dispose();
    _scroll.dispose();
    super.dispose();
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
        allowedExtensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'pdf'],
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
          const allowed = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'pdf'};
          if (ext.isNotEmpty && !allowed.contains(ext)) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pick an image or a PDF.'),
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
        subtitle: 'Be the first to say salaam.',
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
          return _Bubble(
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
    final path = _selectedFilePath;

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
                      onTap: () => _openLocalPreview(path, _selectedFileName),
                    ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Attach an image or PDF (max 15 MB)',
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
                    onPressed: provider.sending ? null : _send,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
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
                        : const Icon(Icons.send_rounded, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openLocalPreview(String path, String? name) {
    if (attachmentKindOf(name ?? path) != AttachmentKind.image) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _ImageViewer(
          image: FileImage(File(path)),
          title: name ?? attachmentNameOf(path),
          heroTag: 'staged-$path',
        ),
      ),
    );
  }
}

/// The chip shown above the input once a file is picked but not yet sent.
/// Images get a real thumbnail; PDFs get a labelled card.
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
    final label = name ?? attachmentNameOf(path);
    final size = sizeBytes != null
        ? '${(sizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB'
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: isImage ? onTap : null,
            child: Hero(
              tag: 'staged-$path',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: isImage
                      ? Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const _KindTile(kind: AttachmentKind.file),
                        )
                      : _KindTile(kind: kind),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.cream,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    isImage
                        ? 'Image'
                        : (kind == AttachmentKind.pdf ? 'PDF' : 'File'),
                    if (size != null) size,
                    if (isImage) 'Tap to preview',
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove attachment',
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.close_rounded,
              size: 17,
              color: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

/// Neutral square used for PDFs and for images that fail to decode.
class _KindTile extends StatelessWidget {
  final AttachmentKind kind;
  const _KindTile({required this.kind});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.line.withValues(alpha: 0.35),
      alignment: Alignment.center,
      child: Icon(
        kind == AttachmentKind.pdf
            ? Icons.picture_as_pdf_rounded
            : Icons.insert_drive_file_rounded,
        size: 22,
        color: AppColors.goldLight,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Message bubble
// -----------------------------------------------------------------------------

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final VoidCallback? onDiscard;

  const _Bubble({
    required this.message,
    required this.mine,
    this.onDiscard,
  });

  Color get _onBubble =>
      mine ? const Color(0xFF231600) : AppColors.cream;

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: const Text(
            'This message was deleted',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final hasText = message.text != null && message.text!.isNotEmpty;
    final showAttachment = message.showsAttachment;
    final kind = message.attachmentKind;
    final isImage = kind == AttachmentKind.image;

    // An image with no caption gets an edge-to-edge bubble.
    final tightImage = isImage && showAttachment && !hasText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!mine && message.sender?.name != null)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 3),
              child: Text(
                message.sender!.name!,
                style: const TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.74,
            ),
            padding: tightImage
                ? const EdgeInsets.all(4)
                : const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: mine ? AppColors.gold : AppColors.surface,
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
                  Padding(
                    padding: tightImage
                        ? const EdgeInsets.fromLTRB(9, 0, 9, 5)
                        : EdgeInsets.zero,
                    child: Text(
                      message.text!,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: _onBubble,
                      ),
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
                  Text(
                    _pendingLabel(message),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 9.5,
                    ),
                  )
                else if (message.failed) ...[
                  const Text('Not sent',
                      style:
                          TextStyle(color: AppColors.danger, fontSize: 9.5)),
                  if (onDiscard != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onDiscard,
                      child: const Text(
                        'Dismiss',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 9.5,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ] else
                  Text(
                    Fmt.ago(message.createdAt),
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 9.5),
                  ),
                if (message.isEdited) ...[
                  const SizedBox(width: 5),
                  const Text('· edited',
                      style:
                          TextStyle(color: AppColors.muted, fontSize: 9.5)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _pendingLabel(ChatMessage m) {
    if (!m.isUploading) return 'Sending…';
    final p = m.uploadProgress;
    if (p == null) return 'Uploading…';
    return 'Uploading ${(p.clamp(0.0, 1.0) * 100).round()}%';
  }
}

/// Renders the attachment inside a bubble: a real thumbnail for images,
/// a compact card for PDFs, and an upload overlay while the file is in flight.
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
    if (remoteUrl != null) return NetworkImage('https://course.nexcoreit4u.com/$remoteUrl');
    return null;
  }

  Future<void> _openExternally() async {
    final url = remoteUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
          externalUrl: remoteUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child =
        kind == AttachmentKind.image ? _image(context) : _document(context);

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
                        backgroundColor: Colors.white24,
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
    if (image == null) return _document(context);

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
            child: Image(
              image: image,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                final value = progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null;
                return _Placeholder(
                  width: maxW,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 2,
                      color: AppColors.goldLight,
                    ),
                  ),
                );
              },
              errorBuilder: (context, _, __) => _Placeholder(
                width: maxW,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image_rounded,
                        size: 22, color: AppColors.muted),
                    const SizedBox(height: 6),
                    Text(
                      'Preview unavailable',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _document(BuildContext context) {
    final isPdf = kind == AttachmentKind.pdf;

    return GestureDetector(
      onTap: uploading ? null : _openExternally,
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
                color: mine
                    ? Colors.black.withValues(alpha: 0.10)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                isPdf
                    ? Icons.picture_as_pdf_rounded
                    : Icons.insert_drive_file_rounded,
                size: 18,
                color: mine ? const Color(0xFF231600) : AppColors.goldLight,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(height: 2),
                  Text(
                    uploading ? 'Uploading' : (isPdf ? 'PDF · Tap to open' : 'Tap to open'),
                    style: TextStyle(
                      fontSize: 9.5,
                      color: mine
                          ? const Color(0xFF231600).withValues(alpha: 0.65)
                          : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final double width;
  final Widget child;
  const _Placeholder({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 160,
      color: AppColors.line.withValues(alpha: 0.30),
      alignment: Alignment.center,
      child: child,
    );
  }
}

// -----------------------------------------------------------------------------
// Full-screen image viewer
// -----------------------------------------------------------------------------

class _ImageViewer extends StatelessWidget {
  final ImageProvider image;
  final String title;
  final Object heroTag;
  final String? externalUrl;

  const _ImageViewer({
    required this.image,
    required this.title,
    required this.heroTag,
    this.externalUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.55),
        elevation: 0,
        foregroundColor: AppColors.cream,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (externalUrl != null)
            IconButton(
              tooltip: 'Open in browser',
              icon: const Icon(Icons.open_in_new_rounded, size: 20),
              onPressed: () async {
                final uri = Uri.tryParse(externalUrl!);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Image(
              image: image,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text(
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