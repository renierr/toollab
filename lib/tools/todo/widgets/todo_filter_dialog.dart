import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/models/todo_filter.dart';
import 'package:tool_lab/tools/todo/todo_list_name.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

/// Create, edit and delete flows for saved filters.
class TodoFilterActions {
  TodoFilterActions._();

  static Future<bool> edit(BuildContext context, {TodoFilter? filter}) async {
    final state = context.read<TodoState>();
    final result = await showDialog<TodoFilter>(
      context: context,
      builder: (_) => _FilterDialog(filter: filter),
    );
    if (result == null) return false;
    await state.saveFilter(result);
    return true;
  }

  static Future<void> showMenu(BuildContext context, TodoFilter filter) async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<TodoState>();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.todoEditFilter),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.todoDeleteFilter),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'edit':
        await edit(context, filter: filter);
      case 'delete':
        final confirmed = await ConfirmActionDialog.show(
          context: context,
          title: l10n.todoDeleteFilter,
          message: l10n.todoDeleteFilterMessage(filter.name),
          cancelLabel: l10n.commonCancel,
          confirmLabel: l10n.commonDelete,
        );
        if (confirmed == true) await state.deleteFilter(filter);
    }
  }
}

class _FilterDialog extends StatefulWidget {
  final TodoFilter? filter;

  const _FilterDialog({this.filter});

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.filter?.name ?? '',
  );
  late String? _listId = widget.filter?.listId;
  late String? _tag = widget.filter?.tag;
  late TodoFilterDue _due = widget.filter?.due ?? TodoFilterDue.any;
  late bool _important = widget.filter?.importantOnly ?? false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      TodoFilter(
        id: widget.filter?.id ?? '',
        name: name,
        listId: _listId,
        tag: _tag,
        due: _due,
        importantOnly: _important,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<TodoState>();
    final tags = [...state.allTags];
    final tag = _tag == null
        ? null
        : tags.firstWhere(
            (t) => t.toLowerCase() == _tag!.toLowerCase(),
            orElse: () {
              tags.add(_tag!);
              return _tag!;
            },
          );
    final dueLabels = {
      TodoFilterDue.any: l10n.todoFilterAny,
      TodoFilterDue.overdue: l10n.todoFilterDueOverdue,
      TodoFilterDue.today: l10n.todoFilterDueToday,
      TodoFilterDue.thisWeek: l10n.todoThisWeek,
      TodoFilterDue.next7Days: l10n.todoFilterDueNext7,
      TodoFilterDue.noDate: l10n.todoNoDate,
    };
    return ResponsiveAlertDialog(
      scrollable: true,
      title: Text(
        widget.filter == null ? l10n.todoNewFilter : l10n.todoEditFilter,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            autofocus: widget.filter == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.todoFilterName),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: state.listById(_listId) == null ? null : _listId,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.todoFilterList),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.todoFilterAny)),
              for (final list in state.lists)
                DropdownMenuItem(
                  value: list.shortId,
                  child: Text(
                    todoListName(list, l10n),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _listId = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: tag,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.todoFilterTag),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.todoFilterAny)),
              for (final tag in tags)
                DropdownMenuItem(value: tag, child: Text('#$tag')),
            ],
            onChanged: (v) => setState(() => _tag = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<TodoFilterDue>(
            initialValue: _due,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.todoFilterDue),
            items: [
              for (final e in dueLabels.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _due = v ?? TodoFilterDue.any),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.todoFilterImportantOnly),
            value: _important,
            onChanged: (v) => setState(() => _important = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        ListenableBuilder(
          listenable: _name,
          builder: (context, _) => FilledButton(
            onPressed: _name.text.trim().isEmpty ? null : _submit,
            child: Text(l10n.commonSave),
          ),
        ),
      ],
    );
  }
}
