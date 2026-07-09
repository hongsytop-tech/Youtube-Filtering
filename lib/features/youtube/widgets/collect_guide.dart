import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../feed/providers/feed_providers.dart';

// Kiwi is discontinued/removed from Play. Use maintained alternatives.
const _cromiteUrl = 'https://www.cromite.org/';
const _lemurSearchUrl =
    'https://play.google.com/store/search?q=Lemur%20Browser&c=apps';
const _extensionZipUrl =
    'https://github.com/hongsytop-tech/Youtube-Filtering/releases/download/extension-latest/feedfilter-extension.zip';

Future<void> _open(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// Settings entry that opens the full collection setup guide.
class CollectGuide extends ConsumerWidget {
  const CollectGuide({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(feedProvider).valueOrNull?.length;
    return ListTile(
      leading: const Icon(Icons.download_for_offline),
      title: const Text('내 추천 피드 수집 설정'),
      subtitle: Text(count == null ? '설치·설정 안내' : '수집된 영상 $count개 · 설정 보기'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CollectGuideScreen()),
      ),
    );
  }
}

class CollectGuideScreen extends StatelessWidget {
  const CollectGuideScreen({super.key});

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('복사되었습니다')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('추천 피드 수집 설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '유튜브 홈 추천은 공식 API로 가져올 수 없어, 확장 프로그램으로 '
            '내가 원할 때 홈 화면을 읽어 수집합니다. (읽기 전용 · 온디맨드)',
          ),
          const SizedBox(height: 8),
          const _Note(
            '※ 앱이 브라우저·확장을 자동 설치할 수는 없어(안드로이드 보안), '
            '아래 링크로 한 번만 설치하면 됩니다.',
          ),
          const SizedBox(height: 16),

          _StepCard(
            n: 1,
            title: 'Lemur 브라우저 설치',
            children: [
              const Text('확장을 지원하는 브라우저가 필요합니다 '
                  '(크롬은 안드로이드에서 확장 미지원). Lemur가 가장 간단합니다.'),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _open(_lemurSearchUrl),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Play 스토어에서 Lemur Browser 설치'),
              ),
              TextButton(
                onPressed: () => _open(_cromiteUrl),
                child: const Text('또는 Cromite (APK, 고급)'),
              ),
              const SizedBox(height: 4),
              const _Note('Play 스토어 검색 결과에서 "Lemur Browser"를 설치하세요.'),
            ],
          ),

          _StepCard(
            n: 2,
            title: '확장 파일(zip) 다운로드',
            children: [
              const Text('GitHub이 자동 빌드한 확장 zip을 받습니다.'),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _open(_extensionZipUrl),
                icon: const Icon(Icons.archive_outlined),
                label: const Text('확장 zip 다운로드'),
              ),
            ],
          ),

          _StepCard(
            n: 3,
            title: '브라우저에 확장 로드',
            children: [
              const Text('1) 위 브라우저 주소창에 아래 주소를 입력해 확장 페이지 열기'),
              const SizedBox(height: 6),
              _CopyRow(
                text: 'chrome://extensions',
                onCopy: () => _copy(context, 'chrome://extensions'),
              ),
              const SizedBox(height: 8),
              const Text('2) 우측 상단 "개발자 모드" 켜기\n'
                  '3) "압축 파일 로드"(또는 +) → 받은 zip 선택\n'
                  '4) 확장이 목록에 추가되면 완료'),
              const SizedBox(height: 6),
              const _Note('Lemur는 메뉴(⋮) → Extensions 에서도 zip을 추가할 수 있습니다.'),
            ],
          ),

          _StepCard(
            n: 4,
            title: '유튜브 홈에서 수집',
            children: [
              const Text('1) 같은 브라우저에서 로그인된 상태로 youtube.com 홈 열기\n'
                  '2) 확장 아이콘 탭 → (최초 1회) 앱 계정으로 로그인\n'
                  '3) "홈 피드 수집" 탭 → 완료되면 이 앱 피드 탭 새로고침'),
              const SizedBox(height: 8),
              const _Note('반복해서 수집하면 영상이 누적됩니다(중복 자동 제거). '
                  '쇼츠는 마이 탭의 "쇼츠 포함" 스위치로 켜고/끌 수 있습니다.'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.n,
    required this.title,
    required this.children,
  });
  final int n;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 13, child: Text('$n')),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.text, required this.onCopy});
  final String text;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: '복사',
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}
