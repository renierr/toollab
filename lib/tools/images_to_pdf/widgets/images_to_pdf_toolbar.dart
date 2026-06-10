import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/tools/images_to_pdf/config.dart';

class ImagesToPdfToolbar extends StatelessWidget {
  final int imageCount;
  final ImageToPdfPageSize pageSize;
  final ValueChanged<ImageToPdfPageSize> onPageSizeChanged;
  final bool landscape;
  final ValueChanged<bool> onLandscapeChanged;
  final int jpegQuality;
  final ValueChanged<int> onJpegQualityChanged;
  final bool isProcessing;
  final VoidCallback onAddMore;
  final VoidCallback onCreatePdf;

  const ImagesToPdfToolbar({
    super.key,
    required this.imageCount,
    required this.pageSize,
    required this.onPageSizeChanged,
    required this.landscape,
    required this.onLandscapeChanged,
    required this.jpegQuality,
    required this.onJpegQualityChanged,
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
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$imageCount image${imageCount == 1 ? '' : 's'}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: isProcessing ? null : onAddMore,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add More'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: imageCount == 0 || isProcessing
                      ? null
                      : onCreatePdf,
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('Create PDF'),
                  style: FilledButton.styleFrom(backgroundColor: accent),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Page Size
                DropdownButton<ImageToPdfPageSize>(
                  value: pageSize,
                  onChanged: isProcessing
                      ? null
                      : (v) {
                          if (v != null) onPageSizeChanged(v);
                        },
                  items: const [
                    DropdownMenuItem(
                      value: ImageToPdfPageSize.a4,
                      child: Text('A4'),
                    ),
                    DropdownMenuItem(
                      value: ImageToPdfPageSize.letter,
                      child: Text('Letter'),
                    ),
                    DropdownMenuItem(
                      value: ImageToPdfPageSize.legal,
                      child: Text('Legal'),
                    ),
                    DropdownMenuItem(
                      value: ImageToPdfPageSize.fit,
                      child: Text('Fit to Image'),
                    ),
                  ],
                  underline: const SizedBox.shrink(),
                ),
                // Orientation
                if (pageSize != ImageToPdfPageSize.fit)
                  FilterChip(
                    label: const Text('Landscape'),
                    selected: landscape,
                    onSelected: isProcessing ? null : onLandscapeChanged,
                  ),
                // Quality
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Quality:', style: theme.textTheme.bodySmall),
                    SizedBox(
                      width: 120,
                      child: Slider(
                        value: jpegQuality.toDouble(),
                        min: 50,
                        max: 100,
                        divisions: 10,
                        label: '$jpegQuality%',
                        onChanged: isProcessing
                            ? null
                            : (v) => onJpegQualityChanged(v.round()),
                      ),
                    ),
                    Text('$jpegQuality%', style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
