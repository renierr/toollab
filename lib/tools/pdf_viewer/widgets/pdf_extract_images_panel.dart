import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_extract_images_empty_state.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_extract_images_grid.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_extract_images_header.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_extract_images_item.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class PdfExtractImagesPanel extends StatefulWidget {
  final String filePath;
  final String fileName;
  final TempFileScope tempScope;
  final VoidCallback onCancel;

  const PdfExtractImagesPanel({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.tempScope,
    required this.onCancel,
  });

  @override
  State<PdfExtractImagesPanel> createState() => _PdfExtractImagesPanelState();
}

class _PdfExtractImagesPanelState extends State<PdfExtractImagesPanel> {
  bool _isLoading = true;
  bool _isExporting = false;
  bool _controlsExpanded = true;
  bool _didInitControlsExpanded = false;
  double _progress = 0;
  String _statusText = '';

  List<PdfExtractedImageItem> _items = [];
  final Set<String> _selectedIds = <String>{};

  String get _baseName => widget.fileName.replaceAll('.pdf', '');

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitControlsExpanded) {
      return;
    }
    final media = MediaQuery.of(context);
    final isCompactScreen = media.size.width < 600 || media.size.height < 760;
    _controlsExpanded = !isCompactScreen;
    _didInitControlsExpanded = true;
  }

  Future<void> _loadImages() async {
    setState(() {
      _isLoading = true;
      _progress = 0;
      _statusText = 'Scanning PDF...';
      _items = [];
      _selectedIds.clear();
    });

    PdfDocument? doc;
    try {
      doc = await PdfEngineHelper.openPdf(widget.filePath);
      final extracted = await PdfEngineHelper.extractEmbeddedImages(
        doc,
        deduplicate: true,
        onProgress: (done, total) {
          if (!mounted) {
            return;
          }
          setState(() {
            _progress = total == 0 ? 0 : done / total;
            _statusText = 'Scanning page $done of $total...';
          });
        },
      );

      final items = <PdfExtractedImageItem>[];
      for (int i = 0; i < extracted.length; i++) {
        final image = extracted[i];
        final fileName =
            '${_baseName}_p${image.pageNumber}_img${i + 1}_${image.checksum.substring(0, 8)}.png';
        final path = await widget.tempScope.createFile(
          fileName,
          bytes: image.pngBytes,
        );
        items.add(
          PdfExtractedImageItem(
            id: image.id,
            fileName: fileName,
            path: path,
            pageNumber: image.pageNumber,
            width: image.width,
            height: image.height,
            bitsPerPixel: image.bitsPerPixel,
            filters: image.filters,
          ),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
        _selectedIds.addAll(items.map((e) => e.id));
        _isLoading = false;
        _progress = 1;
        _statusText =
            '${items.length} image${items.length == 1 ? '' : 's'} found';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _statusText = 'Error: $e';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image extraction failed: $e')));
    } finally {
      doc?.dispose();
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(_items.map((e) => e.id));
    });
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  Future<void> _downloadSingle(PdfExtractedImageItem item) async {
    await FileSaveHelper.saveFileFromPath(
      context: context,
      suggestedName: item.fileName,
      sourcePath: item.path,
    );
  }

  List<PdfExtractedImageItem> get _selectedItems {
    return _items.where((item) => _selectedIds.contains(item.id)).toList();
  }

  Future<void> _downloadSelected() async {
    if (_selectedItems.isEmpty || _isExporting) {
      return;
    }
    if (_selectedItems.length == 1) {
      await _downloadSingle(_selectedItems.first);
      return;
    }
    await _downloadAsZip(_selectedItems, '${_baseName}_images_selected.zip');
  }

  Future<void> _downloadAll() async {
    if (_items.isEmpty || _isExporting) {
      return;
    }
    await _downloadAsZip(_items, '${_baseName}_images_all.zip');
  }

  Future<void> _downloadAsZip(
    List<PdfExtractedImageItem> items,
    String zipName,
  ) async {
    setState(() {
      _isExporting = true;
      _progress = 0;
      _statusText = 'Creating ZIP 0 of ${items.length}...';
    });
    final encoder = ZipFileEncoder();
    var hasOpenZip = false;
    try {
      final zipPath = await widget.tempScope.createFile(zipName);
      encoder.create(zipPath);
      hasOpenZip = true;
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        await encoder.addFile(File(item.path), item.fileName);
        if (!mounted) {
          continue;
        }
        setState(() {
          final done = i + 1;
          _progress = items.isEmpty ? 0 : done / items.length;
          _statusText = 'Creating ZIP $done of ${items.length}...';
        });
      }
      await encoder.close();
      hasOpenZip = false;
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = 'ZIP ready';
        _progress = 1;
      });
      await FileSaveHelper.saveFileFromPath(
        context: context,
        suggestedName: zipName,
        sourcePath: zipPath,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ZIP export failed: $e')));
    } finally {
      if (hasOpenZip) {
        try {
          await encoder.close();
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _isExporting = false;
          _statusText =
              '${_items.length} image${_items.length == 1 ? '' : 's'} found';
          _progress = 1;
        });
      }
    }
  }

  void _showPreview(PdfExtractedImageItem item) {
    showDialog(
      context: context,
      builder: (ctx) {
        return ResponsiveAlertDialog(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  item.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.65,
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            child: InteractiveViewer(
              maxScale: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(item.path), fit: BoxFit.contain),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _downloadSingle(item);
              },
              icon: const Icon(Icons.download),
              label: const Text('Download'),
            ),
          ],
          scrollable: true,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isCompactScreen = media.size.width < 600 || media.size.height < 760;

    return Scaffold(
      appBar: AppBar(
        title: Text('Extract Images: ${widget.fileName}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isLoading || _isExporting ? null : widget.onCancel,
        ),
      ),
      body: Column(
        children: [
          PdfExtractImagesHeader(
            totalCount: _items.length,
            selectedCount: _selectedIds.length,
            isLoading: _isLoading,
            isExporting: _isExporting,
            progress: _progress,
            statusText: _statusText,
            onSelectAll: _selectAll,
            onClearSelection: _clearSelection,
            onDownloadSelected: _downloadSelected,
            onDownloadAll: _downloadAll,
            isCompactScreen: isCompactScreen,
            controlsExpanded: _controlsExpanded,
            onToggleControlsExpanded: () {
              setState(() {
                _controlsExpanded = !_controlsExpanded;
              });
            },
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const PdfExtractImagesEmptyState()
                : PdfExtractImagesGrid(
                    items: _items,
                    selectedIds: _selectedIds,
                    onToggleSelected: _toggleSelection,
                    onPreview: _showPreview,
                    onDownload: _downloadSingle,
                  ),
          ),
        ],
      ),
    );
  }
}
