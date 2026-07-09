import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'update_providers.dart';
import 'update_reload.dart';
import 'update_settings_providers.dart';

/// Invisible widget: when auto-update is enabled and a newer build is live,
/// reloads once per build (guarded via sessionStorage to avoid a loop).
class AutoUpdater extends ConsumerWidget {
  const AutoUpdater({super.key});

  static const _guardKey = 'auto_reloaded_build';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(autoUpdateProvider);
    final info = ref.watch(updateInfoProvider);

    info.whenData((u) {
      if (!enabled || !u.updateAvailable) return;
      if (sessionGet(_guardKey) == u.remoteBuild) return;
      sessionSet(_guardKey, u.remoteBuild);
      WidgetsBinding.instance.addPostFrameCallback((_) => reloadApp());
    });

    return const SizedBox.shrink();
  }
}
