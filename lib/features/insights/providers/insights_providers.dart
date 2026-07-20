import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feed/models/feed_video.dart';
import '../../feed/providers/feed_prefs.dart';
import '../../feed/providers/feed_providers.dart';
import '../../feed/providers/video_states_providers.dart';
import 'exclusions_providers.dart';

enum InsightKind { topic, channel, keyword }

/// Identifies a ranked item (used to look up its videos).
class InsightQuery {
  const InsightQuery(this.kind, this.value);
  final InsightKind kind;
  final String value;

  @override
  bool operator ==(Object other) =>
      other is InsightQuery && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);
}

/// The videos behind a ranked item, over the same visible pool as the insights
/// (minus hidden / shorts / excluded).
final insightVideosProvider =
    Provider.autoDispose.family<List<FeedVideo>, InsightQuery>((ref, q) {
  final videos = ref.watch(feedProvider).asData?.value ?? const <FeedVideo>[];
  final includeShorts = ref.watch(includeShortsProvider);
  final hidden = ref.watch(hiddenVideosProvider);
  final excl = ref.watch(exclusionsProvider);
  final needle = q.value.toLowerCase();

  final out = <FeedVideo>[];
  for (final v in videos) {
    if (hidden.contains(v.videoId)) continue;
    if (!includeShorts && v.isShort) continue;
    if (excl.matches(v)) continue;
    final bool m = switch (q.kind) {
      InsightKind.topic => v.topics.contains(q.value),
      InsightKind.channel => v.channelTitle == q.value,
      InsightKind.keyword => v.title.toLowerCase().contains(needle),
    };
    if (m) out.add(v);
  }
  return out;
});

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

  // Full ranked lists (no truncation) — the UI shows a Top-N preview and lets
  // the user tap the section header to browse everything.
  List<MapEntry<String, int>> ranked(Map<String, int> m, {int min = 1}) {
    final list = m.entries.where((e) => e.value >= min).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  return FeedInsights(
    total: pool.length,
    topics: ranked(topicCount),
    channels: ranked(channelCount),
    keywords: ranked(keywordCount, min: 2),
  );
});
