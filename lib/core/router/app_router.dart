import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/categories/screens/categories_screen.dart';
import '../../features/channels/screens/channel_fetch_screen.dart';
import '../../features/favorites/screens/favorites_screen.dart';
import '../../features/feed/screens/feed_screen.dart';
import '../../features/insights/screens/insights_screen.dart';
import '../../features/ranking/screens/ranking_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../shell/app_shell.dart';
import '../supabase/supabase_service.dart';
import 'auth_refresh_notifier.dart';

class Routes {
  static const feed = '/feed';
  static const categories = '/categories';
  static const favorites = '/favorites';
  static const insights = '/insights';
  static const channels = '/channels';
  static const ranking = '/ranking';
  static const settings = '/settings';
  static const login = '/login';
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.feed,
    refreshListenable: refresh,
    redirect: (context, state) {
      // Backend off → app is fully usable offline; skip the auth gate.
      if (!SupabaseService.isReady) return null;

      final loggedIn = SupabaseService.isSignedIn;
      final loggingIn = state.matchedLocation == Routes.login;

      if (!loggedIn && !loggingIn) return Routes.login;
      if (loggedIn && loggingIn) return Routes.feed;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: Routes.feed,
            builder: (_, __) => const FeedScreen(),
          ),
          GoRoute(
            path: Routes.categories,
            builder: (_, __) => const CategoriesScreen(),
          ),
          GoRoute(
            path: Routes.favorites,
            builder: (_, __) => const FavoritesScreen(),
          ),
          GoRoute(
            path: Routes.insights,
            builder: (_, __) => const InsightsScreen(),
          ),
          GoRoute(
            path: Routes.channels,
            builder: (_, __) => const ChannelFetchScreen(),
          ),
          GoRoute(
            path: Routes.ranking,
            builder: (_, __) => const RankingScreen(),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
