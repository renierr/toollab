import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'pdf_redact_bottom_bar.dart';
import 'pdf_redact_overlay.dart';

class PdfRedactDrawView extends StatelessWidget {
  final Uint8List pageImage;
  final List<Rect> marksFrac;
  final double pageAspect;
  final int pageIndex;
  final int pageCount;
  final int totalMarkCount;
  final bool isDrawing;
  final ValueChanged<Rect> onNewMark;
  final ValueChanged<int> onDeleteMark;
  final VoidCallback onPrevPage;
  final VoidCallback onNextPage;
  final VoidCallback onToggleDraw;

  const PdfRedactDrawView({
    super.key,
    required this.pageImage,
    required this.marksFrac,
    required this.pageAspect,
    required this.pageIndex,
    required this.pageCount,
    required this.totalMarkCount,
    required this.isDrawing,
    required this.onNewMark,
    required this.onDeleteMark,
    required this.onPrevPage,
    required this.onNextPage,
    required this.onToggleDraw,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final areaW = constraints.maxWidth;
              final areaH = constraints.maxHeight;
              final dispW = areaW;
              final dispH = dispW / pageAspect;
              final dispLeft = 0.0;
              final dispTop = dispH < areaH ? (areaH - dispH) / 2 : 0.0;

              return InteractiveViewer(
                minScale: 1,
                maxScale: 6,
                constrained: false,
                child: SizedBox(
                  width: areaW,
                  height: max(areaH, dispH),
                  child: Stack(
                    children: [
                      Positioned(
                        left: dispLeft,
                        top: dispTop,
                        width: dispW,
                        height: dispH,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Image.memory(pageImage, fit: BoxFit.fill),
                        ),
                      ),
                      PdfRedactOverlay(
                        marks: marksFrac,
                        dispLeft: dispLeft,
                        dispTop: dispTop,
                        dispW: dispW,
                        dispH: dispH,
                        onDeleteMark: onDeleteMark,
                        onNewMark: onNewMark,
                        isDrawing: isDrawing,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        PdfRedactBottomBar(
          pageIndex: pageIndex,
          pageCount: pageCount,
          totalMarkCount: totalMarkCount,
          isDrawing: isDrawing,
          onPrevPage: onPrevPage,
          onNextPage: onNextPage,
          onToggleDraw: onToggleDraw,
        ),
      ],
    );
  }
}
