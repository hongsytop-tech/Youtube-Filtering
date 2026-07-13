import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/storage/local_storage.dart';

/// Local cache of on-demand video summaries (videoId → summary text), so a
/// second tap is instant and free.
final summaryCacheProvider =
    StateNotifierProvider<SummaryCacheNotifier, Map<String, String>>(
  (ref) => SummaryCacheNotifier(ref.watch(localStorageProvider)),
);

class SummaryCacheNotifier extends StateNotifier<Map<String, String>> {
  SummaryCacheNotifier(this._store) : super(_load(_store));

  final LocalStorage _store;
  static const _key = 'video_summaries';

  static Map<String, String> _load(LocalStorage s) {
    final raw = s.getString(_key);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map)
          .map((k, v) => MapEntry('$k', '$v'));
    } catch (_) {
      return {};
    }
  }

  String? get(String id) => state[id];

  void put(String id, String summary) {
    state = {...state, id: summary};
    _store.setString(_key, jsonEncode(state));
  }
}
