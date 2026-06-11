import 'package:flutter/material.dart';
import 'package:tool_lab/tools/images_to_pdf/config.dart';

class ImagesToPdfToolbar extends StatelessWidget {
  final int imageCount;
  final bool isProcessing;
  final VoidCallback onAddMore;
  final VoidCallback onCreatePdf;

  const ImagesToPdfToolbar({
    super.key,
    required this.imageCount,
    required this.isProcessing,
    required this.onAddMore,
    required this.onCreatePdf,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = ImagesToPdfTool.config.accentColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$imageCount image${imageCount == 1 ? '' : 's'}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isProcessing ? null : onAddMore,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add More'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: imageCount == 0 || isProcessing
                        ? null
                        : onCreatePdf,
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('Create PDF'),
                    style: FilledButton.styleFrom(backgroundColor: accent),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
