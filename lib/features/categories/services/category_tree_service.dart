import '../../../core/storage/local_storage.dart';
import '../../../core/supabase/supabase_service.dart';
import '../models/filter_group.dart';

/// Blob persistence for the 2-level category tree: local `List<String>` cache +
/// one Supabase row (`filter_categories.data` jsonb array of groups) per user.
class CategoryTreeService {
  CategoryTreeService(this._local);

  final LocalStorage _local;
  static const _key = 'category_tree';
  static const _table = 'filter_categories';

  List<FilterGroup> loadLocal() =>
      _local.getJsonList(_key).map(FilterGroup.fromJson).toList();

  Future<void> saveLocal(List<FilterGroup> items) =>
      _local.setJsonList(_key, items.map((e) => e.toJson()).toList());

  /// Returns null when signed-out; empty when no (usable) row exists yet.
  /// Legacy rows (flat categories, no `subcats`) are treated as empty so the
  /// new tree gets seeded fresh.
  Future<List<FilterGroup>?> pull() async {
    final user = SupabaseService.currentUser;
    if (user == null) return null;
    final row = await SupabaseService.client
        .from(_table)
        .select('data')
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) return <FilterGroup>[];
    final data = (row['data'] as List?) ?? const [];
    final usable = data.where((e) => e is Map && e.containsKey('subcats'));
    return usable
        .map((e) => FilterGroup.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> push(List<FilterGroup> items) async {
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
