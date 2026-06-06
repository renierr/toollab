import 'package:flutter/material.dart';

class MarkdownLoadingSkeleton extends StatelessWidget {
  final Color accentColor;

  const MarkdownLoadingSkeleton({super.key, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          LinearProgressIndicator(
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: accentColor,
          ),
          const SizedBox(height: 12),
          Text(
            'Rendering markdown\u2026',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
