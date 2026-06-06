import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:tool_lab/helpers/pdf_export_helper.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/markdown_checkbox.dart';
import 'package:url_launcher/url_launcher.dart';

class NoteEditor extends StatefulWidget {
  final int? id;
  final String initialContent;
  final Function(String content) onSave;
  final VoidCallback onCancel;

  const NoteEditor({
    super.key,
    this.id,
    required this.initialContent,
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
    final theme = Theme.of(context);
    final items = [
      (Icons.format_bold, 'Bold', () => _insertText('**', suffix: '**')),
      (Icons.format_italic, 'Italic', () => _insertText('*', suffix: '*')),
      (
        Icons.format_strikethrough,
        'Strikethrough',
        () => _insertText('~~', suffix: '~~'),
      ),
      (Icons.looks_one, 'H1', () => _insertText('# ')),
      (Icons.looks_two, 'H2', () => _insertText('## ')),
      (Icons.looks_3, 'H3', () => _insertText('### ')),
      (Icons.format_list_bulleted, 'List', () => _insertText('- ')),
      (Icons.check_box_outlined, 'Todo', () => _insertText('- [ ] ')),
      (Icons.link, 'Link', () => _insertText('[', suffix: '](url)')),
      (Icons.code, 'Code', () => _insertText('`', suffix: '`')),
      (
        Icons.integration_instructions,
        'Code Block',
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
        decoration: const InputDecoration(
          hintText: 'Write notes here... (Markdown supported)',
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final theme = Theme.of(context);

    if (_controller.text.trim().isEmpty) {
      return Center(
        child: Text(
          'Nothing to preview yet',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(16),
      child: MarkdownBody(
        data: _controller.text,
        selectable: true,
        extensionSet: md.ExtensionSet.gitHubFlavored,
        listItemCrossAxisAlignment: MarkdownListItemCrossAxisAlignment.baseline,
        checkboxBuilder: (checked) => MarkdownCheckbox(
          checked: checked,
          checkedColor: AppTheme.accentTeal,
        ),
        onTapLink: (text, href, title) {
          if (href != null) {
            launchUrl(Uri.parse(href));
          }
        },
        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
          blockquoteDecoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.surfaceContainerHighest
                : Colors.blue.shade100,
            borderRadius: BorderRadius.circular(2.0),
          ),
        ),
      ),
    );
  }

  Future<bool> _showDiscardDialog(BuildContext context) async {
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: 'Unsaved Changes',
      message: 'You have unsaved changes. Do you want to discard them?',
      cancelLabel: 'Keep Editing',
      confirmLabel: 'Discard',
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
          title: Text(widget.id == null ? 'Create Note' : 'Edit Note'),
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
              tooltip: 'Export PDF',
              onPressed: _controller.text.trim().isEmpty
                  ? null
                  : () => _exportPdf(context),
            ),
            TextButton(
              onPressed: _controller.text.trim().isEmpty
                  ? null
                  : () => widget.onSave(_controller.text),
              child: Text(
                'Save',
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
                  tabs: const [
                    Tab(text: 'Write'),
                    Tab(text: 'Preview'),
                  ],
                ),
        ),
        body: Column(
          children: [
            _buildToolbar(context),
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
                          child: SingleChildScrollView(
                            child: _buildPreview(context),
                          ),
                        ),
                      ],
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTextField(context),
                        SingleChildScrollView(child: _buildPreview(context)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
