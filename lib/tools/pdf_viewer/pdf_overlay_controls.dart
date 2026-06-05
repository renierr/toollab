import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfOverlayControls extends StatelessWidget {
  final String fileName;
  final PdfViewerController controller;
  final int currentPage;
  final int totalPages;
  final bool visible;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onDownload;

  const PdfOverlayControls({
    super.key,
    required this.fileName,
    required this.controller,
    required this.currentPage,
    required this.totalPages,
    required this.visible,
    required this.onBack,
    required this.onShare,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        // Top Header Overlay
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          top: visible ? 0 : -100 - topPadding,
          left: 0,
          right: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: EdgeInsets.only(
                  top: topPadding + 12,
                  bottom: 12,
                  left: 16,
                  right: 16,
                ),
                color: theme.colorScheme.surface.withValues(alpha: 0.8),
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
              ),
            ),
          ),
        ),

        // Bottom Footer Overlay
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          bottom: visible ? 0 : -120 - bottomPadding,
          left: 0,
          right: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: EdgeInsets.only(
                  top: 12,
                  bottom: bottomPadding + 16,
                  left: 16,
                  right: 16,
                ),
                color: theme.colorScheme.surface.withValues(alpha: 0.8),
                child: SafeArea(
                  top: false,
                  child: Wrap(
                    alignment: WrapAlignment.spaceAround,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      // Page Controls
                      Row(
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
                          ),
                        ],
                      ),

                      // Zoom Controls
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.zoom_out),
                            onPressed: () => controller.zoomDown(),
                            tooltip: 'Zoom Out',
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_backup_restore),
                            onPressed: () => controller.setZoom(
                              controller.centerPosition,
                              1.0,
                            ),
                            tooltip: 'Reset Zoom',
                          ),
                          IconButton(
                            icon: const Icon(Icons.zoom_in),
                            onPressed: () => controller.zoomUp(),
                            tooltip: 'Zoom In',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
