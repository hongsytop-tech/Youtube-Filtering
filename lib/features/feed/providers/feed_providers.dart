import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../categories/models/filter_category.dart';
import '../../categories/providers/categories_providers.dart';
import '../models/feed_video.dart';
import '../services/feed_service.dart';
import 'feed_prefs.dart';

final feedServiceProvider = Provider<FeedService>(
  (ref) => FeedService(ref.watch(localStorageProvider)),
);

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
    return feed.whenData(
      (videos) => _applyFilter(videos, enabled, includeShorts),
    );
  },
);

List<FeedVideo> _applyFilter(
  List<FeedVideo> videos,
  List<FilterCategory> enabled,
  bool includeShorts,
) {
  var pool = videos;
  if (!includeShorts) {
    pool = pool.where((v) => !v.isShort).toList();
  }
  if (enabled.isEmpty) return pool;

  final catIds = <String>{};
  final keywords = <String>[];
  for (final c in enabled) {
    catIds.addAll(c.youtubeCategoryIds);
    keywords.addAll(c.keywords.map((k) => k.toLowerCase()));
  }

  return pool.where((v) {
    if (catIds.contains(v.categoryId)) return true;
    if (keywords.isEmpty) return false;
    final title = v.title.toLowerCase();
    return keywords.any(title.contains);
  }).toList();
}
