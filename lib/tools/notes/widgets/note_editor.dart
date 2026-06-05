import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:tool_lab/theme/theme.dart';

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
      (Icons.title, 'H1', () => _insertText('# ')),
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
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Tooltip(
            message: item.$2,
            child: IconButton(
              icon: Icon(item.$1, size: 20),
              onPressed: item.$3,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        },
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
    final isDark = theme.brightness == Brightness.dark;
    final mdConfig = isDark
        ? MarkdownConfig.darkConfig
        : MarkdownConfig.defaultConfig;

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
      child: MarkdownWidget(
        data: _controller.text,
        config: mdConfig,
        shrinkWrap: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.id == null ? 'Create Note' : 'Edit Note'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel,
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
    );
  }
}
