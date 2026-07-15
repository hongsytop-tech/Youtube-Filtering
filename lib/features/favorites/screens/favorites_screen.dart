import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feed/models/feed_video.dart';
import '../../feed/providers/feed_providers.dart';
import '../../feed/widgets/video_card.dart';
import '../models/saved_video.dart';
import '../providers/favorites_providers.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Extract an 11-char YouTube video id from a URL or a bare id.
  String? _parseVideoId(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;
    final patterns = [
      RegExp(r'[?&]v=([0-9A-Za-z_-]{11})'),
      RegExp(r'youtu\.be/([0-9A-Za-z_-]{11})'),
      RegExp(r'/shorts/([0-9A-Za-z_-]{11})'),
      RegExp(r'/embed/([0-9A-Za-z_-]{11})'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(s);
      if (m != null) return m.group(1);
    }
    if (RegExp(r'^[0-9A-Za-z_-]{11}$').hasMatch(s)) return s;
    return null;
  }

  Future<void> _resetFavorites() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('즐겨찾기 초기화'),
        content: const Text(
          '즐겨찾기한 모든 영상을 삭제합니다. 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(favoritesProvider.notifier).clearAll();
      messenger.showSnackBar(
        const SnackBar(content: Text('즐겨찾기를 초기화했습니다.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('즐겨찾기'),
        actions: [
          if (favorites.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: '즐겨찾기 초기화',
              onPressed: _resetFavorites,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _controller,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: '제목 검색 또는 유튜브 링크 붙여넣기',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: _query.trim().isEmpty
                ? _FavoritesList(favorites: favorites)
                : _SearchResults(query: _query, parseVideoId: _parseVideoId),
          ),
        ],
      ),
    );
  }
}

class _FavoritesList extends StatelessWidget {
  const _FavoritesList({required this.favorites});

  final List<SavedVideo> favorites;

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            '즐겨찾기한 영상이 없습니다.\n'
            '피드에서 별(☆)을 누르거나, 위에서 제목·링크로 검색해 추가하세요.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final pinned = favorites.where((e) => e.pinned).toList();
    final others = favorites.where((e) => !e.pinned).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (pinned.isNotEmpty) const _SectionHeader('📌 고정됨'),
        for (final v in pinned) _favCard(v),
        if (pinned.isNotEmpty && others.isNotEmpty)
          const _SectionHeader('저장한 영상'),
        for (final v in others) _favCard(v),
      ],
    );
  }

  Widget _favCard(SavedVideo v) => Consumer(
        key: ValueKey(v.videoId),
        builder: (context, ref, _) => VideoCard(
          video: v.toFeedVideo(),
          pinned: v.pinned,
          onTogglePin: () =>
              ref.read(favoritesProvider.notifier).togglePin(v.videoId),
        ),
      );
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query, required this.parseVideoId});

  final String query;
  final String? Function(String) parseVideoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = query.trim().toLowerCase();
    final feed = ref.watch(feedProvider).asData?.value ?? const <FeedVideo>[];
    final id = parseVideoId(query);

    final results = <FeedVideo>[];
    final seen = <String>{};

    // A pasted link/id first — use feed metadata if we have it, else a stub.
    if (id != null) {
      final match = feed.where((v) => v.videoId == id).toList();
      results.add(match.isNotEmpty ? match.first : SavedVideo.fromId(id).toFeedVideo());
      seen.add(id);
    }
    // Then title matches from the collected feed.
    for (final v in feed) {
      if (seen.contains(v.videoId)) continue;
      if (v.title.toLowerCase().contains(q)) {
        results.add(v);
        seen.add(v.videoId);
        if (results.length >= 40) break;
      }
    }

    if (results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            '검색 결과가 없습니다.\n'
            '유튜브 링크를 붙여넣으면 그 영상을 바로 추가할 수 있어요.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: results.length,
      itemBuilder: (_, i) => VideoCard(video: results[i]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
