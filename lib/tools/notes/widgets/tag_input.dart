import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';

class TagInput extends StatefulWidget {
  final List<String> tags;
  final ValueChanged<List<String>> onTagsChanged;
  final List<String> suggestions;

  const TagInput({
    super.key,
    required this.tags,
    required this.onTagsChanged,
    this.suggestions = const [],
  });

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _filteredSuggestions = [];
  bool _showSuggestions = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addTag(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty) return;
    if (widget.tags.any((t) => t.toLowerCase() == tag.toLowerCase())) return;

    final updated = [...widget.tags, tag];
    widget.onTagsChanged(updated);
    setState(() {
      _controller.clear();
      _filteredSuggestions = [];
      _showSuggestions = false;
    });
  }

  void _removeTag(String tag) {
    final updated = widget.tags.where((t) => t != tag).toList();
    widget.onTagsChanged(updated);
  }

  void _onTextChanged(String value) {
    if (value.contains(',') || value.contains('\n')) {
      final parts = value.split(RegExp(r'[,\n]'));
      for (final part in parts) {
        _addTag(part);
      }
      return;
    }

    if (value.isEmpty) {
      setState(() {
        _filteredSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    final query = value.toLowerCase();
    final selectedTags = widget.tags.map((t) => t.toLowerCase()).toSet();
    final seen = <String>{};
    final prefixMatches = <String>[];
    final containsMatches = <String>[];

    for (final suggestion in widget.suggestions) {
      final normalized = suggestion.trim();
      if (normalized.isEmpty) continue;
      final lower = normalized.toLowerCase();
      if (selectedTags.contains(lower) || lower == query || !seen.add(lower)) {
        continue;
      }
      if (lower.startsWith(query)) {
        prefixMatches.add(normalized);
        continue;
      }
      if (lower.contains(query)) {
        containsMatches.add(normalized);
      }
    }

    setState(() {
      _filteredSuggestions = [
        ...prefixMatches,
        ...containsMatches,
      ].take(5).toList();
      _showSuggestions = _filteredSuggestions.isNotEmpty;
    });
  }

  void _onSubmit(String value) {
    _addTag(value);
    setState(() {
      _showSuggestions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...widget.tags.map(
              (tag) => Chip(
                label: Text(tag, style: const TextStyle(fontSize: 12)),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => _removeTag(tag),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                backgroundColor: AppTheme.accentTeal.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: AppTheme.accentTeal.withValues(alpha: 0.9),
                ),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onTextChanged,
                onSubmitted: _onSubmit,
                decoration: InputDecoration(
                  hintText: 'Add tag...',
                  hintStyle: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppTheme.accentTeal),
                  ),
                ),
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
        if (_showSuggestions)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 140),
            child: Material(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _filteredSuggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _filteredSuggestions[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      suggestion,
                      style: const TextStyle(fontSize: 13),
                    ),
                    onTap: () => _onSubmit(suggestion),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
