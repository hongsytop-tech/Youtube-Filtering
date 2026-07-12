import '../../../core/storage/local_storage.dart';
import '../../../core/supabase/supabase_service.dart';
import '../models/saved_video.dart';

/// Row-level persistence for favorited videos in `saved_videos` + a local
/// cache, mirroring VideoStatesService. Each user reads/writes only their rows.
class FavoritesService {
  FavoritesService(this._local);

  final LocalStorage _local;
  static const _key = 'saved_videos';
  static const _table = 'saved_videos';

  List<SavedVideo> loadLocal() =>
      _local.getJsonList(_key).map(SavedVideo.fromJson).toList();

  Future<void> saveLocal(List<SavedVideo> items) =>
      _local.setJsonList(_key, items.map((e) => e.toJson()).toList());

  /// Returns null when signed-out.
  Future<List<SavedVideo>?> pull() async {
    final user = SupabaseService.currentUser;
    if (user == null) return null;
    final rows = await SupabaseService.client
        .from(_table)
        .select()
        .eq('user_id', user.id);
    return (rows as List)
        .map((e) => SavedVideo.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> save(SavedVideo v) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    await SupabaseService.client
        .from(_table)
        .upsert(v.toRow(user.id), onConflict: 'user_id,video_id');
  }

  Future<void> remove(String videoId) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    await SupabaseService.client
        .from(_table)
        .delete()
        .eq('user_id', user.id)
        .eq('video_id', videoId);
  }

  Future<void> setPinned(String videoId, bool pinned) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    await SupabaseService.client
        .from(_table)
        .update({'pinned': pinned})
        .eq('user_id', user.id)
        .eq('video_id', videoId);
  }
}
