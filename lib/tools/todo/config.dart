import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'todo_background.dart';
import 'todo_page.dart';
import 'todo_state.dart';
import 'todo_sync_delegate.dart';
import 'widgets/todo_desktop_reminder_host.dart';

class TodoTool {
  TodoTool._();

  static ToolModel get config => ToolModel(
    id: 'todo',
    name: 'Todo',
    description:
        'Tasks with lists, folders, tags, due dates, recurring reminders and alarms',
    icon: Icons.task_alt,
    route: '/todo',
    accentColor: AppTheme.accentBlue,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameTodo,
    descriptionL10n: (l10n) => l10n.toolDescTodo,
    androidProcessIsolated: true,
    createPage: (_) => const TodoPage(),
    syncDelegateFactory: TodoSyncDelegate.new,
    backgroundTasks: () => [TodoBackground.task],
    overlayBuilder: (_) => const TodoDesktopReminderHost(),
    onClose: (context) => context.read<TodoState>().release(),
    stateProviders: () => [
      ChangeNotifierProvider<TodoState>(create: (_) => TodoState()),
    ],
  );
}
