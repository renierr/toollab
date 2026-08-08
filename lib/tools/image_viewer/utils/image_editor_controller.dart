import 'dart:async';
import 'package:tool_lab/helpers/debug_log.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:tool_lab/tools/image_viewer/config.dart';
import 'package:tool_lab/tools/image_viewer/utils/edit_history.dart';
import 'package:tool_lab/tools/image_viewer/utils/image_canvas_ops.dart';
import 'package:tool_lab/tools/image_viewer/utils/image_editor_tasks.dart';
import 'package:tool_lab/tools/image_viewer/utils/image_metadata_extractor.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:tool_lab/tools/image_viewer/utils/onnx_background_remover.dart';
import 'package:tool_lab/tools/image_viewer/utils/windows_ocr.dart';

/// No bundled decoder handles the data (SVG, exotic codecs).
class UnsupportedImageFormatException implements Exception {
  final String fileName;

  const UnsupportedImageFormatException(this.fileName);

  @override
  String toString() => 'UnsupportedImageFormatException: $fileName';
}

class ImageEditorController extends ChangeNotifier {
  img.Image? _decodedImage;
  ui.Image? _uiImage;
  Uint8List? _rawBytes;
  bool _isAnimated = false;
  String? _fileName;
  int _fileSizeBytes = 0;

  int _originalWidth = 0;
  int _originalHeight = 0;

  final TextEditingController widthController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  bool _keepAspectRatio = true;
  String _selectedFormat = 'png';
  double _quality = 90.0;
  bool _isProcessing = false;
  ImageMetadata? _metadata;
  bool _preserveExif = false;

  // Editor and history state (bounded undo/redo, see EditHistory).
  bool _isCropMode = false;
  bool _isRedactMode = false;
  final EditHistory _history = EditHistory();

  // Deferred decoding future and load session counter to prevent memory leaks on close/switch
  Future<img.Image>? _decodingFuture;
  Future<void>? _backgroundSync;
  int _loadSessionCounter = 0;

  // Lazily created ONNX background remover; holds a native session until closed.
  U2NetBackgroundRemover? _bgRemover;

  // Sibling browsing — only populated when the image was opened from a real
  // filesystem path (desktop). Paste/gallery/camera sources leave this empty.
  static final Set<String> _siblingExtensions = imageViewerExtensions
      .map((ext) => '.$ext')
      .toSet();
  List<String> _siblings = const [];
  int _siblingIndex = -1;

  // Getters
  img.Image? get decodedImage => _decodedImage;
  ui.Image? get uiImage => _uiImage;
  Uint8List? get rawBytes => _rawBytes;
  bool get isAnimated => _isAnimated;
  String? get fileName => _fileName;
  int get fileSizeBytes => _fileSizeBytes;
  int get originalWidth => _originalWidth;
  int get originalHeight => _originalHeight;
  bool get keepAspectRatio => _keepAspectRatio;
  String get selectedFormat => _selectedFormat;
  double get quality => _quality;
  bool get isProcessing => _isProcessing;
  ImageMetadata? get metadata => _metadata;
  bool get preserveExif => _preserveExif;
  bool get isCropMode => _isCropMode;
  bool get isRedactMode => _isRedactMode;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  // True when edits are applied on top of the loaded original (undoable).
  bool get hasEdits => _history.canUndo;
  bool get canBrowseSiblings => _siblings.length > 1;
  bool get hasPrevSibling => canBrowseSiblings && _siblingIndex > 0;
  bool get hasNextSibling =>
      canBrowseSiblings && _siblingIndex < _siblings.length - 1;
  int get siblingIndex => _siblingIndex;
  int get siblingCount => _siblings.length;

  late final TempFileScope _scope = TempFileManager.createScope();

  ImageEditorController() {
    widthController.addListener(_onWidthChanged);
    heightController.addListener(_onHeightChanged);
  }

  @override
  void dispose() {
    _loadSessionCounter++;
    widthController.dispose();
    heightController.dispose();
    _uiImage?.dispose();
    _uiImage = null;
    _bgRemover?.dispose();
    _bgRemover = null;
    _scope.cleanTracked();
    super.dispose();
  }

  void setCropMode(bool value) {
    _isCropMode = value;
    notifyListeners();
  }

  void setRedactMode(bool value) {
    _isRedactMode = value;
    notifyListeners();
  }

  void setKeepAspectRatio(bool value) {
    _keepAspectRatio = value;
    notifyListeners();
    if (value) {
      _onWidthChanged();
    }
  }

  void setSelectedFormat(String format) {
    _selectedFormat = format;
    notifyListeners();
  }

  void setQuality(double quality) {
    _quality = quality;
    notifyListeners();
  }

  void setPreserveExif(bool value) {
    _preserveExif = value;
    notifyListeners();
  }

  Future<void> loadImage(Uint8List bytes, String name, int sizeBytes) async {
    _metadata = null;
    _isProcessing = false;
    _decodedImage = null;
    _decodingFuture = null;
    _backgroundSync = null;
    _siblings = const [];
    _siblingIndex = -1;

    _loadSessionCounter++;
    final currentSession = _loadSessionCounter;

    try {
      var data = bytes;
      ui.Codec codec;
      try {
        codec = await ui.instantiateImageCodec(data);
      } catch (_) {
        final transcoded = await compute(transcodeToPngTask, data);
        if (transcoded == null) {
          throw UnsupportedImageFormatException(name);
        }
        data = transcoded;
        codec = await ui.instantiateImageCodec(data);
      }
      final animated = codec.frameCount > 1;
      final frame = await codec.getNextFrame();

      if (currentSession != _loadSessionCounter) {
        frame.image.dispose();
        return;
      }

      _uiImage?.dispose();
      _uiImage = frame.image;
      _isAnimated = animated;
      // Transcoded sources keep the PNG bytes so later re-decodes stay valid.
      _rawBytes = data;

      _fileName = name;
      _fileSizeBytes = sizeBytes;
      _originalWidth = _uiImage!.width;
      _originalHeight = _uiImage!.height;

      _syncDimensionFields();

      _history.clear();
      _isCropMode = false;

      notifyListeners();

      _extractExif(bytes, currentSession);
    } catch (e) {
      errorLog("Failed to load image: $e");
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Sibling browsing — scans the folder of the opened file for other images so
  // the user can step through them with prev/next. Only meaningful when the
  // source is a real filesystem path (desktop file pick / shared file).
  // ---------------------------------------------------------------------------

  Future<void> scanSiblings(String? filePath) async {
    _siblings = const [];
    _siblingIndex = -1;

    if (filePath == null) {
      notifyListeners();
      return;
    }

    try {
      final file = File(filePath);
      final dir = file.parent;
      if (!await dir.exists()) {
        notifyListeners();
        return;
      }

      final paths = <String>[];
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final dot = entity.path.lastIndexOf('.');
        if (dot == -1) continue;
        final ext = entity.path.substring(dot).toLowerCase();
        if (_siblingExtensions.contains(ext)) paths.add(entity.path);
      }
      paths.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      final target = file.absolute.path.toLowerCase();
      _siblings = paths;
      _siblingIndex = paths.indexWhere(
        (p) => File(p).absolute.path.toLowerCase() == target,
      );
    } catch (e) {
      errorLog('Failed to scan sibling images: $e');
      _siblings = const [];
      _siblingIndex = -1;
    }
    notifyListeners();
  }

  Future<void> _loadSiblingAt(int index) async {
    if (index < 0 || index >= _siblings.length) return;
    final path = _siblings[index];
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final size = await file.length();
      final name = path.split(Platform.pathSeparator).last;
      final siblings = _siblings;
      await loadImage(bytes, name, size);
      // loadImage does not touch sibling state; restore it after the reload.
      _siblings = siblings;
      _siblingIndex = index;
      notifyListeners();
    } catch (e) {
      errorLog('Failed to load sibling image: $e');
      rethrow;
    }
  }

  Future<void> nextSibling() => _loadSiblingAt(_siblingIndex + 1);
  Future<void> prevSibling() => _loadSiblingAt(_siblingIndex - 1);

  void _extractExif(Uint8List bytes, int session) {
    compute(extractMetadataTask, bytes)
        .then((metadata) {
          if (session != _loadSessionCounter || _uiImage == null) return;
          _metadata = metadata;
          notifyListeners();
        })
        .catchError((e) {
          errorLog("Failed to extract metadata in background: $e");
        });
  }

  Future<ui.Image> _convertToUiImage(img.Image image) async {
    final rgba8Image =
        image.numChannels == 4 && image.format == img.Format.uint8
        ? image
        : image.convert(numChannels: 4, format: img.Format.uint8);

    final bytes = rgba8Image.toUint8List();

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      bytes,
      image.width,
      image.height,
      ui.PixelFormat.rgba8888,
      (ui.Image img) {
        completer.complete(img);
      },
    );
    return completer.future;
  }

  void _syncDimensionFields() {
    widthController.removeListener(_onWidthChanged);
    heightController.removeListener(_onHeightChanged);
    widthController.text = _originalWidth.toString();
    heightController.text = _originalHeight.toString();
    widthController.addListener(_onWidthChanged);
    heightController.addListener(_onHeightChanged);
  }

  // ---------------------------------------------------------------------------
  // Background sync — chains isolate transforms so the backing img.Image
  // stays in lockstep with the displayed ui.Image. GPU-accelerated Canvas
  // transforms live in image_canvas_ops.dart.
  // ---------------------------------------------------------------------------

  /// Runs [work] on the backing img.Image in a chained isolate to keep it in
  /// step with the GPU display, then records [buildStep] in history. For
  /// destructive edits, [buildStep] snapshots the pre-edit image it receives.
  void _queueBackgroundSync(
    Future<img.Image> Function(img.Image current) work,
    Future<EditStep> Function(img.Image before) buildStep,
  ) {
    final prev = _backgroundSync ?? Future.value(null);
    final session = _loadSessionCounter;

    _backgroundSync = prev.then((_) async {
      if (session != _loadSessionCounter) return;
      await _ensureDecoded();
      if (session != _loadSessionCounter || _decodedImage == null) return;
      final before = _decodedImage!;
      final result = await work(before);
      if (session != _loadSessionCounter) return;
      final step = await buildStep(before);
      if (session != _loadSessionCounter) return;
      _decodedImage = result;
      _history.record(step);
    });
  }

  Future<void> _ensureDecoded() async {
    if (_decodedImage != null) return;
    if (_decodingFuture != null) {
      await _decodingFuture;
      return;
    }
    if (_rawBytes == null) {
      throw Exception("No image data available for decoding.");
    }
    final session = _loadSessionCounter;
    _decodingFuture = compute(decodeAndBakeOrientationTask, _rawBytes!).then((
      decoded,
    ) {
      if (session != _loadSessionCounter) return decoded;
      _decodedImage = decoded;
      if (!_isAnimated) _rawBytes = null;
      return decoded;
    });
    await _decodingFuture;
  }

  Future<void> _ensureFullySynced() async {
    await _ensureDecoded();
    if (_backgroundSync != null) await _backgroundSync;
    if (_decodedImage == null) {
      throw Exception("Backing image not yet decoded.");
    }
  }

  // ---------------------------------------------------------------------------
  // Undo / Redo — waits for all background syncs before navigating history.
  // ---------------------------------------------------------------------------

  Future<void> undo() async {
    _isProcessing = true;
    notifyListeners();

    try {
      await _ensureFullySynced();
      final prevImage = await _history.undo(_decodedImage!);
      if (prevImage != null) await _applyHistoryImage(prevImage);
    } catch (e) {
      errorLog("Undo failed: $e");
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> redo() async {
    _isProcessing = true;
    notifyListeners();

    try {
      await _ensureFullySynced();
      final nextImage = await _history.redo(_decodedImage!);
      if (nextImage != null) await _applyHistoryImage(nextImage);
    } catch (e) {
      errorLog("Redo failed: $e");
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> _applyHistoryImage(img.Image image) async {
    final newUi = await _convertToUiImage(image);
    _uiImage?.dispose();
    _uiImage = newUi;
    _decodedImage = image;
    _originalWidth = image.width;
    _originalHeight = image.height;
    _isAnimated = false;
    _syncDimensionFields();
  }

  // ---------------------------------------------------------------------------
  // Transform operations — Canvas-first for instant display, then background
  // isolate sync to keep img.Image in step.
  // ---------------------------------------------------------------------------

  Future<void> rotateImage(int angle) async {
    if (_uiImage == null) return;

    final newUi = await canvasRotate(_uiImage!, angle);
    _uiImage?.dispose();
    _uiImage = newUi;
    _originalWidth = newUi.width;
    _originalHeight = newUi.height;
    _isAnimated = false;
    _syncDimensionFields();
    notifyListeners();

    _queueBackgroundSync(
      (current) => compute(rotateImageTask, RotateParams(current, angle)),
      (_) async => RotateStep(angle),
    );
  }

  Future<void> flipImage(String direction) async {
    if (_uiImage == null) return;

    final newUi = await canvasFlip(_uiImage!, direction);
    _uiImage?.dispose();
    _uiImage = newUi;
    _isAnimated = false;
    notifyListeners();

    _queueBackgroundSync(
      (current) => compute(flipImageTask, FlipParams(current, direction)),
      (_) async => FlipStep(direction),
    );
  }

  Future<void> segmentSubject() async {
    if (_uiImage == null) return;
    if (!Platform.isAndroid && !Platform.isWindows && !Platform.isLinux) {
      throw UnsupportedError(
        "Background removal is not supported on this platform.",
      );
    }

    _isProcessing = true;
    notifyListeners();

    try {
      await _ensureDecoded();
      if (_decodedImage == null) {
        throw Exception("Decoded image is null.");
      }

      // Snapshot the pre-edit image for history.
      final beforePng = await compute(encodePngTask, _decodedImage!);

      // Android prefers ML Kit; when its model is unavailable, fall back to the
      // bundled on-device ONNX model (which is the only path on Windows/Linux).
      Uint8List segmentedBytes;
      if (Platform.isAndroid) {
        try {
          segmentedBytes = await _segmentWithMlKit(beforePng);
        } catch (e) {
          errorLog("ML Kit segmentation unavailable, falling back to ONNX: $e");
          segmentedBytes = await _segmentWithOnnx();
        }
      } else {
        segmentedBytes = await _segmentWithOnnx();
      }

      // Decode the output image
      final codec = await ui.instantiateImageCodec(segmentedBytes);
      final frame = await codec.getNextFrame();
      final newUiImage = frame.image;

      final newDecodedImage = await compute(decodeImageTask, segmentedBytes);

      // Apply changes
      _uiImage?.dispose();
      _uiImage = newUiImage;
      _decodedImage = newDecodedImage;
      _originalWidth = newUiImage.width;
      _originalHeight = newUiImage.height;
      _isAnimated = false;
      _syncDimensionFields();

      // Record in history
      _history.record(SegmentStep(beforePng, segmentedBytes));

      notifyListeners();
    } catch (e) {
      errorLog("Subject segmentation failed: $e");
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// ML Kit Subject Segmenter (Android). Returns the foreground bitmap as PNG
  /// bytes, retrying once while Google Play Services downloads the model.
  Future<Uint8List> _segmentWithMlKit(Uint8List beforePng) async {
    final tempFilePath = await _scope.createFile(
      'segment_input.png',
      bytes: beforePng,
    );

    final options = SubjectSegmenterOptions(
      enableForegroundBitmap: true,
      enableForegroundConfidenceMask: false,
      enableMultipleSubjects: SubjectResultOptions(
        enableConfidenceMask: false,
        enableSubjectBitmap: false,
      ),
    );

    SubjectSegmentationResult? result;
    for (var attempt = 0; attempt < 2; attempt++) {
      final segmenter = SubjectSegmenter(options: options);
      try {
        final inputImage = InputImage.fromFilePath(tempFilePath);
        result = await segmenter.processImage(inputImage);
        await segmenter.close();
        break;
      } catch (e) {
        await segmenter.close();
        if (e is PlatformException &&
            (e.message?.contains("Waiting for") ?? false) &&
            attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 2500));
          continue;
        }
        rethrow;
      }
    }

    try {
      await _scope.deleteFile('segment_input.png');
    } catch (_) {}

    final segmentedBytes = result?.foregroundBitmap;
    if (segmentedBytes == null) {
      throw Exception(
        "Failed to segment subject: no foreground bitmap returned.",
      );
    }
    return segmentedBytes;
  }

  /// On-device ONNX (u2netp) background removal. Returns an RGBA cutout as PNG.
  Future<Uint8List> _segmentWithOnnx() async {
    _bgRemover ??= U2NetBackgroundRemover();
    return _bgRemover!.removeBackground(_decodedImage!);
  }

  Future<void> cropImage(int x, int y, int w, int h) async {
    if (_uiImage == null) return;
    _isCropMode = false;

    final newUi = await canvasCrop(_uiImage!, x, y, w, h);
    _uiImage?.dispose();
    _uiImage = newUi;
    _originalWidth = w;
    _originalHeight = h;
    _isAnimated = false;
    _syncDimensionFields();
    notifyListeners();

    _queueBackgroundSync(
      (current) => compute(
        cropImageTask,
        CropParams(image: current, x: x, y: y, width: w, height: h),
      ),
      (before) async => CropStep(
        await compute(encodePngTask, before),
        x: x,
        y: y,
        width: w,
        height: h,
      ),
    );
  }

  Future<void> redactImage(
    int x,
    int y,
    int w,
    int h,
    String redactType,
    double intensity,
    Color? solidColor, [
    List<Offset>? relativePathPoints,
  ]) async {
    if (_uiImage == null) return;
    _isRedactMode = false;

    final newUi = await canvasRedact(
      _uiImage!,
      x,
      y,
      w,
      h,
      redactType,
      intensity,
      solidColor,
      relativePathPoints,
    );
    _uiImage?.dispose();
    _uiImage = newUi;
    _isAnimated = false;
    notifyListeners();

    final pathPoints = relativePathPoints?.expand((p) => [p.dx, p.dy]).toList();
    final colorValue = solidColor?.toARGB32();
    _queueBackgroundSync(
      (current) => compute(
        redactImageTask,
        RedactParams(
          image: current,
          x: x,
          y: y,
          width: w,
          height: h,
          redactType: redactType,
          intensity: intensity,
          colorValue: colorValue,
          pathPoints: pathPoints,
        ),
      ),
      (before) async => RedactStep(
        await compute(encodePngTask, before),
        x: x,
        y: y,
        width: w,
        height: h,
        redactType: redactType,
        intensity: intensity,
        colorValue: colorValue,
        pathPoints: pathPoints,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Resize text-field sync
  // ---------------------------------------------------------------------------

  void _onWidthChanged() {
    if (!_keepAspectRatio || _originalWidth == 0 || _originalHeight == 0) {
      return;
    }
    final text = widthController.text;
    if (text.isEmpty) {
      return;
    }

    final w = int.tryParse(text);
    if (w != null && w > 0) {
      final aspect = _originalWidth / _originalHeight;
      final h = (w / aspect).round();
      final currentHText = heightController.text;
      if (currentHText != h.toString()) {
        heightController.removeListener(_onHeightChanged);
        heightController.text = h.toString();
        heightController.addListener(_onHeightChanged);
      }
    }
  }

  void _onHeightChanged() {
    if (!_keepAspectRatio || _originalWidth == 0 || _originalHeight == 0) {
      return;
    }
    final text = heightController.text;
    if (text.isEmpty) {
      return;
    }

    final h = int.tryParse(text);
    if (h != null && h > 0) {
      final aspect = _originalWidth / _originalHeight;
      final w = (h * aspect).round();
      final currentWText = widthController.text;
      if (currentWText != w.toString()) {
        widthController.removeListener(_onWidthChanged);
        widthController.text = w.toString();
        widthController.addListener(_onWidthChanged);
      }
    }
  }

  void clear() {
    _loadSessionCounter++;
    _decodedImage = null;
    _uiImage?.dispose();
    _uiImage = null;
    _rawBytes = null;
    _isAnimated = false;
    _fileName = null;
    _fileSizeBytes = 0;
    _originalWidth = 0;
    _originalHeight = 0;
    _metadata = null;
    _preserveExif = false;
    widthController.clear();
    heightController.clear();
    _history.clear();
    _isCropMode = false;
    _isRedactMode = false;
    _isProcessing = false;
    _decodingFuture = null;
    _backgroundSync = null;
    _siblings = const [];
    _siblingIndex = -1;
    notifyListeners();
  }

  Future<void> prepareForEditing() async {
    if (_decodedImage != null) return;
    _isProcessing = true;
    notifyListeners();
    try {
      await _ensureFullySynced();
    } catch (e) {
      errorLog("Failed to sync/decode image: $e");
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> previewResize() async {
    await _ensureFullySynced();

    final width = int.tryParse(widthController.text);
    final height = int.tryParse(heightController.text);

    if (width == null || width <= 0 || height == null || height <= 0) {
      throw Exception('Please enter valid width and height dimensions.');
    }

    _isProcessing = true;
    notifyListeners();

    try {
      final before = _decodedImage!;
      final beforePng = await compute(encodePngTask, before);

      final resized = await compute(
        resizeImageTask,
        ResizeParams(image: before, width: width, height: height),
      );

      final newUi = await _convertToUiImage(resized);
      _uiImage?.dispose();
      _uiImage = newUi;
      _decodedImage = resized;
      _originalWidth = resized.width;
      _originalHeight = resized.height;
      _syncDimensionFields();
      _history.record(ResizeStep(beforePng, width: width, height: height));
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> exportImage(BuildContext context) async {
    await _ensureFullySynced();

    final width = int.tryParse(widthController.text);
    final height = int.tryParse(heightController.text);

    if (width == null || width <= 0 || height == null || height <= 0) {
      throw Exception('Please enter valid width and height dimensions.');
    }

    _isProcessing = true;
    notifyListeners();

    try {
      final params = ImageResizeParams(
        image: _decodedImage!,
        width: width,
        height: height,
        format: _selectedFormat,
        quality: _quality.round(),
        preserveExif: _preserveExif,
      );

      final exportedBytes = await compute(resizeAndEncodeTask, params);

      final dotIndex = _fileName?.lastIndexOf('.') ?? -1;
      final originalBase = (dotIndex != -1)
          ? _fileName!.substring(0, dotIndex)
          : (_fileName ?? 'image');
      final ext = _selectedFormat == 'jpg' ? 'jpg' : _selectedFormat;
      final hasResized = (width != _originalWidth || height != _originalHeight);
      final suggestedName = hasResized
          ? '${originalBase}_resized.$ext'
          : '$originalBase.$ext';

      if (context.mounted) {
        await FileSaveHelper.saveFile(
          context: context,
          suggestedName: suggestedName,
          bytes: exportedBytes,
          successMessageAndroid: 'Image saved to Downloads directory.',
          successMessageGeneralBuilder: (path) => 'Image saved to $path',
        );
      }
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> shareImage(BuildContext context) async {
    await _ensureFullySynced();

    final width = int.tryParse(widthController.text);
    final height = int.tryParse(heightController.text);

    if (width == null || width <= 0 || height == null || height <= 0) {
      throw Exception('Please enter valid width and height dimensions.');
    }

    _isProcessing = true;
    notifyListeners();

    try {
      final params = ImageResizeParams(
        image: _decodedImage!,
        width: width,
        height: height,
        format: _selectedFormat,
        quality: _quality.round(),
        preserveExif: _preserveExif,
      );

      final exportedBytes = await compute(resizeAndEncodeTask, params);

      final ext = _selectedFormat == 'jpg' ? 'jpg' : _selectedFormat;
      final dotIndex = _fileName?.lastIndexOf('.') ?? -1;
      final originalBase = (dotIndex != -1)
          ? _fileName!.substring(0, dotIndex)
          : (_fileName ?? 'image');
      final hasResized = (width != _originalWidth || height != _originalHeight);
      final suggestedName = hasResized
          ? '${originalBase}_resized.$ext'
          : '$originalBase.$ext';

      final tempPath = await _scope.createFile(
        suggestedName,
        bytes: exportedBytes,
      );

      if (context.mounted) {
        final mimeType = 'image/$_selectedFormat';
        await FileSaveHelper.showShareChooser(
          context: context,
          path: tempPath,
          mimeType: mimeType,
        );
      }
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> copyToClipboard() async {
    if (_uiImage == null) return;

    _isProcessing = true;
    notifyListeners();

    try {
      await ClipboardHelper.setImagePng(_uiImage!);
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = (math.log(bytes) / math.log(1024)).floor();
    return '${(bytes / math.pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<String> extractText() async {
    if (_uiImage == null) {
      throw Exception("No image loaded.");
    }
    if (!Platform.isAndroid && !Platform.isWindows) {
      throw UnsupportedError(
        "Text extraction is not supported on this platform.",
      );
    }

    _isProcessing = true;
    notifyListeners();

    try {
      await _ensureFullySynced();
      if (_decodedImage == null) {
        throw Exception("Decoded image is null.");
      }

      // Convert current decoded image to PNG bytes for the OCR engine.
      final pngBytes = await compute(encodePngTask, _decodedImage!);

      // Windows: built-in WinRT OCR (Windows.Media.Ocr) via a runner channel.
      if (Platform.isWindows) {
        return await WindowsOcr.recognizeText(pngBytes);
      }

      // Android: ML Kit on-device text recognition, fed from a temp file.
      final tempFilePath = await _scope.createFile(
        'ocr_input.png',
        bytes: pngBytes,
      );

      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final inputImage = InputImage.fromFilePath(tempFilePath);
      final recognizedText = await textRecognizer.processImage(inputImage);
      final extractedText = recognizedText.text;

      await textRecognizer.close();

      // Clean up the temp file
      try {
        await _scope.deleteFile('ocr_input.png');
      } catch (_) {}

      return extractedText;
    } catch (e) {
      errorLog("Text extraction failed: $e");
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
}
