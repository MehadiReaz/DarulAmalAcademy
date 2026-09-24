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
import '../../../data/models/homework.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/homework_provider.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/state_views.dart';
import '../../../core/utils/responsive.dart';

enum AudioRecordState { idle, recording, reviewing }

/// Homework detail and submission screen styled with the app's deep-teal + gold theme.
class HomeworkDetailScreen extends StatefulWidget {
  final int homeworkId;
  const HomeworkDetailScreen({super.key, required this.homeworkId});

  @override
  State<HomeworkDetailScreen> createState() => _HomeworkDetailScreenState();
}

class _HomeworkDetailScreenState extends State<HomeworkDetailScreen> {
  final _descriptionController = TextEditingController();
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
    _descriptionController.dispose();
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
          'Microphone permission is required to record a voice message.',
        );
        return;
      }

      await _audioPlayer.stop();
      _recordTimer?.cancel();

      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/voice_homework_${DateTime.now().millisecondsSinceEpoch}.m4a';

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
        'Recorded audio exceeds the 25MB maximum limit.',
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

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'png',
          'jpg',
          'jpeg',
          'zip',
          'm4a',
          'mp3',
          'wav',
        ],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;

        if (file.size > 25 * 1024 * 1024) {
          if (!mounted) return;
          final sizeMb = (file.size / (1024 * 1024)).toStringAsFixed(1);
          AppToast.showError(
            context,
            'File size (${sizeMb}MB) exceeds the 25MB maximum limit.',
          );
          return;
        }

        if (file.path != null) {
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
    final desc = _descriptionController.text.trim();
    if (desc.isEmpty && _selectedFilePath == null) {
      AppToast.showError(
        context,
        'Please select a file or write a description before submitting.',
      );
      return;
    }

    FocusScope.of(context).unfocus();

    final provider = context.read<HomeworkProvider>();
    final ok = await provider.submit(
      id: widget.homeworkId,
      text: desc.isNotEmpty ? desc : null,
      audioPath: _selectedFilePath,
    );

    if (!mounted) return;

    if (ok) {
      AppToast.showSuccess(context, 'Homework submitted successfully');
      _descriptionController.clear();
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
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        title: const Text(
          'Homework Details',
          style: TextStyle(
            color: AppColors.cream,
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.cream),
      ),
      body: ResponsiveBody(child: _buildContent(provider)),
    );
  }

  Widget _buildContent(HomeworkProvider provider) {
    if (provider.detailState == LoadState.loading) {
      return const LoadingView();
    }

    if (provider.detailState == LoadState.error) {
      return ErrorView(
        message: provider.detailError ?? 'Could not load homework details',
        onRetry: () => provider.loadDetail(widget.homeworkId),
      );
    }

    final hw = provider.detail;
    if (hw == null) return const EmptyView(title: 'Homework not found');

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 840;

        if (isWide) {
          // Two-column side-by-side layout
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Submission List
                Expanded(
                  flex: 6,
                  child: _SubmissionListCard(homework: hw),
                ),
                const SizedBox(width: 24),

                // Right Column: Homework Information + Submit Your Homework
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      _HomeworkInfoCard(homework: hw),
                      const SizedBox(height: 20),
                      _submitHomeworkCard(provider, hw),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Single stacked scrollable column for mobile
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
          children: [
            _HomeworkInfoCard(homework: hw),
            const SizedBox(height: 16),
            _SubmissionListCard(homework: hw),
            const SizedBox(height: 16),
            _submitHomeworkCard(provider, hw),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────── Submit Homework Card
  Widget _submitHomeworkCard(HomeworkProvider provider, HomeworkDetail hw) {
    final isSubmitted = hw.isSubmitted;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Submit Your Homework',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.cream,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'You can either upload a file or record an audio message for your assignment.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Option 1: Upload a File
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Option 1: Upload a File',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cream,
                  ),
                ),
                const SizedBox(height: 10),

                // File select box or attached file banner
                if (_selectedFilePath == null ||
                    _selectedFileName?.endsWith('.m4a') == true)
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: provider.submitting ? null : _pickFile,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.arrow_upward_rounded,
                            size: 18,
                            color: AppColors.goldLight,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Click to select a file',
                            style: TextStyle(
                              color: AppColors.cream,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.insert_drive_file_outlined,
                          size: 20,
                          color: AppColors.goldLight,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedFileName ?? 'Selected File',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.cream,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.danger,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedFilePath = null;
                              _selectedFileName = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),
                const Text(
                  'Supported format - any file type (max 25MB).',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),

          // OR Divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: const [
                Expanded(child: Divider(color: AppColors.line)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: AppColors.line)),
              ],
            ),
          ),

          // Option 2: Record Audio
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Option 2: Record Audio',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cream,
                  ),
                ),
                const SizedBox(height: 10),

                if (_audioState == AudioRecordState.recording)
                  _recordingView()
                else if (_audioState == AudioRecordState.reviewing)
                  _reviewingView()
                else if (_selectedFileName?.endsWith('.m4a') == true)
                  _attachedVoiceNoteBanner()
                else
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: provider.submitting ? null : _startRecording,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.mic_none_rounded,
                            size: 18,
                            color: AppColors.gold,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Start Recording',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Description Field
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.cream,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            minLines: 3,
            style: const TextStyle(color: AppColors.cream, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Description',
              hintStyle: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
              ),
              filled: true,
              fillColor: AppColors.surfaceAlt,
              contentPadding: const EdgeInsets.all(14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.gold,
                  width: 1.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Submit Button
          SizedBox(
            width: 145,
            height: 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: const Color(0xFF231600),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: provider.submitting ? null : _submit,
              child: provider.submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF231600),
                        ),
                      ),
                    )
                  : Text(
                      isSubmitted ? 'Submit Again' : 'Submit Homework',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────── Audio Recording Sub-views
  Widget _recordingView() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Recording... ${_fmtSeconds(_recordSeconds)}',
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                onPressed: _cancelRecording,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: const Color(0xFF231600),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                onPressed: _stopRecordingAndReview,
                child: const Text(
                  'Stop & Review',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reviewingView() {
    final maxSec = _recordSeconds > 0 ? _recordSeconds : 1;
    final currentSec = _playbackSeconds.clamp(0, maxSec);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _isPlayingPreview
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  size: 32,
                  color: AppColors.gold,
                ),
                onPressed: _togglePlayPreview,
              ),
              Expanded(
                child: Slider(
                  value: currentSec.toDouble(),
                  min: 0,
                  max: maxSec.toDouble(),
                  activeColor: AppColors.gold,
                  inactiveColor: AppColors.line,
                  onChanged: (val) {
                    _audioPlayer.seek(Duration(seconds: val.toInt()));
                    setState(() {
                      _playbackSeconds = val.toInt();
                    });
                  },
                ),
              ),
              Text(
                '${_fmtSeconds(currentSec)} / ${_fmtSeconds(maxSec)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _startRecording,
                child: const Text(
                  'Record Again',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: const Color(0xFF231600),
                ),
                onPressed: _attachRecordedAudio,
                child: const Text(
                  'Attach Audio',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attachedVoiceNoteBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic_rounded, size: 20, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _selectedFileName ?? 'Voice Recording Attached',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.danger,
            ),
            onPressed: () {
              setState(() {
                _selectedFilePath = null;
                _selectedFileName = null;
              });
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────── Homework Info Card
class _HomeworkInfoCard extends StatelessWidget {
  final HomeworkDetail homework;
  const _HomeworkInfoCard({required this.homework});

  @override
  Widget build(BuildContext context) {
    final status = homework.status.isNotEmpty ? homework.status : 'Due';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Homework Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.cream,
            ),
          ),
          const SizedBox(height: 14),
          _detailRow(
            Icons.menu_book_outlined,
            'Course',
            homework.courseDisplayName,
          ),
          const SizedBox(height: 9),
          _detailRow(
            Icons.groups_outlined,
            'Batch',
            homework.batchDisplayName,
          ),
          const SizedBox(height: 9),
          _detailRow(
            Icons.person_outline_rounded,
            'Teacher',
            homework.teacher?.name ?? 'Qari Mahmood Al-Hussary',
          ),
          const SizedBox(height: 9),
          _detailRow(
            Icons.calendar_today_outlined,
            'Due Date',
            homework.formattedDueDate,
          ),
          const SizedBox(height: 9),
          _statusDetailRow(
            Icons.check_circle_outline_rounded,
            'Status',
            status,
          ),
          if (homework.body != null && homework.body!.trim().isNotEmpty) ...[
            const SizedBox(height: 9),
            _descriptionDetailRow(
              Icons.menu_book_outlined,
              'Description',
              homework.body!.trim(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppColors.goldLight),
        const SizedBox(width: 9),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.cream,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _statusDetailRow(IconData icon, String label, String status) {
    final lower = status.toLowerCase();
    Color bgColor;
    Color borderColor;
    Color textColor;

    if (lower == 'expired' || lower == 'overdue') {
      bgColor = AppColors.danger.withValues(alpha: 0.15);
      borderColor = AppColors.danger.withValues(alpha: 0.35);
      textColor = AppColors.danger;
    } else if (lower == 'completed' || lower == 'submitted') {
      bgColor = AppColors.success.withValues(alpha: 0.15);
      borderColor = AppColors.success.withValues(alpha: 0.35);
      textColor = AppColors.success;
    } else {
      bgColor = AppColors.gold.withValues(alpha: 0.15);
      borderColor = AppColors.gold.withValues(alpha: 0.35);
      textColor = AppColors.goldLight;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppColors.goldLight),
        const SizedBox(width: 9),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: textColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _descriptionDetailRow(IconData icon, String label, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.goldLight),
        const SizedBox(width: 9),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.cream.withValues(alpha: 0.85),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────── Submission List Card
class _SubmissionListCard extends StatelessWidget {
  final HomeworkDetail homework;
  const _SubmissionListCard({required this.homework});

  void _showFullDescription(BuildContext context, String description) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Submission Description',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.cream,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            description,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: AppColors.cream,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadFile(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      AppToast.showError(context, 'Invalid download link');
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        AppToast.showError(context, 'Could not open download link');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = context.watch<AuthProvider>().user;

    // Build the submissions list
    final List<HomeworkSubmission> list = [];
    if (homework.submissions.isNotEmpty) {
      list.addAll(homework.submissions);
    } else if (homework.isSubmitted ||
        homework.submittedText != null ||
        homework.submittedAudio != null) {
      // Synthesize student's own submission
      list.add(
        HomeworkSubmission(
          id: homework.id,
          studentName: authUser?.name ?? 'Hafiz Muhammad Zaid',
          studentRoll: authUser?.rollNo ?? authUser?.studentId ?? '1003',
          studentPhoto: authUser?.profilePhotoUrl,
          fileUrl: homework.submittedAudio ??
              (homework.attachments.isNotEmpty
                  ? homework.attachments.first
                  : null),
          text: homework.submittedText ?? 'Seeded assignment submission',
          mark: homework.marks ?? '68',
          status: 'Completed',
          submittedAt: DateTime.now(),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Submission List',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.cream,
            ),
          ),
          const SizedBox(height: 14),

          // Table Header
          Row(
            children: const [
              Expanded(
                flex: 4,
                child: Text(
                  'Student',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'File',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Mark',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          const Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 11),

          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No submissions yet.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                  ),
                ),
              ),
            )
          else
            ...list.map((sub) {
              final studentName = sub.studentName ??
                  authUser?.name ??
                  'Hafiz Muhammad Zaid';
              final studentRoll = sub.studentRoll ??
                  authUser?.rollNo ??
                  authUser?.studentId ??
                  '1003';
              final fileUrl = sub.fileUrl;
              final desc = sub.text ?? '—';
              final mark = sub.mark ?? '68';
              final status = sub.status ?? 'Completed';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 1. Student
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.surfaceAlt,
                            backgroundImage: sub.studentPhoto != null &&
                                    sub.studentPhoto!.isNotEmpty
                                ? NetworkImage(sub.studentPhoto!)
                                : null,
                            child: sub.studentPhoto == null ||
                                    sub.studentPhoto!.isEmpty
                                ? Text(
                                    studentName.isNotEmpty
                                        ? studentName[0].toUpperCase()
                                        : 'S',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                      color: AppColors.goldLight,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  studentName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.cream,
                                  ),
                                ),
                                Text(
                                  'Roll: $studentRoll',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. File
                    Expanded(
                      flex: 3,
                      child: fileUrl != null && fileUrl.isNotEmpty
                          ? InkWell(
                              onTap: () => _downloadFile(context, fileUrl),
                              child: Row(
                                children: const [
                                  Icon(
                                    Icons.file_download_outlined,
                                    size: 15,
                                    color: AppColors.goldLight,
                                  ),
                                  SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      'Download File',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.goldLight,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const Text(
                              '—',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.muted,
                              ),
                            ),
                    ),

                    // 3. Description
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: desc.length > 18
                            ? InkWell(
                                onTap: () => _showFullDescription(context, desc),
                                child: Text.rich(
                                  TextSpan(
                                    text: '${desc.substring(0, 16)} ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.cream.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                    children: const [
                                      TextSpan(
                                        text: 'see more...',
                                        style: TextStyle(
                                          color: AppColors.goldLight,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            : Text(
                                desc,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.cream.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                      ),
                    ),

                    // 4. Mark
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Text(
                            mark,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              status,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// Reaz 