import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfRedactSelectView extends StatelessWidget {
  final String filePath;
  final PdfPasswordProvider? passwordProvider;
  final ValueChanged<PdfTextSelection> onTextSelectionChange;

  const PdfRedactSelectView({
    super.key,
    required this.filePath,
    required this.passwordProvider,
    required this.onTextSelectionChange,
  });

  @override
  Widget build(BuildContext context) {
    return PdfViewer.file(
      filePath,
      passwordProvider: passwordProvider,
      params: PdfViewerParams(
        textSelectionParams: PdfTextSelectionParams(
          enabled: true,
          onTextSelectionChange: onTextSelectionChange,
        ),
        onViewerReady: (doc, ctrl) {},
        getPageRenderingScale: (ctx, page, ctrl, estimated) {
          return estimated.clamp(1.0, 3.0);
        },
        maxImageBytesCachedOnMemory: 128 * 1024 * 1024,
        scrollPhysics: PdfViewerParams.getScrollPhysics(context),
      ),
    );
  }
}
