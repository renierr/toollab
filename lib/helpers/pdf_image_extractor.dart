import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;

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

class PdfImageExtractor {
  PdfImageExtractor._();

  static Future<List<PdfEmbeddedImageData>> extract(
    PdfDocument doc, {
    bool deduplicate = true,
    bool includeAnnotations = true,
    void Function(int done, int total)? onProgress,
  }) async {
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
