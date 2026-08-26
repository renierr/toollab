import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_viewer_mode.dart';

IconData _modeIcon(PdfViewerMode mode) => switch (mode) {
  PdfViewerMode.sign => Icons.gesture,
  PdfViewerMode.organize => Icons.reorder,
  PdfViewerMode.flatten => Icons.photo_library_outlined,
  PdfViewerMode.extractImages => Icons.collections_outlined,
  PdfViewerMode.extractText => Icons.text_snippet_outlined,
  PdfViewerMode.metadata => Icons.info_outline,
  PdfViewerMode.redact => Icons.edit_note_outlined,
  PdfViewerMode.view => Icons.more_vert,
};

String _modeLabel(PdfViewerMode mode, AppLocalizations l10n) => switch (mode) {
  PdfViewerMode.view => l10n.pdfNavModeView,
  PdfViewerMode.sign => l10n.pdfNavModePlaceSignature,
  PdfViewerMode.organize => l10n.pdfNavModeOrganizePages,
  PdfViewerMode.flatten => l10n.pdfNavModeFlattenPdf,
  PdfViewerMode.extractImages => l10n.pdfNavModeExtractImages,
  PdfViewerMode.extractText => l10n.pdfNavModeExtractText,
  PdfViewerMode.metadata => l10n.pdfNavModeMetadata,
  PdfViewerMode.redact => l10n.pdfNavModeRedact,
};

class _HeaderBar extends StatelessWidget {
  final double topPadding;
  final List<Widget> children;

  const _HeaderBar({required this.topPadding, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.only(
        top: topPadding + 12,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      color: theme.colorScheme.surface.withValues(alpha: 0.95),
      child: Row(children: children),
    );
  }
}

class PdfOverlayNormalHeader extends StatelessWidget {
  final String fileName;
  final double topPadding;
  final PdfViewerMode currentMode;
  final ValueChanged<PdfViewerMode> onModeChanged;
  final VoidCallback onBack;
  final VoidCallback onOpenBookmarks;
  final VoidCallback onToggleSearch;

  const PdfOverlayNormalHeader({
    super.key,
    required this.fileName,
    required this.topPadding,
    required this.currentMode,
    required this.onModeChanged,
    required this.onBack,
    required this.onOpenBookmarks,
    required this.onToggleSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return _HeaderBar(
      topPadding: topPadding,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
          tooltip: l10n.commonBack,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            fileName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.menu_book),
          onPressed: onOpenBookmarks,
          tooltip: l10n.pdfNavBookmarks,
        ),
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: onToggleSearch,
          tooltip: l10n.pdfNavSearchText,
        ),
        PopupMenuButton<PdfViewerMode>(
          icon: Icon(_modeIcon(currentMode)),
          tooltip: l10n.pdfNavMore,
          onSelected: onModeChanged,
          itemBuilder: (context) {
            final menuL10n = AppLocalizations.of(context);
            return [
              for (final mode in PdfViewerMode.values)
                if (mode != currentMode)
                  PopupMenuItem(
                    value: mode,
                    child: Row(
                      children: [
                        Icon(
                          mode == PdfViewerMode.view
                              ? Icons.visibility_outlined
                              : _modeIcon(mode),
                        ),
                        const SizedBox(width: 8),
                        Text(_modeLabel(mode, menuL10n)),
                      ],
                    ),
                  ),
            ];
          },
        ),
      ],
    );
  }
}

class PdfOverlaySearchHeader extends StatelessWidget {
  final double topPadding;
  final TextEditingController searchTextController;
  final VoidCallback onToggleSearch;
  final VoidCallback onPrevMatch;
  final VoidCallback onNextMatch;
  final int currentMatchIndex;
  final int totalMatches;

  const PdfOverlaySearchHeader({
    super.key,
    required this.topPadding,
    required this.searchTextController,
    required this.onToggleSearch,
    required this.onPrevMatch,
    required this.onNextMatch,
    required this.currentMatchIndex,
    required this.totalMatches,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return _HeaderBar(
      topPadding: topPadding,
      children: [
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: onToggleSearch,
          tooltip: l10n.pdfNavCloseSearch,
        ),
        Expanded(
          child: TextField(
            controller: searchTextController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.pdfNavSearchHint,
              border: InputBorder.none,
            ),
            style: theme.textTheme.bodyMedium,
            onSubmitted: (_) => onNextMatch(),
          ),
        ),
        if (totalMatches > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              '${currentMatchIndex + 1}/$totalMatches',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up),
          onPressed: totalMatches > 0 ? onPrevMatch : null,
          tooltip: l10n.pdfNavPrevMatch,
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: totalMatches > 0 ? onNextMatch : null,
          tooltip: l10n.pdfNavNextMatch,
        ),
      ],
    );
  }
}
