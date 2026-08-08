import 'dart:io';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/pdf_export_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/markdown_view.dart';
import 'package:tool_lab/widgets/zoomable_area.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import 'package:tool_lab/tools/notes/widgets/tag_input.dart';
import 'package:tool_lab/tools/notes/widgets/markdown_text_editing_controller.dart';
import 'package:tool_lab/tools/notes/widgets/note_editor_toolbar.dart';
import 'package:tool_lab/tools/notes/widgets/note_editor_text_field.dart';
import 'package:tool_lab/tools/notes/note_image_helper.dart';
import 'package:tool_lab/core/tool_page_state.dart';

enum NoteEditMode { live, source, preview }

class NoteEditor extends StatefulWidget {
  final int? id;
  final String initialContent;
  final List<String> initialTags;
  final List<String> allTags;
  final Function(String content, List<String> tags) onSave;
  final VoidCallback onCancel;

  const NoteEditor({
    super.key,
    this.id,
    required this.initialContent,
    this.initialTags = const [],
    this.allTags = const [],
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> with DisposeCleanup {
  late final MarkdownTextEditingController _controller;
  late final FocusNode _focusNode;
  late List<String> _tags;
  late String _initialBody;

  /// Image data URIs are kept out of the editable buffer entirely — a base64
  /// blob in the text field breaks caret/selection mapping on Android.
  final Map<String, String> _imageRefs = {};

  static final _refDefinition = RegExp(r'^\[(img_ref_\d+)\]:\s*data:image/');

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isControlPressed = HardwareKeyboard.instance.isControlPressed;
    final isMetaPressed = HardwareKeyboard.instance.isMetaPressed;
    final isV = event.logicalKey == LogicalKeyboardKey.keyV;

    if (isV && (isControlPressed || isMetaPressed)) {
      _handleClipboardPaste();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _handleClipboardPaste() async {
    final imageBytes = await ClipboardHelper.getImagePng();
    if (imageBytes != null) {
      await _processAndInsertImage(imageBytes, 'pasted_image.png');
    } else {
      final text = await ClipboardHelper.getText();
      if (text != null && text.isNotEmpty) {
        _insertText(text);
      }
    }
  }

  Future<void> _processAndInsertImage(Uint8List imageBytes, String name) async {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.notesImageProcessing),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      final text = _controller.text;
      // Stored labels count too, so a deleted inline tag cannot reuse its index.
      final result = await NoteImageHelper.processImage(
        imageBytes: imageBytes,
        name: name,
        currentContent: '$text\n${_imageRefs.keys.map((l) => '[$l]').join()}',
      );

      if (result == null) {
        throw Exception('Failed to process image.');
      }

      _imageRefs[result.refLabel] = result.refDefinition;

      final selection = _controller.selection;
      final start = selection.start;
      final end = selection.end;

      final String updatedText;
      final int newCursorPos;

      if (start >= 0 && end >= 0) {
        updatedText = text.replaceRange(start, end, result.inlineTag);
        newCursorPos = start + result.inlineTag.length;
      } else {
        updatedText = '$text${result.inlineTag}';
        newCursorPos = updatedText.length;
      }

      _controller.value = TextEditingValue(
        text: updatedText,
        selection: TextSelection.collapsed(offset: newCursorPos),
      );
    } catch (e) {
      errorLog('[NoteEditor] Failed to process image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to process image: $e')));
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    final l10n = AppLocalizations.of(context);
    final isAndroid = Platform.isAndroid;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return ResponsiveAlertDialog(
          title: Text(l10n.notesImageSourceTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l10n.notesImageSourceGallery),
                onTap: () async {
                  Navigator.of(dialogCtx).pop();
                  final picker = ImagePicker();
                  final pickedFile = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (pickedFile != null) {
                    final bytes = await pickedFile.readAsBytes();
                    await _processAndInsertImage(bytes, pickedFile.name);
                  }
                },
              ),
              if (isAndroid)
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: Text(l10n.notesImageSourceCamera),
                  onTap: () async {
                    Navigator.of(dialogCtx).pop();
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(
                      source: ImageSource.camera,
                    );
                    if (pickedFile != null) {
                      final bytes = await pickedFile.readAsBytes();
                      await _processAndInsertImage(bytes, pickedFile.name);
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.paste_outlined),
                title: Text(l10n.notesImageSourceClipboard),
                onTap: () async {
                  Navigator.of(dialogCtx).pop();
                  final bytes = await ClipboardHelper.getImagePng();
                  if (bytes == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.notesImageSourceClipboardEmpty),
                        ),
                      );
                    }
                  } else {
                    await _processAndInsertImage(bytes, 'pasted_image.png');
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(l10n.commonCancel),
            ),
          ],
        );
      },
    );
  }

  NoteEditMode _editMode = NoteEditMode.live;
  bool _optionsExpanded = true;

  String _extractBody(String content) {
    final kept = <String>[];
    for (final line in content.split('\n')) {
      final match = _refDefinition.firstMatch(line);
      if (match != null) {
        _imageRefs[match.group(1)!] = line;
        continue;
      }
      kept.add(line);
    }
    return kept.join('\n').trimRight();
  }

  /// Body plus the reference definitions still referenced by it (drops stale).
  String _composeContent() {
    final body = _controller.text.trimRight();
    final used = RegExp(
      r'\[(img_ref_\d+)\]',
    ).allMatches(body).map((m) => m.group(1)!).toSet();
    final refs = _imageRefs.entries
        .where((e) => used.contains(e.key))
        .map((e) => e.value)
        .toList();
    if (refs.isEmpty) return body;
    return '$body\n\n${refs.join('\n')}\n';
  }

  @override
  void initState() {
    super.initState();
    _initialBody = _extractBody(widget.initialContent);
    _controller = MarkdownTextEditingController(
      text: _initialBody,
      accentColor: AppTheme.accentTeal,
      showRawSource: _editMode == NoteEditMode.source,
    );
    onDispose(_controller.dispose);
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
    onDispose(_focusNode.dispose);
    _tags = List.from(widget.initialTags);
    _controller.addListener(() {
      setState(() {});
    });
  }

  void _insertText(String prefix, {String suffix = ''}) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start;
    final end = selection.end;

    if (start >= 0 && end >= 0) {
      final selectedText = text.substring(start, end);
      final replacement = '$prefix$selectedText$suffix';
      _controller.value = _controller.value.copyWith(
        text: text.replaceRange(start, end, replacement),
        selection: TextSelection.collapsed(
          offset: start + prefix.length + selectedText.length + suffix.length,
        ),
      );
    } else {
      final offset = start >= 0 ? start : text.length;
      final replacement = '$prefix$suffix';
      _controller.value = _controller.value.copyWith(
        text: text.replaceRange(offset, offset, replacement),
        selection: TextSelection.collapsed(offset: offset + prefix.length),
      );
    }
    _focusNode.requestFocus();
  }

  Future<bool> _showDiscardDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.notesUnsavedChangesTitle,
      message: l10n.notesUnsavedChangesMessage,
      cancelLabel: l10n.notesKeepEditing,
      confirmLabel: l10n.notesDiscard,
    );
    return confirmed ?? false;
  }

  String _getTitle(String content) {
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('# ')) {
        return trimmed.substring(2).trim();
      } else if (trimmed.isNotEmpty) {
        if (trimmed.startsWith('## ') || trimmed.startsWith('### ')) {
          return trimmed.replaceAll(RegExp(r'^#+\s+'), '').trim();
        }
        return trimmed;
      }
    }
    return 'Untitled';
  }

  String _getPureContent(String content) {
    final lines = content.split('\n');
    int titleIdx = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].trim().isNotEmpty) {
        titleIdx = i;
        break;
      }
    }
    if (titleIdx == -1) return '';
    final remainingLines = lines.skip(titleIdx + 1).toList();
    return remainingLines.join('\n').trim();
  }

  void _saveNote() {
    widget.onSave(_composeContent(), _tags);
  }

  Future<void> _exportPdf(BuildContext context) async {
    final content = _composeContent();
    if (content.trim().isEmpty) return;
    await PdfExportHelper.exportMarkdown(
      context: context,
      markdown: content,
      suggestedName: 'note.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasChanges = _controller.text != _initialBody;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          if (hasChanges) {
            final shouldDiscard = await _showDiscardDialog(context);
            if (shouldDiscard) {
              widget.onCancel();
            }
          } else {
            widget.onCancel();
          }
        }
      },
      child: Scaffold(
        appBar: null,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                color: theme.colorScheme.surface,
                child: Column(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _optionsExpanded = !_optionsExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 6.0,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () async {
                                if (hasChanges) {
                                  final shouldDiscard =
                                      await _showDiscardDialog(context);
                                  if (shouldDiscard) {
                                    widget.onCancel();
                                  }
                                } else {
                                  widget.onCancel();
                                }
                              },
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.id == null
                                    ? l10n.notesCreateNoteTitle
                                    : l10n.notesEditNoteTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.save,
                                color: _controller.text.trim().isEmpty
                                    ? theme.colorScheme.onSurface.withValues(
                                        alpha: 0.3,
                                      )
                                    : AppTheme.accentTeal,
                              ),
                              tooltip: l10n.commonSave,
                              onPressed: _controller.text.trim().isEmpty
                                  ? null
                                  : _saveNote,
                            ),
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              turns: _optionsExpanded ? 0.0 : -0.25,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(Icons.expand_more),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    AnimatedCrossFade(
                      firstChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: Wrap(
                              spacing: 8.0,
                              runSpacing: 6.0,
                              alignment: WrapAlignment.start,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SegmentedButton<NoteEditMode>(
                                  showSelectedIcon: false,
                                  style: SegmentedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    selectedBackgroundColor: AppTheme.accentTeal
                                        .withValues(alpha: 0.2),
                                    selectedForegroundColor:
                                        AppTheme.accentTeal,
                                  ),
                                  segments: [
                                    ButtonSegment(
                                      value: NoteEditMode.live,
                                      icon: const Icon(
                                        Icons.edit_note,
                                        size: 20,
                                      ),
                                      tooltip: l10n.notesModeLiveTooltip,
                                    ),
                                    ButtonSegment(
                                      value: NoteEditMode.source,
                                      icon: const Icon(Icons.code, size: 20),
                                      tooltip: l10n.notesModeSourceTooltip,
                                    ),
                                    ButtonSegment(
                                      value: NoteEditMode.preview,
                                      icon: const Icon(
                                        Icons.visibility,
                                        size: 20,
                                      ),
                                      tooltip: l10n.notesModePreviewTooltip,
                                    ),
                                  ],
                                  selected: {_editMode},
                                  onSelectionChanged: (newSelection) {
                                    setState(() {
                                      _editMode = newSelection.first;
                                      _controller.showRawSource =
                                          _editMode == NoteEditMode.source;
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.picture_as_pdf_outlined,
                                  ),
                                  tooltip: l10n.notesExportPdf,
                                  onPressed: _controller.text.trim().isEmpty
                                      ? null
                                      : () => _exportPdf(context),
                                ),
                              ],
                            ),
                          ),
                          if (_editMode != NoteEditMode.preview) ...[
                            NoteEditorToolbar(
                              onBold: () => _insertText('**', suffix: '**'),
                              onItalic: () => _insertText('*', suffix: '*'),
                              onStrikethrough: () =>
                                  _insertText('~~', suffix: '~~'),
                              onH1: () => _insertText('# '),
                              onH2: () => _insertText('## '),
                              onH3: () => _insertText('### '),
                              onList: () => _insertText('- '),
                              onTodo: () => _insertText('- [ ] '),
                              onLink: () => _insertText('[', suffix: '](url)'),
                              onCode: () => _insertText('`', suffix: '`'),
                              onCodeBlock: () =>
                                  _insertText('\n```\n', suffix: '\n```\n'),
                              onImage: () => _showImageSourceDialog(),
                            ),
                            Container(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              child: TagInput(
                                tags: _tags,
                                onTagsChanged: (tags) {
                                  setState(() => _tags = tags);
                                },
                                suggestions: widget.allTags,
                              ),
                            ),
                          ],
                          const Divider(height: 1),
                        ],
                      ),
                      secondChild: const SizedBox(width: double.infinity),
                      crossFadeState: _optionsExpanded
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      duration: const Duration(milliseconds: 200),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _editMode == NoteEditMode.preview
                    ? ZoomableArea(
                        accentColor: AppTheme.accentTeal,
                        builder: (context, scale, physics) {
                          final content = _composeContent();
                          final title = _getTitle(content);
                          final body = _getPureContent(content);
                          return SingleChildScrollView(
                            physics: physics,
                            child: Container(
                              color: theme.colorScheme.surface,
                              padding: const EdgeInsets.all(24),
                              width: double.infinity,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.accentTeal,
                                        ),
                                  ),
                                  const Divider(height: 32),
                                  if (body.isEmpty)
                                    Text(
                                      l10n.widgetMarkdownNoContent,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontStyle: FontStyle.italic,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.4),
                                          ),
                                    )
                                  else
                                    MarkdownView(
                                      data: body,
                                      selectable: true,
                                      accentColor: AppTheme.accentTeal,
                                      scale: scale,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    : ClipRect(
                        child: NoteEditorTextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          isMonospace: _editMode == NoteEditMode.source,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
