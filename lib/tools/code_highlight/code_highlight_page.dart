import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';

import 'config.dart';
import 'code_highlight_state.dart';
import 'widgets/code_highlight_toolbar.dart';
import 'widgets/code_highlight_editor.dart';

class CodeHighlightToolPage extends StatefulWidget {
  final SharedFile? sharedFile;

  const CodeHighlightToolPage({super.key, this.sharedFile});

  @override
  State<CodeHighlightToolPage> createState() => _CodeHighlightToolPageState();
}

class _CodeHighlightToolPageState extends State<CodeHighlightToolPage>
    with DisposeCleanup {
  late final TempFileScope _scope;
  late final CodeHighlightState _highlightState;

  @override
  void initState() {
    super.initState();
    _scope = TempFileManager.createScope();
    onDispose(() => _scope.cleanTracked());

    _highlightState = context.read<CodeHighlightState>();
    onDispose(() {
      _highlightState.clear(notify: false);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CodeHighlightState>().initialize();
      if (widget.sharedFile != null) {
        _loadSharedFile(widget.sharedFile!);
      }
    });

    final sharingSub = SharingService.instance.onSharedFile.listen((file) {
      _loadSharedFile(file);
    });
    onDispose(sharingSub.cancel);
  }

  Future<void> _loadSharedFile(SharedFile file) async {
    try {
      final diskFile = File(file.path);
      if (await diskFile.exists()) {
        final text = await diskFile.readAsString();
        if (mounted) {
          final state = context.read<CodeHighlightState>();
          final lang = state.detectLanguage(file.name);
          state.loadFile(text, file.name, lang);
        }
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.codeHighlightFailedToLoad(e.toString()))),
        );
      }
    }
  }

  Future<void> _onFileSelected(XFile file) async {
    try {
      final content = await file.readAsString();
      if (mounted) {
        final state = context.read<CodeHighlightState>();
        final lang = state.detectLanguage(file.name);
        state.loadFile(content, file.name, lang);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.codeHighlightFailedToLoad(e.toString()))),
        );
      }
    }
  }

  void _onClose() {
    final state = context.read<CodeHighlightState>();
    state.clear();
    if (widget.sharedFile != null) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _copyToClipboard(String text, AppLocalizations l10n) async {
    try {
      await ClipboardHelper.setText(text);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.codeHighlightCopied)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.codeHighlightFailedToCopy(e.toString()))),
        );
      }
    }
  }

  Future<void> _exportFile(String text, String? fileName) async {
    final bytes = Uint8List.fromList(utf8.encode(text));
    await FileSaveHelper.saveFile(
      context: context,
      suggestedName: fileName ?? 'code.txt',
      bytes: bytes,
    );
  }

  Future<void> _shareFile(String text, String? fileName) async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(text));
      final path = await _scope.createFile(
        fileName ?? 'code.txt',
        bytes: bytes,
      );
      if (mounted) {
        await FileSaveHelper.showShareChooser(
          context: context,
          path: path,
          mimeType: 'text/plain',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<CodeHighlightState>();
    final accent = CodeHighlightTool.config.accentColor;

    if (!state.initialized) {
      return Scaffold(
        appBar: AppBar(
          title: Text(CodeHighlightTool.config.localizedName(l10n)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (state.code == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(CodeHighlightTool.config.localizedName(l10n)),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FileDropZone(
            onFileSelected: _onFileSelected,
            allowedExtensions: CodeHighlightTool.config.fileExtensions,
            typeLabel: l10n.codeHighlightTypeLabel,
            accentColor: accent,
            title: l10n.codeHighlightOpenTitle,
            subtitle: l10n.codeHighlightDropSubtitle,
            icon: Icons.code,
            extraButtons: [
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final text = await ClipboardHelper.getText();
                  if (text != null && text.trim().isNotEmpty) {
                    state.loadFile(text, 'pasted_code.txt', 'dart');
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Clipboard is empty or does not contain text',
                          ),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.paste),
                label: Text(l10n.codeHighlightPasteCode),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  state.setCode('');
                },
                icon: const Icon(Icons.edit_note),
                label: const Text('Create Blank File'),
              ),
            ],
          ),
        ),
      );
    }

    return ToolLayout(
      title: CodeHighlightTool.config.localizedName(l10n),
      fullscreen: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.copy),
          tooltip: l10n.commonCopy,
          onPressed: () => _copyToClipboard(state.code!, l10n),
        ),
        IconButton(
          icon: const Icon(Icons.share),
          tooltip: l10n.commonShare,
          onPressed: () => _shareFile(state.code!, state.fileName),
        ),
        IconButton(
          icon: const Icon(Icons.download),
          tooltip: l10n.commonExport,
          onPressed: () => _exportFile(state.code!, state.fileName),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.commonClose,
          onPressed: _onClose,
        ),
      ],
      child: Column(
        children: [
          CodeHighlightToolbar(onReset: _onClose),
          const Divider(height: 1),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CodeHighlightEditor(),
            ),
          ),
        ],
      ),
    );
  }
}
