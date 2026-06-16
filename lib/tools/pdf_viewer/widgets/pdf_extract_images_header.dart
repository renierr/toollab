import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class PdfExtractImagesHeader extends StatelessWidget {
  final int totalCount;
  final int selectedCount;
  final bool isLoading;
  final bool isExporting;
  final double progress;
  final String statusText;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onDownloadSelected;
  final VoidCallback onDownloadAll;
  final bool isCompactScreen;
  final bool controlsExpanded;
  final VoidCallback onToggleControlsExpanded;

  const PdfExtractImagesHeader({
    super.key,
    required this.totalCount,
    required this.selectedCount,
    required this.isLoading,
    required this.isExporting,
    required this.progress,
    required this.statusText,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onDownloadSelected,
    required this.onDownloadAll,
    required this.isCompactScreen,
    required this.controlsExpanded,
    required this.onToggleControlsExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final showControls = !isCompactScreen || controlsExpanded;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.pdfEditExtractSelectionCount(
                      selectedCount,
                      totalCount,
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                if (isCompactScreen)
                  IconButton(
                    tooltip: controlsExpanded
                        ? l10n.pdfEditExtractHideControls
                        : l10n.pdfEditExtractShowControls,
                    onPressed: onToggleControlsExpanded,
                    icon: Icon(
                      controlsExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              statusText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (isLoading || isExporting) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress > 0 ? progress : null),
            ],
            if (showControls) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: isLoading || isExporting ? null : onSelectAll,
                    icon: const Icon(Icons.select_all),
                    label: Text(l10n.pdfEditExtractSelectAll),
                  ),
                  OutlinedButton.icon(
                    onPressed: isLoading || isExporting
                        ? null
                        : onClearSelection,
                    icon: const Icon(Icons.deselect),
                    label: Text(l10n.pdfEditExtractClearSelection),
                  ),
                  FilledButton.icon(
                    onPressed: isLoading || isExporting || selectedCount == 0
                        ? null
                        : onDownloadSelected,
                    icon: const Icon(Icons.download),
                    label: Text(l10n.pdfEditExtractDownloadSelected),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: isLoading || isExporting || totalCount == 0
                        ? null
                        : onDownloadAll,
                    icon: const Icon(Icons.folder_zip_outlined),
                    label: Text(l10n.pdfEditExtractDownloadAllZip),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
