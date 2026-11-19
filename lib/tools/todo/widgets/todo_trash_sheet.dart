import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/models/todo_trash_item.dart';
import 'package:tool_lab/tools/todo/todo_format.dart';
import 'package:tool_lab/tools/todo/todo_list_name.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';

class TodoTrashSheet extends StatefulWidget {
  const TodoTrashSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const TodoTrashSheet(),
  );

  @override
  State<TodoTrashSheet> createState() => _TodoTrashSheetState();
}

class _TodoTrashSheetState extends State<TodoTrashSheet> {
  List<TodoTrashItem>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await context.read<TodoState>().trash();
    if (mounted) setState(() => _items = items);
  }

  Future<void> _restore(List<TodoTrashItem> items) async {
    await context.read<TodoState>().restore(items);
    await _load();
  }

  Future<void> _empty() async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<TodoState>();
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.todoEmptyTrashTitle,
      message: l10n.todoEmptyTrashMessage,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.todoEmptyTrash,
    );
    if (confirmed != true) return;
    await state.emptyTrash();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = _items;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Text(l10n.todoTrash, style: theme.textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                l10n.todoTrashHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (items != null && items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.restore),
                      label: Text(l10n.todoRestoreAll),
                      onPressed: () => _restore(items),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: Text(l10n.todoEmptyTrash),
                      onPressed: _empty,
                    ),
                  ],
                ),
              ),
            Flexible(
              child: items == null
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.todoTrashEmpty,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: items.length,
                      itemBuilder: (context, i) => _TrashTile(
                        item: items[i],
                        onRestore: () => _restore([items[i]]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrashTile extends StatelessWidget {
  final TodoTrashItem item;
  final VoidCallback onRestore;

  const _TrashTile({required this.item, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final list = context.read<TodoState>().listById(item.task.listId);
    return ListTile(
      leading: Icon(
        item.task.completed
            ? Icons.check_circle_outline
            : Icons.circle_outlined,
      ),
      title: Text(
        item.task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          l10n.todoDeletedOn(TodoFormat.dayTime(item.deletedTime, l10n)),
          if (list != null) todoListName(list, l10n),
        ].join(' · '),
      ),
      trailing: IconButton(
        tooltip: l10n.todoRestore,
        icon: const Icon(Icons.restore),
        onPressed: onRestore,
      ),
    );
  }
}
