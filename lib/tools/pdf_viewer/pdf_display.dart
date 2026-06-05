import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfDisplay extends StatelessWidget {
  final String filePath;
  final PdfViewerController controller;
  final void Function(int? pageNumber) onPageChanged;
  final VoidCallback onViewerTap;
  final EdgeInsets boundaryMargin;

  const PdfDisplay({
    super.key,
    required this.filePath,
    required this.controller,
    required this.onPageChanged,
    required this.onViewerTap,
    required this.boundaryMargin,
  });

  @override
  Widget build(BuildContext context) {
    return PdfViewer.file(
      filePath,
      controller: controller,
      params: PdfViewerParams(
        onPageChanged: onPageChanged,
        boundaryMargin: boundaryMargin,
        onGeneralTap: (context, controller, details) {
          onViewerTap();
          return true;
        },
      ),
    );
  }
}
