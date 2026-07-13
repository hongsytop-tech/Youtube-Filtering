import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feed/widgets/video_card.dart';
import '../models/exclusions.dart';
import '../providers/exclusions_providers.dart';
import '../providers/insights_providers.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(feedInsightsProvider);
    final excl = ref.watch(exclusionsProvider);
    final notifier = ref.read(exclusionsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('분석')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          Text(
            '현재 피드 ${insights.total}개를 분석했습니다. '
            '알고리즘이 많이 밀어주는 항목을 "제외"하면 피드에서 사라집니다.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
          ),
          const SizedBox(height: 8),
          if (!excl.isEmpty) _ExcludedSection(excl: excl, notifier: notifier),
          _RankSection(
            title: '주제 Top',
            kind: InsightKind.topic,
            items: insights.topics,
            max: 12,
            onExclude: notifier.excludeTopic,
          ),
          _RankSection(
            title: '채널 Top',
            kind: InsightKind.channel,
            items: insights.channels,
            max: 12,
            onExclude: notifier.excludeChannel,
          ),
          _RankSection(
            title: '키워드 Top',
            kind: InsightKind.keyword,
            items: insights.keywords,
            max: 15,
            onExclude: notifier.excludeKeyword,
          ),
          const SizedBox(height: 12),
          _ManualKeyword(onAdd: notifier.excludeKeyword),
        ],
      ),
    );
  }
}

class _RankSection extends StatelessWidget {
  const _RankSection({
    required this.title,
    required this.kind,
    required this.items,
    required this.max,
    required this.onExclude,
  });

  final String title;
  final InsightKind kind;
  final List<MapEntry<String, int>> items;
  final int max;
  final void Function(String) onExclude;

  void _open(BuildContext context, String value) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _InsightVideosSheet(query: InsightQuery(kind, value)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final shown = items.take(max).toList();
    final top = shown.first.value;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (final e in shown)
            _RankRow(
              label: e.key,
              count: e.value,
              fraction: top == 0 ? 0 : e.value / top,
              onTap: () => _open(context, e.key),
              onExclude: () => onExclude(e.key),
            ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.label,
    required this.count,
    required this.fraction,
    required this.onTap,
    required this.onExclude,
  });

  final String label;
  final int count;
  final double fraction;
  final VoidCallback onTap;
  final VoidCallback onExclude;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: scheme.surfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fraction.clamp(0.04, 1.0),
                  child: Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: scheme.primary.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  Theme.of(context).textTheme.bodyMedium),
                        ),
                        Text('$count',
                            style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: '제외',
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.block),
            color: scheme.error,
            onPressed: onExclude,
          ),
        ],
      ),
    );
  }
}

class _ExcludedSection extends StatelessWidget {
  const _ExcludedSection({required this.excl, required this.notifier});

  final Exclusions excl;
  final ExclusionsNotifier notifier;

  @override
  Widget build(BuildContext context) {
    Widget chips(String head, Iterable<String> items, void Function(String) rm) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(head, style: Theme.of(context).textTheme.labelSmall),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: [
                for (final i in items)
                  InputChip(
                    label: Text(i),
                    onDeleted: () => rm(i),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return Card(
      color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.35),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('제외 중 (${excl.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            chips('채널', excl.channels, notifier.removeChannel),
            chips('주제', excl.topics, notifier.removeTopic),
            chips('키워드', excl.keywords, notifier.removeKeyword),
          ],
        ),
      ),
    );
  }
}

class _ManualKeyword extends StatefulWidget {
  const _ManualKeyword({required this.onAdd});
  final void Function(String) onAdd;

  @override
  State<_ManualKeyword> createState() => _ManualKeywordState();
}

class _ManualKeywordState extends State<_ManualKeyword> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _c.text.trim();
    if (v.isEmpty) return;
    widget.onAdd(v);
    _c.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _c,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: '키워드 직접 제외 (제목에 포함되면 숨김)',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: _submit, child: const Text('제외')),
      ],
    );
  }
}

/// Lists the videos behind a tapped ranked item.
class _InsightVideosSheet extends ConsumerWidget {
  const _InsightVideosSheet({required this.query});

  final InsightQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos = ref.watch(insightVideosProvider(query));
    final maxH = MediaQuery.of(context).size.height * 0.8;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '${query.value} · ${videos.length}개',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: videos.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('영상이 없습니다.')),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: videos.length,
                    itemBuilder: (_, i) => VideoCard(video: videos[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
