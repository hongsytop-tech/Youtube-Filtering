import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_service.dart';
import '../providers/feed_prefs.dart';
import '../providers/feed_providers.dart';
import '../widgets/video_card.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = ref.watch(filteredFeedProvider);
    final includeShorts = ref.watch(includeShortsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('피드'),
        actions: [
          IconButton(
            tooltip: includeShorts ? '쇼츠 포함 중' : '쇼츠 제외 중',
            onPressed: () =>
                ref.read(includeShortsProvider.notifier).set(!includeShorts),
            icon: Icon(
              includeShorts ? Icons.movie : Icons.movie_outlined,
              color: includeShorts
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
          IconButton(
            tooltip: '새로고침',
            onPressed: () => ref.invalidate(feedProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(feedProvider),
        child: filtered.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Center(child: Text('피드를 불러오지 못했습니다.\n$e')),
            ],
          ),
          data: (videos) {
            if (videos.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  _EmptyFeed(),
                ],
              );
            }
            return Column(
              children: [
                if (!SupabaseService.isSignedIn) const _DemoBanner(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: videos.length,
                    itemBuilder: (_, i) => VideoCard(video: videos[i]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.secondaryContainer,
      padding: const EdgeInsets.all(10),
      child: Text(
        '데모 데이터입니다. 마이 탭에서 YouTube를 연결하면 실제 피드가 표시됩니다.',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          '선택한 카테고리에 해당하는 영상이 없습니다.\n카테고리 탭에서 조건을 조정해 보세요.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
