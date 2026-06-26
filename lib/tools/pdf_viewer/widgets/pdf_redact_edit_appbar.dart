import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

enum PdfRedactEditMode { draw, select }

class PdfRedactEditAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String fileName;
  final PdfRedactEditMode mode;
  final bool hasTextSelection;
  final int totalMarkCount;
  final VoidCallback onCancel;
  final VoidCallback onModeChange;
  final VoidCallback? onRedactSelected;
  final VoidCallback? onApply;

  const PdfRedactEditAppBar({
    super.key,
    required this.fileName,
    required this.mode,
    required this.hasTextSelection,
    required this.totalMarkCount,
    required this.onCancel,
    required this.onModeChange,
    this.onRedactSelected,
    this.onApply,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return AppBar(
      title: Text(l10n.pdfEditRedactTitle(fileName)),
      leading: IconButton(icon: const Icon(Icons.close), onPressed: onCancel),
      actions: [
        if (mode == PdfRedactEditMode.select)
          IconButton(
            icon: const Icon(Icons.text_fields),
            tooltip: l10n.pdfEditRedactRedactSelected,
            onPressed: hasTextSelection ? onRedactSelected : null,
          ),
        if (mode == PdfRedactEditMode.select)
          IconButton(
            icon: const Icon(Icons.draw),
            tooltip: l10n.pdfEditRedactModeDraw,
            onPressed: onModeChange,
          ),
        if (mode == PdfRedactEditMode.draw)
          IconButton(
            icon: const Icon(Icons.text_fields),
            tooltip: l10n.pdfEditRedactModeSelect,
            onPressed: onModeChange,
          ),
        if (mode == PdfRedactEditMode.draw)
          IconButton(
            icon: Icon(
              Icons.check,
              color: totalMarkCount > 0
                  ? null
                  : theme.colorScheme.onSurface.withValues(alpha: 0.38),
            ),
            tooltip: l10n.commonApply,
            onPressed: totalMarkCount > 0 ? onApply : null,
          ),
      ],
    );
  }
}
