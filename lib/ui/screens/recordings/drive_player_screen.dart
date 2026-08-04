import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/recording.dart';
import '../../widgets/app_toast.dart';

/// Optional. Only needed if you want to stream "anyone with the link" Drive
/// files through the Drive API. Leave empty to skip the native path for Drive.
///
/// Shipping a key in the binary is a smell — prefer having your backend return
/// a short-lived direct URL on the Recording model and reading that instead.
const String kDriveApiKey = '';

enum _PlayerMode { loading, native, embedded, failed }

/// Plays a recording with a real native player when a direct media URL is
/// available, and falls back to a hardened WebView embed when it isn't.
class DrivePlayerScreen extends StatefulWidget {
  final Recording recording;

  const DrivePlayerScreen({super.key, required this.recording});

  @override
  State<DrivePlayerScreen> createState() => _DrivePlayerScreenState();
}

class _DrivePlayerScreenState extends State<DrivePlayerScreen> {
  static final RegExp _directMedia =
      RegExp(r'\.(mp4|m3u8|mpd|webm|mov|m4v)(\?|#|$)', caseSensitive: false);
  static final RegExp _driveFileId =
      RegExp(r'(?:/d/|[?&]id=)([a-zA-Z0-9_-]{20,})');

  _PlayerMode _mode = _PlayerMode.loading;
  String _failureMessage = '';

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  WebViewController? _webController;

  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final direct = _resolveDirectUrl();
    if (direct != null) {
      final ok = await _startNative(direct);
      if (ok) return;
    }
    _startEmbedded();
  }

  // ---------------------------------------------------------------------------
  // URL resolution
  // ---------------------------------------------------------------------------

  /// Returns a URL the platform video decoder can consume directly, or null.
  String? _resolveDirectUrl() {
    final playable = widget.recording.playableUrl?.trim();

    // Best case: your backend already hands you a real media file or HLS index.
    if (playable != null &&
        playable.isNotEmpty &&
        _directMedia.hasMatch(playable)) {
      return playable;
    }

    // Drive files shared as "anyone with the link" can be streamed through the
    // Drive API. Range requests work, but Drive enforces a per-file download
    // quota — expect 403s on popular videos. Treat this as a stopgap.
    if (kDriveApiKey.isNotEmpty) {
      final source = widget.recording.driveEmbedUrl ?? playable ?? '';
      final id = _driveFileId.firstMatch(source)?.group(1);
      if (id != null) {
        return 'https://www.googleapis.com/drive/v3/files/$id'
            '?alt=media&key=$kDriveApiKey';
      }
    }

    return null;
  }

  String get _embedUrl =>
      widget.recording.driveEmbedUrl ?? widget.recording.playableUrl ?? '';

  // ---------------------------------------------------------------------------
  // Native path
  // ---------------------------------------------------------------------------

  Future<bool> _startNative(String url) async {
    final video = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await video.initialize();
    } catch (_) {
      await video.dispose();
      return false;
    }
    if (!mounted) {
      await video.dispose();
      return false;
    }

    _videoController = video;
    _chewieController = ChewieController(
      videoPlayerController: video,
      autoPlay: true,
      looping: false,
      allowedScreenSleep: false,
      allowFullScreen: true,
      aspectRatio: video.value.aspectRatio,
      deviceOrientationsOnEnterFullScreen: const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      deviceOrientationsAfterFullScreen: const [DeviceOrientation.portraitUp],
      placeholder: const ColoredBox(color: Colors.black),
      materialProgressColors: ChewieProgressColors(
        playedColor: AppColors.gold,
        handleColor: AppColors.goldLight,
        bufferedColor: AppColors.line,
        backgroundColor: Colors.white24,
      ),
      errorBuilder: (_, message) => _PlayerMessage(
        message: message,
        actionLabel: 'Open in browser',
        onAction: _openExternalBrowser,
      ),
    );

    setState(() => _mode = _PlayerMode.native);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Embedded fallback
  // ---------------------------------------------------------------------------

  void _startEmbedded() {
    final url = _embedUrl;
    if (url.isEmpty) {
      setState(() {
        _mode = _PlayerMode.failed;
        _failureMessage = 'This recording has no video attached to it yet.';
      });
      return;
    }

    // iOS refuses inline playback unless it's granted at creation time —
    // without this the video hijacks the screen with the system player.
    final PlatformWebViewControllerCreationParams params =
        WebViewPlatform.instance is WebKitWebViewPlatform
            ? WebKitWebViewControllerCreationParams(
                allowsInlineMediaPlayback: true,
                mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
              )
            : const PlatformWebViewControllerCreationParams();

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            // The embed itself may redirect internally; anything else is a
            // popout or an ad for the Drive app, so it stays out.
            if (_isInternal(request.url)) return NavigationDecision.navigate;
            return NavigationDecision.prevent;
          },
          onPageFinished: (_) {
            if (mounted) setState(() {});
          },
          onWebResourceError: (error) {
            if (!(error.isForMainFrame ?? false) || !mounted) return;
            setState(() {
              _mode = _PlayerMode.failed;
              _failureMessage =
                  'The video host did not respond. Check the connection '
                  'and try again.';
            });
          },
        ),
      );

    if (controller.platform is AndroidWebViewController) {
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    controller.loadHtmlString(_embedHtml(url), baseUrl: 'https://drive.google.com');

    _webController = controller;
    setState(() => _mode = _PlayerMode.embedded);
  }

  bool _isInternal(String url) {
    final u = url.toLowerCase();
    return u.startsWith('about:') ||
        u.startsWith('data:') ||
        u.contains('drive.google.com') ||
        u.contains('googleusercontent.com') ||
        u.contains('googlevideo.com') ||
        u.contains('youtube.com/embed') ||
        u.contains('youtube-nocookie.com');
  }

  String _embedHtml(String url) => '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
  .stage { position: absolute; inset: 0; overflow: hidden; background: #000; }
  iframe { position: absolute; inset: 0; width: 100%; height: 100%; border: 0; }
  /* If the host's top bar still bothers you, oversize and offset the iframe
     so the bar sits outside the clip — it costs you a sliver of picture:
     iframe { top: -44px; height: calc(100% + 44px); } */
</style>
</head>
<body>
  <div class="stage">
    <iframe src="$url" allow="autoplay; encrypted-media; fullscreen" allowfullscreen></iframe>
  </div>
</body>
</html>
''';

  // ---------------------------------------------------------------------------
  // Chrome
  // ---------------------------------------------------------------------------

  Future<void> _toggleFullscreen() async {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  Future<void> _openExternalBrowser() async {
    final raw = widget.recording.playableUrl;
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) return;

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) AppToast.showError(context, 'Could not open link: $e');
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    _chewieController?.dispose();
    _videoController?.dispose();
    // Android keeps the embed's audio running after the route pops.
    _webController?.loadHtmlString('<html><body></body></html>');
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isFullscreen) _toggleFullscreen();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        appBar: _isFullscreen
            ? null
            : AppBar(
                title: Text(
                  widget.recording.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.open_in_browser_rounded),
                    tooltip: 'Open in browser',
                    onPressed: _openExternalBrowser,
                  ),
                ],
              ),
        body: Column(
          children: [
            _buildStage(),
            if (!_isFullscreen) Expanded(child: _buildDetails()),
          ],
        ),
      ),
    );
  }

  Widget _buildStage() {
    final radius =
        _isFullscreen ? BorderRadius.zero : BorderRadius.circular(16);

    return Container(
      margin: _isFullscreen
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: radius,
        border: _isFullscreen ? null : Border.all(color: AppColors.line),
        boxShadow: _isFullscreen
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: _isFullscreen
                  ? MediaQuery.sizeOf(context).aspectRatio
                  : 16 / 9,
              child: ColoredBox(color: Colors.black, child: _buildSurface()),
            ),
            // Chewie ships its own control bar, so the strip is only for the
            // embed, which has none we can trust.
            if (_mode == _PlayerMode.embedded) _buildControlStrip(),
          ],
        ),
      ),
    );
  }

  Widget _buildSurface() {
    switch (_mode) {
      case _PlayerMode.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2.5),
              SizedBox(height: 12),
              Text(
                'Loading video',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        );

      case _PlayerMode.native:
        return Chewie(controller: _chewieController!);

      case _PlayerMode.embedded:
        return Stack(
          children: [
            WebViewWidget(controller: _webController!),
            // Invisible shield over the host's popout button. Navigation
            // blocking already stops the jump; this stops the flicker.
            Positioned(
              top: 0,
              right: 0,
              width: 64,
              height: 56,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: const SizedBox.expand(),
              ),
            ),
          ],
        );

      case _PlayerMode.failed:
        return _PlayerMessage(
          message: _failureMessage,
          actionLabel: 'Open in browser',
          onAction: _openExternalBrowser,
        );
    }
  }

  Widget _buildControlStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFF141414),
      child: Row(
        children: [
          const Icon(Icons.play_circle_fill_rounded,
              color: AppColors.gold, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.recording.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.cream,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _isFullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              color: AppColors.goldLight,
              size: 20,
            ),
            onPressed: _toggleFullscreen,
            tooltip: _isFullscreen ? 'Exit fullscreen' : 'Fullscreen',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails() {
    final r = widget.recording;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              height: 1.3,
              color: AppColors.cream,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(icon: Icons.movie_outlined, label: r.sourceLabel),
              if (r.subject?.name != null)
                _Chip(icon: Icons.book_outlined, label: r.subject!.name!),
              if (r.teacher?.name != null)
                _Chip(icon: Icons.person_outline, label: r.teacher!.name!),
              if (r.batch?.name != null)
                _Chip(icon: Icons.groups_outlined, label: r.batch!.name!),
              if (r.recordedAt != null)
                _Chip(
                  icon: Icons.calendar_today_outlined,
                  label: Fmt.date(r.recordedAt),
                ),
            ],
          ),
          if (r.description != null && r.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              r.description!,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.cream,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerMessage extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _PlayerMessage({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.danger, size: 36),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.gold),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.cream,
            ),
          ),
        ],
      ),
    );
  }
}