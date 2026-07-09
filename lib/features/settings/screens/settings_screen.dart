import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../../update/update_section.dart';
import '../../youtube/providers/youtube_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final yt = ref.watch(youtubeConnectProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('마이')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: Text(user?.email ?? '로그인되지 않음'),
            subtitle: Text(
              SupabaseService.isReady ? '백엔드 연결됨' : '오프라인(로컬) 모드',
            ),
          ),
          const Divider(),
          _YoutubeConnectTile(state: yt),
          const Divider(),
          if (SupabaseService.isSignedIn)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('로그아웃'),
              onTap: () => ref.read(authControllerProvider.notifier).signOut(),
            ),
          const Divider(),
          const UpdateSection(),
        ],
      ),
    );
  }
}

class _YoutubeConnectTile extends ConsumerWidget {
  const _YoutubeConnectTile({required this.state});

  final YoutubeConnectState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = SupabaseService.isSignedIn;
    final canConnect =
        signedIn && Env.isGoogleConfigured && !state.loading;

    String subtitle;
    if (!Env.isGoogleConfigured) {
      subtitle = 'GOOGLE_WEB_CLIENT_ID 미설정 (GitHub Secret 등록 필요)';
    } else if (!signedIn) {
      subtitle = '먼저 로그인해야 연결할 수 있습니다.';
    } else if (state.connected) {
      subtitle = state.message ?? '연결됨';
    } else {
      subtitle = '구글 계정을 연결해 구독 피드를 가져옵니다.';
    }

    return Column(
      children: [
        ListTile(
          leading: Icon(
            state.connected ? Icons.check_circle : Icons.link,
            color: state.connected
                ? Colors.green
                : Theme.of(context).colorScheme.primary,
          ),
          title: const Text('YouTube 연결'),
          subtitle: Text(subtitle),
          trailing: state.loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : FilledButton(
                  onPressed: canConnect
                      ? () =>
                          ref.read(youtubeConnectProvider.notifier).connect()
                      : null,
                  child: Text(state.connected ? '다시 연결' : '연결'),
                ),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}
