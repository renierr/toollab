import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:tool_lab/theme/theme.dart';
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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _focusNode = FocusNode();
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
        onTapLink: (text, href, title) {
          if (href != null) {
            launchUrl(Uri.parse(href));
          }
        },
        styleSheet: MarkdownStyleSheet.fromTheme(theme),
      ),
    );
  }

  Future<bool> _showDiscardDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. Do you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
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
                        Expanded(child: _buildPreview(context)),
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
