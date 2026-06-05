import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/tools/pdf_viewer/layout_mode.dart';

class PdfOverlayControls extends StatelessWidget {
  final String fileName;
  final PdfViewerController controller;
  final ValueNotifier<int> currentPageNotifier;
  final ValueNotifier<int> totalPagesNotifier;
  final bool visible;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onDownload;

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
    required this.onBack,
    required this.onShare,
    required this.onDownload,
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
            tooltip: 'Back',
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
            tooltip: 'Bookmarks',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: onToggleSearch,
            tooltip: 'Search Text',
          ),
          PopupMenuButton<PdfLayoutMode>(
            icon: const Icon(Icons.layers_outlined),
            tooltip: 'Page Layout',
            onSelected: onLayoutModeChanged,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: PdfLayoutMode.vertical,
                child: Row(
                  children: [
                    Icon(Icons.splitscreen_outlined),
                    SizedBox(width: 8),
                    Text('Vertical Scroll'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: PdfLayoutMode.horizontal,
                child: Row(
                  children: [
                    Icon(Icons.view_week_outlined),
                    SizedBox(width: 8),
                    Text('Horizontal Scroll'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: PdfLayoutMode.doublePage,
                child: Row(
                  children: [
                    Icon(Icons.auto_stories_outlined),
                    SizedBox(width: 8),
                    Text('Double Page View'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: onShare,
            tooltip: 'Share File',
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: onDownload,
            tooltip: 'Save to Downloads',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(ThemeData theme, double topPadding) {
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
            tooltip: 'Close Search',
          ),
          Expanded(
            child: TextField(
              controller: searchTextController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search text...',
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
            tooltip: 'Previous Match',
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: totalMatches > 0 ? onNextMatch : null,
            tooltip: 'Next Match',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                ? _buildSearchHeader(theme, topPadding)
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
                top: 8,
                bottom: 12,
                left: 16,
                right: 16,
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
                    // Page Controls
                    ListenableBuilder(
                      listenable: Listenable.merge([
                        currentPageNotifier,
                        totalPagesNotifier,
                      ]),
                      builder: (context, _) {
                        final currentPage = currentPageNotifier.value;
                        final totalPages = totalPagesNotifier.value > 0
                            ? totalPagesNotifier.value
                            : 1;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: currentPage > 1
                                  ? () => controller.goToPage(
                                      pageNumber: currentPage - 1,
                                    )
                                  : null,
                              tooltip: 'Previous Page',
                              iconSize: 20,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                            Text(
                              'Page $currentPage of $totalPages',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: currentPage < totalPages
                                  ? () => controller.goToPage(
                                      pageNumber: currentPage + 1,
                                    )
                                  : null,
                              tooltip: 'Next Page',
                              iconSize: 20,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
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
                          tooltip: 'Zoom Out',
                          iconSize: 20,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_backup_restore),
                          onPressed: () => controller.setZoom(
                            controller.centerPosition,
                            1.0,
                          ),
                          tooltip: 'Reset Zoom',
                          iconSize: 20,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.zoom_in),
                          onPressed: () => controller.zoomUp(),
                          tooltip: 'Zoom In',
                          iconSize: 20,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
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
