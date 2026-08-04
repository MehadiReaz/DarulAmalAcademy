import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../core/utils/json_utils.dart';
import 'student_user.dart';

/// A class recording, from `GET /student/recordings` (paginated) and
/// `GET /student/recordings/{id}`.
class Recording {
  final int id;
  final String title;
  final String? description;

  /// 'youtube' | 'google_drive' | others.
  final String videoType;
  final String? videoUrl;
  final String? embedUrl;
  final String? thumbnail;
  final String? recordedOn;
  final bool active;
  final NamedRef? teacher;
  final NamedRef? course;
  final NamedRef? subject;
  final NamedRef? batch;

  const Recording({
    required this.id,
    required this.title,
    this.description,
    this.videoType = '',
    this.videoUrl,
    this.embedUrl,
    this.thumbnail,
    this.recordedOn,
    this.active = true,
    this.teacher,
    this.course,
    this.subject,
    this.batch,
  });

  factory Recording.fromJson(Map<String, dynamic> json) => Recording(
        id: asInt(json['id']),
        title: asString(json['title'], fallback: 'Recording'),
        description: asStringOrNull(json['description']),
        videoType: asString(json['video_type']),
        videoUrl: asStringOrNull(json['video_url']),
        embedUrl: asStringOrNull(json['embed_url']),
        thumbnail: asStringOrNull(json['thumbnail']),
        recordedOn: asStringOrNull(json['recorded_on']),
        active: asBool(json['status']),
        teacher: json['teacher'] == null
            ? null
            : NamedRef.fromJson(asMap(json['teacher']) ?? {}),
        course: json['course'] == null
            ? null
            : NamedRef.fromJson(asMap(json['course']) ?? {}),
        subject: json['subject'] == null
            ? null
            : NamedRef.fromJson(asMap(json['subject']) ?? {}),
        batch: json['batch'] == null
            ? null
            : NamedRef.fromJson(asMap(json['batch']) ?? {}),
      );

  DateTime? get recordedAt => asDate(recordedOn);

  bool get isYoutube => videoType.toLowerCase() == 'youtube';
  bool get isDrive => videoType.toLowerCase() == 'google_drive';

  String get sourceLabel {
    if (isYoutube) return 'YouTube';
    if (isDrive) return 'Google Drive';
    return videoType.isEmpty ? 'Video' : videoType;
  }

  /// Prefer the plain URL for playback; fall back to the embed one.
  String? get playableUrl {
    if (videoUrl != null && videoUrl!.isNotEmpty) return videoUrl;
    if (embedUrl != null && embedUrl!.isNotEmpty) return embedUrl;
    return null;
  }

  /// Extracts the YouTube video ID from [playableUrl] or [embedUrl] or [videoUrl].
  String? get youtubeId {
    final url = playableUrl;
    if (url == null || url.isEmpty) return null;
    return YoutubePlayer.convertUrlToId(url);
  }

  /// Returns true if this recording has a valid YouTube link that can be played in-app.
  bool get isYoutubePlayable => youtubeId != null;

  /// Extracts the Google Drive file ID from [playableUrl] or [embedUrl] or [videoUrl].
  String? get driveFileId {
    final url = playableUrl;
    if (url == null || url.isEmpty) return null;

    final fileMatch =
        RegExp(r'drive\.google\.com/file/d/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (fileMatch != null) return fileMatch.group(1);

    final idMatch = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(url);
    if (idMatch != null) return idMatch.group(1);

    return null;
  }

  /// Format URL for Google Drive preview iframe embed playback in-app.
  String? get driveEmbedUrl {
    final fileId = driveFileId;
    if (fileId != null && fileId.isNotEmpty) {
      return 'https://drive.google.com/file/d/$fileId/preview';
    }
    return playableUrl;
  }

  bool get isDrivePlayable =>
      isDrive ||
      (playableUrl != null && playableUrl!.contains('drive.google.com'));

  bool get isPlayable =>
      isYoutubePlayable ||
      isDrivePlayable ||
      (playableUrl != null && playableUrl!.isNotEmpty);
}
