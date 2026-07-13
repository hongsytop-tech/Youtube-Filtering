import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feed/models/feed_video.dart';
import '../../feed/providers/feed_prefs.dart';
import '../../feed/providers/feed_providers.dart';
import '../../feed/providers/video_states_providers.dart';
import 'exclusions_providers.dart';

/// A ranked breakdown of the current feed — "what the algorithm feeds me".
class FeedInsights {
  const FeedInsights({
    required this.total,
    required this.topics,
    required this.channels,
    required this.keywords,
  });

  final int total;
  final List<MapEntry<String, int>> topics;
  final List<MapEntry<String, int>> channels;
  final List<MapEntry<String, int>> keywords;
}

const _stopwords = <String>{
  '영상', '공식', '풀버전', '다시보기', 'the', 'and', 'for', 'you', 'official',
  'video', 'mv', 'shorts', 'ep', 'feat', 'with', 'live', 'full', 'vs',
  '리뷰', '방송', '하는', '했다', '이런', '그리고', '진짜', '이제', '근데',
};

final _wordSplit = RegExp(r'[^0-9A-Za-z가-힣]+');

/// Insights computed over the currently-visible feed (respects hidden, shorts
/// toggle, and exclusions) so the picture updates as you trim.
final feedInsightsProvider = Provider.autoDispose<FeedInsights>((ref) {
  final videos = ref.watch(feedProvider).asData?.value ?? const <FeedVideo>[];
  final includeShorts = ref.watch(includeShortsProvider);
  final hidden = ref.watch(hiddenVideosProvider);
  final excl = ref.watch(exclusionsProvider);

  final pool = <FeedVideo>[];
  for (final v in videos) {
    if (hidden.contains(v.videoId)) continue;
    if (!includeShorts && v.isShort) continue;
    if (excl.matches(v)) continue;
    pool.add(v);
  }

  final topicCount = <String, int>{};
  final channelCount = <String, int>{};
  final keywordCount = <String, int>{};

  for (final v in pool) {
    for (final t in v.topics) {
      topicCount[t] = (topicCount[t] ?? 0) + 1;
    }
    if (v.channelTitle.isNotEmpty) {
      channelCount[v.channelTitle] = (channelCount[v.channelTitle] ?? 0) + 1;
    }
    final seen = <String>{};
    for (final w in v.title.toLowerCase().split(_wordSplit)) {
      if (w.length < 2) continue;
      if (_stopwords.contains(w)) continue;
      if (RegExp(r'^[0-9]+$').hasMatch(w)) continue;
      if (!seen.add(w)) continue;
      keywordCount[w] = (keywordCount[w] ?? 0) + 1;
    }
  }

  List<MapEntry<String, int>> top(Map<String, int> m, int n, {int min = 1}) {
    final list = m.entries.where((e) => e.value >= min).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list.take(n).toList();
  }

  return FeedInsights(
    total: pool.length,
    topics: top(topicCount, 20),
    channels: top(channelCount, 20),
    keywords: top(keywordCount, 25, min: 2),
  );
});
