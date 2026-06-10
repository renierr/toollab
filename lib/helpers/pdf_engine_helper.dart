import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';

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

  static Future<Uint8List> createPdfFromImages(
    List<Uint8List> imageBytes, {
    ImageToPdfPageSize pageSize = ImageToPdfPageSize.a4,
    int jpegQuality = 90,
    bool landscape = false,
  }) async {
    await _ensureInit();
    final docs = <PdfDocument>[];
    try {
      for (int i = 0; i < imageBytes.length; i++) {
        final decoded = img.decodeImage(imageBytes[i]);
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

    doc.pages = indices.map((i) => pages[i]).toList();
    return doc.encodePdf();
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

  static Future<Uint8List> flattenPdf(
    PdfDocument doc, {
    int dpi = 200,
    int jpegQuality = 90,
    String format = 'jpeg',
  }) async {
    final images = <Uint8List>[];
    final pages = doc.pages.toList();
    for (int i = 0; i < pages.length; i++) {
      final bytes = await renderPageToBytes(
        pages[i],
        dpi: dpi,
        format: format,
        jpegQuality: jpegQuality,
      );
      images.add(bytes);
    }
    return createPdfFromImages(
      images,
      pageSize: ImageToPdfPageSize.fit,
      jpegQuality: jpegQuality,
    );
  }

  static Future<String> savePdfToTemp(Uint8List bytes, String name) async {
    final safeName = name.replaceAll(RegExp(r'[^\w\-.]'), '_');
    return TempFileManager.createFile(safeName, bytes: bytes);
  }
}
