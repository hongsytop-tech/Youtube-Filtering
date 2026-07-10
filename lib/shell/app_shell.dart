import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/core_providers.dart';
import '../core/router/app_router.dart';
import '../core/supabase/supabase_service.dart';
import '../features/feed/providers/feed_providers.dart';
import '../features/update/auto_updater.dart';
import '../features/update/update_banner.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  DateTime? _lastRefresh;

  static const _tabs = <String>[
    Routes.feed,
    Routes.categories,
    Routes.channels,
    Routes.settings,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAutoReclassify();
      _maybeAutoTag();
    });
  }

  /// Ask the server to assign fine-grained topic tags to any untagged videos
  /// (Claude Haiku). Idempotent + throttled, so it's safe to call on launch and
  /// whenever the app is resumed. Refreshes the feed if anything was tagged.
  Future<void> _maybeAutoTag() async {
    if (!SupabaseService.isSignedIn) return;
    final store = ref.read(localStorageProvider);
    final last = DateTime.tryParse(store.getString('last_auto_tag') ?? '');
    if (last != null && DateTime.now().difference(last).inMinutes < 10) return;
    await store.setString('last_auto_tag', DateTime.now().toIso8601String());
    try {
      var anyTagged = false;
      // Drain the backlog: keep going while the server says more rows remain
      // (e.g. after a classifier-version bump re-tags everything). Capped so a
      // runaway can't loop forever.
      for (var i = 0; i < 8; i++) {
        final res = await SupabaseService.client.functions.invoke('tag-feed');
        final data = res.data as Map?;
        if ((data?['tagged'] as int? ?? 0) > 0) anyTagged = true;
        if (data?['more'] != true) break;
      }
      if (mounted && anyTagged) ref.invalidate(feedProvider);
    } catch (_) {
      // best-effort; will retry on the next launch/resume
    }
  }

  /// Silently re-classify Shorts / backfill durations once a day, so the user
  /// never has to press the manual button. Cheap after the first cleanup.
  Future<void> _maybeAutoReclassify() async {
    if (!SupabaseService.isSignedIn) return;
    final store = ref.read(localStorageProvider);
    final last = DateTime.tryParse(store.getString('last_auto_reclassify') ?? '');
    if (last != null && DateTime.now().difference(last).inHours < 24) return;
    await store.setString(
      'last_auto_reclassify',
      DateTime.now().toIso8601String(),
    );
    try {
      await SupabaseService.client.functions.invoke(
        'ingest-feed',
        body: {'reclassify': true},
      );
      if (mounted) ref.invalidate(feedProvider);
    } catch (_) {
      // best-effort; extension already classifies new collections
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-pull the feed when returning to the app (e.g. after collecting in
  /// another tab/browser). Throttled so it doesn't refetch on every focus.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final now = DateTime.now();
    if (_lastRefresh != null &&
        now.difference(_lastRefresh!).inSeconds < 10) {
      return;
    }
    _lastRefresh = now;
    ref.invalidate(feedProvider);
    _maybeAutoTag();
  }

  int _indexFor(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _indexFor(location);

    return Scaffold(
      body: Column(
        children: [
          const AutoUpdater(),
          const UpdateBanner(),
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed),
            label: '피드',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: '카테고리',
          ),
          NavigationDestination(
            icon: Icon(Icons.subscriptions_outlined),
            selectedIcon: Icon(Icons.subscriptions),
            label: '채널',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '마이',
          ),
        ],
      ),
    );
  }
}
