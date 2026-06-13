import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;

enum ImageToPdfPageSize { a4, letter, legal, fit }

class PdfEmbeddedImageData {
  final String id;
  final int pageNumber;
  final int objectIndex;
  final int width;
  final int height;
  final int bitsPerPixel;
  final List<String> filters;
  final String checksum;
  final Uint8List pngBytes;

  const PdfEmbeddedImageData({
    required this.id,
    required this.pageNumber,
    required this.objectIndex,
    required this.width,
    required this.height,
    required this.bitsPerPixel,
    required this.filters,
    required this.checksum,
    required this.pngBytes,
  });
}

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
    // fullWidth/fullHeight set the scale the whole page is rasterized at;
    // without them pdfrx renders at 72-dpi into a corner of the crop.
    final rendered = await page.render(
      fullWidth: w.toDouble(),
      fullHeight: h.toDouble(),
      width: w,
      height: h,
    );
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
    final rendered = await page.render(
      fullWidth: w.toDouble(),
      fullHeight: h.toDouble(),
      width: w,
      height: h,
    );
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
    void Function(int done, int total)? onProgress,
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
        onProgress?.call(i + 1, imagePaths.length);
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

  static Future<List<PdfEmbeddedImageData>> extractEmbeddedImages(
    PdfDocument doc, {
    bool deduplicate = true,
    void Function(int done, int total)? onProgress,
  }) async {
    await _ensureInit();
    final images = <PdfEmbeddedImageData>[];
    final seenHashes = <String>{};

    await doc.useNativeDocumentHandle((nativeDocumentHandle) {
      final pdf = pdfium.getPdfium();
      final documentHandle = pdfium.FPDF_DOCUMENT.fromAddress(
        nativeDocumentHandle,
      );
      final pageCount = pdf.FPDF_GetPageCount(documentHandle);

      for (int pageIndex = 0; pageIndex < pageCount; pageIndex++) {
        final pageHandle = pdf.FPDF_LoadPage(documentHandle, pageIndex);
        if (pageHandle.address == 0) {
          onProgress?.call(pageIndex + 1, pageCount);
          continue;
        }

        try {
          final objectCount = pdf.FPDFPage_CountObjects(pageHandle);
          for (int objectIndex = 0; objectIndex < objectCount; objectIndex++) {
            final objectHandle = pdf.FPDFPage_GetObject(
              pageHandle,
              objectIndex,
            );
            if (objectHandle.address == 0) {
              continue;
            }
            _collectImagesFromObject(
              pdf: pdf,
              documentHandle: documentHandle,
              pageHandle: pageHandle,
              objectHandle: objectHandle,
              pageIndex: pageIndex,
              objectIndex: objectIndex,
              deduplicate: deduplicate,
              seenHashes: seenHashes,
              images: images,
            );
          }
        } finally {
          pdf.FPDF_ClosePage(pageHandle);
          onProgress?.call(pageIndex + 1, pageCount);
        }
      }
    });

    return images;
  }

  static void _collectImagesFromObject({
    required pdfium.PDFium pdf,
    required pdfium.FPDF_DOCUMENT documentHandle,
    required pdfium.FPDF_PAGE pageHandle,
    required pdfium.FPDF_PAGEOBJECT objectHandle,
    required int pageIndex,
    required int objectIndex,
    required bool deduplicate,
    required Set<String> seenHashes,
    required List<PdfEmbeddedImageData> images,
  }) {
    final objectType = pdf.FPDFPageObj_GetType(objectHandle);
    if (objectType == pdfium.FPDF_PAGEOBJ_IMAGE) {
      final item = _extractImageFromObject(
        pdf: pdf,
        documentHandle: documentHandle,
        pageHandle: pageHandle,
        objectHandle: objectHandle,
        pageIndex: pageIndex,
        objectIndex: objectIndex,
        deduplicate: deduplicate,
        seenHashes: seenHashes,
        serial: images.length + 1,
      );
      if (item != null) {
        images.add(item);
      }
      return;
    }

    if (objectType != pdfium.FPDF_PAGEOBJ_FORM) {
      return;
    }

    final childCount = pdf.FPDFFormObj_CountObjects(objectHandle);
    for (int childIndex = 0; childIndex < childCount; childIndex++) {
      final childHandle = pdf.FPDFFormObj_GetObject(objectHandle, childIndex);
      if (childHandle.address == 0) {
        continue;
      }
      _collectImagesFromObject(
        pdf: pdf,
        documentHandle: documentHandle,
        pageHandle: pageHandle,
        objectHandle: childHandle,
        pageIndex: pageIndex,
        objectIndex: objectIndex,
        deduplicate: deduplicate,
        seenHashes: seenHashes,
        images: images,
      );
    }
  }

  static PdfEmbeddedImageData? _extractImageFromObject({
    required pdfium.PDFium pdf,
    required pdfium.FPDF_DOCUMENT documentHandle,
    required pdfium.FPDF_PAGE pageHandle,
    required pdfium.FPDF_PAGEOBJECT objectHandle,
    required int pageIndex,
    required int objectIndex,
    required bool deduplicate,
    required Set<String> seenHashes,
    required int serial,
  }) {
    final renderedBitmap = pdf.FPDFImageObj_GetRenderedBitmap(
      documentHandle,
      pageHandle,
      objectHandle,
    );
    final bitmapHandle = renderedBitmap.address != 0
        ? renderedBitmap
        : pdf.FPDFImageObj_GetBitmap(objectHandle);

    if (bitmapHandle.address == 0) {
      return null;
    }

    try {
      final width = pdf.FPDFBitmap_GetWidth(bitmapHandle);
      final height = pdf.FPDFBitmap_GetHeight(bitmapHandle);
      final stride = pdf.FPDFBitmap_GetStride(bitmapHandle);
      if (width <= 0 || height <= 0 || stride <= 0) {
        return null;
      }

      final rawPtr = pdf.FPDFBitmap_GetBuffer(bitmapHandle);
      if (rawPtr.address == 0) {
        return null;
      }

      final bufferLength = stride * height;
      final raw = rawPtr.cast<Uint8>().asTypedList(bufferLength);

      final bitmapFormat = pdf.FPDFBitmap_GetFormat(bitmapHandle);
      final pngBytes = _encodeBitmapToPng(
        raw,
        width: width,
        height: height,
        stride: stride,
        bitmapFormat: bitmapFormat,
      );

      final checksum = sha1.convert(pngBytes).toString();
      if (deduplicate && seenHashes.contains(checksum)) {
        return null;
      }
      seenHashes.add(checksum);

      final metadata = calloc<pdfium.FPDF_IMAGEOBJ_METADATA>();
      final bitsPerPixel = (() {
        try {
          final metaLoaded =
              pdf.FPDFImageObj_GetImageMetadata(
                objectHandle,
                pageHandle,
                metadata,
              ) !=
              0;
          if (!metaLoaded) {
            return 0;
          }
          return metadata.ref.bits_per_pixel;
        } finally {
          calloc.free(metadata);
        }
      })();

      final imageWidth = bitsPerPixel > 0
          ? _readImageDimension(pdf, objectHandle, pageHandle, width, true)
          : width;
      final imageHeight = bitsPerPixel > 0
          ? _readImageDimension(pdf, objectHandle, pageHandle, height, false)
          : height;

      final filters = _readImageFilters(pdf, objectHandle);

      return PdfEmbeddedImageData(
        id: 'p${pageIndex + 1}_o${objectIndex + 1}_$serial',
        pageNumber: pageIndex + 1,
        objectIndex: objectIndex,
        width: imageWidth,
        height: imageHeight,
        bitsPerPixel: bitsPerPixel,
        filters: filters,
        checksum: checksum,
        pngBytes: pngBytes,
      );
    } finally {
      pdf.FPDFBitmap_Destroy(bitmapHandle);
    }
  }

  static int _readImageDimension(
    pdfium.PDFium pdf,
    pdfium.FPDF_PAGEOBJECT objectHandle,
    pdfium.FPDF_PAGE pageHandle,
    int fallback,
    bool isWidth,
  ) {
    final metadata = calloc<pdfium.FPDF_IMAGEOBJ_METADATA>();
    try {
      final metaLoaded =
          pdf.FPDFImageObj_GetImageMetadata(
            objectHandle,
            pageHandle,
            metadata,
          ) !=
          0;
      if (!metaLoaded) {
        return fallback;
      }
      final value = isWidth ? metadata.ref.width : metadata.ref.height;
      return value > 0 ? value : fallback;
    } finally {
      calloc.free(metadata);
    }
  }

  static List<String> _readImageFilters(
    pdfium.PDFium pdf,
    pdfium.FPDF_PAGEOBJECT objectHandle,
  ) {
    final count = pdf.FPDFImageObj_GetImageFilterCount(objectHandle);
    if (count <= 0) {
      return const [];
    }

    final filters = <String>[];
    for (int i = 0; i < count; i++) {
      final length = pdf.FPDFImageObj_GetImageFilter(
        objectHandle,
        i,
        nullptr,
        0,
      );
      if (length <= 0) {
        continue;
      }
      final bytesPtr = calloc<Uint8>(length);
      try {
        final written = pdf.FPDFImageObj_GetImageFilter(
          objectHandle,
          i,
          bytesPtr.cast<Void>(),
          length,
        );
        if (written <= 0) {
          continue;
        }
        final value = utf8
            .decode(bytesPtr.asTypedList(written), allowMalformed: true)
            .replaceAll('\u0000', '')
            .trim();
        if (value.isNotEmpty) {
          filters.add(value);
        }
      } finally {
        calloc.free(bytesPtr);
      }
    }
    return filters;
  }

  static Uint8List _encodeBitmapToPng(
    Uint8List bgra, {
    required int width,
    required int height,
    required int stride,
    required int bitmapFormat,
  }) {
    final image = img.Image(width: width, height: height);
    final bytesPerPixel = bitmapFormat == pdfium.FPDFBitmap_BGR ? 3 : 4;
    for (int y = 0; y < height; y++) {
      final rowStart = y * stride;
      for (int x = 0; x < width; x++) {
        final offset = rowStart + x * bytesPerPixel;
        final b = bgra[offset];
        final g = bgra[offset + 1];
        final r = bgra[offset + 2];
        final a = bytesPerPixel == 4 ? bgra[offset + 3] : 255;
        image.setPixelRgba(x, y, r, g, b, a);
      }
    }

    return Uint8List.fromList(img.encodePng(image));
  }
}
