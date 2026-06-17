import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_operation_session.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_extract_images_empty_state.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_extract_images_error_state.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_extract_images_grid.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_extract_images_header.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_extract_images_item.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class PdfExtractImagesPanel extends StatefulWidget {
  final PdfOperationSession session;
  final VoidCallback onCancel;

  const PdfExtractImagesPanel({
    super.key,
    required this.session,
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
  bool _didStartLoad = false;
  double _progress = 0;
  String _statusText = '';
  String? _errorText;

  List<PdfExtractedImageItem> _items = [];
  final Set<String> _selectedIds = <String>{};

  String get _baseName => widget.session.fileName.replaceAll('.pdf', '');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitControlsExpanded) {
      final media = MediaQuery.of(context);
      final isCompactScreen = media.size.width < 600 || media.size.height < 760;
      _controlsExpanded = !isCompactScreen;
      _didInitControlsExpanded = true;
    }
    // Kick off loading here (not in initState) so AppLocalizations.of(context)
    // is a legal inherited-widget lookup.
    if (!_didStartLoad) {
      _didStartLoad = true;
      _loadImages();
    }
  }

  Future<void> _loadImages() async {
    PdfDocument? doc;
    try {
      final l10n = AppLocalizations.of(context);
      setState(() {
        _isLoading = true;
        _progress = 0;
        _statusText = l10n.pdfEditExtractScanning;
        _errorText = null;
        _items = [];
        _selectedIds.clear();
      });

      doc = await widget.session.openDocument();
      final extracted = await PdfEngineHelper.extractEmbeddedImages(
        doc,
        deduplicate: true,
        includeAnnotations: true,
        onProgress: (done, total) {
          if (!mounted) {
            return;
          }
          final l10nCb = AppLocalizations.of(context);
          setState(() {
            _progress = total == 0 ? 0 : done / total;
            _statusText = l10nCb.pdfEditExtractScanningObjects(done, total);
          });
        },
      );

      final items = <PdfExtractedImageItem>[];
      if (mounted && extracted.isNotEmpty) {
        final l10nPrep = AppLocalizations.of(context);
        setState(() {
          _progress = 0;
          _statusText = l10nPrep.pdfEditExtractPreparingImages(
            0,
            extracted.length,
          );
        });
      }
      for (int i = 0; i < extracted.length; i++) {
        final image = extracted[i];
        final extension = image.fileExtension;
        final fileName =
            '${_baseName}_p${image.pageNumber}_img${i + 1}_${image.checksum.substring(0, 8)}.$extension';
        final path = await widget.session.tempScope.createFile(
          fileName,
          bytes: image.bytes,
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
        if (mounted && ((i + 1) % 8 == 0 || i + 1 == extracted.length)) {
          final l10nProg = AppLocalizations.of(context);
          setState(() {
            final done = i + 1;
            _progress = extracted.isEmpty ? 0 : done / extracted.length;
            _statusText = l10nProg.pdfEditExtractPreparingImages(
              done,
              extracted.length,
            );
          });
        }
      }

      if (!mounted) {
        return;
      }

      final l10nDone = AppLocalizations.of(context);
      setState(() {
        _items = items;
        _isLoading = false;
        _progress = 1;
        _statusText = l10nDone.pdfEditExtractImagesFound(items.length);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      final l10nErr = AppLocalizations.of(context);
      final message = l10nErr.pdfEditExtractFailed(e.toString());
      setState(() {
        _isLoading = false;
        _statusText = message;
        _errorText = message;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isExporting = true;
      _progress = 0;
      _statusText = l10n.pdfEditExtractCreatingZip(0, items.length);
    });
    final encoder = ZipFileEncoder();
    var hasOpenZip = false;
    try {
      final zipPath = await widget.session.tempScope.createFile(zipName);
      encoder.create(zipPath);
      hasOpenZip = true;
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        await encoder.addFile(File(item.path), item.fileName);
        if (!mounted) {
          continue;
        }
        final l10nZip = AppLocalizations.of(context);
        setState(() {
          final done = i + 1;
          _progress = items.isEmpty ? 0 : done / items.length;
          _statusText = l10nZip.pdfEditExtractCreatingZip(done, items.length);
        });
      }
      await encoder.close();
      hasOpenZip = false;
      if (!mounted) {
        return;
      }
      final l10nReady = AppLocalizations.of(context);
      setState(() {
        _statusText = l10nReady.pdfEditExtractZipReady;
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
      final l10nErr = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10nErr.pdfEditExtractZipFailed(e.toString()))),
      );
    } finally {
      if (hasOpenZip) {
        try {
          await encoder.close();
        } catch (_) {}
      }
      if (mounted) {
        final l10nFin = AppLocalizations.of(context);
        setState(() {
          _isExporting = false;
          _statusText = l10nFin.pdfEditExtractImagesFound(_items.length);
          _progress = 1;
        });
      }
    }
  }

  void _showPreview(PdfExtractedImageItem item) {
    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
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
              child: Text(l10n.commonClose),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _downloadSingle(item);
              },
              icon: const Icon(Icons.download),
              label: Text(l10n.pdfEditDownload),
            ),
          ],
          scrollable: true,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final isCompactScreen = media.size.width < 600 || media.size.height < 760;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pdfEditExtractTitle(widget.session.fileName)),
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
                : _errorText != null
                ? PdfExtractImagesErrorState(
                    message: _errorText!,
                    onRetry: _loadImages,
                  )
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
