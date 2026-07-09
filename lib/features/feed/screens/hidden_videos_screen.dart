import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/feed_providers.dart';
import '../providers/video_states_providers.dart';

/// Lists videos the user hid, with a restore action.
class HiddenVideosScreen extends ConsumerWidget {
  const HiddenVideosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(hiddenVideosProvider);
    final all = ref.watch(feedProvider).valueOrNull ?? const [];
    final videos = all.where((v) => hidden.contains(v.videoId)).toList();

    return Scaffold(
      appBar: AppBar(title: Text('숨긴 영상 (${hidden.length})')),
      body: hidden.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('숨긴 영상이 없습니다.\n피드에서 영상 우상단 X로 지울 수 있어요.',
                    textAlign: TextAlign.center),
              ),
            )
          : ListView(
              children: [
                if (videos.length < hidden.length)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '최근 피드에 있는 ${videos.length}개만 표시됩니다. '
                      '(전체 숨김: ${hidden.length}개)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ...videos.map(
                  (v) => ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: v.thumbnailUrl,
                        width: 72,
                        height: 40,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            const SizedBox(width: 72, height: 40),
                      ),
                    ),
                    title: Text(v.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(v.channelTitle),
                    trailing: TextButton(
                      onPressed: () =>
                          ref.read(hiddenVideosProvider.notifier).unhide(v.videoId),
                      child: const Text('복원'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
