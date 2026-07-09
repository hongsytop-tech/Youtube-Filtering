import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'update_providers.dart';
import 'update_reload.dart';
import 'update_settings_providers.dart';

/// Settings section: auto-update toggle, current build, a manual
/// "check for updates" button, and a manual "update now" when stale.
class UpdateSection extends ConsumerWidget {
  const UpdateSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(updateInfoProvider);
    final autoOn = ref.watch(autoUpdateProvider);

    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.autorenew),
          title: const Text('자동 업데이트'),
          subtitle: const Text('새 버전이 있으면 자동으로 새로고침합니다.'),
          value: autoOn,
          onChanged: (v) => ref.read(autoUpdateProvider.notifier).set(v),
        ),
        ListTile(
          leading: const Icon(Icons.system_update),
          title: const Text('앱 버전'),
          subtitle: Text('build ${info.valueOrNull?.localBuild ?? '…'}'),
          trailing: info.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  onPressed: () => ref.invalidate(updateInfoProvider),
                  child: const Text('업데이트 확인'),
                ),
        ),
        info.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('업데이트 확인 실패. 잠시 후 다시 시도하세요.'),
            ),
          ),
          data: (u) {
            if (u.updateAvailable) {
              return Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.secondaryContainer,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '새 버전이 있습니다 (${u.remoteBuild.substring(0, u.remoteBuild.length < 8 ? u.remoteBuild.length : 8)}…)',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: reloadApp,
                      child: const Text('지금 업데이트'),
                    ),
                  ],
                ),
              );
            }
            return const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('최신 버전입니다.'),
              ),
            );
          },
        ),
      ],
    );
  }
}
