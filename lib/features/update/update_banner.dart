import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'update_providers.dart';
import 'update_reload.dart';
import 'update_settings_providers.dart';

/// Shows a dismissible banner when a newer build is deployed AND auto-update
/// is off (when auto is on, [AutoUpdater] reloads instead of prompting).
class UpdateBanner extends ConsumerStatefulWidget {
  const UpdateBanner({super.key});

  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(updateInfoProvider);
    final autoOn = ref.watch(autoUpdateProvider);
    return info.maybeWhen(
      data: (u) {
        if (!u.updateAvailable || _dismissed || autoOn) {
          return const SizedBox.shrink();
        }
        return MaterialBanner(
          content: const Text('새 버전이 배포되었습니다.'),
          leading: const Icon(Icons.system_update),
          actions: [
            TextButton(
              onPressed: () => setState(() => _dismissed = true),
              child: const Text('나중에'),
            ),
            FilledButton(
              onPressed: reloadApp,
              child: const Text('지금 업데이트'),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
