import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/homework.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/homework_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/state_views.dart';

enum AudioRecordState { idle, recording, reviewing }

/// Homework detail + submission, backed by `GET /student/homework/{id}`
/// and `POST /student/homework/{id}/submit`.
class HomeworkDetailScreen extends StatefulWidget {
  final int homeworkId;
  const HomeworkDetailScreen({super.key, required this.homeworkId});

  @override
  State<HomeworkDetailScreen> createState() => _HomeworkDetailScreenState();
}

class _HomeworkDetailScreenState extends State<HomeworkDetailScreen> {
  final _answerController = TextEditingController();
  String? _selectedFilePath;
  String? _selectedFileName;

  // Audio recording & player handles
  late final AudioRecorder _audioRecorder;
  late final AudioPlayer _audioPlayer;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerPositionSubscription;
  StreamSubscription? _playerDurationSubscription;

  // Audio recording & review state
  AudioRecordState _audioState = AudioRecordState.idle;
  Timer? _recordTimer;
  int _recordSeconds = 0;
  int _playbackSeconds = 0;
  bool _isPlayingPreview = false;
  String? _recordedTempPath;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingPreview = false;
          _playbackSeconds = 0;
        });
      }
    });

    _playerPositionSubscription = _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted && _audioState == AudioRecordState.reviewing) {
        setState(() {
          _playbackSeconds = pos.inSeconds;
        });
      }
    });

    _playerDurationSubscription = _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted && dur.inSeconds > 0) {
        setState(() {
          _recordSeconds = dur.inSeconds;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeworkProvider>().loadDetail(widget.homeworkId);
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    _recordTimer?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerPositionSubscription?.cancel();
    _playerDurationSubscription?.cancel();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  String _fmtSeconds(int totalSec) {
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        AppToast.showError(
          context,
          'Microphone permission is required to record a voice answer.',
        );
        return;
      }

      await _audioPlayer.stop();
      _recordTimer?.cancel();

      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      setState(() {
        _audioState = AudioRecordState.recording;
        _recordSeconds = 0;
        _playbackSeconds = 0;
        _isPlayingPreview = false;
        _recordedTempPath = path;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _recordSeconds++);
        }
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, 'Could not start voice recording: $e');
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
      await _audioPlayer.stop();
    } catch (_) {}

    setState(() {
      _audioState = AudioRecordState.idle;
      _recordSeconds = 0;
      _playbackSeconds = 0;
      _isPlayingPreview = false;
      _recordedTempPath = null;
    });
  }

  Future<void> _stopRecordingAndReview() async {
    _recordTimer?.cancel();
    String? path;
    try {
      path = await _audioRecorder.stop();
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, 'Error stopping recording: $e');
      return;
    }

    final finalPath = path ?? _recordedTempPath;
    if (finalPath == null || !File(finalPath).existsSync()) {
      if (!mounted) return;
      AppToast.showError(context, 'Recording failed. Please try again.');
      _cancelRecording();
      return;
    }

    final fileSize = await File(finalPath).length();
    if (fileSize > 25 * 1024 * 1024) {
      if (!mounted) return;
      AppToast.showError(
        context,
        'Recorded audio exceeds the 25MB max limit.',
      );
      _cancelRecording();
      return;
    }

    final sec = _recordSeconds == 0 ? 1 : _recordSeconds;

    setState(() {
      _recordedTempPath = finalPath;
      _recordSeconds = sec;
      _playbackSeconds = 0;
      _isPlayingPreview = false;
      _audioState = AudioRecordState.reviewing;
    });
  }

  Future<void> _togglePlayPreview() async {
    if (_isPlayingPreview) {
      await _audioPlayer.pause();
      setState(() => _isPlayingPreview = false);
    } else {
      if (_recordedTempPath != null && File(_recordedTempPath!).existsSync()) {
        if (_playbackSeconds >= _recordSeconds) {
          _playbackSeconds = 0;
        }
        await _audioPlayer.play(DeviceFileSource(_recordedTempPath!));
        setState(() => _isPlayingPreview = true);
      } else {
        AppToast.showError(context, 'Audio file not found.');
      }
    }
  }

  Future<void> _attachRecordedAudio() async {
    if (_recordedTempPath == null || !File(_recordedTempPath!).existsSync()) {
      AppToast.showError(context, 'No recording available to attach.');
      return;
    }

    await _audioPlayer.stop();
    if (!mounted) return;

    setState(() {
      _selectedFilePath = _recordedTempPath;
      _selectedFileName = 'Voice_Note_${_fmtSeconds(_recordSeconds)}.m4a';
      _audioState = AudioRecordState.idle;
      _isPlayingPreview = false;
    });
    AppToast.showSuccess(context, 'Voice note attached to submission');
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'png', 'jpg', 'jpeg', 'pdf', 'zip', 'doc', 'docx', 'm4a', 'mp3', 'wav',
        ],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;

        // 25MB Limit Check (25 * 1024 * 1024 bytes)
        if (file.size > 25 * 1024 * 1024) {
          if (!mounted) return;
          final sizeMb = (file.size / (1024 * 1024)).toStringAsFixed(1);
          AppToast.showError(
            context,
            'File size (${sizeMb}MB) exceeds the 25MB maximum upload limit.',
          );
          return;
        }

        if (file.path != null) {
          final ext = file.extension?.toLowerCase() ?? '';
          const allowed = {
            'png', 'jpg', 'jpeg', 'pdf', 'zip', 'doc', 'docx', 'm4a', 'mp3', 'wav',
          };
          if (ext.isNotEmpty && !allowed.contains(ext)) {
            if (!mounted) return;
            AppToast.showError(
              context,
              'Supported formats: PNG, JPG, JPEG, PDF, ZIP, DOC, DOCX, M4A, MP3, WAV.',
            );
            return;
          }
          setState(() {
            _selectedFilePath = file.path;
            _selectedFileName = file.name;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, 'Could not select file: $e');
    }
  }

  Future<void> _submit() async {
    final text = _answerController.text.trim();
    if (text.isEmpty && _selectedFilePath == null) {
      AppToast.showError(
        context,
        'Write your answer or attach a file/voice note before submitting.',
      );
      return;
    }

    FocusScope.of(context).unfocus();

    final provider = context.read<HomeworkProvider>();
    final ok = await provider.submit(
      id: widget.homeworkId,
      text: text.isNotEmpty ? text : null,
      audioPath: _selectedFilePath,
    );

    if (!mounted) return;

    if (ok) {
      AppToast.showSuccess(context, 'Homework submitted successfully');
      _answerController.clear();
      setState(() {
        _selectedFilePath = null;
        _selectedFileName = null;
        _audioState = AudioRecordState.idle;
      });
    } else {
      AppToast.showError(
        context,
        provider.submitError ?? 'Could not submit homework',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeworkProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Homework Details')),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(HomeworkProvider provider) {
    if (provider.detailState == LoadState.loading) {
      return const LoadingView();
    }

    if (provider.detailState == LoadState.error) {
      return ErrorView(
        message: provider.detailError ?? 'Could not load this homework',
        onRetry: () => provider.loadDetail(widget.homeworkId),
      );
    }

    final hw = provider.detail;
    if (hw == null) return const EmptyView(title: 'Homework not found');

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
      children: [
        // Homework Hero Card
        _HomeworkHeroCard(hw: hw),

        // Instructions
        if (hw.body != null && hw.body!.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _SectionHeader(title: 'INSTRUCTIONS'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(
              hw.body!,
              style: const TextStyle(
                color: AppColors.cream,
                fontSize: 13.5,
                height: 1.65,
              ),
            ),
          ),
        ],

        // Teacher Attachments
        if (hw.attachments.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _SectionHeader(title: 'ATTACHMENTS'),
          const SizedBox(height: 10),
          ...hw.attachments.map(_attachmentTile),
        ],

        const SizedBox(height: 24),

        // Submission View / Form
        if (hw.isSubmitted)
          _submittedView(hw)
        else
          _submitForm(provider),
      ],
    );
  }

  Widget _submittedView(HomeworkDetail hw) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'YOUR SUBMISSION'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Submitted Successfully',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (hw.history.isNotEmpty)
                    Text(
                      Fmt.ago(hw.history.first.submittedAt),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              if (hw.submittedText != null && hw.submittedText!.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.line),
                const SizedBox(height: 14),
                Text(
                  hw.submittedText!,
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
              if (hw.submittedAudio != null &&
                  hw.submittedAudio!.isNotEmpty) ...[
                const SizedBox(height: 14),
                _attachmentTile(hw.submittedAudio!),
              ],
            ],
          ),
        ),

        // Teacher remarks
        if (hw.teacherRemarks != null &&
            hw.teacherRemarks!.isNotEmpty &&
            hw.teacherRemarks != hw.submittedText) ...[
          const SizedBox(height: 22),
          const _SectionHeader(title: 'TEACHER REMARKS'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: AppColors.goldLight,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hw.teacherRemarks!,
                    style: const TextStyle(
                      color: AppColors.cream,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),
        Row(
          children: const [
            Icon(Icons.info_outline_rounded, size: 14, color: AppColors.muted),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Homework can only be submitted once. Speak to your teacher if you need to resubmit.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _submitForm(HomeworkProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'SUBMIT YOUR ANSWER'),
        const SizedBox(height: 10),
        TextField(
          controller: _answerController,
          maxLines: 5,
          minLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Write your answer here… (Optional if file/voice attached)',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 20),
        const _SectionHeader(title: 'ATTACHMENT / VOICE ANSWER'),
        const SizedBox(height: 6),
        const Text(
          'Upload a document/file or record a voice audio answer. Max 25MB.',
          style: TextStyle(color: AppColors.muted, fontSize: 11.5),
        ),
        const SizedBox(height: 12),

        if (_audioState == AudioRecordState.recording)
          _recordingCard()
        else if (_audioState == AudioRecordState.reviewing)
          _reviewingCard()
        else if (_selectedFilePath == null)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: provider.submitting ? null : _pickAttachment,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      children: const [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 24,
                          color: AppColors.goldLight,
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Upload File',
                          style: TextStyle(
                            color: AppColors.cream,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: provider.submitting ? null : _startRecording,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      children: const [
                        Icon(
                          Icons.mic_rounded,
                          size: 24,
                          color: AppColors.gold,
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Record Voice',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          _attachedPreviewCard(provider),

        if (provider.submitError != null) ...[
          const SizedBox(height: 10),
          Text(
            provider.submitError!,
            style: const TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ],
        const SizedBox(height: 24),
        AppButton(
          label: 'Submit Homework',
          icon: Icons.send_rounded,
          loading: provider.submitting,
          onPressed: _submit,
        ),
        const SizedBox(height: 10),
        const Text(
          'You can only submit once, so check your answer before sending.',
          style: TextStyle(color: AppColors.muted, fontSize: 11.5, height: 1.4),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────── Audio Recorder Cards

  Widget _recordingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _PulsingRedDot(),
              SizedBox(width: 8),
              Text(
                'RECORDING VOICE ANSWER',
                style: TextStyle(
                  color: AppColors.danger,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _AudioWaveformAnimation(isRecording: true),
          const SizedBox(height: 14),
          Text(
            _fmtSeconds(_recordSeconds),
            style: const TextStyle(
              color: AppColors.cream,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _cancelRecording,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: const Color(0xFF231600),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _stopRecordingAndReview,
                  icon: const Icon(Icons.stop_rounded, size: 18),
                  label: const Text(
                    'Stop & Review',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reviewingCard() {
    final maxSec = _recordSeconds > 0 ? _recordSeconds : 1;
    final currentSec = _playbackSeconds.clamp(0, maxSec);
    final progress = currentSec / maxSec;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.headphones_rounded,
                size: 18,
                color: AppColors.goldLight,
              ),
              const SizedBox(width: 8),
              const Text(
                'Review Voice Recording',
                style: TextStyle(
                  color: AppColors.cream,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                'Duration: ${_fmtSeconds(_recordSeconds)}',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AudioWaveformAnimation(
            isRecording: false,
            isPlaying: _isPlayingPreview,
            progress: progress,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: _togglePlayPreview,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPlayingPreview
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 26,
                    color: const Color(0xFF231600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: AppColors.gold,
                    inactiveTrackColor: AppColors.line,
                    thumbColor: AppColors.goldLight,
                  ),
                  child: Slider(
                    value: currentSec.toDouble(),
                    min: 0,
                    max: maxSec.toDouble(),
                    onChanged: (val) {
                      final sec = val.toInt();
                      _audioPlayer.seek(Duration(seconds: sec));
                      setState(() {
                        _playbackSeconds = sec;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_fmtSeconds(currentSec)} / ${_fmtSeconds(maxSec)}',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.cream,
                    side: const BorderSide(color: AppColors.line),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _startRecording,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Record Again'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: const Color(0xFF231600),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _attachRecordedAudio,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text(
                    'Attach Audio',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attachedPreviewCard(HomeworkProvider provider) {
    final fileName = _selectedFileName ?? _fileName(_selectedFilePath!);
    final isAudio = fileName.toLowerCase().endsWith('.m4a') ||
        fileName.toLowerCase().endsWith('.mp3') ||
        fileName.toLowerCase().endsWith('.wav');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isAudio ? Icons.mic_rounded : Icons.insert_drive_file_rounded,
              size: 20,
              color: AppColors.goldLight,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isAudio ? 'Voice Note Attachment' : 'Attached File',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove attachment',
            onPressed: provider.submitting
                ? null
                : () async {
                    await _audioPlayer.stop();
                    setState(() {
                      _selectedFilePath = null;
                      _selectedFileName = null;
                    });
                  },
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────── Attachment Tile Helper

  Widget _attachmentTile(String url) {
    final fileName = _fileName(url);
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toUpperCase()
        : 'FILE';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final uri = Uri.tryParse(url);
        if (uri == null) return;
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                ext,
                style: const TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.cream,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  String _fileName(String url) {
    final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
    if (segments.isEmpty) return 'Attachment';
    final last = segments[segments.length - 1];
    return last.isEmpty ? 'Attachment' : last;
  }
}

// ─────────────────────────────────────────────── Hero Card
class _HomeworkHeroCard extends StatelessWidget {
  final HomeworkDetail hw;
  const _HomeworkHeroCard({required this.hw});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceAlt,
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hw.title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.cream,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _badge(
                hw.isSubmitted ? 'SUBMITTED' : 'PENDING',
                hw.isSubmitted ? AppColors.success : AppColors.gold,
              ),
              if (hw.subject?.name != null)
                _badge(hw.subject!.name!.toUpperCase(), AppColors.muted),
              if (hw.hasMarks)
                _badge('MARKS: ${hw.marks}', AppColors.goldLight),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 12),
          _metaRow(
            Icons.person_outline_rounded,
            'Teacher',
            hw.teacher?.name ?? '—',
          ),
          const SizedBox(height: 8),
          _metaRow(
            Icons.event_available_outlined,
            'Assigned',
            hw.assignedDate ?? '—',
          ),
          const SizedBox(height: 8),
          _metaRow(
            Icons.event_busy_outlined,
            'Due Date',
            hw.dueDate ?? '—',
            isDanger: !hw.isSubmitted && hw.dueDate != null,
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _metaRow(
    IconData icon,
    String label,
    String value, {
    bool isDanger = false,
  }) {
    final valueColor = isDanger ? AppColors.danger : AppColors.cream;

    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.goldLight),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────── Section Header
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: AppColors.gold,
          letterSpacing: 0.8,
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
  final double progress; // 0.0 to 1.0

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

  // Curated pattern of normalized bar heights (0.2 to 1.0)
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
          height: 48,
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

              double barHeight = (baseRatio * bounce * 36).clamp(6.0, 42.0);

              Color barColor;
              if (widget.isRecording) {
                barColor = AppColors.gold;
              } else if (isPassed && widget.isPlaying) {
                barColor = AppColors.goldLight;
              } else {
                barColor = AppColors.line.withValues(alpha: 0.8);
              }

              return Container(
                width: 3.5,
                height: barHeight,
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: widget.isRecording || (isPassed && widget.isPlaying)
                      ? [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.3),
                            blurRadius: 4,
                          )
                        ]
                      : null,
                ),
              );
            }),
          ),
        );
      },
    );
  }
}


