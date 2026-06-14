import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_operation_session.dart';

class PdfMetadataPanel extends StatefulWidget {
  final PdfOperationSession session;
  final void Function(String pdfPath, String name) onComplete;
  final VoidCallback onCancel;

  const PdfMetadataPanel({
    super.key,
    required this.session,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  State<PdfMetadataPanel> createState() => _PdfMetadataPanelState();
}

enum _MetadataPhase { loading, editing, processing, done }

class _PdfMetadataPanelState extends State<PdfMetadataPanel> {
  _MetadataPhase _phase = _MetadataPhase.loading;
  String? _errorText;
  String? _resultPath;
  int _resultSize = 0;

  bool _isEncrypted = false;
  int? _permissionsRaw;
  int? _securityRevision;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _keywordsController = TextEditingController();
  final TextEditingController _creatorController = TextEditingController();
  final TextEditingController _producerController = TextEditingController();
  final TextEditingController _creationDateController = TextEditingController();
  final TextEditingController _modificationDateController =
      TextEditingController();
  final TextEditingController _trappedController = TextEditingController();

  bool _removePassword = false;

  String get _baseName => widget.session.fileName.replaceAll('.pdf', '');

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _subjectController.dispose();
    _keywordsController.dispose();
    _creatorController.dispose();
    _producerController.dispose();
    _creationDateController.dispose();
    _modificationDateController.dispose();
    _trappedController.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    setState(() {
      _phase = _MetadataPhase.loading;
      _errorText = null;
    });

    PdfDocument? doc;
    try {
      doc = await widget.session.openDocument();
      final metadata = await PdfEngineHelper.readMetadata(doc);
      final permissions = doc.permissions;

      if (!mounted) {
        return;
      }

      _titleController.text = metadata.title;
      _authorController.text = metadata.author;
      _subjectController.text = metadata.subject;
      _keywordsController.text = metadata.keywords;
      _creatorController.text = metadata.creator;
      _producerController.text = metadata.producer;
      _creationDateController.text = metadata.creationDate;
      _modificationDateController.text = metadata.modificationDate;
      _trappedController.text = metadata.trapped;

      setState(() {
        _isEncrypted = doc!.isEncrypted;
        _permissionsRaw = permissions?.permissions;
        _securityRevision = permissions?.securityHandlerRevision;
        _phase = _MetadataPhase.editing;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _phase = _MetadataPhase.editing;
        _errorText = 'Failed to load metadata: $e';
      });
    } finally {
      await doc?.dispose();
    }
  }

  Future<void> _saveAsNew() async {
    setState(() {
      _phase = _MetadataPhase.processing;
      _errorText = null;
    });

    PdfDocument? doc;
    try {
      doc = await widget.session.openDocument();
      final bytes = _removePassword
          ? await PdfEngineHelper.createUnsecuredCopy(doc)
          : await doc.encodePdf();

      final fileNameSuffix = _removePassword
          ? '${_baseName}_metadata_unsecured.pdf'
          : '${_baseName}_metadata.pdf';
      final resultPath = await widget.session.tempScope.createFile(
        fileNameSuffix,
        bytes: bytes,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _resultPath = resultPath;
        _resultSize = bytes.length;
        _phase = _MetadataPhase.done;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _phase = _MetadataPhase.editing;
        _errorText = 'Failed to save PDF: $e';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      await doc?.dispose();
    }
  }

  Future<void> _download() async {
    final path = _resultPath;
    if (path == null) return;
    await FileSaveHelper.saveFileFromPath(
      context: context,
      suggestedName: _removePassword
          ? '${_baseName}_metadata_unsecured.pdf'
          : '${_baseName}_metadata.pdf',
      sourcePath: path,
    );
  }

  Future<void> _share() async {
    final path = _resultPath;
    if (path == null || !mounted) return;
    await FileSaveHelper.showShareChooser(
      context: context,
      path: path,
      mimeType: 'application/pdf',
    );
  }

  Widget _buildMetadataField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildPermissionChip(ThemeData theme, String label, bool allowed) {
    return Chip(
      avatar: Icon(
        allowed ? Icons.check_circle_outline : Icons.block_outlined,
        size: 16,
        color: allowed
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildEditing(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Metadata & Security', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Save a new PDF copy. Metadata editing is prepared in UI; security can be removed from encrypted PDFs.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (_errorText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _errorText!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Document Metadata', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                _buildMetadataField('Title', _titleController),
                const SizedBox(height: 10),
                _buildMetadataField('Author', _authorController),
                const SizedBox(height: 10),
                _buildMetadataField('Subject', _subjectController),
                const SizedBox(height: 10),
                _buildMetadataField('Keywords', _keywordsController),
                const SizedBox(height: 10),
                _buildMetadataField('Creator', _creatorController),
                const SizedBox(height: 10),
                _buildMetadataField('Producer', _producerController),
                const SizedBox(height: 10),
                _buildMetadataField('Creation Date', _creationDateController),
                const SizedBox(height: 10),
                _buildMetadataField(
                  'Modification Date',
                  _modificationDateController,
                ),
                const SizedBox(height: 10),
                _buildMetadataField('Trapped', _trappedController),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Security', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  _isEncrypted
                      ? 'Encrypted (revision ${_securityRevision ?? '-'})'
                      : 'Not encrypted',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPermissionChip(
                      theme,
                      'Copy',
                      (PdfPermissions(_permissionsRaw ?? 0, 0)).allowsCopying,
                    ),
                    _buildPermissionChip(
                      theme,
                      'Print',
                      (PdfPermissions(_permissionsRaw ?? 0, 0)).allowsPrinting,
                    ),
                    _buildPermissionChip(
                      theme,
                      'Annotations',
                      (PdfPermissions(
                        _permissionsRaw ?? 0,
                        0,
                      )).allowsModifyAnnotations,
                    ),
                    _buildPermissionChip(
                      theme,
                      'Assemble',
                      (PdfPermissions(
                        _permissionsRaw ?? 0,
                        0,
                      )).allowsDocumentAssembly,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  value: _removePassword,
                  onChanged: _isEncrypted
                      ? (v) => setState(() => _removePassword = v)
                      : null,
                  title: const Text('Remove password/security on output'),
                  subtitle: Text(
                    _isEncrypted
                        ? 'Creates a new unsecured PDF copy.'
                        : 'Disabled because this PDF is not encrypted.',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saveAsNew,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save as New PDF'),
        ),
      ],
    );
  }

  Widget _buildDone(ThemeData theme) {
    final size = _resultSize;
    final sizeText = size > 1024 * 1024
        ? '${(size / (1024 * 1024)).toStringAsFixed(1)} MB'
        : size > 1024
        ? '${(size / 1024).toStringAsFixed(1)} KB'
        : '$size B';
    final outName = _removePassword
        ? '${_baseName}_metadata_unsecured.pdf'
        : '${_baseName}_metadata.pdf';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Metadata Save Complete',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'New PDF size: $sizeText',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _download,
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                ),
                OutlinedButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => widget.onComplete(_resultPath!, outName),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in Viewer'),
            ),
            TextButton(onPressed: widget.onCancel, child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Metadata: ${widget.session.fileName}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _phase == _MetadataPhase.processing
              ? null
              : widget.onCancel,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload metadata',
            onPressed: _phase == _MetadataPhase.processing
                ? null
                : _loadMetadata,
          ),
        ],
      ),
      body: switch (_phase) {
        _MetadataPhase.loading || _MetadataPhase.processing => const Center(
          child: CircularProgressIndicator(),
        ),
        _MetadataPhase.editing => _buildEditing(theme),
        _MetadataPhase.done => _buildDone(theme),
      },
    );
  }
}
