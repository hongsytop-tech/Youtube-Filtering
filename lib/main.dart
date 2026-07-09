import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers/core_providers.dart';
import 'core/storage/local_storage.dart';
import 'core/supabase/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // best-effort .env load; app must still boot without it.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    dotenv.testLoad(fileInput: '');
  }

  // no-op when credentials are absent; never blocks boot.
  try {
    await SupabaseService.initialize();
  } catch (e, s) {
    debugPrint('Supabase init failed: $e\n$s');
  }

  final localStorage = await LocalStorage.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(localStorage),
      ],
      child: const YoutubeFilterApp(),
    ),
  );
}
