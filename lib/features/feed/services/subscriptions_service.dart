import 'dart:convert';

import '../../../core/storage/local_storage.dart';
import '../../../core/supabase/supabase_service.dart';

/// Fetches + caches the set of channel ids the user is subscribed to, so the
/// feed can be split into 구독(subscribed) vs 비구독(recommended) videos.
class SubscriptionsService {
  SubscriptionsService(this._local);

  final LocalStorage _local;
  static const _idsKey = 'subscribed_channel_ids';
  static const _atKey = 'subscribed_channel_ids_at';

  Set<String> loadLocal() {
    final raw = _local.getString(_idsKey);
    if (raw == null) return <String>{};
    try {
      return (jsonDecode(raw) as List).map((e) => '$e').toSet();
    } catch (_) {
      return <String>{};
    }
  }

  DateTime? lastFetched() =>
      DateTime.tryParse(_local.getString(_atKey) ?? '');

  Future<void> _saveLocal(Set<String> ids) async {
    await _local.setString(_idsKey, jsonEncode(ids.toList()));
    await _local.setString(_atKey, DateTime.now().toIso8601String());
  }

  /// Pull the subscription channel ids from the edge function and cache them.
  /// Returns the fresh set. Throws on failure (caller keeps the cached set).
  Future<Set<String>> refresh() async {
    if (!SupabaseService.isSignedIn) return loadLocal();
    final res =
        await SupabaseService.client.functions.invoke('subscriptions');
    final data = res.data as Map?;
    final list = (data?['channelIds'] as List?) ?? const [];
    final ids = list.map((e) => '$e').toSet();
    await _saveLocal(ids);
    return ids;
  }
}
