import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';

/// Captures what an undo snackbar needs up front, so it still works after
/// the calling route was popped.
class TodoUndoNotifier {
  final ScaffoldMessengerState messenger;
  final TodoState state;
  final String label;

  TodoUndoNotifier.of(BuildContext context)
    : messenger = ScaffoldMessenger.of(context),
      state = context.read<TodoState>(),
      label = AppLocalizations.of(context).todoUndo;

  void show(String message, TodoUndo undo) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
        behavior: SnackBarBehavior.floating,
        // Snackbars with an action persist by default.
        persist: false,
        action: SnackBarAction(label: label, onPressed: () => state.undo(undo)),
      ),
    );
  }
}
