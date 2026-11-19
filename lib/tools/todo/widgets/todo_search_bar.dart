import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';
import 'package:tool_lab/widgets/readable_width.dart';

class TodoSearchBar extends StatelessWidget {
  final VoidCallback onClose;

  const TodoSearchBar({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ReadableWidth(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: SearchBar(
          autoFocus: true,
          elevation: const WidgetStatePropertyAll(0),
          hintText: l10n.todoSearchHint,
          leading: const Icon(Icons.search),
          trailing: [
            IconButton(
              tooltip: l10n.commonClose,
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
          ],
          onChanged: context.read<TodoState>().setQuery,
        ),
      ),
    );
  }
}
