import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
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

  static final _listPrefix = RegExp(
    r'^(\s*)([-*+]\s\[[ x]\]\s|[-*+]\s|\d+[.)]\s)',
  );

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isControlPressed = HardwareKeyboard.instance.isControlPressed;
    final isMetaPressed = HardwareKeyboard.instance.isMetaPressed;
    final isV = event.logicalKey == LogicalKeyboardKey.keyV;

    if (isV && (isControlPressed || isMetaPressed)) {
      _handleClipboardPaste();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final text = _controller.text;
      final sel = _controller.selection;
      final cursorPos = sel.start;
      if (cursorPos >= 0) {
        final lineStart = text.lastIndexOf('\n', cursorPos - 1) + 1;
        final currentLine = text.substring(lineStart, cursorPos);
        final match = _listPrefix.firstMatch(currentLine);
        if (match != null) {
          final prefix = match.group(0)!;
          final rest = currentLine.substring(prefix.length);
          final before = text.substring(0, cursorPos);
          final after = text.substring(sel.end);

          if (rest.trim().isEmpty) {
            final beforeLine = text.substring(0, lineStart);
            _controller.value = TextEditingValue(
              text: '$beforeLine\n$after',
              selection: TextSelection.collapsed(offset: beforeLine.length + 1),
            );
          } else {
            _controller.value = TextEditingValue(
              text: '$before\n$prefix$after',
              selection: TextSelection.collapsed(
                offset: cursorPos + 1 + prefix.length,
              ),
            );
          }
          return KeyEventResult.handled;
        }
      }
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
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) {
        throw Exception('Failed to decode image.');
      }

      const maxDim = 800;
      img.Image processed = decoded;

      if (decoded.width > maxDim || decoded.height > maxDim) {
        double ratio = decoded.width / decoded.height;
        int newWidth, newHeight;
        if (decoded.width > decoded.height) {
          newWidth = maxDim;
          newHeight = (maxDim / ratio).round();
        } else {
          newHeight = maxDim;
          newWidth = (maxDim * ratio).round();
        }
        processed = img.copyResize(decoded, width: newWidth, height: newHeight);
      }

      final compressedBytes = img.encodeJpg(processed, quality: 80);
      final base64Str = base64Encode(compressedBytes);

      final text = _controller.text;
      final matches = RegExp(r'\[img_ref_(\d+)\]').allMatches(text);
      int maxIndex = 0;
      for (final match in matches) {
        final index = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (index > maxIndex) {
          maxIndex = index;
        }
      }
      final refLabel = 'img_ref_${maxIndex + 1}';

      final sanitizedName = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final inlineTag = '![$sanitizedName|300][$refLabel]';
      final refDefinition = '[$refLabel]: data:image/jpeg;base64,$base64Str';

      final selection = _controller.selection;
      final start = selection.start;
      final end = selection.end;

      String updatedText;
      int newCursorPos;

      if (start >= 0 && end >= 0) {
        final textBefore = text.substring(0, start);
        final textAfter = text.substring(end);
        updatedText = '$textBefore$inlineTag$textAfter';
        newCursorPos = start + inlineTag.length;
      } else {
        updatedText = '$text$inlineTag';
        newCursorPos = updatedText.length;
      }

      if (updatedText.endsWith('\n')) {
        updatedText = '$updatedText$refDefinition\n';
      } else {
        updatedText = '$updatedText\n$refDefinition\n';
      }

      _controller.isProgrammaticUpdate = true;
      _controller.value = TextEditingValue(
        text: updatedText,
        selection: TextSelection.collapsed(offset: newCursorPos),
      );
      _controller.isProgrammaticUpdate = false;
    } catch (e) {
      debugPrint('[NoteEditor] Failed to process image: $e');
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

  @override
  void initState() {
    super.initState();
    _controller = MarkdownTextEditingController(
      context: context,
      text: widget.initialContent,
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

  Widget _buildToolbar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = [
      (
        Icons.format_bold,
        l10n.notesToolbarBold,
        () => _insertText('**', suffix: '**'),
      ),
      (
        Icons.format_italic,
        l10n.notesToolbarItalic,
        () => _insertText('*', suffix: '*'),
      ),
      (
        Icons.format_strikethrough,
        l10n.notesToolbarStrikethrough,
        () => _insertText('~~', suffix: '~~'),
      ),
      (Icons.looks_one, l10n.notesToolbarH1, () => _insertText('# ')),
      (Icons.looks_two, l10n.notesToolbarH2, () => _insertText('## ')),
      (Icons.looks_3, l10n.notesToolbarH3, () => _insertText('### ')),
      (
        Icons.format_list_bulleted,
        l10n.notesToolbarList,
        () => _insertText('- '),
      ),
      (
        Icons.check_box_outlined,
        l10n.notesToolbarTodo,
        () => _insertText('- [ ] '),
      ),
      (
        Icons.link,
        l10n.notesToolbarLink,
        () => _insertText('[', suffix: '](url)'),
      ),
      (Icons.code, l10n.notesToolbarCode, () => _insertText('`', suffix: '`')),
      (
        Icons.integration_instructions,
        l10n.notesToolbarCodeBlock,
        () => _insertText('\n```\n', suffix: '\n```\n'),
      ),
      (
        Icons.add_photo_alternate_outlined,
        l10n.notesToolbarImage,
        () => _showImageSourceDialog(),
      ),
    ];

    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      width: double.infinity,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: items.map((item) {
          return Tooltip(
            message: item.$2,
            child: IconButton(
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
              icon: Icon(item.$1, size: 20),
              onPressed: item.$3,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTextField(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surface,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        style: TextStyle(
          fontFamily: _editMode == NoteEditMode.source ? 'monospace' : null,
          fontSize: 14,
          height: 1.5,
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: l10n.notesEditorHint,
          border: InputBorder.none,
        ),
      ),
    );
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

  int _findRefSectionStart(String txt) {
    final match = RegExp(r'\[img_ref_\d+\]: data:image/').firstMatch(txt);
    return match?.start ?? -1;
  }

  String _cleanStaleImageReferences(String text) {
    final refStart = _findRefSectionStart(text);
    if (refStart == -1) return text;

    final body = text.substring(0, refStart);
    final refSection = text.substring(refStart);

    final refMatches = RegExp(r'\[(img_ref_\d+)\]').allMatches(body);
    final referencedLabels = <String>{};
    for (final match in refMatches) {
      final label = match.group(1);
      if (label != null) {
        referencedLabels.add(label);
      }
    }

    final refLines = refSection.split('\n');
    final cleanedRefLines = <String>[];
    for (final line in refLines) {
      final refDefMatch = RegExp(
        r'^\[(img_ref_\d+)\]:\s*data:image/',
      ).firstMatch(line);
      if (refDefMatch != null) {
        final label = refDefMatch.group(1);
        if (label != null && !referencedLabels.contains(label)) {
          continue;
        }
      }
      cleanedRefLines.add(line);
    }

    final cleanedRefSection = cleanedRefLines.join('\n').trim();
    final cleanedBody = body.trimRight();

    if (cleanedRefSection.isEmpty) {
      return '$cleanedBody\n';
    }

    return '$cleanedBody\n\n$cleanedRefSection\n';
  }

  void _saveNote() {
    final originalText = _controller.text;
    final cleanedText = _cleanStaleImageReferences(originalText);

    if (cleanedText != originalText) {
      _controller.isProgrammaticUpdate = true;
      _controller.text = cleanedText;
      _controller.isProgrammaticUpdate = false;
    }

    widget.onSave(cleanedText, _tags);
  }

  Future<void> _exportPdf(BuildContext context) async {
    final content = _controller.text;
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
    final hasChanges = _controller.text != widget.initialContent;

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
        appBar: AppBar(
          title: Text(
            widget.id == null
                ? l10n.notesCreateNoteTitle
                : l10n.notesEditNoteTitle,
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (hasChanges) {
                final shouldDiscard = await _showDiscardDialog(context);
                if (shouldDiscard) {
                  widget.onCancel();
                }
              } else {
                widget.onCancel();
              }
            },
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: SegmentedButton<NoteEditMode>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  selectedBackgroundColor: AppTheme.accentTeal.withValues(
                    alpha: 0.2,
                  ),
                  selectedForegroundColor: AppTheme.accentTeal,
                ),
                segments: [
                  ButtonSegment(
                    value: NoteEditMode.live,
                    icon: const Icon(Icons.edit_note, size: 20),
                    tooltip: l10n.notesModeLiveTooltip,
                  ),
                  ButtonSegment(
                    value: NoteEditMode.source,
                    icon: const Icon(Icons.code, size: 20),
                    tooltip: l10n.notesModeSourceTooltip,
                  ),
                  ButtonSegment(
                    value: NoteEditMode.preview,
                    icon: const Icon(Icons.visibility, size: 20),
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
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: l10n.notesExportPdf,
              onPressed: _controller.text.trim().isEmpty
                  ? null
                  : () => _exportPdf(context),
            ),
            TextButton(
              onPressed: _controller.text.trim().isEmpty ? null : _saveNote,
              child: Text(
                l10n.commonSave,
                style: TextStyle(
                  color: _controller.text.trim().isEmpty
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                      : AppTheme.accentTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_editMode != NoteEditMode.preview) ...[
              _buildToolbar(context),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                child: TagInput(
                  tags: _tags,
                  onTagsChanged: (tags) {
                    setState(() => _tags = tags);
                  },
                  suggestions: widget.allTags,
                ),
              ),
            ],
            Expanded(
              child: _editMode == NoteEditMode.preview
                  ? ZoomableArea(
                      accentColor: AppTheme.accentTeal,
                      builder: (context, scale, physics) =>
                          SingleChildScrollView(
                            physics: physics,
                            child: Container(
                              color: theme.colorScheme.surface,
                              padding: const EdgeInsets.all(16),
                              width: double.infinity,
                              child: MarkdownView(
                                data: _controller.text,
                                selectable: true,
                                accentColor: AppTheme.accentTeal,
                                scale: scale,
                              ),
                            ),
                          ),
                    )
                  : _buildTextField(context),
            ),
          ],
        ),
      ),
    );
  }
}
