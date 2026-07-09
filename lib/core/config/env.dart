import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Null-safe wrapper around dotenv. Never throws even if `.env` is missing,
/// so the app can boot in a degraded (backend-off) mode.
class Env {
  static String _get(String key) {
    try {
      return dotenv.env[key]?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  static String get supabaseUrl => _get('SUPABASE_URL');
  static String get supabaseAnonKey => _get('SUPABASE_ANON_KEY');
  static String get googleClientId => _get('GOOGLE_WEB_CLIENT_ID');

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get isGoogleConfigured => googleClientId.isNotEmpty;

  /// Injected at build time via `--dart-define=BUILD_ID=<sha>`.
  static const String buildId =
      String.fromEnvironment('BUILD_ID', defaultValue: 'dev');
}
