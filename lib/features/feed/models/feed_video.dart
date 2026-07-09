/// A video from the user's subscription feed, populated by the server-side
/// `fetch-feed` Edge Function (or sample data in demo mode).
class FeedVideo {
  const FeedVideo({
    required this.videoId,
    required this.title,
    required this.channelId,
    required this.channelTitle,
    required this.thumbnailUrl,
    required this.publishedAt,
    required this.categoryId,
    this.durationSeconds,
    this.isShort = false,
  });

  final String videoId;
  final String title;
  final String channelId;
  final String channelTitle;
  final String thumbnailUrl;
  final DateTime publishedAt;
  final String categoryId;
  final int? durationSeconds;
  final bool isShort;

  String get watchUrl => 'https://www.youtube.com/watch?v=$videoId';

  factory FeedVideo.fromJson(Map<String, dynamic> j) => FeedVideo(
        videoId: '${j['videoId'] ?? j['video_id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        channelId: '${j['channelId'] ?? j['channel_id'] ?? ''}',
        channelTitle: '${j['channelTitle'] ?? j['channel_title'] ?? ''}',
        thumbnailUrl: '${j['thumbnailUrl'] ?? j['thumbnail_url'] ?? ''}',
        publishedAt:
            DateTime.tryParse('${j['publishedAt'] ?? j['published_at'] ?? ''}')
                    ?.toLocal() ??
                DateTime.now(),
        categoryId: '${j['categoryId'] ?? j['category_id'] ?? ''}',
        durationSeconds:
            (j['durationSeconds'] ?? j['duration_seconds']) as int?,
        isShort: (j['isShort'] ?? j['is_short'] ?? false) as bool,
      );

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'title': title,
        'channelId': channelId,
        'channelTitle': channelTitle,
        'thumbnailUrl': thumbnailUrl,
        'publishedAt': publishedAt.toUtc().toIso8601String(),
        'categoryId': categoryId,
        'durationSeconds': durationSeconds,
        'isShort': isShort,
      };
}
