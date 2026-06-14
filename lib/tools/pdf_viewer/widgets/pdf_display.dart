import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfDisplay extends StatelessWidget {
  final String filePath;
  final PdfViewerController controller;
  final PdfPasswordProvider? passwordProvider;
  final void Function(PdfDocumentRef documentRef, bool succeeded)?
  onDocumentLoadFinished;
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
    this.passwordProvider,
    this.onDocumentLoadFinished,
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
      passwordProvider: passwordProvider,
      controller: controller,
      params: PdfViewerParams(
        textSelectionParams: const PdfTextSelectionParams(enabled: true),
        onPageChanged: onPageChanged,
        boundaryMargin: boundaryMargin,
        pagePaintCallbacks: pagePaintCallbacks,
        layoutPages: layoutPages,
        onViewerReady: onViewerReady,
        onDocumentLoadFinished: onDocumentLoadFinished,
        onGeneralTap: (context, controller, details) {
          onViewerTap();
          return false;
        },
        getPageRenderingScale: (context, page, controller, estimatedScale) {
          final scale = estimatedScale.clamp(1.0, 3.0);
          final maxDim = max(page.width, page.height);
          if (maxDim * scale > 2500) return 2500 / maxDim;
          return scale;
        },
        maxImageBytesCachedOnMemory: 256 * 1024 * 1024,
        scrollByMouseWheel: 2,
        scrollPhysics: PdfViewerParams.getScrollPhysics(context),
        interactionDelegateProvider:
            const PdfViewerScrollInteractionDelegateProviderPhysics(
              panFriction: 6.0,
            ),
        sizeDelegateProvider: const PdfViewerSizeDelegateProviderSmart(
          smartMaxScale: 2.0,
        ),
        behaviorControlParams: const PdfViewerBehaviorControlParams(
          partialImageLoadingDelay: Duration(milliseconds: 200),
        ),
        horizontalCacheExtent: 0.5,
        verticalCacheExtent: 0.5,
      ),
    );
  }
}
