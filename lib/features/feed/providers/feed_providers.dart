import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../categories/models/filter_category.dart';
import '../../categories/providers/categories_providers.dart';
import '../models/feed_video.dart';
import '../services/feed_service.dart';
import 'feed_prefs.dart';
import 'video_states_providers.dart';

final feedServiceProvider = Provider<FeedService>(
  (ref) => FeedService(ref.watch(localStorageProvider)),
);

/// True while an in-app (server-side subscription) collection is running.
final feedCollectingProvider = StateProvider<bool>((ref) => false);

final feedProvider = FutureProvider.autoDispose<List<FeedVideo>>(
  (ref) => ref.watch(feedServiceProvider).fetch(),
);

/// The feed after applying the enabled categories' filter.
/// If no category is enabled, everything shows.
final filteredFeedProvider = Provider.autoDispose<AsyncValue<List<FeedVideo>>>(
  (ref) {
    final feed = ref.watch(feedProvider);
    final enabled = ref.watch(categoriesProvider).enabled;
    final includeShorts = ref.watch(includeShortsProvider);
    final hidden = ref.watch(hiddenVideosProvider);
    return feed.whenData(
      (videos) => _applyFilter(videos, enabled, includeShorts, hidden),
    );
  },
);

/// True if [c] would surface [v] (same rule the feed filter uses per-category).
bool categoryMatchesVideo(FilterCategory c, FeedVideo v) {
  if (c.youtubeCategoryIds.contains(v.categoryId)) return true;
  if (c.topics.any(v.topics.contains)) return true;
  if (c.keywords.isEmpty) return false;
  final title = v.title.toLowerCase();
  return c.keywords.any((k) => title.contains(k.toLowerCase()));
}

/// Categories worth showing in the feed's selector: those that actually match
/// at least one collected video (plus any currently-enabled one, so it can
/// still be toggled off). Keeps the bar from listing empty categories.
final visibleCategoriesProvider =
    Provider.autoDispose<List<FilterCategory>>((ref) {
  final videos = ref.watch(feedProvider).asData?.value ?? const <FeedVideo>[];
  final cats = ref.watch(categoriesProvider).items;
  final includeShorts = ref.watch(includeShortsProvider);
  final hidden = ref.watch(hiddenVideosProvider);

  var pool = videos.where((v) => !hidden.contains(v.videoId));
  if (!includeShorts) pool = pool.where((v) => !v.isShort);
  final list = pool.toList(growable: false);

  return cats
      .where((c) => c.enabled || list.any((v) => categoryMatchesVideo(c, v)))
      .toList(growable: false);
});

List<FeedVideo> _applyFilter(
  List<FeedVideo> videos,
  List<FilterCategory> enabled,
  bool includeShorts,
  Set<String> hidden,
) {
  var pool = videos.where((v) => !hidden.contains(v.videoId)).toList();
  if (!includeShorts) {
    pool = pool.where((v) => !v.isShort).toList();
  }
  if (enabled.isEmpty) return pool;

  final catIds = <String>{};
  final topics = <String>{};
  final keywords = <String>[];
  for (final c in enabled) {
    catIds.addAll(c.youtubeCategoryIds);
    topics.addAll(c.topics);
    keywords.addAll(c.keywords.map((k) => k.toLowerCase()));
  }

  return pool.where((v) {
    if (catIds.contains(v.categoryId)) return true;
    if (topics.isNotEmpty && v.topics.any(topics.contains)) return true;
    if (keywords.isEmpty) return false;
    final title = v.title.toLowerCase();
    return keywords.any(title.contains);
  }).toList();
}
