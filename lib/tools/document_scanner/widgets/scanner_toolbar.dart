import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class ScannerToolbar extends StatelessWidget {
  final bool hasPages;
  final bool isProcessing;
  final VoidCallback onAddCamera;
  final VoidCallback onAddGallery;
  final VoidCallback onCompilePdf;
  final VoidCallback onClearAll;
  final Color accentColor;

  const ScannerToolbar({
    super.key,
    required this.hasPages,
    required this.isProcessing,
    required this.onAddCamera,
    required this.onAddGallery,
    required this.onCompilePdf,
    required this.onClearAll,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      padding: const EdgeInsets.all(16.0),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Clear All button (only visible if we have pages)
                if (hasPages) ...[
                  OutlinedButton.icon(
                    onPressed: isProcessing ? null : onClearAll,
                    icon: const Icon(Icons.clear_all),
                    label: Text(l10n.commonClear),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(
                        color: theme.colorScheme.error.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // Add Page button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isProcessing ? null : onAddCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(l10n.docScanActionScan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Gallery button
                IconButton(
                  onPressed: isProcessing ? null : onAddGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  tooltip: l10n.docScanActionGallery,
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),

            // Compile PDF button (only visible if we have pages)
            if (hasPages) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isProcessing ? null : onCompilePdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(l10n.docScanActionSave),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
