import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/tools/todo/todo_desktop_reminders.dart';

/// Starts desktop reminders with the app, not with the tool page. Paints nothing.
class TodoDesktopReminderHost extends StatefulWidget {
  const TodoDesktopReminderHost({super.key});

  @override
  State<TodoDesktopReminderHost> createState() =>
      _TodoDesktopReminderHostState();
}

class _TodoDesktopReminderHostState extends State<TodoDesktopReminderHost> {
  @override
  void initState() {
    super.initState();
    if (TodoDesktopReminders.isSupported) {
      unawaited(TodoDesktopReminders.instance.start());
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
