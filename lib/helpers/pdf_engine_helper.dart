import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';

enum ImageToPdfPageSize { a4, letter, legal, fit }

class PdfEngineHelper {
  static bool _initialized = false;

  static Future<void> _ensureInit() async {
    if (!_initialized) {
      await pdfrxFlutterInitialize();
      _initialized = true;
    }
  }

  static Future<PdfDocument> openPdf(String path) async {
    await _ensureInit();
    return PdfDocument.openFile(path);
  }

  static Future<PdfDocument> openPdfFromBytes(
    Uint8List data,
    String name,
  ) async {
    await _ensureInit();
    return PdfDocument.openData(data, sourceName: name);
  }

  static Future<Uint8List> renderPageToBytes(
    PdfPage page, {
    int dpi = 150,
    String format = 'png',
    int jpegQuality = 90,
  }) async {
    final w = (page.width * dpi / 72).round();
    final h = (page.height * dpi / 72).round();
    final rendered = await page.render(width: w, height: h);
    if (rendered == null) throw Exception('Failed to render page');
    try {
      final image = rendered.createImageNF();
      final Uint8List bytes;
      if (format == 'jpeg') {
        bytes = Uint8List.fromList(img.encodeJpg(image, quality: jpegQuality));
      } else {
        bytes = Uint8List.fromList(img.encodePng(image));
      }
      return bytes;
    } finally {
      rendered.dispose();
    }
  }

  static Future<Uint8List> renderPageThumbnail(
    PdfPage page, {
    int height = 200,
  }) async {
    final ratio = height / page.height;
    final w = (page.width * ratio).round();
    final h = height;
    final rendered = await page.render(width: w, height: h);
    if (rendered == null) throw Exception('Failed to render thumbnail');
    try {
      final image = rendered.createImageNF();
      return Uint8List.fromList(img.encodeJpg(image, quality: 70));
    } finally {
      rendered.dispose();
    }
  }

  /// Reads and decodes each image from disk one at a time, so the full set of
  /// source images is never held in memory at once.
  static Future<Uint8List> createPdfFromImagePaths(
    List<String> imagePaths, {
    ImageToPdfPageSize pageSize = ImageToPdfPageSize.a4,
    int jpegQuality = 90,
    bool landscape = false,
  }) async {
    await _ensureInit();
    final docs = <PdfDocument>[];
    try {
      for (int i = 0; i < imagePaths.length; i++) {
        final bytes = await File(imagePaths[i]).readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded == null) throw Exception('Failed to decode image $i');

        final jpegData = Uint8List.fromList(
          img.encodeJpg(decoded, quality: jpegQuality),
        );

        final (pw, ph) = _pageSizePoints(pageSize, landscape, decoded);
        final imageDoc = await PdfDocument.createFromJpegData(
          jpegData,
          width: pw,
          height: ph,
          sourceName: 'img_$i.pdf',
        );
        docs.add(imageDoc);
      }

      final result = await PdfDocument.createNew(sourceName: 'combined.pdf');
      result.pages = docs.map((d) => d.pages[0]).toList();
      final bytes = await result.encodePdf();
      result.dispose();
      return bytes;
    } finally {
      for (final d in docs) {
        d.dispose();
      }
    }
  }

  static (double, double) _pageSizePoints(
    ImageToPdfPageSize size,
    bool landscape,
    img.Image image,
  ) {
    final (w, h) = switch (size) {
      ImageToPdfPageSize.a4 => (595.0, 842.0),
      ImageToPdfPageSize.letter => (612.0, 792.0),
      ImageToPdfPageSize.legal => (612.0, 1008.0),
      ImageToPdfPageSize.fit => _fitToImage(image),
    };
    return landscape ? (h, w) : (w, h);
  }

  static (double, double) _fitToImage(img.Image image) {
    const assumedDpi = 150.0;
    final w = image.width * 72 / assumedDpi;
    final h = image.height * 72 / assumedDpi;
    return (w, h);
  }

  static Future<Uint8List> reorganizePdf(
    PdfDocument doc, {
    List<int>? order,
    Set<int>? remove,
  }) async {
    final pages = doc.pages.toList();
    final totalPages = pages.length;
    var indices = List.generate(totalPages, (i) => i);

    if (remove != null && remove.isNotEmpty) {
      indices = indices.where((i) => !remove.contains(i)).toList();
    }

    if (order != null && order.isNotEmpty) {
      indices = order.where((i) => i >= 0 && i < totalPages).toList();
    }

    final newDoc = await PdfDocument.createNew(sourceName: 'reorganized.pdf');
    newDoc.pages = indices.map((i) => pages[i]).toList();
    final bytes = await newDoc.encodePdf();
    newDoc.dispose();
    return bytes;
  }

  static Future<Uint8List> insertPagesFromPdf(
    PdfDocument targetDoc,
    String sourcePdfPath, {
    int atIndex = -1,
    List<int>? sourcePages,
  }) async {
    final sourceDoc = await openPdf(sourcePdfPath);
    try {
      var srcPages = sourceDoc.pages.toList();
      if (sourcePages != null && sourcePages.isNotEmpty) {
        srcPages = sourcePages.map((i) => srcPages[i]).toList();
      }

      final targetPages = targetDoc.pages.toList();
      final insertAt = atIndex < 0
          ? targetPages.length
          : atIndex.clamp(0, targetPages.length);

      targetDoc.pages = [
        ...targetPages.take(insertAt),
        ...srcPages,
        ...targetPages.skip(insertAt),
      ];

      return targetDoc.encodePdf();
    } finally {
      sourceDoc.dispose();
    }
  }

  /// Flattens [doc] into a non-extractable, image-only PDF that preserves each
  /// page's exact size and format. Every page is rasterized at [dpi] and the
  /// image fully fills a new page of the original page's point dimensions, so
  /// the output looks identical to the source (no white margins, same A4/Letter
  /// geometry). [dpi] and [jpegQuality] only affect output quality/size.
  ///
  /// Renders one page at a time and never accumulates page bitmaps on the Dart
  /// heap; PDFium embeds each JPEG inline as it goes.
  static Future<Uint8List> flattenPdfDocument(
    PdfDocument doc, {
    int dpi = 200,
    int jpegQuality = 90,
    void Function(int done, int total)? onProgress,
  }) async {
    await _ensureInit();
    final pages = doc.pages.toList();
    final imageDocs = <PdfDocument>[];
    try {
      for (int i = 0; i < pages.length; i++) {
        final page = pages[i];
        final jpegData = await renderPageToBytes(
          page,
          dpi: dpi,
          format: 'jpeg',
          jpegQuality: jpegQuality,
        );
        // Page size in points (1/72") = original geometry; the image fills it.
        final imageDoc = await PdfDocument.createFromJpegData(
          jpegData,
          width: page.width,
          height: page.height,
          sourceName: 'flat_$i.pdf',
        );
        imageDocs.add(imageDoc);
        onProgress?.call(i + 1, pages.length);
      }

      final result = await PdfDocument.createNew(sourceName: 'flattened.pdf');
      result.pages = imageDocs.map((d) => d.pages[0]).toList();
      final bytes = await result.encodePdf();
      result.dispose();
      return bytes;
    } finally {
      for (final d in imageDocs) {
        d.dispose();
      }
    }
  }
}
