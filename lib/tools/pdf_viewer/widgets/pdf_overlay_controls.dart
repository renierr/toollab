import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/pdf_viewer/layout_mode.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_viewer_mode.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_overlay_header.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final viewPadding = MediaQuery.paddingOf(context);
    final topPadding = viewPadding.top;
    final bottomPadding = viewPadding.bottom;

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
                ? PdfOverlaySearchHeader(
                    topPadding: topPadding,
                    searchTextController: searchTextController,
                    onToggleSearch: onToggleSearch,
                    onPrevMatch: onPrevMatch,
                    onNextMatch: onNextMatch,
                    currentMatchIndex: currentMatchIndex,
                    totalMatches: totalMatches,
                  )
                : PdfOverlayNormalHeader(
                    fileName: fileName,
                    topPadding: topPadding,
                    currentMode: currentMode,
                    onModeChanged: onModeChanged,
                    onBack: onBack,
                    onOpenBookmarks: onOpenBookmarks,
                    onToggleSearch: onToggleSearch,
                  ),
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
