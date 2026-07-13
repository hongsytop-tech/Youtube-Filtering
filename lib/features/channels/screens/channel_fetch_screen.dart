import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../favorites/models/saved_video.dart';
import '../../favorites/providers/favorites_providers.dart';

class _ChannelVideo {
  _ChannelVideo({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    required this.publishedAt,
    required this.channelTitle,
  });

  final String videoId;
  final String title;
  final String thumbnailUrl;
  final DateTime? publishedAt;
  final String channelTitle;

  String get watchUrl => 'https://www.youtube.com/watch?v=$videoId';

  factory _ChannelVideo.fromJson(Map<String, dynamic> j) => _ChannelVideo(
        videoId: '${j['videoId'] ?? ''}',
        title: '${j['title'] ?? ''}',
        thumbnailUrl: '${j['thumbnailUrl'] ?? ''}',
        publishedAt: DateTime.tryParse('${j['publishedAt'] ?? ''}')?.toLocal(),
        channelTitle: '${j['channelTitle'] ?? ''}',
      );

  SavedVideo toSaved() => SavedVideo(
        videoId: videoId,
        title: title,
        channelTitle: channelTitle,
        thumbnailUrl: thumbnailUrl,
        publishedAt: publishedAt,
        createdAt: DateTime.now(),
      );
}

class ChannelFetchScreen extends ConsumerStatefulWidget {
  const ChannelFetchScreen({super.key});

  @override
  ConsumerState<ChannelFetchScreen> createState() => _ChannelFetchScreenState();
}

class _ChannelFetchScreenState extends ConsumerState<ChannelFetchScreen> {
  final _input = TextEditingController();
  int _count = 50;
  List<_ChannelVideo> _videos = [];
  final Set<String> _selected = {};
  String? _channelTitle;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final channel = _input.text.trim();
    if (channel.isEmpty) return;
    if (!SupabaseService.isSignedIn) {
      setState(() => _error = '먼저 마이 탭에서 로그인/YouTube 연결을 해주세요.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _videos = [];
      _selected.clear();
      _channelTitle = null;
    });
    try {
      final res = await SupabaseService.client.functions.invoke(
        'channel-videos',
        body: {'channel': channel, 'max': _count},
      );
      final data = res.data as Map?;
      final list = (data?['videos'] as List?) ?? const [];
      setState(() {
        _channelTitle = data?['channelTitle'] as String?;
        _videos = list
            .map((e) => _ChannelVideo.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (_videos.isEmpty) _error = '영상을 찾지 못했습니다.';
      });
    } catch (e) {
      setState(() => _error = '가져오기 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(String id) => setState(() {
        _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
      });

  void _selectAll() => setState(() {
        if (_selected.length == _videos.length) {
          _selected.clear();
        } else {
          _selected
            ..clear()
            ..addAll(_videos.map((v) => v.videoId));
        }
      });

  Future<void> _copyLinks() async {
    final links = _videos
        .where((v) => _selected.contains(v.videoId))
        .map((v) => v.watchUrl)
        .join('\n');
    await Clipboard.setData(ClipboardData(text: links));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_selected.length}개 링크를 복사했습니다.')),
      );
    }
  }

  Future<void> _saveSelected() async {
    final notifier = ref.read(favoritesProvider.notifier);
    for (final v in _videos.where((v) => _selected.contains(v.videoId))) {
      await notifier.add(v.toSaved());
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_selected.length}개를 즐겨찾기에 추가했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSel = _videos.isNotEmpty && _selected.length == _videos.length;
    return Scaffold(
      appBar: AppBar(title: const Text('채널 영상 가져오기')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _input,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _fetch(),
              decoration: const InputDecoration(
                hintText: '채널 URL / @핸들 / 채널ID',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                const Text('개수'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _count,
                  onChanged: (v) => setState(() => _count = v ?? 50),
                  items: const [
                    DropdownMenuItem(value: 50, child: Text('50개')),
                    DropdownMenuItem(value: 100, child: Text('100개')),
                    DropdownMenuItem(value: 150, child: Text('150개')),
                    DropdownMenuItem(value: 200, child: Text('200개')),
                  ],
                ),
                const Spacer(),
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
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (_videos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_channelTitle ?? ''} · ${_videos.length}개',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: _selectAll,
                    child: Text(allSel ? '전체 해제' : '전체 선택'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _videos.length,
              itemBuilder: (_, i) {
                final v = _videos[i];
                final sel = _selected.contains(v.videoId);
                return CheckboxListTile(
                  value: sel,
                  onChanged: (_) => _toggle(v.videoId),
                  controlAffinity: ListTileControlAffinity.leading,
                  secondary: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: v.thumbnailUrl,
                      width: 96,
                      height: 54,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const ColoredBox(color: Colors.black12),
                      errorWidget: (_, __, ___) =>
                          const ColoredBox(color: Colors.black12),
                    ),
                  ),
                  title: Text(v.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  dense: true,
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saveSelected,
                        icon: const Icon(Icons.star_border),
                        label: const Text('즐겨찾기'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _copyLinks,
                        icon: const Icon(Icons.copy),
                        label: Text('${_selected.length}개 링크 복사'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
