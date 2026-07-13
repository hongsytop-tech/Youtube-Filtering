import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../models/feed_video.dart';
import '../services/feed_service.dart';
import 'feed_prefs.dart';
import 'topic_filter.dart';
import 'video_states_providers.dart';

final feedServiceProvider = Provider<FeedService>(
  (ref) => FeedService(ref.watch(localStorageProvider)),
);

/// True while an in-app (server-side subscription) collection is running.
final feedCollectingProvider = StateProvider<bool>((ref) => false);

final feedProvider = FutureProvider.autoDispose<List<FeedVideo>>(
  (ref) => ref.watch(feedServiceProvider).fetch(),
);

/// The feed after applying the selected fine-topic filter.
/// If no topic is selected, everything shows.
final filteredFeedProvider = Provider.autoDispose<AsyncValue<List<FeedVideo>>>(
  (ref) {
    final feed = ref.watch(feedProvider);
    final selected = ref.watch(selectedTopicsProvider);
    final includeShorts = ref.watch(includeShortsProvider);
    final hidden = ref.watch(hiddenVideosProvider);
    return feed.whenData(
      (videos) => _applyFilter(videos, selected, includeShorts, hidden),
    );
  },
);

List<FeedVideo> _applyFilter(
  List<FeedVideo> videos,
  Set<String> selected,
  bool includeShorts,
  Set<String> hidden,
) {
  var pool = videos.where((v) => !hidden.contains(v.videoId)).toList();
  if (!includeShorts) {
    pool = pool.where((v) => !v.isShort).toList();
  }
  if (selected.isEmpty) return pool;
  return pool.where((v) => v.topics.any(selected.contains)).toList();
}
