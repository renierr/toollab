import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/syntax_highlight_editing_controller.dart';

import '../sqlite_viewer_state.dart';

/// Highlighted SQL input with a line-number gutter. Tab inserts two spaces and
/// Ctrl/Cmd+Enter runs the statement.
class SqliteSqlEditor extends StatefulWidget {
  final VoidCallback onRun;

  const SqliteSqlEditor({super.key, required this.onRun});

  @override
  State<SqliteSqlEditor> createState() => _SqliteSqlEditorState();
}

class _SqliteSqlEditorState extends State<SqliteSqlEditor> {
  final SyntaxHighlightEditingController _controller =
      SyntaxHighlightEditingController();
  final ScrollController _scrollController = ScrollController();
  SqliteViewerState? _state;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<SqliteViewerState>();
    if (_state != state) {
      _state?.removeListener(_onStateChanged);
      _state = state;
      state.addListener(_onStateChanged);
    }
    _onStateChanged();
  }

  @override
  void dispose() {
    _state?.removeListener(_onStateChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    final state = _state;
    if (!mounted || state == null) return;
    if (state.sql != _controller.text) {
      final selection = _controller.selection;
      _controller.text = state.sql;
      _controller.selection = TextSelection.collapsed(
        offset: selection.baseOffset.clamp(0, state.sql.length),
      );
    }
    _controller.setHighlight(state.sqlTokens, state.sqlScopes);
  }

  void _onTextChanged() {
    _state?.setSql(_controller.text);
    setState(() {});
  }

  void _insertTab() {
    final selection = _controller.selection;
    if (selection.start < 0) return;
    const tab = '  ';
    _controller.value = TextEditingValue(
      text: _controller.text.replaceRange(selection.start, selection.end, tab),
      selection: TextSelection.collapsed(offset: selection.start + tab.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lineCount = '\n'.allMatches(_controller.text).length + 1;
    final lineNumbers = List.generate(lineCount, (i) => '${i + 1}').join('\n');

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.15,
                    ),
                    border: Border(
                      right: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: Text(
                    lineNumbers,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.4,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.tab): _insertTab,
                      const SingleActivator(
                        LogicalKeyboardKey.enter,
                        control: true,
                      ): widget.onRun,
                      const SingleActivator(
                        LogicalKeyboardKey.enter,
                        meta: true,
                      ): widget.onRun,
                    },
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      minLines: 4,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.4,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: l10n.sqliteViewerSqlHint,
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
