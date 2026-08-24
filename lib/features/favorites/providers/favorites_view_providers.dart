import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feed/providers/feed_providers.dart';
import '../models/saved_video.dart';
import 'favorites_providers.dart';

/// Favorites can be viewed grouped by folder (manual) or by topic (from the
/// analysis tags).
enum FavView { folder, topic }

final favViewProvider = StateProvider<FavView>((ref) => FavView.folder);

/// Selected topic in 주제별 view: null = 전체, kNoTopic = 주제 없음.
final selectedFavTopicProvider = StateProvider<String?>((ref) => null);

/// Sentinel for favorites that carry no topic tags.
const kNoTopic = '__notopic__';

/// videoId → topics from the current feed, used to backfill topics for
/// favorites that were saved before topics were captured (and are still
/// present in the feed).
final favoriteFeedTopicsProvider =
    Provider.autoDispose<Map<String, List<String>>>((ref) {
  final feed = ref.watch(feedProvider).asData?.value ?? const [];
  return {for (final v in feed) v.videoId: v.topics};
});

/// The effective topics for a favorite: its stored tags, or the feed's tags for
/// the same video id if it has none stored.
List<String> effectiveTopics(
  SavedVideo v,
  Map<String, List<String>> feedTopics,
) =>
    v.topics.isNotEmpty ? v.topics : (feedTopics[v.videoId] ?? const []);

/// Topic → favorite count, most common first. Used by the 주제별 chip bar.
final favoriteTopicCountsProvider =
    Provider.autoDispose<List<MapEntry<String, int>>>((ref) {
  final favs = ref.watch(favoritesProvider);
  final feedTopics = ref.watch(favoriteFeedTopicsProvider);
  final counts = <String, int>{};
  for (final f in favs) {
    for (final t in effectiveTopics(f, feedTopics)) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
  }
  final list = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return list;
});
