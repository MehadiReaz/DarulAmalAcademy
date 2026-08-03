import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/json_utils.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/class_provider.dart';
import '../../widgets/state_views.dart';

class MyBatchesScreen extends StatefulWidget {
  const MyBatchesScreen({super.key});

  @override
  State<MyBatchesScreen> createState() => _MyBatchesScreenState();
}

class _MyBatchesScreenState extends State<MyBatchesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClassProvider>().loadBatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClassProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Batches'),
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(ClassProvider provider) {
    if (provider.batchesState == LoadState.loading && provider.batches.isEmpty) {
      return const LoadingView(message: 'Loading your assigned batches…');
    }

    if (provider.batchesState == LoadState.error && provider.batches.isEmpty) {
      return ErrorView(
        message: provider.batchesError ?? 'Could not load your batches',
        onRetry: () => provider.loadBatches(force: true),
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () => provider.loadBatches(force: true),
      child: provider.batches.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                const EmptyView(
                  icon: Icons.groups_outlined,
                  title: 'No active batches',
                  subtitle: 'Batch assignments from your madrasah will appear here.',
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
              itemCount: provider.batches.length,
              itemBuilder: (context, index) {
                final batch = provider.batches[index];
                return _BatchCard(batch: batch);
              },
            ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  final Map<String, dynamic> batch;
  const _BatchCard({required this.batch});

  Future<void> _launchZoom(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open Zoom link: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        final minute = parts[1];
        final ampm = hour >= 12 ? 'PM' : 'AM';
        hour = hour % 12;
        if (hour == 0) hour = 12;
        return '$hour:$minute $ampm';
      }
    } catch (_) {}
    return timeStr;
  }

  @override
  Widget build(BuildContext context) {
    final name = asString(batch['name'] ?? batch['batch_name'], fallback: 'Batch');
    final courseMap = asMap(batch['course']) ?? {};
    final courseName = asString(courseMap['name'], fallback: asString(batch['course_name']));
    final teacherMap = asMap(batch['teacher']) ?? {};
    final teacherName = asStringOrNull(teacherMap['name']);
    final teacherPhoto = asStringOrNull(teacherMap['profile_photo_url']);

    final zoomLink = asStringOrNull(batch['zoom_link']);
    final zoomMeetingId = asStringOrNull(batch['zoom_meeting_id']);

    final startTime = _formatTime(asStringOrNull(batch['start_time']));
    final endTime = _formatTime(asStringOrNull(batch['end_time']));
    final timeDisplay = (startTime.isNotEmpty && endTime.isNotEmpty)
        ? '$startTime – $endTime'
        : (startTime.isNotEmpty ? startTime : '');

    final daysList = (batch['days'] is List)
        ? (batch['days'] as List).map((e) => e.toString()).toList()
        : <String>[];

    final description = asStringOrNull(batch['description']);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Title + Course Tag
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2B5B53), Color(0xFF193D37)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.groups_rounded,
                  color: AppColors.goldLight,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.cream,
                      ),
                    ),
                    if (courseName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        courseName,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.goldLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF2ECC71).withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    color: Color(0xFF2ECC71),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          // Description if present
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.muted,
                height: 1.35,
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(color: AppColors.line, height: 1),
          const SizedBox(height: 12),

          // Teacher & Timing Row
          Row(
            children: [
              if (teacherName != null)
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: const Color(0xFF24504A),
                        backgroundImage: (teacherPhoto != null && teacherPhoto.isNotEmpty)
                            ? NetworkImage(teacherPhoto)
                            : null,
                        child: (teacherPhoto == null || teacherPhoto.isEmpty)
                            ? Text(
                                teacherName[0].toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.goldLight,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Teacher',
                              style: TextStyle(fontSize: 9.5, color: AppColors.muted),
                            ),
                            Text(
                              teacherName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.cream,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (timeDisplay.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: AppColors.gold),
                    const SizedBox(width: 5),
                    Text(
                      timeDisplay,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.goldLight,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Schedule Days Pills
          if (daysList.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: daysList.map((day) {
                final shortDay = day.length >= 3 ? day.substring(0, 3) : day;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF193731),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    shortDay,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.cream,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Meeting Info & Zoom Join Button
          if (zoomLink != null && zoomLink.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (zoomMeetingId != null && zoomMeetingId.isNotEmpty)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Meeting ID',
                          style: TextStyle(fontSize: 9.5, color: AppColors.muted),
                        ),
                        Text(
                          zoomMeetingId,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.cream,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _launchZoom(context, zoomLink),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D8CFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.video_call_rounded, size: 18),
                  label: const Text(
                    'Join Zoom',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
