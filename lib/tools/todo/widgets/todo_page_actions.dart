import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';
import 'package:tool_lab/tools/todo/todo_view.dart';
import 'package:tool_lab/tools/todo/widgets/todo_settings_sheet.dart';

List<Widget> todoPageActions(
  BuildContext context, {
  required bool searching,
  required VoidCallback onToggleSearch,
  VoidCallback? onOpenLists,
}) {
  final l10n = AppLocalizations.of(context);
  return [
    if (onOpenLists != null)
      IconButton(
        tooltip: l10n.todoShowLists,
        icon: const Icon(Icons.format_list_bulleted),
        onPressed: onOpenLists,
      ),
    IconButton(
      tooltip: l10n.commonSearch,
      icon: Icon(searching ? Icons.search_off : Icons.search),
      onPressed: onToggleSearch,
    ),
    const _PlannedModeButton(),
    const _SortMenu(),
    const _SyncButton(),
    IconButton(
      tooltip: l10n.todoSettings,
      icon: const Icon(Icons.tune),
      onPressed: () => TodoSettingsSheet.show(context),
    ),
  ];
}

class _PlannedModeButton extends StatelessWidget {
  const _PlannedModeButton();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TodoState>();
    if (state.view.smart != TodoSmartList.planned ||
        state.query.trim().isNotEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final calendar = state.plannedCalendar;
    return IconButton(
      tooltip: calendar ? l10n.todoListView : l10n.todoCalendarView,
      icon: Icon(calendar ? Icons.view_agenda_outlined : Icons.calendar_month),
      onPressed: () => state.setPlannedCalendar(!calendar),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TodoState>();
    final l10n = AppLocalizations.of(context);
    final view = state.view;
    if (view.smart == TodoSmartList.completed) return const SizedBox.shrink();
    final current = state.sortFor(view);
    final labels = {
      TodoSort.manual: l10n.todoSortManual,
      TodoSort.dueDate: l10n.todoSortDue,
      TodoSort.importance: l10n.todoSortImportance,
      TodoSort.alphabetical: l10n.todoSortAlphabetical,
      TodoSort.created: l10n.todoSortCreated,
    };
    return PopupMenuButton<TodoSort>(
      tooltip: l10n.todoSort,
      icon: const Icon(Icons.sort),
      onSelected: (s) => state.setSort(view, s),
      itemBuilder: (_) => [
        for (final e in labels.entries)
          CheckedPopupMenuItem(
            value: e.key,
            checked: e.key == current,
            child: Text(e.value),
          ),
      ],
    );
  }
}

class _SyncButton extends StatelessWidget {
  const _SyncButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final syncing = context.select<TodoState, bool>((s) => s.syncing);
    final error = context.select<TodoState, String?>((s) => s.syncError);
    return IconButton(
      tooltip: error ?? l10n.todoSyncNow,
      icon: syncing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(error == null ? Icons.sync : Icons.sync_problem),
      onPressed: syncing
          ? null
          : () async {
              final messenger = ScaffoldMessenger.of(context);
              final state = context.read<TodoState>();
              final configured = await state.syncNow();
              if (!configured) {
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.todoSyncNotConfigured)),
                );
              } else if (state.syncError != null) {
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.todoSyncFailed)),
                );
              }
            },
    );
  }
}
