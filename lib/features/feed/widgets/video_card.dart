import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/youtube_categories.dart';
import '../../favorites/models/saved_video.dart';
import '../../favorites/providers/favorites_providers.dart';
import '../models/feed_video.dart';
import 'summary_sheet.dart';

/// Compact horizontal video card used by the feed and the favorites screen.
/// A small left thumbnail keeps rows short so more videos fit on screen.
class VideoCard extends ConsumerWidget {
  const VideoCard({
    super.key,
    required this.video,
    this.onHide,
    this.showFavorite = true,
    this.pinned,
    this.onTogglePin,
  });

  final FeedVideo video;
  final VoidCallback? onHide;
  final bool showFavorite;

  /// When non-null the pin toggle is shown (favorites screen).
  final bool? pinned;
  final VoidCallback? onTogglePin;

  Future<void> _open() async {
    await launchUrl(Uri.parse(video.watchUrl),
        mode: LaunchMode.externalApplication);
  }

  void _showSummary(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          SummarySheet(videoId: video.videoId, title: video.title),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoriteIdsProvider).contains(video.videoId);
    final labels = video.topics.isNotEmpty
        ? video.topics.take(2).toList()
        : [YoutubeCategories.label(video.categoryId)];
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 132,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const ColoredBox(color: Colors.black12),
                      errorWidget: (_, __, ___) => const ColoredBox(
                        color: Colors.black12,
                        child: Icon(Icons.play_circle_outline, size: 32),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                    ),
                    const SizedBox(height: 4),
                    if (video.channelTitle.isNotEmpty)
                      Text(
                        video.channelTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final l in labels)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              l,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: scheme.onSecondaryContainer),
                            ),
                          ),
                        Text(
                          _relative(video.publishedAt),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _Actions(
                isFav: isFav,
                showFavorite: showFavorite,
                pinned: pinned,
                onToggleFavorite: () => ref
                    .read(favoritesProvider.notifier)
                    .toggle(SavedVideo.fromFeedVideo(video)),
                onTogglePin: onTogglePin,
                onHide: onHide,
                onSummary: () => _showSummary(context),
              ),
            ],
          ),
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

class _Actions extends StatelessWidget {
  const _Actions({
    required this.isFav,
    required this.showFavorite,
    required this.pinned,
    required this.onToggleFavorite,
    required this.onTogglePin,
    required this.onHide,
    required this.onSummary,
  });

  final bool isFav;
  final bool showFavorite;
  final bool? pinned;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onTogglePin;
  final VoidCallback? onHide;
  final VoidCallback onSummary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'AI 요약',
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          icon: const Icon(Icons.auto_awesome_outlined),
          onPressed: onSummary,
        ),
        if (showFavorite)
          IconButton(
            tooltip: isFav ? '즐겨찾기 해제' : '즐겨찾기',
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: Icon(
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? Colors.amber : null,
            ),
            onPressed: onToggleFavorite,
          ),
        if (onTogglePin != null)
          IconButton(
            tooltip: (pinned ?? false) ? '고정 해제' : '상단 고정',
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: Icon(
              (pinned ?? false) ? Icons.push_pin : Icons.push_pin_outlined,
              color: (pinned ?? false) ? scheme.primary : null,
            ),
            onPressed: onTogglePin,
          ),
        if (onHide != null)
          IconButton(
            tooltip: '이 영상 지우기',
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: const Icon(Icons.close),
            onPressed: onHide,
          ),
      ],
    );
  }
}
