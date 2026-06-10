import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart'
    show XFile, XTypeGroup, openFiles;
import 'package:image_picker/image_picker.dart' show ImagePicker;
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:tool_lab/tools/images_to_pdf/config.dart';
import 'package:tool_lab/tools/images_to_pdf/images_to_pdf_preview.dart';
import 'package:tool_lab/tools/images_to_pdf/images_to_pdf_toolbar.dart';

class ImagesToPdfPage extends StatefulWidget {
  const ImagesToPdfPage({super.key});

  @override
  State<ImagesToPdfPage> createState() => _ImagesToPdfPageState();
}

class _ImagesToPdfPageState extends State<ImagesToPdfPage> with DisposeCleanup {
  final List<_ImageItem> _items = [];
  bool _isProcessing = false;
  bool _dragging = false;

  ImageToPdfPageSize _pageSize = ImageToPdfPageSize.fit;
  bool _landscape = false;
  int _jpegQuality = 90;

  late final TempFileScope _tempScope;

  static const _imageExtensions = ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif'];

  @override
  void initState() {
    super.initState();
    _tempScope = TempFileManager.createScope();
    onDispose(() => _tempScope.cleanTracked());
  }

  Future<void> _addFiles(List<XFile> files) async {
    for (final file in files) {
      try {
        final bytes = await file.readAsBytes();
        if (mounted) {
          setState(() {
            _items.add(_ImageItem(bytes: bytes, name: file.name));
          });
        }
      } catch (e) {
        debugPrint('[ImagesToPdf] Failed to load ${file.name}: $e');
      }
    }
  }

  Future<void> _onDropFiles(List<XFile> files) async {
    await _addFiles(files);
  }

  Future<void> _onFileSelected(XFile file) async {
    await _addFiles([file]);
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
    setState(() => _items.removeAt(index));
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
    setState(() => _isProcessing = true);

    try {
      final imageBytes = _items.map((i) => i.bytes).toList();
      final pdfBytes = await PdfEngineHelper.createPdfFromImages(
        imageBytes,
        pageSize: _pageSize,
        jpegQuality: _jpegQuality,
        landscape: _landscape,
      );

      if (!mounted) return;

      await FileSaveHelper.saveFile(
        context: context,
        suggestedName: 'images_export.pdf',
        bytes: pdfBytes,
        successMessageGeneralBuilder: (path) => 'PDF saved to $path',
        errorMessageBuilder: (e) => 'Failed to save PDF: $e',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolLayout(
      title: ImagesToPdfTool.config.name,
      child: Column(
        children: [
          Expanded(
            child: _items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: FileDropZone(
                      onFilesSelected: _onDropFiles,
                      onFileSelected: _onFileSelected,
                      allowedExtensions: _imageExtensions,
                      typeLabel: 'Images',
                      accentColor: ImagesToPdfTool.config.accentColor,
                      icon: Icons.collections_bookmark_outlined,
                      title: 'Drop images here',
                      subtitle: 'Supports PNG, JPEG, WebP, BMP, GIF',
                      buttonLabel: 'Browse Files',
                      buttonIcon: Icons.folder_open,
                      multiple: true,
                      extraButtons: [
                        if (Platform.isAndroid) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _pickFromGallery,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Pick from Gallery'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  ImagesToPdfTool.config.accentColor,
                              side: BorderSide(
                                color: ImagesToPdfTool.config.accentColor
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
                      ],
                    ),
                  )
                : DropTarget(
                    onDragDone: (details) {
                      setState(() => _dragging = false);
                      final valid = details.files.where((f) {
                        final name = f.name.toLowerCase();
                        return _imageExtensions.any(
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
                        images: _items.map((i) => i.bytes).toList(),
                        names: _items.map((i) => i.name).toList(),
                        onRemove: _removeImage,
                        onReorder: _reorderImages,
                      ),
                    ),
                  ),
          ),
          if (_isProcessing) LinearProgressIndicator(),
          ImagesToPdfToolbar(
            imageCount: _items.length,
            pageSize: _pageSize,
            onPageSizeChanged: (v) => setState(() => _pageSize = v),
            landscape: _landscape,
            onLandscapeChanged: (v) => setState(() => _landscape = v),
            jpegQuality: _jpegQuality,
            onJpegQualityChanged: (v) => setState(() => _jpegQuality = v),
            isProcessing: _isProcessing,
            onAddMore: () async {
              final files = await openFiles(
                acceptedTypeGroups: [
                  XTypeGroup(
                    label: 'Images',
                    extensions: _imageExtensions,
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
  final Uint8List bytes;
  final String name;

  const _ImageItem({required this.bytes, required this.name});
}
