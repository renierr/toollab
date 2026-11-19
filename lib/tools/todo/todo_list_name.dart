import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/models/todo_list.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';

/// The default list is stored nameless so every device shows it localized.
String todoListName(TodoList list, AppLocalizations l10n) =>
    list.name.isEmpty && list.shortId == TodoState.defaultListId
    ? l10n.todoDefaultList
    : list.name;
