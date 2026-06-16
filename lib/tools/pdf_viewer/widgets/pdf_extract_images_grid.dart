import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_extract_images_item.dart';

class PdfExtractImagesGrid extends StatelessWidget {
  final List<PdfExtractedImageItem> items;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelected;
  final ValueChanged<PdfExtractedImageItem> onPreview;
  final ValueChanged<PdfExtractedImageItem> onDownload;

  const PdfExtractImagesGrid({
    super.key,
    required this.items,
    required this.selectedIds,
    required this.onToggleSelected,
    required this.onPreview,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      addSemanticIndexes: false,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.98,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selectedIds.contains(item.id);
        return _PdfExtractImageCard(
          item: item,
          isSelected: isSelected,
          onToggleSelected: () => onToggleSelected(item.id),
          onPreview: () => onPreview(item),
          onDownload: () => onDownload(item),
        );
      },
    );
  }
}

class _PdfExtractImageCard extends StatelessWidget {
  final PdfExtractedImageItem item;
  final bool isSelected;
  final VoidCallback onToggleSelected;
  final VoidCallback onPreview;
  final VoidCallback onDownload;

  const _PdfExtractImageCard({
    required this.item,
    required this.isSelected,
    required this.onToggleSelected,
    required this.onPreview,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final filterText = item.filters.isEmpty ? '-' : item.filters.join(', ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPreview,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.file(
                      File(item.path),
                      fit: BoxFit.cover,
                      cacheWidth: 640,
                      filterQuality: FilterQuality.low,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: theme.colorScheme.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onToggleSelected,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Text(
                l10n.pdfEditExtractImagePageDimensions(
                  item.pageNumber,
                  item.width,
                  item.height,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 2),
              child: Text(
                l10n.pdfEditExtractImageBpp(
                  item.bitsPerPixel > 0 ? item.bitsPerPixel.toString() : '-',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
              child: Text(
                l10n.pdfEditExtractImageFilter(filterText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onPreview,
                    icon: const Icon(Icons.zoom_in),
                    label: Text(l10n.pdfEditExtractPreview),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download),
                    label: Text(l10n.pdfEditDownload),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
