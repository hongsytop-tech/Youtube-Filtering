import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/storage/local_storage.dart';

/// The fine topics currently used to filter the feed. Empty = show everything.
/// Persisted locally so the selection survives restarts.
final selectedTopicsProvider =
    StateNotifierProvider<SelectedTopicsNotifier, Set<String>>(
  (ref) => SelectedTopicsNotifier(ref.watch(localStorageProvider)),
);

class SelectedTopicsNotifier extends StateNotifier<Set<String>> {
  SelectedTopicsNotifier(this._store) : super(_load(_store));

  final LocalStorage _store;
  static const _key = 'selected_topics';

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

  void toggle(String topic) {
    final next = {...state};
    next.contains(topic) ? next.remove(topic) : next.add(topic);
    state = next;
    _persist();
  }

  /// Select all of [topics] if any is missing, otherwise clear them all.
  void toggleAll(Iterable<String> topics) {
    final next = {...state};
    if (topics.every(next.contains)) {
      next.removeAll(topics);
    } else {
      next.addAll(topics);
    }
    state = next;
    _persist();
  }

  void clear() {
    state = <String>{};
    _persist();
  }
}

/// Which macro group is expanded (its fine topics shown) in the feed bar.
/// Ephemeral UI state — not persisted.
final openGroupProvider = StateProvider<String?>((ref) => null);
