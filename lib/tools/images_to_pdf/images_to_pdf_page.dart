import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart'
    show XFile, XTypeGroup, openFiles;
import 'package:image_picker/image_picker.dart' show ImagePicker;
import 'package:tool_lab/core/tool_localization.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:tool_lab/tools/images_to_pdf/config.dart';
import 'package:tool_lab/tools/images_to_pdf/widgets/images_to_pdf_preview.dart';
import 'package:tool_lab/tools/images_to_pdf/widgets/images_to_pdf_progress.dart';
import 'package:tool_lab/tools/images_to_pdf/widgets/images_to_pdf_toolbar.dart';
import 'package:tool_lab/tools/images_to_pdf/widgets/images_to_pdf_settings_drawer.dart';

class ImagesToPdfPage extends StatefulWidget {
  const ImagesToPdfPage({super.key});

  @override
  State<ImagesToPdfPage> createState() => _ImagesToPdfPageState();
}

class _ImagesToPdfPageState extends State<ImagesToPdfPage> with DisposeCleanup {
  final List<_ImageItem> _items = [];
  bool _isProcessing = false;
  bool _dragging = false;
  double _progress = 0;
  String _progressText = '';

  ImageToPdfPageSize _pageSize = ImageToPdfPageSize.fit;
  bool _landscape = false;
  int _jpegQuality = 90;

  late final TempFileScope _tempScope;
  int _seq = 0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _tempScope = TempFileManager.createScope();
    onDispose(() => _tempScope.cleanTracked());
  }

  void _addItem(_ImageItem item) {
    if (mounted) setState(() => _items.add(item));
  }

  // For in-memory sources (clipboard) with no backing file — spool to temp.
  Future<void> _addImageBytes(Uint8List bytes, String name) async {
    try {
      final safe = name.replaceAll(RegExp(r'[^\w\-.]'), '_');
      final tempName = 'img_${_seq++}_$safe';
      final path = await _tempScope.createFile(tempName, bytes: bytes);
      _addItem(_ImageItem(path: path, tempName: tempName, name: name));
    } catch (e) {
      debugPrint('[ImagesToPdf] Failed to load $name: $e');
    }
  }

  Future<void> _addFiles(List<XFile> files) async {
    for (final file in files) {
      if (file.path.isNotEmpty) {
        // Reference the existing file directly — no copy of bytes to temp.
        _addItem(_ImageItem(path: file.path, name: file.name));
      } else {
        try {
          await _addImageBytes(await file.readAsBytes(), file.name);
        } catch (e) {
          debugPrint('[ImagesToPdf] Failed to load ${file.name}: $e');
        }
      }
    }
  }

  Future<void> _onDropFiles(List<XFile> files) async {
    await _addFiles(files);
  }

  Future<void> _onFileSelected(XFile file) async {
    await _addFiles([file]);
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final bytes = await ClipboardHelper.getImagePng();
      if (bytes != null) {
        await _addImageBytes(bytes, 'clipboard_$_seq.png');
      } else if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.img2pdfNoImageInClipboard)));
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.img2pdfFailedReadClipboard(e.toString())),
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      final xFiles = pickedFiles
          .map((f) => XFile(f.path, name: f.name))
          .toList();
      await _addFiles(xFiles);
    }
  }

  void _removeImage(int index) {
    final item = _items[index];
    setState(() => _items.removeAt(index));
    final tempName = item.tempName;
    if (tempName != null) _tempScope.deleteFile(tempName);
  }

  void _reorderImages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  Future<void> _createPdf() async {
    if (_items.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isProcessing = true;
      _progress = 0;
      _progressText = l10n.img2pdfPreparing;
    });

    try {
      final pdfBytes = await PdfEngineHelper.createPdfFromImagePaths(
        _items.map((i) => i.path).toList(),
        pageSize: _pageSize,
        jpegQuality: _jpegQuality,
        landscape: _landscape,
        onProgress: (done, total) {
          if (mounted) {
            setState(() {
              _progress = total == 0 ? 0 : done / total;
              _progressText = l10n.img2pdfProcessingImage(done, total);
            });
          }
        },
      ).timeout(const Duration(minutes: 5));

      if (mounted) {
        setState(() {
          _progress = 1;
          _progressText = l10n.img2pdfSavingPdf;
        });
      }

      // Hand the saver a path so the PDF bytes are not re-buffered for sharing.
      final pdfPath = await _tempScope.createFile(
        'images_export.pdf',
        bytes: pdfBytes,
      );

      if (!mounted) return;

      await FileSaveHelper.saveFileFromPath(
        context: context,
        suggestedName: 'images_export.pdf',
        sourcePath: pdfPath,
        successMessageGeneralBuilder: (path) => l10n.img2pdfSavedTo(path),
        errorMessageBuilder: (e) => l10n.img2pdfSaveFailed(e),
      );
    } catch (e) {
      if (mounted) {
        FileSaveHelper.showErrorNotification(
          context: context,
          errorMessage: l10n.img2pdfCreateFailed(e.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ToolLayout(
      title: ImagesToPdfTool.config.localizedName(l10n),
      scaffoldKey: _scaffoldKey,
      actions: _items.isEmpty
          ? null
          : [
              IconButton(
                tooltip: l10n.img2pdfSettingsTooltip,
                icon: const Icon(Icons.tune),
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
            ],
      endDrawer: ImagesToPdfSettingsDrawer(
        pageSize: _pageSize,
        onPageSizeChanged: (v) => setState(() => _pageSize = v),
        landscape: _landscape,
        onLandscapeChanged: (v) => setState(() => _landscape = v),
        jpegQuality: _jpegQuality,
        onJpegQualityChanged: (v) => setState(() => _jpegQuality = v),
        isProcessing: _isProcessing,
      ),
      child: Column(
        children: [
          Expanded(
            child: _items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: FileDropZone(
                      onFilesSelected: _onDropFiles,
                      onFileSelected: _onFileSelected,
                      allowedExtensions: ImagesToPdfTool.config.fileExtensions,
                      typeLabel: l10n.img2pdfImagesLabel,
                      accentColor: ImagesToPdfTool.config.accentColor,
                      icon: Icons.collections_bookmark_outlined,
                      title: l10n.img2pdfDropTitle,
                      subtitle: l10n.img2pdfDropSubtitle,
                      buttonLabel: l10n.img2pdfBrowseFiles,
                      buttonIcon: Icons.folder_open,
                      multiple: true,
                      extraButtons: [
                        const SizedBox(height: 16),
                        _DropZoneActionButton(
                          onPressed: _pasteFromClipboard,
                          icon: Icons.paste_outlined,
                          label: l10n.img2pdfPasteFromClipboard,
                        ),
                        if (Platform.isAndroid) ...[
                          const SizedBox(height: 12),
                          _DropZoneActionButton(
                            onPressed: _pickFromGallery,
                            icon: Icons.photo_library_outlined,
                            label: l10n.img2pdfPickFromGallery,
                          ),
                        ],
                      ],
                    ),
                  )
                : DropTarget(
                    onDragDone: (details) {
                      setState(() => _dragging = false);
                      final valid = details.files.where((f) {
                        final name = f.name.toLowerCase();
                        return ImagesToPdfTool.config.fileExtensions.any(
                          (ext) => name.endsWith('.${ext.toLowerCase()}'),
                        );
                      }).toList();
                      if (valid.isNotEmpty) _onDropFiles(valid);
                    },
                    onDragEntered: (_) => setState(() => _dragging = true),
                    onDragExited: (_) => setState(() => _dragging = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _dragging
                              ? ImagesToPdfTool.config.accentColor
                              : Colors.transparent,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: ImagesToPdfPreview(
                        paths: _items.map((i) => i.path).toList(),
                        names: _items.map((i) => i.name).toList(),
                        onRemove: _removeImage,
                        onReorder: _reorderImages,
                      ),
                    ),
                  ),
          ),
          if (_isProcessing)
            ImagesToPdfProgress(progress: _progress, statusText: _progressText),
          ImagesToPdfToolbar(
            imageCount: _items.length,
            isProcessing: _isProcessing,
            onPaste: _pasteFromClipboard,
            onAddMore: () async {
              final files = await openFiles(
                acceptedTypeGroups: [
                  XTypeGroup(
                    label: 'Images',
                    extensions: ImagesToPdfTool.config.fileExtensions,
                    mimeTypes: ['image/*'],
                  ),
                ],
              );
              if (files.isNotEmpty) await _addFiles(files);
            },
            onCreatePdf: _createPdf,
          ),
        ],
      ),
    );
  }
}

class _ImageItem {
  final String path;
  final String? tempName;
  final String name;

  const _ImageItem({required this.path, this.tempName, required this.name});
}

class _DropZoneActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _DropZoneActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ImagesToPdfTool.config.accentColor;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: accent.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
