import 'dart:convert';

import '../../../core/storage/local_storage.dart';
import '../../../core/supabase/supabase_service.dart';

/// Persists which videos the user hid ("삭제"). Row-level in `video_states`
/// (status='hidden') + local cache, so hidden videos never resurface —
/// even after a new collection.
class VideoStatesService {
  VideoStatesService(this._local);

  final LocalStorage _local;
  static const _key = 'hidden_video_ids';
  static const _table = 'video_states';

  Set<String> loadLocal() {
    final raw = _local.getString(_key);
    if (raw == null) return <String>{};
    try {
      return (jsonDecode(raw) as List).map((e) => '$e').toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> saveLocal(Set<String> ids) =>
      _local.setString(_key, jsonEncode(ids.toList()));

  Future<Set<String>?> pull() async {
    final user = SupabaseService.currentUser;
    if (user == null) return null;
    final rows = await SupabaseService.client
        .from(_table)
        .select('video_id')
        .eq('user_id', user.id)
        .eq('status', 'hidden');
    return (rows as List).map((e) => '${e['video_id']}').toSet();
  }

  Future<void> hide(String videoId) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    await SupabaseService.client.from(_table).upsert(
      {
        'user_id': user.id,
        'video_id': videoId,
        'status': 'hidden',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,video_id',
    );
  }

  Future<void> unhide(String videoId) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    await SupabaseService.client
        .from(_table)
        .delete()
        .eq('user_id', user.id)
        .eq('video_id', videoId);
  }
}
