import 'package:flutter/material.dart';

import '../../../core/utils/feed_topics.dart';
import '../../../core/utils/youtube_categories.dart';
import '../models/filter_category.dart';

class CategoryDraft {
  CategoryDraft({
    required this.name,
    required this.color,
    required this.youtubeCategoryIds,
    required this.keywords,
    required this.topics,
  });

  final String name;
  final int color;
  final List<String> youtubeCategoryIds;
  final List<String> keywords;
  final List<String> topics;
}

class CategoryEditorSheet extends StatefulWidget {
  const CategoryEditorSheet({super.key, this.existing});

  final FilterCategory? existing;

  @override
  State<CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<CategoryEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _keywords;
  late Set<String> _selectedIds;
  late Set<String> _selectedTopics;
  late int _color;

  static const _palette = <int>[
    0xFFEF4444,
    0xFF3B82F6,
    0xFF8B5CF6,
    0xFF10B981,
    0xFFF59E0B,
    0xFFEC4899,
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _keywords = TextEditingController(text: e?.keywords.join(', ') ?? '');
    _selectedIds = {...?e?.youtubeCategoryIds};
    _selectedTopics = {...?e?.topics};
    _color = e?.color ?? _palette.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _keywords.dispose();
    super.dispose();
  }

  void _save() {
    final keywords = _keywords.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    Navigator.of(context).pop(
      CategoryDraft(
        name: _name.text.trim().isEmpty ? '새 카테고리' : _name.text.trim(),
        color: _color,
        youtubeCategoryIds: _selectedIds.toList(),
        keywords: keywords,
        topics: _selectedTopics.toList(),
      ),
    );
  }

  Widget _topicGroup(MapEntry<String, List<String>> group) {
    final selectedInGroup =
        group.value.where(_selectedTopics.contains).length;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(
          selectedInGroup > 0 ? '${group.key} ($selectedInGroup)' : group.key,
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: group.value.map((t) {
                final selected = _selectedTopics.contains(t);
                return FilterChip(
                  label: Text(t),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _selectedTopics.add(t);
                    } else {
                      _selectedTopics.remove(t);
                    }
                  }),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? '카테고리 추가' : '카테고리 편집',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: '이름',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('세부 주제'),
                const SizedBox(width: 8),
                if (_selectedTopics.isNotEmpty)
                  Text(
                    '${_selectedTopics.length}개 선택',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'AI가 영상별로 붙인 세부 주제입니다. 여러 개 선택하면 그중 하나라도 맞으면 노출됩니다.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
            const SizedBox(height: 8),
            ...FeedTopics.groups.entries.map(_topicGroup),
            const SizedBox(height: 16),
            const Text('YouTube 카테고리 (대분류)'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: YoutubeCategories.all.map((e) {
                final selected = _selectedIds.contains(e.key);
                return FilterChip(
                  label: Text(e.value),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _selectedIds.add(e.key);
                    } else {
                      _selectedIds.remove(e.key);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _keywords,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: '제목 키워드 (쉼표로 구분, 선택)',
                hintText: '예: 리뷰, 튜토리얼',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('색상'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: _palette.map((c) {
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: CircleAvatar(
                    backgroundColor: Color(c),
                    radius: 16,
                    child: _color == c
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _save, child: const Text('저장')),
            ),
          ],
        ),
      ),
    );
  }
}
