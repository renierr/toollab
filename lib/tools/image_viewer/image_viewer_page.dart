import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/tools/image_viewer/config.dart';
import 'package:tool_lab/tools/image_viewer/utils/image_metadata_extractor.dart';
import 'package:tool_lab/tools/image_viewer/widgets/image_viewer_display.dart';
import 'package:tool_lab/tools/image_viewer/widgets/image_viewer_editor.dart';
import 'package:tool_lab/tools/image_viewer/utils/image_editor_tasks.dart';
import 'package:tool_lab/tools/image_viewer/widgets/image_viewer_crop_panel.dart';

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

  // Editor and history state
  bool _isCropMode = false;
  final List<Uint8List> _history = [];
  int _historyIndex = -1;

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

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final size = await pickedFile.length();
        await _processLoadedImage(
          bytes,
          pickedFile.name,
          pickedFile.path,
          size,
        );
      }
    } catch (e) {
      _showError('Failed to select image from gallery: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final size = await pickedFile.length();
        await _processLoadedImage(
          bytes,
          pickedFile.name,
          pickedFile.path,
          size,
        );
      }
    } catch (e) {
      _showError('Failed to take photo: $e');
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
      _metadata = null;
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

          // Clear history and store initial version
          _history.clear();
          _history.add(bytes);
          _historyIndex = 0;
          _isCropMode = false;

          // Pause listeners to avoid side-effects/rounding during initialization
          _widthController.removeListener(_onWidthChanged);
          _heightController.removeListener(_onHeightChanged);

          _widthController.text = _originalWidth.toString();
          _heightController.text = _originalHeight.toString();

          _widthController.addListener(_onWidthChanged);
          _heightController.addListener(_onHeightChanged);

          // Reset zoom transformation
          _transformationController.value = Matrix4.identity();

          // Auto-detect format from file extension if possible
          final ext = name.split('.').last.toLowerCase();
          if (ext == 'png' ||
              ext == 'jpg' ||
              ext == 'jpeg' ||
              ext == 'webp' ||
              ext == 'bmp') {
            _selectedFormat = (ext == 'jpeg') ? 'jpg' : ext;
          } else {
            _selectedFormat = 'png';
          }
        });
      }

      // Load EXIF metadata in background asynchronously
      compute(extractMetadataTask, bytes)
          .then((metadata) {
            if (mounted) {
              setState(() {
                _metadata = metadata;
              });
            }
          })
          .catchError((e) {
            debugPrint("Failed to extract metadata in background: $e");
          });
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

  Future<void> _applyNewBytes(Uint8List newBytes) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final codec = await ui.instantiateImageCodec(newBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      if (mounted) {
        setState(() {
          _imageBytes = newBytes;
          _originalWidth = image.width;
          _originalHeight = image.height;

          // Clear redo history if we are editing from a middle index
          if (_historyIndex < _history.length - 1) {
            _history.removeRange(_historyIndex + 1, _history.length);
          }
          _history.add(newBytes);
          _historyIndex = _history.length - 1;

          // Sync textfields
          _widthController.removeListener(_onWidthChanged);
          _heightController.removeListener(_onHeightChanged);
          _widthController.text = _originalWidth.toString();
          _heightController.text = _originalHeight.toString();
          _widthController.addListener(_onWidthChanged);
          _heightController.addListener(_onHeightChanged);

          // Reset zoom transformation
          _transformationController.value = Matrix4.identity();
        });
      }
    } catch (e) {
      _showError('Failed to apply edits: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _undo() async {
    if (_historyIndex > 0) {
      final prevBytes = _history[_historyIndex - 1];
      setState(() {
        _isProcessing = true;
      });

      try {
        final codec = await ui.instantiateImageCodec(prevBytes);
        final frame = await codec.getNextFrame();
        final image = frame.image;

        if (mounted) {
          setState(() {
            _historyIndex--;
            _imageBytes = prevBytes;
            _originalWidth = image.width;
            _originalHeight = image.height;

            _widthController.removeListener(_onWidthChanged);
            _heightController.removeListener(_onHeightChanged);
            _widthController.text = _originalWidth.toString();
            _heightController.text = _originalHeight.toString();
            _widthController.addListener(_onWidthChanged);
            _heightController.addListener(_onHeightChanged);

            _transformationController.value = Matrix4.identity();
          });
        }
      } catch (e) {
        _showError('Undo failed: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    }
  }

  Future<void> _redo() async {
    if (_historyIndex < _history.length - 1) {
      final nextBytes = _history[_historyIndex + 1];
      setState(() {
        _isProcessing = true;
      });

      try {
        final codec = await ui.instantiateImageCodec(nextBytes);
        final frame = await codec.getNextFrame();
        final image = frame.image;

        if (mounted) {
          setState(() {
            _historyIndex++;
            _imageBytes = nextBytes;
            _originalWidth = image.width;
            _originalHeight = image.height;

            _widthController.removeListener(_onWidthChanged);
            _heightController.removeListener(_onHeightChanged);
            _widthController.text = _originalWidth.toString();
            _heightController.text = _originalHeight.toString();
            _widthController.addListener(_onWidthChanged);
            _heightController.addListener(_onHeightChanged);

            _transformationController.value = Matrix4.identity();
          });
        }
      } catch (e) {
        _showError('Redo failed: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    }
  }

  Future<void> _rotateImage(int angle) async {
    if (_imageBytes == null) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      final params = RotateParams(
        bytes: _imageBytes!,
        format: _selectedFormat,
        angle: angle,
      );
      final rotatedBytes = await compute(rotateImageTask, params);
      await _applyNewBytes(rotatedBytes);
    } catch (e) {
      _showError('Rotation failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _flipImage(String direction) async {
    if (_imageBytes == null) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      final params = FlipParams(
        bytes: _imageBytes!,
        format: _selectedFormat,
        direction: direction,
      );
      final flippedBytes = await compute(flipImageTask, params);
      await _applyNewBytes(flippedBytes);
    } catch (e) {
      _showError('Flipping failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _cropImage(int x, int y, int w, int h) async {
    if (_imageBytes == null) return;
    setState(() {
      _isProcessing = true;
      _isCropMode = false;
    });

    try {
      final params = CropParams(
        bytes: _imageBytes!,
        format: _selectedFormat,
        x: x,
        y: y,
        width: w,
        height: h,
      );
      final croppedBytes = await compute(cropImageTask, params);
      await _applyNewBytes(croppedBytes);
    } catch (e) {
      _showError('Cropping failed: $e');
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
      _history.clear();
      _historyIndex = -1;
      _isCropMode = false;
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
      final dotIndex = _fileName?.lastIndexOf('.') ?? -1;
      final originalBase = (dotIndex != -1)
          ? _fileName!.substring(0, dotIndex)
          : (_fileName ?? 'image');
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
        ? (_isCropMode
              ? ImageViewerCropPanel(
                  imageBytes: _imageBytes!,
                  onCropApplied: _cropImage,
                  onCropCancelled: () {
                    setState(() {
                      _isCropMode = false;
                    });
                  },
                )
              : ImageViewerDisplay(
                  imageBytes: _imageBytes!,
                  transformationController: _transformationController,
                  onResetZoom: _onResetZoom,
                ))
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
            onRotateLeft: () => _rotateImage(270),
            onRotateRight: () => _rotateImage(90),
            onFlipHorizontal: () => _flipImage('horizontal'),
            onFlipVertical: () => _flipImage('vertical'),
            onToggleCropMode: () {
              setState(() {
                _isCropMode = !_isCropMode;
              });
            },
            isCropMode: _isCropMode,
            isWideScreen: isWideScreen,
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
          buttonLabel: 'Browse Files',
          buttonIcon: Icons.folder_open,
          extraButtons: Platform.isAndroid
              ? [
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_outlined),
                        label: const Text('Browse Gallery'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ImageViewerTool.config.accentColor,
                          side: BorderSide(
                            color: ImageViewerTool.config.accentColor
                                .withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _takePhoto,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Take Photo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ImageViewerTool.config.accentColor,
                          side: BorderSide(
                            color: ImageViewerTool.config.accentColor
                                .withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ]
              : null,
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
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _historyIndex > 0 ? _undo : null,
              tooltip: 'Undo',
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              onPressed: _historyIndex < _history.length - 1 ? _redo : null,
              tooltip: 'Redo',
            ),
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

  // Bake orientation to ensure width/height match what the user sees in the UI
  final oriented = img.bakeOrientation(decoded);

  final resized = img.copyResize(
    oriented,
    width: params.width,
    height: params.height,
    interpolation: img.Interpolation.average,
  );

  if (!params.preserveExif) {
    resized.exif = img.ExifData();
  }

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
