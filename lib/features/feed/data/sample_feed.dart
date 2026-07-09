import '../models/feed_video.dart';

/// Demo feed used when the backend hasn't fetched real data yet.
/// Lets you exercise the category filter UI without burning API quota.
final List<FeedVideo> kSampleFeed = () {
  final now = DateTime.now();
  FeedVideo v(
    String id,
    String title,
    String channel,
    String categoryId,
    int hoursAgo,
  ) =>
      FeedVideo(
        videoId: id,
        title: title,
        channelId: 'ch_$channel',
        channelTitle: channel,
        thumbnailUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
        publishedAt: now.subtract(Duration(hours: hoursAgo)),
        categoryId: categoryId,
      );

  return <FeedVideo>[
    v('dQw4w9WgXcQ', '오늘의 신곡 플레이리스트', 'MusicDaily', '10', 2),
    v('9bZkp7q19f0', '초보를 위한 Flutter 입문', 'CodeSchool', '27', 5),
    v('kJQP7kiw5Fk', 'RTX 5090 실사용 리뷰', 'TechReview', '28', 8),
    v('L_jWHffIx5E', '전략 게임 신작 첫인상', 'GameCast', '20', 12),
    v('3JZ_D3ELwOQ', '30분 홈트레이닝 루틴', 'FitLife', '17', 20),
    v('e-ORhEE9VVg', '주간 뉴스 브리핑', 'NewsRoom', '25', 26),
    v('fJ9rUzIMcZQ', '알고리즘 문제풀이 라이브', 'CodeSchool', '27', 30),
    v('OPf0YbXqDm0', '집에서 만드는 파스타', 'CookNow', '26', 40),
  ];
}();
