import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/tools/image_viewer/utils/image_editor_tasks.dart';
import 'package:tool_lab/tools/image_viewer/utils/image_metadata_extractor.dart';

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

  // Editor and history state (max 5 steps)
  bool _isCropMode = false;
  final List<img.Image> _history = [];
  int _historyIndex = -1;
  static const int _maxHistorySteps = 5;

  // Deferred decoding future and load session counter to prevent memory leaks on close/switch
  Future<img.Image>? _decodingFuture;
  Future<void>? _backgroundSync;
  int _loadSessionCounter = 0;

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
  int get historyIndex => _historyIndex;
  int get historyLength => _history.length;

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
    super.dispose();
  }

  void setCropMode(bool value) {
    _isCropMode = value;
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

    _loadSessionCounter++;
    final currentSession = _loadSessionCounter;

    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final animated = codec.frameCount > 1;
      final frame = await codec.getNextFrame();

      if (currentSession != _loadSessionCounter) {
        frame.image.dispose();
        return;
      }

      _uiImage?.dispose();
      _uiImage = frame.image;
      _isAnimated = animated;
      _rawBytes = animated ? bytes : null;

      _fileName = name;
      _fileSizeBytes = sizeBytes;
      _originalWidth = _uiImage!.width;
      _originalHeight = _uiImage!.height;

      _syncDimensionFields();

      _history.clear();
      _historyIndex = -1;
      _isCropMode = false;

      notifyListeners();

      _decodingFuture = compute(decodeAndBakeOrientationTask, bytes).then((
        decoded,
      ) {
        if (currentSession != _loadSessionCounter || _uiImage == null) {
          return decoded;
        }
        _decodedImage = decoded;
        _history.add(decoded);
        _historyIndex = 0;
        return decoded;
      });

      _extractExif(bytes, currentSession);
    } catch (e) {
      debugPrint("Failed to load image: $e");
      rethrow;
    }
  }

  void _extractExif(Uint8List bytes, int session) {
    compute(extractMetadataTask, bytes)
        .then((metadata) {
          if (session != _loadSessionCounter || _uiImage == null) return;
          _metadata = metadata;
          notifyListeners();
        })
        .catchError((e) {
          debugPrint("Failed to extract metadata in background: $e");
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
  // GPU-accelerated Canvas transforms — instant (<10ms) vs seconds with the
  // pure-Dart image package. The backing img.Image is synced in a chained
  // background isolate afterwards so export/undo keep working.
  // ---------------------------------------------------------------------------

  Future<ui.Image> _canvasRotate(ui.Image source, int angle) async {
    final a = angle % 360;
    final swap = a == 90 || a == 270;
    final w = swap ? source.height : source.width;
    final h = swap ? source.width : source.height;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    switch (a) {
      case 90:
        canvas.translate(w.toDouble(), 0);
      case 180:
        canvas.translate(w.toDouble(), h.toDouble());
      case 270:
        canvas.translate(0, h.toDouble());
    }
    canvas.rotate(a * math.pi / 180);
    canvas.drawImage(source, Offset.zero, Paint());

    final picture = recorder.endRecording();
    final result = await picture.toImage(w, h);
    picture.dispose();
    return result;
  }

  Future<ui.Image> _canvasFlip(ui.Image source, String direction) async {
    final w = source.width.toDouble();
    final h = source.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    if (direction == 'horizontal') {
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    } else {
      canvas.translate(0, h);
      canvas.scale(1, -1);
    }
    canvas.drawImage(source, Offset.zero, Paint());

    final picture = recorder.endRecording();
    final result = await picture.toImage(source.width, source.height);
    picture.dispose();
    return result;
  }

  Future<ui.Image> _canvasCrop(
    ui.Image source,
    int x,
    int y,
    int w,
    int h,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImageRect(
      source,
      Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()),
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint(),
    );

    final picture = recorder.endRecording();
    final result = await picture.toImage(w, h);
    picture.dispose();
    return result;
  }

  // ---------------------------------------------------------------------------
  // Background sync — chains isolate transforms so the backing img.Image
  // stays in lockstep with the displayed ui.Image.
  // ---------------------------------------------------------------------------

  void _pushHistory(img.Image newImage) {
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(newImage);
    if (_history.length > _maxHistorySteps) {
      _history.removeAt(0);
    }
    _historyIndex = _history.length - 1;
  }

  void _queueBackgroundSync(
    Future<img.Image> Function(img.Image current) work,
  ) {
    final prev = _backgroundSync ?? Future.value(null);
    final session = _loadSessionCounter;

    _backgroundSync = prev.then((_) async {
      if (session != _loadSessionCounter) return;
      // Wait for the initial heavy decode if still in flight
      if (_decodedImage == null && _decodingFuture != null) {
        await _decodingFuture;
      }
      if (session != _loadSessionCounter || _decodedImage == null) return;
      final result = await work(_decodedImage!);
      if (session != _loadSessionCounter) return;
      _decodedImage = result;
      _pushHistory(result);
    });
  }

  Future<void> _ensureFullySynced() async {
    if (_decodingFuture != null) await _decodingFuture;
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
      if (_historyIndex > 0) {
        final prevImage = _history[_historyIndex - 1];
        final newUi = await _convertToUiImage(prevImage);
        _uiImage?.dispose();
        _uiImage = newUi;
        _decodedImage = prevImage;
        _historyIndex--;
        _originalWidth = prevImage.width;
        _originalHeight = prevImage.height;
        _syncDimensionFields();
      }
    } catch (e) {
      debugPrint("Undo failed: $e");
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
      if (_historyIndex < _history.length - 1) {
        final nextImage = _history[_historyIndex + 1];
        final newUi = await _convertToUiImage(nextImage);
        _uiImage?.dispose();
        _uiImage = newUi;
        _decodedImage = nextImage;
        _historyIndex++;
        _originalWidth = nextImage.width;
        _originalHeight = nextImage.height;
        _syncDimensionFields();
      }
    } catch (e) {
      debugPrint("Redo failed: $e");
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Transform operations — Canvas-first for instant display, then background
  // isolate sync to keep img.Image in step.
  // ---------------------------------------------------------------------------

  Future<void> rotateImage(int angle) async {
    if (_uiImage == null) return;

    final newUi = await _canvasRotate(_uiImage!, angle);
    _uiImage?.dispose();
    _uiImage = newUi;
    _originalWidth = newUi.width;
    _originalHeight = newUi.height;
    _syncDimensionFields();
    notifyListeners();

    _queueBackgroundSync(
      (current) => compute(rotateImageTask, RotateParams(current, angle)),
    );
  }

  Future<void> flipImage(String direction) async {
    if (_uiImage == null) return;

    final newUi = await _canvasFlip(_uiImage!, direction);
    _uiImage?.dispose();
    _uiImage = newUi;
    notifyListeners();

    _queueBackgroundSync(
      (current) => compute(flipImageTask, FlipParams(current, direction)),
    );
  }

  Future<void> cropImage(int x, int y, int w, int h) async {
    if (_uiImage == null) return;
    _isCropMode = false;

    final newUi = await _canvasCrop(_uiImage!, x, y, w, h);
    _uiImage?.dispose();
    _uiImage = newUi;
    _originalWidth = w;
    _originalHeight = h;
    _syncDimensionFields();
    notifyListeners();

    _queueBackgroundSync(
      (current) => compute(
        cropImageTask,
        CropParams(image: current, x: x, y: y, width: w, height: h),
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
    _historyIndex = -1;
    _isCropMode = false;
    _isProcessing = false;
    _decodingFuture = null;
    _backgroundSync = null;
    notifyListeners();
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

      final tempDir = await getTemporaryDirectory();
      final ext = _selectedFormat == 'jpg' ? 'jpg' : _selectedFormat;
      final dotIndex = _fileName?.lastIndexOf('.') ?? -1;
      final originalBase = (dotIndex != -1)
          ? _fileName!.substring(0, dotIndex)
          : (_fileName ?? 'image');
      final hasResized = (width != _originalWidth || height != _originalHeight);
      final suggestedName = hasResized
          ? '${originalBase}_resized.$ext'
          : '$originalBase.$ext';

      final tempFile = File('${tempDir.path}/$suggestedName');
      await tempFile.writeAsBytes(exportedBytes);

      if (context.mounted) {
        final mimeType = 'image/$_selectedFormat';
        await FileSaveHelper.showShareChooser(
          context: context,
          path: tempFile.path,
          mimeType: mimeType,
        );
      }
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
}
