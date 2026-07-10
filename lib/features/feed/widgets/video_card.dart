import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/youtube_categories.dart';
import '../models/feed_video.dart';

class VideoCard extends StatelessWidget {
  const VideoCard({super.key, required this.video, this.onHide});

  final FeedVideo video;
  final VoidCallback? onHide;

  Future<void> _open() async {
    final uri = Uri.parse(video.watchUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: _open,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const ColoredBox(color: Colors.black12),
                    errorWidget: (_, __, ___) => const ColoredBox(
                      color: Colors.black12,
                      child: Icon(Icons.play_circle_outline, size: 40),
                    ),
                  ),
                ),
                if (onHide != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: '이 영상 지우기',
                        iconSize: 20,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: onHide,
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    video.channelTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  _CategoryLabels(video: video),
                  const SizedBox(height: 2),
                  Text(
                    _relative(video.publishedAt),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relative(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes}분 전';
    if (d.inHours < 24) return '${d.inHours}시간 전';
    if (d.inDays < 7) return '${d.inDays}일 전';
    return DateFormat('M월 d일').format(t);
  }
}

/// Shows the video's fine-grained topic tags (the LLM classification). Falls
/// back to the coarse YouTube category only when no topic was assigned.
class _CategoryLabels extends StatelessWidget {
  const _CategoryLabels({required this.video});

  final FeedVideo video;

  @override
  Widget build(BuildContext context) {
    final labels = video.topics.isNotEmpty
        ? video.topics
        : [YoutubeCategories.label(video.categoryId)];
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final l in labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              l,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
            ),
          ),
      ],
    );
  }
}
