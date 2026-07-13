import 'dart:convert';

import '../../../core/storage/local_storage.dart';
import '../../../core/supabase/supabase_service.dart';
import '../models/exclusions.dart';

/// Persists the feed blacklist: local cache + one Supabase row (reuses the
/// existing `channel_rules` blob table, storing an object).
class ExclusionsService {
  ExclusionsService(this._local);

  final LocalStorage _local;
  static const _key = 'feed_exclusions';
  static const _table = 'channel_rules';

  Exclusions loadLocal() {
    final raw = _local.getString(_key);
    if (raw == null) return const Exclusions();
    try {
      return Exclusions.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return const Exclusions();
    }
  }

  Future<void> saveLocal(Exclusions e) =>
      _local.setString(_key, jsonEncode(e.toJson()));

  Future<Exclusions?> pull() async {
    final user = SupabaseService.currentUser;
    if (user == null) return null;
    final row = await SupabaseService.client
        .from(_table)
        .select('data')
        .eq('user_id', user.id)
        .maybeSingle();
    final data = row?['data'];
    if (data is Map) {
      return Exclusions.fromJson(Map<String, dynamic>.from(data));
    }
    return const Exclusions(); // absent or legacy array → empty
  }

  Future<void> push(Exclusions e) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    await SupabaseService.client.from(_table).upsert(
      {
        'user_id': user.id,
        'data': e.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id',
    );
  }
}
