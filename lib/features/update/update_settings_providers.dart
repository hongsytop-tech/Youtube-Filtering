import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/storage/local_storage.dart';

/// Whether new builds auto-reload. Defaults to ON; persisted locally.
final autoUpdateProvider =
    StateNotifierProvider<AutoUpdateNotifier, bool>((ref) {
  return AutoUpdateNotifier(ref.watch(localStorageProvider));
});

class AutoUpdateNotifier extends StateNotifier<bool> {
  AutoUpdateNotifier(this._store)
      : super(_store.getString(_key) != 'false');

  static const _key = 'auto_update_enabled';
  final LocalStorage _store;

  void set(bool enabled) {
    state = enabled;
    _store.setString(_key, enabled ? 'true' : 'false');
  }
}
