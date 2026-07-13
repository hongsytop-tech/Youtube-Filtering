import 'package:flutter/material.dart';

import '../models/filter_group.dart';

class GroupDraft {
  GroupDraft({required this.name, required this.color});
  final String name;
  final int color;
}

/// Bottom sheet to create/edit a 대분류 (name + color).
class GroupEditorSheet extends StatefulWidget {
  const GroupEditorSheet({super.key, this.existing});
  final FilterGroup? existing;

  @override
  State<GroupEditorSheet> createState() => _GroupEditorSheetState();
}

class _GroupEditorSheetState extends State<GroupEditorSheet> {
  late final TextEditingController _name;
  late int _color;

  static const _palette = <int>[
    0xFF3B82F6, 0xFFEF4444, 0xFF8B5CF6, 0xFF10B981, 0xFFF59E0B,
    0xFFEC4899, 0xFF06B6D4, 0xFFF97316,
  ];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _color = widget.existing?.color ?? _palette.first;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.existing == null ? '대분류 추가' : '대분류 편집',
              style: Theme.of(context).textTheme.titleLarge),
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
          const Text('색상'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: _palette
                .map((c) => GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: CircleAvatar(
                        backgroundColor: Color(c),
                        radius: 16,
                        child: _color == c
                            ? const Icon(Icons.check,
                                size: 18, color: Colors.white)
                            : null,
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(
                GroupDraft(
                  name: _name.text.trim().isEmpty
                      ? '새 대분류'
                      : _name.text.trim(),
                  color: _color,
                ),
              ),
              child: const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }
}
