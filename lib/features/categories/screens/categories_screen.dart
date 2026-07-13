import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/filter_group.dart';
import '../providers/categories_providers.dart';
import '../widgets/group_editor_sheet.dart';
import '../widgets/subcat_editor_sheet.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(categoriesProvider);
    final notifier = ref.read(categoriesProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('카테고리'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'reset') _confirmReset(context, notifier);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reset', child: Text('기본값으로 초기화')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addGroup(context, notifier),
        icon: const Icon(Icons.add),
        label: const Text('대분류 추가'),
      ),
      body: groups.isEmpty
          ? const _Empty()
          : ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
              children: [
                const _Legend(),
                for (final g in groups)
                  _GroupTile(group: g, notifier: notifier),
              ],
            ),
    );
  }

  Future<void> _addGroup(
      BuildContext context, CategoriesNotifier notifier) async {
    final draft = await showModalBottomSheet<GroupDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const GroupEditorSheet(),
    );
    if (draft != null) await notifier.addGroup(draft.name, draft.color);
  }

  Future<void> _confirmReset(
      BuildContext context, CategoriesNotifier notifier) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('기본값으로 초기화'),
        content: const Text('직접 만든 카테고리가 모두 사라지고 기본 분류로 되돌립니다. 진행할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('초기화')),
        ],
      ),
    );
    if (ok == true) await notifier.resetToDefaults();
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group, required this.notifier});
  final FilterGroup group;
  final CategoriesNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(backgroundColor: Color(group.color), radius: 8),
        title: Text(group.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('소분류 ${group.subcats.length}개'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ExposeSwitch(
              value: group.exposed,
              onChanged: (_) => notifier.toggleGroupExposed(group.id),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    _editGroup(context);
                  case 'add':
                    _addSubcat(context);
                  case 'delete':
                    notifier.removeGroup(group.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('편집')),
                PopupMenuItem(value: 'add', child: Text('소분류 추가')),
                PopupMenuItem(value: 'delete', child: Text('삭제')),
              ],
            ),
          ],
        ),
        children: [
          for (final s in group.subcats)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 32, right: 8),
              title: Text(s.name),
              subtitle: Text(
                s.topics.isEmpty ? '주제 없음' : s.topics.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ExposeSwitch(
                    value: s.exposed,
                    onChanged: (_) =>
                        notifier.toggleSubcatExposed(group.id, s.id),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') {
                        _editSubcat(context, s);
                      } else {
                        notifier.removeSubcat(group.id, s.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('편집')),
                      PopupMenuItem(value: 'delete', child: Text('삭제')),
                    ],
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 8, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _addSubcat(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('소분류 추가'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editGroup(BuildContext context) async {
    final draft = await showModalBottomSheet<GroupDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GroupEditorSheet(existing: group),
    );
    if (draft != null) {
      await notifier
          .updateGroup(group.copyWith(name: draft.name, color: draft.color));
    }
  }

  Future<void> _addSubcat(BuildContext context) async {
    final draft = await showModalBottomSheet<SubcatDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SubcatEditorSheet(),
    );
    if (draft != null) {
      await notifier.addSubcat(group.id, draft.name, draft.topics);
    }
  }

  Future<void> _editSubcat(BuildContext context, FilterSubcategory s) async {
    final draft = await showModalBottomSheet<SubcatDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SubcatEditorSheet(existing: s),
    );
    if (draft != null) {
      await notifier.updateSubcat(
          group.id, s.copyWith(name: draft.name, topics: draft.topics));
    }
  }
}

class _ExposeSwitch extends StatelessWidget {
  const _ExposeSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: value ? '피드에 노출됨' : '피드에서 숨김',
      child: Transform.scale(
        scale: 0.8,
        child: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Text(
        '대분류 > 소분류 2단 구조입니다. 스위치로 피드 노출을 켜고 끄세요 '
        '(노출을 켜도 영상이 없으면 피드 바에는 표시되지 않습니다).',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).hintColor,
            ),
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
        child: Text('대분류를 추가해 카테고리를 만들어보세요.',
            textAlign: TextAlign.center),
      ),
    );
  }
}
