import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/supabase/supabase_service.dart';
import '../models/favorite_folder.dart';
import '../services/favorite_folders_service.dart';

/// Sentinel folder selection for "미분류" (videos with no folder). A `null`
/// selection means "전체" (all favorites).
const kUnfiledFolderId = '__unfiled__';

final favoriteFoldersServiceProvider = Provider<FavoriteFoldersService>(
  (ref) => FavoriteFoldersService(ref.watch(localStorageProvider)),
);

/// The user's favorites folders (ordered).
final favoriteFoldersProvider =
    StateNotifierProvider<FavoriteFoldersNotifier, List<FavoriteFolder>>(
  (ref) => FavoriteFoldersNotifier(ref.watch(favoriteFoldersServiceProvider)),
);

/// Which folder is being viewed: null = 전체, kUnfiledFolderId = 미분류,
/// otherwise a folder id.
final selectedFolderProvider = StateProvider<String?>((ref) => null);

class FavoriteFoldersNotifier extends StateNotifier<List<FavoriteFolder>> {
  FavoriteFoldersNotifier(this._svc) : super(const []) {
    _init();
  }

  final FavoriteFoldersService _svc;

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

  List<FavoriteFolder> _sorted(List<FavoriteFolder> items) {
    final copy = [...items]..sort((a, b) => a.order.compareTo(b.order));
    return copy;
  }

  Future<void> _persist() async {
    await _svc.saveLocal(state);
    try {
      await _svc.push(state);
    } catch (_) {}
  }

  /// Create a folder and return its id. Uses a timestamp-based id so it's
  /// stable across devices without needing a server round-trip.
  Future<String> add(String name) async {
    final trimmed = name.trim();
    final id = 'f${DateTime.now().microsecondsSinceEpoch}';
    final next = FavoriteFolder(
      id: id,
      name: trimmed.isEmpty ? '새 폴더' : trimmed,
      order: state.length,
    );
    state = [...state, next];
    await _persist();
    return id;
  }

  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = [
      for (final f in state)
        if (f.id == id) f.copyWith(name: trimmed) else f,
    ];
    await _persist();
  }

  Future<void> remove(String id) async {
    state = [
      for (final f in state)
        if (f.id != id) f,
    ];
    // renumber order to stay compact
    state = [
      for (var i = 0; i < state.length; i++) state[i].copyWith(order: i),
    ];
    await _persist();
  }
}
