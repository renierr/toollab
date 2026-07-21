import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/pdf_viewer/layout_mode.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_viewer_mode.dart';

class PdfOverlayControls extends StatelessWidget {
  final String fileName;
  final PdfViewerController controller;
  final ValueNotifier<int> currentPageNotifier;
  final ValueNotifier<int> totalPagesNotifier;
  final bool visible;
  final PdfViewerMode currentMode;
  final ValueChanged<PdfViewerMode> onModeChanged;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onDownload;
  final VoidCallback? onPrevPage;
  final VoidCallback? onNextPage;

  // Bookmarks
  final VoidCallback onOpenBookmarks;

  // Search
  final bool isSearchingText;
  final TextEditingController searchTextController;
  final VoidCallback onToggleSearch;
  final VoidCallback onPrevMatch;
  final VoidCallback onNextMatch;
  final int currentMatchIndex;
  final int totalMatches;

  // Layout mode
  final PdfLayoutMode currentLayoutMode;
  final Function(PdfLayoutMode mode) onLayoutModeChanged;

  const PdfOverlayControls({
    super.key,
    required this.fileName,
    required this.controller,
    required this.currentPageNotifier,
    required this.totalPagesNotifier,
    required this.visible,
    required this.currentMode,
    required this.onModeChanged,
    required this.onBack,
    required this.onShare,
    required this.onDownload,
    this.onPrevPage,
    this.onNextPage,
    required this.onOpenBookmarks,
    required this.isSearchingText,
    required this.searchTextController,
    required this.onToggleSearch,
    required this.onPrevMatch,
    required this.onNextMatch,
    required this.currentMatchIndex,
    required this.totalMatches,
    required this.currentLayoutMode,
    required this.onLayoutModeChanged,
  });

  Widget _buildNormalHeader(
    BuildContext context,
    ThemeData theme,
    double topPadding,
  ) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.only(
        top: topPadding + 12,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      color: theme.colorScheme.surface.withValues(alpha: 0.95),
      child: Row(
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
            icon: Icon(
              currentMode == PdfViewerMode.sign
                  ? Icons.gesture
                  : currentMode == PdfViewerMode.organize
                  ? Icons.reorder
                  : currentMode == PdfViewerMode.flatten
                  ? Icons.photo_library_outlined
                  : currentMode == PdfViewerMode.extractImages
                  ? Icons.collections_outlined
                  : currentMode == PdfViewerMode.extractText
                  ? Icons.text_snippet_outlined
                  : currentMode == PdfViewerMode.metadata
                  ? Icons.info_outline
                  : currentMode == PdfViewerMode.redact
                  ? Icons.edit_note_outlined
                  : Icons.more_vert,
            ),
            tooltip: l10n.pdfNavMore,
            onSelected: onModeChanged,
            itemBuilder: (context) {
              final menuL10n = AppLocalizations.of(context);
              return [
                if (currentMode != PdfViewerMode.view)
                  PopupMenuItem(
                    value: PdfViewerMode.view,
                    child: Row(
                      children: [
                        const Icon(Icons.visibility_outlined),
                        const SizedBox(width: 8),
                        Text(menuL10n.pdfNavModeView),
                      ],
                    ),
                  ),
                if (currentMode != PdfViewerMode.sign)
                  PopupMenuItem(
                    value: PdfViewerMode.sign,
                    child: Row(
                      children: [
                        const Icon(Icons.gesture),
                        const SizedBox(width: 8),
                        Text(menuL10n.pdfNavModePlaceSignature),
                      ],
                    ),
                  ),
                if (currentMode != PdfViewerMode.organize)
                  PopupMenuItem(
                    value: PdfViewerMode.organize,
                    child: Row(
                      children: [
                        const Icon(Icons.reorder),
                        const SizedBox(width: 8),
                        Text(menuL10n.pdfNavModeOrganizePages),
                      ],
                    ),
                  ),
                if (currentMode != PdfViewerMode.flatten)
                  PopupMenuItem(
                    value: PdfViewerMode.flatten,
                    child: Row(
                      children: [
                        const Icon(Icons.photo_library_outlined),
                        const SizedBox(width: 8),
                        Text(menuL10n.pdfNavModeFlattenPdf),
                      ],
                    ),
                  ),
                if (currentMode != PdfViewerMode.extractImages)
                  PopupMenuItem(
                    value: PdfViewerMode.extractImages,
                    child: Row(
                      children: [
                        const Icon(Icons.collections_outlined),
                        const SizedBox(width: 8),
                        Text(menuL10n.pdfNavModeExtractImages),
                      ],
                    ),
                  ),
                if (currentMode != PdfViewerMode.extractText)
                  PopupMenuItem(
                    value: PdfViewerMode.extractText,
                    child: Row(
                      children: [
                        const Icon(Icons.text_snippet_outlined),
                        const SizedBox(width: 8),
                        Text(menuL10n.pdfNavModeExtractText),
                      ],
                    ),
                  ),
                if (currentMode != PdfViewerMode.metadata)
                  PopupMenuItem(
                    value: PdfViewerMode.metadata,
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline),
                        const SizedBox(width: 8),
                        Text(menuL10n.pdfNavModeMetadata),
                      ],
                    ),
                  ),
                if (currentMode != PdfViewerMode.redact)
                  PopupMenuItem(
                    value: PdfViewerMode.redact,
                    child: Row(
                      children: [
                        const Icon(Icons.edit_note_outlined),
                        const SizedBox(width: 8),
                        Text(menuL10n.pdfNavModeRedact),
                      ],
                    ),
                  ),
              ];
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(
    BuildContext context,
    ThemeData theme,
    double topPadding,
  ) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.only(
        top: topPadding + 12,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      color: theme.colorScheme.surface.withValues(alpha: 0.95),
      child: Row(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          top: visible ? 0 : -100 - topPadding,
          left: 0,
          right: 0,
          child: RepaintBoundary(
            child: isSearchingText
                ? _buildSearchHeader(context, theme, topPadding)
                : _buildNormalHeader(context, theme, topPadding),
          ),
        ),

        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          bottom: visible ? 0 : -120 - bottomPadding,
          left: 0,
          right: 0,
          child: RepaintBoundary(
            child: Container(
              padding: const EdgeInsets.only(
                top: 4,
                bottom: 8,
                left: 12,
                right: 12,
              ),
              color: theme.colorScheme.surface.withValues(alpha: 0.95),
              child: SafeArea(
                top: false,
                child: Wrap(
                  alignment: WrapAlignment.spaceAround,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    // Share / Download
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share_outlined),
                          onPressed: onShare,
                          tooltip: l10n.pdfNavShareFile,
                          iconSize: 16,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.download_outlined),
                          onPressed: onDownload,
                          tooltip: l10n.pdfNavSaveToDownloads,
                          iconSize: 16,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),
                      ],
                    ),

                    // Page Controls
                    ListenableBuilder(
                      listenable: Listenable.merge([
                        currentPageNotifier,
                        totalPagesNotifier,
                      ]),
                      builder: (context, _) {
                        final innerL10n = AppLocalizations.of(context);
                        final currentPage = currentPageNotifier.value;
                        final totalPages = totalPagesNotifier.value;
                        final pageText = totalPages > 0
                            ? innerL10n.pdfNavPageOf(currentPage, totalPages)
                            : innerL10n.pdfNavPageLoading(currentPage);
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: currentPage > 1 ? onPrevPage : null,
                              tooltip: innerL10n.pdfNavPrevPage,
                              iconSize: 16,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                            ),
                            Text(
                              pageText,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed:
                                  totalPages > 0 && currentPage < totalPages
                                  ? onNextPage
                                  : null,
                              tooltip: innerL10n.pdfNavNextPage,
                              iconSize: 16,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    // Zoom Controls
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.zoom_out),
                          onPressed: () => controller.zoomDown(),
                          tooltip: l10n.pdfNavZoomOut,
                          iconSize: 16,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_backup_restore),
                          onPressed: () => controller.setZoom(
                            controller.centerPosition,
                            1.0,
                          ),
                          tooltip: l10n.pdfNavZoomReset,
                          iconSize: 16,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.zoom_in),
                          onPressed: () => controller.zoomUp(),
                          tooltip: l10n.pdfNavZoomIn,
                          iconSize: 16,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
