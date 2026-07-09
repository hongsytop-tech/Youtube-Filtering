import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../feed/providers/feed_providers.dart';

const _firefoxPlayUrl =
    'https://play.google.com/store/apps/details?id=org.mozilla.firefox';
const _extensionZipUrl =
    'https://github.com/hongsytop-tech/Youtube-Filtering/releases/download/extension-latest/feedfilter-extension.zip';

/// In-app guide for setting up on-demand home-feed collection via the
/// Firefox extension. We cannot auto-install apps from a PWA, so this walks
/// the user through installing Firefox + the extension, and shows status.
class CollectGuide extends ConsumerWidget {
  const CollectGuide({super.key});

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    final count = feed.valueOrNull?.length;

    return ExpansionTile(
      leading: const Icon(Icons.download_for_offline),
      title: const Text('내 추천 피드 수집'),
      subtitle: Text(
        count == null ? '설정 방법 보기' : '수집된 영상 $count개',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '유튜브 홈 추천은 공식 API로 못 가져오기 때문에, '
            'Firefox 확장으로 내가 원할 때 홈 화면을 읽어 수집합니다. '
            '(읽기 전용·온디맨드)',
          ),
        ),
        const SizedBox(height: 12),
        _Step(
          n: 1,
          title: 'Firefox(안드로이드) 설치',
          child: OutlinedButton.icon(
            onPressed: () => _open(_firefoxPlayUrl),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Play 스토어에서 Firefox 설치'),
          ),
        ),
        _Step(
          n: 2,
          title: '확장 zip 내려받기',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('GitHub이 자동 빌드한 zip을 폰에서 바로 받습니다.'),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => _open(_extensionZipUrl),
                icon: const Icon(Icons.archive_outlined),
                label: const Text('확장 zip 다운로드'),
              ),
            ],
          ),
        ),
        const _Step(
          n: 3,
          title: '브라우저에 확장 로드',
          child: Text(
            'Firefox(또는 Kiwi 등)에 이 zip을 확장으로 로드합니다. '
            '자세한 순서는 저장소의 browser-extension/README.md 참고.',
          ),
        ),
        const _Step(
          n: 4,
          title: '수집하기',
          child: Text(
            '브라우저에서 youtube.com 홈을 열고 → 확장 아이콘 탭 → '
            'Supabase 설정 입력 + 앱 계정 로그인 → "홈 피드 수집". '
            '그다음 피드 탭 새로고침.',
          ),
        ),
        const SizedBox(height: 4),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '※ 앱이 다른 앱(Firefox/확장)을 자동 설치할 수는 없어, 링크·안내로 진행합니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.title, required this.child});
  final int n;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 12, child: Text('$n')),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
