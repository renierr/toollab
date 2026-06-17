import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Offset;
import 'package:image/image.dart' as img;
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/tools/document_scanner/utils/perspective_warp.dart';
import 'package:tool_lab/tools/document_scanner/utils/document_filters.dart';
import 'package:tool_lab/tools/document_scanner/utils/auto_crop_detector.dart';

class ScannedPage {
  final String id;
  final String originalFileName;
  final String processedFileName;
  final String originalImagePath;
  final String processedImagePath;
  final List<Offset> corners;
  final DocumentFilterType filter;
  final int rotation; // 0, 90, 180, 270 degrees
  final double width;
  final double height;

  const ScannedPage({
    required this.id,
    required this.originalFileName,
    required this.processedFileName,
    required this.originalImagePath,
    required this.processedImagePath,
    required this.corners,
    required this.filter,
    required this.rotation,
    required this.width,
    required this.height,
  });

  ScannedPage copyWith({
    String? processedFileName,
    String? processedImagePath,
    List<Offset>? corners,
    DocumentFilterType? filter,
    int? rotation,
    double? width,
    double? height,
  }) {
    return ScannedPage(
      id: id,
      originalFileName: originalFileName,
      processedFileName: processedFileName ?? this.processedFileName,
      originalImagePath: originalImagePath,
      processedImagePath: processedImagePath ?? this.processedImagePath,
      corners: corners ?? this.corners,
      filter: filter ?? this.filter,
      rotation: rotation ?? this.rotation,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

class DocumentScannerState extends ChangeNotifier {
  final List<ScannedPage> _pages = [];
  bool _isProcessing = false;
  double _progress = 0.0;
  String _progressText = '';
  int _seq = 0;

  final TempFileScope _tempScope = TempFileManager.createScope();

  List<ScannedPage> get pages => List.unmodifiable(_pages);
  bool get isProcessing => _isProcessing;
  double get progress => _progress;
  String get progressText => _progressText;

  @override
  void dispose() {
    _tempScope.cleanTracked();
    super.dispose();
  }

  void _setProcessing(bool val, {double progress = 0.0, String text = ''}) {
    _isProcessing = val;
    _progress = progress;
    _progressText = text;
    notifyListeners();
  }

  /// Adds a new page from a picked image path.
  Future<void> addPage(String pickedPath) async {
    _setProcessing(true, text: 'Importing image...');
    try {
      final bytes = await File(pickedPath).readAsBytes();

      // Decode and bake orientation so it's upright
      final decoded = await compute(_decodeAndBakeImage, bytes);

      final id = 'page_${_seq++}_${DateTime.now().millisecondsSinceEpoch}';
      final origName = '${id}_original.jpg';
      final origBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
      final originalImagePath = await _tempScope.createFile(
        origName,
        bytes: origBytes,
      );

      // Detect corners
      final corners = AutoCropDetector.detect(decoded);

      // Initial warp & clean filter
      final processedImage = await compute(
        _warpAndFilterImageTask,
        _WarpFilterParams(
          image: decoded,
          corners: corners,
          filter: DocumentFilterType.clean,
          rotation: 0,
        ),
      );

      final procName = '${id}_processed.jpg';
      final procBytes = Uint8List.fromList(
        img.encodeJpg(processedImage, quality: 90),
      );
      final processedImagePath = await _tempScope.createFile(
        procName,
        bytes: procBytes,
      );

      final page = ScannedPage(
        id: id,
        originalFileName: origName,
        processedFileName: procName,
        originalImagePath: originalImagePath,
        processedImagePath: processedImagePath,
        corners: corners,
        filter: DocumentFilterType.clean,
        rotation: 0,
        width: processedImage.width.toDouble(),
        height: processedImage.height.toDouble(),
      );

      _pages.add(page);
    } catch (e) {
      debugPrint('[DocumentScannerState] Failed to add page: $e');
      rethrow;
    } finally {
      _setProcessing(false);
    }
  }

  /// Updates the crop corners of a page.
  Future<void> updatePageCrop(int index, List<Offset> newCorners) async {
    if (index < 0 || index >= _pages.length) return;
    _setProcessing(true, text: 'Warping image...');
    try {
      final page = _pages[index];
      final origBytes = await _tempScope.readFile(page.originalFileName);
      final origImage = img.decodeImage(origBytes);
      if (origImage == null) throw Exception('Failed to decode original image');

      final processedImage = await compute(
        _warpAndFilterImageTask,
        _WarpFilterParams(
          image: origImage,
          corners: newCorners,
          filter: page.filter,
          rotation: page.rotation,
        ),
      );

      final procBytes = Uint8List.fromList(
        img.encodeJpg(processedImage, quality: 90),
      );
      final newProcName =
          '${page.id}_processed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newProcessedImagePath = await _tempScope.createFile(
        newProcName,
        bytes: procBytes,
      );

      try {
        await _tempScope.deleteFile(page.processedFileName);
      } catch (_) {}

      _pages[index] = page.copyWith(
        processedFileName: newProcName,
        processedImagePath: newProcessedImagePath,
        corners: newCorners,
        width: processedImage.width.toDouble(),
        height: processedImage.height.toDouble(),
      );
    } catch (e) {
      debugPrint('[DocumentScannerState] Failed to update crop: $e');
      rethrow;
    } finally {
      _setProcessing(false);
    }
  }

  /// Updates the filter applied to a page.
  Future<void> updatePageFilter(int index, DocumentFilterType filter) async {
    if (index < 0 || index >= _pages.length) return;
    _setProcessing(true, text: 'Applying filter...');
    try {
      final page = _pages[index];
      final origBytes = await _tempScope.readFile(page.originalFileName);
      final origImage = img.decodeImage(origBytes);
      if (origImage == null) throw Exception('Failed to decode original image');

      final processedImage = await compute(
        _warpAndFilterImageTask,
        _WarpFilterParams(
          image: origImage,
          corners: page.corners,
          filter: filter,
          rotation: page.rotation,
        ),
      );

      final procBytes = Uint8List.fromList(
        img.encodeJpg(processedImage, quality: 90),
      );
      final newProcName =
          '${page.id}_processed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newProcessedImagePath = await _tempScope.createFile(
        newProcName,
        bytes: procBytes,
      );

      try {
        await _tempScope.deleteFile(page.processedFileName);
      } catch (_) {}

      _pages[index] = page.copyWith(
        processedFileName: newProcName,
        processedImagePath: newProcessedImagePath,
        filter: filter,
        width: processedImage.width.toDouble(),
        height: processedImage.height.toDouble(),
      );
    } catch (e) {
      debugPrint('[DocumentScannerState] Failed to update filter: $e');
      rethrow;
    } finally {
      _setProcessing(false);
    }
  }

  /// Rotates the page by 90 degrees (clockwise or counter-clockwise).
  Future<void> rotatePage(int index, int angleDegrees) async {
    if (index < 0 || index >= _pages.length) return;
    _setProcessing(true, text: 'Rotating image...');
    try {
      final page = _pages[index];
      final newRotation = (page.rotation + angleDegrees) % 360;

      final origBytes = await _tempScope.readFile(page.originalFileName);
      final origImage = img.decodeImage(origBytes);
      if (origImage == null) throw Exception('Failed to decode original image');

      final processedImage = await compute(
        _warpAndFilterImageTask,
        _WarpFilterParams(
          image: origImage,
          corners: page.corners,
          filter: page.filter,
          rotation: newRotation,
        ),
      );

      final procBytes = Uint8List.fromList(
        img.encodeJpg(processedImage, quality: 90),
      );
      final newProcName =
          '${page.id}_processed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newProcessedImagePath = await _tempScope.createFile(
        newProcName,
        bytes: procBytes,
      );

      try {
        await _tempScope.deleteFile(page.processedFileName);
      } catch (_) {}

      _pages[index] = page.copyWith(
        processedFileName: newProcName,
        processedImagePath: newProcessedImagePath,
        rotation: newRotation,
        width: processedImage.width.toDouble(),
        height: processedImage.height.toDouble(),
      );
    } catch (e) {
      debugPrint('[DocumentScannerState] Failed to rotate page: $e');
      rethrow;
    } finally {
      _setProcessing(false);
    }
  }

  /// Removes a page and deletes its corresponding temp files.
  Future<void> removePage(int index) async {
    if (index < 0 || index >= _pages.length) return;
    final page = _pages.removeAt(index);
    notifyListeners();

    try {
      await _tempScope.deleteFile(page.originalFileName);
      await _tempScope.deleteFile(page.processedFileName);
    } catch (e) {
      debugPrint(
        '[DocumentScannerState] Warning: Failed to delete page files: $e',
      );
    }
  }

  /// Reorders pages.
  void reorderPages(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final page = _pages.removeAt(oldIndex);
    _pages.insert(newIndex, page);
    notifyListeners();
  }

  /// Clears all pages.
  Future<void> clearAll() async {
    _pages.clear();
    await _tempScope.cleanTracked();
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// Isolate worker tasks
// ---------------------------------------------------------------------------

img.Image _decodeAndBakeImage(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw Exception('Could not decode image');
  }
  return img.bakeOrientation(decoded);
}

class _WarpFilterParams {
  final img.Image image;
  final List<Offset> corners;
  final DocumentFilterType filter;
  final int rotation;

  const _WarpFilterParams({
    required this.image,
    required this.corners,
    required this.filter,
    required this.rotation,
  });
}

img.Image _warpAndFilterImageTask(_WarpFilterParams params) {
  // 1. Warp perspective
  var output = PerspectiveWarp.warp(params.image, params.corners);

  // 2. Apply rotation if any
  if (params.rotation != 0) {
    output = img.copyRotate(output, angle: params.rotation);
  }

  // 3. Apply filter
  output = DocumentFilters.apply(output, params.filter);

  return output;
}
