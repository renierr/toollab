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

  const SignatureStampRequest({
    required this.pageIndex,
    required this.pngBytes,
    required this.fx,
    required this.fy,
    required this.fw,
    required this.fh,
  });
}

class PdfEmbeddedImageData {
  final String id;
  final int pageNumber;
  final int objectIndex;
  final int width;
  final int height;
  final int bitsPerPixel;
  final List<String> filters;
  final String checksum;
  final Uint8List bytes;
  final String fileExtension;
  final bool isRawExport;

  const PdfEmbeddedImageData({
    required this.id,
    required this.pageNumber,
    required this.objectIndex,
    required this.width,
    required this.height,
    required this.bitsPerPixel,
    required this.filters,
    required this.checksum,
    required this.bytes,
    required this.fileExtension,
    required this.isRawExport,
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

class _RawImageExportFormat {
  final String fileExtension;

  const _RawImageExportFormat(this.fileExtension);
}

class _ExtractionProgress {
  final void Function(int done, int total)? onProgress;
  int done;
  int total;
  int _lastReportedDone = -1;

  _ExtractionProgress({
    required this.onProgress,
    required this.done,
    required this.total,
  });

  void addTotal(int value) {
    if (value <= 0) {
      return;
    }
    total += value;
    _emit(force: true);
  }

  void step([int value = 1]) {
    done += value;
    _emit();
  }

  void complete() {
    if (done < total) {
      done = total;
    }
    _emit(force: true);
  }

  void _emit({bool force = false}) {
    if (onProgress == null) {
      return;
    }
    final safeTotal = total <= 0 ? 1 : total;
    if (!force && done != safeTotal && (done - _lastReportedDone) < 8) {
      return;
    }
    _lastReportedDone = done;
    onProgress!(done.clamp(0, safeTotal), safeTotal);
  }
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
            final x = stamp.fx * pageW;
            final wPts = stamp.fw * pageW;
            final hPts = stamp.fh * pageH;
            final yBottom = pageH * (1 - stamp.fy - stamp.fh);

            final imageObject = pdf.FPDFPageObj_NewImageObj(documentHandle);
            pdf.FPDFImageObj_SetBitmap(nullptr, 0, imageObject, bitmap);
            pdf.FPDFImageObj_SetMatrix(
              imageObject,
              wPts,
              0,
              0,
              hPts,
              x,
              yBottom,
            );

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
    final images = <PdfEmbeddedImageData>[];
    final seenHashes = <String>{};

    await doc.useNativeDocumentHandle((nativeDocumentHandle) async {
      final pdf = pdfium.getPdfium();
      final documentHandle = pdfium.FPDF_DOCUMENT.fromAddress(
        nativeDocumentHandle,
      );
      final pageCount = pdf.FPDF_GetPageCount(documentHandle);
      final progress = _ExtractionProgress(
        onProgress: onProgress,
        done: 0,
        total: pageCount > 0 ? pageCount : 1,
      );
      var uiYieldCounter = 0;

      Future<void> yieldToUi() async {
        uiYieldCounter++;
        if (uiYieldCounter % 24 != 0) {
          return;
        }
        await Future<void>.delayed(Duration.zero);
      }

      for (int pageIndex = 0; pageIndex < pageCount; pageIndex++) {
        final pageHandle = pdf.FPDF_LoadPage(documentHandle, pageIndex);
        if (pageHandle.address == 0) {
          progress.step();
          await yieldToUi();
          continue;
        }

        try {
          final objectCount = pdf.FPDFPage_CountObjects(pageHandle);
          progress.addTotal(objectCount);
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
              progress: progress,
            );
            await yieldToUi();
          }

          if (includeAnnotations) {
            await _collectImagesFromAnnotations(
              pdf: pdf,
              documentHandle: documentHandle,
              pageHandle: pageHandle,
              pageIndex: pageIndex,
              deduplicate: deduplicate,
              seenHashes: seenHashes,
              images: images,
              progress: progress,
              onChunkProcessed: yieldToUi,
            );
          }
        } finally {
          pdf.FPDF_ClosePage(pageHandle);
          progress.step();
          await yieldToUi();
        }
      }

      progress.complete();
    });

    return images;
  }

  static Future<void> _collectImagesFromAnnotations({
    required pdfium.PDFium pdf,
    required pdfium.FPDF_DOCUMENT documentHandle,
    required pdfium.FPDF_PAGE pageHandle,
    required int pageIndex,
    required bool deduplicate,
    required Set<String> seenHashes,
    required List<PdfEmbeddedImageData> images,
    required _ExtractionProgress progress,
    Future<void> Function()? onChunkProcessed,
  }) async {
    final annotCount = pdf.FPDFPage_GetAnnotCount(pageHandle);
    if (annotCount <= 0) {
      return;
    }

    for (int annotIndex = 0; annotIndex < annotCount; annotIndex++) {
      final annotHandle = pdf.FPDFPage_GetAnnot(pageHandle, annotIndex);
      if (annotHandle.address == 0) {
        continue;
      }

      try {
        final objectCount = pdf.FPDFAnnot_GetObjectCount(annotHandle);
        if (objectCount <= 0) {
          continue;
        }
        progress.addTotal(objectCount);

        for (int objectIndex = 0; objectIndex < objectCount; objectIndex++) {
          final objectHandle = pdf.FPDFAnnot_GetObject(
            annotHandle,
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
            objectIndex: 1000000 + annotIndex * 1000 + objectIndex,
            deduplicate: deduplicate,
            seenHashes: seenHashes,
            images: images,
            progress: progress,
          );
          if (onChunkProcessed != null) {
            await onChunkProcessed();
          }
        }
      } finally {
        pdf.FPDFPage_CloseAnnot(annotHandle);
      }
    }
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
    required _ExtractionProgress progress,
  }) {
    progress.step();
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
    progress.addTotal(childCount);
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
        progress: progress,
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
    final rawFormat = _tryDetectRawExportFormat(
      pdf: pdf,
      objectHandle: objectHandle,
    );
    if (rawFormat != null) {
      final rawBytes = _tryReadRawImageBytes(
        pdf: pdf,
        objectHandle: objectHandle,
      );
      if (rawBytes != null && rawBytes.isNotEmpty) {
        final rawChecksum = sha1.convert(rawBytes).toString();
        if (!deduplicate || !seenHashes.contains(rawChecksum)) {
          seenHashes.add(rawChecksum);
          final metadata = _readImageMetadata(
            pdf: pdf,
            objectHandle: objectHandle,
            pageHandle: pageHandle,
          );
          final filters = _readImageFilters(pdf, objectHandle);
          return PdfEmbeddedImageData(
            id: 'p${pageIndex + 1}_o${objectIndex + 1}_$serial',
            pageNumber: pageIndex + 1,
            objectIndex: objectIndex,
            width: metadata.width,
            height: metadata.height,
            bitsPerPixel: metadata.bitsPerPixel,
            filters: filters,
            checksum: rawChecksum,
            bytes: rawBytes,
            fileExtension: rawFormat.fileExtension,
            isRawExport: true,
          );
        }
      }
    }

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

      final metadata = _readImageMetadata(
        pdf: pdf,
        objectHandle: objectHandle,
        pageHandle: pageHandle,
        fallbackWidth: width,
        fallbackHeight: height,
      );

      final filters = _readImageFilters(pdf, objectHandle);

      return PdfEmbeddedImageData(
        id: 'p${pageIndex + 1}_o${objectIndex + 1}_$serial',
        pageNumber: pageIndex + 1,
        objectIndex: objectIndex,
        width: metadata.width,
        height: metadata.height,
        bitsPerPixel: metadata.bitsPerPixel,
        filters: filters,
        checksum: checksum,
        bytes: pngBytes,
        fileExtension: 'png',
        isRawExport: false,
      );
    } finally {
      pdf.FPDFBitmap_Destroy(bitmapHandle);
    }
  }

  static _RawImageExportFormat? _tryDetectRawExportFormat({
    required pdfium.PDFium pdf,
    required pdfium.FPDF_PAGEOBJECT objectHandle,
  }) {
    final filters = _readImageFilters(pdf, objectHandle);
    for (final filter in filters) {
      final normalized = filter.trim().toLowerCase();
      if (normalized == 'dctdecode') {
        return const _RawImageExportFormat('jpg');
      }
      if (normalized == 'jpxdecode') {
        return const _RawImageExportFormat('jp2');
      }
    }
    return null;
  }

  static Uint8List? _tryReadRawImageBytes({
    required pdfium.PDFium pdf,
    required pdfium.FPDF_PAGEOBJECT objectHandle,
  }) {
    final rawLength = pdf.FPDFImageObj_GetImageDataRaw(
      objectHandle,
      nullptr,
      0,
    );
    if (rawLength <= 0) {
      return null;
    }
    final rawPtr = calloc<Uint8>(rawLength);
    try {
      final written = pdf.FPDFImageObj_GetImageDataRaw(
        objectHandle,
        rawPtr.cast<Void>(),
        rawLength,
      );
      if (written <= 0) {
        return null;
      }
      return Uint8List.fromList(rawPtr.asTypedList(written));
    } finally {
      calloc.free(rawPtr);
    }
  }

  static ({int width, int height, int bitsPerPixel}) _readImageMetadata({
    required pdfium.PDFium pdf,
    required pdfium.FPDF_PAGEOBJECT objectHandle,
    required pdfium.FPDF_PAGE pageHandle,
    int? fallbackWidth,
    int? fallbackHeight,
  }) {
    final metadata = calloc<pdfium.FPDF_IMAGEOBJ_METADATA>();
    try {
      final metaLoaded =
          pdf.FPDFImageObj_GetImageMetadata(
            objectHandle,
            pageHandle,
            metadata,
          ) !=
          0;
      final width = metaLoaded && metadata.ref.width > 0
          ? metadata.ref.width
          : (fallbackWidth ?? 0);
      final height = metaLoaded && metadata.ref.height > 0
          ? metadata.ref.height
          : (fallbackHeight ?? 0);
      final bitsPerPixel = metaLoaded ? metadata.ref.bits_per_pixel : 0;
      return (width: width, height: height, bitsPerPixel: bitsPerPixel);
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
