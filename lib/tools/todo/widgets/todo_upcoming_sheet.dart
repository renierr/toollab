import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/todo_format.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';
import 'package:tool_lab/tools/todo/todo_upcoming.dart';

class TodoUpcomingSheet extends StatefulWidget {
  const TodoUpcomingSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const TodoUpcomingSheet(),
  );

  @override
  State<TodoUpcomingSheet> createState() => _TodoUpcomingSheetState();
}

class _TodoUpcomingSheetState extends State<TodoUpcomingSheet> {
  late final Future<List<TodoUpcomingReminder>> _future;

  @override
  void initState() {
    super.initState();
    final state = context.read<TodoState>();
    _future = TodoUpcoming.load(
      tasks: state.tasks,
      lists: state.lists,
      l10n: AppLocalizations.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
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
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                l10n.todoUpcomingTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: FutureBuilder<List<TodoUpcomingReminder>>(
                future: _future,
                builder: (context, snapshot) {
                  final items = snapshot.data;
                  if (items == null) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.todoUpcomingEmpty,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _UpcomingTile(item: items[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  final TodoUpcomingReminder item;

  const _UpcomingTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entry = item.entry;
    final kind = item.snoozed
        ? l10n.todoSnoozed
        : entry.alarm
        ? l10n.todoAlarm
        : l10n.todoReminder;
    return ListTile(
      leading: Icon(
        item.snoozed
            ? Icons.snooze
            : entry.alarm
            ? Icons.alarm
            : Icons.notifications_none,
        color: Color(entry.color),
      ),
      title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          TodoFormat.dayTime(item.time, l10n),
          kind,
          if (entry.body.isNotEmpty) entry.body,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
