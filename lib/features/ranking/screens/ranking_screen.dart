import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../favorites/models/saved_video.dart';
import '../../favorites/providers/favorites_providers.dart';
import '../data/regions.dart';

String fmtCount(int n) {
  if (n >= 100000000) return '${(n / 100000000).toStringAsFixed(1)}억';
  if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}만';
  return '$n';
}

String fmtDur(int s) {
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  final ss = sec.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

Future<void> _open(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

class RankVideo {
  RankVideo(this.j);
  final Map<String, dynamic> j;
  String get videoId => '${j['videoId'] ?? ''}';
  String get title => '${j['title'] ?? ''}';
  String get channelTitle => '${j['channelTitle'] ?? ''}';
  String get categoryId => '${j['categoryId'] ?? ''}';
  String get thumbnailUrl => '${j['thumbnailUrl'] ?? ''}';
  int get views => (j['viewCount'] as num?)?.toInt() ?? 0;
  int get likes => (j['likeCount'] as num?)?.toInt() ?? 0;
  int get comments => (j['commentCount'] as num?)?.toInt() ?? 0;
  int get duration => (j['durationSeconds'] as num?)?.toInt() ?? 0;
  DateTime? get published => DateTime.tryParse('${j['publishedAt'] ?? ''}');
  String get watchUrl => 'https://www.youtube.com/watch?v=$videoId';

  SavedVideo toSaved() => SavedVideo(
        videoId: videoId,
        title: title,
        channelTitle: channelTitle,
        thumbnailUrl: thumbnailUrl,
        publishedAt: published,
        createdAt: DateTime.now(),
      );
}

class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('랭킹'),
          bottom: const TabBar(tabs: [
            Tab(text: '영상 순위'),
            Tab(text: '카테고리 순위'),
          ]),
        ),
        body: const TabBarView(
          children: [_VideoRankingTab(), _CategoryRankingTab()],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _VideoRankingTab extends ConsumerStatefulWidget {
  const _VideoRankingTab();
  @override
  ConsumerState<_VideoRankingTab> createState() => _VideoRankingTabState();
}

class _VideoRankingTabState extends ConsumerState<_VideoRankingTab> {
  String _region = 'KR';
  String _source = 'popular'; // popular | shorts
  String _category = ''; // '' = 전체
  int _count = 50;
  int _days = 7;
  List<Map<String, String>> _categories = [];
  List<RankVideo> _videos = [];
  String _sort = 'views';
  bool _desc = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
  }

  Future<void> _loadCategories() async {
    if (!SupabaseService.isSignedIn) return;
    try {
      final res = await SupabaseService.client.functions.invoke('ranking',
          body: {'mode': 'categories', 'regionCode': _region});
      final list = (res.data as Map?)?['categories'] as List? ?? const [];
      setState(() {
        _categories = list
            .map((e) => {
                  'id': '${e['id']}',
                  'title': '${e['title']}',
                })
            .toList();
        if (!_categories.any((c) => c['id'] == _category)) _category = '';
      });
    } catch (_) {/* categories are optional */}
  }

  Future<void> _fetch() async {
    if (!SupabaseService.isSignedIn) {
      setState(() => _error = '먼저 마이 탭에서 로그인/YouTube 연결을 해주세요.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _videos = [];
    });
    try {
      final body = {
        'mode': _source,
        'regionCode': _region,
        'categoryId': _category,
        'max': _count,
        if (_source == 'shorts') 'days': _days,
      };
      final res =
          await SupabaseService.client.functions.invoke('ranking', body: body);
      final data = res.data as Map?;
      final list = (data?['videos'] as List?) ?? const [];
      setState(() {
        _videos = list
            .map((e) => RankVideo(Map<String, dynamic>.from(e)))
            .toList();
        if (_videos.isEmpty) {
          _error = (data?['detail'] as String?) ?? '결과가 없습니다.';
        }
      });
    } catch (e) {
      setState(() => _error = '가져오기 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<RankVideo> get _sorted {
    int cmp(RankVideo a, RankVideo b) {
      switch (_sort) {
        case 'likes':
          return a.likes.compareTo(b.likes);
        case 'comments':
          return a.comments.compareTo(b.comments);
        case 'duration':
          return a.duration.compareTo(b.duration);
        case 'published':
          return (a.published ?? DateTime(0))
              .compareTo(b.published ?? DateTime(0));
        default:
          return a.views.compareTo(b.views);
      }
    }

    final list = [..._videos]..sort(cmp);
    if (_desc) return list.reversed.toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final favIds = ref.watch(favoriteIdsProvider);
    final catName = {
      for (final c in _categories) c['id'] ?? '': c['title'] ?? '',
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _regionDropdown(_region, (v) {
                setState(() => _region = v);
                _loadCategories();
              }),
              SegmentedButton<String>(
                style: const ButtonStyle(
                    visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: 'popular', label: Text('인기 차트')),
                  ButtonSegment(value: 'shorts', label: Text('쇼츠')),
                ],
                selected: {_source},
                onSelectionChanged: (s) => setState(() => _source = s.first),
              ),
              _categoryDropdown(),
              _countDropdown(_count, (v) => setState(() => _count = v)),
              if (_source == 'shorts')
                DropdownButton<int>(
                  value: _days,
                  onChanged: (v) => setState(() => _days = v ?? 7),
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('최근 7일')),
                    DropdownMenuItem(value: 30, child: Text('최근 30일')),
                    DropdownMenuItem(value: 90, child: Text('최근 90일')),
                  ],
                ),
              FilledButton(
                onPressed: _loading ? null : _fetch,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('가져오기'),
              ),
            ],
          ),
        ),
        if (_videos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Text('정렬'),
                const SizedBox(width: 6),
                DropdownButton<String>(
                  value: _sort,
                  onChanged: (v) => setState(() => _sort = v ?? 'views'),
                  items: const [
                    DropdownMenuItem(value: 'views', child: Text('조회수')),
                    DropdownMenuItem(value: 'likes', child: Text('좋아요')),
                    DropdownMenuItem(value: 'comments', child: Text('댓글')),
                    DropdownMenuItem(value: 'published', child: Text('업로드일')),
                    DropdownMenuItem(value: 'duration', child: Text('길이')),
                  ],
                ),
                IconButton(
                  tooltip: _desc ? '내림차순' : '오름차순',
                  icon: Icon(
                      _desc ? Icons.arrow_downward : Icons.arrow_upward,
                      size: 18),
                  onPressed: () => setState(() => _desc = !_desc),
                ),
                const Spacer(),
                Text('${_videos.length}개',
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _sorted.length,
            itemBuilder: (_, i) {
              final v = _sorted[i];
              final fav = favIds.contains(v.videoId);
              return _VideoRow(
                rank: i + 1,
                v: v,
                fav: fav,
                category: catName[v.categoryId],
                onFav: () => ref
                    .read(favoritesProvider.notifier)
                    .toggle(v.toSaved()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _categoryDropdown() {
    return DropdownButton<String>(
      value: _category,
      hint: const Text('카테고리'),
      onChanged: (v) => setState(() => _category = v ?? ''),
      items: [
        const DropdownMenuItem(value: '', child: Text('전체 카테고리')),
        for (final c in _categories)
          DropdownMenuItem(value: c['id'], child: Text(c['title'] ?? '')),
      ],
    );
  }
}

class _VideoRow extends StatelessWidget {
  const _VideoRow(
      {required this.rank,
      required this.v,
      required this.fav,
      required this.onFav,
      this.category});
  final int rank;
  final RankVideo v;
  final bool fav;
  final VoidCallback onFav;
  final String? category;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: InkWell(
        onTap: () => _open(v.watchUrl),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text('$rank',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: v.thumbnailUrl,
                  width: 108,
                  height: 61,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      const ColoredBox(color: Colors.black12),
                  errorWidget: (_, __, ___) =>
                      const ColoredBox(color: Colors.black12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Row(
                      children: [
                        Expanded(
                          child: Text(v.channelTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                        if (category != null && category!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(category!,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSecondaryContainer)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '👁 ${fmtCount(v.views)}  👍 ${fmtCount(v.likes)}  '
                      '💬 ${fmtCount(v.comments)}  ⏱ ${fmtDur(v.duration)}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                icon: Icon(fav ? Icons.star : Icons.star_border,
                    color: fav ? Colors.amber : null),
                onPressed: onFav,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _CategoryRankingTab extends ConsumerStatefulWidget {
  const _CategoryRankingTab();
  @override
  ConsumerState<_CategoryRankingTab> createState() =>
      _CategoryRankingTabState();
}

class _CategoryRankingTabState extends ConsumerState<_CategoryRankingTab> {
  String _region = 'KR';
  int _perCat = 15;
  List<Map<String, dynamic>> _rankings = [];
  bool _loading = false;
  String? _error;

  Future<void> _fetch() async {
    if (!SupabaseService.isSignedIn) {
      setState(() => _error = '먼저 마이 탭에서 로그인/YouTube 연결을 해주세요.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _rankings = [];
    });
    try {
      final res = await SupabaseService.client.functions.invoke('ranking',
          body: {
            'mode': 'categoryRankings',
            'regionCode': _region,
            'perCategory': _perCat,
          });
      final list = (res.data as Map?)?['rankings'] as List? ?? const [];
      setState(() {
        _rankings =
            list.map((e) => Map<String, dynamic>.from(e)).toList();
        if (_rankings.isEmpty) _error = '결과가 없습니다.';
      });
    } catch (e) {
      setState(() => _error = '가져오기 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _regionDropdown(_region, (v) => setState(() => _region = v)),
              DropdownButton<int>(
                value: _perCat,
                onChanged: (v) => setState(() => _perCat = v ?? 15),
                items: const [
                  DropdownMenuItem(value: 10, child: Text('카테고리당 10')),
                  DropdownMenuItem(value: 15, child: Text('카테고리당 15')),
                  DropdownMenuItem(value: 20, child: Text('카테고리당 20')),
                ],
              ),
              FilledButton(
                onPressed: _loading ? null : _fetch,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('집계'),
              ),
            ],
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('전 카테고리를 조회 중… (10~20초)'),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _rankings.length,
            itemBuilder: (_, i) {
              final r = _rankings[i];
              final eng =
                  ((r['avgEngagement'] as num?)?.toDouble() ?? 0) * 100;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text('${r['categoryName'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '총 조회수 ${fmtCount((r['totalViews'] as num?)?.toInt() ?? 0)} · '
                    '평균 ${fmtCount((r['avgViews'] as num?)?.toInt() ?? 0)} · '
                    '참여율 ${eng.toStringAsFixed(1)}%\n'
                    '1위: ${r['topTitle'] ?? ''}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => _CategoryVideosSheet(
                      region: _region,
                      categoryId: '${r['categoryId'] ?? ''}',
                      categoryName: '${r['categoryName'] ?? ''}',
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
Widget _regionDropdown(String value, ValueChanged<String> onChanged) {
  return DropdownButton<String>(
    value: value,
    onChanged: (v) => v == null ? null : onChanged(v),
    items: [
      for (final e in kRankingRegions.entries)
        DropdownMenuItem(value: e.key, child: Text(e.value)),
    ],
  );
}

Widget _countDropdown(int value, ValueChanged<int> onChanged) {
  return DropdownButton<int>(
    value: value,
    onChanged: (v) => v == null ? null : onChanged(v),
    items: const [
      DropdownMenuItem(value: 50, child: Text('50개')),
      DropdownMenuItem(value: 100, child: Text('100개')),
      DropdownMenuItem(value: 150, child: Text('150개')),
      DropdownMenuItem(value: 200, child: Text('200개')),
    ],
  );
}

/// Popular videos of one category, ranked — opened from the category ranking.
class _CategoryVideosSheet extends ConsumerStatefulWidget {
  const _CategoryVideosSheet({
    required this.region,
    required this.categoryId,
    required this.categoryName,
  });
  final String region;
  final String categoryId;
  final String categoryName;

  @override
  ConsumerState<_CategoryVideosSheet> createState() =>
      _CategoryVideosSheetState();
}

class _CategoryVideosSheetState extends ConsumerState<_CategoryVideosSheet> {
  List<RankVideo> _videos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    try {
      final res = await SupabaseService.client.functions.invoke('ranking',
          body: {
            'mode': 'popular',
            'regionCode': widget.region,
            'categoryId': widget.categoryId,
            'max': 50,
          });
      final list = (res.data as Map?)?['videos'] as List? ?? const [];
      setState(() {
        _videos =
            list.map((e) => RankVideo(Map<String, dynamic>.from(e))).toList();
        if (_videos.isEmpty) _error = '결과가 없습니다.';
      });
    } catch (e) {
      setState(() => _error = '가져오기 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final favIds = ref.watch(favoriteIdsProvider);
    final maxH = MediaQuery.of(context).size.height * 0.85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('${widget.categoryName} 인기 영상',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _videos.length,
              itemBuilder: (_, i) {
                final v = _videos[i];
                return _VideoRow(
                  rank: i + 1,
                  v: v,
                  fav: favIds.contains(v.videoId),
                  onFav: () =>
                      ref.read(favoritesProvider.notifier).toggle(v.toSaved()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
