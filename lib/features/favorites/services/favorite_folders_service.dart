import '../../../core/storage/local_storage.dart';
import '../../../core/supabase/supabase_service.dart';
import '../models/favorite_folder.dart';

/// Blob persistence for the favorites folder list: local `List<String>` cache +
/// one Supabase row (`favorite_folders.data` jsonb array) per user.
class FavoriteFoldersService {
  FavoriteFoldersService(this._local);

  final LocalStorage _local;
  static const _key = 'favorite_folders';
  static const _table = 'favorite_folders';

  List<FavoriteFolder> loadLocal() =>
      _local.getJsonList(_key).map(FavoriteFolder.fromJson).toList();

  Future<void> saveLocal(List<FavoriteFolder> items) =>
      _local.setJsonList(_key, items.map((e) => e.toJson()).toList());

  /// Returns null when signed-out; empty when no row exists yet.
  Future<List<FavoriteFolder>?> pull() async {
    final user = SupabaseService.currentUser;
    if (user == null) return null;
    final row = await SupabaseService.client
        .from(_table)
        .select('data')
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) return <FavoriteFolder>[];
    final data = (row['data'] as List?) ?? const [];
    return data
        .whereType<Map>()
        .map((e) => FavoriteFolder.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> push(List<FavoriteFolder> items) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    await SupabaseService.client.from(_table).upsert(
      {
        'user_id': user.id,
        'data': items.map((e) => e.toJson()).toList(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id',
    );
  }
}
