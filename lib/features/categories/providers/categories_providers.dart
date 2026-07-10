import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/supabase/supabase_service.dart';
import '../data/category_presets.dart';
import '../models/filter_category.dart';
import '../services/categories_service.dart';

final categoriesServiceProvider = Provider<CategoriesService>(
  (ref) => CategoriesService(ref.watch(localStorageProvider)),
);

class CategoriesState {
  const CategoriesState({
    this.items = const [],
    this.loading = false,
    this.syncError,
  });

  final List<FilterCategory> items;
  final bool loading;
  final String? syncError;

  List<FilterCategory> get enabled =>
      items.where((c) => c.enabled).toList(growable: false);

  CategoriesState copyWith({
    List<FilterCategory>? items,
    bool? loading,
    Object? syncError = _sentinel,
  }) {
    return CategoriesState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      syncError:
          syncError == _sentinel ? this.syncError : syncError as String?,
    );
  }

  static const _sentinel = Object();
}

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, CategoriesState>(
  (ref) => CategoriesNotifier(ref.watch(categoriesServiceProvider)),
);

class CategoriesNotifier extends StateNotifier<CategoriesState> {
  CategoriesNotifier(this._svc)
      : super(const CategoriesState(loading: true)) {
    _init();
  }

  final CategoriesService _svc;

  Future<void> _init() async {
    final local = _svc.loadLocal();
    state = CategoriesState(items: _sorted(local), loading: false);

    if (SupabaseService.isSignedIn) {
      await sync();
    } else if (local.isEmpty) {
      await _seedDefaults();
    }
    // One-time backfill: existing users (who only have the old coarse seeds)
    // automatically get the full fine-grained preset set on next launch.
    await _ensurePresets();
  }

  Future<void> _ensurePresets() async {
    if (_svc.presetsLoaded) return;
    await addPresets(); // adds any missing presets (disabled) and persists
    await _svc.markPresetsLoaded();
  }

  /// Pull-before-push: never overwrites the cloud with stale local data.
  Future<void> sync() async {
    try {
      final remote = await _svc.pull();
      if (remote == null) return; // signed out
      if (remote.isEmpty && state.items.isNotEmpty) {
        await _svc.push(state.items); // first upload of local/seed data
      } else if (remote.isEmpty && state.items.isEmpty) {
        await _seedDefaults(pushRemote: true);
      } else {
        state = state.copyWith(items: _sorted(remote), syncError: null);
        await _svc.saveLocal(remote);
      }
    } catch (e) {
      state = state.copyWith(syncError: e.toString());
    }
  }

  Future<void> add({
    required String name,
    required int color,
    required List<String> youtubeCategoryIds,
    required List<String> keywords,
    List<String> topics = const [],
  }) async {
    final now = DateTime.now();
    final item = FilterCategory(
      id: '${now.microsecondsSinceEpoch}',
      name: name,
      color: color,
      youtubeCategoryIds: youtubeCategoryIds,
      keywords: keywords,
      topics: topics,
      enabled: true,
      order: state.items.length,
      createdAt: now,
      updatedAt: now,
    );
    state = state.copyWith(items: _sorted([...state.items, item]));
    await _persist();
  }

  Future<void> update(FilterCategory updated) async {
    final next = state.items
        .map((c) => c.id == updated.id
            ? updated.copyWith(updatedAt: DateTime.now())
            : c)
        .toList();
    state = state.copyWith(items: _sorted(next));
    await _persist();
  }

  Future<void> toggle(String id) async {
    final target = state.items.firstWhere((c) => c.id == id);
    await update(target.copyWith(enabled: !target.enabled));
  }

  /// Turn every category off → the feed shows everything ("전체").
  Future<void> disableAll() async {
    final now = DateTime.now();
    state = state.copyWith(
      items: state.items
          .map((c) => c.enabled ? c.copyWith(enabled: false, updatedAt: now) : c)
          .toList(),
    );
    await _persist();
  }

  /// Bulk-add the curated fine-grained presets that aren't present yet (matched
  /// by name). Added disabled so they don't suddenly re-filter the feed — the
  /// user toggles on the ones they want. Returns how many were added.
  Future<int> addPresets() async {
    final existingNames = state.items.map((c) => c.name).toSet();
    final now = DateTime.now();
    var order = state.items.length;
    final additions = <FilterCategory>[];
    for (final p in kCategoryPresets) {
      if (existingNames.contains(p.name)) continue;
      additions.add(FilterCategory(
        id: '${now.microsecondsSinceEpoch + order}',
        name: p.name,
        color: p.color,
        youtubeCategoryIds: const [],
        keywords: p.keywords,
        topics: p.topics,
        enabled: false,
        order: order++,
        createdAt: now,
        updatedAt: now,
      ));
    }
    if (additions.isEmpty) return 0;
    state = state.copyWith(items: _sorted([...state.items, ...additions]));
    await _persist();
    return additions.length;
  }

  Future<void> remove(String id) async {
    state = state.copyWith(
      items: state.items.where((c) => c.id != id).toList(),
    );
    await _persist();
  }

  Future<void> _persist() async {
    await _svc.saveLocal(state.items);
    try {
      await _svc.push(state.items);
      state = state.copyWith(syncError: null);
    } catch (e) {
      state = state.copyWith(syncError: e.toString());
    }
  }

  Future<void> _seedDefaults({bool pushRemote = false}) async {
    final now = DateTime.now();
    // Seed the full fine-grained preset set (disabled), so a new user opens the
    // app to a rich, granular category list and just toggles what they want.
    var order = 0;
    final seeded = [
      for (final p in kCategoryPresets)
        FilterCategory(
          id: '${now.microsecondsSinceEpoch + order}',
          name: p.name,
          color: p.color,
          youtubeCategoryIds: const [],
          keywords: p.keywords,
          topics: p.topics,
          enabled: false,
          order: order++,
          createdAt: now,
          updatedAt: now,
        ),
    ];
    state = state.copyWith(items: seeded);
    await _svc.saveLocal(seeded);
    if (pushRemote) await _svc.push(seeded);
  }

  List<FilterCategory> _sorted(List<FilterCategory> items) {
    final copy = [...items]..sort((a, b) => a.order.compareTo(b.order));
    return copy;
  }
}
