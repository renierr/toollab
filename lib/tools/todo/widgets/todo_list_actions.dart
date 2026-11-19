import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/models/todo_folder.dart';
import 'package:tool_lab/tools/todo/models/todo_list.dart';
import 'package:tool_lab/tools/todo/todo_list_name.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

/// Create / edit / delete flows for lists and folders.
class TodoListActions {
  TodoListActions._();

  static Future<bool> createList(BuildContext context) async {
    final state = context.read<TodoState>();
    final result = await showDialog<_ListDraft>(
      context: context,
      builder: (_) => const _ListEditorDialog(),
    );
    if (result == null || result.name.trim().isEmpty) return false;
    await state.createList(
      result.name,
      emoji: result.emoji,
      color: result.color,
      folderId: result.folderId,
    );
    return true;
  }

  static Future<void> editList(BuildContext context, TodoList list) async {
    final state = context.read<TodoState>();
    final result = await showDialog<_ListDraft>(
      context: context,
      builder: (_) => _ListEditorDialog(list: list),
    );
    if (result == null) return;
    final name = result.name.trim();
    await state.updateList(
      list.copyWith(
        name: name.isEmpty ? list.name : name,
        emoji: result.emoji,
        color: result.color,
        folderId: () => result.folderId,
      ),
    );
  }

  static Future<void> deleteList(BuildContext context, TodoList list) async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<TodoState>();
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.todoDeleteListTitle,
      message: l10n.todoDeleteListMessage(todoListName(list, l10n)),
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.commonDelete,
    );
    if (confirmed == true) await state.deleteList(list);
  }

  static Future<void> createFolder(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<TodoState>();
    final name = await TodoTextInputDialog.show(
      context,
      title: l10n.todoNewFolder,
      hint: l10n.todoFolderName,
    );
    if (name != null && name.trim().isNotEmpty) await state.createFolder(name);
  }

  static Future<void> showListMenu(BuildContext context, TodoList list) async {
    final l10n = AppLocalizations.of(context);
    final isDefault = list.shortId == TodoState.defaultListId;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.todoEditList),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            if (!isDefault)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.todoDeleteListTitle),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'edit':
        await editList(context, list);
      case 'delete':
        await deleteList(context, list);
    }
  }

  static Future<void> showFolderMenu(
    BuildContext context,
    TodoFolder folder,
  ) async {
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
              leading: const Icon(Icons.drive_file_rename_outline),
              title: Text(l10n.todoRenameFolder),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: Text(l10n.todoDeleteFolder),
              subtitle: Text(l10n.todoDeleteFolderHint),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'rename':
        final name = await TodoTextInputDialog.show(
          context,
          title: l10n.todoRenameFolder,
          hint: l10n.todoFolderName,
          initial: folder.name,
        );
        if (name != null && name.trim().isNotEmpty) {
          await state.renameFolder(folder, name);
        }
      case 'delete':
        await state.deleteFolder(folder);
    }
  }
}

class _ListDraft {
  final String name;
  final String emoji;
  final int color;
  final String? folderId;

  const _ListDraft(this.name, this.emoji, this.color, this.folderId);
}

class _ListEditorDialog extends StatefulWidget {
  final TodoList? list;

  const _ListEditorDialog({this.list});

  @override
  State<_ListEditorDialog> createState() => _ListEditorDialogState();
}

class _ListEditorDialogState extends State<_ListEditorDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.list == null
        ? ''
        : todoListName(widget.list!, AppLocalizations.of(context)),
  );
  late final TextEditingController _emoji = TextEditingController(
    text: widget.list?.emoji ?? '',
  );
  late int _color = widget.list?.color ?? TodoState.listColors.first;
  late String? _folderId = widget.list?.folderId;

  @override
  void dispose() {
    _name.dispose();
    _emoji.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(
      context,
      _ListDraft(_name.text, _emoji.text.trim(), _color, _folderId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final folders = context.watch<TodoState>().folders;
    return ResponsiveAlertDialog(
      title: Text(widget.list == null ? l10n.todoNewList : l10n.todoEditList),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _emoji,
                  textAlign: TextAlign.center,
                  maxLength: 2,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '😀',
                    labelText: l10n.todoEmoji,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: l10n.todoListName),
                  onSubmitted: (_) => _submit(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in TodoState.listColors)
                _ColorDot(
                  color: Color(c),
                  selected: c == _color,
                  onTap: () => setState(() => _color = c),
                ),
            ],
          ),
          if (folders.isNotEmpty) ...[
            const SizedBox(height: 20),
            DropdownButtonFormField<String?>(
              initialValue: _folderId,
              decoration: InputDecoration(labelText: l10n.todoFolder),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.todoNoFolder)),
                for (final f in folders)
                  DropdownMenuItem(value: f.shortId, child: Text(f.name)),
              ],
              onChanged: (v) => setState(() => _folderId = v),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.commonSave)),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? onSurface : color,
            width: selected ? 3 : 0,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, size: 18, color: Colors.white)
            : null,
      ),
    );
  }
}

class TodoTextInputDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String initial;

  const TodoTextInputDialog({
    super.key,
    required this.title,
    required this.hint,
    this.initial = '',
  });

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String hint,
    String initial = '',
  }) => showDialog<String>(
    context: context,
    builder: (_) =>
        TodoTextInputDialog(title: title, hint: hint, initial: initial),
  );

  @override
  State<TodoTextInputDialog> createState() => _TodoTextInputDialogState();
}

class _TodoTextInputDialogState extends State<TodoTextInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
