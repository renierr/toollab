import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;
import 'package:tool_lab/helpers/pdf_image_extractor.dart';

export 'package:tool_lab/helpers/pdf_image_extractor.dart'
    show PdfEmbeddedImageData;

enum ImageToPdfPageSize { a4, letter, legal, fit }

/// A request to stamp one signature image onto a PDF page.
///
/// Position is expressed as a fraction (0..1) of the page in top-left origin
/// space (matching how the UI lays the overlay over a rendered page image).
class SignatureStampRequest {
  final int pageIndex;
  final Uint8List pngBytes;
  final double fx;
  final double fy;
  final double fw;
  final double fh;

  /// Clockwise rotation in radians (UI/screen convention), about the center.
  final double rotation;

  const SignatureStampRequest({
    required this.pageIndex,
    required this.pngBytes,
    required this.fx,
    required this.fy,
    required this.fw,
    required this.fh,
    this.rotation = 0,
  });
}

class PdfDocumentMetadata {
  final String title;
  final String author;
  final String subject;
  final String keywords;
  final String creator;
  final String producer;
  final String creationDate;
  final String modificationDate;
  final String trapped;
  final String pdfVersion;
  final int pageCount;
  final double widthPoints;
  final double heightPoints;
  final int fileSize;

  const PdfDocumentMetadata({
    required this.title,
    required this.author,
    required this.subject,
    required this.keywords,
    required this.creator,
    required this.producer,
    required this.creationDate,
    required this.modificationDate,
    required this.trapped,
    required this.pdfVersion,
    required this.pageCount,
    required this.widthPoints,
    required this.heightPoints,
    required this.fileSize,
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

  static Future<PdfDocument> openPdfWithPassword(
    String path, {
    PdfPasswordProvider? passwordProvider,
  }) async {
    await _ensureInit();
    return PdfDocument.openFile(path, passwordProvider: passwordProvider);
  }

  static Future<PdfDocumentMetadata> readMetadata(
    PdfDocument doc,
    String filePath,
  ) async {
    await _ensureInit();
    final file = File(filePath);
    final fileSize = await file.exists() ? await file.length() : 0;

    final pageCount = doc.pages.length;
    final firstPage = doc.pages.isNotEmpty ? doc.pages.first : null;
    final widthPoints = firstPage?.width ?? 0.0;
    final heightPoints = firstPage?.height ?? 0.0;

    return doc.useNativeDocumentHandle((nativeDocumentHandle) async {
      final pdf = pdfium.getPdfium();
      final documentHandle = pdfium.FPDF_DOCUMENT.fromAddress(
        nativeDocumentHandle,
      );

      final versionPtr = calloc<Int>();
      String pdfVersion = 'Unknown';
      try {
        final success =
            pdf.FPDF_GetFileVersion(documentHandle, versionPtr) != 0;
        if (success) {
          final verInt = versionPtr.value;
          pdfVersion = '${verInt / 10}';
        }
      } catch (_) {
      } finally {
        calloc.free(versionPtr);
      }

      String readTag(String tag) {
        final tagBytes = tag.toNativeUtf8();
        try {
          final byteCount = pdf.FPDF_GetMetaText(
            documentHandle,
            tagBytes.cast(),
            nullptr,
            0,
          );
          if (byteCount <= 2) {
            return '';
          }
          final buffer = calloc<Uint8>(byteCount);
          try {
            final written = pdf.FPDF_GetMetaText(
              documentHandle,
              tagBytes.cast(),
              buffer.cast(),
              byteCount,
            );
            if (written <= 2) {
              return '';
            }
            final bytes = buffer.asTypedList(written);
            final codeUnits = bytes.buffer.asUint16List(
              bytes.offsetInBytes,
              bytes.lengthInBytes ~/ 2,
            );
            final text = String.fromCharCodes(codeUnits);
            return text
                .replaceAll('\u0000', '')
                .replaceAll('\uFEFF', '')
                .trim();
          } finally {
            calloc.free(buffer);
          }
        } finally {
          calloc.free(tagBytes);
        }
      }

      return PdfDocumentMetadata(
        title: readTag('Title'),
        author: readTag('Author'),
        subject: readTag('Subject'),
        keywords: readTag('Keywords'),
        creator: readTag('Creator'),
        producer: readTag('Producer'),
        creationDate: readTag('CreationDate'),
        modificationDate: readTag('ModDate'),
        trapped: readTag('Trapped'),
        pdfVersion: pdfVersion,
        pageCount: pageCount,
        widthPoints: widthPoints,
        heightPoints: heightPoints,
        fileSize: fileSize,
      );
    });
  }

  static Future<Uint8List> createUnsecuredCopy(PdfDocument doc) async {
    await _ensureInit();

    final removedByFlag = await doc.encodePdf(removeSecurity: true);
    try {
      final verify = await openPdfFromBytes(
        removedByFlag,
        'verify_unsecured.pdf',
      );
      await verify.dispose();
      return removedByFlag;
    } catch (_) {
      // Fallback path for PDFs where save flag does not fully remove security.
    }

    final cleanDoc = await PdfDocument.createNew(
      sourceName: 'unsecured_copy.pdf',
    );
    try {
      cleanDoc.pages = doc.pages.toList();
      return await cleanDoc.encodePdf();
    } finally {
      await cleanDoc.dispose();
    }
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

      return await targetDoc.encodePdf();
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

  /// Permanently removes content in the given redaction rectangles and paints
  /// solid black filled rectangles over those areas.
  ///
  /// [redactionMarks] maps a zero-based page index to a list of rectangles in
  /// PDF points (bottom-left origin). The method:
  /// 1. Recursively walks page objects (including Form XObject children) and
  ///    removes/deactivates those overlapping redaction areas.
  /// 2. Inserts solid black filled rectangles over each area.
  /// 3. Regenerates the content stream via FPDFPage_GenerateContent.
  /// 4. Re-hosts the modified pages into a new document to strip the
  ///    /StructTreeRoot (tagged PDF text layer), ensuring text is truly gone.
  static Future<Uint8List> redactPdfDocument(
    PdfDocument doc,
    Map<int, List<Rect>> redactionMarks, {
    void Function(int done, int total)? onProgress,
  }) async {
    await _ensureInit();
    if (redactionMarks.isEmpty) return doc.encodePdf();

    final pages = doc.pages.toList();
    final count = pages.length;

    await doc.useNativeDocumentHandle((nativeDocumentHandle) async {
      final pdf = pdfium.getPdfium();
      final documentHandle = pdfium.FPDF_DOCUMENT.fromAddress(
        nativeDocumentHandle,
      );

      for (int pageIdx = 0; pageIdx < count; pageIdx++) {
        final marks = redactionMarks[pageIdx];
        if (marks == null || marks.isEmpty) {
          onProgress?.call(pageIdx + 1, count);
          continue;
        }

        final pageHandle = pdf.FPDF_LoadPage(documentHandle, pageIdx);
        if (pageHandle.address == 0) {
          onProgress?.call(pageIdx + 1, count);
          continue;
        }

        try {
          _redactPageObjects(
            pdf: pdf,
            pageHandle: pageHandle,
            objectHandle: null,
            marks: marks,
          );

          // Also check annotation objects
          final annotCount = pdf.FPDFPage_GetAnnotCount(pageHandle);
          for (int ai = 0; ai < annotCount; ai++) {
            final annotHandle = pdf.FPDFPage_GetAnnot(pageHandle, ai);
            if (annotHandle.address == 0) continue;
            try {
              final annotObjCount = pdf.FPDFAnnot_GetObjectCount(annotHandle);
              for (int oi = 0; oi < annotObjCount; oi++) {
                final obj = pdf.FPDFAnnot_GetObject(annotHandle, oi);
                if (obj.address == 0) continue;
                _tryRemoveObject(
                  pdf: pdf,
                  pageHandle: pageHandle,
                  obj: obj,
                  marks: marks,
                );
              }
            } finally {
              pdf.FPDFPage_CloseAnnot(annotHandle);
            }
          }

          for (final redact in marks) {
            // Dart Rect uses top=smallerY, bottom=largerY. PDF coords:
            // smaller Y = bottom of page (passed as y to CreateNewRect).
            final rectObj = pdf.FPDFPageObj_CreateNewRect(
              redact.left,
              redact.top,
              redact.width,
              redact.height,
            );
            if (rectObj.address == 0) continue;

            pdf.FPDFPageObj_SetFillColor(rectObj, 0, 0, 0, 255);
            pdf.FPDFPath_SetDrawMode(
              rectObj,
              pdfium.FPDF_FILLMODE_ALTERNATE,
              0,
            );
            pdf.FPDFPage_InsertObject(pageHandle, rectObj);
          }

          pdf.FPDFPage_GenerateContent(pageHandle);
        } finally {
          pdf.FPDF_ClosePage(pageHandle);
        }

        onProgress?.call(pageIdx + 1, count);
      }
    });

    // Create a new document and copy all pages to strip the /StructTreeRoot
    // (tagged PDF text layer) and any other catalog-level content references.
    final newDoc = await PdfDocument.createNew(sourceName: 'redacted.pdf');
    newDoc.pages = doc.pages.toList();
    final bytes = await newDoc.encodePdf();
    newDoc.dispose();
    return bytes;
  }

  /// Recursively walks page objects (including Form XObject children) and
  /// removes/deactivates those whose bounds overlap any redaction mark.
  static void _redactPageObjects({
    required pdfium.PDFium pdf,
    required pdfium.FPDF_PAGE pageHandle,
    required pdfium.FPDF_PAGEOBJECT? objectHandle,
    required List<Rect> marks,
  }) {
    final objCount = objectHandle != null
        ? pdf.FPDFFormObj_CountObjects(objectHandle)
        : pdf.FPDFPage_CountObjects(pageHandle);

    for (int i = 0; i < objCount; i++) {
      final obj = objectHandle != null
          ? pdf.FPDFFormObj_GetObject(objectHandle, i)
          : pdf.FPDFPage_GetObject(pageHandle, i);
      if (obj.address == 0) continue;

      final objType = pdf.FPDFPageObj_GetType(obj);

      // Recurse into Form XObjects to find nested content
      if (objType == pdfium.FPDF_PAGEOBJ_FORM) {
        _redactPageObjects(
          pdf: pdf,
          pageHandle: pageHandle,
          objectHandle: obj,
          marks: marks,
        );
      }

      _tryRemoveObject(
        pdf: pdf,
        pageHandle: pageHandle,
        obj: obj,
        marks: marks,
      );
    }
  }

  /// Checks [obj] against all [marks] and removes (or deactivates) it if its
  /// bounds overlap. Text objects are deactivated via SetIsActive(false);
  /// others are removed via RemoveObject.
  static void _tryRemoveObject({
    required pdfium.PDFium pdf,
    required pdfium.FPDF_PAGE pageHandle,
    required pdfium.FPDF_PAGEOBJECT obj,
    required List<Rect> marks,
  }) {
    final left = calloc<Float>();
    final bottom = calloc<Float>();
    final right = calloc<Float>();
    final top = calloc<Float>();
    try {
      final ok = pdf.FPDFPageObj_GetBounds(obj, left, bottom, right, top);
      if (ok == 0) return;

      final objRect = Rect.fromLTRB(
        left.value,
        bottom.value,
        right.value,
        top.value,
      );

      bool overlaps = false;
      for (final redact in marks) {
        if (objRect.overlaps(redact)) {
          overlaps = true;
          break;
        }
      }
      if (!overlaps) return;

      final objType = pdf.FPDFPageObj_GetType(obj);
      if (objType == pdfium.FPDF_PAGEOBJ_TEXT) {
        // FPDFPage_RemoveObject does not fully remove text from the content
        // stream; deactivating the object causes GenerateContent to skip it.
        pdf.FPDFPageObj_SetIsActive(obj, 0);
      } else {
        final removed = pdf.FPDFPage_RemoveObject(pageHandle, obj);
        if (removed != 0) {
          pdf.FPDFPageObj_Destroy(obj);
        }
      }
    } finally {
      calloc.free(left);
      calloc.free(bottom);
      calloc.free(right);
      calloc.free(top);
    }
  }

  /// Stamps each signature PNG onto its target page as a baked image page
  /// object, then returns the re-encoded PDF bytes.
  ///
  /// The transparent PNG is decoded to BGRA and embedded as an image page
  /// object, positioned via its matrix and committed with
  /// FPDFPage_GenerateContent. Page coordinates are points with a bottom-left
  /// origin, so the top-left UI fraction is flipped vertically.
  static Future<Uint8List> stampSignatureAnnotations(
    PdfDocument doc,
    List<SignatureStampRequest> stamps,
  ) async {
    await _ensureInit();
    if (stamps.isEmpty) return doc.encodePdf();

    final pageSizes = [
      for (final p in doc.pages) (width: p.width, height: p.height),
    ];

    await doc.useNativeDocumentHandle((nativeDocumentHandle) async {
      final pdf = pdfium.getPdfium();
      final documentHandle = pdfium.FPDF_DOCUMENT.fromAddress(
        nativeDocumentHandle,
      );

      for (final stamp in stamps) {
        if (stamp.pageIndex < 0 || stamp.pageIndex >= pageSizes.length) {
          continue;
        }
        final decoded = img.decodeImage(stamp.pngBytes);
        if (decoded == null) continue;

        final rgbaImage = decoded.numChannels == 4
            ? decoded
            : decoded.convert(numChannels: 4);
        final w = rgbaImage.width;
        final h = rgbaImage.height;
        final stride = w * 4;
        final bgra = rgbaImage.getBytes(order: img.ChannelOrder.bgra);

        final buffer = calloc<Uint8>(stride * h);
        try {
          buffer.asTypedList(stride * h).setRange(0, bgra.length, bgra);
          final bitmap = pdf.FPDFBitmap_CreateEx(
            w,
            h,
            pdfium.FPDFBitmap_BGRA,
            buffer.cast<Void>(),
            stride,
          );
          if (bitmap.address == 0) continue;

          final page = pdf.FPDF_LoadPage(documentHandle, stamp.pageIndex);
          if (page.address == 0) {
            pdf.FPDFBitmap_Destroy(bitmap);
            continue;
          }

          try {
            final pageW = pageSizes[stamp.pageIndex].width;
            final pageH = pageSizes[stamp.pageIndex].height;
            final wPts = stamp.fw * pageW;
            final hPts = stamp.fh * pageH;
            // Center in page points (bottom-left origin; flip the top-left UI y).
            final cxp = (stamp.fx + stamp.fw / 2) * pageW;
            final cyp = pageH * (1 - (stamp.fy + stamp.fh / 2));
            // Negate rotation: UI angle is clockwise in a y-down space, PDF is
            // y-up. Matrix maps the unit square's u-axis to (a,b), v to (c,d).
            final theta = -stamp.rotation;
            final cosT = math.cos(theta);
            final sinT = math.sin(theta);
            final a = wPts * cosT;
            final b = wPts * sinT;
            final c = -hPts * sinT;
            final d = hPts * cosT;
            final e = cxp - 0.5 * (a + c);
            final f = cyp - 0.5 * (b + d);

            final imageObject = pdf.FPDFPageObj_NewImageObj(documentHandle);
            pdf.FPDFImageObj_SetBitmap(nullptr, 0, imageObject, bitmap);
            pdf.FPDFImageObj_SetMatrix(imageObject, a, b, c, d, e, f);

            // Bake the image into the page content. STAMP annotations with an
            // appended image are not reliably given an appearance stream by
            // PDFium on save, so they can disappear; a page object always
            // renders and persists through encodePdf().
            pdf.FPDFPage_InsertObject(page, imageObject);
            pdf.FPDFPage_GenerateContent(page);
          } finally {
            pdf.FPDFBitmap_Destroy(bitmap);
            pdf.FPDF_ClosePage(page);
          }
        } finally {
          calloc.free(buffer);
        }
      }
    });

    return doc.encodePdf();
  }

  static Future<List<PdfEmbeddedImageData>> extractEmbeddedImages(
    PdfDocument doc, {
    bool deduplicate = true,
    bool includeAnnotations = true,
    void Function(int done, int total)? onProgress,
  }) async {
    await _ensureInit();
    return PdfImageExtractor.extract(
      doc,
      deduplicate: deduplicate,
      includeAnnotations: includeAnnotations,
      onProgress: onProgress,
    );
  }
}
