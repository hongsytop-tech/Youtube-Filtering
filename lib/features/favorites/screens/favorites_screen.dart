import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feed/models/feed_video.dart';
import '../../feed/providers/feed_providers.dart';
import '../../feed/widgets/video_card.dart';
import '../models/favorite_folder.dart';
import '../models/saved_video.dart';
import '../providers/favorites_providers.dart';
import '../providers/favorites_view_providers.dart';
import '../providers/folders_providers.dart';

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

  Future<void> _createFolder() async {
    final name = await _promptName(title: '폴더 만들기');
    if (name == null) return;
    final id = await ref.read(favoriteFoldersProvider.notifier).add(name);
    ref.read(selectedFolderProvider.notifier).state = id;
  }

  Future<String?> _promptName({required String title, String initial = ''}) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.pop(ctx, c.text),
          decoration: const InputDecoration(
            hintText: '폴더 이름',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);
    final searching = _query.trim().isNotEmpty;
    final view = ref.watch(favViewProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('즐겨찾기'),
        actions: [
          if (view == FavView.folder)
            IconButton(
              icon: const Icon(Icons.create_new_folder_outlined),
              tooltip: '폴더 만들기',
              onPressed: _createFolder,
            ),
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
          if (!searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: SegmentedButton<FavView>(
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(
                    value: FavView.folder,
                    icon: Icon(Icons.folder_outlined, size: 18),
                    label: Text('폴더별'),
                  ),
                  ButtonSegment(
                    value: FavView.topic,
                    icon: Icon(Icons.sell_outlined, size: 18),
                    label: Text('주제별'),
                  ),
                ],
                selected: {view},
                onSelectionChanged: (s) =>
                    ref.read(favViewProvider.notifier).state = s.first,
              ),
            ),
          if (!searching && view == FavView.folder)
            _FolderBar(
              favorites: favorites,
              onCreate: _createFolder,
              onRename: (f) async {
                final name =
                    await _promptName(title: '폴더 이름 변경', initial: f.name);
                if (name != null) {
                  await ref
                      .read(favoriteFoldersProvider.notifier)
                      .rename(f.id, name);
                }
              },
              onDelete: _deleteFolder,
            ),
          if (!searching && view == FavView.topic)
            _TopicChipBar(favorites: favorites),
          Expanded(
            child: searching
                ? _SearchResults(query: _query, parseVideoId: _parseVideoId)
                : view == FavView.folder
                    ? _FavoritesList(favorites: favorites)
                    : _TopicFavoritesList(favorites: favorites),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFolder(FavoriteFolder f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${f.name}" 폴더 삭제'),
        content: const Text(
          '폴더만 삭제되고, 안에 있던 영상은 미분류로 이동합니다. '
          '즐겨찾기 자체는 삭제되지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(favoritesProvider.notifier).clearFolderAssignments(f.id);
    await ref.read(favoriteFoldersProvider.notifier).remove(f.id);
    if (ref.read(selectedFolderProvider) == f.id) {
      ref.read(selectedFolderProvider.notifier).state = kUnfiledFolderId;
    }
  }
}

/// Horizontal folder selector. Each folder chip is also a drop target: drag a
/// video card onto it to file the video there. 전체 = all, 미분류 = unfiled.
class _FolderBar extends ConsumerWidget {
  const _FolderBar({
    required this.favorites,
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
  });

  final List<SavedVideo> favorites;
  final VoidCallback onCreate;
  final void Function(FavoriteFolder) onRename;
  final void Function(FavoriteFolder) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(favoriteFoldersProvider);
    final selected = ref.watch(selectedFolderProvider);

    final unfiled = favorites.where((v) => v.folderId == null).length;
    final countByFolder = <String, int>{};
    for (final v in favorites) {
      final fid = v.folderId;
      if (fid != null) countByFolder[fid] = (countByFolder[fid] ?? 0) + 1;
    }

    void select(String? id) =>
        ref.read(selectedFolderProvider.notifier).state = id;

    Future<void> assign(SavedVideo v, String? folderId) async {
      await ref.read(favoritesProvider.notifier).setFolder(v.videoId, folderId);
      if (!context.mounted) return;
      final where = folderId == null
          ? '미분류'
          : folders
              .firstWhere(
                (f) => f.id == folderId,
                orElse: () =>
                    const FavoriteFolder(id: '', name: '폴더', order: 0),
              )
              .name;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text('"$where"(으)로 이동했습니다'),
          ),
        );
    }

    return Material(
      elevation: 1,
      child: SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          children: [
            // 미분류 — dropping here unfiles a video (default view).
            _DropChip(
              label: '미분류',
              count: unfiled,
              selected: selected == kUnfiledFolderId,
              onSelected: () => select(kUnfiledFolderId),
              onAccept: (v) => assign(v, null),
            ),
            for (final f in folders)
              _DropChip(
                label: f.name,
                count: countByFolder[f.id] ?? 0,
                selected: selected == f.id,
                onSelected: () => select(f.id),
                onAccept: (v) => assign(v, f.id),
                onLongPress: () => _folderMenu(context, f),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('폴더'),
                onPressed: onCreate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _folderMenu(BuildContext context, FavoriteFolder f) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('이름 변경'),
              onTap: () {
                Navigator.pop(ctx);
                onRename(f);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: const Text('폴더 삭제'),
              onTap: () {
                Navigator.pop(ctx);
                onDelete(f);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A selectable folder chip that also accepts dropped videos.
class _DropChip extends StatelessWidget {
  const _DropChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
    required this.onAccept,
    this.onLongPress,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;
  final void Function(SavedVideo) onAccept;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DragTarget<SavedVideo>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (d) => onAccept(d.data),
        builder: (context, candidate, rejected) {
          final hot = candidate.isNotEmpty;
          return GestureDetector(
            onLongPress: onLongPress,
            child: FilterChip(
              label: Text('$label ($count)'),
              selected: selected,
              showCheckmark: false,
              backgroundColor: hot ? scheme.primary.withOpacity(0.22) : null,
              side: hot ? BorderSide(color: scheme.primary, width: 2) : null,
              onSelected: (_) => onSelected(),
            ),
          );
        },
      ),
    );
  }
}

class _FavoritesList extends ConsumerWidget {
  const _FavoritesList({required this.favorites});

  final List<SavedVideo> favorites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedFolderProvider);
    final folders = ref.watch(favoriteFoldersProvider);

    // No "전체" view. 미분류(default) shows unfiled videos; a folder selection
    // shows just that folder. Pinned videos are always surfaced at the top of
    // the 미분류 view, even when they live inside a folder.
    final unfiledView = selected == null || selected == kUnfiledFolderId;
    final List<SavedVideo> pinned;
    final List<SavedVideo> others;
    if (unfiledView) {
      pinned = favorites.where((e) => e.pinned).toList();
      others =
          favorites.where((e) => !e.pinned && e.folderId == null).toList();
    } else {
      final inFolder = favorites.where((e) => e.folderId == selected).toList();
      pinned = inFolder.where((e) => e.pinned).toList();
      others = inFolder.where((e) => !e.pinned).toList();
    }

    if (pinned.isEmpty && others.isEmpty) {
      final msg = unfiledView
          ? '미분류 영상이 없습니다.\n'
              '피드에서 별(☆)을 누르거나, 위에서 제목·링크로 검색해 추가하세요.'
          : '이 폴더에 영상이 없습니다.\n영상을 길게 눌러 이 폴더로 드래그하세요.';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(msg, textAlign: TextAlign.center),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (folders.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '카드를 길게 눌러 위의 폴더로 드래그하면 정리됩니다.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
          ),
        if (pinned.isNotEmpty) const _SectionHeader('📌 고정됨'),
        for (final v in pinned)
          _DraggableFavorite(key: ValueKey(v.videoId), video: v),
        if (pinned.isNotEmpty && others.isNotEmpty)
          const _SectionHeader('저장한 영상'),
        for (final v in others)
          _DraggableFavorite(key: ValueKey(v.videoId), video: v),
      ],
    );
  }
}

/// Horizontal topic selector for the 주제별 view. Topics come from the analysis
/// tags captured on each favorite (backfilled from the feed when possible).
class _TopicChipBar extends ConsumerWidget {
  const _TopicChipBar({required this.favorites});

  final List<SavedVideo> favorites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicCounts = ref.watch(favoriteTopicCountsProvider);
    final feedTopics = ref.watch(favoriteFeedTopicsProvider);
    final selected = ref.watch(selectedFavTopicProvider);
    final noTopic =
        favorites.where((v) => effectiveTopics(v, feedTopics).isEmpty).length;

    void select(String? t) =>
        ref.read(selectedFavTopicProvider.notifier).state = t;

    if (topicCounts.isEmpty && noTopic == 0) return const SizedBox.shrink();

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
                label: Text('전체 (${favorites.length})'),
                selected: selected == null,
                showCheckmark: false,
                onSelected: (_) => select(null),
              ),
            ),
            for (final e in topicCounts)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: Text('${e.key} (${e.value})'),
                  selected: selected == e.key,
                  showCheckmark: false,
                  onSelected: (_) => select(e.key),
                ),
              ),
            if (noTopic > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: Text('주제 없음 ($noTopic)'),
                  selected: selected == kNoTopic,
                  showCheckmark: false,
                  onSelected: (_) => select(kNoTopic),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Favorites filtered by the selected topic (no drag — topics are automatic).
class _TopicFavoritesList extends ConsumerWidget {
  const _TopicFavoritesList({required this.favorites});

  final List<SavedVideo> favorites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedFavTopicProvider);
    final feedTopics = ref.watch(favoriteFeedTopicsProvider);

    final inView = favorites.where((v) {
      final ts = effectiveTopics(v, feedTopics);
      if (selected == null) return true;
      if (selected == kNoTopic) return ts.isEmpty;
      return ts.contains(selected);
    }).toList();

    if (inView.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            '이 주제의 즐겨찾기가 없습니다.\n'
            '주제는 분석(태그)이 끝난 영상에만 표시됩니다.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final pinned = inView.where((e) => e.pinned).toList();
    final others = inView.where((e) => !e.pinned).toList();

    Widget card(SavedVideo v) => VideoCard(
          key: ValueKey(v.videoId),
          video: v.toFeedVideo(),
          pinned: v.pinned,
          onTogglePin: () =>
              ref.read(favoritesProvider.notifier).togglePin(v.videoId),
        );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (pinned.isNotEmpty) const _SectionHeader('📌 고정됨'),
        for (final v in pinned) card(v),
        if (pinned.isNotEmpty && others.isNotEmpty)
          const _SectionHeader('저장한 영상'),
        for (final v in others) card(v),
      ],
    );
  }
}

/// A favorite card that can be long-pressed and dragged onto a folder chip.
class _DraggableFavorite extends ConsumerWidget {
  const _DraggableFavorite({super.key, required this.video});

  final SavedVideo video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = VideoCard(
      video: video.toFeedVideo(),
      pinned: video.pinned,
      onTogglePin: () =>
          ref.read(favoritesProvider.notifier).togglePin(video.videoId),
    );

    return LongPressDraggable<SavedVideo>(
      data: video,
      hapticFeedbackOnStart: true,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _DragFeedback(video: video),
      childWhenDragging: Opacity(opacity: 0.4, child: card),
      child: card,
    );
  }
}

/// Compact floating preview shown under the finger while dragging a favorite.
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.video});

  final SavedVideo video;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: scheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: video.thumbnailUrl,
                width: 64,
                height: 36,
                fit: BoxFit.cover,
                placeholder: (_, __) => const ColoredBox(color: Colors.black12),
                errorWidget: (_, __, ___) =>
                    const ColoredBox(color: Colors.black12),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            const Icon(Icons.drag_indicator, size: 18),
          ],
        ),
      ),
    );
  }
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
      results.add(
          match.isNotEmpty ? match.first : SavedVideo.fromId(id).toFeedVideo());
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
