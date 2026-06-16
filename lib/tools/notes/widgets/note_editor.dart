import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/helpers/pdf_export_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/markdown_view.dart';
import 'package:tool_lab/widgets/zoomable_area.dart';
import 'package:tool_lab/tools/notes/widgets/tag_input.dart';

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

class _NoteEditorState extends State<NoteEditor>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  TabController? _tabController;
  late List<String> _tags;

  static final _listPrefix = RegExp(
    r'^(\s*)([-*+]\s\[[ x]\]\s|[-*+]\s|\d+[.)]\s)',
  );

  KeyEventResult _handleEnter(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    final text = _controller.text;
    final sel = _controller.selection;
    final cursorPos = sel.start;
    final lineStart = text.lastIndexOf('\n', cursorPos - 1) + 1;
    final currentLine = text.substring(lineStart, cursorPos);
    final match = _listPrefix.firstMatch(currentLine);
    if (match == null) return KeyEventResult.ignored;

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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _focusNode = FocusNode(onKeyEvent: _handleEnter);
    _tabController = TabController(length: 2, vsync: this);
    _tags = List.from(widget.initialTags);
    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _tabController?.dispose();
    super.dispose();
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
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          height: 1.5,
        ),
        decoration: InputDecoration(
          hintText: l10n.notesEditorHint,
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context, double scale) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_controller.text.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Text(
            l10n.notesEditorNoPreview,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(16),
      child: MarkdownView(
        data: _controller.text,
        selectable: true,
        accentColor: AppTheme.accentTeal,
        scale: scale,
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
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 800;
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
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: l10n.notesExportPdf,
              onPressed: _controller.text.trim().isEmpty
                  ? null
                  : () => _exportPdf(context),
            ),
            TextButton(
              onPressed: _controller.text.trim().isEmpty
                  ? null
                  : () => widget.onSave(_controller.text, _tags),
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
          bottom: isWide
              ? null
              : TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.accentTeal,
                  labelColor: AppTheme.accentTeal,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  tabs: [
                    Tab(text: l10n.notesTabWrite),
                    Tab(text: l10n.notesTabPreview),
                  ],
                ),
        ),
        body: Column(
          children: [
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
            Expanded(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                            ),
                            child: _buildTextField(context),
                          ),
                        ),
                        Expanded(
                          child: ZoomableArea(
                            accentColor: AppTheme.accentTeal,
                            builder: (context, scale, physics) =>
                                SingleChildScrollView(
                                  physics: physics,
                                  child: _buildPreview(context, scale),
                                ),
                          ),
                        ),
                      ],
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTextField(context),
                        ZoomableArea(
                          accentColor: AppTheme.accentTeal,
                          builder: (context, scale, physics) =>
                              SingleChildScrollView(
                                physics: physics,
                                child: _buildPreview(context, scale),
                              ),
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
