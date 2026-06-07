import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/tools/image_viewer/config.dart';
import 'package:tool_lab/tools/image_viewer/widgets/image_viewer_display.dart';
import 'package:tool_lab/tools/image_viewer/widgets/image_viewer_editor.dart';

class ImageViewerPage extends StatefulWidget {
  final SharedFile? sharedFile;

  const ImageViewerPage({super.key, this.sharedFile});

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> with DisposeCleanup {
  Uint8List? _imageBytes;
  String? _fileName;
  int _fileSizeBytes = 0;

  int _originalWidth = 0;
  int _originalHeight = 0;

  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  bool _keepAspectRatio = true;
  String _selectedFormat = 'png';
  double _quality = 90.0;
  bool _isProcessing = false;
  ImageMetadata? _metadata;
  bool _preserveExif = false;

  final TransformationController _transformationController =
      TransformationController();

  bool _isEditorOpen = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    _widthController.addListener(_onWidthChanged);
    _heightController.addListener(_onHeightChanged);

    onDispose(() {
      _widthController.dispose();
      _heightController.dispose();
      _transformationController.dispose();
    });

    if (widget.sharedFile != null) {
      _loadSharedFile(widget.sharedFile!);
    }

    final sharingSub = SharingService.instance.onSharedFile.listen((file) {
      final mime = file.mimeType.toLowerCase();
      if (mime.startsWith('image/') ||
          file.name.endsWith('.png') ||
          file.name.endsWith('.jpg') ||
          file.name.endsWith('.jpeg') ||
          file.name.endsWith('.webp') ||
          file.name.endsWith('.bmp') ||
          file.name.endsWith('.gif')) {
        _loadSharedFile(file);
      }
    });
    onDispose(sharingSub.cancel);
  }

  Future<void> _loadSharedFile(SharedFile file) async {
    try {
      final diskFile = File(file.path);
      if (await diskFile.exists()) {
        final bytes = await diskFile.readAsBytes();
        final size = await diskFile.length();
        await _processLoadedImage(bytes, file.name, file.path, size);
      }
    } catch (e) {
      _showError('Failed to load image: $e');
    }
  }

  Future<void> _onFileSelected(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final size = await file.length();
      await _processLoadedImage(bytes, file.name, file.path, size);
    } catch (e) {
      _showError('Failed to read selected file: $e');
    }
  }

  Future<void> _processLoadedImage(
    Uint8List bytes,
    String name,
    String? path,
    int sizeBytes,
  ) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final metadata = await compute(_extractMetadataTask, bytes);

      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _fileName = name;
          _fileSizeBytes = sizeBytes;
          _originalWidth = image.width;
          _originalHeight = image.height;
          _metadata = metadata;

          // Set size fields silently without invoking listeners recursively
          _widthController.text = _originalWidth.toString();
          _heightController.text = _originalHeight.toString();

          // Reset zoom transformation
          _transformationController.value = Matrix4.identity();

          // Auto-detect format from file extension if possible
          final ext = name.split('.').last.toLowerCase();
          if (ext == 'png' || ext == 'jpg' || ext == 'jpeg' || ext == 'bmp') {
            _selectedFormat = (ext == 'jpeg') ? 'jpg' : ext;
          } else {
            _selectedFormat = 'png';
          }
        });
      }
    } catch (e) {
      _showError('Failed to process image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // Width text field listener
  void _onWidthChanged() {
    if (!_keepAspectRatio || _originalWidth == 0 || _originalHeight == 0) {
      return;
    }
    final text = _widthController.text;
    if (text.isEmpty) {
      return;
    }

    final w = int.tryParse(text);
    if (w != null && w > 0) {
      final aspect = _originalWidth / _originalHeight;
      final h = (w / aspect).round();
      final currentHText = _heightController.text;
      if (currentHText != h.toString()) {
        _heightController.removeListener(_onHeightChanged);
        _heightController.text = h.toString();
        _heightController.addListener(_onHeightChanged);
      }
    }
  }

  // Height text field listener
  void _onHeightChanged() {
    if (!_keepAspectRatio || _originalWidth == 0 || _originalHeight == 0) {
      return;
    }
    final text = _heightController.text;
    if (text.isEmpty) {
      return;
    }

    final h = int.tryParse(text);
    if (h != null && h > 0) {
      final aspect = _originalWidth / _originalHeight;
      final w = (h * aspect).round();
      final currentWText = _widthController.text;
      if (currentWText != w.toString()) {
        _widthController.removeListener(_onWidthChanged);
        _widthController.text = w.toString();
        _widthController.addListener(_onWidthChanged);
      }
    }
  }

  void _onResetZoom() {
    setState(() {
      _transformationController.value = Matrix4.identity();
    });
  }

  void _onClose() {
    if (widget.sharedFile != null) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        _clearImage();
      }
    } else {
      _clearImage();
    }
  }

  void _clearImage() {
    setState(() {
      _imageBytes = null;
      _fileName = null;
      _fileSizeBytes = 0;
      _originalWidth = 0;
      _originalHeight = 0;
      _metadata = null;
      _preserveExif = false;
      _widthController.clear();
      _heightController.clear();
    });
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = (math.log(bytes) / math.log(1024)).floor();
    return '${(bytes / math.pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<void> _exportImage() async {
    if (_imageBytes == null) return;

    final width = int.tryParse(_widthController.text);
    final height = int.tryParse(_heightController.text);

    if (width == null || width <= 0 || height == null || height <= 0) {
      _showError('Please enter valid width and height dimensions.');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final params = ImageResizeParams(
        bytes: _imageBytes!,
        width: width,
        height: height,
        format: _selectedFormat,
        quality: _quality.round(),
        preserveExif: _preserveExif,
      );

      final exportedBytes = await compute(_resizeAndEncodeTask, params);

      if (!mounted) return;

      // Clean up base name to construct suggested output file name
      final originalBase = _fileName?.split('.').first ?? 'image';
      final ext = _selectedFormat == 'jpg' ? 'jpg' : _selectedFormat;
      final hasResized = (width != _originalWidth || height != _originalHeight);
      final suggestedName = hasResized
          ? '${originalBase}_resized.$ext'
          : '$originalBase.$ext';

      await FileSaveHelper.saveFile(
        context: context,
        suggestedName: suggestedName,
        bytes: exportedBytes,
        successMessageAndroid: 'Image saved to Downloads directory.',
        successMessageGeneralBuilder: (path) => 'Image saved to $path',
      );
    } catch (e) {
      _showError('Failed to export image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _shareImage() async {
    if (_imageBytes == null) return;

    final width = int.tryParse(_widthController.text);
    final height = int.tryParse(_heightController.text);

    if (width == null || width <= 0 || height == null || height <= 0) {
      _showError('Please enter valid width and height dimensions.');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final params = ImageResizeParams(
        bytes: _imageBytes!,
        width: width,
        height: height,
        format: _selectedFormat,
        quality: _quality.round(),
        preserveExif: _preserveExif,
      );

      final exportedBytes = await compute(_resizeAndEncodeTask, params);

      if (!mounted) return;

      final tempDir = await getTemporaryDirectory();
      final ext = _selectedFormat == 'jpg' ? 'jpg' : _selectedFormat;
      final originalBase = _fileName?.split('.').first ?? 'image';
      final hasResized = (width != _originalWidth || height != _originalHeight);
      final suggestedName = hasResized
          ? '${originalBase}_resized.$ext'
          : '$originalBase.$ext';

      final tempFile = File('${tempDir.path}/$suggestedName');
      await tempFile.writeAsBytes(exportedBytes);

      if (mounted) {
        final mimeType = 'image/$_selectedFormat';
        await FileSaveHelper.showShareChooser(
          context: context,
          path: tempFile.path,
          mimeType: mimeType,
        );
      }
    } catch (e) {
      _showError('Failed to share image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWideScreen = MediaQuery.of(context).size.width > 720;

    final displayWidget = _imageBytes != null
        ? ImageViewerDisplay(
            imageBytes: _imageBytes!,
            transformationController: _transformationController,
            onResetZoom: _onResetZoom,
          )
        : const SizedBox.shrink();

    final editorWidget = _imageBytes != null
        ? ImageViewerEditor(
            widthController: _widthController,
            heightController: _heightController,
            keepAspectRatio: _keepAspectRatio,
            onKeepAspectRatioChanged: (val) {
              setState(() {
                _keepAspectRatio = val;
              });
              if (val) {
                _onWidthChanged();
              }
            },
            selectedFormat: _selectedFormat,
            onFormatChanged: (val) {
              setState(() {
                _selectedFormat = val;
              });
            },
            quality: _quality,
            onQualityChanged: (val) {
              setState(() {
                _quality = val;
              });
            },
            onSave: _exportImage,
            onShare: _shareImage,
            isProcessing: _isProcessing,
            originalDimensions: '${_originalWidth}x$_originalHeight px',
            originalSize: _formatBytes(_fileSizeBytes),
            metadata: _metadata,
            fileName: _fileName ?? 'image.png',
            preserveExif: _preserveExif,
            onPreserveExifChanged: (val) {
              setState(() {
                _preserveExif = val;
              });
            },
          )
        : const SizedBox.shrink();

    Widget mainContent;
    if (_imageBytes == null) {
      mainContent = Padding(
        padding: const EdgeInsets.all(16.0),
        child: FileDropZone(
          onFileSelected: _onFileSelected,
          allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif'],
          typeLabel: 'Images',
          accentColor: ImageViewerTool.config.accentColor,
          title: 'Drop an image here',
          subtitle: 'Supports PNG, JPEG, WebP, BMP, GIF',
          icon: Icons.image_outlined,
          buttonLabel: 'Browse Images',
          buttonIcon: Icons.photo_library_outlined,
        ),
      );
    } else {
      if (isWideScreen) {
        mainContent = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: displayWidget,
              ),
            ),
            if (_isEditorOpen)
              Container(
                width: 320,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                child: editorWidget,
              ),
          ],
        );
      } else {
        mainContent = Padding(
          padding: const EdgeInsets.all(12.0),
          child: displayWidget,
        );
      }
    }

    final List<Widget>? actions = _imageBytes != null
        ? [
            if (isWideScreen)
              IconButton(
                icon: Icon(
                  _isEditorOpen
                      ? Icons.view_sidebar
                      : Icons.view_sidebar_outlined,
                ),
                onPressed: () => setState(() => _isEditorOpen = !_isEditorOpen),
                tooltip: _isEditorOpen ? 'Hide settings' : 'Show settings',
              )
            else
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                tooltip: 'Edit image',
              ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _onClose,
              tooltip: 'Close image',
            ),
          ]
        : null;

    final Widget? fab = (_imageBytes != null && !isWideScreen)
        ? FloatingActionButton(
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            tooltip: 'Edit image',
            child: const Icon(Icons.tune),
          )
        : null;

    final Widget? endDrawer = (_imageBytes != null && !isWideScreen)
        ? Drawer(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppBar(
                    title: const Text('Edit Image'),
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  Expanded(child: editorWidget),
                ],
              ),
            ),
          )
        : null;

    return ToolLayout(
      title: ImageViewerTool.config.name,
      fullscreen: ImageViewerTool.config.fullscreen,
      scaffoldKey: _scaffoldKey,
      actions: actions,
      floatingActionButton: fab,
      endDrawer: endDrawer,
      child: mainContent,
    );
  }
}

class ImageResizeParams {
  final Uint8List bytes;
  final int width;
  final int height;
  final String format;
  final int quality;
  final bool preserveExif;

  ImageResizeParams({
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
    required this.quality,
    required this.preserveExif,
  });
}

Uint8List _resizeAndEncodeTask(ImageResizeParams params) {
  final decoded = img.decodeImage(params.bytes);
  if (decoded == null) {
    throw Exception('Could not decode original image');
  }

  final resized = img.copyResize(
    decoded,
    width: params.width,
    height: params.height,
    interpolation: img.Interpolation.average,
  );

  List<int> encoded;
  switch (params.format) {
    case 'jpg':
    case 'jpeg':
      encoded = img.encodeJpg(resized, quality: params.quality);
      if (params.preserveExif) {
        try {
          final injected = img.injectJpgExif(
            Uint8List.fromList(encoded),
            decoded.exif,
          );
          if (injected != null) {
            encoded = injected;
          }
        } catch (_) {
          // ignore or fallback
        }
      }
      break;
    case 'png':
      encoded = img.encodePng(resized);
      break;
    case 'bmp':
      encoded = img.encodeBmp(resized);
      break;
    default:
      encoded = img.encodePng(resized);
  }

  return Uint8List.fromList(encoded);
}

class ImageMetadata {
  final Map<String, Map<String, String>> exifTags;
  final double? latitude;
  final double? longitude;
  final String? gpsDMS;

  ImageMetadata({
    required this.exifTags,
    this.latitude,
    this.longitude,
    this.gpsDMS,
  });
}

ImageMetadata _extractMetadataTask(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return ImageMetadata(exifTags: {});
    }

    final exif = decoded.exif;
    final tags = <String, Map<String, String>>{};

    void extractDirectory(String name, img.IfdDirectory? dir) {
      if (dir == null || dir.isEmpty) return;
      final map = <String, String>{};
      for (final key in dir.keys) {
        final tagName = exif.getTagName(key);
        final val = dir[key];
        if (val != null) {
          map[tagName] = val.toString();
        }
      }
      if (map.isNotEmpty) {
        tags[name] = map;
      }
    }

    extractDirectory('Image Info', exif.imageIfd);
    extractDirectory('Exif Info', exif.exifIfd);
    extractDirectory('GPS Info', exif.gpsIfd);
    extractDirectory('Thumbnail Info', exif.thumbnailIfd);
    extractDirectory('Interop Info', exif.interopIfd);

    double? lat;
    double? lon;
    String? gpsDMS;

    final gpsDir = exif.gpsIfd;
    if (!gpsDir.isEmpty) {
      final latVal = gpsDir[2]; // Tag 2 is GPSLatitude
      final latRef = gpsDir.gpsLatitudeRef;
      final lonVal = gpsDir[4]; // Tag 4 is GPSLongitude
      final lonRef = gpsDir.gpsLongitudeRef;

      final parsedLat = _parseGpsCoordinate(latVal, latRef);
      final parsedLon = _parseGpsCoordinate(lonVal, lonRef);

      if (parsedLat != null && parsedLon != null) {
        lat = parsedLat;
        lon = parsedLon;
        gpsDMS =
            '${_formatDMS(latVal, latRef)} / ${_formatDMS(lonVal, lonRef)}';
      }
    }

    return ImageMetadata(
      exifTags: tags,
      latitude: lat,
      longitude: lon,
      gpsDMS: gpsDMS,
    );
  } catch (e) {
    debugPrint("Failed to extract metadata: $e");
    return ImageMetadata(exifTags: {});
  }
}

double? _parseGpsCoordinate(dynamic value, String? ref) {
  if (value == null) return null;
  try {
    final str = value.toString();
    final matches = RegExp(r'\d+/\d+|\d+\.\d+|\d+').allMatches(str);
    final List<double> parts = [];
    for (final m in matches) {
      final tok = m.group(0)!;
      if (tok.contains('/')) {
        final fraction = tok.split('/');
        final numVal = double.tryParse(fraction[0]);
        final denVal = double.tryParse(fraction[1]);
        if (numVal != null && denVal != null && denVal != 0) {
          parts.add(numVal / denVal);
        }
      } else {
        final parsed = double.tryParse(tok);
        if (parsed != null) parts.add(parsed);
      }
    }

    if (parts.length >= 3) {
      double decimal = parts[0] + (parts[1] / 60.0) + (parts[2] / 3600.0);
      if (ref == 'S' || ref == 'W') {
        decimal = -decimal;
      }
      return decimal;
    } else if (parts.length == 1) {
      double decimal = parts[0];
      if (ref == 'S' || ref == 'W') {
        decimal = -decimal;
      }
      return decimal;
    }
  } catch (e) {
    debugPrint("Failed to parse GPS coordinate: $e");
  }
  return null;
}

String _formatDMS(dynamic value, String? ref) {
  if (value == null) return '';
  try {
    final str = value.toString();
    final matches = RegExp(r'\d+/\d+|\d+\.\d+|\d+').allMatches(str);
    final List<double> parts = [];
    for (final m in matches) {
      final tok = m.group(0)!;
      if (tok.contains('/')) {
        final fraction = tok.split('/');
        final numVal = double.tryParse(fraction[0]);
        final denVal = double.tryParse(fraction[1]);
        if (numVal != null && denVal != null && denVal != 0) {
          parts.add(numVal / denVal);
        }
      } else {
        final parsed = double.tryParse(tok);
        if (parsed != null) parts.add(parsed);
      }
    }

    if (parts.length >= 3) {
      return "${parts[0].round()}° ${parts[1].round()}' ${parts[2].toStringAsFixed(2)}\" ${ref ?? ''}";
    }
  } catch (_) {}
  return '$value ${ref ?? ''}';
}
