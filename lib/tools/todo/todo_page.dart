import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/config.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/todo_native.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';
import 'package:tool_lab/tools/todo/widgets/todo_detail_page.dart';
import 'package:tool_lab/tools/todo/widgets/todo_page_actions.dart';
import 'package:tool_lab/tools/todo/widgets/todo_search_bar.dart';
import 'package:tool_lab/tools/todo/widgets/todo_sidebar.dart';
import 'package:tool_lab/tools/todo/widgets/todo_task_detail.dart';
import 'package:tool_lab/tools/todo/widgets/todo_task_pane.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> with DisposeCleanup {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FocusNode _quickAddFocus = FocusNode();
  bool _searching = false;
  bool _detailInline = false;
  String? _lastIntentKey;
  DateTime _lastIntentAt = DateTime(0);

  @override
  void initState() {
    super.initState();
    onDispose(_quickAddFocus.dispose);
    final state = context.read<TodoState>();
    final sub = state.launchIntents.listen(_handleIntent);
    onDispose(sub.cancel);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start(state));
  }

  Future<void> _start(TodoState state) async {
    if (!state.loaded) await state.load();
    final intent = await TodoNative.consumeLaunchIntent();
    if (intent != null) await _handleIntent(intent);
  }

  /// Native may both push and hand out the same launch intent; act once.
  Future<void> _handleIntent(TodoLaunchIntent intent) async {
    final key = '${intent.taskId}|${intent.quickAdd}|${intent.listId}';
    final now = DateTime.now();
    if (key == _lastIntentKey &&
        now.difference(_lastIntentAt) < const Duration(seconds: 3)) {
      return;
    }
    _lastIntentKey = key;
    _lastIntentAt = now;
    if (!mounted) return;
    final state = context.read<TodoState>();
    await state.handleLaunchIntent(intent);
    if (!mounted) return;
    final task = intent.taskId == null ? null : state.taskById(intent.taskId!);
    if (task != null) _openTask(task);
    if (intent.quickAdd) _quickAddFocus.requestFocus();
  }

  void _openTask(TodoTask task) {
    final state = context.read<TodoState>();
    state.selectTask(task.shortId);
    if (_detailInline) return;
    unawaited(
      Navigator.of(context)
          .push(
            MaterialPageRoute<void>(
              builder: (_) => TodoDetailPage(taskId: task.shortId),
            ),
          )
          .then((_) {
            if (mounted) state.selectTask(null);
          }),
    );
  }

  void _toggleSearch() {
    final state = context.read<TodoState>();
    setState(() => _searching = !_searching);
    if (!_searching) state.setQuery('');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedId = context.select<TodoState, String?>(
      (s) => s.selectedTask?.shortId,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.canSplit;
        // Sidebar + task list + detail need roughly 280 + 360 + 400.
        final threePanes = constraints.maxWidth >= 1040;
        _detailInline = threePanes;

        final pane = Column(
          children: [
            if (_searching) TodoSearchBar(onClose: _toggleSearch),
            Expanded(
              child: TodoTaskPane(
                onOpenTask: _openTask,
                quickAddFocus: _quickAddFocus,
              ),
            ),
          ],
        );

        return ToolLayout(
          scaffoldKey: _scaffoldKey,
          title: TodoTool.config.localizedName(l10n),
          drawer: split
              ? null
              : Drawer(
                  child: TodoSidebar(
                    onSelected: () => _scaffoldKey.currentState?.closeDrawer(),
                  ),
                ),
          actions: todoPageActions(
            context,
            searching: _searching,
            onToggleSearch: _toggleSearch,
          ),
          child: split
              ? Row(
                  children: [
                    const SizedBox(width: 280, child: TodoSidebar()),
                    const VerticalDivider(width: 1),
                    Expanded(child: pane),
                    if (threePanes && selectedId != null) ...[
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: 400,
                        child: TodoTaskDetail(
                          key: ValueKey(selectedId),
                          taskId: selectedId,
                          onClose: () =>
                              context.read<TodoState>().selectTask(null),
                        ),
                      ),
                    ],
                  ],
                )
              : pane,
        );
      },
    );
  }
}
