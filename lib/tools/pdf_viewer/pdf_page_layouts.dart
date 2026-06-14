import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfPageLayouts {
  PdfPageLayouts._();

  static PdfPageLayout horizontal(List<PdfPage> pages, PdfViewerParams params) {
    final height =
        pages.fold(
          0.0,
          (prev, page) => prev > page.height ? prev : page.height,
        ) +
        params.margin * 2;
    final pageLayouts = <Rect>[];
    double x = params.margin;
    for (final page in pages) {
      pageLayouts.add(
        Rect.fromLTWH(x, (height - page.height) / 2, page.width, page.height),
      );
      x += page.width + params.margin;
    }
    return PdfPageLayout(
      pageLayouts: pageLayouts,
      documentSize: Size(x, height),
    );
  }

  static PdfPageLayout doublePage(List<PdfPage> pages, PdfViewerParams params) {
    final pageLayouts = <Rect>[];
    double y = params.margin;
    double maxWidth = 0;
    for (int i = 0; i < pages.length; i += 2) {
      final page1 = pages[i];
      final hasSecond = i + 1 < pages.length;
      final page2 = hasSecond ? pages[i + 1] : null;
      final rowHeight = page2 == null
          ? page1.height
          : math.max(page1.height, page2.height);
      final rowWidth = page1.width + (page2?.width ?? 0.0) + params.margin;
      maxWidth = math.max(maxWidth, rowWidth);
      pageLayouts.add(
        Rect.fromLTWH(
          params.margin,
          y + (rowHeight - page1.height) / 2,
          page1.width,
          page1.height,
        ),
      );
      if (page2 != null) {
        pageLayouts.add(
          Rect.fromLTWH(
            params.margin + page1.width + params.margin,
            y + (rowHeight - page2.height) / 2,
            page2.width,
            page2.height,
          ),
        );
      }
      y += rowHeight + params.margin;
    }
    return PdfPageLayout(
      pageLayouts: pageLayouts,
      documentSize: Size(maxWidth + params.margin * 2, y),
    );
  }
}
