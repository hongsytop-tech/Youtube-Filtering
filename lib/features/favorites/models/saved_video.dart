import '../../feed/models/feed_video.dart';

/// A favorited video: a self-contained snapshot so it survives leaving the
/// feed, plus a [pinned] flag for keeping it at the top.
class SavedVideo {
  const SavedVideo({
    required this.videoId,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
    this.publishedAt,
    this.pinned = false,
    this.folderId,
    this.topics = const [],
    required this.createdAt,
  });

  final String videoId;
  final String title;
  final String channelTitle;
  final String thumbnailUrl;
  final DateTime? publishedAt;
  final bool pinned;

  /// Id of the folder this favorite is filed under (null = 미분류/unfiled).
  final String? folderId;

  /// Fine-grained topic tags captured from the feed when favorited (used for
  /// the 주제별 view). Empty for favorites added by link.
  final List<String> topics;
  final DateTime createdAt;

  String get watchUrl => 'https://www.youtube.com/watch?v=$videoId';

  factory SavedVideo.fromFeedVideo(FeedVideo v) => SavedVideo(
        videoId: v.videoId,
        title: v.title,
        channelTitle: v.channelTitle,
        thumbnailUrl: v.thumbnailUrl,
        publishedAt: v.publishedAt,
        topics: v.topics,
        createdAt: DateTime.now(),
      );

  /// Minimal favorite built from a bare video id (e.g. added by link) — uses
  /// YouTube's public thumbnail so a card still renders.
  factory SavedVideo.fromId(String videoId, {String? title}) => SavedVideo(
        videoId: videoId,
        title: title ?? '유튜브 영상',
        channelTitle: '',
        thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/mqdefault.jpg',
        createdAt: DateTime.now(),
      );

  /// A FeedVideo view for rendering in the shared VideoCard.
  FeedVideo toFeedVideo() => FeedVideo(
        videoId: videoId,
        title: title,
        channelId: '',
        channelTitle: channelTitle,
        thumbnailUrl: thumbnailUrl,
        publishedAt: publishedAt ?? createdAt,
        categoryId: '',
        topics: topics,
      );

  factory SavedVideo.fromJson(Map<String, dynamic> j) => SavedVideo(
        videoId: '${j['videoId'] ?? j['video_id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        channelTitle: '${j['channelTitle'] ?? j['channel_title'] ?? ''}',
        thumbnailUrl: '${j['thumbnailUrl'] ?? j['thumbnail_url'] ?? ''}',
        publishedAt: DateTime.tryParse(
                '${j['publishedAt'] ?? j['published_at'] ?? ''}')
            ?.toLocal(),
        pinned: (j['pinned'] ?? false) as bool,
        folderId: (j['folderId'] ?? j['folder_id']) == null
            ? null
            : '${j['folderId'] ?? j['folder_id']}',
        topics: ((j['topics']) as List?)?.map((e) => '$e').toList() ?? const [],
        createdAt:
            DateTime.tryParse('${j['createdAt'] ?? j['created_at'] ?? ''}')
                    ?.toLocal() ??
                DateTime.now(),
      );

  /// Local-cache JSON (camelCase).
  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'title': title,
        'channelTitle': channelTitle,
        'thumbnailUrl': thumbnailUrl,
        'publishedAt': publishedAt?.toUtc().toIso8601String(),
        'pinned': pinned,
        'folderId': folderId,
        'topics': topics,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  /// Supabase row (snake_case columns).
  Map<String, dynamic> toRow(String userId) => {
        'user_id': userId,
        'video_id': videoId,
        'title': title,
        'channel_title': channelTitle,
        'thumbnail_url': thumbnailUrl,
        'published_at': publishedAt?.toUtc().toIso8601String(),
        'pinned': pinned,
        'folder_id': folderId,
        'topics': topics,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  // `_keep` distinguishes "argument omitted" from "explicitly set to null" so
  // folderId can be cleared (move to 미분류) via copyWith.
  static const _keep = Object();

  SavedVideo copyWith({
    bool? pinned,
    Object? folderId = _keep,
    List<String>? topics,
  }) =>
      SavedVideo(
        videoId: videoId,
        title: title,
        channelTitle: channelTitle,
        thumbnailUrl: thumbnailUrl,
        publishedAt: publishedAt,
        pinned: pinned ?? this.pinned,
        folderId:
            identical(folderId, _keep) ? this.folderId : folderId as String?,
        topics: topics ?? this.topics,
        createdAt: createdAt,
      );
}
