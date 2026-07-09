import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/supabase/supabase_service.dart';
import '../services/video_states_service.dart';

final videoStatesServiceProvider = Provider<VideoStatesService>(
  (ref) => VideoStatesService(ref.watch(localStorageProvider)),
);

/// Set of hidden ("삭제") video ids. Local-first + Supabase-synced so hidden
/// videos never resurface, even after a new collection.
final hiddenVideosProvider =
    StateNotifierProvider<HiddenVideosNotifier, Set<String>>(
  (ref) => HiddenVideosNotifier(ref.watch(videoStatesServiceProvider)),
);

class HiddenVideosNotifier extends StateNotifier<Set<String>> {
  HiddenVideosNotifier(this._svc) : super(<String>{}) {
    _init();
  }

  final VideoStatesService _svc;

  Future<void> _init() async {
    state = _svc.loadLocal();
    if (SupabaseService.isSignedIn) {
      try {
        final remote = await _svc.pull();
        if (remote != null) {
          state = {...state, ...remote};
          await _svc.saveLocal(state);
        }
      } catch (_) {
        // keep local set on sync failure
      }
    }
  }

  Future<void> hide(String videoId) async {
    state = {...state, videoId};
    await _svc.saveLocal(state);
    try {
      await _svc.hide(videoId);
    } catch (_) {}
  }

  Future<void> unhide(String videoId) async {
    state = {...state}..remove(videoId);
    await _svc.saveLocal(state);
    try {
      await _svc.unhide(videoId);
    } catch (_) {}
  }
}
