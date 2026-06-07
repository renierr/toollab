import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:image/image.dart' as img;
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

  final TransformationController _transformationController =
      TransformationController();

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

      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _fileName = name;
          _fileSizeBytes = sizeBytes;
          _originalWidth = image.width;
          _originalHeight = image.height;

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

  Future<void> _exportImage(bool doShare) async {
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
      );

      final exportedBytes = await compute(_resizeAndEncodeTask, params);

      if (!mounted) return;

      // Clean up base name to construct suggested output file name
      final originalBase = _fileName?.split('.').first ?? 'image';
      final ext = _selectedFormat == 'jpg' ? 'jpg' : _selectedFormat;
      final suggestedName = '${originalBase}_resized.$ext';

      final savedPath = await FileSaveHelper.saveFile(
        context: context,
        suggestedName: suggestedName,
        bytes: exportedBytes,
        successMessageAndroid: 'Image saved to Downloads directory.',
        successMessageGeneralBuilder: (path) => 'Image saved to $path',
      );

      if (savedPath != null && doShare && mounted) {
        final mimeType = 'image/$_selectedFormat';
        await FileSaveHelper.showShareChooser(
          context: context,
          path: savedPath,
          mimeType: mimeType,
        );
      }
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
      mainContent = LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape =
              constraints.maxWidth > constraints.maxHeight + 100;

          final displayWidget = ImageViewerDisplay(
            imageBytes: _imageBytes!,
            transformationController: _transformationController,
            onResetZoom: _onResetZoom,
          );

          final editorWidget = ImageViewerEditor(
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
            onSave: () => _exportImage(false),
            onShare: () => _exportImage(true),
            isProcessing: _isProcessing,
            originalDimensions: '${_originalWidth}x$_originalHeight px',
            originalSize: _formatBytes(_fileSizeBytes),
          );

          if (isLandscape) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: displayWidget,
                  ),
                ),
                Container(
                  width: 320,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: theme.colorScheme.outline.withValues(
                          alpha: 0.15,
                        ),
                      ),
                    ),
                  ),
                  child: editorWidget,
                ),
              ],
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: displayWidget,
                  ),
                ),
                const Divider(height: 1),
                SizedBox(height: 360, child: editorWidget),
              ],
            );
          }
        },
      );
    }

    return ToolLayout(
      title: ImageViewerTool.config.name,
      fullscreen: ImageViewerTool.config.fullscreen,
      actions: _imageBytes != null
          ? [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _onClose,
                tooltip: 'Close image',
              ),
            ]
          : null,
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

  ImageResizeParams({
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
    required this.quality,
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
