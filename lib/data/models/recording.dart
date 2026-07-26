import '../../core/utils/json_utils.dart';
import 'student_user.dart';

/// A class recording, from `GET /student/recordings` (paginated) and
/// `GET /student/recordings/{id}`.
///
/// The server supplies both `video_url` (the human-facing link) and
/// `embed_url` (the iframe-ready one). Since the app has no webview
/// dependency, playback opens `video_url` externally — [embedUrl] is kept
/// for when an in-app player is added.
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

  /// Prefer the plain URL for external launch; fall back to the embed one
  /// so a recording without `video_url` is still playable.
  String? get playableUrl {
    if (videoUrl != null && videoUrl!.isNotEmpty) return videoUrl;
    if (embedUrl != null && embedUrl!.isNotEmpty) return embedUrl;
    return null;
  }

  bool get isPlayable => playableUrl != null;
}
