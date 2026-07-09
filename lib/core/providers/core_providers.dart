import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_storage.dart';

/// Overridden in `main()` with the resolved [LocalStorage] instance.
final localStorageProvider = Provider<LocalStorage>((ref) {
  throw UnimplementedError(
    'localStorageProvider must be overridden in main() via ProviderScope',
  );
});
