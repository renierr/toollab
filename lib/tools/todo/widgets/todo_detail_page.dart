import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/todo_list_name.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';
import 'package:tool_lab/tools/todo/widgets/todo_task_detail.dart';

/// Task detail as its own route on narrow screens. A plain [Scaffold]:
/// `ToolLayout` needs a GoRouter route, which a pushed page is not.
class TodoDetailPage extends StatelessWidget {
  final String taskId;

  const TodoDetailPage({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final listName = context.select<TodoState, String>((s) {
      final task = s.taskById(taskId);
      final list = task == null ? null : s.listById(task.listId);
      return list == null ? '' : todoListName(list, l10n);
    });
    return Scaffold(
      appBar: AppBar(title: Text(listName)),
      body: TodoTaskDetail(taskId: taskId),
    );
  }
}
