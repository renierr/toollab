import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/models/todo_folder.dart';
import 'package:tool_lab/tools/todo/models/todo_list.dart';
import 'package:tool_lab/tools/todo/todo_colors.dart';
import 'package:tool_lab/tools/todo/todo_format.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';
import 'package:tool_lab/tools/todo/todo_view.dart';
import 'package:tool_lab/tools/todo/widgets/todo_filter_dialog.dart';
import 'package:tool_lab/tools/todo/widgets/todo_list_actions.dart';
import 'package:tool_lab/tools/todo/todo_list_name.dart';

/// Smart lists, folders, lists and tags. Inline on wide screens, a drawer
/// on narrow ones; [onSelected] closes the drawer.
class TodoSidebar extends StatelessWidget {
  final VoidCallback? onSelected;

  const TodoSidebar({super.key, this.onSelected});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TodoState>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final topLevel = state.listsInFolder(null);
    final tags = state.allTags;

    void select(TodoView view) {
      state.selectView(view);
      onSelected?.call();
    }

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final smart in TodoSmartList.values)
                    _SidebarTile(
                      icon: Icon(
                        TodoColors.smartIcon(smart),
                        color: TodoColors.smart(smart),
                      ),
                      label: TodoFormat.smartName(smart, l10n),
                      count: smart == TodoSmartList.completed
                          ? null
                          : state.openCount(TodoView.smart(smart)),
                      selected: state.view == TodoView.smart(smart),
                      onTap: () => select(TodoView.smart(smart)),
                    ),
                  const Divider(indent: 16, endIndent: 16),
                  for (final list in topLevel)
                    _ListTile(list: list, onTap: select),
                  for (final folder in state.folders)
                    _FolderSection(folder: folder, onTap: select),
                  if (state.filters.isNotEmpty) ...[
                    const Divider(indent: 16, endIndent: 16),
                    _SectionLabel(l10n.todoFilters),
                    for (final filter in state.filters)
                      _SidebarTile(
                        icon: const Icon(
                          Icons.filter_alt_outlined,
                          color: TodoColors.filter,
                        ),
                        label: filter.name,
                        count: state.openCount(TodoView.filter(filter.id)),
                        selected: state.view == TodoView.filter(filter.id),
                        onTap: () => select(TodoView.filter(filter.id)),
                        onLongPress: () =>
                            TodoFilterActions.showMenu(context, filter),
                      ),
                  ],
                  if (tags.isNotEmpty) ...[
                    const Divider(indent: 16, endIndent: 16),
                    _SectionLabel(l10n.todoTags),
                    for (final tag in tags)
                      _SidebarTile(
                        icon: Icon(
                          Icons.tag,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        label: tag,
                        count: state.openCount(TodoView.tag(tag)),
                        selected: state.view == TodoView.tag(tag),
                        onTap: () => select(TodoView.tag(tag)),
                      ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.todoNewList),
                      onPressed: () async {
                        final created = await TodoListActions.createList(
                          context,
                        );
                        if (created) onSelected?.call();
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.todoNewFilter,
                    icon: const Icon(Icons.filter_alt_outlined),
                    onPressed: () async {
                      final created = await TodoFilterActions.edit(context);
                      if (created) onSelected?.call();
                    },
                  ),
                  IconButton(
                    tooltip: l10n.todoNewFolder,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    onPressed: () => TodoListActions.createFolder(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListTile extends StatelessWidget {
  final TodoList list;
  final ValueChanged<TodoView> onTap;
  final double indent;

  const _ListTile({required this.list, required this.onTap, this.indent = 0});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TodoState>();
    final view = TodoView.list(list.shortId);
    return _SidebarTile(
      indent: indent,
      icon: list.emoji.isNotEmpty
          ? Text(list.emoji, style: const TextStyle(fontSize: 18))
          : Icon(Icons.list_rounded, color: Color(list.color)),
      label: todoListName(list, AppLocalizations.of(context)),
      count: state.openCount(view),
      selected: state.view == view,
      onTap: () => onTap(view),
      onLongPress: () => TodoListActions.showListMenu(context, list),
    );
  }
}

class _FolderSection extends StatelessWidget {
  final TodoFolder folder;
  final ValueChanged<TodoView> onTap;

  const _FolderSection({required this.folder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TodoState>();
    final theme = Theme.of(context);
    final lists = state.listsInFolder(folder.shortId);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey('todo-folder-${folder.shortId}'),
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.only(left: 20, right: 8),
        leading: Icon(
          Icons.folder_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: GestureDetector(
          onLongPress: () => TodoListActions.showFolderMenu(context, folder),
          child: Text(folder.name, style: theme.textTheme.titleSmall),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_horiz, size: 20),
          onPressed: () => TodoListActions.showFolderMenu(context, folder),
        ),
        children: [
          for (final list in lists)
            _ListTile(list: list, onTap: onTap, indent: 16),
          if (lists.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
              child: Text(
                AppLocalizations.of(context).todoFolderEmpty,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final Widget icon;
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double indent;

  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.indent = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(left: 8 + indent, right: 8),
      child: ListTile(
        dense: true,
        selected: selected,
        selectedTileColor: theme.colorScheme.secondaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: SizedBox(width: 28, child: Center(child: icon)),
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: selected ? FontWeight.w600 : null,
          ),
        ),
        trailing: count != null && count! > 0
            ? Text(
                '$count',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
