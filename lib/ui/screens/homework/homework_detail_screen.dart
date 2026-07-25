import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/homework.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/homework_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/state_views.dart';

/// Homework detail + submission, backed by `GET /student/homework/{id}`
/// and `POST /student/homework/{id}/submit`.
///
/// The backend accepts a text answer and/or an audio file. Only the text
/// path is wired here because the project has no recorder or file-picker
/// dependency yet — `HomeworkRepository.submit` already takes an
/// `audioPath`, so adding one is a UI-only change.
class HomeworkDetailScreen extends StatefulWidget {
  final int homeworkId;
  const HomeworkDetailScreen({super.key, required this.homeworkId});

  @override
  State<HomeworkDetailScreen> createState() => _HomeworkDetailScreenState();
}

class _HomeworkDetailScreenState extends State<HomeworkDetailScreen> {
  final _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeworkProvider>().loadDetail(widget.homeworkId);
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _answerController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write your answer before submitting.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    final provider = context.read<HomeworkProvider>();
    final ok = await provider.submit(id: widget.homeworkId, text: text);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Homework submitted' : (provider.submitError ?? 'Could not submit'),
        ),
        backgroundColor: ok ? null : AppColors.danger,
      ),
    );

    if (ok) _answerController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeworkProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Homework')),
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
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hw.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill(
                    hw.isSubmitted ? 'Submitted' : 'Pending',
                    hw.isSubmitted ? AppColors.success : AppColors.gold,
                  ),
                  if (hw.subject?.name != null)
                    _pill(hw.subject!.name!, AppColors.muted),
                  if (hw.hasMarks) _pill('Marks ${hw.marks}', AppColors.gold),
                ],
              ),
              const SizedBox(height: 14),
              _meta(Icons.person_outline_rounded, 'Teacher',
                  hw.teacher?.name ?? '—'),
              _meta(Icons.event_available_outlined, 'Assigned',
                  hw.assignedDate ?? '—'),
              _meta(Icons.event_busy_outlined, 'Due', hw.dueDate ?? '—'),
            ],
          ),
        ),
        if (hw.body != null && hw.body!.isNotEmpty) ...[
          const SizedBox(height: 18),
          const _SectionLabel('Instructions'),
          const SizedBox(height: 10),
          _card(
            child: Text(
              hw.body!,
              style: const TextStyle(
                color: AppColors.cream,
                fontSize: 13,
                height: 1.65,
              ),
            ),
          ),
        ],
        if (hw.attachments.isNotEmpty) ...[
          const SizedBox(height: 18),
          const _SectionLabel('Attachments'),
          const SizedBox(height: 10),
          ...hw.attachments.map(_attachmentTile),
        ],
        const SizedBox(height: 18),
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
        const _SectionLabel('Your submission'),
        const SizedBox(height: 10),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  const Text(
                    'Submitted',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (hw.history.isNotEmpty)
                    Text(
                      Fmt.ago(hw.history.first.submittedAt),
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 10.5),
                    ),
                ],
              ),
              if (hw.submittedText != null && hw.submittedText!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  hw.submittedText!,
                  style: const TextStyle(fontSize: 12.5, height: 1.6),
                ),
              ],
              if (hw.submittedAudio != null &&
                  hw.submittedAudio!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _attachmentTile(hw.submittedAudio!),
              ],
            ],
          ),
        ),
        // `teacher_remarks` is currently a duplicate of the submitted text
        // on the backend, so it is only shown when it actually differs.
        if (hw.teacherRemarks != null &&
            hw.teacherRemarks!.isNotEmpty &&
            hw.teacherRemarks != hw.submittedText) ...[
          const SizedBox(height: 18),
          const _SectionLabel('Teacher remarks'),
          const SizedBox(height: 10),
          _card(
            child: Text(
              hw.teacherRemarks!,
              style: const TextStyle(fontSize: 12.5, height: 1.6),
            ),
          ),
        ],
        const SizedBox(height: 14),
        const Text(
          'Homework can only be submitted once. Speak to your teacher if '
          'you need to change your answer.',
          style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.5),
        ),
      ],
    );
  }

  Widget _submitForm(HomeworkProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Your answer'),
        const SizedBox(height: 10),
        TextField(
          controller: _answerController,
          maxLines: 7,
          minLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Write your answer here…',
            alignLabelWithHint: true,
          ),
        ),
        if (provider.submitError != null) ...[
          const SizedBox(height: 10),
          Text(
            provider.submitError!,
            style: const TextStyle(color: AppColors.danger, fontSize: 11.5),
          ),
        ],
        const SizedBox(height: 16),
        AppButton(
          label: 'Submit Homework',
          icon: Icons.send_rounded,
          loading: provider.submitting,
          onPressed: _submit,
        ),
        const SizedBox(height: 10),
        const Text(
          'You can only submit once, so check your answer before sending.',
          style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.5),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────── small pieces

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }

  Widget _meta(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.goldLight),
          const SizedBox(width: 9),
          Text(label,
              style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _attachmentTile(String url) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
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
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF24504A),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.attach_file_rounded,
                  size: 18, color: AppColors.goldLight),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _fileName(url),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.open_in_new_rounded,
                size: 16, color: AppColors.muted),
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: AppColors.muted,
      ),
    );
  }
}
