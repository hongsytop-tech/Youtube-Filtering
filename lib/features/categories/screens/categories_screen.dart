import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/youtube_categories.dart';
import '../models/filter_category.dart';
import '../providers/categories_providers.dart';
import '../widgets/category_editor_sheet.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(categoriesProvider);
    final notifier = ref.read(categoriesProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('카테고리'),
        actions: [
          IconButton(
            tooltip: '추천 세분 카테고리 추가',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => _loadPresets(context, notifier),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('추가'),
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (state.syncError != null)
                  _SyncBanner(message: state.syncError!),
                Expanded(
                  child: state.items.isEmpty
                      ? const _Empty()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                          itemCount: state.items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final c = state.items[i];
                            return _CategoryCard(
                              category: c,
                              onToggle: () => notifier.toggle(c.id),
                              onEdit: () =>
                                  _openEditor(context, ref, existing: c),
                              onDelete: () => notifier.remove(c.id),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _loadPresets(
    BuildContext context,
    CategoriesNotifier notifier,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final added = await notifier.addPresets();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          added > 0
              ? '세분 카테고리 $added개를 추가했습니다. 원하는 항목을 켜보세요.'
              : '추가할 새 추천 카테고리가 없습니다.',
        ),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    FilterCategory? existing,
  }) async {
    final result = await showModalBottomSheet<CategoryDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryEditorSheet(existing: existing),
    );
    if (result == null) return;
    final notifier = ref.read(categoriesProvider.notifier);
    if (existing == null) {
      await notifier.add(
        name: result.name,
        color: result.color,
        youtubeCategoryIds: result.youtubeCategoryIds,
        keywords: result.keywords,
        topics: result.topics,
      );
    } else {
      await notifier.update(existing.copyWith(
        name: result.name,
        color: result.color,
        youtubeCategoryIds: result.youtubeCategoryIds,
        keywords: result.keywords,
        topics: result.topics,
      ));
    }
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final FilterCategory category;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final labels = category.topics
        .followedBy(category.youtubeCategoryIds.map(YoutubeCategories.label))
        .followedBy(category.keywords.map((k) => '#$k'))
        .join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Color(category.color), radius: 10),
        title: Text(category.name),
        subtitle: Text(
          labels.isEmpty ? '조건 없음' : labels,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: category.enabled, onChanged: (_) => onToggle()),
            PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('편집')),
                PopupMenuItem(value: 'delete', child: Text('삭제')),
              ],
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.errorContainer,
      padding: const EdgeInsets.all(10),
      child: Text(
        '동기화 오류: $message',
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          '보고 싶은 카테고리를 추가하세요.\n예: 교육, 음악, 게임',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
