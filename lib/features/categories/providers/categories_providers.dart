import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/supabase/supabase_service.dart';
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
  }) async {
    final now = DateTime.now();
    final item = FilterCategory(
      id: '${now.microsecondsSinceEpoch}',
      name: name,
      color: color,
      youtubeCategoryIds: youtubeCategoryIds,
      keywords: keywords,
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
    FilterCategory make(String name, int color, List<String> ids, int order) =>
        FilterCategory(
          id: '${now.microsecondsSinceEpoch + order}',
          name: name,
          color: color,
          youtubeCategoryIds: ids,
          keywords: const [],
          enabled: true,
          order: order,
          createdAt: now,
          updatedAt: now,
        );
    final seeded = <FilterCategory>[
      make('교육/지식', 0xFF3B82F6, ['27', '28'], 0),
      make('음악', 0xFFEF4444, ['10'], 1),
      make('게임', 0xFF8B5CF6, ['20'], 2),
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
