import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class PdfRedactBottomBar extends StatelessWidget {
  final int pageIndex;
  final int pageCount;
  final int totalMarkCount;
  final bool isDrawing;
  final VoidCallback? onPrevPage;
  final VoidCallback? onNextPage;
  final VoidCallback onToggleDraw;

  const PdfRedactBottomBar({
    super.key,
    required this.pageIndex,
    required this.pageCount,
    required this.totalMarkCount,
    required this.isDrawing,
    required this.onToggleDraw,
    this.onPrevPage,
    this.onNextPage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: pageIndex > 0 ? onPrevPage : null,
            ),
            Text(
              l10n.pdfEditRedactPageOf(pageIndex + 1, pageCount),
              style: theme.textTheme.bodyMedium,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: pageIndex < pageCount - 1 ? onNextPage : null,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(isDrawing ? Icons.edit : Icons.pan_tool_outlined),
              tooltip: isDrawing
                  ? l10n.pdfEditRedactModeNavigate
                  : l10n.pdfEditRedactModeDraw,
              onPressed: onToggleDraw,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                totalMarkCount > 0
                    ? l10n.pdfEditRedactDrawHint
                    : l10n.pdfEditRedactSelectHint,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
