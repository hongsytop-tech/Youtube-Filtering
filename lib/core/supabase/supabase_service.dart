import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Thin wrapper around the global Supabase client. All access is guarded so
/// callers never crash when the backend is unconfigured.
class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;

  static bool get isConfigured => Env.isSupabaseConfigured;
  static bool get isReady => _initialized;

  static Future<void> initialize() async {
    if (_initialized || !Env.isSupabaseConfigured) return;
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
    _initialized = true;
  }

  static SupabaseClient get client => Supabase.instance.client;

  static GoTrueClient get auth => Supabase.instance.client.auth;

  /// Null when the backend isn't ready or nobody is signed in.
  static User? get currentUser {
    if (!_initialized) return null;
    return Supabase.instance.client.auth.currentUser;
  }

  static bool get isSignedIn => currentUser != null;
}
