import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
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
  bool _deduplicate = true;
  bool _isLoading = true;
  bool _isExporting = false;
  double _progress = 0;
  String _statusText = '';

  List<_ExtractedImageItem> _items = [];
  final Set<String> _selectedIds = <String>{};

  String get _baseName => widget.fileName.replaceAll('.pdf', '');

  @override
  void initState() {
    super.initState();
    _loadImages();
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
        deduplicate: _deduplicate,
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

      final items = <_ExtractedImageItem>[];
      for (int i = 0; i < extracted.length; i++) {
        final image = extracted[i];
        final fileName =
            '${_baseName}_p${image.pageNumber}_img${i + 1}_${image.checksum.substring(0, 8)}.png';
        final path = await widget.tempScope.createFile(
          fileName,
          bytes: image.pngBytes,
        );
        items.add(
          _ExtractedImageItem(
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

  Future<void> _downloadSingle(_ExtractedImageItem item) async {
    await FileSaveHelper.saveFileFromPath(
      context: context,
      suggestedName: item.fileName,
      sourcePath: item.path,
    );
  }

  List<_ExtractedImageItem> get _selectedItems {
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
    List<_ExtractedImageItem> items,
    String zipName,
  ) async {
    setState(() {
      _isExporting = true;
    });
    try {
      final archive = Archive();
      for (final item in items) {
        final bytes = await File(item.path).readAsBytes();
        archive.addFile(ArchiveFile(item.fileName, bytes.length, bytes));
      }
      final zip = ZipEncoder().encodeBytes(archive);
      final zipPath = await widget.tempScope.createFile(zipName, bytes: zip);
      if (!mounted) {
        return;
      }
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
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  void _showPreview(_ExtractedImageItem item) {
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
          _ExtractImagesHeader(
            deduplicate: _deduplicate,
            onDeduplicateChanged: (value) async {
              if (_isExporting || _isLoading) {
                return;
              }
              setState(() => _deduplicate = value);
              await _loadImages();
            },
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
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const _ExtractImagesEmptyState()
                : _ExtractImagesGrid(
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

class _ExtractImagesHeader extends StatelessWidget {
  final bool deduplicate;
  final ValueChanged<bool> onDeduplicateChanged;
  final int totalCount;
  final int selectedCount;
  final bool isLoading;
  final bool isExporting;
  final double progress;
  final String statusText;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onDownloadSelected;
  final VoidCallback onDownloadAll;

  const _ExtractImagesHeader({
    required this.deduplicate,
    required this.onDeduplicateChanged,
    required this.totalCount,
    required this.selectedCount,
    required this.isLoading,
    required this.isExporting,
    required this.progress,
    required this.statusText,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onDownloadSelected,
    required this.onDownloadAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: deduplicate,
                      onChanged: isLoading || isExporting
                          ? null
                          : onDeduplicateChanged,
                    ),
                    const SizedBox(width: 8),
                    const Text('Deduplicate identical images'),
                  ],
                ),
                Text(
                  '$selectedCount selected / $totalCount total',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              statusText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (isLoading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress > 0 ? progress : null),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isLoading || isExporting ? null : onSelectAll,
                  icon: const Icon(Icons.select_all),
                  label: const Text('Select All'),
                ),
                OutlinedButton.icon(
                  onPressed: isLoading || isExporting ? null : onClearSelection,
                  icon: const Icon(Icons.deselect),
                  label: const Text('Clear Selection'),
                ),
                FilledButton.icon(
                  onPressed: isLoading || isExporting || selectedCount == 0
                      ? null
                      : onDownloadSelected,
                  icon: const Icon(Icons.download),
                  label: const Text('Download Selected'),
                ),
                FilledButton.tonalIcon(
                  onPressed: isLoading || isExporting || totalCount == 0
                      ? null
                      : onDownloadAll,
                  icon: const Icon(Icons.folder_zip_outlined),
                  label: const Text('Download All (ZIP)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtractImagesEmptyState extends StatelessWidget {
  const _ExtractImagesEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No embedded images found in this PDF',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtractImagesGrid extends StatelessWidget {
  final List<_ExtractedImageItem> items;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelected;
  final ValueChanged<_ExtractedImageItem> onPreview;
  final ValueChanged<_ExtractedImageItem> onDownload;

  const _ExtractImagesGrid({
    required this.items,
    required this.selectedIds,
    required this.onToggleSelected,
    required this.onPreview,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.98,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selectedIds.contains(item.id);
        return _ExtractImageCard(
          item: item,
          isSelected: isSelected,
          onToggleSelected: () => onToggleSelected(item.id),
          onPreview: () => onPreview(item),
          onDownload: () => onDownload(item),
        );
      },
    );
  }
}

class _ExtractImageCard extends StatelessWidget {
  final _ExtractedImageItem item;
  final bool isSelected;
  final VoidCallback onToggleSelected;
  final VoidCallback onPreview;
  final VoidCallback onDownload;

  const _ExtractImageCard({
    required this.item,
    required this.isSelected,
    required this.onToggleSelected,
    required this.onPreview,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filterText = item.filters.isEmpty ? '-' : item.filters.join(', ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPreview,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.file(File(item.path), fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: theme.colorScheme.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onToggleSelected,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Text(
                'Page ${item.pageNumber} • ${item.width}x${item.height}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 2),
              child: Text(
                'BPP: ${item.bitsPerPixel > 0 ? item.bitsPerPixel : '-'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
              child: Text(
                'Filter: $filterText',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onPreview,
                    icon: const Icon(Icons.zoom_in),
                    label: const Text('Preview'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtractedImageItem {
  final String id;
  final String fileName;
  final String path;
  final int pageNumber;
  final int width;
  final int height;
  final int bitsPerPixel;
  final List<String> filters;

  const _ExtractedImageItem({
    required this.id,
    required this.fileName,
    required this.path,
    required this.pageNumber,
    required this.width,
    required this.height,
    required this.bitsPerPixel,
    required this.filters,
  });
}
