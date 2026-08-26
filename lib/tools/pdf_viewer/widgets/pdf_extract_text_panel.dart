import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_operation_session.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_text_ai_qa.dart';
import 'package:tool_lab/widgets/selectable_text_view.dart';

class PdfExtractTextPanel extends StatefulWidget {
  final PdfOperationSession session;
  final VoidCallback onCancel;

  const PdfExtractTextPanel({
    super.key,
    required this.session,
    required this.onCancel,
  });

  @override
  State<PdfExtractTextPanel> createState() => _PdfExtractTextPanelState();
}

class _PdfExtractTextPanelState extends State<PdfExtractTextPanel> {
  bool _isLoading = true;
  bool _didStartLoad = false;
  double _progress = 0;
  String _statusText = '';
  String? _errorText;
  String _text = '';

  String get _baseName => widget.session.fileName.replaceAll('.pdf', '');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Kick off loading here (not in initState) so AppLocalizations.of(context)
    // is a legal inherited-widget lookup.
    if (!_didStartLoad) {
      _didStartLoad = true;
      _extractText();
    }
  }

  Future<void> _extractText() async {
    PdfDocument? doc;
    try {
      final l10n = AppLocalizations.of(context);
      setState(() {
        _isLoading = true;
        _progress = 0;
        _statusText = l10n.pdfExtractTextProgress(0, 0);
        _errorText = null;
        _text = '';
      });

      doc = await widget.session.openDocument().timeout(
        const Duration(seconds: 30),
      );
      final total = doc.pages.length;
      final buffer = StringBuffer();
      for (int i = 0; i < total; i++) {
        final pageText = await doc.pages[i].loadText();
        if (pageText != null && pageText.fullText.trim().isNotEmpty) {
          buffer.writeln(pageText.fullText);
          buffer.writeln();
        }
        if (mounted && ((i + 1) % 4 == 0 || i + 1 == total)) {
          final l10nCb = AppLocalizations.of(context);
          setState(() {
            _progress = total == 0 ? 0 : (i + 1) / total;
            _statusText = l10nCb.pdfExtractTextProgress(i + 1, total);
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _text = buffer.toString().trim();
        _isLoading = false;
        _progress = 1;
      });
    } catch (e) {
      if (!mounted) return;
      final message = AppLocalizations.of(
        context,
      ).pdfExtractTextFailed(e.toString());
      setState(() {
        _isLoading = false;
        _errorText = message;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      doc?.dispose();
    }
  }

  Future<void> _copy() async {
    final l10n = AppLocalizations.of(context);
    await ClipboardHelper.setText(_text);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.pdfExtractTextCopied)));
  }

  Future<void> _save() async {
    await FileSaveHelper.saveFile(
      context: context,
      suggestedName: '$_baseName.txt',
      bytes: Uint8List.fromList(utf8.encode(_text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasText = _text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pdfExtractTextTitle(widget.session.fileName)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                    ),
                    const SizedBox(height: 16),
                    Text(_statusText),
                  ],
                ),
              )
            : _errorText != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(_errorText!, textAlign: TextAlign.center),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: hasText ? _copy : null,
                          icon: const Icon(Icons.copy_all, size: 18),
                          label: Text(l10n.pdfExtractTextCopy),
                        ),
                        TextButton.icon(
                          onPressed: hasText ? _save : null,
                          icon: const Icon(Icons.save_alt, size: 18),
                          label: Text(l10n.pdfExtractTextSave),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: SelectableTextView(
                        text: _text,
                        emptyMessage: l10n.pdfExtractTextEmpty,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                    ),
                    child: SingleChildScrollView(
                      child: PdfTextAiQa(documentText: _text),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
