import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../categories/providers/categories_providers.dart';
import '../providers/feed_prefs.dart';
import '../providers/feed_providers.dart';
import '../providers/video_states_providers.dart';
import '../widgets/video_card.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = ref.watch(filteredFeedProvider);
    final includeShorts = ref.watch(includeShortsProvider);
    final collecting = ref.watch(feedCollectingProvider);

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
              color:
                  includeShorts ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          IconButton(
            tooltip: '새로고침',
            onPressed: () => ref.invalidate(feedProvider),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '새 피드 수집 (구독 채널)',
            onPressed: collecting ? null : () => _collect(context, ref),
            icon: collecting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_for_offline),
          ),
        ],
      ),
      body: Column(
        children: [
          const _CategoryBar(),
          if (!SupabaseService.isSignedIn) const _DemoBanner(),
          Expanded(
            child: filtered.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(child: Text('피드를 불러오지 못했습니다.\n$e')),
                ],
              ),
              data: (videos) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(feedProvider),
                child: videos.isEmpty
                    ? ListView(
                        children: const [SizedBox(height: 80), _EmptyFeed()],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: videos.length,
                        itemBuilder: (context, i) {
                          final v = videos[i];
                          return VideoCard(
                            video: v,
                            onHide: () => _hide(context, ref, v.videoId),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _collect(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!SupabaseService.isSignedIn) {
      messenger.showSnackBar(
        const SnackBar(content: Text('먼저 마이 탭에서 로그인/YouTube 연결을 해주세요.')),
      );
      return;
    }
    ref.read(feedCollectingProvider.notifier).state = true;
    messenger.showSnackBar(
      const SnackBar(content: Text('구독 채널 최신 영상 수집 중…')),
    );
    try {
      final res = await SupabaseService.client.functions.invoke(
        'fetch-feed',
        body: const {},
      );
      final results = (res.data as Map?)?['results'] as Map?;
      final first = (results != null && results.isNotEmpty)
          ? results.values.first
          : null;
      // Assign fine-grained topic tags to the freshly-collected videos.
      try {
        await SupabaseService.client.functions.invoke('tag-feed');
      } catch (_) {/* best-effort; the shell retries on resume */}
      ref.invalidate(feedProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            first is int ? '구독 영상 $first개 수집 완료.' : '수집 완료. 피드를 갱신했습니다.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('수집 실패: $e')));
    } finally {
      ref.read(feedCollectingProvider.notifier).state = false;
    }
  }

  void _hide(BuildContext context, WidgetRef ref, String videoId) {
    ref.read(hiddenVideosProvider.notifier).hide(videoId);
    // Replace any pending/visible snackbar so deleting several videos in a row
    // doesn't queue them up — only the latest shows, for 3s from the last hide.
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: const Text('영상을 지웠습니다'),
        action: SnackBarAction(
          label: '실행취소',
          onPressed: () =>
              ref.read(hiddenVideosProvider.notifier).unhide(videoId),
        ),
      ),
    );
  }
}

/// Sticky, horizontally-scrollable category selector at the top of the feed.
class _CategoryBar extends ConsumerWidget {
  const _CategoryBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(visibleCategoriesProvider);
    final anyEnabled = ref.watch(categoriesProvider).items.any((c) => c.enabled);
    if (items.isEmpty && !anyEnabled) return const SizedBox.shrink();

    return Material(
      elevation: 1,
      child: SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: const Text('전체'),
                selected: !anyEnabled,
                onSelected: (_) =>
                    ref.read(categoriesProvider.notifier).disableAll(),
              ),
            ),
            ...items.map(
              (c) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: Text(c.name),
                  selected: c.enabled,
                  avatar: CircleAvatar(
                    backgroundColor: Color(c.color),
                    radius: 6,
                  ),
                  onSelected: (_) =>
                      ref.read(categoriesProvider.notifier).toggle(c.id),
                ),
              ),
            ),
          ],
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
          '선택한 카테고리에 해당하는 영상이 없습니다.\n상단 카테고리를 조정하거나 "전체"를 눌러보세요.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
