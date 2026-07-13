import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/supabase/supabase_service.dart';
import '../models/exclusions.dart';
import '../services/exclusions_service.dart';

final exclusionsServiceProvider = Provider<ExclusionsService>(
  (ref) => ExclusionsService(ref.watch(localStorageProvider)),
);

/// The user's feed blacklist (channels / topics / keywords), synced.
final exclusionsProvider =
    StateNotifierProvider<ExclusionsNotifier, Exclusions>(
  (ref) => ExclusionsNotifier(ref.watch(exclusionsServiceProvider)),
);

class ExclusionsNotifier extends StateNotifier<Exclusions> {
  ExclusionsNotifier(this._svc) : super(const Exclusions()) {
    _init();
  }

  final ExclusionsService _svc;

  Future<void> _init() async {
    state = _svc.loadLocal();
    if (SupabaseService.isSignedIn) {
      try {
        final remote = await _svc.pull();
        if (remote != null && !remote.isEmpty) {
          state = remote;
          await _svc.saveLocal(state);
        } else if (remote != null && remote.isEmpty && !state.isEmpty) {
          await _svc.push(state);
        }
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    await _svc.saveLocal(state);
    try {
      await _svc.push(state);
    } catch (_) {}
  }

  Future<void> excludeChannel(String channelTitle) async {
    state = state.copyWith(channels: {...state.channels, channelTitle});
    await _persist();
  }

  Future<void> excludeTopic(String topic) async {
    state = state.copyWith(topics: {...state.topics, topic});
    await _persist();
  }

  Future<void> excludeKeyword(String keyword) async {
    final k = keyword.trim().toLowerCase();
    if (k.isEmpty) return;
    state = state.copyWith(keywords: {...state.keywords, k});
    await _persist();
  }

  Future<void> removeChannel(String c) async {
    state = state.copyWith(channels: {...state.channels}..remove(c));
    await _persist();
  }

  Future<void> removeTopic(String t) async {
    state = state.copyWith(topics: {...state.topics}..remove(t));
    await _persist();
  }

  Future<void> removeKeyword(String k) async {
    state = state.copyWith(keywords: {...state.keywords}..remove(k));
    await _persist();
  }
}
