import 'package:flutter/material.dart';

import '../../../core/utils/feed_topics.dart';
import '../models/filter_group.dart';

class SubcatDraft {
  SubcatDraft({required this.name, required this.topics});
  final String name;
  final List<String> topics;
}

/// Bottom sheet to create/edit a 소분류 (name + a bundle of fine topics).
class SubcatEditorSheet extends StatefulWidget {
  const SubcatEditorSheet({super.key, this.existing});
  final FilterSubcategory? existing;

  @override
  State<SubcatEditorSheet> createState() => _SubcatEditorSheetState();
}

class _SubcatEditorSheetState extends State<SubcatEditorSheet> {
  late final TextEditingController _name;
  late Set<String> _topics;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _topics = {...?widget.existing?.topics};
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    Navigator.of(context).pop(SubcatDraft(
      name: name.isEmpty
          ? (_topics.isNotEmpty ? _topics.first : '새 소분류')
          : name,
      topics: _topics.toList(),
    ));
  }

  Widget _group(MapEntry<String, List<String>> g) {
    final selectedIn = g.value.where(_topics.contains).length;
    final allSel = selectedIn == g.value.length;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Row(
        children: [
          Expanded(
            child:
                Text(selectedIn > 0 ? '${g.key} ($selectedIn)' : g.key),
          ),
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => setState(() {
              if (allSel) {
                _topics.removeAll(g.value);
              } else {
                _topics.addAll(g.value);
              }
            }),
            child: Text(allSel ? '전체 해제' : '전체 선택'),
          ),
        ],
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: g.value
                .map((t) => FilterChip(
                      label: Text(t),
                      selected: _topics.contains(t),
                      onSelected: (v) => setState(() =>
                          v ? _topics.add(t) : _topics.remove(t)),
                    ))
                .toList(),
          ),
        ),
      ],
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
            Text(widget.existing == null ? '소분류 추가' : '소분류 편집',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: '이름 (비우면 첫 주제명)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text('포함할 세부 주제 (${_topics.length}개 선택)',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            ...FeedTopics.groups.entries.map(_group),
            const SizedBox(height: 20),
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
