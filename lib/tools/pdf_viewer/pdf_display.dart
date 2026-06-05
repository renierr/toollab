import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfDisplay extends StatelessWidget {
  final String filePath;
  final PdfViewerController controller;
  final void Function(int? pageNumber) onPageChanged;
  final VoidCallback onViewerTap;
  final EdgeInsets boundaryMargin;
  final List<PdfViewerPagePaintCallback> pagePaintCallbacks;
  final PdfPageLayoutFunction? layoutPages;
  final void Function(PdfDocument document, PdfViewerController controller)?
  onViewerReady;

  const PdfDisplay({
    super.key,
    required this.filePath,
    required this.controller,
    required this.onPageChanged,
    required this.onViewerTap,
    required this.boundaryMargin,
    required this.pagePaintCallbacks,
    this.layoutPages,
    this.onViewerReady,
  });

  @override
  Widget build(BuildContext context) {
    return PdfViewer.file(
      filePath,
      controller: controller,
      params: PdfViewerParams(
        textSelectionParams: const PdfTextSelectionParams(enabled: true),
        onPageChanged: onPageChanged,
        boundaryMargin: boundaryMargin,
        pagePaintCallbacks: pagePaintCallbacks,
        layoutPages: layoutPages,
        onViewerReady: onViewerReady,
        onGeneralTap: (context, controller, details) {
          onViewerTap();
          return false;
        },
        getPageRenderingScale: (context, page, controller, estimatedScale) =>
            estimatedScale.clamp(1.0, 2.0),
        maxImageBytesCachedOnMemory: 128 * 1024 * 1024,
        scrollPhysics: PdfViewerParams.getScrollPhysics(context),
        interactionDelegateProvider:
            const PdfViewerScrollInteractionDelegateProviderPhysics(),
      ),
    );
  }
}
