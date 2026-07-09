import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/storage/local_storage.dart';

/// Whether Shorts are shown in the feed. Defaults to OFF (excluded); persisted.
final includeShortsProvider =
    StateNotifierProvider<IncludeShortsNotifier, bool>((ref) {
  return IncludeShortsNotifier(ref.watch(localStorageProvider));
});

class IncludeShortsNotifier extends StateNotifier<bool> {
  IncludeShortsNotifier(this._store) : super(_store.getString(_key) == 'true');

  static const _key = 'include_shorts';
  final LocalStorage _store;

  void set(bool include) {
    state = include;
    _store.setString(_key, include ? 'true' : 'false');
  }
}
