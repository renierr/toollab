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

  // Editor and history state
  bool _isCropMode = false;
  final List<img.Image> _history = [];
  int _historyIndex = -1;

  // Deferred decoding future
  Future<img.Image>? _decodingFuture;

  // Getters
  img.Image? get decodedImage => _decodedImage;
  ui.Image? get uiImage => _uiImage;
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
    widthController.dispose();
    heightController.dispose();
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
    _isProcessing = false; // Do not show loader on open
    _decodedImage = null;
    _decodingFuture = null;

    try {
      // Decode instantly using native Flutter C++ engine (under 50ms) for visual preview
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _uiImage = frame.image;

      _fileName = name;
      _fileSizeBytes = sizeBytes;
      _originalWidth = _uiImage!.width;
      _originalHeight = _uiImage!.height;

      // Update text fields
      widthController.removeListener(_onWidthChanged);
      heightController.removeListener(_onHeightChanged);
      widthController.text = _originalWidth.toString();
      heightController.text = _originalHeight.toString();
      widthController.addListener(_onWidthChanged);
      heightController.addListener(_onHeightChanged);

      _history.clear();
      _historyIndex = -1;
      _isCropMode = false;

      // Instantly notify so image displays
      notifyListeners();

      // Start the heavy pure-Dart decode asynchronously in background
      _decodingFuture = compute(decodeAndBakeOrientationTask, bytes).then((
        decoded,
      ) {
        _decodedImage = decoded;
        _history.add(decoded);
        _historyIndex = 0;
        return decoded;
      });

      // Load EXIF in background
      _extractExif(bytes);
    } catch (e) {
      debugPrint("Failed to load image: $e");
      rethrow;
    }
  }

  void _extractExif(Uint8List bytes) {
    compute(extractMetadataTask, bytes)
        .then((metadata) {
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

  Future<void> _applyNewImage(img.Image newImage) async {
    _isProcessing = true;
    notifyListeners();

    try {
      _uiImage = await _convertToUiImage(newImage);
      _decodedImage = newImage;
      _originalWidth = newImage.width;
      _originalHeight = newImage.height;

      // Clear redo history
      if (_historyIndex < _history.length - 1) {
        _history.removeRange(_historyIndex + 1, _history.length);
      }
      _history.add(newImage);
      _historyIndex = _history.length - 1;

      // Sync text fields
      widthController.removeListener(_onWidthChanged);
      heightController.removeListener(_onHeightChanged);
      widthController.text = _originalWidth.toString();
      heightController.text = _originalHeight.toString();
      widthController.addListener(_onWidthChanged);
      heightController.addListener(_onHeightChanged);
    } catch (e) {
      debugPrint("Failed to apply new image: $e");
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> _ensureDecoded() async {
    if (_decodedImage == null && _decodingFuture != null) {
      await _decodingFuture;
    }
    if (_decodedImage == null) {
      throw Exception("Backing image not yet decoded.");
    }
  }

  Future<void> undo() async {
    await _ensureDecoded();
    if (_historyIndex > 0) {
      final prevImage = _history[_historyIndex - 1];
      _isProcessing = true;
      notifyListeners();

      try {
        _uiImage = await _convertToUiImage(prevImage);
        _decodedImage = prevImage;
        _historyIndex--;
        _originalWidth = prevImage.width;
        _originalHeight = prevImage.height;

        widthController.removeListener(_onWidthChanged);
        heightController.removeListener(_onHeightChanged);
        widthController.text = _originalWidth.toString();
        heightController.text = _originalHeight.toString();
        widthController.addListener(_onWidthChanged);
        heightController.addListener(_onHeightChanged);
      } catch (e) {
        debugPrint("Undo failed: $e");
        rethrow;
      } finally {
        _isProcessing = false;
        notifyListeners();
      }
    }
  }

  Future<void> redo() async {
    await _ensureDecoded();
    if (_historyIndex < _history.length - 1) {
      final nextImage = _history[_historyIndex + 1];
      _isProcessing = true;
      notifyListeners();

      try {
        _uiImage = await _convertToUiImage(nextImage);
        _decodedImage = nextImage;
        _historyIndex++;
        _originalWidth = nextImage.width;
        _originalHeight = nextImage.height;

        widthController.removeListener(_onWidthChanged);
        heightController.removeListener(_onHeightChanged);
        widthController.text = _originalWidth.toString();
        heightController.text = _originalHeight.toString();
        widthController.addListener(_onWidthChanged);
        heightController.addListener(_onHeightChanged);
      } catch (e) {
        debugPrint("Redo failed: $e");
        rethrow;
      } finally {
        _isProcessing = false;
        notifyListeners();
      }
    }
  }

  Future<void> rotateImage(int angle) async {
    _isProcessing = true;
    notifyListeners();

    try {
      await _ensureDecoded();
      final params = RotateParams(_decodedImage!, angle);
      final rotatedImage = await compute(rotateImageTask, params);
      await _applyNewImage(rotatedImage);
    } catch (e) {
      debugPrint("Rotation failed: $e");
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> flipImage(String direction) async {
    _isProcessing = true;
    notifyListeners();

    try {
      await _ensureDecoded();
      final params = FlipParams(_decodedImage!, direction);
      final flippedImage = await compute(flipImageTask, params);
      await _applyNewImage(flippedImage);
    } catch (e) {
      debugPrint("Flipping failed: $e");
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> cropImage(int x, int y, int w, int h) async {
    _isProcessing = true;
    _isCropMode = false;
    notifyListeners();

    try {
      await _ensureDecoded();
      final params = CropParams(
        image: _decodedImage!,
        x: x,
        y: y,
        width: w,
        height: h,
      );
      final croppedImage = await compute(cropImageTask, params);
      await _applyNewImage(croppedImage);
    } catch (e) {
      debugPrint("Cropping failed: $e");
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

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
    _decodedImage = null;
    _uiImage = null;
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
    notifyListeners();
  }

  Future<void> exportImage(BuildContext context) async {
    await _ensureDecoded();

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

      // Clean up base name to construct suggested output file name
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
    await _ensureDecoded();

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
