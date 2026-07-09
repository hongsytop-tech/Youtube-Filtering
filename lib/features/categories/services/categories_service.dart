import '../../../core/storage/local_storage.dart';
import '../../../core/supabase/supabase_service.dart';
import '../models/filter_category.dart';

/// Blob-style persistence: local `List<String>` cache + one Supabase row
/// (`filter_categories.data` jsonb array) per user.
class CategoriesService {
  CategoriesService(this._local);

  final LocalStorage _local;

  static const _key = 'filter_categories';
  static const _table = 'filter_categories';

  List<FilterCategory> loadLocal() =>
      _local.getJsonList(_key).map(FilterCategory.fromJson).toList();

  Future<void> saveLocal(List<FilterCategory> items) =>
      _local.setJsonList(_key, items.map((e) => e.toJson()).toList());

  /// Returns null when signed-out; empty list when the row doesn't exist yet.
  Future<List<FilterCategory>?> pull() async {
    final user = SupabaseService.currentUser;
    if (user == null) return null;
    final row = await SupabaseService.client
        .from(_table)
        .select('data')
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) return <FilterCategory>[];
    final data = (row['data'] as List?) ?? const [];
    return data
        .map((e) => FilterCategory.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> push(List<FilterCategory> items) async {
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
