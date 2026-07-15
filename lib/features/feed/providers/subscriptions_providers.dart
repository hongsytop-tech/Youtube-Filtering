import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/supabase/supabase_service.dart';
import '../services/subscriptions_service.dart';

final subscriptionsServiceProvider = Provider<SubscriptionsService>(
  (ref) => SubscriptionsService(ref.watch(localStorageProvider)),
);

/// Which feed source is shown: 전체 / 구독 / 비구독.
final feedSourceProvider = StateProvider<FeedSource>((ref) => FeedSource.all);

enum FeedSource { all, subscribed, unsubscribed }

class SubscriptionsState {
  const SubscriptionsState({
    this.ids = const <String>{},
    this.loading = false,
    this.loaded = false,
    this.error,
  });

  final Set<String> ids;
  final bool loading;
  final bool loaded; // a refresh has completed at least once this session
  final String? error;

  SubscriptionsState copyWith({
    Set<String>? ids,
    bool? loading,
    bool? loaded,
    Object? error = _sentinel,
  }) =>
      SubscriptionsState(
        ids: ids ?? this.ids,
        loading: loading ?? this.loading,
        loaded: loaded ?? this.loaded,
        error: identical(error, _sentinel) ? this.error : error as String?,
      );

  static const _sentinel = Object();
}

/// Subscribed channel ids (local-cached, refreshed from the edge function).
/// Auto-refreshes on first load when signed in and the cache is empty or stale.
final subscribedChannelsProvider =
    StateNotifierProvider<SubscriptionsNotifier, SubscriptionsState>(
  (ref) => SubscriptionsNotifier(ref.watch(subscriptionsServiceProvider)),
);

class SubscriptionsNotifier extends StateNotifier<SubscriptionsState> {
  SubscriptionsNotifier(this._svc) : super(const SubscriptionsState()) {
    _init();
  }

  final SubscriptionsService _svc;
  static const _staleAfter = Duration(days: 7);

  void _init() {
    state = state.copyWith(ids: _svc.loadLocal());
    if (!SupabaseService.isSignedIn) return;
    final at = _svc.lastFetched();
    final stale = at == null || DateTime.now().difference(at) > _staleAfter;
    if (state.ids.isEmpty || stale) refresh();
  }

  Future<void> refresh() async {
    if (state.loading || !SupabaseService.isSignedIn) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final ids = await _svc.refresh();
      state = state.copyWith(ids: ids, loading: false, loaded: true);
    } catch (e) {
      state = state.copyWith(loading: false, loaded: true, error: '$e');
    }
  }
}
