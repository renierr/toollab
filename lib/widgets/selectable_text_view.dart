import 'package:flutter/material.dart';

/// Shared read-only text result display: a bordered, scrollable, selectable
/// text box with an empty-state fallback. Used wherever extracted/generated
/// text is shown with copy/save actions (image OCR dialog, PDF text extraction).
class SelectableTextView extends StatelessWidget {
  final String text;

  /// Max height of the scroll area. When null, the view sizes to its content.
  final double? maxHeight;

  /// Message shown when [text] is empty (after trimming).
  final String emptyMessage;

  const SelectableTextView({
    super.key,
    required this.text,
    required this.emptyMessage,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmed = text.trim();

    if (trimmed.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.text_snippet_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      constraints: maxHeight != null
          ? BoxConstraints(maxHeight: maxHeight!)
          : const BoxConstraints(),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.15,
        ),
      ),
      padding: const EdgeInsets.all(12.0),
      child: SingleChildScrollView(
        child: SelectableText(trimmed, style: theme.textTheme.bodyMedium),
      ),
    );
  }
}
