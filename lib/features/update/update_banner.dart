import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import 'update_providers.dart';

/// Shows a MaterialBanner when a newer build is deployed and reloads once
/// automatically (guarded by sessionStorage to avoid a reload loop).
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  static const _guardKey = 'auto_reloaded_for_build';

  void _reload() => web.window.location.reload();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(updateInfoProvider);
    return info.maybeWhen(
      data: (u) {
        if (!u.updateAvailable) return const SizedBox.shrink();

        // one automatic reload per new build
        final already = web.window.sessionStorage.getItem(_guardKey);
        if (already != u.remoteBuild) {
          web.window.sessionStorage.setItem(_guardKey, u.remoteBuild);
          WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
        }

        return MaterialBanner(
          content: const Text('새 버전이 배포되었습니다.'),
          actions: [
            TextButton(onPressed: _reload, child: const Text('업데이트')),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
