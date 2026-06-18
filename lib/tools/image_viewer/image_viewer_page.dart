import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/widgets/floating_back_button.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/tools/image_viewer/config.dart';
import 'package:tool_lab/tools/image_viewer/widgets/image_viewer_display.dart';
import 'package:tool_lab/tools/image_viewer/widgets/image_viewer_editor.dart';
import 'package:tool_lab/tools/image_viewer/widgets/image_viewer_crop_panel.dart';
import 'package:tool_lab/tools/image_viewer/widgets/image_viewer_redact_panel.dart';
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
        if (!Platform.isAndroid) unawaited(_controller.scanSiblings(file.path));
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
      if (!Platform.isAndroid && file.path.isNotEmpty) {
        unawaited(_controller.scanSiblings(file.path));
      }
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

  /// Returns true if it is safe to leave the current image — either there are
  /// no unsaved edits, or the user chose to discard them.
  Future<bool> _confirmDiscardEdits() async {
    if (!_controller.hasEdits) return true;
    final l10n = AppLocalizations.of(context);
    final discard = await ConfirmActionDialog.show(
      context: context,
      title: l10n.imgViewDiscardChangesTitle,
      message: l10n.imgViewDiscardChangesMessage,
      confirmLabel: l10n.imgViewDiscard,
      cancelLabel: l10n.imgViewKeepEditing,
    );
    return discard ?? false;
  }

  Future<void> _prevImage() async {
    if (!await _confirmDiscardEdits()) return;
    try {
      await _controller.prevSibling();
      _onResetZoom();
    } catch (e) {
      _showError('Failed to load previous image: $e');
    }
  }

  Future<void> _nextImage() async {
    if (!await _confirmDiscardEdits()) return;
    try {
      await _controller.nextSibling();
      _onResetZoom();
    } catch (e) {
      _showError('Failed to load next image: $e');
    }
  }

  void _onResetZoom() {
    setState(() {
      _transformationController.value = Matrix4.identity();
    });
  }

  Future<void> _onClose() async {
    if (widget.sharedFile != null && Navigator.of(context).canPop()) {
      // Leaves the route — PopScope handles the discard confirmation.
      Navigator.of(context).maybePop();
      return;
    }
    if (!await _confirmDiscardEdits()) return;
    _controller.clear();
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

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
                  : (_controller.isRedactMode
                        ? ImageViewerRedactPanel(
                            image: _controller.uiImage!,
                            decodedImage: _controller.decodedImage,
                            onRedactApplied:
                                (
                                  x,
                                  y,
                                  w,
                                  h,
                                  redactType,
                                  intensity,
                                  color,
                                  relativePathPoints,
                                ) async {
                                  try {
                                    await _controller.redactImage(
                                      x,
                                      y,
                                      w,
                                      h,
                                      redactType,
                                      intensity,
                                      color,
                                      relativePathPoints,
                                    );
                                    _onResetZoom();
                                  } catch (e) {
                                    _showError('Redaction failed: $e');
                                  }
                                },
                            onRedactCancelled: () =>
                                _controller.setRedactMode(false),
                          )
                        : ImageViewerDisplay(
                            image: _controller.uiImage!,
                            rawBytes: _controller.rawBytes,
                            isAnimated: _controller.isAnimated,
                            transformationController: _transformationController,
                            onResetZoom: _onResetZoom,
                            showSiblingNav: _controller.canBrowseSiblings,
                            hasPrevSibling: _controller.hasPrevSibling,
                            hasNextSibling: _controller.hasNextSibling,
                            siblingLabel: _controller.canBrowseSiblings
                                ? '${_controller.siblingIndex + 1} / ${_controller.siblingCount}'
                                : null,
                            onPrevImage: _prevImage,
                            onNextImage: _nextImage,
                          )))
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
                onToggleRedactMode: () {
                  final enteringRedact = !_controller.isRedactMode;
                  _controller.setRedactMode(enteringRedact);
                  if (enteringRedact && !isWideScreen) {
                    _scaffoldKey.currentState?.closeEndDrawer();
                  }
                },
                isRedactMode: _controller.isRedactMode,
                isWideScreen: isWideScreen,
                onSegmentSubject: Platform.isAndroid
                    ? () async {
                        final l10n = AppLocalizations.of(context);
                        if (!isWideScreen) {
                          _scaffoldKey.currentState?.closeEndDrawer();
                        }
                        try {
                          await _controller.segmentSubject();
                          _onResetZoom();
                        } catch (e) {
                          _showError(
                            l10n.imgViewSegmentSubjectFailed(e.toString()),
                          );
                        }
                      }
                    : null,
              )
            : const SizedBox.shrink();

        Widget mainContent;
        if (_controller.uiImage == null) {
          mainContent = Padding(
            padding: const EdgeInsets.all(16.0),
            child: FileDropZone(
              onFileSelected: _onFileSelected,
              allowedExtensions: ImageViewerTool.config.fileExtensions,
              typeLabel: l10n.imgViewTypeLabel,
              accentColor: ImageViewerTool.config.accentColor,
              title: l10n.imgViewDropZoneTitle,
              subtitle: l10n.imgViewDropZoneSubtitle,
              icon: Icons.image_outlined,
              buttonLabel: l10n.imgViewBrowseFiles,
              buttonIcon: Icons.folder_open,
              extraButtons: [
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.paste_outlined),
                  label: Text(l10n.imgViewPasteFromClipboard),
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
            if (!_controller.isCropMode && !_controller.isRedactMode)
              const Positioned(left: 12, top: 12, child: FloatingBackButton()),
            ImageViewerLoadingOverlay(isVisible: _controller.isProcessing),
          ],
        );

        final List<Widget>? actions =
            _controller.uiImage != null &&
                !_controller.isCropMode &&
                !_controller.isRedactMode
            ? [
                IconButton(
                  icon: const Icon(Icons.undo),
                  onPressed: _controller.canUndo
                      ? () async {
                          try {
                            await _controller.undo();
                            _onResetZoom();
                          } catch (e) {
                            _showError('Undo failed: $e');
                          }
                        }
                      : null,
                  tooltip: l10n.imgViewUndo,
                ),
                IconButton(
                  icon: const Icon(Icons.redo),
                  onPressed: _controller.canRedo
                      ? () async {
                          try {
                            await _controller.redo();
                            _onResetZoom();
                          } catch (e) {
                            _showError('Redo failed: $e');
                          }
                        }
                      : null,
                  tooltip: l10n.imgViewRedo,
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () async {
                    try {
                      await _controller.copyToClipboard();
                      _showSuccess(l10n.imgViewImageCopied);
                    } catch (e) {
                      _showError(
                        'Copy failed: ${e.toString().replaceAll('Exception: ', '')}',
                      );
                    }
                  },
                  tooltip: l10n.imgViewCopyToClipboard,
                ),
                if (isWideScreen)
                  IconButton(
                    icon: Icon(
                      _isEditorOpen
                          ? Icons.view_sidebar
                          : Icons.view_sidebar_outlined,
                    ),
                    onPressed: () {
                      setState(() => _isEditorOpen = !_isEditorOpen);
                      if (_isEditorOpen) {
                        _controller.prepareForEditing();
                      }
                    },
                    tooltip: _isEditorOpen
                        ? l10n.imgViewHideSettings
                        : l10n.imgViewShowSettings,
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.tune),
                    onPressed: () {
                      _scaffoldKey.currentState?.openEndDrawer();
                      _controller.prepareForEditing();
                    },
                    tooltip: l10n.imgViewEditImageTooltip,
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _onClose,
                  tooltip: l10n.imgViewCloseImage,
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
                        title: Text(l10n.imgViewEditImageDrawerTitle),
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

        return PopScope(
          canPop: !_controller.hasEdits,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final navigator = Navigator.of(context);
            final discard = await _confirmDiscardEdits();
            if (!mounted || !discard) return;
            navigator.pop();
          },
          child: ToolLayout(
            title: ImageViewerTool.config.localizedName(l10n),
            fullscreen: true,
            showFloatingBackButton: false,
            scaffoldKey: _scaffoldKey,
            actions: actions,
            floatingActionButton: fab,
            endDrawer: endDrawer,
            child: bodyContent,
          ),
        );
      },
    );
  }
}
