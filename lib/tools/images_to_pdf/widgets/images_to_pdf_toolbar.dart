import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/images_to_pdf/config.dart';

class ImagesToPdfToolbar extends StatelessWidget {
  final int imageCount;
  final bool isProcessing;
  final VoidCallback onPaste;
  final VoidCallback onAddMore;
  final VoidCallback onCreatePdf;

  const ImagesToPdfToolbar({
    super.key,
    required this.imageCount,
    required this.isProcessing,
    required this.onPaste,
    required this.onAddMore,
    required this.onCreatePdf,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = ImagesToPdfTool.config.accentColor;
    final l10n = AppLocalizations.of(context);

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
              imageCount == 1
                  ? l10n.img2pdfImageCountSingle
                  : l10n.img2pdfImageCountPlural(imageCount),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.outlined(
                  onPressed: isProcessing ? null : onPaste,
                  icon: const Icon(Icons.paste_outlined, size: 18),
                  tooltip: l10n.img2pdfPasteFromClipboard,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isProcessing ? null : onAddMore,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.img2pdfAddMore),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: imageCount == 0 || isProcessing
                        ? null
                        : onCreatePdf,
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: Text(l10n.img2pdfCreatePdf),
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
