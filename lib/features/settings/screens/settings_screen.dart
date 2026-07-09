import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../auth/providers/auth_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

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
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('YouTube 연결'),
            subtitle: Text(
              Env.isGoogleConfigured
                  ? '구글 계정을 연결해 실제 피드를 가져옵니다. (연동 단계에서 구현)'
                  : 'GOOGLE_WEB_CLIENT_ID 미설정',
            ),
            trailing: const Icon(Icons.chevron_right),
            enabled: false,
            onTap: null,
          ),
          const Divider(),
          if (SupabaseService.isSignedIn)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('로그아웃'),
              onTap: () => ref.read(authControllerProvider.notifier).signOut(),
            ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'build ${Env.buildId}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}
