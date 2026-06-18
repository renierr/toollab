import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/document_scanner/document_scanner_state.dart';
import 'package:tool_lab/tools/document_scanner/utils/document_filters.dart';

class PageEditor extends StatelessWidget {
  final ScannedPage page;
  final int pageIndex;
  final VoidCallback onBack;
  final VoidCallback onAdjustCrop;
  final Future<void> Function(DocumentFilterType filter) onFilterChanged;
  final Future<void> Function(int angle) onRotate;
  final Color accentColor;

  const PageEditor({
    super.key,
    required this.page,
    required this.pageIndex,
    required this.onBack,
    required this.onAdjustCrop,
    required this.onFilterChanged,
    required this.onRotate,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.docScanEditPageTitle(pageIndex + 1)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      ),
      body: Column(
        children: [
          // 1. Processed Image Preview
          Expanded(
            child: Container(
              color: Colors.black12,
              padding: const EdgeInsets.all(16),
              child: Center(
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(page.processedImagePath),
                      key: ValueKey(
                        page.processedImagePath,
                      ), // Force reload when file content changes
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Editing controls
          SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.dividerColor, width: 0.5),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Action buttons
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _ActionButton(
                          icon: Icons.crop_outlined,
                          label: l10n.docScanCropWarp,
                          onPressed: onAdjustCrop,
                          primary: true,
                          accentColor: accentColor,
                        ),
                        const SizedBox(width: 8),
                        _ActionButton(
                          icon: Icons.rotate_left_outlined,
                          label: l10n.docScanRotateL,
                          onPressed: () => onRotate(-90),
                        ),
                        const SizedBox(width: 8),
                        _ActionButton(
                          icon: Icons.rotate_right_outlined,
                          label: l10n.docScanRotateR,
                          onPressed: () => onRotate(90),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Filters selection
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.docScanFiltersHeading,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: DocumentFilterType.values.map((filterType) {
                        final isSelected = page.filter == filterType;
                        final label = switch (filterType) {
                          DocumentFilterType.none => l10n.docScanFilterOriginal,
                          DocumentFilterType.grayscale =>
                            l10n.docScanFilterGrayscale,
                          DocumentFilterType.bw => l10n.docScanFilterBw,
                          DocumentFilterType.clean => l10n.docScanFilterClean,
                        };

                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                onFilterChanged(filterType);
                              }
                            },
                            selectedColor: accentColor.withValues(alpha: 0.2),
                            side: isSelected
                                ? BorderSide(color: accentColor, width: 1.5)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final Color? accentColor;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (primary && accentColor != null) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: theme.colorScheme.onSurface),
      label: Text(label, style: TextStyle(color: theme.colorScheme.onSurface)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
