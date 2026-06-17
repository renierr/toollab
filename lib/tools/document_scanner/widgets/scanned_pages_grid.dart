import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/document_scanner/document_scanner_state.dart';

class ScannedPagesList extends StatelessWidget {
  final ValueChanged<int> onEditPage;
  final ValueChanged<int> onDeletePage;
  final void Function(int oldIndex, int newIndex) onReorder;

  const ScannedPagesList({
    super.key,
    required this.onEditPage,
    required this.onDeletePage,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = context.watch<DocumentScannerState>();
    final pages = state.pages;

    if (pages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.scanner_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.docScanNoPages,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.docScanAddHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: pages.length,
      buildDefaultDragHandles: false,
      onReorderItem: onReorder,
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final page = pages[index];
        final filterName = page.filter.name.toUpperCase();

        return Card(
          key: ValueKey(page.id),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onEditPage(index),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Icon(
                        Icons.drag_handle,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(page.processedImagePath),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      cacheWidth: 128,
                      cacheHeight: 128,
                      key: ValueKey(
                        page.processedImagePath,
                      ), // Forces reload when image updates
                      errorBuilder: (_, _, _) => Container(
                        width: 64,
                        height: 64,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.docScanPageTitle(index + 1),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${l10n.docScanFilterLabel(filterName)}  •  ${l10n.docScanRotationLabel(page.rotation)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          l10n.docScanSizeLabel(
                            page.width.toInt(),
                            page.height.toInt(),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_note),
                        tooltip: l10n.commonEdit,
                        onPressed: () => onEditPage(index),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error,
                        ),
                        tooltip: l10n.commonDelete,
                        onPressed: () => onDeletePage(index),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
