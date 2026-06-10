import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/widgets/floating_back_button.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:tool_lab/tools/image_viewer/config.dart';
import 'package:tool_lab/tools/image_viewer/widgets/image_viewer_display.dart';
import 'package:tool_lab/tools/image_viewer/widgets/image_viewer_editor.dart';
import 'package:tool_lab/tools/image_viewer/widgets/image_viewer_crop_panel.dart';
import 'package:tool_lab/tools/image_viewer/widgets/image_viewer_loading_overlay.dart';
import 'package:tool_lab/tools/image_viewer/widgets/android_picker_buttons.dart';
import 'package:tool_lab/tools/image_viewer/utils/image_editor_controller.dart';

class ImageViewerPage extends StatefulWidget {
  final SharedFile? sharedFile;

  const ImageViewerPage({super.key, this.sharedFile});

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> with DisposeCleanup {
  final ImageEditorController _controller = ImageEditorController();
  final TransformationController _transformationController =
      TransformationController();

  bool _isEditorOpen = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    onDispose(() {
      _controller.dispose();
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
        await _controller.loadImage(bytes, file.name, size);
      }
    } catch (e) {
      _showError('Failed to load image: $e');
    }
  }

  Future<void> _onFileSelected(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final size = await file.length();
      await _controller.loadImage(bytes, file.name, size);
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
        await _controller.loadImage(bytes, pickedFile.name, size);
      }
    } catch (e) {
      _showError('Failed to select image: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final size = await pickedFile.length();
        await _controller.loadImage(bytes, pickedFile.name, size);
      }
    } catch (e) {
      _showError('Failed to take photo: $e');
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final bytes = await ClipboardHelper.getImagePng();
      if (bytes != null && mounted) {
        await _controller.loadImage(bytes, 'clipboard.png', bytes.length);
      } else if (mounted) {
        _showError('No image found in clipboard');
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to read clipboard: $e');
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
        _controller.clear();
      }
    } else {
      _controller.clear();
    }
  }

  Future<void> _exportImage() async {
    try {
      await _controller.exportImage(context);
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _shareImage() async {
    try {
      await _controller.shareImage(context);
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
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

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        final displayWidget = _controller.uiImage != null
            ? (_controller.isCropMode
                  ? ImageViewerCropPanel(
                      image: _controller.uiImage!,
                      onCropApplied: (x, y, w, h) async {
                        try {
                          await _controller.cropImage(x, y, w, h);
                          _onResetZoom();
                        } catch (e) {
                          _showError('Cropping failed: $e');
                        }
                      },
                      onCropCancelled: () => _controller.setCropMode(false),
                    )
                  : ImageViewerDisplay(
                      image: _controller.uiImage!,
                      rawBytes: _controller.rawBytes,
                      isAnimated: _controller.isAnimated,
                      transformationController: _transformationController,
                      onResetZoom: _onResetZoom,
                    ))
            : const SizedBox.shrink();

        final editorWidget = _controller.uiImage != null
            ? ImageViewerEditor(
                widthController: _controller.widthController,
                heightController: _controller.heightController,
                keepAspectRatio: _controller.keepAspectRatio,
                onKeepAspectRatioChanged: (val) =>
                    _controller.setKeepAspectRatio(val),
                selectedFormat: _controller.selectedFormat,
                onFormatChanged: (val) => _controller.setSelectedFormat(val),
                quality: _controller.quality,
                onQualityChanged: (val) => _controller.setQuality(val),
                onPreview: () async {
                  try {
                    await _controller.previewResize();
                    _onResetZoom();
                  } catch (e) {
                    _showError(e.toString().replaceAll('Exception: ', ''));
                  }
                },
                onSave: _exportImage,
                onShare: _shareImage,
                isProcessing: _controller.isProcessing,
                originalDimensions:
                    '${_controller.originalWidth}x${_controller.originalHeight} px',
                originalSize: _controller.formatBytes(
                  _controller.fileSizeBytes,
                ),
                metadata: _controller.metadata,
                fileName: _controller.fileName ?? 'image.png',
                preserveExif: _controller.preserveExif,
                onPreserveExifChanged: (val) =>
                    _controller.setPreserveExif(val),
                onRotateLeft: () async {
                  try {
                    await _controller.rotateImage(270);
                    _onResetZoom();
                  } catch (e) {
                    _showError('Rotation failed: $e');
                  }
                },
                onRotateRight: () async {
                  try {
                    await _controller.rotateImage(90);
                    _onResetZoom();
                  } catch (e) {
                    _showError('Rotation failed: $e');
                  }
                },
                onFlipHorizontal: () async {
                  try {
                    await _controller.flipImage('horizontal');
                    _onResetZoom();
                  } catch (e) {
                    _showError('Flipping failed: $e');
                  }
                },
                onFlipVertical: () async {
                  try {
                    await _controller.flipImage('vertical');
                    _onResetZoom();
                  } catch (e) {
                    _showError('Flipping failed: $e');
                  }
                },
                onToggleCropMode: () {
                  final enteringCrop = !_controller.isCropMode;
                  _controller.setCropMode(enteringCrop);
                  if (enteringCrop && !isWideScreen) {
                    _scaffoldKey.currentState?.closeEndDrawer();
                  }
                },
                isCropMode: _controller.isCropMode,
                isWideScreen: isWideScreen,
              )
            : const SizedBox.shrink();

        Widget mainContent;
        if (_controller.uiImage == null) {
          mainContent = Padding(
            padding: const EdgeInsets.all(16.0),
            child: FileDropZone(
              onFileSelected: _onFileSelected,
              allowedExtensions: const [
                'png',
                'jpg',
                'jpeg',
                'webp',
                'bmp',
                'gif',
              ],
              typeLabel: 'Images',
              accentColor: ImageViewerTool.config.accentColor,
              title: 'Drop an image here',
              subtitle: 'Supports PNG, JPEG, WebP, BMP, GIF',
              icon: Icons.image_outlined,
              buttonLabel: 'Browse Files',
              buttonIcon: Icons.folder_open,
              extraButtons: [
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.paste_outlined),
                  label: const Text('Paste from Clipboard'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ImageViewerTool.config.accentColor,
                    side: BorderSide(
                      color: ImageViewerTool.config.accentColor.withValues(
                        alpha: 0.5,
                      ),
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
                if (Platform.isAndroid) ...[
                  const SizedBox(height: 16),
                  AndroidPickerButtons(
                    onPickFromGallery: _pickFromGallery,
                    onTakePhoto: _takePhoto,
                    accentColor: ImageViewerTool.config.accentColor,
                  ),
                ],
              ],
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
            mainContent = Padding(
              padding: const EdgeInsets.all(12.0),
              child: displayWidget,
            );
          }
        }

        final Widget bodyContent = Stack(
          children: [
            mainContent,
            if (!_controller.isCropMode)
              const Positioned(left: 12, top: 12, child: FloatingBackButton()),
            ImageViewerLoadingOverlay(isVisible: _controller.isProcessing),
          ],
        );

        final List<Widget>? actions =
            _controller.uiImage != null && !_controller.isCropMode
            ? [
                IconButton(
                  icon: const Icon(Icons.undo),
                  onPressed: _controller.historyIndex > 0
                      ? () async {
                          try {
                            await _controller.undo();
                            _onResetZoom();
                          } catch (e) {
                            _showError('Undo failed: $e');
                          }
                        }
                      : null,
                  tooltip: 'Undo',
                ),
                IconButton(
                  icon: const Icon(Icons.redo),
                  onPressed:
                      _controller.historyIndex < _controller.historyLength - 1
                      ? () async {
                          try {
                            await _controller.redo();
                            _onResetZoom();
                          } catch (e) {
                            _showError('Redo failed: $e');
                          }
                        }
                      : null,
                  tooltip: 'Redo',
                ),
                if (isWideScreen)
                  IconButton(
                    icon: Icon(
                      _isEditorOpen
                          ? Icons.view_sidebar
                          : Icons.view_sidebar_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _isEditorOpen = !_isEditorOpen),
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

        final Widget? fab = null;

        final Widget? endDrawer = (_controller.uiImage != null && !isWideScreen)
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
          fullscreen: true,
          showFloatingBackButton: false,
          scaffoldKey: _scaffoldKey,
          actions: actions,
          floatingActionButton: fab,
          endDrawer: endDrawer,
          child: bodyContent,
        );
      },
    );
  }
}
