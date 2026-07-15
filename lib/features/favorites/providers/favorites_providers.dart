import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../feed/models/feed_video.dart';
import '../models/saved_video.dart';
import '../services/favorites_service.dart';

final favoritesServiceProvider = Provider<FavoritesService>(
  (ref) => FavoritesService(ref.watch(localStorageProvider)),
);

/// The user's favorited videos, pinned first then newest first.
final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, List<SavedVideo>>(
  (ref) => FavoritesNotifier(ref.watch(favoritesServiceProvider)),
);

/// Just the favorited ids — cheap lookup for the star toggle on cards.
final favoriteIdsProvider = Provider<Set<String>>(
  (ref) => ref.watch(favoritesProvider).map((e) => e.videoId).toSet(),
);

class FavoritesNotifier extends StateNotifier<List<SavedVideo>> {
  FavoritesNotifier(this._svc) : super(const []) {
    _init();
  }

  final FavoritesService _svc;

  Future<void> _init() async {
    state = _sorted(_svc.loadLocal());
    if (SupabaseService.isSignedIn) {
      try {
        final remote = await _svc.pull();
        if (remote != null) {
          state = _sorted(remote);
          await _svc.saveLocal(state);
        }
      } catch (_) {
        // keep local on sync failure
      }
    }
  }

  bool isFavorite(String videoId) => state.any((e) => e.videoId == videoId);

  Future<void> add(SavedVideo v) async {
    if (isFavorite(v.videoId)) return;
    state = _sorted([...state, v]);
    await _svc.saveLocal(state);
    try {
      await _svc.save(v);
    } catch (_) {}
  }

  Future<void> addFromFeed(FeedVideo v) => add(SavedVideo.fromFeedVideo(v));

  Future<void> remove(String videoId) async {
    state = state.where((e) => e.videoId != videoId).toList();
    await _svc.saveLocal(state);
    try {
      await _svc.remove(videoId);
    } catch (_) {}
  }

  Future<void> toggle(SavedVideo v) =>
      isFavorite(v.videoId) ? remove(v.videoId) : add(v);

  Future<void> togglePin(String videoId) async {
    SavedVideo? target;
    for (final e in state) {
      if (e.videoId == videoId) {
        target = e;
        break;
      }
    }
    if (target == null) return;
    final next = target.copyWith(pinned: !target.pinned);
    state = _sorted([
      for (final e in state) if (e.videoId == videoId) next else e,
    ]);
    await _svc.saveLocal(state);
    try {
      await _svc.setPinned(videoId, next.pinned);
    } catch (_) {}
  }

  /// Remove every favorite (server rows + local cache).
  Future<void> clearAll() async {
    state = const [];
    await _svc.clearAll();
  }

  List<SavedVideo> _sorted(List<SavedVideo> items) {
    final copy = [...items]..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    return copy;
  }
}
