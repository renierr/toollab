import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/tools/todo/todo_view.dart';

class TodoColors {
  TodoColors._();

  static const Color myDay = Color(0xFFFFB74D);
  static const Color important = Color(0xFFF06292);
  static const Color planned = Color(0xFF4DB6AC);
  static const Color all = Color(0xFF7986CB);
  static const Color completed = Color(0xFF81C784);
  static const Color overdue = Color(0xFFE57373);
  static const Color star = Color(0xFFF06292);

  static Color smart(TodoSmartList smart) => switch (smart) {
    TodoSmartList.myDay => myDay,
    TodoSmartList.important => important,
    TodoSmartList.planned => planned,
    TodoSmartList.all => all,
    TodoSmartList.completed => completed,
  };

  static IconData smartIcon(TodoSmartList smart) => switch (smart) {
    TodoSmartList.myDay => Icons.wb_sunny_outlined,
    TodoSmartList.important => Icons.star_outline,
    TodoSmartList.planned => Icons.event_outlined,
    TodoSmartList.all => Icons.all_inclusive,
    TodoSmartList.completed => Icons.check_circle_outline,
  };
}
