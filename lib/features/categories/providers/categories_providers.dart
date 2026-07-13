import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/utils/feed_topics.dart';
import '../models/filter_group.dart';
import '../services/category_tree_service.dart';

final categoryTreeServiceProvider = Provider<CategoryTreeService>(
  (ref) => CategoryTreeService(ref.watch(localStorageProvider)),
);

/// The user's 2-level category tree (대분류 → 소분류), local-first + synced.
final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, List<FilterGroup>>(
  (ref) => CategoriesNotifier(ref.watch(categoryTreeServiceProvider)),
);

const _groupColors = <int>[
  0xFF3B82F6, 0xFFEF4444, 0xFF8B5CF6, 0xFF10B981, 0xFFF59E0B, 0xFFEC4899,
  0xFF06B6D4, 0xFF64748B, 0xFF14B8A6, 0xFF71717A, 0xFFF97316, 0xFF6366F1,
  0xFFA855F7,
];

class CategoriesNotifier extends StateNotifier<List<FilterGroup>> {
  CategoriesNotifier(this._svc) : super(const []) {
    _init();
  }

  final CategoryTreeService _svc;

  Future<void> _init() async {
    state = _sorted(_svc.loadLocal());
    if (SupabaseService.isSignedIn) {
      await sync();
    } else if (state.isEmpty) {
      await _seed();
    }
  }

  Future<void> sync() async {
    try {
      final remote = await _svc.pull();
      if (remote == null) return;
      if (remote.isEmpty && state.isNotEmpty) {
        await _svc.push(state);
      } else if (remote.isEmpty && state.isEmpty) {
        await _seed(push: true);
      } else {
        state = _sorted(remote);
        await _svc.saveLocal(state);
      }
    } catch (_) {/* keep local on failure */}
  }

  String _id() => '${DateTime.now().microsecondsSinceEpoch}_${state.length}';

  // ---- group ops ----
  Future<void> addGroup(String name, int color) async {
    final g = FilterGroup(
      id: _id(),
      name: name,
      color: color,
      exposed: true,
      order: state.length,
    );
    state = _sorted([...state, g]);
    await _persist();
  }

  Future<void> updateGroup(FilterGroup g) async {
    state = _sorted([for (final x in state) x.id == g.id ? g : x]);
    await _persist();
  }

  Future<void> removeGroup(String id) async {
    state = state.where((g) => g.id != id).toList();
    await _persist();
  }

  Future<void> toggleGroupExposed(String id) async {
    final g = state.firstWhere((g) => g.id == id);
    await updateGroup(g.copyWith(exposed: !g.exposed));
  }

  // ---- subcategory ops ----
  Future<void> addSubcat(
    String groupId,
    String name,
    List<String> topics,
  ) async {
    final g = state.firstWhere((g) => g.id == groupId);
    final sub = FilterSubcategory(
      id: _id(),
      name: name,
      topics: topics,
      exposed: true,
      order: g.subcats.length,
    );
    await updateGroup(g.copyWith(subcats: [...g.subcats, sub]));
  }

  Future<void> updateSubcat(String groupId, FilterSubcategory sub) async {
    final g = state.firstWhere((g) => g.id == groupId);
    await updateGroup(g.copyWith(
      subcats: [for (final s in g.subcats) s.id == sub.id ? sub : s],
    ));
  }

  Future<void> removeSubcat(String groupId, String subId) async {
    final g = state.firstWhere((g) => g.id == groupId);
    await updateGroup(
        g.copyWith(subcats: g.subcats.where((s) => s.id != subId).toList()));
  }

  Future<void> toggleSubcatExposed(String groupId, String subId) async {
    final g = state.firstWhere((g) => g.id == groupId);
    final s = g.subcats.firstWhere((s) => s.id == subId);
    await updateSubcat(groupId, s.copyWith(exposed: !s.exposed));
  }

  /// Re-seed from the taxonomy (used for "기본값 불러오기" / first run).
  Future<void> resetToDefaults() => _seed(push: SupabaseService.isSignedIn);

  Future<void> _seed({bool push = false}) async {
    final groups = FeedTopics.groups.entries.toList();
    final now = DateTime.now().microsecondsSinceEpoch;
    final seeded = <FilterGroup>[
      for (var gi = 0; gi < groups.length; gi++)
        FilterGroup(
          id: 'g${now}_$gi',
          name: groups[gi].key,
          color: _groupColors[gi % _groupColors.length],
          exposed: true,
          order: gi,
          subcats: [
            for (var si = 0; si < groups[gi].value.length; si++)
              FilterSubcategory(
                id: 's${now}_${gi}_$si',
                name: groups[gi].value[si],
                topics: [groups[gi].value[si]],
                exposed: true,
                order: si,
              ),
          ],
        ),
    ];
    state = seeded;
    await _svc.saveLocal(seeded);
    if (push) await _svc.push(seeded);
  }

  Future<void> _persist() async {
    await _svc.saveLocal(state);
    try {
      await _svc.push(state);
    } catch (_) {}
  }

  List<FilterGroup> _sorted(List<FilterGroup> items) {
    final copy = [
      for (final g in items)
        g.copyWith(
          subcats: [...g.subcats]..sort((a, b) => a.order.compareTo(b.order)),
        ),
    ]..sort((a, b) => a.order.compareTo(b.order));
    return copy;
  }
}

/// Which subcategories are active filters (by id). Empty = show everything.
/// Persisted locally.
final selectedSubcatsProvider =
    StateNotifierProvider<SelectedSubcatsNotifier, Set<String>>(
  (ref) => SelectedSubcatsNotifier(ref.watch(localStorageProvider)),
);

class SelectedSubcatsNotifier extends StateNotifier<Set<String>> {
  SelectedSubcatsNotifier(this._store) : super(_load(_store));

  final LocalStorage _store;
  static const _key = 'selected_subcats';

  static Set<String> _load(LocalStorage s) {
    final raw = s.getString(_key);
    if (raw == null) return <String>{};
    try {
      return (jsonDecode(raw) as List).map((e) => '$e').toSet();
    } catch (_) {
      return <String>{};
    }
  }

  void _persist() => _store.setString(_key, jsonEncode(state.toList()));

  void toggle(String id) {
    final next = {...state};
    next.contains(id) ? next.remove(id) : next.add(id);
    state = next;
    _persist();
  }

  void setMany(Iterable<String> ids, bool selected) {
    final next = {...state};
    selected ? next.addAll(ids) : next.removeAll(ids);
    state = next;
    _persist();
  }

  void clear() {
    state = <String>{};
    _persist();
  }
}

/// The union of fine topics from all selected subcategories — the feed filter.
final activeFilterTopicsProvider = Provider<Set<String>>((ref) {
  final tree = ref.watch(categoriesProvider);
  final selected = ref.watch(selectedSubcatsProvider);
  if (selected.isEmpty) return const {};
  final out = <String>{};
  for (final g in tree) {
    for (final s in g.subcats) {
      if (selected.contains(s.id)) out.addAll(s.topics);
    }
  }
  return out;
});

/// Which group's sub-row is expanded in the feed bar (ephemeral UI state).
final openGroupProvider = StateProvider<String?>((ref) => null);
