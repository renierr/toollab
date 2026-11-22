import 'x_media.dart';
import 'x_post.dart';

/// One video or GIF of a post that was played past the view threshold.
class XWatchedVideo {
  final String postId;

  /// Index into the post's `allMedia`; quoted media belong to the quoted post.
  final int mediaIndex;
  final String authorScreenName;
  final String authorName;
  final String? avatarUrl;

  /// The post text, shortened.
  final String text;
  final String videoUrl;
  final String previewUrl;
  final bool isGif;
  final Duration duration;

  /// Time actually played, summed over all plays; seeking does not count.
  final Duration watched;
  final int playCount;
  final DateTime firstWatchedAt;
  final DateTime lastWatchedAt;

  const XWatchedVideo({
    required this.postId,
    required this.mediaIndex,
    required this.authorScreenName,
    required this.authorName,
    required this.avatarUrl,
    required this.text,
    required this.videoUrl,
    required this.previewUrl,
    required this.isGif,
    required this.duration,
    required this.watched,
    required this.playCount,
    required this.firstWatchedAt,
    required this.lastWatchedAt,
  });

  static const int _maxText = 200;

  /// A first view of [media], the [mediaIndex]th of [post]'s own media.
  factory XWatchedVideo.fromPost(XPost post, XMedia media, int mediaIndex) {
    final now = DateTime.now();
    return XWatchedVideo(
      postId: post.id,
      mediaIndex: mediaIndex,
      authorScreenName: post.author.screenName,
      authorName: post.author.name,
      avatarUrl: post.author.avatarUrl,
      text: post.text.length > _maxText
          ? '${post.text.substring(0, _maxText)}…'
          : post.text,
      videoUrl: media.videoUrl!,
      previewUrl: media.previewUrl,
      isGif: media.type == XMediaType.gif,
      duration: Duration(milliseconds: media.durationMs ?? 0),
      watched: Duration.zero,
      playCount: 0,
      firstWatchedAt: now,
      lastWatchedAt: now,
    );
  }

  factory XWatchedVideo.fromMap(Map<String, Object?> row) => XWatchedVideo(
    postId: row['post_id']! as String,
    mediaIndex: row['media_index']! as int,
    authorScreenName: row['author_screen_name']! as String,
    authorName: row['author_name']! as String,
    avatarUrl: row['avatar_url'] as String?,
    text: row['text']! as String,
    videoUrl: row['video_url']! as String,
    previewUrl: row['preview_url']! as String,
    isGif: row['is_gif'] == 1,
    duration: Duration(milliseconds: row['duration_ms']! as int),
    watched: Duration(milliseconds: row['watched_ms']! as int),
    playCount: row['play_count']! as int,
    firstWatchedAt: DateTime.fromMillisecondsSinceEpoch(
      row['first_watched_at']! as int,
    ),
    lastWatchedAt: DateTime.fromMillisecondsSinceEpoch(
      row['last_watched_at']! as int,
    ),
  );

  Map<String, Object?> toMap() => {
    'post_id': postId,
    'media_index': mediaIndex,
    'author_screen_name': authorScreenName,
    'author_name': authorName,
    'avatar_url': avatarUrl,
    'text': text,
    'video_url': videoUrl,
    'preview_url': previewUrl,
    'is_gif': isGif ? 1 : 0,
    'duration_ms': duration.inMilliseconds,
    'watched_ms': watched.inMilliseconds,
    'play_count': playCount,
    'first_watched_at': firstWatchedAt.millisecondsSinceEpoch,
    'last_watched_at': lastWatchedAt.millisecondsSinceEpoch,
  };

  String get postUrl => 'https://x.com/$authorScreenName/status/$postId';
}
