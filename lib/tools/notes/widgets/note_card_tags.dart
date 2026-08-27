import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';

class NoteCardTags extends StatelessWidget {
  final List<String> tags;

  const NoteCardTags({super.key, required this.tags});

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    const maxVisible = 3;
    final visible = tags.take(maxVisible).toList();
    final remaining = tags.length - maxVisible;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...visible.map(
          (tag) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.accentTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.accentTeal.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '+$remaining',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
      ],
    );
  }
}
