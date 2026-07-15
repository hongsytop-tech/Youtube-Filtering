import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../categories/providers/categories_providers.dart';
import '../../insights/models/exclusions.dart';
import '../../insights/providers/exclusions_providers.dart';
import '../models/feed_video.dart';
import '../services/feed_service.dart';
import 'feed_prefs.dart';
import 'subscriptions_providers.dart';
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
    final selected = ref.watch(activeFilterTopicsProvider);
    final includeShorts = ref.watch(includeShortsProvider);
    final hidden = ref.watch(hiddenVideosProvider);
    final excl = ref.watch(exclusionsProvider);
    final source = ref.watch(feedSourceProvider);
    final subs = ref.watch(subscribedChannelsProvider).ids;
    return feed.whenData(
      (videos) => _applyFilter(
          videos, selected, includeShorts, hidden, excl, source, subs),
    );
  },
);

/// True if the video's channel is in the subscribed set.
bool _matchesSource(FeedVideo v, FeedSource source, Set<String> subs) {
  switch (source) {
    case FeedSource.subscribed:
      return subs.contains(v.channelId);
    case FeedSource.unsubscribed:
      return !subs.contains(v.channelId);
    case FeedSource.all:
      return true;
  }
}

/// The set of fine topics that still have at least one visible video in the
/// feed (respecting hidden + the shorts toggle). Used to hide empty groups /
/// topics from the selector — delete every video of a topic and it disappears.
final presentTopicsProvider = Provider.autoDispose<Set<String>>((ref) {
  final videos = ref.watch(feedProvider).asData?.value ?? const <FeedVideo>[];
  final includeShorts = ref.watch(includeShortsProvider);
  final hidden = ref.watch(hiddenVideosProvider);
  final excl = ref.watch(exclusionsProvider);
  final source = ref.watch(feedSourceProvider);
  final subs = ref.watch(subscribedChannelsProvider).ids;
  final out = <String>{};
  for (final v in videos) {
    if (hidden.contains(v.videoId)) continue;
    if (!includeShorts && v.isShort) continue;
    if (excl.matches(v)) continue;
    if (!_matchesSource(v, source, subs)) continue;
    out.addAll(v.topics);
  }
  return out;
});

List<FeedVideo> _applyFilter(
  List<FeedVideo> videos,
  Set<String> selected,
  bool includeShorts,
  Set<String> hidden,
  Exclusions excl,
  FeedSource source,
  Set<String> subs,
) {
  var pool = videos.where((v) => !hidden.contains(v.videoId)).toList();
  if (!includeShorts) {
    pool = pool.where((v) => !v.isShort).toList();
  }
  // Blacklist (channel / topic / keyword) always wins.
  pool = pool.where((v) => !excl.matches(v)).toList();
  // 구독 / 비구독 source split.
  pool = pool.where((v) => _matchesSource(v, source, subs)).toList();
  if (selected.isEmpty) return pool;
  return pool.where((v) => v.topics.any(selected.contains)).toList();
}
